import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_tab_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

V2TimConversation _c2c(String id, {int unread = 0, int recvOpt = 0}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    unreadCount: unread,
    recvOpt: recvOpt,
    showName: id,
  );
}

V2TimConversation _group(String id, {int orderKey = 0}) {
  return V2TimConversation(
    conversationID: id,
    type: 2,
    groupID: id.replaceFirst('group_', ''),
    orderkey: orderKey,
    showName: id,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  late ConversationSyncService sync;

  setUp(() {
    // This suite exercises the SDK-primary projection only. An explicit empty
    // owner keeps the local-only C2C reconciliation path from invoking UIKit.
    ConversationLocalStore.instance.debugOwnerUserId = '';
    ConversationPerfFlags.conversationListSdkPrimary = false;
    ConversationPerfFlags.tabStoreCommittedViewEnabled = false;
    ConversationPerfGateLog.resetCountsForTest();
    ConversationTabStore.debugFetchOverride = null;
    ConversationTabStore.instance.clear();
    ConversationListNotifier.instance.setConversationsForTest(const []);
    sync = ConversationSyncService.instance;
    sync.resetChatTransitionStateForTesting();
  });

  tearDown(() {
    ConversationLocalStore.instance.debugOwnerUserId = null;
    ConversationPerfFlags.conversationListSdkPrimary = false;
    ConversationPerfFlags.tabStoreCommittedViewEnabled = false;
    ConversationTabStore.debugFetchOverride = null;
    ConversationTabStore.instance.clear();
    ConversationListNotifier.instance.setConversationsForTest(const []);
    sync.resetChatTransitionStateForTesting();
  });

  test('Phase4: pendingUiApply is no-op when sdk-primary', () {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    sync.notePendingUiApplyForTest(
      [_c2c('c2c_pending', unread: 2)],
      cause: 'quiet',
    );
    expect(sync.pendingUiApplyCountForTest, 0);
    expect(
      ConversationPerfGateLog.eventCountsForTest['mirror_skip_ui'] ?? 0,
      greaterThan(0),
    );
  });

  test('Phase4: flush pendingUiApply clears without DB UI when sdk-primary',
      () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    await sync.flushPendingUiApplyForTest(reason: 'quiet_end');
    expect(sync.pendingUiApplyCountForTest, 0);
    expect(
      ConversationPerfGateLog.eventCountsForTest['mirror_skip_ui'] ?? 0,
      greaterThan(0),
    );
  });

  test('Phase4: recvOpt patches TabStore without hydrate dual-write', () {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    final notifier = ConversationListNotifier.instance;
    notifier.ensureTabStoreBridgeAttached();
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [_c2c('c2c_recv')],
      finished: true,
    );
    ConversationTabStore.instance.applyPatches(
      [_c2c('c2c_recv')],
      reason: 'seed',
    );
    ConversationPerfGateLog.resetCountsForTest();

    notifier.applyRecvOptLocally(
      conversationID: 'c2c_recv',
      recvOpt: 2,
      snapshot: _c2c('c2c_recv'),
    );

    expect(
      ConversationPerfGateLog.eventCountsForTest['type_hydrate_patched'] ?? 0,
      0,
    );
    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .firstWhere((c) => c.conversationID == 'c2c_recv')
          .recvOpt,
      2,
    );
  });

  test('Phase4: TabStore remains SDK-fake source for list reads', () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    ConversationTabStore.debugFetchOverride = ({
      required int convType,
      required String nextSeq,
      required int count,
    }) async {
      return (
        conversationList: <V2TimConversation>[_c2c('c2c_fake_page')],
        nextSeq: '0',
        isFinished: true,
        code: 0,
        desc: '',
      );
    };
    addTearDown(() => ConversationTabStore.debugFetchOverride = null);

    final notifier = ConversationListNotifier.instance;
    notifier.ensureTabStoreBridgeAttached();
    await ConversationTabStore.instance.loadFirstPage(convType: 1);

    expect(notifier.conversationAtTypeIndex(1, 0)?.conversationID,
        'c2c_fake_page');
    expect(
      ConversationPerfGateLog.eventCountsForTest['tab_store_page'] ?? 0,
      greaterThan(0),
    );
  });

  test('Phase4: compatibility recovery preserves a deep group window',
      () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    ConversationPerfFlags.tabStoreCommittedViewEnabled = true;
    var fetches = 0;
    ConversationTabStore.debugFetchOverride = ({
      required int convType,
      required String nextSeq,
      required int count,
    }) async {
      fetches++;
      return (
        conversationList: const <V2TimConversation>[],
        nextSeq: '0',
        isFinished: true,
        code: 0,
        desc: '',
      );
    };

    final groups = List<V2TimConversation>.generate(
      150,
      (index) => _group('group_deep_$index', orderKey: 10000 - index),
    );
    final tabStore = ConversationTabStore.instance;
    tabStore.setItemsForTest(
      convType: 1,
      items: <V2TimConversation>[_c2c('c2c_existing')],
      nextSeq: 'deep_c2c_cursor',
      finished: false,
    );
    tabStore.setItemsForTest(
      convType: 2,
      items: groups,
      nextSeq: 'deep_group_cursor',
      finished: false,
    );
    final cursorBefore = tabStore.pageCursorForType(2)?.conversationID;

    await ConversationListNotifier.instance.restoreStoreProjection(
      reason: ConversationStoreProjectionReason.sdkCompatibilityRecovery,
    );

    expect(fetches, 0);
    expect(tabStore.countForType(2), groups.length);
    expect(tabStore.nextSeqForType(2), 'deep_group_cursor');
    expect(tabStore.pageCursorForType(2)?.conversationID, cursorBefore);
    expect(
      tabStore.itemsForType(2).map((row) => row.conversationID),
      groups.map((row) => row.conversationID),
    );
    expect(
      ConversationPerfGateLog
              .eventCountsForTest['sdk_primary_restore_preserve_view'] ??
          0,
      2,
    );
  });

  test('Phase4: compatibility recovery primes an empty Store', () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    var fetches = 0;
    ConversationTabStore.debugFetchOverride = ({
      required int convType,
      required String nextSeq,
      required int count,
    }) async {
      fetches++;
      return (
        conversationList: convType == 1
            ? <V2TimConversation>[_c2c('c2c_primed')]
            : <V2TimConversation>[_group('group_primed')],
        nextSeq: '0',
        isFinished: true,
        code: 0,
        desc: '',
      );
    };

    await ConversationListNotifier.instance.restoreStoreProjection(
      reason: ConversationStoreProjectionReason.sdkCompatibilityRecovery,
    );

    expect(fetches, 2);
    expect(
      ConversationTabStore.instance.itemsForType(1).single.conversationID,
      'c2c_primed',
    );
    expect(
      ConversationTabStore.instance.itemsForType(2).single.conversationID,
      'group_primed',
    );
  });

  test('Phase4: late SQLite commit wakes an empty C2C projection', () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    ConversationPerfFlags.tabStoreCommittedViewEnabled = true;
    final store = ConversationLocalStore.instance;
    const owner = 'phase4_late_c2c_owner';
    store.debugOwnerUserId = owner;
    addTearDown(() async {
      store.debugOwnerUserId = null;
      await store.clearForOwner(owner);
    });

    await store.clearForOwner(owner);
    await ConversationTabStore.instance.loadFirstPage(convType: 1);
    expect(ConversationTabStore.instance.finishedForType(1), isTrue);
    expect(ConversationTabStore.instance.countForType(1), 0);

    await store.upsertBatch(
      conversations: <V2TimConversation>[_c2c('c2c_late_bootstrap')],
      ownerUserId: owner,
    );
    await ConversationListNotifier.instance
        .refreshEmptySdkPrimaryTypeProjectionForTest(
      convType: 1,
      reason: 'test_late_commit',
    );

    expect(ConversationTabStore.instance.countForType(1), 1);
    expect(
      ConversationTabStore.instance.atTypeIndex(1, 0)?.conversationID,
      'c2c_late_bootstrap',
    );
  });

  test('Phase4: C2C bootstrap failure retries independently of groups',
      () async {
    final store = ConversationLocalStore.instance;
    const owner = 'phase4_c2c_retry_owner';
    store.debugOwnerUserId = owner;
    sync.debugOwnerUserId = owner;
    addTearDown(() async {
      sync.debugOwnerUserId = null;
      store.debugOwnerUserId = null;
      await store.clearForOwner(owner);
    });

    await store.clearForOwner(owner);
    var c2cCalls = 0;
    var groupCalls = 0;
    ConversationSyncService.debugGetConversationListByFilterOverride = ({
      required int convType,
      required String nextSeq,
      required int count,
    }) async {
      if (convType == 1) {
        c2cCalls++;
        if (c2cCalls == 1) {
          return (
            conversationList: const <V2TimConversation>[],
            nextSeq: '0',
            isFinished: true,
            code: 70001,
            desc: 'temporary C2C failure',
          );
        }
        return (
          conversationList: <V2TimConversation>[_c2c('c2c_retry_success')],
          nextSeq: '0',
          isFinished: true,
          code: 0,
          desc: '',
        );
      }
      groupCalls++;
      return (
        conversationList: <V2TimConversation>[_group('group_bootstrap')],
        nextSeq: '0',
        isFinished: true,
        code: 0,
        desc: '',
      );
    };
    addTearDown(
      () => ConversationSyncService.debugGetConversationListByFilterOverride =
          null,
    );

    await sync.bootstrapTypedFirstScreen(
      reason: 'test_c2c_failure',
      reset: true,
    );
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final current = await store.readSyncMeta(ownerUserId: owner);
      if (c2cCalls >= 2 && !current.c2cHaveMore) {
        break;
      }
    }

    expect(groupCalls, 1);
    expect(c2cCalls, 2);
    final meta = await store.readSyncMeta(ownerUserId: owner);
    expect(meta.c2cHaveMore, isFalse);
    expect(
      (await store.loadConvTypePage(
        convType: 1,
        offset: 0,
        limit: 10,
        ownerUserId: owner,
      ))
          .map((conversation) => conversation.conversationID),
      contains('c2c_retry_success'),
    );
  });
}
