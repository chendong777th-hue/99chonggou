import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_tab_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

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

  setUp(() {
    ConversationPerfFlags.conversationListSdkPrimary = false;
    archivedConversationC2cIDsNotifier.value = <String>{};
    archivedConversationGroupIDsNotifier.value = <String>{};
    ConversationTabStore.instance.clear();
    ConversationListNotifier.instance.setConversationsForTest(const []);
  });

  tearDown(() {
    ConversationPerfFlags.conversationListSdkPrimary = false;
    archivedConversationC2cIDsNotifier.value = <String>{};
    archivedConversationGroupIDsNotifier.value = <String>{};
    ConversationTabStore.instance.clear();
    ConversationListNotifier.instance.setConversationsForTest(const []);
  });

  test('Phase3: loadFirstPage skips archived ids', () async {
    archivedConversationC2cIDsNotifier.value = {'c2c_archived'};
    ConversationTabStore.debugFetchOverride = ({
      required int convType,
      required String nextSeq,
      required int count,
    }) async {
      return (
        conversationList: <V2TimConversation>[
          _c2c('c2c_keep'),
          _c2c('c2c_archived'),
        ],
        nextSeq: '0',
        isFinished: true,
        code: 0,
        desc: '',
      );
    };
    addTearDown(() => ConversationTabStore.debugFetchOverride = null);

    await ConversationTabStore.instance.loadFirstPage(convType: 1);
    expect(
      ConversationTabStore.instance.itemsForType(1).map((c) => c.conversationID),
      ['c2c_keep'],
    );
  });

  test('Phase3: applyPatches removes newly archived row', () {
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [_c2c('c2c_a'), _c2c('c2c_b')],
      finished: true,
    );
    archivedConversationC2cIDsNotifier.value = {'c2c_a'};
    ConversationTabStore.instance.applyPatches(
      [_c2c('c2c_a', unread: 3)],
      reason: 'test',
    );
    expect(
      ConversationTabStore.instance.itemsForType(1).map((c) => c.conversationID),
      ['c2c_b'],
    );
  });

  test('Phase3: purgeArchived + sdk-primary archive sync', () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    ConversationListNotifier.instance.ensureTabStoreBridgeAttached();
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [_c2c('c2c_keep'), _c2c('c2c_gone')],
      finished: true,
    );
    ConversationListNotifier.instance.ensureTabStoreBridgeAttached();
    // Force adopt once.
    ConversationTabStore.instance.applyPatches(
      [_c2c('c2c_keep')],
      reason: 'seed',
    );

    archivedConversationC2cIDsNotifier.value = {'c2c_gone'};
    await ConversationListNotifier.instance.syncMainListAfterArchiveChange(
      removedIds: const ['c2c_gone'],
      reason: 'phase3_test',
    );

    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .any((c) => c.conversationID == 'c2c_gone'),
      isFalse,
    );
    expect(
      ConversationListNotifier.instance.conversations
          .any((c) => c.conversationID == 'c2c_gone'),
      isFalse,
    );
  });

  test('Phase3: mirror-only flag is on (UI authority documented)', () {
    expect(ConversationPerfFlags.conversationSqliteListFieldsMirrorOnly, isTrue);
  });
}
