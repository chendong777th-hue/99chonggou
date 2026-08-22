import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

V2TimConversation _c2c({
  required String id,
  required int activeSec,
}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    draftTimestamp: activeSec,
    orderkey: activeSec,
    showName: id,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('exclude query serialization', () {
    const owner = 'archive_sync_exclude_owner';

    setUp(() async {
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      await ConversationLocalStore.instance.clearForOwner(owner);
    });

    tearDown(() async {
      await ConversationLocalStore.instance.clearForOwner(owner);
      ConversationLocalStore.instance.debugOwnerUserId = null;
    });

    test('parallel exclude COUNT stays correct', () async {
      final items = <V2TimConversation>[
        for (var i = 0; i < 20; i++)
          _c2c(id: 'c2c_ex$i', activeSec: 1700000000 + i),
      ];
      await ConversationLocalStore.instance.upsertBatch(conversations: items);

      final excludeA = {'c2c_ex0', 'c2c_ex1', 'c2c_ex2'};
      final excludeB = {'c2c_ex0'};

      final futures = <Future<int>>[
        for (var i = 0; i < 8; i++)
          ConversationLocalStore.instance.countByConvType(
            convType: 1,
            excludeConversationIds: i.isEven ? excludeA : excludeB,
          ),
      ];
      final results = await Future.wait(futures);

      for (var i = 0; i < results.length; i++) {
        expect(
          results[i],
          i.isEven ? 17 : 19,
          reason: 'index=$i',
        );
      }
    });
  });

  group('syncMainListAfterArchiveChange', () {
    const owner = 'archive_sync_main_owner';
    late ConversationListNotifier notifier;

    setUp(() async {
      ConversationLocalStore.bypassUpsertCoalesceForTest = true;
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      await ConversationLocalStore.instance.clearForOwner(owner);
      archivedConversationC2cIDsNotifier.value = <String>{};
      archivedConversationGroupIDsNotifier.value = <String>{};
      notifier = ConversationListNotifier.instance;
      notifier.clearSession();
    });

    tearDown(() async {
      notifier.clearSession();
      archivedConversationC2cIDsNotifier.value = <String>{};
      archivedConversationGroupIDsNotifier.value = <String>{};
      await ConversationLocalStore.instance.clearForOwner(owner);
      ConversationLocalStore.instance.debugOwnerUserId = null;
      ConversationLocalStore.bypassUpsertCoalesceForTest = false;
    });

    test('removedIds purge from UI window', () async {
      final a = _c2c(id: 'c2c_keep', activeSec: 100);
      final b = _c2c(id: 'c2c_gone', activeSec: 90);
      await ConversationLocalStore.instance.upsertBatch(conversations: [a, b]);
      notifier.setConversationsForTest([a, b]);

      archivedConversationC2cIDsNotifier.value = {'c2c_gone'};
      await notifier.syncMainListAfterArchiveChange(
        removedIds: const ['c2c_gone'],
        reason: 'test_remove',
      );

      expect(
        notifier.conversations.map((c) => c.conversationID),
        ['c2c_keep'],
      );
    });

    test('restoredIds re-admit into UI window', () async {
      final a = _c2c(id: 'c2c_keep2', activeSec: 200);
      final b = _c2c(id: 'c2c_back', activeSec: 180);
      await ConversationLocalStore.instance.upsertBatch(conversations: [a, b]);
      notifier.setConversationsForTest([a]);
      archivedConversationC2cIDsNotifier.value = <String>{};

      await notifier.syncMainListAfterArchiveChange(
        restoredIds: const ['c2c_back'],
        reason: 'test_restore',
      );

      expect(
        notifier.conversations.any((c) => c.conversationID == 'c2c_back'),
        isTrue,
      );
      expect(
        notifier.conversations.any((c) => c.conversationID == 'c2c_keep2'),
        isTrue,
      );
    });

    test('restoredIds appear in type hydrate for virtual list', () async {
      final a = _c2c(id: 'c2c_keep3', activeSec: 300);
      final b = _c2c(id: 'c2c_back3', activeSec: 280);
      await ConversationLocalStore.instance.upsertBatch(conversations: [a, b]);
      notifier.setConversationsForTest([a]);
      // 模拟归档 purge：hydrate 头窗只有 keep，没有 back。
      notifier.setTypeHydrateForTest(
        convType: 1,
        page: [a],
        start: 0,
        total: 1,
      );
      archivedConversationC2cIDsNotifier.value = <String>{};

      await notifier.syncMainListAfterArchiveChange(
        restoredIds: const ['c2c_back3'],
        reason: 'test_restore_hydrate',
      );

      expect(
        notifier.conversations.any((c) => c.conversationID == 'c2c_back3'),
        isTrue,
      );
      expect(
        notifier.conversationAtTypeIndex(1, 0)?.conversationID,
        isNotNull,
      );
      final pageIds = <String>[];
      for (var i = 0; i < 8; i++) {
        final row = notifier.conversationAtTypeIndex(1, i);
        if (row == null) {
          break;
        }
        pageIds.add(row.conversationID);
      }
      expect(pageIds.contains('c2c_back3'), isTrue);
    });

    test('single-flight coalesces restored while in flight', () async {
      final items = <V2TimConversation>[
        _c2c(id: 'c2c_sf0', activeSec: 300),
        _c2c(id: 'c2c_sf1', activeSec: 290),
        _c2c(id: 'c2c_sf2', activeSec: 280),
      ];
      await ConversationLocalStore.instance.upsertBatch(conversations: items);
      notifier.setConversationsForTest([items.first]);

      final first = notifier.syncMainListAfterArchiveChange(
        restoredIds: const ['c2c_sf1'],
        reason: 'sf_a',
      );
      final second = notifier.syncMainListAfterArchiveChange(
        restoredIds: const ['c2c_sf2'],
        reason: 'sf_b',
      );
      await Future.wait([first, second]);

      expect(
        notifier.conversations.any((c) => c.conversationID == 'c2c_sf1'),
        isTrue,
      );
      expect(
        notifier.conversations.any((c) => c.conversationID == 'c2c_sf2'),
        isTrue,
      );
      expect(notifier.pendingArchiveRestoredCountForTest, 0);
      expect(notifier.archiveSyncInFlightForTest, isFalse);
    });
  });
}
