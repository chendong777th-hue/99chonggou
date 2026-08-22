import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_aggregate.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_entry_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';

/// 与首页 Tab 角标一致的未读汇总，供桌面图标角标复用。
class AppBadgeUnreadUtils {
  AppBadgeUnreadUtils._();

  /// 消息 Tab + 群聊 Tab + 通讯录好友申请。
  static int totalAppBadgeUnreadCount() {
    return visibleUnreadForC2c() +
        visibleUnreadForGroup() +
        FriendRequestNoticeService.instance.pendingApplicationCount.value;
  }

  static int visibleUnreadForC2c() =>
      ConversationUnreadAggregate.instance.c2cNotifiableUnreadSum;

  static int visibleUnreadForGroup() =>
      ConversationUnreadAggregate.instance.groupNotifiableUnreadSum +
      (GroupNoticeEntrySettingsService.instance.isMuted
          ? 0
          : GroupNoticeUnreadService.instance.unreadCount);

  /// 通讯录 Tab 同时承载“新的朋友”和“群通知”，两类未读都应显示。
  static int visibleUnreadForContact() => contactTabUnreadCount(
        friendRequestUnread:
            FriendRequestNoticeService.instance.pendingApplicationCount.value,
        groupNoticeUnread: GroupNoticeUnreadService.instance.unreadCount,
      );
}

int contactTabUnreadCount({
  required int friendRequestUnread,
  required int groupNoticeUnread,
}) {
  final friends = friendRequestUnread > 0 ? friendRequestUnread : 0;
  final groups = groupNoticeUnread > 0 ? groupNoticeUnread : 0;
  return friends + groups;
}
