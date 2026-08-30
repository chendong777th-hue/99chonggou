import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/read_outbox_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/read_receipt_outbox_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ConversationLocalStore.instance.debugOwnerUserId = 'read_outbox_owner';
    await ConversationReadOutboxStore.instance.clearOwner('read_outbox_owner');
    await ReadReceiptOutboxStore.instance.clearOwner('read_outbox_owner');
  });

  tearDown(() async {
    await ConversationReadOutboxStore.instance.clearOwner('read_outbox_owner');
    await ReadReceiptOutboxStore.instance.clearOwner('read_outbox_owner');
    ConversationLocalStore.instance.debugOwnerUserId = null;
  });

  test('older enqueue and acknowledgement cannot erase a newer read intent',
      () async {
    final store = ConversationReadOutboxStore.instance;
    await store.enqueue(
      ownerUserId: 'read_outbox_owner',
      conversationId: 'c2c_bob',
      lastReadMessageId: 'new-message',
      lastReadAtMs: 200,
    );
    await store.enqueue(
      ownerUserId: 'read_outbox_owner',
      conversationId: 'c2c_bob',
      lastReadMessageId: 'old-message',
      lastReadAtMs: 100,
    );

    var rows = await store.listDue(ownerUserId: 'read_outbox_owner');
    expect(rows, hasLength(1));
    expect(rows.single.lastReadAtMs, 200);
    expect(rows.single.lastReadMessageId, 'new-message');

    await store.acknowledge(
      ownerUserId: 'read_outbox_owner',
      conversationId: 'c2c_bob',
      lastReadAtMs: 100,
    );
    rows = await store.listDue(ownerUserId: 'read_outbox_owner');
    expect(rows, hasLength(1));

    await store.acknowledge(
      ownerUserId: 'read_outbox_owner',
      conversationId: 'c2c_bob',
      lastReadAtMs: 200,
    );
    expect(
      await store.listDue(ownerUserId: 'read_outbox_owner'),
      isEmpty,
    );
  });

  test('read receipt row is removed only after explicit acknowledgement',
      () async {
    final store = ReadReceiptOutboxStore.instance;
    await store.enqueue(
      ownerUserId: 'read_outbox_owner',
      messageIds: const <String>['m1', 'm2', 'm1'],
    );

    expect(
      await store.listDue(ownerUserId: 'read_outbox_owner'),
      hasLength(2),
    );
    await store.acknowledge(
      ownerUserId: 'read_outbox_owner',
      messageIds: const <String>['m1'],
    );
    final rows = await store.listDue(ownerUserId: 'read_outbox_owner');
    expect(rows.map((row) => row.messageId), <String>['m2']);
  });
}
