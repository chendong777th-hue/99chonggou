import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

V2TimConversation _conversation({
  required String id,
  required int activeTimestamp,
}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    isPinned: false,
    draftTimestamp: activeTimestamp,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const owner = 'pinned_type_page_order_owner';
  final store = ConversationLocalStore.instance;
  final pinService = ConversationPinSyncService.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    ConversationLocalStore.bypassUpsertCoalesceForTest = true;
    store.debugOwnerUserId = owner;
    await store.clearForOwner(owner);
    await pinService.clearSession();
  });

  tearDown(() async {
    await pinService.clearSession();
    await store.clearForOwner(owner);
    store.debugOwnerUserId = null;
    ConversationLocalStore.bypassUpsertCoalesceForTest = false;
  });

  tearDownAll(() async {
    await store.closeDatabaseForTest();
  });

  test('hydrated pin truth is applied before virtual page limit and offset',
      () async {
    await store.upsertBatch(
      conversations: <V2TimConversation>[
        _conversation(id: 'c2c_newest', activeTimestamp: 300),
        _conversation(id: 'c2c_middle', activeTimestamp: 200),
        _conversation(id: 'c2c_old_pinned', activeTimestamp: 100),
      ],
      ownerUserId: owner,
    );

    // 模拟腾讯置顶集合已经返回，但 SQLite is_pinned 镜像尚未对齐的竞态。
    pinService.debugReplacePinnedIdsForTest(
      const <String>['c2c_old_pinned'],
      markHydrated: true,
    );

    final firstPage = await store.loadConvTypePage(
      convType: 1,
      offset: 0,
      limit: 2,
      ownerUserId: owner,
    );

    expect(firstPage, hasLength(2));
    expect(firstPage.first.conversationID, 'c2c_old_pinned');
    expect(firstPage.first.isPinned, isTrue);
  });

  test('keyset page continues after pinned/order/id cursor', () async {
    await store.upsertBatch(
      conversations: <V2TimConversation>[
        _conversation(id: 'c2c_a', activeTimestamp: 300),
        _conversation(id: 'c2c_b', activeTimestamp: 200),
        _conversation(id: 'c2c_c', activeTimestamp: 100),
      ],
      ownerUserId: owner,
    );
    final first = await store.loadConvTypePage(
      convType: 1,
      offset: 0,
      limit: 2,
      ownerUserId: owner,
    );
    expect(first.map((row) => row.conversationID), ['c2c_a', 'c2c_b']);

    final second = await store.loadConvTypePageAfterCursor(
      convType: 1,
      cursor: ConversationTypePageCursor(
        pinned: first.last.isPinned == true,
        activeTime: ConversationLocalStore.activeTimeMs(first.last),
        orderKey: first.last.orderkey ?? 0,
        conversationID: first.last.conversationID,
      ),
      limit: 2,
      ownerUserId: owner,
    );
    expect(second.map((row) => row.conversationID), ['c2c_c']);
  });
}
