import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ConversationLocalStore mark read batch', () {
    const owner = 'mark_read_batch_owner';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      await ConversationLocalStore.instance.clearForOwner(owner);
    });

    tearDown(() async {
      await ConversationLocalStore.instance.clearForOwner(owner);
      ConversationLocalStore.instance.debugOwnerUserId = null;
    });

    test('markConversationsReadLocallyBatch clears only given ids', () async {
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: 'c2c_a',
            type: 1,
            userID: 'a',
            unreadCount: 2,
          ),
          V2TimConversation(
            conversationID: 'c2c_b',
            type: 1,
            userID: 'b',
            unreadCount: 7,
          ),
        ],
      );

      final result = await ConversationLocalStore.instance
          .markConversationsReadLocallyBatch({'c2c_a'});
      expect(result.conversationCount, 1);
      expect(result.unreadSumBefore, 2);

      final a = await ConversationLocalStore.instance.conversationById('c2c_a');
      final b = await ConversationLocalStore.instance.conversationById('c2c_b');
      expect(a?.unreadCount, 0);
      expect(b?.unreadCount, 7);
    });

    test('markAllUnreadReadLocally respects scope and exclude', () async {
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: 'group_g1',
            type: 2,
            groupID: 'g1',
            unreadCount: 3,
          ),
          V2TimConversation(
            conversationID: 'group_g2',
            type: 2,
            groupID: 'g2',
            unreadCount: 4,
          ),
          V2TimConversation(
            conversationID: 'c2c_x',
            type: 1,
            userID: 'x',
            unreadCount: 8,
          ),
        ],
      );

      final result =
          await ConversationLocalStore.instance.markAllUnreadReadLocally(
        scope: MarkReadLocalScope.group,
        excludeConversationIds: {'group_g2'},
      );
      expect(result.conversationCount, 1);
      expect(result.unreadSumBefore, 3);

      final g1 =
          await ConversationLocalStore.instance.conversationById('group_g1');
      final g2 =
          await ConversationLocalStore.instance.conversationById('group_g2');
      final c2c =
          await ConversationLocalStore.instance.conversationById('c2c_x');
      expect(g1?.unreadCount, 0);
      expect(g2?.unreadCount, 4);
      expect(c2c?.unreadCount, 8);
    });
  });
}
