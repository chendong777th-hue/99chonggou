import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

V2TimConversation _conversation(int index) {
  return V2TimConversation(
    conversationID: 'c2c_tail_$index',
    type: 1,
    userID: 'tail_$index',
    orderkey: 810000 - index,
    showName: 'tail $index',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const owner = 'virtual_tail_window_test';
  final store = ConversationLocalStore.instance;
  final notifier = ConversationListNotifier.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    ConversationLocalStore.bypassUpsertCoalesceForTest = true;
    store.debugOwnerUserId = owner;
  });

  tearDown(() async {
    notifier.clearSession();
    await store.clearForOwner(owner);
    store.debugOwnerUserId = null;
    ConversationLocalStore.bypassUpsertCoalesceForTest = false;
  });

  tearDownAll(() async {
    await store.closeDatabaseForTest();
  });

  test('legacy append cannot overwrite a distant virtual hydrate window',
      () async {
    if (!ConversationPerfFlags.conversationVirtualListEnabled) {
      return;
    }
    await store.upsertBatch(
      conversations: <V2TimConversation>[
        for (var i = 0; i < 240; i++) _conversation(i),
      ],
      ownerUserId: owner,
    );
    await notifier.reloadFromLocal();
    await notifier.ensureTypeIndexHydrated(
      convType: 1,
      centerIndex: 239,
      forceReload: true,
      allowWindowJump: true,
    );

    final tailStart = notifier.hydratedStartOffsetForType(1);
    expect(tailStart, greaterThan(0));
    expect(
      notifier.conversationAtTypeIndex(1, 239)?.conversationID,
      'c2c_tail_239',
    );

    final slide = await notifier.appendOlderFromLocal(
      convType: 1,
      protectVirtualViewport: true,
    );

    expect(slide.changed, isFalse);
    expect(notifier.hydratedStartOffsetForType(1), tailStart);
    expect(
      notifier.conversationAtTypeIndex(1, 239)?.conversationID,
      'c2c_tail_239',
    );
  });
}
