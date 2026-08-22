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
    ConversationListNotifier.instance.clearSession();
    sync.resetChatTransitionStateForTesting();
    ActiveChatRegistry.instance.reset();
  });

  test('active chat apply records dirty and leave patch dedupes', () async {
    expect(ConversationPerfFlags.chatLeavePatchLeftOnlyEnabled, isTrue);
    expect(ConversationPerfFlags.chatLeaveFlushDedupeEnabled, isTrue);

    ActiveChatRegistry.instance.enter(
      'c2c_leave_1',
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
          conversationID: 'c2c_leave_1',
          type: 1,
          userID: 'u1',
          unreadCount: 2,
          showName: 'a',
        ),
        V2TimConversation(
          conversationID: 'c2c_leave_other',
          type: 1,
          userID: 'u2',
          unreadCount: 1,
          showName: 'b',
        ),
      ],
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(
      (ConversationPerfGateLog
                  .eventCountsForTest['ui_notify_deferred_active_chat'] ??
              0) >
          0,
      isTrue,
    );

    final notifyBeforeLeave = notifyCount;
    ActiveChatRegistry.instance.leave('c2c_leave_1');
    ConversationPerfGateLog.resetCountsForTest();

    final first = await notifier.patchConversationAfterChatLeave(
      'c2c_leave_1',
      reason: 'chat_leave_deactivate',
    );
    final second = await notifier.patchConversationAfterChatLeave(
      'c2c_leave_1',
      reason: 'chat_leave_dispose',
    );
    expect(first, isTrue);
    expect(second, isFalse);
    expect(
      ConversationPerfGateLog.eventCountsForTest['chat_leave_patch_left'] ?? 0,
      1,
    );
    expect(
      ConversationPerfGateLog
              .eventCountsForTest['chat_leave_flush_skipped_dedupe'] ??
          0,
      1,
    );
    expect(
      ConversationPerfGateLog.eventCountsForTest['ui_notify_flush'] ?? 0,
      0,
      reason: 'leave 不应走整表 deferred flush，只刷挂起的 pending notify',
    );
    expect(
      ConversationPerfGateLog
              .eventCountsForTest['chat_leave_flush_pending_notify'] ??
          0,
      1,
    );
    expect(notifyCount, greaterThan(notifyBeforeLeave));
    expect(notifier.isPostChatLeaveQuiet, isTrue);
  });

  test('leave flushes deferred notify so in-chat new conversation appears',
      () async {
    ActiveChatRegistry.instance.enter(
      'c2c_leave_current',
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
          conversationID: 'c2c_leave_current',
          type: 1,
          userID: 'current',
          unreadCount: 0,
          showName: 'current',
        ),
      ],
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final notifyAfterSeed = notifyCount;

    await notifier.applyConversationsFromStore(
      upserted: [
        V2TimConversation(
          conversationID: 'c2c_new_during_chat',
          type: 1,
          userID: 'peer',
          unreadCount: 1,
          showName: 'peer',
          orderkey: 999,
        ),
      ],
      forceAdmitIds: const {'c2c_new_during_chat'},
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(notifyCount, notifyAfterSeed, reason: '聊中 Feed notify 应被 defer');
    expect(
      notifier.conversations.any(
        (c) => c.conversationID == 'c2c_new_during_chat',
      ),
      isTrue,
    );

    ActiveChatRegistry.instance.leave('c2c_leave_current');
    await notifier.patchConversationAfterChatLeave(
      'c2c_leave_current',
      reason: 'chat_leave_deactivate',
    );
    expect(notifyCount, greaterThan(notifyAfterSeed));
    expect(
      ConversationPerfGateLog
              .eventCountsForTest['chat_leave_flush_pending_notify'] ??
          0,
      greaterThan(0),
    );
    expect(
      notifier.conversations.any(
        (c) => c.conversationID == 'c2c_new_during_chat',
      ),
      isTrue,
    );
  });

  test('flushDeferred chat_leave redirects when left-only enabled', () async {
    ActiveChatRegistry.instance.enter(
      'c2c_redirect_1',
      conversationType: ConvType.c2c,
    );
    final notifier = ConversationListNotifier.instance;
    await notifier.applyConversationsFromStore(
      upserted: [
        V2TimConversation(
          conversationID: 'c2c_redirect_1',
          type: 1,
          userID: 'u1',
          unreadCount: 1,
          showName: 'a',
        ),
      ],
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    ActiveChatRegistry.instance.leave('c2c_redirect_1');
    ConversationPerfGateLog.resetCountsForTest();
    notifier.flushDeferredUiNotifyIfNeeded(reason: 'chat_leave_dispose');
    expect(
      ConversationPerfGateLog
              .eventCountsForTest['ui_notify_flush_redirect_leave'] ??
          0,
      greaterThan(0),
    );
    expect(
      ConversationPerfGateLog.eventCountsForTest['ui_notify_flush'] ?? 0,
      0,
    );
  });
}
