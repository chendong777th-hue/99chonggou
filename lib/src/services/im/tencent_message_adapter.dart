import 'dart:async';

import 'package:tencent_cloud_chat_demo/src/services/im/contracts/contracts.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_priority_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_list_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_list_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

typedef ImSyncIdentitySink = void Function(
  EventEnvelope<OutgoingIdentityContract> event,
);

/// Minimal SDK port used by [TencentMessageAdapter].
///
/// Keeping this interface small lets contract tests use a fake and prevents
/// the domain layer from depending on TUIKit's service locator or model.
abstract interface class ImTencentMessagePort {
  Future<V2TimValueCallback<V2TimMessage>> sendMessage({
    required String id,
    required String receiver,
    required String groupID,
    required MessagePriorityEnum priority,
    required bool onlineUserOnly,
    required bool isExcludedFromUnreadCount,
    required bool needReadReceipt,
    required OfflinePushInfo? offlinePushInfo,
    required String cloudCustomData,
    required String? localCustomData,
    required bool isExcludedFromContentModeration,
    required void Function(String syncMsgID) onSyncMsgID,
  });

  Future<ImSdkHistoryResponse?> getHistoryMessageListWithComplete({
    required HistoryMsgGetTypeEnum getType,
    required String? userID,
    required String? groupID,
    required int lastMsgSeq,
    required int count,
    required String? lastMsgID,
    required List<int>? messageTypeList,
    required List<int>? messageSeqList,
    required int? timeBegin,
    required int? timePeriod,
  });
}

/// Transitional port for the existing TUIKit MessageService.
///
/// It deliberately does not expose TUIKit models or invoke a UI writer. The
/// old `onSyncMsgID` side effect remains in MessageServiceImpl until the next
/// migration step replaces that implementation with this port.
class TUIKitMessageServicePort implements ImTencentMessagePort {
  const TUIKitMessageServicePort(this.service);

  final MessageService service;

  @override
  Future<V2TimValueCallback<V2TimMessage>> sendMessage({
    required String id,
    required String receiver,
    required String groupID,
    required MessagePriorityEnum priority,
    required bool onlineUserOnly,
    required bool isExcludedFromUnreadCount,
    required bool needReadReceipt,
    required OfflinePushInfo? offlinePushInfo,
    required String cloudCustomData,
    required String? localCustomData,
    required bool isExcludedFromContentModeration,
    required void Function(String syncMsgID) onSyncMsgID,
  }) {
    return service.sendMessage(
      id: id,
      receiver: receiver,
      groupID: groupID,
      priority: priority,
      onlineUserOnly: onlineUserOnly,
      isExcludedFromUnreadCount: isExcludedFromUnreadCount,
      needReadReceipt: needReadReceipt,
      offlinePushInfo: offlinePushInfo,
      cloudCustomData: cloudCustomData,
      localCustomData: localCustomData,
      isExcludedFromContentModeration: isExcludedFromContentModeration,
      onSyncMsgID: onSyncMsgID,
    );
  }

  @override
  Future<ImSdkHistoryResponse?> getHistoryMessageListWithComplete({
    required HistoryMsgGetTypeEnum getType,
    required String? userID,
    required String? groupID,
    required int lastMsgSeq,
    required int count,
    required String? lastMsgID,
    required List<int>? messageTypeList,
    required List<int>? messageSeqList,
    required int? timeBegin,
    required int? timePeriod,
  }) async {
    final result = await service.getHistoryMessageListWithComplete(
      getType: getType,
      userID: userID,
      groupID: groupID,
      lastMsgSeq: lastMsgSeq,
      count: count,
      lastMsgID: lastMsgID,
      messageTypeList: messageTypeList,
      messageSeqList: messageSeqList,
      timeBegin: timeBegin,
      timePeriod: timePeriod,
    );
    if (result == null) return null;
    return ImSdkHistoryResponse(
      result: result,
      actualSource: _sourceForGetType(getType),
      proofLevel: ImHistoryProofLevel.none,
    );
  }
}

class ImSdkHistoryResponse {
  const ImSdkHistoryResponse({
    required this.result,
    required this.actualSource,
    required this.proofLevel,
  });

  final V2TimMessageListResult result;
  final ImHistorySource actualSource;
  final ImHistoryProofLevel proofLevel;
}

class ImSendResponse {
  const ImSendResponse({required this.identity, this.message});

  final OutgoingIdentityContract identity;
  final V2TimMessage? message;
}

class ImHistoryReadResponse {
  const ImHistoryReadResponse({required this.messages, required this.proof});

  final List<V2TimMessage> messages;
  final HistoryProof proof;
}

/// First SDK Adapter boundary for the IM migration.
///
/// This class owns cloudCustomData injection and converts SDK send/history
/// results into typed domain DTOs. It has no dependency on pages, TUIKit
/// global state, or the conversation store.
class TencentMessageAdapter {
  TencentMessageAdapter({
    required this.port,
    required this.platform,
    required String ownerUserId,
    required this.accountGeneration,
    required this.domainGeneration,
    required this.nextAccountIngressSequence,
    required this.nextScopeIngressSequence,
    this.onSyncIdentity,
  }) : ownerUserId = _requiredOwner(ownerUserId) {
    if (accountGeneration < 0 || domainGeneration < 0) {
      throw ArgumentError('adapter generations must be non-negative');
    }
  }

  final ImTencentMessagePort port;
  final ImPlatform platform;
  final String ownerUserId;
  final int accountGeneration;
  final int domainGeneration;
  final int Function() nextAccountIngressSequence;
  final int Function(AccountScopedConversationKey scope)
      nextScopeIngressSequence;
  final ImSyncIdentitySink? onSyncIdentity;

  Future<SdkResult<ImSendResponse>> send({
    required OutgoingIdentityContract identity,
    required String sdkLocalId,
    required String receiver,
    required String groupID,
    int sendOperationGeneration = 0,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool onlineUserOnly = false,
    bool isExcludedFromUnreadCount = false,
    bool needReadReceipt = false,
    OfflinePushInfo? offlinePushInfo,
    String? localCustomData,
    String? businessCloudCustomData,
    bool isExcludedFromContentModeration = false,
  }) async {
    final localId = sdkLocalId.trim();
    if (localId.isEmpty) {
      return SdkResult<ImSendResponse>.failure(
        errorKind: SdkErrorKind.invalidArgument,
        resultDesc: 'sdkLocalId is required',
      );
    }
    final addressError = _validateAddress(identity.scope, receiver, groupID);
    if (addressError != null) {
      return SdkResult<ImSendResponse>.failure(
        errorKind: SdkErrorKind.invalidArgument,
        resultDesc: addressError,
      );
    }
    if (sendOperationGeneration < 0) {
      return SdkResult<ImSendResponse>.failure(
        errorKind: SdkErrorKind.invalidArgument,
        resultDesc: 'sendOperationGeneration must be non-negative',
      );
    }

    try {
      final result = await port.sendMessage(
        id: localId,
        receiver: receiver,
        groupID: groupID,
        priority: priority,
        onlineUserOnly: onlineUserOnly,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount,
        needReadReceipt: needReadReceipt,
        offlinePushInfo: offlinePushInfo,
        cloudCustomData: identity.encodeCloudCustomData(
          businessCloudCustomData: businessCloudCustomData,
        ),
        localCustomData: localCustomData,
        isExcludedFromContentModeration: isExcludedFromContentModeration,
        onSyncMsgID: (syncMsgID) {
          _emitSyncIdentity(
            identity: identity,
            sdkLocalId: localId,
            syncMsgID: syncMsgID,
            sendOperationGeneration: sendOperationGeneration,
          );
        },
      );
      if (result.code != 0) {
        return SdkResult<ImSendResponse>.failure(
          errorKind: SdkErrorKind.sdk,
          code: result.code,
          resultDesc: result.desc,
        );
      }
      final formalIdentity = identity.withFormalIdentity(
        sdkLocalId: localId,
        serverMsgId: result.data?.msgID,
      );
      return SdkResult<ImSendResponse>.success(
        data: ImSendResponse(identity: formalIdentity, message: result.data),
        code: result.code,
        resultDesc: result.desc,
      );
    } on TimeoutException catch (error) {
      return SdkResult<ImSendResponse>.outcomeUnknown(
        resultDesc: error.toString(),
      );
    } catch (error) {
      // A transport exception does not prove that the provider rejected the
      // operation. The Outbox must query/adopt before offering a retry.
      return SdkResult<ImSendResponse>.outcomeUnknown(
        resultDesc: error.toString(),
      );
    }
  }

  Future<SdkResult<ImHistoryReadResponse>> readHistory({
    required AccountScopedConversationKey scope,
    required ImHistoryDirection direction,
    required ImHistorySource requestedSource,
    required int requestGeneration,
    required String requestId,
    required int count,
    int lastMsgSeq = -1,
    String? lastMsgID,
    List<int>? messageTypeList,
    List<int>? messageSeqList,
    int? timeBegin,
    int? timePeriod,
    String? requestFingerprint,
  }) async {
    if (scope.ownerUserId != ownerUserId) {
      return SdkResult<ImHistoryReadResponse>.failure(
        errorKind: SdkErrorKind.invalidArgument,
        resultDesc: 'history scope belongs to another account',
      );
    }
    if (requestGeneration < 0 || count <= 0) {
      return SdkResult<ImHistoryReadResponse>.failure(
        errorKind: SdkErrorKind.invalidArgument,
        resultDesc: 'invalid history request generation or count',
      );
    }
    final actualSource =
        platform == ImPlatform.web ? ImHistorySource.cloud : requestedSource;
    final getType = _historyGetType(
      source: actualSource,
      direction: direction,
    );
    try {
      final sdkResponse = await port.getHistoryMessageListWithComplete(
        getType: getType,
        userID: scope.conversationType == ImConversationType.c2c
            ? scope.conversationId.substring(4)
            : null,
        groupID: scope.conversationType == ImConversationType.group
            ? scope.conversationId.substring(6)
            : null,
        lastMsgSeq: lastMsgSeq,
        count: count,
        lastMsgID: lastMsgID,
        messageTypeList: messageTypeList,
        messageSeqList: messageSeqList,
        timeBegin: timeBegin,
        timePeriod: timePeriod,
      );
      if (sdkResponse == null) {
        return SdkResult<ImHistoryReadResponse>.failure(
          errorKind: SdkErrorKind.unknown,
          resultDesc: 'SDK returned no history result',
        );
      }
      final result = sdkResponse.result;
      final messages = List<V2TimMessage>.unmodifiable(result.messageList);
      final proof = HistoryProof(
        scope: scope,
        platform: platform,
        accountGeneration: accountGeneration,
        domainGeneration: domainGeneration,
        requestGeneration: requestGeneration,
        requestId: requestId,
        direction: direction,
        requestedSource: requestedSource,
        actualSource: sdkResponse.actualSource,
        level: sdkResponse.proofLevel,
        returnedCount: messages.length,
        isFinished: result.isFinished,
        boundaryMessageIds: _messageIds(messages),
        overlapMessageIds: _overlapIds(messages, lastMsgID),
        cursor: ImHistoryCursor(
            messageId: lastMsgID, sequence: lastMsgSeq > 0 ? lastMsgSeq : null),
        oldestSequence: _oldestSequence(messages),
        newestSequence: _newestSequence(messages),
        requestFingerprint: requestFingerprint,
      );
      return SdkResult<ImHistoryReadResponse>.success(
        data: ImHistoryReadResponse(messages: messages, proof: proof),
      );
    } on TimeoutException catch (error) {
      return SdkResult<ImHistoryReadResponse>.failure(
        errorKind: SdkErrorKind.timeout,
        resultDesc: error.toString(),
      );
    } catch (error) {
      return SdkResult<ImHistoryReadResponse>.failure(
        errorKind: SdkErrorKind.unknown,
        resultDesc: error.toString(),
      );
    }
  }

  void _emitSyncIdentity({
    required OutgoingIdentityContract identity,
    required String sdkLocalId,
    required String syncMsgID,
    required int sendOperationGeneration,
  }) {
    final formalId = syncMsgID.trim();
    if (formalId.isEmpty || onSyncIdentity == null) return;
    final accountSequence = nextAccountIngressSequence();
    final scopeSequence = nextScopeIngressSequence(identity.scope);
    final event = EventEnvelope<OutgoingIdentityContract>(
      eventId: 'send-sync:${identity.operationId}:$formalId',
      eventNamespace: 'chat',
      kind: ImEventKind.outgoingAdoption,
      scope: identity.scope,
      ownerUserId: ownerUserId,
      accountGeneration: accountGeneration,
      domainGeneration: domainGeneration,
      sendOperationGeneration: sendOperationGeneration,
      clearEpoch: 0,
      accountIngressSequence: accountSequence,
      scopeIngressSequence: scopeSequence,
      source: ImEventSource.sdkSend,
      authority: ImEventAuthority.provider,
      operationId: identity.operationId,
      observedAtMs: DateTime.now().millisecondsSinceEpoch,
      payload: identity.withFormalIdentity(
        sdkLocalId: sdkLocalId,
        serverMsgId: formalId,
      ),
    );
    onSyncIdentity!(event);
  }

  String? _validateAddress(
    AccountScopedConversationKey scope,
    String receiver,
    String groupID,
  ) {
    if (scope.ownerUserId != ownerUserId) {
      return 'outgoing scope belongs to another account';
    }
    final hasReceiver = receiver.trim().isNotEmpty;
    final hasGroup = groupID.trim().isNotEmpty;
    if (hasReceiver == hasGroup) {
      return 'exactly one of receiver and groupID is required';
    }
    final expected = AccountScopedConversationKey(
      ownerUserId: ownerUserId,
      conversationType:
          hasGroup ? ImConversationType.group : ImConversationType.c2c,
      conversationId: hasGroup ? groupID : receiver,
    );
    return expected == scope ? null : 'send address does not match scope';
  }
}

String _requiredOwner(String raw) {
  final owner = ChatIdFormat.rawUserUid(raw);
  if (owner.isEmpty) throw ArgumentError.value(raw, 'ownerUserId');
  return owner;
}

HistoryMsgGetTypeEnum _historyGetType({
  required ImHistorySource source,
  required ImHistoryDirection direction,
}) {
  final newer = direction == ImHistoryDirection.newer;
  if (source == ImHistorySource.local) {
    return newer
        ? HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_NEWER_MSG
        : HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG;
  }
  return newer
      ? HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_NEWER_MSG
      : HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG;
}

ImHistorySource _sourceForGetType(HistoryMsgGetTypeEnum getType) {
  switch (getType) {
    case HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG:
    case HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_NEWER_MSG:
      return ImHistorySource.local;
    case HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG:
    case HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_NEWER_MSG:
      return ImHistorySource.cloud;
    case HistoryMsgGetTypeEnum.V2TIM_NULL:
      return ImHistorySource.cloud;
  }
}

List<String> _messageIds(Iterable<V2TimMessage> messages) =>
    List<String>.unmodifiable(
      messages
          .map((message) => message.msgID?.trim() ?? '')
          .where((id) => id.isNotEmpty),
    );

List<String> _overlapIds(Iterable<V2TimMessage> messages, String? cursor) {
  final id = cursor?.trim() ?? '';
  if (id.isEmpty) return const <String>[];
  return _messageIds(messages)
      .where((value) => value == id)
      .toList(growable: false);
}

int? _oldestSequence(Iterable<V2TimMessage> messages) {
  final values = messages
      .map((message) => int.tryParse(message.seq?.trim() ?? ''))
      .whereType<int>()
      .toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a < b ? a : b);
}

int? _newestSequence(Iterable<V2TimMessage> messages) {
  final values = messages
      .map((message) => int.tryParse(message.seq?.trim() ?? ''))
      .whereType<int>()
      .toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a > b ? a : b);
}
