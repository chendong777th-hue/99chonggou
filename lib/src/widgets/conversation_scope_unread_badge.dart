import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/conversation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_aggregate.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_entry_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_badge_unread_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/unread_message.dart';

/// 消息 / 群聊 Tab 未读角标（与桌面图标角标同一套汇总逻辑）。
class ConversationScopeUnreadBadge extends StatelessWidget {
  const ConversationScopeUnreadBadge({
    super.key,
    required this.scope,
    this.width = 16,
    this.height = 16,
  });

  final ConversationListScope scope;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ConversationUnreadAggregate.instance,
        GroupNoticeUnreadService.instance,
        GroupNoticeEntrySettingsService.instance,
      ]),
      builder: (context, child) {
        final visibleUnread = scope == ConversationListScope.group
            ? AppBadgeUnreadUtils.visibleUnreadForGroup()
            : AppBadgeUnreadUtils.visibleUnreadForC2c();
        if (visibleUnread <= 0) {
          return const SizedBox.shrink();
        }
        return UnreadMessage(
          unreadCount: visibleUnread,
          width: width,
          height: height,
        );
      },
    );
  }
}
