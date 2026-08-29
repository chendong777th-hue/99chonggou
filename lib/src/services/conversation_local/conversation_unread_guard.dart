import 'package:tencent_cloud_chat_demo/src/services/foreground_chat_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 列表未读：活跃会话强制 0，其余透传 IM SDK `unreadCount`。
class ConversationUnreadGuard {
  ConversationUnreadGuard._();

  // The SDK can deliver the conversation row after the message callback but
  // before its unread counter catches up. Keep the UI-side bump alive for a
  // short window, tied to the exact message, so a delayed zero cannot make
  // the list badge disappear. An explicit read barrier still wins.
  static const Duration _optimisticProtectionWindow = Duration(seconds: 5);
  static final Map<String, _OptimisticUnreadStamp> _optimisticUnread =
      <String, _OptimisticUnreadStamp>{};

  static void recordOptimisticUnread({
    required String conversationId,
    required V2TimMessage message,
    required int unreadCount,
  }) {
    final id = conversationId.trim();
    final messageId = (message.msgID ?? message.id ?? '').trim();
    if (id.isEmpty || messageId.isEmpty || unreadCount <= 0) {
      return;
    }
    _optimisticUnread[id] = _OptimisticUnreadStamp(
      messageId: messageId,
      recordedAt: DateTime.now(),
    );
  }

  static void clearOptimisticUnread(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    _optimisticUnread.remove(id);
    _optimisticUnread.removeWhere(
      (key, _) => MessageConversationId.sameConversation(key, id),
    );
  }

  static void clearOptimisticUnreadMany(Iterable<String> conversationIds) {
    for (final id in conversationIds) {
      clearOptimisticUnread(id);
    }
  }

  static void clearAllOptimisticUnread() {
    _optimisticUnread.clear();
  }

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
    if (sdkUnread > 0 &&
        _isReadAnchorReplay(
          conversationId: conversationId,
          incoming: incoming,
          ownerUserId: ownerUserId,
        )) {
      incoming.unreadCount = 0;
      return 0;
    }
    // 全部已读后 SDK 回灌宽限判定：与 Store 层 _upsertBatchImpl 对齐，
    // 在 read anchor 的 12 秒宽限期内，如果 incoming 的 lastMessage 时间戳
    // 不晚于 read cleared 时间，说明 SDK 回灌的是已读前的旧快照——
    // 即使 msgID 不完全匹配也强制 unread=0，避免气泡残留。
    if (sdkUnread > 0 &&
        _isReadGraceReplay(
          conversationId: conversationId,
          incoming: incoming,
          ownerUserId: ownerUserId,
        )) {
      incoming.unreadCount = 0;
      return 0;
    }
    var resolved = sdkUnread;
    if (_shouldPreserveOptimisticUnread(
      conversationId: conversationId,
      existingUnread: existingUnread,
      sdkUnread: sdkUnread,
      existingLastMessage: existingLastMessage,
      incoming: incoming,
      ownerUserId: ownerUserId,
    )) {
      resolved = existingUnread;
    }
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

  static bool _shouldPreserveOptimisticUnread({
    required String conversationId,
    required int existingUnread,
    required int sdkUnread,
    required V2TimMessage? existingLastMessage,
    required V2TimConversation incoming,
    String? ownerUserId,
  }) {
    if (existingUnread <= 0 || sdkUnread >= existingUnread) {
      if (sdkUnread > 0 && existingUnread > 0) {
        // The SDK has caught up with the optimistic value. A later zero is
        // then allowed to represent a genuine cross-device read.
        clearOptimisticUnread(conversationId);
      }
      return false;
    }
    if (ForegroundChatGuard.isActiveConversation(conversationId)) {
      return false;
    }
    final id = conversationId.trim();
    final stamp = _stampFor(id);
    if (stamp == null) {
      return false;
    }
    final now = DateTime.now();
    if (now.difference(stamp.recordedAt) > _optimisticProtectionWindow) {
      clearOptimisticUnread(id);
      return false;
    }
    final readClearedAt = ConversationLocalStore.instance.readClearedAtFor(
      id,
      ownerUserId: ownerUserId,
    );
    if (readClearedAt >= stamp.recordedAt.millisecondsSinceEpoch) {
      clearOptimisticUnread(id);
      return false;
    }
    final existingId =
        (existingLastMessage?.msgID ?? existingLastMessage?.id ?? '').trim();
    if (existingId != stamp.messageId) {
      // A different local message superseded the optimistic stamp.
      clearOptimisticUnread(id);
      return false;
    }
    if (lastMessageAdvanced(
      before: existingLastMessage,
      after: incoming.lastMessage,
    )) {
      clearOptimisticUnread(id);
      return false;
    }
    return true;
  }

  static _OptimisticUnreadStamp? _stampFor(String conversationId) {
    final direct = _optimisticUnread[conversationId];
    if (direct != null) {
      return direct;
    }
    for (final entry in _optimisticUnread.entries) {
      if (MessageConversationId.sameConversation(entry.key, conversationId)) {
        return entry.value;
      }
    }
    return null;
  }

  static int resolveForPersist({
    required V2TimConversation conversation,
    required int uiUnread,
    required bool suppressStaleForRecentlyLeft,
    String? ownerUserId,
  }) {
    // uiUnread / suppressStaleForRecentlyLeft / ownerUserId 保留签名兼容。
    if ((conversation.unreadCount ?? 0) > 0 &&
        _isReadAnchorReplay(
          conversationId: conversation.conversationID,
          incoming: conversation,
          ownerUserId: ownerUserId,
        )) {
      conversation.unreadCount = 0;
      return 0;
    }
    final resolved = _resolveUnread(
      conversation.conversationID,
      conversation,
    );
    conversation.unreadCount = resolved;
    return resolved;
  }

  static bool _isReadAnchorReplay({
    required String conversationId,
    required V2TimConversation incoming,
    String? ownerUserId,
  }) {
    final incomingId = incoming.lastMessage?.msgID?.trim() ?? '';
    if (incomingId.isEmpty) {
      return false;
    }
    final anchor = ConversationLocalStore.instance.readClearedLastMessageIdFor(
      conversationId,
      ownerUserId: ownerUserId,
    );
    return anchor != null && anchor.isNotEmpty && anchor == incomingId;
  }

  /// 全部已读后 SDK 回灌宽限判定：与 Store 层 _upsertBatchImpl 的
  /// readGraceReplay 对齐。在 read cleared 的 12 秒宽限期内，如果
  /// incoming 的 lastMessage 时间戳不晚于 read cleared 时间，
  /// 说明 SDK 回灌的是已读前的旧快照——强制 unread=0。
  static bool _isReadGraceReplay({
    required String conversationId,
    required V2TimConversation incoming,
    String? ownerUserId,
  }) {
    final readClearedAtMs = ConversationLocalStore.instance.readClearedAtFor(
      conversationId,
      ownerUserId: ownerUserId,
    );
    if (readClearedAtMs <= 0) {
      return false;
    }
    if (!ConversationLocalStore.instance.isWithinReadGrace(readClearedAtMs)) {
      return false;
    }
    final incomingTs = ConversationLocalStore.lastMessageTimestampMs(incoming);
    if (incomingTs <= 0) {
      return false;
    }
    return incomingTs <= readClearedAtMs;
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
    if (beforeId.isNotEmpty && afterId.isNotEmpty && beforeId == afterId) {
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

class _OptimisticUnreadStamp {
  const _OptimisticUnreadStamp({
    required this.messageId,
    required this.recordedAt,
  });

  final String messageId;
  final DateTime recordedAt;
}
