import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_sync_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

V2TimConversation _c2c({
  required String id,
  int orderkey = 0,
  bool pinned = false,
  String? customData,
}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    unreadCount: 0,
    isPinned: pinned,
    orderkey: orderkey,
    showName: id,
    customData: customData,
  );
}

V2TimConversation _group({required String id, int orderkey = 0}) {
  return V2TimConversation(
    conversationID: id,
    type: 2,
    groupID: id.replaceFirst('group_', ''),
    unreadCount: 0,
    orderkey: orderkey,
    showName: id,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('unlimited flags', () {
    test('sliding window on; no soft ByIds cap', () {
      expect(ConversationPerfFlags.uiSlidingWindowEnabled, isTrue);
      expect(ConversationPerfFlags.uiWindowHardCap, 0);
      expect(ConversationPerfFlags.uiSlidingWindowBudget, 120);
      expect(ConversationPerfFlags.softReloadByIdsMax, lessThanOrEqualTo(0));
      expect(ConversationPerfFlags.upsertWriteCoalesceEnabled, isTrue);
      expect(
        ConversationPerfFlags.upsertWriteCoalesceMaxDelay.inMilliseconds,
        250,
      );
      expect(ConversationPerfFlags.postPopLightReloadEnabled, isTrue);
      expect(ConversationPerfFlags.isolateRowDecodeEnabled, isTrue);
      expect(ConversationPerfFlags.isolateRowDecodeMinRows, 24);
      expect(ConversationPerfFlags.deferUiNotifyWhileFeedScrolling, isTrue);
      expect(ConversationPerfFlags.deferUiNotifyWhileActiveChat, isTrue);
      expect(ConversationPerfFlags.persistUiApplyWhileFeedScrolling, isFalse);
    });
  });

  test('concurrent cold reads share one database open', () async {
    final store = ConversationLocalStore.instance;
    store.debugOwnerUserId = 'open_once_user';
    await store.closeDatabaseForTest();
    final openCountBefore = store.databaseOpenCountForTest;
    try {
      await Future.wait<Object?>([
        store.loadUiWindow(),
        store.countRows(),
        store.readSyncMeta(),
      ]);
      expect(store.databaseOpenCountForTest, openCountBefore + 1);
    } finally {
      await store.clearForOwner('open_once_user');
      store.debugOwnerUserId = null;
    }
  });

  group('selectSoftReloadConversationIds', () {
    test('maxIds<=0 returns full window', () {
      final window = <V2TimConversation>[
        for (var i = 0; i < 400; i++) _c2c(id: 'c2c_$i', orderkey: 100000 - i),
      ];
      final ids = ConversationListNotifier.selectSoftReloadConversationIds(
        window: window,
        anchorId: 'c2c_200',
        maxIds: 0,
      );
      expect(ids.length, 400);
    });

    test('positive maxIds still caps around anchor', () {
      final window = <V2TimConversation>[
        for (var i = 0; i < 400; i++) _c2c(id: 'c2c_$i', orderkey: 100000 - i),
      ];
      final ids = ConversationListNotifier.selectSoftReloadConversationIds(
        window: window,
        anchorId: 'c2c_200',
        maxIds: 120,
      );
      expect(ids.length, lessThanOrEqualTo(120));
      expect(ids.contains('c2c_200'), isTrue);
    });
  });

  group('trimAroundViewportAnchor', () {
    test('budget<=0 is no-op', () {
      final sorted = <V2TimConversation>[
        for (var i = 0; i < 300; i++) _c2c(id: 'c2c_$i', orderkey: 100000 - i),
      ];
      final slide = ConversationListNotifier.trimAroundViewportAnchor(
        sorted,
        anchorId: 'c2c_150',
        budget: 0,
      );
      expect(slide.list.length, 300);
      expect(slide.trimmedFromStart, 0);
      expect(slide.trimmedFromEnd, 0);
    });
  });

  group('A upsert coalesce', () {
    setUp(() {
      ConversationLocalStore.bypassUpsertCoalesceForTest = false;
      ConversationLocalStore.instance.debugOwnerUserId = 'coalesce_user';
    });

    tearDown(() async {
      await ConversationLocalStore.instance.clearForOwner('coalesce_user');
      ConversationListSyncNotifier.instance.clearSession();
      ConversationLocalStore.instance.debugOwnerUserId = null;
      ConversationLocalStore.bypassUpsertCoalesceForTest = true;
    });

    test('concurrent upsertBatch merges by id', () async {
      final f1 = ConversationLocalStore.instance.upsertBatch(
        conversations: [_c2c(id: 'c2c_a', orderkey: 1)],
      );
      final f2 = ConversationLocalStore.instance.upsertBatch(
        conversations: [_c2c(id: 'c2c_b', orderkey: 2)],
      );
      final f3 = ConversationLocalStore.instance.upsertBatch(
        conversations: [_c2c(id: 'c2c_a', orderkey: 3)],
      );
      final results = await Future.wait([f1, f2, f3]);
      expect(results[0].map((c) => c.conversationID), ['c2c_a']);
      expect(results[1].map((c) => c.conversationID), ['c2c_b']);
      expect(results[2].map((c) => c.conversationID), ['c2c_a']);
      await ConversationLocalStore.instance.flushUpsertWriteCoalesceForTest();
      final all = await ConversationLocalStore.instance.loadUiWindow();
      final a = all.where((c) => c.conversationID == 'c2c_a').toList();
      expect(a.length, 1);
      expect(a.first.orderkey, 3);
      expect(all.any((c) => c.conversationID == 'c2c_b'), isTrue);
    });

    test('large upsert is transaction-chunked without dropping rows', () async {
      final conversations = <V2TimConversation>[
        for (var i = 0; i < 405; i++)
          _c2c(id: 'c2c_chunk_$i', orderkey: 100000 - i),
      ];

      final merged = await ConversationLocalStore.instance.upsertBatch(
        conversations: conversations,
      );

      expect(merged, hasLength(conversations.length));
      expect(
        await ConversationLocalStore.instance.countRows(),
        conversations.length,
      );
      expect(
        await ConversationLocalStore.instance.conversationById('c2c_chunk_404'),
        isNotNull,
      );
    });

    test('unchanged persisted conversation returns no downstream patch',
        () async {
      final first = await ConversationLocalStore.instance.upsertBatch(
        conversations: [_c2c(id: 'c2c_unchanged', orderkey: 7)],
      );
      final repeated = await ConversationLocalStore.instance.upsertBatch(
        conversations: [_c2c(id: 'c2c_unchanged', orderkey: 7)],
      );

      expect(first, hasLength(1));
      expect(repeated, isEmpty);
      final stored = await ConversationLocalStore.instance.conversationById(
        'c2c_unchanged',
      );
      expect(stored?.orderkey, 7);
    });

    test('raw-json-only changes are persisted', () async {
      final first = await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          _c2c(
            id: 'c2c_raw_json_changed',
            orderkey: 8,
            customData: 'before',
          ),
        ],
      );
      final changed = await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          _c2c(
            id: 'c2c_raw_json_changed',
            orderkey: 8,
            customData: 'after',
          ),
        ],
      );

      expect(first, hasLength(1));
      expect(changed, hasLength(1));
      final stored = await ConversationLocalStore.instance.conversationById(
        'c2c_raw_json_changed',
      );
      expect(stored?.customData, 'after');
    });

    test('pinned flag diff changes only rows outside the requested set', () {
      final rows = <Map<String, Object?>>[
        <String, Object?>{'conversation_id': 'c2c_pin_a', 'is_pinned': 1},
        <String, Object?>{'conversation_id': 'c2c_pin_b', 'is_pinned': 0},
        <String, Object?>{'conversation_id': 'c2c_pin_c', 'is_pinned': 1},
      ];
      final changes = ConversationLocalStore.pinnedFlagChangesForRows(
        rows: rows,
        matchesPinned: (id) => id == 'c2c_pin_b',
      );

      expect(
        changes,
        <(String, bool)>[
          ('c2c_pin_a', false),
          ('c2c_pin_b', true),
          ('c2c_pin_c', false),
        ],
      );
      expect(
        ConversationLocalStore.pinnedFlagChangesForRows(
          rows: const <Map<String, Object?>>[
            <String, Object?>{
              'conversation_id': 'c2c_pin_a',
              'is_pinned': 0,
            },
            <String, Object?>{
              'conversation_id': 'c2c_pin_b',
              'is_pinned': 1,
            },
            <String, Object?>{
              'conversation_id': 'c2c_pin_c',
              'is_pinned': 0,
            },
          ],
          matchesPinned: (id) => id == 'c2c_pin_b',
        ),
        isEmpty,
      );
    });

    test('arrivals during a write wait for a new quiet window', () async {
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final secondStarted = Completer<void>();
      var invocations = 0;
      ConversationLocalStore.instance.beforeUpsertBatchImplForTest = () async {
        invocations++;
        if (invocations == 1) {
          firstStarted.complete();
          await releaseFirst.future;
        } else if (invocations == 2) {
          secondStarted.complete();
        }
      };

      final first = ConversationLocalStore.instance.upsertBatch(
        conversations: [_c2c(id: 'c2c_first')],
      );
      await firstStarted.future.timeout(const Duration(seconds: 1));
      final second = ConversationLocalStore.instance.upsertBatch(
        conversations: [_c2c(id: 'c2c_second')],
      );

      releaseFirst.complete();
      await first;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(secondStarted.isCompleted, isFalse);
      await secondStarted.future.timeout(const Duration(milliseconds: 300));
      await second;
    });

    test('delete cancels a queued upsert before it reaches SQLite', () async {
      final pending = ConversationLocalStore.instance.upsertBatch(
        conversations: [_c2c(id: 'c2c_pending_delete')],
      );

      await ConversationLocalStore.instance.deleteBatch(
        conversationIds: const ['c2c_pending_delete'],
      );

      expect(await pending, isEmpty);
      await ConversationLocalStore.instance.flushUpsertWriteCoalesceForTest();
      expect(
        await ConversationLocalStore.instance.conversationById(
          'c2c_pending_delete',
        ),
        isNull,
      );
    });

    test('typed delete does not confuse c2c and group ids', () async {
      await Future.wait([
        ConversationLocalStore.instance.upsertBatch(
          conversations: [_c2c(id: 'c2c_same_peer')],
        ),
        ConversationLocalStore.instance.upsertBatch(
          conversations: [_group(id: 'group_same_peer')],
        ),
      ]);

      final deleted = await ConversationLocalStore.instance.deleteBatch(
        conversationIds: const ['c2c_same_peer'],
      );

      expect(deleted, ['c2c_same_peer']);
      expect(
        await ConversationLocalStore.instance.conversationById(
          'group_same_peer',
        ),
        isNotNull,
      );
    });

    test('UIKit page callback does not overwrite the SDK cursor', () async {
      await ConversationLocalStore.instance.writeSyncMeta(
        meta: const ConversationSyncMeta(
          nextSeq: 'sdk_next',
          haveMore: true,
          hasSyncedOnce: true,
        ),
      );

      await ConversationSyncService.instance.onViewModelPageLoaded(
        conversations: const <V2TimConversation?>[],
        isRefresh: true,
        nextSeq: 'uikit_next',
        haveMoreData: false,
        hasLoadedOnce: true,
      );

      final meta = await ConversationLocalStore.instance.readSyncMeta();
      expect(meta.nextSeq, 'sdk_next');
      expect(meta.haveMore, isTrue);
      expect(meta.hasSyncedOnce, isTrue);
    });
  });
}
