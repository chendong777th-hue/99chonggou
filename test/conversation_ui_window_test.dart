import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

V2TimConversation _c2c({
  required String id,
  int unread = 0,
  bool pinned = false,
  int orderkey = 0,
  String showName = 'n',
}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    unreadCount: unread,
    isPinned: pinned,
    orderkey: orderkey,
    showName: showName,
  );
}

V2TimConversation _group({
  required String id,
  int orderkey = 0,
  String showName = 'g',
  int unread = 0,
  bool pinned = false,
}) {
  final gid = id.replaceFirst('group_', '');
  return V2TimConversation(
    conversationID: id,
    type: 2,
    groupID: gid,
    unreadCount: unread,
    isPinned: pinned,
    orderkey: orderkey,
    showName: showName,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ui window snapshot', () {
    late ConversationListNotifier notifier;

    setUp(() {
      ConversationLocalStore.bypassUpsertCoalesceForTest = true;
      ConversationLocalStore.instance.debugOwnerUserId = 'window_test_user';
      notifier = ConversationListNotifier.instance;
    });

    tearDown(() async {
      notifier.clearSession();
      await ConversationLocalStore.instance.clearForOwner('window_test_user');
      ConversationLocalStore.instance.debugOwnerUserId = null;
      ConversationLocalStore.bypassUpsertCoalesceForTest = false;
    });

    test('hard cap off; sliding trim on (budget 120); snapshot 40+40', () {
      expect(ConversationPerfFlags.uiWindowHardCapEnabled, isFalse);
      expect(ConversationPerfFlags.uiWindowHardCap, lessThanOrEqualTo(0));
      expect(ConversationPerfFlags.uiSlidingWindowActive, isTrue);
      expect(ConversationPerfFlags.uiSlidingWindowEnabled, isTrue);
      expect(ConversationPerfFlags.uiSlidingWindowBudget, 120);
      expect(ConversationPerfFlags.softReloadByIdsMax, lessThanOrEqualTo(0));
      expect(ConversationPerfFlags.sdkSyncAdmitColdConversations, isFalse);
      expect(ConversationPerfFlags.uiSnapshotEnabled, isTrue);
      expect(ConversationPerfFlags.uiSnapshotC2cLimit, 40);
      expect(ConversationPerfFlags.uiSnapshotGroupLimit, 40);
      expect(ConversationPerfFlags.uiViewportFillMaxPages, 3);
    });

    test('reloadFromLocal loads at most c2c snapshot for large c2c table',
        () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 200; i++) {
        seed.add(_c2c(id: 'c2c_full_$i', orderkey: 200000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();

      final rows = await ConversationLocalStore.instance.countRows();
      expect(rows, 200);
      expect(
        notifier.conversations.length,
        ConversationPerfFlags.uiSnapshotC2cLimit,
      );
      expect(notifier.conversations.first.conversationID, 'c2c_full_0');
    });

    test('virtual hydrate can jump directly to a restored distant viewport',
        () async {
      if (!ConversationPerfFlags.conversationVirtualListEnabled) {
        return;
      }
      final seed = <V2TimConversation>[
        for (var i = 0; i < 240; i++)
          _c2c(id: 'c2c_jump_$i', orderkey: 800000 - i),
      ];
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();

      expect(notifier.conversationAtTypeIndex(1, 180), isNull);

      await notifier.ensureTypeIndexHydrated(
        convType: 1,
        centerIndex: 180,
        forceReload: true,
        allowWindowJump: true,
      );

      expect(
        notifier.conversationAtTypeIndex(1, 180)?.conversationID,
        'c2c_jump_180',
      );
    });

    test('snapshot seed keeps distant hydrate window', () {
      if (!ConversationPerfFlags.conversationVirtualListEnabled) {
        return;
      }
      final hot = <V2TimConversation>[
        for (var i = 0; i < 40; i++)
          _c2c(id: 'c2c_hot_seed_$i', orderkey: 900000 - i),
      ];
      final distant = _c2c(id: 'c2c_hv4sm5pfoe', orderkey: 1);
      notifier.setConversationsForTest(hot);
      notifier.setTypeHydrateForTest(
        convType: 1,
        page: <V2TimConversation>[distant],
        start: 80,
        total: 200,
      );
      expect(notifier.isTypeIndexLiveHydrated(1, 80), isTrue);
      expect(notifier.isTypeIndexLiveHydrated(1, 0), isFalse);
      notifier.seedHydratesFromConversationsForTest();
      expect(notifier.hydratedStartOffsetForType(1), 80);
      expect(
        notifier.conversationAtTypeIndex(1, 80)?.conversationID,
        'c2c_hv4sm5pfoe',
      );
    });

    test('virtual hydrate while scrolling caches adjacent page only', () async {
      if (!ConversationPerfFlags.conversationVirtualListEnabled) {
        return;
      }
      final seed = <V2TimConversation>[
        for (var i = 0; i < 180; i++)
          _c2c(id: 'c2c_scroll_$i', orderkey: 700000 - i),
      ];
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(notifier.conversationAtTypeIndex(1, 80), isNull);

      var notifyCount = 0;
      void onNotify() => notifyCount++;
      notifier.addListener(onNotify);
      addTearDown(() => notifier.removeListener(onNotify));
      notifier.isFeedScrolling = () => true;

      await notifier.ensureTypeIndexHydrated(
        convType: 1,
        centerIndex: 80,
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
        notifier.conversationAtTypeIndex(1, 80)?.conversationID,
        'c2c_scroll_80',
      );
      expect(
        notifier.conversations.any((c) => c.conversationID == 'c2c_scroll_80'),
        isFalse,
      );
      expect(notifyCount, 0);

      notifier.isFeedScrolling = () => false;
      await notifier.ensureTypeIndexHydrated(
        convType: 1,
        centerIndex: 80,
        forceReload: true,
      );

      expect(
        notifier.conversations.any((c) => c.conversationID == 'c2c_scroll_80'),
        isTrue,
      );
      expect(notifyCount, greaterThan(0));
    });

    test('cold pinned outside snapshot limit still enters loadUiWindow',
        () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 80; i++) {
        // 近期会话占满 snapshot；isPinned=false 模拟列未对齐。
        seed.add(_c2c(id: 'c2c_hot_$i', orderkey: 900000 - i));
      }
      // 很旧的置顶会话：按 active_time 进不了 LIMIT 40。
      seed.add(
        _c2c(id: 'c2c_cold_pinned', orderkey: 1, pinned: false),
      );
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);

      ConversationPinSyncService.instance.debugReplacePinnedIdsForTest([
        'c2c_cold_pinned',
      ]);
      try {
        final window = await ConversationLocalStore.instance.loadUiWindow();
        expect(
          window.any((c) => c.conversationID == 'c2c_cold_pinned'),
          isTrue,
        );
        final pinned = window.firstWhere(
          (c) => c.conversationID == 'c2c_cold_pinned',
        );
        expect(pinned.isPinned, isTrue);

        await notifier.reloadFromLocal();
        expect(
          notifier.conversations.any(
            (c) => c.conversationID == 'c2c_cold_pinned',
          ),
          isTrue,
        );
        expect(
          notifier.conversations.first.conversationID,
          'c2c_cold_pinned',
        );
      } finally {
        ConversationPinSyncService.instance.debugReplacePinnedIdsForTest(
          const <String>[],
        );
      }
    });

    test('reloadFromLocal loads c2c+group snapshot caps', () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 60; i++) {
        seed.add(_c2c(id: 'c2c_s_$i', orderkey: 300000 - i));
        seed.add(_group(id: 'group_s_$i', orderkey: 200000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();

      final rows = await ConversationLocalStore.instance.countRows();
      expect(rows, 120);
      final c2c =
          notifier.conversations.where((c) => (c.type ?? 0) == 1).length;
      final group =
          notifier.conversations.where((c) => (c.type ?? 0) == 2).length;
      expect(c2c, ConversationPerfFlags.uiSnapshotC2cLimit);
      expect(group, ConversationPerfFlags.uiSnapshotGroupLimit);
      expect(
        notifier.conversations.length,
        ConversationPerfFlags.uiSnapshotC2cLimit +
            ConversationPerfFlags.uiSnapshotGroupLimit,
      );
    });

    test('shouldAdmit: below type floor cold true; at floor false; hot true',
        () {
      notifier.setConversationsForTest([
        _c2c(id: 'c2c_in_window', orderkey: 100),
      ]);
      expect(
        notifier.shouldAdmitToUiWindow(_c2c(id: 'c2c_cold', orderkey: 1)),
        isTrue,
      );
      expect(
        notifier.shouldAdmitToUiWindow(
          _c2c(id: 'c2c_unread', unread: 2, orderkey: 1),
        ),
        isTrue,
      );
      expect(
        notifier.shouldAdmitToUiWindow(
          _c2c(id: 'c2c_pin', pinned: true, orderkey: 1),
        ),
        isTrue,
      );

      notifier.setConversationsForTest([
        for (var i = 0; i < ConversationPerfFlags.uiSnapshotC2cLimit; i++)
          _c2c(id: 'c2c_floor_$i', orderkey: 100000 - i),
      ]);
      expect(
        notifier.shouldAdmitToUiWindow(_c2c(id: 'c2c_over_floor', orderkey: 1)),
        isFalse,
      );
      expect(
        notifier.shouldAdmitToUiWindow(
          _c2c(id: 'c2c_unread_over', unread: 1, orderkey: 1),
        ),
        isTrue,
      );
    });

    test('shouldBlockSnapshotWindowReload when user expanded', () {
      expect(
        ConversationListNotifier.shouldBlockSnapshotWindowReload(
          userExpanded: true,
          scrolling: false,
          pageLoadInFlight: false,
          windowNonEmpty: true,
        ),
        isTrue,
      );
      expect(
        ConversationListNotifier.shouldBlockSnapshotWindowReload(
          userExpanded: false,
          scrolling: false,
          pageLoadInFlight: false,
          windowNonEmpty: true,
        ),
        isFalse,
      );
      expect(
        ConversationListNotifier.shouldBlockSnapshotWindowReload(
          userExpanded: false,
          scrolling: true,
          pageLoadInFlight: false,
          windowNonEmpty: true,
        ),
        isTrue,
      );
      expect(
        ConversationListNotifier.shouldBlockSnapshotWindowReload(
          userExpanded: true,
          scrolling: false,
          pageLoadInFlight: false,
          windowNonEmpty: false,
        ),
        isFalse,
      );
    });

    test('reloadFromLocal merge-preserves expanded list and refreshes fields',
        () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 50; i++) {
        seed.add(_c2c(id: 'c2c_store_$i', orderkey: 200000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();
      expect(
        notifier.conversations.length,
        ConversationPerfFlags.uiSnapshotC2cLimit,
      );

      final olderSlide = await notifier.appendOlderFromLocal(convType: 1);
      expect(olderSlide.changed, isTrue);
      expect(notifier.slidingWindowUserExpanded, isTrue);
      final expandedLen = notifier.conversations.length;
      expect(
          expandedLen, greaterThan(ConversationPerfFlags.uiSnapshotC2cLimit));

      // 无上限后 merge-preserve 禁止整窗 ByIds：热快照内字段会刷新；列表长度不裁回。
      final patched = _c2c(id: 'c2c_store_0', orderkey: 200000, unread: 3);
      await ConversationLocalStore.instance
          .upsertBatch(conversations: [patched]);
      await notifier.reloadFromLocal();
      expect(notifier.conversations.length, expandedLen);
      expect(
        notifier.conversations.any((c) => c.conversationID == 'c2c_store_40'),
        isTrue,
      );
      final row = notifier.conversations.firstWhere(
        (c) => c.conversationID == 'c2c_store_0',
      );
      expect(row.unreadCount, 3);
    });

    test('applyWindowPatches grows window with cold upserts until type floor',
        () async {
      notifier.setConversationsForTest([
        _c2c(id: 'c2c_w_0', orderkey: 100000),
      ]);
      await notifier.applyWindowPatchesIfNeeded(
        upserted: [
          for (var i = 1; i < 10; i++)
            _c2c(id: 'c2c_cold_$i', orderkey: 100000 - i),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(notifier.conversations.length, 10);
    });

    test('applyWindowPatches does not grow past type floor with cold upserts',
        () async {
      notifier.setConversationsForTest([
        for (var i = 0; i < 40; i++) _c2c(id: 'c2c_w_$i', orderkey: 100000 - i),
      ]);
      final before = notifier.conversations.length;
      await notifier.applyWindowPatchesIfNeeded(
        upserted: [
          for (var i = 0; i < 80; i++)
            _c2c(id: 'c2c_cold_$i', orderkey: 10 - (i % 10)),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(notifier.conversations.length, before);
    });

    test('applyWindowPatchesIfNeeded keeps hot upsert under sliding budget',
        () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 350; i++) {
        seed.add(_c2c(id: 'c2c_$i', orderkey: 100000 - i));
      }
      notifier.setConversationsForTest(seed);

      await notifier.applyWindowPatchesIfNeeded(
        upserted: [
          _c2c(id: 'c2c_new_hot', unread: 5, orderkey: 200000),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        notifier.conversations.length,
        lessThanOrEqualTo(ConversationPerfFlags.uiSlidingWindowBudget),
      );
      expect(
        notifier.conversations.any((c) => c.conversationID == 'c2c_new_hot'),
        isTrue,
      );
    });

    test('appendOlderFromLocal can grow past snapshot without hard cap',
        () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 120; i++) {
        seed.add(_c2c(id: 'c2c_a_$i', orderkey: 500000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();
      expect(notifier.conversations.length, 40);

      await notifier.appendOlderFromLocal(convType: 1);
      expect(notifier.conversations.length, 80);
      await notifier.appendOlderFromLocal(convType: 1);
      expect(notifier.conversations.length, 120);
    });

    test('sliding window: further append grows past budget', () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 300; i++) {
        seed.add(_c2c(id: 'c2c_slide_$i', orderkey: 900000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();
      expect(notifier.conversations.length, 40);
      expect(notifier.conversations.first.conversationID, 'c2c_slide_0');

      var addedAny = false;
      ConversationWindowSlideResult? last;
      for (var i = 0; i < 5; i++) {
        last = await notifier.appendOlderFromLocal(convType: 1);
        if ((last?.added ?? 0) > 0) {
          addedAny = true;
        }
      }
      // 虚拟列表 softCap = 水合上限；触顶后再 append 可能 added=0。
      expect(
        notifier.conversations.length,
        ConversationPerfFlags.virtualHydrateMaxPerType,
      );
      expect(
        notifier.conversations.length,
        lessThanOrEqualTo(
          ConversationPerfFlags.conversationVirtualListEnabled
              ? ConversationPerfFlags.virtualHydrateMaxPerType
              : (ConversationPerfFlags.uiAppendOlderEmergencyMaxPerType > 0
                  ? ConversationPerfFlags.uiAppendOlderEmergencyMaxPerType
                  : ConversationPerfFlags.uiAppendOlderMaxPerType),
        ),
      );
      expect(addedAny, isTrue);
      expect(last, isNotNull);
    });

    test('append older soft-caps window and keeps loading newer pages',
        () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 700; i++) {
        seed.add(_c2c(id: 'c2c_cap_$i', orderkey: 900000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();

      if (ConversationPerfFlags.conversationVirtualListEnabled) {
        // 真虚拟列表：禁止头裁换窗；水合/窗受 softCap；可滚总数独立。
        ConversationWindowSlideResult? last;
        for (var i = 0; i < 30; i++) {
          last = await notifier.appendOlderFromLocal(convType: 1);
          if (!last.changed) {
            break;
          }
          expect(last.trimmedFromStart, 0, reason: '虚拟列表禁止整批头裁');
          expect(
            notifier.conversations.where((c) => c.type == 1).length,
            lessThanOrEqualTo(ConversationPerfFlags.uiAppendOlderMaxPerType),
          );
        }
        expect(notifier.totalCountForType(1), 700);
        expect(last?.trimmedFromStart ?? 0, 0);
        return;
      }

      final appendCap =
          ConversationPerfFlags.uiAppendOlderEmergencyMaxPerType > 0
              ? ConversationPerfFlags.uiAppendOlderEmergencyMaxPerType
              : ConversationPerfFlags.uiAppendOlderMaxPerType;
      var sawTrim = false;
      var sawGrowPastSoft = false;
      ConversationWindowSlideResult? last;
      for (var i = 0; i < 30; i++) {
        last = await notifier.appendOlderFromLocal(convType: 1);
        if (!last.changed) {
          break;
        }
        final typed = notifier.conversations.where((c) => c.type == 1).length;
        expect(
          typed,
          lessThanOrEqualTo(appendCap),
          reason: '单聊紧急上限，避免无上限卡死',
        );
        if (typed > ConversationPerfFlags.uiAppendOlderMaxPerType) {
          sawGrowPastSoft = true;
        }
        if (last.trimmedFromStart > 0) {
          sawTrim = true;
        }
      }
      expect(
        sawGrowPastSoft,
        isTrue,
        reason: '软顶内应继续长大，体感往下加载而不是立刻换批',
      );
      expect(sawTrim, isTrue, reason: '超过紧急上限后应裁掉更热单聊');
      expect(
        notifier.conversations.where((c) => c.type == 1).length,
        appendCap,
      );
    });

    test('group soft-cap keeps pinned when trimming hotter groups', () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 40; i++) {
        seed.add(_c2c(id: 'c2c_pinkeep_$i', orderkey: 50000 - i));
      }
      seed.add(
        _group(id: 'group_pin_keep', orderkey: 1000, showName: 'pinned'),
      );
      for (var i = 0; i < 300; i++) {
        seed.add(_group(id: 'group_hot_pin_$i', orderkey: 800000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      ConversationPinSyncService.instance.debugReplacePinnedIdsForTest([
        'group_pin_keep',
      ]);
      try {
        await notifier.reloadFromLocal();
        expect(
          notifier.conversations
              .any((c) => c.conversationID == 'group_pin_keep'),
          isTrue,
        );
        for (var i = 0; i < 10; i++) {
          final slide = await notifier.appendOlderFromLocal(convType: 2);
          if (!slide.changed) {
            break;
          }
        }
        expect(
          notifier.conversations
              .any((c) => c.conversationID == 'group_pin_keep'),
          isTrue,
          reason: '触底软裁不得丢掉置顶',
        );
      } finally {
        ConversationPinSyncService.instance.debugReplacePinnedIdsForTest(
          const <String>[],
        );
      }
    });

    test('scheme C: scroll-top restores hot prefix then append is continuous',
        () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 40; i++) {
        seed.add(_c2c(id: 'c2c_cont_$i', orderkey: 50000 - i));
      }
      for (var i = 0; i < 400; i++) {
        seed.add(_group(id: 'group_cont_$i', orderkey: 900000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();

      for (var i = 0; i < 12; i++) {
        final slide = await notifier.appendOlderFromLocal(convType: 2);
        if (!slide.changed) {
          break;
        }
      }
      // 普通上拉只连续 prepend，不整窗跳热前缀。
      await notifier.prependNewerFromLocal(convType: 2);
      // 显式回到顶部才滑热前缀。
      await notifier.slideToHotPrefix(convType: 2);
      expect(
        notifier.conversations.any((c) => c.conversationID == 'group_cont_0'),
        isTrue,
        reason: '回到顶部必须滑回库序热前缀',
      );
      // 两阶段：Phase1 后 typed 至少热头 reserve；等 Phase2 补满。
      final typedAfterPhase1 =
          notifier.conversations.where((c) => c.type == 2).length;
      expect(
        typedAfterPhase1,
        greaterThanOrEqualTo(ConversationPerfFlags.uiAppendOlderHotHeadReserve),
      );
      // 等 Phase2 后台补齐（或用户未打断时保持）。
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await pumpEventQueue();
        final typed = notifier.conversations.where((c) => c.type == 2).length;
        if (typed >= ConversationPerfFlags.uiAppendOlderMaxPerType) {
          break;
        }
      }
      final typedAfterPhase2 =
          notifier.conversations.where((c) => c.type == 2).length;
      expect(
        typedAfterPhase2,
        greaterThanOrEqualTo(typedAfterPhase1),
        reason: 'Phase2 应补齐或保持热前缀',
      );

      final idsBefore = notifier.conversations
          .where((c) => c.type == 2)
          .map((c) => c.conversationID)
          .toSet();
      final again = await notifier.appendOlderFromLocal(convType: 2);
      expect(again.changed, isTrue, reason: '回顶重置游标后应能继续触底');
      final idsAfter = notifier.conversations
          .where((c) => c.type == 2)
          .map((c) => c.conversationID)
          .toSet();
      expect(
        idsAfter.difference(idsBefore),
        isNotEmpty,
        reason: '再下滑应补上热前缀之后的连续页',
      );
      final groupOrderKeys = notifier.conversations
          .where((c) => c.type == 2 && c.isPinned != true)
          .map((c) => c.orderkey ?? 0)
          .toList();
      for (var i = 1; i < groupOrderKeys.length; i++) {
        expect(
          groupOrderKeys[i] <= groupOrderKeys[i - 1],
          isTrue,
          reason: '视口窗内非置顶群须时间序连续不升序断层',
        );
      }
    });

    test('scheme C: gradual prepend stays continuous without hot jump',
        () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 40; i++) {
        seed.add(_c2c(id: 'c2c_grad_$i', orderkey: 50000 - i));
      }
      for (var i = 0; i < 400; i++) {
        seed.add(_group(id: 'group_grad_$i', orderkey: 900000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();
      for (var i = 0; i < 12; i++) {
        final slide = await notifier.appendOlderFromLocal(convType: 2);
        if (!slide.changed) {
          break;
        }
      }
      final beforeHot =
          notifier.conversations.any((c) => c.conversationID == 'group_grad_0');
      final prepend = await notifier.prependNewerFromLocal(convType: 2);
      expect(prepend.changed || !beforeHot, isTrue);
      // 普通上拉不应直接整窗跳到最热（除非本来就在热端附近）。
      final afterIds = notifier.conversations
          .where((c) => c.type == 2)
          .map((c) => c.conversationID)
          .toList();
      final keys = notifier.conversations
          .where((c) => c.type == 2 && c.isPinned != true)
          .map((c) => c.orderkey ?? 0)
          .toList();
      for (var i = 1; i < keys.length; i++) {
        expect(keys[i] <= keys[i - 1], isTrue);
      }
      expect(afterIds, isNotEmpty);
    });

    test('group append soft-cap never wipes c2c tab floor', () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 40; i++) {
        seed.add(_c2c(id: 'c2c_keep_tab_$i', orderkey: 50000 - i));
      }
      for (var i = 0; i < 400; i++) {
        seed.add(_group(id: 'group_cap_$i', orderkey: 800000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();
      expect(
        notifier.conversations.where((c) => c.type == 1).length,
        ConversationPerfFlags.uiSnapshotC2cLimit,
      );

      for (var i = 0; i < 10; i++) {
        final slide = await notifier.appendOlderFromLocal(convType: 2);
        if (!slide.changed) {
          break;
        }
      }
      expect(
        notifier.conversations.where((c) => c.type == 1).length,
        greaterThanOrEqualTo(ConversationPerfFlags.uiSnapshotC2cLimit),
        reason: '滑群裁窗不得把单聊 tab 挤空',
      );
      expect(
        notifier.conversations.where((c) => c.type == 2).length,
        lessThanOrEqualTo(
          ConversationPerfFlags.conversationVirtualListEnabled
              ? ConversationPerfFlags.uiAppendOlderMaxPerType
              : (ConversationPerfFlags.uiAppendOlderEmergencyMaxPerType > 0
                  ? ConversationPerfFlags.uiAppendOlderEmergencyMaxPerType
                  : ConversationPerfFlags.uiAppendOlderMaxPerType),
        ),
      );
    });

    test('append older groups keeps c2c floor and advances past unread flood',
        () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 40; i++) {
        seed.add(_c2c(id: 'c2c_keep_$i', orderkey: 800000 - i));
      }
      for (var i = 0; i < 200; i++) {
        seed.add(
          _group(
            id: 'group_u_$i',
            orderkey: 700000 - i,
            unread: 1,
          ),
        );
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();
      expect(
        notifier.conversations.where((c) => c.type == 1).length,
        ConversationPerfFlags.uiSnapshotC2cLimit,
      );
      expect(
        notifier.conversations.where((c) => c.type == 2).length,
        ConversationPerfFlags.uiSnapshotGroupLimit,
      );

      final first = await notifier.appendOlderFromLocal(convType: 2);
      expect(first.changed, isTrue);
      expect(first.added, greaterThan(0));
      expect(
        notifier.conversations.where((c) => c.type == 1).length,
        greaterThanOrEqualTo(ConversationPerfFlags.uiSnapshotC2cLimit),
        reason: '群触底不得裁光单聊地板',
      );
      final idsAfterFirst = notifier.conversations
          .where((c) => c.type == 2)
          .map((c) => c.conversationID)
          .toSet();

      final second = await notifier.appendOlderFromLocal(convType: 2);
      expect(second.changed, isTrue, reason: '不得因未读优先陷入 append_older_noop');
      expect(
        notifier.conversations.where((c) => c.type == 1).length,
        greaterThanOrEqualTo(ConversationPerfFlags.uiSnapshotC2cLimit),
      );
      expect(
        notifier.conversations.length,
        greaterThan(ConversationPerfFlags.uiSlidingWindowBudget),
        reason: '连续下滑应抬高显示数量',
      );
      final idsAfterSecond = notifier.conversations
          .where((c) => c.type == 2)
          .map((c) => c.conversationID)
          .toSet();
      expect(
        idsAfterSecond.difference(idsAfterFirst),
        isNotEmpty,
        reason: '第二页应推进到更旧群',
      );
    });

    test('append older uses db-oldest edge when pinned old group is at top',
        () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 40; i++) {
        seed.add(_c2c(id: 'c2c_pinedge_$i', orderkey: 900000 - i));
      }
      // 置顶中等旧群在顶部；type_offset 续页应稳定增长并最终进到 cold，
      // 不得因置顶/游标漂移空转。
      seed.add(
        _group(
          id: 'group_pin_old',
          orderkey: 50000,
          showName: 'pinned-old',
        ),
      );
      for (var i = 0; i < 120; i++) {
        seed.add(_group(id: 'group_hot_$i', orderkey: 800000 - i));
      }
      for (var i = 0; i < 80; i++) {
        seed.add(_group(id: 'group_cold_$i', orderkey: 40000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      ConversationPinSyncService.instance.debugReplacePinnedIdsForTest([
        'group_pin_old',
      ]);
      try {
        await notifier.reloadFromLocal();
        expect(
          notifier.conversations
              .any((c) => c.conversationID == 'group_pin_old'),
          isTrue,
        );
        final groupsBefore =
            notifier.conversations.where((c) => c.type == 2).length;

        var reachedCold = false;
        for (var i = 0; i < 6; i++) {
          final slide = await notifier.appendOlderFromLocal(convType: 2);
          expect(slide.changed, isTrue, reason: '第${i + 1}页应继续增长');
          expect(slide.added, greaterThan(0));
          if (notifier.conversations
              .any((c) => c.conversationID.startsWith('group_cold_'))) {
            reachedCold = true;
            break;
          }
        }
        expect(reachedCold, isTrue, reason: '连续 OFFSET 续页应进入 cold 群');
        expect(
          notifier.conversations.where((c) => c.type == 2).length,
          greaterThan(groupsBefore),
        );
        expect(
          notifier.conversations
              .any((c) => c.conversationID == 'group_pin_old'),
          isTrue,
          reason: '扩窗不得丢掉置顶群',
        );
      } finally {
        ConversationPinSyncService.instance.debugReplacePinnedIdsForTest(
          const <String>[],
        );
      }
    });

    test('pagingAnchorMs matches activeTimeMs for db cursor', () {
      final conversation = _group(id: 'group_anchor', orderkey: 900000);
      expect(
        ConversationLocalStore.pagingAnchorMs(conversation),
        ConversationLocalStore.activeTimeMs(conversation),
      );
      expect(ConversationLocalStore.pagingAnchorMs(conversation), 900000);
    });

    test('append older offset-fallback when paging cursor drifts below db',
        () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 40; i++) {
        seed.add(_c2c(id: 'c2c_drift_$i', orderkey: 900000 - i));
      }
      for (var i = 0; i < 120; i++) {
        seed.add(_group(id: 'group_drift_$i', orderkey: 800000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();
      final groupsBefore =
          notifier.conversations.where((c) => c.type == 2).length;
      expect(groupsBefore, ConversationPerfFlags.uiSnapshotGroupLimit);

      // 模拟内存游标远小于库列 active_time：普通 loadOlder 会空，应走 OFFSET 兜底。
      for (final conversation in notifier.conversations) {
        if (conversation.type == 2) {
          ConversationLocalStore.instance.rememberPagingActiveTime(
            conversation,
            1,
          );
        }
      }
      final slide = await notifier.appendOlderFromLocal(convType: 2);
      expect(slide.changed, isTrue, reason: '游标漂移时仍应 OFFSET 加载更多群');
      expect(slide.added, greaterThan(0));
      expect(
        notifier.conversations.where((c) => c.type == 2).length,
        greaterThan(groupsBefore),
      );
    });

    test('sliding window keeps growing after append', () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 200; i++) {
        seed.add(_c2c(id: 'c2c_pre_$i', orderkey: 800000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();
      for (var i = 0; i < 4; i++) {
        await notifier.appendOlderFromLocal(convType: 1);
      }
      expect(
        notifier.conversations.length,
        ConversationPerfFlags.virtualHydrateMaxPerType,
      );
      expect(notifier.conversations, isNotEmpty);
      expect(
        notifier.conversations
            .any((c) => c.conversationID.startsWith('c2c_pre_')),
        isTrue,
      );
    });

    test('loadNewerPage store returns items hotter than cursor', () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 80; i++) {
        seed.add(_c2c(id: 'c2c_n_$i', orderkey: 700000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      final page = await ConversationLocalStore.instance.loadNewerPage(
        afterActiveTime: 700000 - 40,
        afterConversationId: 'c2c_n_40',
        limit: 10,
        convType: 1,
      );
      expect(page.length, 10);
      expect(page.last.conversationID, 'c2c_n_39');
      expect(page.first.conversationID, 'c2c_n_30');
    });

    test('soft reloadUiFromLocal keeps expanded append length', () async {
      final seed = <V2TimConversation>[];
      for (var i = 0; i < 300; i++) {
        seed.add(_c2c(id: 'c2c_soft_$i', orderkey: 600000 - i));
      }
      await ConversationLocalStore.instance.upsertBatch(conversations: seed);
      await notifier.reloadFromLocal();
      for (var i = 0; i < 5; i++) {
        await notifier.appendOlderFromLocal(convType: 1);
      }
      final before = notifier.conversations.length;
      expect(before, greaterThan(40));
      expect(
        before,
        lessThanOrEqualTo(
          ConversationPerfFlags.uiAppendOlderMaxPerType,
        ),
      );

      ConversationSyncService.instance.resetChatTransitionStateForTesting();
      await ConversationSyncService.instance.reloadUiFromLocal(
        immediate: true,
      );
      expect(notifier.conversations.length, greaterThanOrEqualTo(before));
    });

    test('trimUiWindowWithTypeFloors is no-op when hard cap disabled', () {
      final mixed = <V2TimConversation>[];
      for (var i = 0; i < 50; i++) {
        mixed.add(_group(id: 'group_hot_$i', orderkey: 900000 - i));
        mixed.add(_c2c(id: 'c2c_cold_$i', orderkey: 100000 - i));
      }
      final trimmed = ConversationLocalStore.trimUiWindowWithTypeFloors(mixed);
      expect(trimmed.length, mixed.length);
    });

    test('searchConversations finds by showName', () async {
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          _c2c(id: 'c2c_x', showName: '张三丰', orderkey: 1),
          _c2c(id: 'c2c_y', showName: '李四', orderkey: 2),
        ],
      );
      final hit = await ConversationLocalStore.instance.searchConversations(
        keyword: '张三',
      );
      expect(hit.length, 1);
      expect(hit.first.conversationID, 'c2c_x');
    });

    test('searchConversations finds rows outside ui snapshot window', () async {
      final conversations = <V2TimConversation>[];
      for (var i = 0; i < 60; i++) {
        conversations.add(
          _c2c(
            id: 'c2c_user_$i',
            showName: i == 55 ? '冷门联系人甲' : '用户$i',
            orderkey: 1000 - i,
          ),
        );
      }
      await ConversationLocalStore.instance.upsertBatch(
        conversations: conversations,
      );

      final window = await ConversationLocalStore.instance.loadUiWindow();
      expect(window.length, lessThan(conversations.length));
      expect(
        window.any((item) => item.conversationID == 'c2c_user_55'),
        isFalse,
      );

      final hit = await ConversationLocalStore.instance.searchConversations(
        keyword: '冷门联系人',
        limit: 100,
      );
      expect(hit.length, 1);
      expect(hit.first.conversationID, 'c2c_user_55');
    });

    test('searchConversationsAllPages paginates without stalling', () async {
      final conversations = <V2TimConversation>[];
      for (var i = 0; i < 120; i++) {
        conversations.add(
          _c2c(
            id: 'c2c_match_$i',
            showName: '匹配群友$i',
            orderkey: 2000 - i,
          ),
        );
      }
      conversations.add(
        _c2c(id: 'c2c_other', showName: '无关会话', orderkey: 1),
      );
      await ConversationLocalStore.instance.upsertBatch(
        conversations: conversations,
      );

      var batchCount = 0;
      final all =
          await ConversationLocalStore.instance.searchConversationsAllPages(
        keyword: '匹配群友',
        pageSize: 50,
        maxResults: 500,
        maxPages: 30,
        onBatch: (_, __) {
          batchCount++;
        },
      );
      expect(all.length, 120);
      expect(batchCount, greaterThan(1));
    });

    test('searchConversationsAllPages stops when cancelled', () async {
      final conversations = <V2TimConversation>[];
      for (var i = 0; i < 120; i++) {
        conversations.add(
          _c2c(
            id: 'c2c_cancel_$i',
            showName: '取消测试$i',
            orderkey: 3000 - i,
          ),
        );
      }
      await ConversationLocalStore.instance.upsertBatch(
        conversations: conversations,
      );

      var pages = 0;
      final partial =
          await ConversationLocalStore.instance.searchConversationsAllPages(
        keyword: '取消测试',
        pageSize: 20,
        maxResults: 500,
        maxPages: 30,
        shouldCancel: () {
          pages++;
          return pages >= 2;
        },
      );
      expect(partial.length, lessThan(120));
      expect(partial.length, greaterThanOrEqualTo(20));
    });
  });
}
