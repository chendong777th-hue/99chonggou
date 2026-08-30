import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/account_scoped_conversation_key.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/outgoing_identity_contract.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_persistence.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 发送失败消息策略：
/// - 已失败（SEND_FAIL）→ 显示红色感叹号，**不**在进会话/恢复时自动重发
/// - 卡住的发送中（SENDING）→ 落成 SEND_FAIL，交给用户手动点感叹号重发
class ChatFailedMessageRetryService {
  ChatFailedMessageRetryService._();

  static final ChatFailedMessageRetryService instance =
      ChatFailedMessageRetryService._();

  static const int defaultMaxRecentConversations = 5;
  static const int defaultSdkMessagesPerConversation = 30;

  /// Detects the [ImConversationType] implied by a [messageListMap] storage
  /// key. Both `c2c_<uid>` and `group_<id>` shapes are accepted. Returns
  /// `null` for empty keys or unrecognized shapes so the caller can fall
  /// back to UI projection only.
  @visibleForTesting
  ImConversationType? detectConversationType(String storageKey) {
    final trimmed = storageKey.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('c2c_')) return ImConversationType.c2c;
    if (lower.startsWith('group_')) return ImConversationType.group;
    return null;
  }

  /// Routes a stuck sending message through the Outbox failure path before
  /// the UI projection is updated. Returns `true` when the Outbox was
  /// reachable for the operation; `false` when identity, lease or scope
  /// were unavailable (the caller should still settle the UI projection).
  @visibleForTesting
  Future<bool> recordOutboxFailureForStuckMessage({
    required String storageKey,
    required String sdkLocalId,
    String? serverMsgId,
    String resultCode = '-1',
  }) async {
    final localId = sdkLocalId.trim();
    if (localId.isEmpty) return false;
    final type = detectConversationType(storageKey);
    if (type == null) return false;
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return false;
    final scope = AccountScopedConversationKey.tryParse(
      ownerUserId: identity.ownerUserId,
      conversationType: type,
      conversationId: storageKey,
    );
    if (scope == null) return false;
    final leaseContext = await ConversationSyncService.instance
        .messageCoreLeaseForOutgoingSend();
    if (leaseContext == null) return false;
    final persistence = Im05Persistence(store: leaseContext.store);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final operationId = hashOutgoingOperationId(
      scope: scope,
      sdkLocalId: localId,
    );
    await persistence.recordOutboxSdkFailed(
      ownerUserId: identity.ownerUserId,
      operationId: operationId,
      leaseOwnerId: leaseContext.lease.leaseOwnerId,
      fencingToken: leaseContext.lease.fencingToken,
      nowMs: nowMs,
      sdkLocalId: localId,
      serverMsgId: serverMsgId,
      resultCode: resultCode,
    );
    return true;
  }

  /// 将卡住的「发送中」落成发送失败（红感叹号），不自动重发。
  Future<void> settleStuckSendingAsFailed({
    String? conversationID,
    ConvType? conversationType,
    Duration stuckLongerThan = const Duration(seconds: 15),
  }) async {
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final stuckBefore = nowSeconds - stuckLongerThan.inSeconds;
    final filterId = conversationID?.trim() ?? '';

    for (final entry in globalModel.messageListMap.entries) {
      final convID = entry.key;
      if (filterId.isNotEmpty &&
          convID != filterId &&
          !_conversationIdsMatch(convID, filterId)) {
        continue;
      }
      final list = entry.value;
      if (list == null || list.isEmpty) continue;

      for (final message in list) {
        if (message.isSelf != true) continue;
        if (message.status != MessageStatus.V2TIM_MSG_STATUS_SENDING) {
          continue;
        }
        final ts = message.timestamp ?? 0;
        // 无时间戳或已卡住足够久：落成失败，留给用户手动点感叹号重发。
        if (ts > 0 && ts > stuckBefore) {
          continue;
        }
        // 先把失败写进 Outbox 主记录（如果能定位 scope）；Outbox 不可达
        // 时仍然更新 UI 投影，保证原有的兜底体验不丢。
        await recordOutboxFailureForStuckMessage(
          storageKey: convID,
          sdkLocalId: message.id ?? '',
          serverMsgId: message.msgID,
          resultCode: 'stuck_sending',
        );
        globalModel.markOutgoingSendFailedByIdentity(
          conversationID: convID,
          clientId: message.id,
          msgID: message.msgID,
          reason: 'stuck_sending',
        );
      }
    }

    // conversationType 仅保留参数兼容。
    if (conversationType != null && filterId.isEmpty) {
      return;
    }
  }

  bool _conversationIdsMatch(String left, String right) {
    final a = left.trim().toLowerCase();
    final b = right.trim().toLowerCase();
    if (a == b) return true;
    String strip(String value) {
      if (value.startsWith('group_')) return value.substring(6);
      if (value.startsWith('c2c_')) return value.substring(4);
      return value;
    }

    return strip(a) == strip(b);
  }

  /// 兼容旧调用：不再自动重发失败消息，只结算卡住的发送中。
  Future<void> retryLoadedFailedMessages({
    String? conversationID,
    ConvType? conversationType,
    int limit = 8,
  }) {
    return settleStuckSendingAsFailed(
      conversationID: conversationID,
      conversationType: conversationType,
    );
  }

  /// 兼容旧调用：已停用 SDK 历史失败消息自动重发。
  Future<void> retryConversationFromSdk({
    required String conversationID,
    ConvType? conversationType,
    int messageCount = defaultSdkMessagesPerConversation,
    int retryLimit = 6,
  }) async {
    await settleStuckSendingAsFailed(
      conversationID: conversationID,
      conversationType: conversationType,
    );
  }

  /// 兼容旧调用：已停用最近会话失败消息自动重发。
  Future<void> retryRecentConversationsFromSdk({
    int maxConversations = defaultMaxRecentConversations,
    int messagesPerConversation = 20,
    int retryLimitPerConversation = 3,
  }) async {
    await settleStuckSendingAsFailed();
  }
}
