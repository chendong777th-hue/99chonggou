import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
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
