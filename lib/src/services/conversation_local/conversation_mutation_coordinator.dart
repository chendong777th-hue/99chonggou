import 'dart:async';

import 'conversation_field_authority.dart';
import 'conversation_mutation_event.dart';

enum ConversationMutationDisposition {
  applied,
  ignoredDuplicate,
  rejectedEmptyIdentity,
  rejectedStaleOwner,
  rejectedStaleConversation,
  rejectedByTombstone,
  ignoredLowerAuthority,
}

enum ConversationDatabaseChangeType { upsert, delete }

enum ConversationDatabaseCommitDisposition {
  applied,
  ignoredDuplicate,
  rejectedEmptyIdentity,
  rejectedStaleGeneration,
  rejectedByTombstone,
  rejectedMissingSnapshot,
  noop,
}

class ConversationMutationResult {
  const ConversationMutationResult({
    required this.disposition,
    required this.canonicalConversationId,
    this.changedFields = const <ConversationMutationField>{},
  });

  final ConversationMutationDisposition disposition;
  final String canonicalConversationId;
  final Set<ConversationMutationField> changedFields;
}

class ConversationDatabaseCommitPlan<TSnapshot> {
  const ConversationDatabaseCommitPlan({
    required this.ownerUserId,
    required this.canonicalConversationId,
    required this.conversationType,
    required this.changeType,
    required this.generation,
    required this.tombstone,
    required this.idempotencyKey,
    required this.recreatesDeletedConversation,
    this.fieldPatch = const <ConversationMutationField, Object?>{},
    this.fullSnapshot,
  });

  final String ownerUserId;
  final String canonicalConversationId;
  final ConversationMutationConversationType conversationType;
  final ConversationDatabaseChangeType changeType;
  final int generation;
  final bool tombstone;
  final String idempotencyKey;
  final bool recreatesDeletedConversation;
  final Map<ConversationMutationField, Object?> fieldPatch;
  final TSnapshot? fullSnapshot;
}

class ConversationMutationDatabaseResult<TSnapshot> {
  const ConversationMutationDatabaseResult({
    required this.mutationResult,
    this.plan,
  });

  final ConversationMutationResult mutationResult;
  final ConversationDatabaseCommitPlan<TSnapshot>? plan;

  bool get hasCommitPlan => plan != null;
}

class ConversationDatabaseCommitResult<TSnapshot> {
  ConversationDatabaseCommitResult({
    required this.disposition,
    required this.plan,
    List<TSnapshot>? upsertedSnapshots,
    List<String>? deletedConversationIds,
    this.shouldNotifyUi = false,
  })  : upsertedSnapshots = upsertedSnapshots ?? <TSnapshot>[],
        deletedConversationIds = deletedConversationIds ?? <String>[];

  final ConversationDatabaseCommitDisposition disposition;
  final ConversationDatabaseCommitPlan<TSnapshot> plan;
  final List<TSnapshot> upsertedSnapshots;
  final List<String> deletedConversationIds;
  final bool shouldNotifyUi;

  ConversationUiSnapshotBatch<TSnapshot> get uiBatch =>
      ConversationUiSnapshotBatch<TSnapshot>(
        upsertedSnapshots: upsertedSnapshots,
        deletedCanonicalIds: deletedConversationIds,
        structureChanged: deletedConversationIds.isNotEmpty ||
            plan.fieldPatch.containsKey(ConversationMutationField.pin) ||
            plan.fieldPatch.containsKey(ConversationMutationField.order) ||
            plan.recreatesDeletedConversation,
        changedFieldMasks: <String, Set<ConversationMutationField>>{
          if (plan.fieldPatch.isNotEmpty)
            plan.canonicalConversationId:
                Set<ConversationMutationField>.unmodifiable(
              plan.fieldPatch.keys,
            ),
        },
        commitGeneration: plan.generation,
      );
}

class ConversationUiSnapshotBatch<TSnapshot> {
  ConversationUiSnapshotBatch({
    required Iterable<TSnapshot> upsertedSnapshots,
    required Iterable<String> deletedCanonicalIds,
    required this.structureChanged,
    required Map<String, Set<ConversationMutationField>> changedFieldMasks,
    required this.commitGeneration,
    Iterable<ConversationUiUnreadDelta> unreadDeltas = const [],
    Iterable<ConversationUiMove> moves = const [],
    this.unreadProjectionComplete,
  })  : upsertedSnapshots = List<TSnapshot>.unmodifiable(upsertedSnapshots),
        deletedCanonicalIds = List<String>.unmodifiable(deletedCanonicalIds),
        unreadDeltas = List<ConversationUiUnreadDelta>.unmodifiable(
          unreadDeltas,
        ),
        moves = List<ConversationUiMove>.unmodifiable(moves),
        changedFieldMasks =
            Map<String, Set<ConversationMutationField>>.unmodifiable(
                changedFieldMasks);

  final List<TSnapshot> upsertedSnapshots;
  final List<String> deletedCanonicalIds;
  final bool structureChanged;
  final Map<String, Set<ConversationMutationField>> changedFieldMasks;
  final int commitGeneration;
  final List<ConversationUiUnreadDelta> unreadDeltas;
  final List<ConversationUiMove> moves;
  /// Null keeps legacy UI-derived behavior during staged rollout.
  final bool? unreadProjectionComplete;

  bool get isEmpty => upsertedSnapshots.isEmpty && deletedCanonicalIds.isEmpty;
}

class ConversationUiMove {
  const ConversationUiMove({
    required this.conversationID,
    required this.convType,
    required this.oldIndex,
    required this.newIndex,
    required this.reason,
  });

  final String conversationID;
  final int convType;
  final int oldIndex;
  final int newIndex;
  final String reason;
}

class ConversationUiUnreadDelta {
  const ConversationUiUnreadDelta({
    required this.isGroup,
    required this.oldNotifiable,
    required this.newNotifiable,
  });

  final bool isGroup;
  final int oldNotifiable;
  final int newNotifiable;
}

class ConversationShadowSnapshot {
  const ConversationShadowSnapshot({
    required this.ownerUserId,
    required this.canonicalConversationId,
    required this.conversationGeneration,
    required this.values,
    required this.deleted,
    required this.fieldSources,
    required this.fieldVersions,
  });

  final String ownerUserId;
  final String canonicalConversationId;
  final int conversationGeneration;
  final Map<ConversationMutationField, Object?> values;
  final bool deleted;
  final Map<ConversationMutationField, ConversationMutationSource>
      fieldSources;
  final Map<ConversationMutationField, int> fieldVersions;
}

class _FieldStamp {
  const _FieldStamp({
    required this.version,
    required this.source,
    required this.eventId,
  });

  final int version;
  final ConversationMutationSource source;
  final String eventId;
}

class _ShadowState {
  _ShadowState({
    required this.ownerUserId,
    required this.canonicalConversationId,
  });

  final String ownerUserId;
  final String canonicalConversationId;
  int conversationGeneration = 0;
  int? tombstoneGeneration;
  final Map<ConversationMutationField, Object?> values =
      <ConversationMutationField, Object?>{};
  final Map<ConversationMutationField, _FieldStamp> stamps =
      <ConversationMutationField, _FieldStamp>{};
  final Set<String> appliedEventIds = <String>{};
}

/// Phase-1/2 shadow coordinator.
///
/// It serializes mutations per logical conversation and computes the intended
/// field projection, but intentionally has no database or UI dependency. Until
/// the cutover phase, callers must use it only for tests and shadow comparison.
class ConversationMutationCoordinator {
  ConversationMutationCoordinator({this.shadowOnly = true});

  final bool shadowOnly;
  final Map<String, Future<void>> _tails = <String, Future<void>>{};
  final Map<String, _ShadowState> _states = <String, _ShadowState>{};
  final Map<String, int> _ownerGenerations = <String, int>{};

  Future<ConversationMutationResult> submit(
    ConversationMutationEvent event,
  ) {
    return _submitQueued(event, _reduce);
  }

  Future<ConversationMutationDatabaseResult<TSnapshot>>
      submitForDatabaseCommit<TSnapshot>(
    ConversationMutationEvent event, {
    TSnapshot? fullSnapshot,
    Map<ConversationMutationField, Object?>? fieldPatch,
  }) async {
    final mutationResult = await _submitQueued(event, _reduce);
    final plan = _databasePlanFor(
      event,
      mutationResult,
      fullSnapshot: fullSnapshot,
      fieldPatch: fieldPatch,
    );
    return ConversationMutationDatabaseResult<TSnapshot>(
      mutationResult: mutationResult,
      plan: plan,
    );
  }

  Future<T> _submitQueued<T>(
    ConversationMutationEvent event,
    T Function(ConversationMutationEvent event, String canonicalId) reduce,
  ) {
    final canonicalId = event.canonicalConversationId;
    if (canonicalId.isEmpty || event.ownerUserId.trim().isEmpty) {
      return Future<T>.value(
        reduce(
          event,
          canonicalId,
        ),
      );
    }
    final queueKey = '${event.ownerUserId.trim()}::$canonicalId';
    final completer = Completer<T>();
    final previous = _tails[queueKey] ?? Future<void>.value();
    late final Future<void> next;
    next = previous.then((_) {
      completer.complete(reduce(event, canonicalId));
    }).catchError((Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }).whenComplete(() {
      if (identical(_tails[queueKey], next)) {
        _tails.remove(queueKey);
      }
    });
    _tails[queueKey] = next;
    return completer.future;
  }

  ConversationMutationResult _reduceForEmptyIdentity(
    String canonicalId,
  ) {
    return ConversationMutationResult(
      disposition: ConversationMutationDisposition.rejectedEmptyIdentity,
      canonicalConversationId: canonicalId,
    );
  }

  int beginOwnerGeneration(String ownerUserId) {
    final owner = ownerUserId.trim();
    final next = (_ownerGenerations[owner] ?? 0) + 1;
    _ownerGenerations[owner] = next;
    _states.removeWhere((key, _) => key.startsWith('$owner::'));
    return next;
  }

  int ownerGeneration(String ownerUserId) =>
      _ownerGenerations[ownerUserId.trim()] ?? 0;

  ConversationShadowSnapshot? snapshot({
    required String ownerUserId,
    required String conversationId,
    required ConversationMutationConversationType conversationType,
  }) {
    final canonical = canonicalizeConversationMutationId(
      conversationId,
      conversationType,
    );
    final state = _states['${ownerUserId.trim()}::$canonical'];
    if (state == null) {
      return null;
    }
    return ConversationShadowSnapshot(
      ownerUserId: state.ownerUserId,
      canonicalConversationId: state.canonicalConversationId,
      conversationGeneration: state.conversationGeneration,
      values:
          Map<ConversationMutationField, Object?>.unmodifiable(state.values),
      deleted: state.tombstoneGeneration != null,
      fieldSources: Map<ConversationMutationField,
          ConversationMutationSource>.unmodifiable(
        <ConversationMutationField, ConversationMutationSource>{
          for (final entry in state.stamps.entries)
            entry.key: entry.value.source,
        },
      ),
      fieldVersions: Map<ConversationMutationField, int>.unmodifiable(
        <ConversationMutationField, int>{
          for (final entry in state.stamps.entries)
            entry.key: entry.value.version,
        },
      ),
    );
  }

  ConversationMutationResult _reduce(
    ConversationMutationEvent event,
    String canonicalId,
  ) {
    if (canonicalId.isEmpty || event.ownerUserId.trim().isEmpty) {
      return _reduceForEmptyIdentity(canonicalId);
    }
    final owner = event.ownerUserId.trim();
    final activeOwnerGeneration = _ownerGenerations[owner] ?? 0;
    if (event.ownerGeneration != activeOwnerGeneration) {
      return ConversationMutationResult(
        disposition: ConversationMutationDisposition.rejectedStaleOwner,
        canonicalConversationId: canonicalId,
      );
    }
    final key = '$owner::$canonicalId';
    final state = _states.putIfAbsent(
      key,
      () => _ShadowState(
        ownerUserId: owner,
        canonicalConversationId: canonicalId,
      ),
    );
    if (!state.appliedEventIds.add(event.eventId)) {
      return ConversationMutationResult(
        disposition: ConversationMutationDisposition.ignoredDuplicate,
        canonicalConversationId: canonicalId,
      );
    }
    if (event.conversationGeneration < state.conversationGeneration) {
      return ConversationMutationResult(
        disposition: ConversationMutationDisposition.rejectedStaleConversation,
        canonicalConversationId: canonicalId,
      );
    }

    if (event.kind == ConversationMutationKind.delete) {
      state
        ..conversationGeneration = event.conversationGeneration
        ..tombstoneGeneration = event.conversationGeneration
        ..values.clear()
        ..stamps.clear();
      return ConversationMutationResult(
        disposition: ConversationMutationDisposition.applied,
        canonicalConversationId: canonicalId,
      );
    }

    final tombstoneGeneration = state.tombstoneGeneration;
    if (tombstoneGeneration != null) {
      final canRecreate = event.kind == ConversationMutationKind.recreate &&
          event.conversationGeneration > tombstoneGeneration;
      if (!canRecreate) {
        return ConversationMutationResult(
          disposition: ConversationMutationDisposition.rejectedByTombstone,
          canonicalConversationId: canonicalId,
        );
      }
      state
        ..tombstoneGeneration = null
        ..conversationGeneration = event.conversationGeneration;
    } else if (event.conversationGeneration > state.conversationGeneration) {
      state.conversationGeneration = event.conversationGeneration;
    }

    final changed = <ConversationMutationField>{};
    for (final entry in event.values.entries) {
      final authority =
          ConversationFieldAuthority.rank(entry.key, event.source);
      if (authority <= 0) {
        continue;
      }
      final previous = state.stamps[entry.key];
      final previousValue = state.values[entry.key];
      final incomingVersion = event.versionFor(entry.key);
      final shouldApply = entry.key == ConversationMutationField.lastMessage
          ? _prefersIncomingLastMessage(
              incoming: entry.value,
              incomingSource: event.source,
              existing: state.values[entry.key],
              existingSource: previous?.source,
              conversationType: event.conversationType,
            )
          : previous == null ||
              ConversationFieldAuthority.prefersIncoming(
                field: entry.key,
                incomingSource: event.source,
                incomingVersion: incomingVersion,
                existingSource: previous.source,
                existingVersion: previous.version,
              );
      if (!shouldApply) {
        continue;
      }
      final valueChanged = previous == null || previousValue != entry.value;
      state.values[entry.key] = entry.value;
      state.stamps[entry.key] = _FieldStamp(
        version: incomingVersion,
        source: event.source,
        eventId: event.eventId,
      );
      if (valueChanged) {
        changed.add(entry.key);
      }
    }
    return ConversationMutationResult(
      disposition: changed.isEmpty
          ? ConversationMutationDisposition.ignoredLowerAuthority
          : ConversationMutationDisposition.applied,
      canonicalConversationId: canonicalId,
      changedFields: changed,
    );
  }

  bool _prefersIncomingLastMessage({
    required Object? incoming,
    required ConversationMutationSource incomingSource,
    required Object? existing,
    required ConversationMutationSource? existingSource,
    required ConversationMutationConversationType conversationType,
  }) {
    if (incoming is! ConversationShadowLastMessage) {
      return false;
    }
    if (existing is! ConversationShadowLastMessage) {
      return true;
    }
    final sameId = incoming.messageId.isNotEmpty &&
        incoming.messageId == existing.messageId;
    if (sameId) {
      if (incoming.isRevoked != existing.isRevoked) {
        return incoming.isRevoked;
      }
      if (incoming.statusRank != existing.statusRank) {
        return incoming.statusRank > existing.statusRank;
      }
      if (incoming.isPeerRead != existing.isPeerRead) {
        return incoming.isPeerRead;
      }
      if (incoming.contentFingerprint != existing.contentFingerprint) {
        if (incoming.isWeakCustom && !existing.isWeakCustom) {
          return false;
        }
        if (existingSource == null) {
          return true;
        }
        return ConversationFieldAuthority.rank(
              ConversationMutationField.lastMessage,
              incomingSource,
            ) >=
            ConversationFieldAuthority.rank(
              ConversationMutationField.lastMessage,
              existingSource,
            );
      }
      return existingSource == null ||
          ConversationFieldAuthority.rank(
                ConversationMutationField.lastMessage,
                incomingSource,
              ) >
              ConversationFieldAuthority.rank(
                ConversationMutationField.lastMessage,
                existingSource,
              );
    }
    if (incoming.timestamp != existing.timestamp) {
      return incoming.timestamp > existing.timestamp;
    }
    if (incoming.isWeakCustom && !existing.isWeakCustom) {
      return false;
    }
    if (incoming.isSelf && incoming.isSending) {
      return true;
    }
    if (conversationType == ConversationMutationConversationType.group) {
      if (incoming.sequence > 0 && existing.sequence > 0) {
        return incoming.sequence > existing.sequence;
      }
      if (incoming.sequence > 0 && existing.sequence <= 0) {
        return true;
      }
      if (existing.sequence > 0 && incoming.sequence <= 0) {
        return false;
      }
    }
    // Different same-second messages without a comparable group sequence are
    // unordered. Preserve the committed preview instead of using arrival time.
    return false;
  }

  ConversationDatabaseCommitPlan<TSnapshot>? _databasePlanFor<TSnapshot>(
    ConversationMutationEvent event,
    ConversationMutationResult result, {
    required TSnapshot? fullSnapshot,
    required Map<ConversationMutationField, Object?>? fieldPatch,
  }) {
    if (result.disposition != ConversationMutationDisposition.applied) {
      return null;
    }
    final changeType = event.kind == ConversationMutationKind.delete
        ? ConversationDatabaseChangeType.delete
        : ConversationDatabaseChangeType.upsert;
    return ConversationDatabaseCommitPlan<TSnapshot>(
      ownerUserId: event.ownerUserId.trim(),
      canonicalConversationId: result.canonicalConversationId,
      conversationType: event.conversationType,
      changeType: changeType,
      generation: event.conversationGeneration,
      tombstone: changeType == ConversationDatabaseChangeType.delete,
      idempotencyKey: event.eventId,
      recreatesDeletedConversation:
          event.kind == ConversationMutationKind.recreate,
      fieldPatch: Map<ConversationMutationField, Object?>.unmodifiable(
        <ConversationMutationField, Object?>{
          for (final field in result.changedFields)
            if ((fieldPatch ?? event.values).containsKey(field))
              field: (fieldPatch ?? event.values)[field],
        },
      ),
      fullSnapshot: fullSnapshot,
    );
  }
}
