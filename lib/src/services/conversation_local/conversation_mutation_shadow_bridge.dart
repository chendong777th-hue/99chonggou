import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_last_message_prefer.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/enum/conversation_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

import 'conversation_mutation_coordinator.dart';
import 'conversation_mutation_event.dart';

class ConversationShadowDifference {
  const ConversationShadowDifference({
    required this.canonicalConversationId,
    required this.fields,
  });

  final String canonicalConversationId;
  final Set<ConversationMutationField> fields;
}

class ConversationSdkCommitCandidate {
  const ConversationSdkCommitCandidate({
    required this.conversation,
    required this.plan,
  });

  final V2TimConversation conversation;
  final ConversationDatabaseCommitPlan<V2TimConversation> plan;
}

/// Read-only adapter from SDK conversation objects into the phase-2 shadow
/// coordinator. It never writes SQLite and never notifies the conversation UI.
class ConversationMutationShadowBridge {
  ConversationMutationShadowBridge._();

  static final ConversationMutationShadowBridge instance =
      ConversationMutationShadowBridge._();

  /// Shadow comparison stays out of release builds until it is proven bounded.
  static bool enabled = kDebugMode;

  /// Phase-3 kill switch: when disabled, SDK sources fall back to the legacy
  /// direct persist path while shadow comparison may still run in debug builds.
  static bool authoritativeSdkCommitEnabled = true;

  ConversationMutationCoordinator _coordinator =
      ConversationMutationCoordinator();
  String _activeOwner = '';
  int _ownerGeneration = 0;
  int _eventSequence = 0;
  final Map<String, int> _conversationGenerations = <String, int>{};
  final Set<String> _tombstoned = <String>{};
  Future<void> _pending = Future<void>.value();
  List<ConversationShadowDifference> _lastDifferences =
      const <ConversationShadowDifference>[];

  ConversationMutationCoordinator get coordinator => _coordinator;

  List<ConversationShadowDifference> get lastDifferences => _lastDifferences;

  void restoreDurableConversationState({
    required String ownerUserId,
    required String conversationId,
    required int generation,
    required bool tombstoned,
  }) {
    final owner = ownerUserId.trim();
    final type = _conversationTypeFromId(conversationId);
    if (owner.isEmpty || type == null) {
      return;
    }
    _ensureOwner(owner);
    final canonical = canonicalizeConversationMutationId(conversationId, type);
    if (canonical.isEmpty) {
      return;
    }
    final current = _conversationGenerations[canonical] ?? 0;
    if (generation > current) {
      _conversationGenerations[canonical] = generation;
    }
    if (tombstoned) {
      _tombstoned.add(canonical);
    }
  }

  Future<List<V2TimConversation>> admitSdkConversationsForCommit({
    required String ownerUserId,
    required List<V2TimConversation> conversations,
    required ConversationMutationSource source,
    bool allowRecreate = false,
  }) async {
    if (conversations.isEmpty) {
      return const <V2TimConversation>[];
    }
    if (!authoritativeSdkCommitEnabled) {
      observeSdkConversations(
        ownerUserId: ownerUserId,
        conversations: conversations,
        source: source,
        allowRecreate: allowRecreate,
      );
      return conversations;
    }
    final owner = ownerUserId.trim();
    if (owner.isEmpty) {
      return const <V2TimConversation>[];
    }
    _ensureOwner(owner);
    final admitted = <V2TimConversation>[];
    for (final conversation in conversations) {
      final result = await _submitSdkConversationForDatabaseCommit(
        owner: owner,
        conversation: conversation,
        source: source,
        allowRecreate: allowRecreate,
      );
      if (result?.plan != null) {
        admitted.add(conversation);
      }
    }
    return admitted;
  }

  /// Builds authoritative Store commit plans for SDK-owned conversation rows.
  ///
  /// The legacy admission API remains available for the runtime kill switch,
  /// but production callers should consume these plans exactly once instead of
  /// performing a second direct upsert after coordinator admission.
  Future<List<ConversationSdkCommitCandidate>> prepareSdkConversationCommits({
    required String ownerUserId,
    required List<V2TimConversation> conversations,
    required ConversationMutationSource source,
    bool allowRecreate = false,
    Map<String, int> sourceVersionFloorByConversationId = const <String, int>{},
  }) async {
    if (!authoritativeSdkCommitEnabled || conversations.isEmpty) {
      return const <ConversationSdkCommitCandidate>[];
    }
    final owner = ownerUserId.trim();
    if (owner.isEmpty) {
      return const <ConversationSdkCommitCandidate>[];
    }
    _ensureOwner(owner);
    final commits = <ConversationSdkCommitCandidate>[];
    for (final conversation in conversations) {
      final result = await _submitSdkConversationForDatabaseCommit(
        owner: owner,
        conversation: conversation,
        source: source,
        allowRecreate: allowRecreate,
        sourceVersionFloor:
            sourceVersionFloorByConversationId[conversation.conversationID],
      );
      final plan = result?.plan;
      if (plan != null) {
        commits.add(
          ConversationSdkCommitCandidate(
            conversation: conversation,
            plan: plan,
          ),
        );
      }
    }
    return commits;
  }

  Future<List<String>> admitSdkDeletedForCommit({
    required String ownerUserId,
    required Iterable<String> conversationIds,
  }) async {
    final ids = conversationIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      return const <String>[];
    }
    if (!authoritativeSdkCommitEnabled) {
      observeSdkDeleted(
        ownerUserId: ownerUserId,
        conversationIds: ids,
      );
      return ids;
    }
    final owner = ownerUserId.trim();
    if (owner.isEmpty) {
      return const <String>[];
    }
    _ensureOwner(owner);
    final admitted = <String>[];
    for (final rawId in ids) {
      final type = _conversationTypeFromId(rawId);
      if (type == null) {
        continue;
      }
      final canonical = canonicalizeConversationMutationId(rawId, type);
      if (canonical.isEmpty) {
        continue;
      }
      final generation = (_conversationGenerations[canonical] ?? 0) + 1;
      _conversationGenerations[canonical] = generation;
      _tombstoned.add(canonical);
      final sequence = ++_eventSequence;
      final result = await _coordinator.submit(
        ConversationMutationEvent(
          eventId: 'sdk:$sequence:delete',
          ownerUserId: owner,
          conversationId: canonical,
          conversationType: type,
          kind: ConversationMutationKind.delete,
          source: ConversationMutationSource.sdkDelete,
          ownerGeneration: _ownerGeneration,
          conversationGeneration: generation,
          sourceVersion: sequence,
          values: const <ConversationMutationField, Object?>{},
        ),
      );
      if (result.disposition == ConversationMutationDisposition.applied) {
        admitted.add(rawId);
      }
    }
    return admitted;
  }

  Future<List<ConversationDatabaseCommitPlan<V2TimConversation>>>
      prepareSdkDeleteCommits({
    required String ownerUserId,
    required Iterable<String> conversationIds,
  }) async {
    if (!authoritativeSdkCommitEnabled) {
      return const <ConversationDatabaseCommitPlan<V2TimConversation>>[];
    }
    final owner = ownerUserId.trim();
    if (owner.isEmpty) {
      return const <ConversationDatabaseCommitPlan<V2TimConversation>>[];
    }
    _ensureOwner(owner);
    final plans = <ConversationDatabaseCommitPlan<V2TimConversation>>[];
    for (final raw in conversationIds) {
      final rawId = raw.trim();
      final type = _conversationTypeFromId(rawId);
      if (rawId.isEmpty || type == null) {
        continue;
      }
      final canonical = canonicalizeConversationMutationId(rawId, type);
      if (canonical.isEmpty) {
        continue;
      }
      final generation = (_conversationGenerations[canonical] ?? 0) + 1;
      _conversationGenerations[canonical] = generation;
      _tombstoned.add(canonical);
      final sequence = ++_eventSequence;
      final result =
          await _coordinator.submitForDatabaseCommit<V2TimConversation>(
        ConversationMutationEvent(
          eventId: 'sdk:$sequence:delete',
          ownerUserId: owner,
          conversationId: canonical,
          conversationType: type,
          kind: ConversationMutationKind.delete,
          source: ConversationMutationSource.sdkDelete,
          ownerGeneration: _ownerGeneration,
          conversationGeneration: generation,
          sourceVersion: sequence,
          values: const <ConversationMutationField, Object?>{},
        ),
      );
      final plan = result.plan;
      if (plan != null) {
        plans.add(plan);
      }
    }
    return plans;
  }

  /// Builds one typed local-intent plan. The Store remains the only place that
  /// interprets and persists [fieldPatch]; callers must not write the same
  /// field through a legacy Store API after consuming this plan.
  Future<ConversationDatabaseCommitPlan<V2TimConversation>?>
      prepareLocalIntentCommit({
    required String ownerUserId,
    required String conversationId,
    required Map<ConversationMutationField, Object?> fieldPatch,
    V2TimConversation? fullSnapshot,
    int? sourceVersion,
  }) {
    return prepareFieldPatchCommit(
      ownerUserId: ownerUserId,
      conversationId: conversationId,
      source: ConversationMutationSource.localIntent,
      fieldPatch: fieldPatch,
      fullSnapshot: fullSnapshot,
      sourceVersion: sourceVersion,
    );
  }

  Future<ConversationDatabaseCommitPlan<V2TimConversation>?>
      prepareFieldPatchCommit({
    required String ownerUserId,
    required String conversationId,
    required ConversationMutationSource source,
    required Map<ConversationMutationField, Object?> fieldPatch,
    V2TimConversation? fullSnapshot,
    int? sourceVersion,
  }) async {
    final owner = ownerUserId.trim();
    final rawId = conversationId.trim();
    final type = _conversationTypeFromId(rawId);
    if (owner.isEmpty || rawId.isEmpty || type == null || fieldPatch.isEmpty) {
      return null;
    }
    _ensureOwner(owner);
    final canonical = canonicalizeConversationMutationId(rawId, type);
    if (canonical.isEmpty) {
      return null;
    }
    final sequence = ++_eventSequence;
    final eventVersion = sourceVersion != null && sourceVersion > sequence
        ? sourceVersion
        : sequence;
    final result =
        await _coordinator.submitForDatabaseCommit<V2TimConversation>(
      ConversationMutationEvent(
        eventId: '${source.name}:$sequence:patch',
        ownerUserId: owner,
        conversationId: canonical,
        conversationType: type,
        kind: ConversationMutationKind.patch,
        source: source,
        ownerGeneration: _ownerGeneration,
        conversationGeneration: _conversationGenerations[canonical] ?? 0,
        sourceVersion: eventVersion,
        values: fieldPatch,
      ),
      fullSnapshot: fullSnapshot,
      fieldPatch: fieldPatch,
    );
    return result.plan;
  }

  void observeSdkConversations({
    required String ownerUserId,
    required List<V2TimConversation> conversations,
    required ConversationMutationSource source,
    bool allowRecreate = false,
  }) {
    if (!enabled || conversations.isEmpty) {
      return;
    }
    final owner = ownerUserId.trim();
    if (owner.isEmpty) {
      return;
    }
    _ensureOwner(owner);
    for (final conversation in conversations) {
      final type = _conversationType(conversation);
      if (type == null) {
        continue;
      }
      final canonical = canonicalizeConversationMutationId(
        conversation.conversationID,
        type,
      );
      if (canonical.isEmpty) {
        continue;
      }
      var generation = _conversationGenerations[canonical] ?? 0;
      var kind = ConversationMutationKind.upsert;
      if (allowRecreate && _tombstoned.remove(canonical)) {
        generation++;
        _conversationGenerations[canonical] = generation;
        kind = ConversationMutationKind.recreate;
      }
      final sequence = ++_eventSequence;
      final message = conversation.lastMessage;
      final messageVersion = _messageVersion(conversation, sequence);
      final conversationValues = <ConversationMutationField, Object?>{
        ConversationMutationField.unread: conversation.unreadCount ?? 0,
        ConversationMutationField.order: conversation.orderkey ?? 0,
        ConversationMutationField.pin: conversation.isPinned ?? false,
        if (message != null)
          ConversationMutationField.lastMessage: ConversationShadowLastMessage(
            messageId: (message.msgID ?? message.id ?? '').trim(),
            timestamp: message.timestamp ?? 0,
            status: message.status ?? 0,
            statusRank: GroupTipsMessageHelper.messageStatusRank(message.status),
            isSelf: message.isSelf == true,
            isPeerRead: message.isPeerRead == true,
            isRevoked: isRevokedMessage(message),
            isWeakCustom:
                ConversationLastMessagePrefer.isWeakCustomLastMessage(message),
            isSending: message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING,
            contentFingerprint: _messageContentFingerprint(message),
          ),
      };
      _enqueue(
        ConversationMutationEvent(
          eventId: 'sdk:$sequence:conversation',
          ownerUserId: owner,
          conversationId: canonical,
          conversationType: type,
          kind: kind,
          source: source,
          ownerGeneration: _ownerGeneration,
          conversationGeneration: generation,
          sourceVersion: sequence,
          fieldVersions: <ConversationMutationField, int>{
            ConversationMutationField.lastMessage: messageVersion,
            ConversationMutationField.order: sequence,
          },
          values: conversationValues,
        ),
      );

      final metadata = <ConversationMutationField, Object?>{
        if ((conversation.showName?.trim().isNotEmpty ?? false))
          ConversationMutationField.name: conversation.showName!.trim(),
        if ((conversation.faceUrl?.trim().isNotEmpty ?? false))
          ConversationMutationField.avatar: conversation.faceUrl!.trim(),
      };
      if (metadata.isNotEmpty) {
        _enqueue(
          ConversationMutationEvent(
            eventId: 'sdk:$sequence:metadata',
            ownerUserId: owner,
            conversationId: canonical,
            conversationType: type,
            kind: ConversationMutationKind.patch,
            source: source,
            ownerGeneration: _ownerGeneration,
            conversationGeneration: generation,
            // Metadata sources are compared by authority before this sequence.
            sourceVersion: sequence,
            values: metadata,
          ),
        );
      }
    }
  }

  void observeSdkDeleted({
    required String ownerUserId,
    required Iterable<String> conversationIds,
  }) {
    if (!enabled) {
      return;
    }
    final owner = ownerUserId.trim();
    if (owner.isEmpty) {
      return;
    }
    _ensureOwner(owner);
    for (final rawId in conversationIds) {
      final type = _conversationTypeFromId(rawId);
      if (type == null) {
        continue;
      }
      final canonical = canonicalizeConversationMutationId(rawId, type);
      if (canonical.isEmpty) {
        continue;
      }
      final generation = (_conversationGenerations[canonical] ?? 0) + 1;
      _conversationGenerations[canonical] = generation;
      _tombstoned.add(canonical);
      final sequence = ++_eventSequence;
      _enqueue(
        ConversationMutationEvent(
          eventId: 'sdk:$sequence:delete',
          ownerUserId: owner,
          conversationId: canonical,
          conversationType: type,
          kind: ConversationMutationKind.delete,
          source: ConversationMutationSource.sdkDelete,
          ownerGeneration: _ownerGeneration,
          conversationGeneration: generation,
          sourceVersion: sequence,
          values: const <ConversationMutationField, Object?>{},
        ),
      );
    }
  }

  Future<void> flush() => _pending;

  /// Compares only SDK-owned conversation fields. Draft, metadata, membership
  /// and pin are intentionally excluded until their local mutation sources are
  /// migrated into the coordinator.
  Future<List<ConversationShadowDifference>> compareLegacyProjection({
    required String ownerUserId,
    required List<V2TimConversation> conversations,
  }) async {
    if (!enabled || conversations.isEmpty) {
      return const <ConversationShadowDifference>[];
    }
    await flush();
    final differences = <ConversationShadowDifference>[];
    for (final conversation in conversations) {
      final type = _conversationType(conversation);
      if (type == null) {
        continue;
      }
      final snapshot = _coordinator.snapshot(
        ownerUserId: ownerUserId,
        conversationId: conversation.conversationID,
        conversationType: type,
      );
      if (snapshot == null || snapshot.deleted) {
        continue;
      }
      final fields = <ConversationMutationField>{};
      final expectedLast =
          snapshot.values[ConversationMutationField.lastMessage]
              as ConversationShadowLastMessage?;
      final actualLast = conversation.lastMessage;
      if (expectedLast != null &&
          (expectedLast.messageId !=
                  (actualLast?.msgID ?? actualLast?.id ?? '').trim() ||
              expectedLast.timestamp != (actualLast?.timestamp ?? 0) ||
              expectedLast.status != (actualLast?.status ?? 0) ||
              expectedLast.isPeerRead != (actualLast?.isPeerRead == true) ||
              expectedLast.contentFingerprint !=
                  _messageContentFingerprint(actualLast))) {
        fields.add(ConversationMutationField.lastMessage);
      }
      if (snapshot.values[ConversationMutationField.unread] !=
          (conversation.unreadCount ?? 0)) {
        fields.add(ConversationMutationField.unread);
      }
      if (snapshot.values[ConversationMutationField.order] !=
          (conversation.orderkey ?? 0)) {
        fields.add(ConversationMutationField.order);
      }
      if (fields.isNotEmpty) {
        differences.add(
          ConversationShadowDifference(
            canonicalConversationId: snapshot.canonicalConversationId,
            fields: Set<ConversationMutationField>.unmodifiable(fields),
          ),
        );
      }
    }
    _lastDifferences = List<ConversationShadowDifference>.unmodifiable(
      differences,
    );
    return _lastDifferences;
  }

  void clearSession() {
    final owner = _activeOwner;
    if (owner.isNotEmpty) {
      _coordinator.beginOwnerGeneration(owner);
    }
    _activeOwner = '';
    _ownerGeneration = 0;
    _conversationGenerations.clear();
    _tombstoned.clear();
    _lastDifferences = const <ConversationShadowDifference>[];
  }

  @visibleForTesting
  void resetForTest() {
    _coordinator = ConversationMutationCoordinator();
    _activeOwner = '';
    _ownerGeneration = 0;
    _eventSequence = 0;
    _conversationGenerations.clear();
    _tombstoned.clear();
    _pending = Future<void>.value();
    _lastDifferences = const <ConversationShadowDifference>[];
    enabled = true;
    authoritativeSdkCommitEnabled = true;
  }

  void _ensureOwner(String owner) {
    if (_activeOwner == owner && _ownerGeneration > 0) {
      return;
    }
    if (_activeOwner.isNotEmpty) {
      _coordinator.beginOwnerGeneration(_activeOwner);
    }
    _activeOwner = owner;
    _ownerGeneration = _coordinator.beginOwnerGeneration(owner);
    _conversationGenerations.clear();
    _tombstoned.clear();
  }

  void _enqueue(ConversationMutationEvent event) {
    _pending = _pending.then((_) async {
      await _coordinator.submit(event);
    }).catchError((Object _) {
      // Shadow comparison must never affect the authoritative legacy path.
    });
  }

  Future<ConversationMutationDatabaseResult<V2TimConversation>?>
      _submitSdkConversationForDatabaseCommit({
    required String owner,
    required V2TimConversation conversation,
    required ConversationMutationSource source,
    required bool allowRecreate,
    int? sourceVersionFloor,
  }) async {
    final type = _conversationType(conversation);
    if (type == null) {
      return null;
    }
    final canonical = canonicalizeConversationMutationId(
      conversation.conversationID,
      type,
    );
    if (canonical.isEmpty) {
      return null;
    }
    var generation = _conversationGenerations[canonical] ?? 0;
    var kind = ConversationMutationKind.upsert;
    if (allowRecreate && _tombstoned.remove(canonical)) {
      generation++;
      _conversationGenerations[canonical] = generation;
      kind = ConversationMutationKind.recreate;
    }
    final sequence = ++_eventSequence;
    final message = conversation.lastMessage;
    final rawMessageVersion = _messageVersion(conversation, sequence);
    final messageVersion =
        sourceVersionFloor != null && sourceVersionFloor > rawMessageVersion
            ? sourceVersionFloor
            : rawMessageVersion;
    final conversationValues = <ConversationMutationField, Object?>{
      ConversationMutationField.unread: conversation.unreadCount ?? 0,
      ConversationMutationField.order: conversation.orderkey ?? 0,
      ConversationMutationField.pin: conversation.isPinned ?? false,
      if (message != null)
        ConversationMutationField.lastMessage: ConversationShadowLastMessage(
          messageId: (message.msgID ?? message.id ?? '').trim(),
          timestamp: message.timestamp ?? 0,
          status: message.status ?? 0,
          statusRank: GroupTipsMessageHelper.messageStatusRank(message.status),
          isSelf: message.isSelf == true,
          isPeerRead: message.isPeerRead == true,
          isRevoked: isRevokedMessage(message),
          isWeakCustom:
              ConversationLastMessagePrefer.isWeakCustomLastMessage(message),
          isSending: message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING,
          contentFingerprint: _messageContentFingerprint(message),
        ),
    };
    final conversationResult =
        await _coordinator.submitForDatabaseCommit<V2TimConversation>(
      ConversationMutationEvent(
        eventId: 'sdk:$sequence:conversation',
        ownerUserId: owner,
        conversationId: canonical,
        conversationType: type,
        kind: kind,
        source: source,
        ownerGeneration: _ownerGeneration,
        conversationGeneration: generation,
        sourceVersion: sequence,
        fieldVersions: <ConversationMutationField, int>{
          ConversationMutationField.lastMessage: messageVersion,
          ConversationMutationField.order: sequence,
        },
        values: conversationValues,
      ),
      fullSnapshot: conversation,
      fieldPatch: conversationValues,
    );

    final metadata = <ConversationMutationField, Object?>{
      if ((conversation.showName?.trim().isNotEmpty ?? false))
        ConversationMutationField.name: conversation.showName!.trim(),
      if ((conversation.faceUrl?.trim().isNotEmpty ?? false))
        ConversationMutationField.avatar: conversation.faceUrl!.trim(),
    };
    if (metadata.isNotEmpty) {
      await _coordinator.submit(
        ConversationMutationEvent(
          eventId: 'sdk:$sequence:metadata',
          ownerUserId: owner,
          conversationId: canonical,
          conversationType: type,
          kind: ConversationMutationKind.patch,
          source: source,
          ownerGeneration: _ownerGeneration,
          conversationGeneration: generation,
          sourceVersion: sequence,
          values: metadata,
        ),
      );
    }
    return conversationResult;
  }

  static int _messageVersion(V2TimConversation conversation, int fallback) {
    final timestamp = conversation.lastMessage?.timestamp ?? 0;
    return timestamp > 0 ? timestamp : fallback;
  }

  static String _messageContentFingerprint(V2TimMessage? message) {
    if (message == null) {
      return '';
    }
    return <Object?>[
      message.elemType,
      message.textElem?.text ?? '',
      message.customElem?.data ?? '',
      message.customElem?.desc ?? '',
      message.customElem?.extension ?? '',
      message.faceElem?.data ?? '',
      message.sender ?? '',
      message.nickName ?? '',
      message.nameCard ?? '',
      message.groupID ?? '',
      message.cloudCustomData ?? '',
      message.localCustomData ?? '',
      if (message.groupTipsElem != null)
        jsonEncode(message.groupTipsElem!.toJson()),
    ].join('\u001f');
  }

  static ConversationMutationConversationType? _conversationType(
    V2TimConversation conversation,
  ) {
    if (conversation.type == ConversationType.V2TIM_C2C) {
      return ConversationMutationConversationType.c2c;
    }
    if (conversation.type == ConversationType.V2TIM_GROUP) {
      return ConversationMutationConversationType.group;
    }
    return _conversationTypeFromId(conversation.conversationID);
  }

  static ConversationMutationConversationType? _conversationTypeFromId(
    String rawId,
  ) {
    if (MessageConversationId.looksLikeC2cConversationId(rawId)) {
      return ConversationMutationConversationType.c2c;
    }
    if (MessageConversationId.looksLikeGroupConversationId(rawId)) {
      return ConversationMutationConversationType.group;
    }
    return null;
  }
}
