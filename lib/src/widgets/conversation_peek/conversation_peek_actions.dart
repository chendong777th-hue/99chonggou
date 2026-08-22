import 'package:flutter/foundation.dart';

enum ConversationPeekMenuVariant {
  /// 消息列表：归档、置顶、静音、删除会话等。
  conversation,
  /// 通讯录：发消息、查看资料、星标、删除好友等。
  contact,
}

class ConversationPeekActions {
  const ConversationPeekActions({
    required this.onOpenChat,
    this.variant = ConversationPeekMenuVariant.conversation,
    this.onArchive,
    this.onAddToFolder,
    this.onMarkUnread,
    this.onTogglePin,
    this.onToggleMute,
    this.onDelete,
    this.onViewProfile,
    this.onToggleStar,
    this.onDeleteFriend,
    this.isPinned = false,
    this.isMuted = false,
    this.isArchived = false,
    this.isStarred = false,
    this.isOfficialAccount = false,
    this.onlineStatusText,
  });

  final VoidCallback onOpenChat;
  final ConversationPeekMenuVariant variant;
  final Future<void> Function()? onArchive;
  final Future<void> Function()? onAddToFolder;
  final Future<void> Function()? onMarkUnread;
  final Future<void> Function()? onTogglePin;
  final Future<void> Function()? onToggleMute;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onViewProfile;
  final Future<void> Function()? onToggleStar;
  final Future<void> Function()? onDeleteFriend;
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;
  final bool isStarred;
  final bool isOfficialAccount;
  final String? onlineStatusText;
}
