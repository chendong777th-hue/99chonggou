import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_host.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

V2TimConversation _c2c(String userId) {
  return V2TimConversation(
    conversationID: 'c2c_$userId',
    type: 1,
    userID: userId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'sqflite_lifecycle_owner';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SqfliteLifecycleGuard.instance.debugReset();
    SqfliteLifecycleHost.debugReset();
    ConversationLocalStore.bypassUpsertCoalesceForTest = false;
    ConversationLocalStore.instance.debugOwnerUserId = owner;
    await ConversationLocalStore.instance.clearForOwner(owner);
  });

  tearDown(() async {
    SqfliteLifecycleGuard.instance.debugReset();
    SqfliteLifecycleHost.debugReset();
    ConversationLocalStore.bypassUpsertCoalesceForTest = false;
    await ConversationLocalStore.instance.clearForOwner(owner);
    ConversationLocalStore.instance.debugOwnerUserId = null;
  });

  test('pauseWrites 时 upsertBatch 不 open、不 flush', () async {
    final store = ConversationLocalStore.instance;
    final openedBefore = store.databaseOpenCountForTest;

    SqfliteLifecycleGuard.instance.pauseWrites();
    store.pauseCoalesceForBackground();

    final result = await store.upsertBatch(conversations: [_c2c('paused')]);

    expect(result.single.conversationID, 'c2c_paused');
    expect(store.databaseOpenCountForTest, openedBefore);
  });

  test('coalesce waiter 在 pause 时会 complete', () async {
    final store = ConversationLocalStore.instance;
    final pending = store.upsertBatch(conversations: [_c2c('waiter')]);
    await Future<void>.delayed(Duration.zero);

    SqfliteLifecycleGuard.instance.pauseWrites();
    store.pauseCoalesceForBackground();

    final result = await pending.timeout(const Duration(seconds: 2));
    expect(result, isNotEmpty);
    expect(result.single.conversationID, 'c2c_waiter');
  });

  test('resume 后 upsertBatch 可以再写盘', () async {
    final store = ConversationLocalStore.instance;
    final openedBefore = store.databaseOpenCountForTest;

    SqfliteLifecycleGuard.instance.pauseWrites();
    store.pauseCoalesceForBackground();
    await store.upsertBatch(conversations: [_c2c('queued')]);
    expect(store.databaseOpenCountForTest, openedBefore);
    await store.closeIfOpen();
    final openedAfterClose = store.databaseOpenCountForTest;

    SqfliteLifecycleGuard.instance.resume();
    store.resumeCoalesceAfterForeground();
    await store.waitUntilUpsertWriteIdle(
      maxWait: const Duration(seconds: 2),
    );

    expect(store.databaseOpenCountForTest, greaterThan(openedAfterClose));
    final loaded = await store.conversationById('c2c_queued');
    expect(loaded?.conversationID, 'c2c_queued');
  });

  test('forbidOpen 时 beforeOpen 抛 SqfliteClosedForBackground', () {
    SqfliteLifecycleGuard.instance.forbidOpen();
    expect(
      () => SqfliteLifecycleGuard.beforeOpen(null),
      throwsA(isA<SqfliteClosedForBackground>()),
    );
  });

  test('resumed handle 后 canOpenDatabase 为 true', () async {
    SqfliteLifecycleHost.debugReset();
    SqfliteLifecycleGuard.instance.forbidOpen();
    expect(SqfliteLifecycleGuard.instance.canOpenDatabase, isFalse);

    await SqfliteLifecycleHost.handle(AppLifecycleState.resumed);

    expect(SqfliteLifecycleGuard.instance.canOpenDatabase, isTrue);
    expect(SqfliteLifecycleGuard.instance.writesAllowed, isTrue);
  });

  test('waitUntilOpenAllowed 在 resume 后返回 true', () async {
    SqfliteLifecycleHost.debugReset();
    SqfliteLifecycleGuard.instance.forbidOpen();

    final wait = SqfliteLifecycleHost.waitUntilOpenAllowed(
      timeout: const Duration(seconds: 2),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await SqfliteLifecycleHost.handle(AppLifecycleState.resumed);

    expect(await wait, isTrue);
  });
}
