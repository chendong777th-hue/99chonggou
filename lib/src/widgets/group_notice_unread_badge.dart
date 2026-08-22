import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/unread_message.dart';

/// 群通知未读角标（通讯录入口、会话列表等）。
class GroupNoticeUnreadBadge extends StatelessWidget {
  const GroupNoticeUnreadBadge({
    super.key,
    this.width = 16,
    this.height = 16,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: GroupNoticeUnreadService.instance,
      builder: (context, child) {
        final count = GroupNoticeUnreadService.instance.unreadCount;
        if (count <= 0) {
          return const SizedBox.shrink();
        }
        return UnreadMessage(
          unreadCount: count,
          width: width,
          height: height,
        );
      },
    );
  }
}
