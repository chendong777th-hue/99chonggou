import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_persistence.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/tencent_message_adapter.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_priority_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';

class ImCoordinatedSendResult {
  const ImCoordinatedSendResult({
    required this.sdkResult,
    required this.usedOutbox,
    this.identity,
    this.accountGeneration,
    this.domainGeneration,
    this.dispatchDecision,
    this.outcomeUnknown = false,
  });

  final V2TimValueCallback<V2TimMessage> sdkResult;
  final bool usedOutbox;
  final OutgoingIdentityContract? identity;
  final int? accountGeneration;
  final int? domainGeneration;
  final ImOutboxDispatchDecision? dispatchDecision;
  final bool outcomeUnknown;

  bool get canCompleteProjection =>
      usedOutbox && identity != null && sdkResult.code == 0;
}

class ImOutgoingSendCoordinator {
  ImOutgoingSendCoordinator._();

  static final ImOutgoingSendCoordinator instance =
      ImOutgoingSendCoordinator._();

  int _transientIngressSequence = 0;
  int _sendOperationGeneration = 0;

  Future<ImCoordinatedSendResult> send({
    required MessageService messageService,
    required String sdkLocalId,
    required String conversationId,
    required ImConversationType conversationType,
    required String receiver,
    required String groupID,
    V2TimMessage? fallbackMessage,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool onlineUserOnly = false,
    bool isExcludedFromUnreadCount = false,
    bool needReadReceipt = false,
    OfflinePushInfo? offlinePushInfo,
    String? businessCloudCustomData,
    String? localCustomData,
    bool isExcludedFromContentModeration = false,
    bool persistOutbox = true,
    bool recoverPreparedOutbox = false,
    void Function(String syncMsgID)? onSyncMsgID,
  }) async {
    final localId = sdkLocalId.trim();
    if (localId.isEmpty) {
      return _blocked(
        fallbackMessage: fallbackMessage,
        desc: 'sdkLocalId is required',
      );
    }
    final context = await ConversationSyncService.instance
        .messageCoreLeaseForOutgoingSend();
    if (context == null) {
      return _blocked(
        fallbackMessage: fallbackMessage,
        desc: 'message core lease unavailable',
      );
    }
    final scope = AccountScopedConversationKey.tryParse(
      ownerUserId: context.ownerUserId,
      conversationType: conversationType,
      conversationId: conversationId,
    );
    if (scope == null) {
      return _blocked(
        fallbackMessage: fallbackMessage,
        desc: 'invalid outgoing conversation scope',
      );
    }

    if (recoverPreparedOutbox && !persistOutbox) {
      return _blocked(
        fallbackMessage: fallbackMessage,
        desc: 'prepared recovery requires durable Outbox',
      );
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final persistence = Im05Persistence(store: context.store);
    final operationId = _operationId(scope: scope, sdkLocalId: localId);
    final clientCorrelationId = _clientCorrelationId(localId);
    ImOutboxDispatchAssessment? recoveredPrepared;
    if (recoverPreparedOutbox) {
      recoveredPrepared = await persistence.assessOutboxForDispatch(
        ownerUserId: context.ownerUserId,
        operationId: operationId,
        leaseOwnerId: context.lease.leaseOwnerId,
        fencingToken: context.lease.fencingToken,
        nowMs: nowMs,
      );
      final recoveredMain = recoveredPrepared.main;
      if (!recoveredPrepared.canDispatch ||
          recoveredMain == null ||
          recoveredMain.state != ImOutboxState.prepared ||
          recoveredMain.operationId != operationId ||
          recoveredMain.clientCorrelationId != clientCorrelationId ||
          recoveredMain.conversationId != scope.storageKey) {
        return _blocked(
          fallbackMessage: fallbackMessage,
          usedOutbox: true,
          decision: recoveredPrepared.decision,
          outcomeUnknown: recoveredPrepared.requiresOutcomeQuery,
          desc: 'prepared Outbox recovery identity rejected',
        );
      }
    }
    final messageKind = _messageKindFor(fallbackMessage?.elemType);
    final payloadEnvelope = recoveredPrepared?.main?.payloadReference ??
        _encodeOutgoingEnvelope(
          message: fallbackMessage,
          sdkLocalId: localId,
          conversationId: conversationId,
          receiver: receiver,
          groupID: groupID,
          priority: priority,
          onlineUserOnly: onlineUserOnly,
          isExcludedFromUnreadCount: isExcludedFromUnreadCount,
          needReadReceipt: needReadReceipt,
          offlinePushInfo: offlinePushInfo,
          businessCloudCustomData: businessCloudCustomData,
          localCustomData: localCustomData,
          isExcludedFromContentModeration: isExcludedFromContentModeration,
        );
    if (persistOutbox && payloadEnvelope == null) {
      return _blocked(
        fallbackMessage: fallbackMessage,
        desc: 'durable outgoing payload is unavailable',
      );
    }
    final payloadFingerprint = sha256
        .convert(utf8.encode(payloadEnvelope ?? 'sdkLocalId:$localId'))
        .toString();
    if (recoveredPrepared != null &&
        recoveredPrepared.main!.payloadHash != payloadFingerprint) {
      return _blocked(
        fallbackMessage: fallbackMessage,
        usedOutbox: true,
        decision: ImOutboxDispatchDecision.identityConflict,
        desc: 'prepared Outbox payload fingerprint rejected',
      );
    }
    final identity = OutgoingIdentityContract(
      scope: scope,
      operationId: operationId,
      clientCorrelationId: clientCorrelationId,
      messageKind: messageKind,
      payloadFingerprint: payloadFingerprint,
      createdAtMs: recoveredPrepared?.main?.createdAtMs ?? nowMs,
      sdkLocalId: localId,
    );
    final sendGeneration = ++_sendOperationGeneration;

    if (persistOutbox) {
      final main = ImOutboxRecord(
        operationId: identity.operationId,
        ownerUserId: context.ownerUserId,
        conversationId: scope.storageKey,
        clientCorrelationId: identity.clientCorrelationId,
        messageType: fallbackMessage?.elemType ?? messageKind.index,
        payloadReference: payloadEnvelope!,
        mediaLocalRef: _mediaLocalReference(fallbackMessage),
        payloadHash: identity.payloadFingerprint,
        contentChecksum: identity.payloadFingerprint,
        sdkMessageId: localId,
        state: ImOutboxState.prepared,
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      );
      final recovery = ImOutboxRecoveryRecord(
        ownerUserId: context.ownerUserId,
        operationId: identity.operationId,
        clientCorrelationId: identity.clientCorrelationId,
        conversationId: scope.storageKey,
        messageType: main.messageType,
        recoveryRevision: 1,
        state: ImOutboxCopyState.copyPrepared,
        payloadReferenceOrCiphertext: payloadEnvelope,
        payloadHash: identity.payloadFingerprint,
        checksum: identity.payloadFingerprint,
        sdkLocalId: localId,
        updatedAtMs: nowMs,
      );
      final prepared = recoveredPrepared ??
          await persistence.prepareOutbox(
            main: main,
            recoveryCopy: recovery,
            leaseOwnerId: context.lease.leaseOwnerId,
            fencingToken: context.lease.fencingToken,
            nowMs: nowMs,
          );
      if (!prepared.canDispatch) {
        return _blocked(
          fallbackMessage: fallbackMessage,
          identity: identity,
          usedOutbox: true,
          decision: prepared.decision,
          outcomeUnknown: prepared.requiresOutcomeQuery,
          desc: 'outbox dispatch rejected: ${prepared.decision.name}',
        );
      }
      final dispatch = await persistence.recordDispatchIntent(
        ownerUserId: context.ownerUserId,
        operationId: identity.operationId,
        dispatchAttemptId:
            'attempt:${identity.operationId}:$sendGeneration:$nowMs',
        leaseOwnerId: context.lease.leaseOwnerId,
        fencingToken: context.lease.fencingToken,
        nowMs: nowMs,
      );
      if (!dispatch.canDispatch || dispatch.main == null) {
        return _blocked(
          fallbackMessage: fallbackMessage,
          identity: identity,
          usedOutbox: true,
          decision: dispatch.decision,
          outcomeUnknown: dispatch.requiresOutcomeQuery,
          desc: 'outbox dispatch rejected: ${dispatch.decision.name}',
        );
      }
      final sending = await persistence.transitionOutbox(
        next: dispatch.main!.copyWith(
          state: ImOutboxState.sending,
          sdkMessageId: localId,
        ),
        expectedState: ImOutboxState.dispatchIntent,
        leaseOwnerId: context.lease.leaseOwnerId,
        fencingToken: context.lease.fencingToken,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      if (sending == null) {
        return _blocked(
          fallbackMessage: fallbackMessage,
          identity: identity,
          usedOutbox: true,
          decision: ImOutboxDispatchDecision.fencingRejected,
          desc: 'outbox sending transition rejected',
        );
      }
    }

    final adapter = TencentMessageAdapter(
      port: TUIKitMessageServicePort(messageService),
      platform: ImPlatform.unknown,
      ownerUserId: context.ownerUserId,
      accountGeneration: context.accountGeneration,
      domainGeneration: context.domainGeneration,
      nextAccountIngressSequence: _nextTransientIngressSequence,
      nextScopeIngressSequence: (_) => _nextTransientIngressSequence(),
      onSyncIdentity: (event) {
        final serverId = event.payload?.serverMsgId?.trim() ?? '';
        if (serverId.isNotEmpty) {
          onSyncMsgID?.call(serverId);
        }
      },
    );
    final sdk = await adapter.send(
      identity: identity,
      sdkLocalId: localId,
      receiver: receiver,
      groupID: groupID,
      sendOperationGeneration: sendGeneration,
      priority: priority,
      onlineUserOnly: onlineUserOnly,
      isExcludedFromUnreadCount: isExcludedFromUnreadCount,
      needReadReceipt: needReadReceipt,
      offlinePushInfo: offlinePushInfo,
      businessCloudCustomData: businessCloudCustomData,
      localCustomData: localCustomData,
      isExcludedFromContentModeration: isExcludedFromContentModeration,
    );

    final formalIdentity = sdk.data?.identity ?? identity;
    var callback = V2TimValueCallback<V2TimMessage>(
      code: sdk.code ?? (sdk.isSuccess ? 0 : -1),
      desc: sdk.resultDesc ?? '',
      data: sdk.data?.message ?? fallbackMessage,
    );
    var providerConfirmed = false;
    if (persistOutbox) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (sdk.isSuccess) {
        await persistence.recordOutboxSdkSucceeded(
          ownerUserId: context.ownerUserId,
          operationId: identity.operationId,
          leaseOwnerId: context.lease.leaseOwnerId,
          fencingToken: context.lease.fencingToken,
          nowMs: now,
          sdkLocalId: localId,
          serverMsgId: formalIdentity.serverMsgId,
          resultCode: '${callback.code}',
        );
      } else if (sdk.isOutcomeUnknown) {
        final recorded = await persistence.recordOutcomeUnknown(
          ownerUserId: context.ownerUserId,
          operationId: identity.operationId,
          leaseOwnerId: context.lease.leaseOwnerId,
          fencingToken: context.lease.fencingToken,
          nowMs: now,
          resultCode: '${callback.code}',
        );
        if (!recorded) {
          providerConfirmed = await _providerAlreadyConfirmed(
            persistence,
            ownerUserId: context.ownerUserId,
            operationId: identity.operationId,
          );
        }
      } else {
        final recorded = await persistence.recordOutboxSdkFailed(
          ownerUserId: context.ownerUserId,
          operationId: identity.operationId,
          leaseOwnerId: context.lease.leaseOwnerId,
          fencingToken: context.lease.fencingToken,
          nowMs: now,
          sdkLocalId: localId,
          serverMsgId: formalIdentity.serverMsgId,
          resultCode: '${callback.code}',
        );
        if (!recorded) {
          providerConfirmed = await _providerAlreadyConfirmed(
            persistence,
            ownerUserId: context.ownerUserId,
            operationId: identity.operationId,
          );
        }
      }
    }
    if (providerConfirmed) {
      callback = V2TimValueCallback<V2TimMessage>(
        code: 0,
        desc: 'provider evidence confirmed delivery',
        data: sdk.data?.message ?? fallbackMessage,
      );
    }
    return ImCoordinatedSendResult(
      sdkResult: callback,
      usedOutbox: persistOutbox,
      identity: formalIdentity,
      accountGeneration: context.accountGeneration,
      domainGeneration: context.domainGeneration,
      outcomeUnknown: sdk.isOutcomeUnknown && !providerConfirmed,
    );
  }

  Future<bool> completeSuccessfulProjection(
    ImCoordinatedSendResult result,
  ) async {
    final identity = result.identity;
    if (!result.canCompleteProjection || identity == null) return false;
    final context = await ConversationSyncService.instance
        .messageCoreLeaseForOutgoingSend();
    if (context == null ||
        context.ownerUserId != identity.scope.ownerUserId ||
        context.accountGeneration != result.accountGeneration ||
        context.domainGeneration != result.domainGeneration) {
      return false;
    }
    return Im05Persistence(store: context.store).completeOutboxProjection(
      ownerUserId: context.ownerUserId,
      operationId: identity.operationId,
      leaseOwnerId: context.lease.leaseOwnerId,
      fencingToken: context.lease.fencingToken,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Reconciles durable unknown sends from an already-committed history page.
  /// Only self messages carrying the exact outgoing identity envelope can
  /// advance an Outbox row.
  Future<int> adoptProviderHistory(
    Iterable<V2TimMessage> messages,
  ) async {
    final context = await ConversationSyncService.instance
        .messageCoreLeaseForOutgoingSend();
    if (context == null) return 0;
    final persistence = Im05Persistence(store: context.store);
    var adoptedCount = 0;
    for (final message in messages) {
      if (message.isSelf != true) continue;
      final conversationId = MessageConversationId.fromMessage(
        message,
        loginUserId: context.ownerUserId,
      );
      if (conversationId == null) continue;
      final scope = AccountScopedConversationKey.tryParse(
        ownerUserId: context.ownerUserId,
        conversationType: conversationId.startsWith('group_')
            ? ImConversationType.group
            : ImConversationType.c2c,
        conversationId: conversationId,
      );
      if (scope == null) continue;
      final outgoing = OutgoingIdentityContract.fromCloudCustomData(
        message.cloudCustomData,
        scope: scope,
      );
      if (outgoing == null) continue;
      final adopted = await persistence.adoptOutboxProviderSucceeded(
        ownerUserId: context.ownerUserId,
        operationId: outgoing.operationId,
        clientCorrelationId: outgoing.clientCorrelationId,
        conversationId: scope.storageKey,
        payloadHash: outgoing.payloadFingerprint,
        leaseOwnerId: context.lease.leaseOwnerId,
        fencingToken: context.lease.fencingToken,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        sdkLocalId: message.id,
        serverMsgId: message.msgID,
      );
      if (!adopted) continue;
      final completed = await persistence.completeOutboxProjection(
        ownerUserId: context.ownerUserId,
        operationId: outgoing.operationId,
        leaseOwnerId: context.lease.leaseOwnerId,
        fencingToken: context.lease.fencingToken,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      if (completed) adoptedCount++;
    }
    return adoptedCount;
  }

  int _nextTransientIngressSequence() => ++_transientIngressSequence;
}

Future<bool> _providerAlreadyConfirmed(
  Im05Persistence persistence, {
  required String ownerUserId,
  required String operationId,
}) async {
  final assessment = await persistence.recoverOutbox(
    ownerUserId: ownerUserId,
    operationId: operationId,
  );
  return assessment.main?.state == ImOutboxState.acknowledged ||
      assessment.main?.state == ImOutboxState.completed;
}

ImCoordinatedSendResult _blocked({
  required V2TimMessage? fallbackMessage,
  OutgoingIdentityContract? identity,
  bool usedOutbox = false,
  ImOutboxDispatchDecision? decision,
  bool outcomeUnknown = false,
  required String desc,
}) {
  return ImCoordinatedSendResult(
    sdkResult: V2TimValueCallback<V2TimMessage>(
      code: -1,
      desc: desc,
      data: fallbackMessage,
    ),
    usedOutbox: usedOutbox,
    identity: identity,
    dispatchDecision: decision,
    outcomeUnknown: outcomeUnknown,
  );
}

String _operationId({
  required AccountScopedConversationKey scope,
  required String sdkLocalId,
}) =>
    hashOutgoingOperationId(scope: scope, sdkLocalId: sdkLocalId);

String _clientCorrelationId(String sdkLocalId) =>
    hashOutgoingClientCorrelationId(sdkLocalId);

String? _encodeOutgoingEnvelope({
  required V2TimMessage? message,
  required String sdkLocalId,
  required String conversationId,
  required String receiver,
  required String groupID,
  required MessagePriorityEnum priority,
  required bool onlineUserOnly,
  required bool isExcludedFromUnreadCount,
  required bool needReadReceipt,
  required OfflinePushInfo? offlinePushInfo,
  required String? businessCloudCustomData,
  required String? localCustomData,
  required bool isExcludedFromContentModeration,
}) {
  if (message == null) return null;
  try {
    return jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'sdkLocalId': sdkLocalId.trim(),
      'conversationId': conversationId.trim(),
      'receiver': receiver.trim(),
      'groupID': groupID.trim(),
      'priority': priority.index,
      'onlineUserOnly': onlineUserOnly,
      'isExcludedFromUnreadCount': isExcludedFromUnreadCount,
      'needReadReceipt': needReadReceipt,
      'offlinePushInfo': offlinePushInfo?.toJson(),
      'businessCloudCustomData': businessCloudCustomData,
      'localCustomData': localCustomData,
      'isExcludedFromContentModeration': isExcludedFromContentModeration,
      // V2TimMessage.fromJson can rebuild the SDK-created local message after
      // a process restart. Media paths are retained separately as well.
      'message': message.toJson(),
    });
  } catch (_) {
    return null;
  }
}

String? _mediaLocalReference(V2TimMessage? message) {
  final candidates = <String?>[
    message?.imageElem?.path,
    message?.videoElem?.videoPath,
    message?.videoElem?.snapshotPath,
    message?.soundElem?.path,
    message?.fileElem?.path,
  ];
  for (final candidate in candidates) {
    final value = candidate?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return null;
}

OutgoingMessageKind _messageKindFor(int? elemType) {
  switch (elemType) {
    case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
      return OutgoingMessageKind.text;
    case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
      return OutgoingMessageKind.image;
    case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
      return OutgoingMessageKind.video;
    case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
      return OutgoingMessageKind.audio;
    default:
      return OutgoingMessageKind.custom;
  }
}
