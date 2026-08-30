// IM-08 P0-Critical 第二刀：所有业务消息类型的外发（钱包/名片/群创建/分享）
// 必须通过本 helper 在 Outbox 主表写入记录，使失败可恢复。
//
// ChatExternalMessageSender.sendCreatedMessage 仍然是 UIKit 真实发送入口
// (vendor _sendMessage),但调用 SDK 前必须先经过本 helper,在 Outbox 主表写入:
//   prepared -> dispatchIntent -> sending
// 然后根据 UIKit sendMessageFromController 返回的 code:
//   0   -> recordOutboxSdkSucceeded
//   !=0 -> recordOutboxSdkFailed (或 OutcomeUnknown)
//
// vendor 不能改,所以 Outbox 与 UIKit 同步写入;若 UIKit 真实发送成功但本 helper
// 失败,以 UIKit 为准 (UIKit 自己的乐观气泡 + 历史回写);若本 helper 成功但 UIKit
// 失败,以 Outbox 为准,可被 ImRecoveryWorker 恢复重试。

import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/account_scoped_conversation_key.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/outgoing_identity_contract.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_persistence.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ExternalOutboxRecordOutcome {
  const ExternalOutboxRecordOutcome({
    required this.prepared,
    required this.outcomeUnknown,
  });
  final bool prepared;
  final bool outcomeUnknown;
}

class OutgoingExternalSendHelper {
  OutgoingExternalSendHelper._();

  /// 在 Outbox 主表写入 prepared + dispatchIntent + sending 记录。
  /// 用于 ChatExternalMessageSender.sendCreatedMessage 调用 UIKit SDK 前。
  ///
  /// 返回 [ExternalOutboxRecordOutcome]:
  ///   - prepared=false: lease 不可用或 scope 非法,Outbox 没写入
  ///   - outcomeUnknown=true: 主表或恢复副本状态冲突,不能继续
  static Future<ExternalOutboxRecordOutcome> recordOutboxEntryForExternal({
    required V2TimMessage message,
    required String sdkLocalId,
    required String ownerUserId,
    required ImConversationType conversationType,
    required String conversationId,
  }) async {
    final context = await ConversationSyncService.instance
        .messageCoreLeaseForOutgoingSend();
    if (context == null || context.ownerUserId != ownerUserId) {
      return const ExternalOutboxRecordOutcome(
        prepared: false,
        outcomeUnknown: false,
      );
    }
    final scope = AccountScopedConversationKey.tryParse(
      ownerUserId: ownerUserId,
      conversationType: conversationType,
      conversationId: conversationId,
    );
    if (scope == null) {
      return const ExternalOutboxRecordOutcome(
        prepared: false,
        outcomeUnknown: false,
      );
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elemType = message.elemType ?? MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
    final payloadHash = sha256
        .convert(utf8.encode(
            '${sdkLocalId}:${elemType}:${message.timestamp ?? 0}'))
        .toString();
    final identity = OutgoingIdentityContract(
      scope: scope,
      operationId: 'external:${scope.storageKey}:${sdkLocalId}',
      clientCorrelationId: sdkLocalId,
      messageKind: OutgoingMessageKind.custom,
      payloadFingerprint: payloadHash,
      createdAtMs: nowMs,
      sdkLocalId: sdkLocalId,
    );
    final main = ImOutboxRecord(
      operationId: identity.operationId,
      ownerUserId: ownerUserId,
      conversationId: scope.storageKey,
      clientCorrelationId: identity.clientCorrelationId,
      messageType: elemType,
      payloadReference: 'sdkLocalId:$sdkLocalId',
      payloadHash: payloadHash,
      contentChecksum: payloadHash,
      sdkMessageId: sdkLocalId,
      state: ImOutboxState.prepared,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    );
    final recovery = ImOutboxRecoveryRecord(
      ownerUserId: ownerUserId,
      operationId: identity.operationId,
      clientCorrelationId: identity.clientCorrelationId,
      conversationId: scope.storageKey,
      messageType: elemType,
      recoveryRevision: 1,
      state: ImOutboxCopyState.copyPrepared,
      payloadReferenceOrCiphertext: 'sdkLocalId:$sdkLocalId',
      payloadHash: payloadHash,
      checksum: payloadHash,
      sdkLocalId: sdkLocalId,
      updatedAtMs: nowMs,
    );
    final persistence = Im05Persistence(store: context.store);
    try {
      final prepared = await persistence.prepareOutbox(
        main: main,
        recoveryCopy: recovery,
        leaseOwnerId: context.lease.leaseOwnerId,
        fencingToken: context.lease.fencingToken,
        nowMs: nowMs,
      );
      if (!prepared.canDispatch) {
        return ExternalOutboxRecordOutcome(
          prepared: false,
          outcomeUnknown: prepared.requiresOutcomeQuery,
        );
      }
      final dispatch = await persistence.recordDispatchIntent(
        ownerUserId: ownerUserId,
        operationId: identity.operationId,
        dispatchAttemptId: 'external-attempt:${identity.operationId}:$nowMs',
        leaseOwnerId: context.lease.leaseOwnerId,
        fencingToken: context.lease.fencingToken,
        nowMs: nowMs,
      );
      if (!dispatch.canDispatch) {
        return ExternalOutboxRecordOutcome(
          prepared: false,
          outcomeUnknown: dispatch.requiresOutcomeQuery,
        );
      }
      final sending = await persistence.transitionOutbox(
        next: dispatch.main!.copyWith(state: ImOutboxState.sending),
        expectedState: ImOutboxState.dispatchIntent,
        leaseOwnerId: context.lease.leaseOwnerId,
        fencingToken: context.lease.fencingToken,
        nowMs: nowMs,
      );
      if (sending == null) {
        return const ExternalOutboxRecordOutcome(
          prepared: false,
          outcomeUnknown: false,
        );
      }
      return const ExternalOutboxRecordOutcome(prepared: true, outcomeUnknown: false);
    } on Im05IdentityConflictException {
      return const ExternalOutboxRecordOutcome(
        prepared: false,
        outcomeUnknown: true,
      );
    } catch (_) {
      return const ExternalOutboxRecordOutcome(
        prepared: false,
        outcomeUnknown: true,
      );
    }
  }

  /// 在 UIKit sendMessageFromController 返回后,根据 code 写最终态。
  static Future<void> finalizeOutboxForExternal({
    required String ownerUserId,
    required String conversationId,
    required String sdkLocalId,
    required String? serverMsgId,
    required int resultCode,
    required bool outcomeUnknown,
  }) async {
    final context = await ConversationSyncService.instance
        .messageCoreLeaseForOutgoingSend();
    if (context == null || context.ownerUserId != ownerUserId) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final operationId = 'external:${ownerUserId}|${conversationId}:${sdkLocalId}';
    final persistence = Im05Persistence(store: context.store);
    if (outcomeUnknown) {
      await persistence.recordOutcomeUnknown(
        ownerUserId: ownerUserId,
        operationId: operationId,
        leaseOwnerId: context.lease.leaseOwnerId,
        fencingToken: context.lease.fencingToken,
        nowMs: nowMs,
        resultCode: '$resultCode',
      );
      return;
    }
    if (resultCode == 0) {
      await persistence.recordOutboxSdkSucceeded(
        ownerUserId: ownerUserId,
        operationId: operationId,
        leaseOwnerId: context.lease.leaseOwnerId,
        fencingToken: context.lease.fencingToken,
        nowMs: nowMs,
        sdkLocalId: sdkLocalId,
        serverMsgId: serverMsgId,
        resultCode: '$resultCode',
      );
      return;
    }
    await persistence.recordOutboxSdkFailed(
      ownerUserId: ownerUserId,
      operationId: operationId,
      leaseOwnerId: context.lease.leaseOwnerId,
      fencingToken: context.lease.fencingToken,
      nowMs: nowMs,
      sdkLocalId: sdkLocalId,
      serverMsgId: serverMsgId,
      resultCode: '$resultCode',
    );
  }
}
