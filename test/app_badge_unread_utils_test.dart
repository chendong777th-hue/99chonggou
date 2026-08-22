import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_aggregate.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_badge_unread_utils.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_unread_utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

void main() {
  tearDown(() {
    ConversationListNotifier.instance.setConversationsForTest(const []);
    ConversationUnreadAggregate.instance.resetForTest();
    clearArchivedConversationSessionState();
    FriendRequestNoticeService.instance.pendingApplicationCount.value = 0;
  });

  test('totalAppBadgeUnreadCount matches tab badge rules', () {
    ConversationListNotifier.instance.setConversationsForTest([
      V2TimConversation(
        conversationID: 'c2c_user1',
        type: 1,
        userID: 'user1',
        unreadCount: 2,
      ),
      V2TimConversation(
        conversationID: 'c2c_user2',
        type: 1,
        userID: 'user2',
        unreadCount: 5,
        recvOpt: 1,
      ),
      V2TimConversation(
        conversationID: 'group_g1',
        type: 2,
        groupID: 'g1',
        unreadCount: 3,
      ),
      V2TimConversation(
        conversationID: 'c2c_10000',
        type: 1,
        userID: '10000',
        unreadCount: 9,
      ),
    ]);
    archivedConversationC2cIDsNotifier.value = {'c2c_user1'};
    // 角标读 Aggregate，不读 Notifier 列表；注入与规则一致的合计。
    ConversationUnreadAggregate.instance.setSumsForTest(c2c: 0, group: 3);
    FriendRequestNoticeService.instance.pendingApplicationCount.value = 4;

    expect(AppBadgeUnreadUtils.visibleUnreadForC2c(), 0);
    expect(AppBadgeUnreadUtils.visibleUnreadForGroup(), 3);
    expect(
      AppBadgeUnreadUtils.totalAppBadgeUnreadCount(),
      3 + 4,
    );
    expect(
      ConversationUnreadUtils.notifiableUnreadCount(
        ConversationListNotifier.instance.conversations[1],
      ),
      0,
    );
  });

  test('contact tab combines friend requests and group notices', () {
    expect(
      contactTabUnreadCount(
        friendRequestUnread: 2,
        groupNoticeUnread: 3,
      ),
      5,
    );
    expect(
      contactTabUnreadCount(
        friendRequestUnread: 0,
        groupNoticeUnread: 1,
      ),
      1,
    );
    expect(
      contactTabUnreadCount(
        friendRequestUnread: -1,
        groupNoticeUnread: -2,
      ),
      0,
    );
  });
}
