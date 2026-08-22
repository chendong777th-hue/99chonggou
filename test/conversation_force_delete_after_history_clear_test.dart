import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('force delete after history clear', () {
    const owner = 'owner_force_delete';
    const conversationId = 'group_ghost1';

    setUp(() async {
      ConversationSyncService.instance.resetChatTransitionStateForTesting();
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      ConversationLocalStore.instance.resetAnchorStateForTest();
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      await ConversationLocalStore.instance.clearForOwner(owner);
    });

    tearDown(() async {
      ConversationSyncService.instance.resetChatTransitionStateForTesting();
      await ConversationLocalStore.instance.clearForOwner(owner);
      ConversationLocalStore.instance.resetAnchorStateForTest();
    });

    test('force=true deletes shell preserved by history clear', () async {
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: conversationId,
            type: 2,
            groupID: 'ghost1',
          ),
        ],
        ownerUserId: owner,
      );
      await ConversationLocalStore.instance
          .ensureConversationShellAfterHistoryClear(
        conversationId,
        ownerUserId: owner,
      );

      expect(
        ConversationLocalStore.instance
            .shouldSuppressConversationDeletionAfterHistoryClear(
          conversationId,
        ),
        isTrue,
      );

      await ConversationSyncService.instance.persistDeletedForTest(
        [conversationId],
      );
      expect(
        await ConversationLocalStore.instance.conversationById(
          conversationId,
          ownerUserId: owner,
        ),
        isNotNull,
      );

      await ConversationSyncService.instance.persistDeletedForTest(
        [conversationId],
        force: true,
      );
      expect(
        await ConversationLocalStore.instance.conversationById(
          conversationId,
          ownerUserId: owner,
        ),
        isNull,
      );
    });
  });
}
