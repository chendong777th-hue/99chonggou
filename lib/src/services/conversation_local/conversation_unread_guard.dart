import 'package:tencent_cloud_chat_demo/src/services/foreground_chat_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 列表未读：活跃会话强制 0，其余透传 IM SDK `unreadCount`。
class ConversationUnreadGuard {
  ConversationUnreadGuard._();

  static int resolveForListApply({
    required String conversationId,
    required int existingUnread,
    required V2TimConversation incoming,
    V2TimMessage? existingLastMessage,
    String? ownerUserId,
  }) {
    final sdkUnread = _resolveUnread(
      conversationId,
      incoming,
    );
    var resolved = sdkUnread;
    if (existingLastMessage != null &&
        lastMessageAdvanced(
          before: existingLastMessage,
          after: incoming.lastMessage,
        ) &&
        sdkUnread < existingUnread) {
      // SDK 会话 patch 常领先未读计数：保留列表侧已乐观 +1 的值，避免角标回跳。
      resolved = existingUnread;
    }
    incoming.unreadCount = resolved;
    return resolved;
  }

  static int resolveForPersist({
    required V2TimConversation conversation,
    required int uiUnread,
    required bool suppressStaleForRecentlyLeft,
    String? ownerUserId,
  }) {
    // uiUnread / suppressStaleForRecentlyLeft / ownerUserId 保留签名兼容。
    final resolved = _resolveUnread(
      conversation.conversationID,
      conversation,
    );
    conversation.unreadCount = resolved;
    return resolved;
  }

  /// 入站消息乐观预览时是否同步 +1 未读（与预览同帧刷新）。
  static bool shouldOptimisticBumpUnread({
    required String conversationId,
    required V2TimMessage message,
  }) {
    if (message.isSelf == true) {
      return false;
    }
    if (ForegroundChatGuard.isActiveConversation(conversationId)) {
      return false;
    }
    if (GroupTipsMessageHelper.shouldSuppressConversationUnread(message)) {
      return false;
    }
    return true;
  }

  /// 合并前后 lastMessage 是否前进到新消息（同 msgID 状态升级不算前进）。
  static bool lastMessageAdvanced({
    V2TimMessage? before,
    V2TimMessage? after,
  }) {
    if (after == null) {
      return false;
    }
    if (before == null) {
      return true;
    }
    final beforeId = before.msgID?.trim() ?? '';
    final afterId = after.msgID?.trim() ?? '';
    if (beforeId.isNotEmpty &&
        afterId.isNotEmpty &&
        beforeId == afterId) {
      return false;
    }
    final beforeTs = before.timestamp ?? 0;
    final afterTs = after.timestamp ?? 0;
    if (afterTs > beforeTs) {
      return true;
    }
    if (afterTs < beforeTs) {
      return false;
    }
    return beforeId != afterId;
  }

  static int _resolveUnread(
    String conversationId,
    V2TimConversation conversation,
  ) {
    final id = conversationId.trim();
    if (ForegroundChatGuard.isActiveConversation(id)) {
      conversation.unreadCount = 0;
      return 0;
    }
    return conversation.unreadCount ?? 0;
  }
}
