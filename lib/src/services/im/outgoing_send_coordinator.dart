import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_persistence.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/tencent_message_adapter.dart';
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

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final messageKind = _messageKindFor(fallbackMessage?.elemType);
    final identity = OutgoingIdentityContract(
      scope: scope,
      operationId: _operationId(scope: scope, sdkLocalId: localId),
      clientCorrelationId: _clientCorrelationId(localId),
      messageKind: messageKind,
      payloadFingerprint: _payloadFingerprint(
        message: fallbackMessage,
        sdkLocalId: localId,
        businessCloudCustomData: businessCloudCustomData,
        localCustomData: localCustomData,
      ),
      createdAtMs: nowMs,
      sdkLocalId: localId,
    );
    final persistence = Im05Persistence(store: context.store);
    final sendGeneration = ++_sendOperationGeneration;

    if (persistOutbox) {
      final main = ImOutboxRecord(
        operationId: identity.operationId,
        ownerUserId: context.ownerUserId,
        conversationId: scope.storageKey,
        clientCorrelationId: identity.clientCorrelationId,
        messageType: fallbackMessage?.elemType ?? messageKind.index,
        payloadReference: 'sdkLocalId:$localId',
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
        payloadReferenceOrCiphertext: 'sdkLocalId:$localId',
        payloadHash: identity.payloadFingerprint,
        checksum: identity.payloadFingerprint,
        sdkLocalId: localId,
        updatedAtMs: nowMs,
      );
      final prepared = await persistence.prepareOutbox(
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
    final callback = V2TimValueCallback<V2TimMessage>(
      code: sdk.code ?? (sdk.isSuccess ? 0 : -1),
      desc: sdk.resultDesc ?? '',
      data: sdk.data?.message ?? fallbackMessage,
    );
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
        await persistence.recordOutcomeUnknown(
          ownerUserId: context.ownerUserId,
          operationId: identity.operationId,
          leaseOwnerId: context.lease.leaseOwnerId,
          fencingToken: context.lease.fencingToken,
          nowMs: now,
          resultCode: '${callback.code}',
        );
      } else {
        await persistence.recordOutboxSdkFailed(
          ownerUserId: context.ownerUserId,
          operationId: identity.operationId,
          leaseOwnerId: context.lease.leaseOwnerId,
          fencingToken: context.lease.fencingToken,
          nowMs: now,
          sdkLocalId: localId,
          serverMsgId: formalIdentity.serverMsgId,
          resultCode: '${callback.code}',
        );
      }
    }
    return ImCoordinatedSendResult(
      sdkResult: callback,
      usedOutbox: persistOutbox,
      identity: formalIdentity,
      accountGeneration: context.accountGeneration,
      domainGeneration: context.domainGeneration,
      outcomeUnknown: sdk.isOutcomeUnknown,
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

  int _nextTransientIngressSequence() => ++_transientIngressSequence;
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
}) {
  final digest = sha256.convert(
    utf8.encode('send|${scope.storageKey}|${sdkLocalId.trim()}'),
  );
  return 'send_${digest.toString().substring(0, 32)}';
}

String _clientCorrelationId(String sdkLocalId) {
  final digest = sha256.convert(utf8.encode('client|${sdkLocalId.trim()}'));
  return 'client_${digest.toString().substring(0, 24)}';
}

String _payloadFingerprint({
  required V2TimMessage? message,
  required String sdkLocalId,
  required String? businessCloudCustomData,
  required String? localCustomData,
}) {
  final payload = <String, Object?>{
    'sdkLocalId': sdkLocalId.trim(),
    'elemType': message?.elemType,
    'text': message?.textElem?.text,
    'custom': message?.customElem?.data,
    'imagePath': message?.imageElem?.path,
    'videoPath': message?.videoElem?.videoPath,
    'soundPath': message?.soundElem?.path,
    'fileName': message?.fileElem?.fileName,
    'fileSize': message?.fileElem?.fileSize,
    'businessCloudCustomData': businessCloudCustomData,
    'localCustomData': localCustomData,
  };
  return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
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
