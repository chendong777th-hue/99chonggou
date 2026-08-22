import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_badge_unread_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/unread_message.dart';

/// 自托管好友申请未读角标（底部导航通讯录 Tab、新的朋友等）。
class FriendRequestUnreadBadge extends StatelessWidget {
  const FriendRequestUnreadBadge({
    super.key,
    this.width = 16,
    this.height = 16,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable:
          FriendRequestNoticeService.instance.pendingApplicationCount,
      builder: (context, count, child) {
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

/// 底部/桌面导航通讯录角标：好友申请 + 群通知未读实时合计。
class ContactUnreadBadge extends StatelessWidget {
  const ContactUnreadBadge({
    super.key,
    this.width = 16,
    this.height = 16,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        FriendRequestNoticeService.instance.pendingApplicationCount,
        GroupNoticeUnreadService.instance,
      ]),
      builder: (context, child) {
        final count = AppBadgeUnreadUtils.visibleUnreadForContact();
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
