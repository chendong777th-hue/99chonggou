import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_sync_notifier.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

void main() {
  tearDown(() {
    ConversationListNotifier.instance.clearSession();
    ConversationListSyncNotifier.instance.clearSession();
  });

  test('sync notifier changes do not notify conversation list notifier', () {
    var dataNotifications = 0;
    var syncNotifications = 0;
    ConversationListNotifier.instance.addListener(() {
      dataNotifications++;
    });
    ConversationListSyncNotifier.instance.addListener(() {
      syncNotifications++;
    });

    ConversationListSyncNotifier.instance.setSyncing(true);
    ConversationListSyncNotifier.instance.setHasSyncedOnce(true);
    ConversationListSyncNotifier.instance.setDraining(true);
    ConversationListSyncNotifier.instance.clearSession();

    expect(dataNotifications, 0);
    expect(syncNotifications, 4);
  });

  test('conversation list reload does not notify sync notifier', () {
    var dataNotifications = 0;
    var syncNotifications = 0;
    ConversationListNotifier.instance.addListener(() {
      dataNotifications++;
    });
    ConversationListSyncNotifier.instance.addListener(() {
      syncNotifications++;
    });

    ConversationListNotifier.instance.setConversationsForTest([
      V2TimConversation(
        conversationID: 'c2c_a',
        type: 1,
        userID: 'a',
        unreadCount: 1,
      ),
    ]);

    expect(dataNotifications, 1);
    expect(syncNotifications, 0);
  });
}
