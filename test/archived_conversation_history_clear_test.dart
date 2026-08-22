import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/archived_conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const owner = 'owner_archive_clear';
  const peerId = 'peer_archived_x';
  const conversationId = 'c2c_$peerId';

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setArchivedConversationAccountScopeResolverForTest(() => owner);
    clearArchivedConversationSessionState();
    ArchiveHistoryProvider.clearHistoryClearPending(conversationId);
  });

  tearDown(() {
    ArchiveHistoryProvider.clearHistoryClearPending(conversationId);
    setArchivedConversationAccountScopeResolverForTest(null);
    clearArchivedConversationSessionState();
  });

  group('archived conversation survives history clear', () {
    test('unarchive realtime event ignored during history clear grace',
        () async {
      await saveArchivedConversationIDs(
        ConversationArchiveScope.c2c,
        {conversationId},
      );

      ArchiveHistoryProvider.markHistoryClearPending(conversationId);

      await ArchivedConversationSyncService.instance.handleRealtimeEvent(
        FriendRealtimeEvent.fromJson(<String, dynamic>{
          'event': 'conversation_archive_changed',
          'chatType': 'c2c',
          'peerId': peerId,
          'archived': false,
        }),
      );

      expect(
        archivedConversationC2cIDsNotifier.value.contains(conversationId),
        isTrue,
      );
    });

    test('unarchive realtime event applied outside grace', () async {
      await saveArchivedConversationIDs(
        ConversationArchiveScope.c2c,
        {conversationId},
      );

      await ArchivedConversationSyncService.instance.handleRealtimeEvent(
        FriendRealtimeEvent.fromJson(<String, dynamic>{
          'event': 'conversation_archive_changed',
          'chatType': 'c2c',
          'peerId': peerId,
          'archived': false,
        }),
      );

      expect(
        archivedConversationC2cIDsNotifier.value.contains(conversationId),
        isFalse,
      );
    });

    test('reassert keeps local archived id pinned', () async {
      await saveArchivedConversationIDs(
        ConversationArchiveScope.c2c,
        {conversationId},
      );

      // 服务端上报会失败（测试无网络），但本地集合必须保持归档。
      await ArchivedConversationSyncService.instance
          .reassertArchivedAfterHistoryClear(
        isGroup: false,
        peerId: peerId,
      );

      expect(
        archivedConversationC2cIDsNotifier.value.contains(conversationId),
        isTrue,
      );
    });

    test('reassert is a no-op for conversations never archived', () async {
      await ArchivedConversationSyncService.instance
          .reassertArchivedAfterHistoryClear(
        isGroup: false,
        peerId: peerId,
      );

      expect(
        archivedConversationC2cIDsNotifier.value.contains(conversationId),
        isFalse,
      );
    });
  });
}
