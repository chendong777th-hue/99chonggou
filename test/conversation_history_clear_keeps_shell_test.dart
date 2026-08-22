import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('history clear removes conversation from list', () {
    const owner = 'owner_history_clear_shell';
    const conversationId = 'c2c_peer_archived';

    setUp(() async {
      ConversationSyncService.instance.resetChatTransitionStateForTesting();
      ConversationLocalStore.instance.resetAnchorStateForTest();
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      await ConversationLocalStore.instance.clearForOwner(owner);
      ConversationListNotifier.instance.clearSession();
    });

    tearDown(() async {
      ArchiveHistoryProvider.clearHistoryClearPending(conversationId);
      ConversationSyncService.instance.resetChatTransitionStateForTesting();
      await ConversationLocalStore.instance.clearForOwner(owner);
      ConversationListNotifier.instance.clearSession();
      ConversationLocalStore.instance.resetAnchorStateForTest();
    });

    test('suppress deletion matches c2c alias after clear', () async {
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_archived',
          ),
        ],
        ownerUserId: owner,
      );
      await ConversationLocalStore.instance.clearConversationLastMessage(
        conversationId,
        ownerUserId: owner,
      );

      expect(
        ConversationLocalStore.instance
            .shouldSuppressConversationDeletionAfterHistoryClear(
          'peer_archived',
        ),
        isTrue,
      );
      expect(
        ConversationLocalStore.instance
            .shouldSuppressConversationDeletionAfterHistoryClear(
          conversationId,
        ),
        isTrue,
      );
    });

    test('force delete after clear removes from list notifier', () async {
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_archived',
          ),
        ],
        ownerUserId: owner,
      );
      await ConversationListNotifier.instance.reloadFromLocal();
      expect(ConversationListNotifier.instance.conversations, isNotEmpty);

      ArchiveHistoryProvider.markHistoryClearPending(conversationId);
      await ConversationLocalStore.instance.clearConversationLastMessage(
        conversationId,
        ownerUserId: owner,
      );

      await ConversationSyncService.instance.persistDeletedForTest(
        [conversationId],
        force: true,
      );

      final stillThere = ConversationListNotifier.instance.conversations.any(
        (c) => c.conversationID == conversationId,
      );
      expect(stillThere, isFalse);
      expect(
        await ConversationLocalStore.instance.conversationById(
          conversationId,
          ownerUserId: owner,
        ),
        isNull,
      );
    });

    test('non-force suppress is no-op and does not re-pin shell', () async {
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_archived',
          ),
        ],
        ownerUserId: owner,
      );
      await ConversationListNotifier.instance.reloadFromLocal();
      ArchiveHistoryProvider.markHistoryClearPending(conversationId);
      await ConversationLocalStore.instance.clearConversationLastMessage(
        conversationId,
        ownerUserId: owner,
      );

      await ConversationSyncService.instance.persistDeletedForTest(
        [conversationId],
      );

      // suppress 时既不删也不回钉；行仍在（预览已空）。生产路径一律 force。
      expect(
        await ConversationLocalStore.instance.conversationById(
          conversationId,
          ownerUserId: owner,
        ),
        isNotNull,
      );
    });
  });
}
