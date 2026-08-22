import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConversationSyncService sync;
  var scrolling = false;

  setUp(() {
    ConversationPerfGateLog.resetCountsForTest();
    ConversationPerfGateLog.skipUnreadAggregateScheduleForTest = true;
    sync = ConversationSyncService.instance;
    scrolling = false;
    ConversationListNotifier.instance.isFeedScrolling = () => scrolling;
    ConversationListNotifier.instance.setConversationsForTest(const []);
    sync.resetChatTransitionStateForTesting();
    ActiveChatRegistry.instance.reset();
  });

  tearDown(() {
    ConversationPerfGateLog.skipUnreadAggregateScheduleForTest = false;
    ConversationListNotifier.instance.isFeedScrolling = null;
    ConversationListNotifier.instance.setConversationsForTest(const []);
    sync.resetChatTransitionStateForTesting();
    ActiveChatRegistry.instance.reset();
  });

  test('realtime flags: scrolling defers feed ui apply/notify', () {
    expect(ConversationPerfFlags.deferUiNotifyWhileFeedScrolling, isTrue);
    expect(ConversationPerfFlags.deferUiNotifyWhileActiveChat, isTrue);
    expect(ConversationPerfFlags.persistUiApplyWhileFeedScrolling, isFalse);
    expect(
      ConversationPerfFlags.feedScrollUiNotifyMaxDefer.inMilliseconds,
      1200,
    );
    expect(
      ConversationPerfFlags.pendingPreviewPatchMaxWait.inMilliseconds,
      1200,
    );
  });

  test('persist ui apply defers while scrolling and flushes after scroll',
      () async {
    ConversationListNotifier.instance.setConversationsForTest([
      V2TimConversation(
        conversationID: 'c2c_perf_gate_1',
        type: 1,
        userID: 'u1',
        unreadCount: 0,
        showName: 'u1',
      ),
    ]);
    scrolling = true;
    final conv = V2TimConversation(
      conversationID: 'c2c_perf_gate_1',
      type: 1,
      userID: 'u1',
      unreadCount: 1,
      showName: 'u1',
    );
    await sync.notifyUiAfterLocalWriteForTest(upserted: [conv]);
    expect(
      ConversationPerfGateLog.eventCountsForTest['ui_apply_deferred'] ?? 0,
      greaterThan(0),
    );
    expect(sync.pendingUiApplyCountForTest, 1);
    expect(
      ConversationListNotifier.instance.conversations.any(
        (c) => c.conversationID == 'c2c_perf_gate_1',
      ),
      isTrue,
    );
    expect(
      ConversationListNotifier.instance.conversations
          .firstWhere((c) => c.conversationID == 'c2c_perf_gate_1')
          .unreadCount,
      0,
    );

    scrolling = false;
    await sync.flushPendingUiApplyForTest(reason: 'scroll_end');
    expect(sync.pendingUiApplyCountForTest, 0);
    expect(
      ConversationListNotifier.instance.conversations.any(
        (c) => c.conversationID == 'c2c_perf_gate_1',
      ),
      isTrue,
    );
    expect(
      ConversationListNotifier.instance.conversations
          .firstWhere((c) => c.conversationID == 'c2c_perf_gate_1')
          .unreadCount,
      1,
    );
  });

  test('list notify defers while active chat and flushes after leave',
      () async {
    scrolling = false;
    ActiveChatRegistry.instance.enter(
      'c2c_active_1',
      conversationType: ConvType.c2c,
    );
    final notifier = ConversationListNotifier.instance;
    var notifyCount = 0;
    void onNotify() => notifyCount++;
    notifier.addListener(onNotify);
    addTearDown(() => notifier.removeListener(onNotify));

    await notifier.applyConversationsFromStore(
      upserted: [
        V2TimConversation(
          conversationID: 'c2c_active_1',
          type: 1,
          userID: 'u1',
          unreadCount: 3,
          showName: 'a',
        ),
      ],
    );
    // coalesce 48ms
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(
      ConversationPerfGateLog
              .eventCountsForTest['ui_notify_deferred_active_chat'] ??
          0,
      greaterThan(0),
    );
    expect(notifyCount, 0);

    ActiveChatRegistry.instance.leave('c2c_active_1');
    notifier.flushDeferredUiNotifyIfNeeded(reason: 'active_chat_test');
    expect(notifyCount, greaterThan(0));
  });

  test('chat leave still patches left conversation', () async {
    scrolling = false;
    ActiveChatRegistry.instance.enter(
      'c2c_active_2',
      conversationType: ConvType.c2c,
    );
    final notifier = ConversationListNotifier.instance;
    await notifier.applyConversationsFromStore(
      upserted: [
        V2TimConversation(
          conversationID: 'c2c_active_2',
          type: 1,
          userID: 'u2',
          unreadCount: 1,
          showName: 'b',
        ),
      ],
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    ActiveChatRegistry.instance.leave('c2c_active_2');
    ConversationPerfGateLog.resetCountsForTest();
    final patched = await notifier.patchConversationAfterChatLeave(
      'c2c_active_2',
      reason: 'chat_leave',
    );
    expect(patched, isTrue);
    expect(
      ConversationPerfGateLog.eventCountsForTest['chat_leave_patch_left'] ?? 0,
      greaterThan(0),
    );
  });

  test('flush pending ui apply only patches in-window items', () async {
    scrolling = false;
    final notifier = ConversationListNotifier.instance;
    final inWindow = V2TimConversation(
      conversationID: 'c2c_flush_in',
      type: 1,
      userID: 'in',
      unreadCount: 2,
      showName: 'in',
    );
    final outside = V2TimConversation(
      conversationID: 'group_flush_out',
      type: 2,
      groupID: 'out',
      unreadCount: 9,
      showName: 'out',
    );
    await notifier.applyConversationsFromStore(upserted: [inWindow]);
    expect(
      notifier.conversations.any((c) => c.conversationID == 'c2c_flush_in'),
      isTrue,
    );
    expect(
      notifier.conversations.any((c) => c.conversationID == 'group_flush_out'),
      isFalse,
    );

    // resume quiet 仍可挂起 UI apply（与滑/聊 defer 关闭正交）。
    sync.beginResumeQuietWindow(duration: const Duration(seconds: 30));
    await sync.notifyUiAfterLocalWriteForTest(
      upserted: [
        V2TimConversation(
          conversationID: 'c2c_flush_in',
          type: 1,
          userID: 'in',
          unreadCount: 5,
          showName: 'in-updated',
        ),
        outside,
      ],
    );
    expect(sync.pendingUiApplyCountForTest, greaterThan(0));

    ConversationPerfGateLog.resetCountsForTest();
    await sync.flushPendingUiApplyForTest(reason: 'scroll_end');
    expect(sync.pendingUiApplyCountForTest, 0);
    expect(
      notifier.conversations.any((c) => c.conversationID == 'group_flush_out'),
      isFalse,
      reason: '窗外未读群不得因 flush 热准入灌进 UI',
    );
    final updated = notifier.conversations.firstWhere(
      (c) => c.conversationID == 'c2c_flush_in',
    );
    expect(updated.unreadCount, 5);
    expect(
      ConversationPerfGateLog.eventCountsForTest['ui_apply_flush_append'] ?? 0,
      greaterThan(0),
      reason: '窗外 pending 应触发 append 补页尝试',
    );
  });
}
