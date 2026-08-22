import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_tab_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

V2TimConversation _c2c(String id, {int unread = 0}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    unreadCount: unread,
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
    sync.upsertBatchOverride = (rows) async => rows;
  });

  tearDown(() {
    ConversationPerfFlags.conversationListSdkPrimary = false;
    ConversationTabStore.instance.clear();
    ConversationListNotifier.instance.setConversationsForTest(const []);
    sync.upsertBatchOverride = null;
    sync.resetChatTransitionStateForTesting();
  });

  test('Phase2: paced sync does not drive UI when sdk-primary', () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    ConversationListNotifier.instance.ensureTabStoreBridgeAttached();

    await sync.applyPacedSyncPageToUiForTest(
      [_c2c('c2c_paced', unread: 2)],
      reason: 'typed_sync_db_only',
    );

    expect(ConversationTabStore.instance.countForType(1), 0);
    expect(
      ConversationPerfGateLog.eventCountsForTest['mirror_skip_ui'] ?? 0,
      greaterThan(0),
    );
  });

  test('Phase2: quiet does not defer UI apply when sdk-primary', () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    ConversationListNotifier.instance.ensureTabStoreBridgeAttached();
    sync.beginResumeQuietWindow(duration: const Duration(seconds: 30));

    await sync.notifyUiAfterLocalWriteForTest(
      upserted: [_c2c('c2c_quiet', unread: 1)],
    );

    expect(sync.pendingUiApplyCountForTest, 0);
    expect(ConversationTabStore.instance.countForType(1), 1);
  });

  test('Phase2: listener persist patches TabStore before mirror', () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    ConversationListNotifier.instance.ensureTabStoreBridgeAttached();

    await sync.persistChangedForTest(
      [_c2c('c2c_listener', unread: 5)],
      reason: 'changed',
    );

    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .any((c) => c.conversationID == 'c2c_listener'),
      isTrue,
    );
    expect(
      ConversationListNotifier.instance.conversations
          .any((c) => c.conversationID == 'c2c_listener'),
      isTrue,
    );
    expect(
      ConversationPerfGateLog.eventCountsForTest['mirror_skip_ui'] ?? 0,
      greaterThan(0),
    );
  });

  test('Phase2 off: quiet still defers when persistUiApplyInResumeQuiet=false',
      () async {
    expect(ConversationPerfFlags.persistUiApplyInResumeQuiet, isFalse);
    ConversationPerfFlags.conversationListSdkPrimary = false;
    sync.beginResumeQuietWindow(duration: const Duration(seconds: 30));

    await sync.notifyUiAfterLocalWriteForTest(
      upserted: [_c2c('c2c_legacy_quiet', unread: 1)],
    );

    expect(sync.pendingUiApplyCountForTest, greaterThan(0));
    expect(
      ConversationListNotifier.instance.conversations
          .any((c) => c.conversationID == 'c2c_legacy_quiet'),
      isFalse,
    );
  });
}
