import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConversationSyncService sync;

  setUp(() {
    ConversationPerfFlags.conversationListSdkPrimary = false;
    ConversationPerfGateLog.resetCountsForTest();
    ConversationTabStore.instance.clear();
    ConversationListNotifier.instance.setConversationsForTest(const []);
    sync = ConversationSyncService.instance;
    sync.resetChatTransitionStateForTesting();
  });

  tearDown(() {
    ConversationPerfFlags.conversationListSdkPrimary = false;
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

    expect(notifier.conversationAtTypeIndex(1, 0)?.conversationID, 'c2c_fake_page');
    expect(
      ConversationPerfGateLog.eventCountsForTest['tab_store_page'] ?? 0,
      greaterThan(0),
    );
  });
}
