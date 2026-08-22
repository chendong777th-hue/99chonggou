import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/red_packet_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await RedPacketLocalStore.instance.clearForTest();
  });

  test('markOpened and isOpened persist by orderId', () async {
    const owner = 'test-user-1';
    expect(
      await RedPacketLocalStore.instance.isOpened(
        orderId: 'rp-1',
        ownerUserId: owner,
      ),
      isFalse,
    );

    await RedPacketLocalStore.instance.markOpened(
      orderId: 'rp-1',
      ownerUserId: owner,
    );

    expect(
      await RedPacketLocalStore.instance.isOpened(
        orderId: 'rp-1',
        ownerUserId: owner,
      ),
      isTrue,
    );
    expect(
      await RedPacketLocalStore.instance.isOpened(
        orderId: 'rp-2',
        ownerUserId: owner,
      ),
      isFalse,
    );
  });

  test('markOpened aliases clientOrderId and orderId', () async {
    const owner = 'test-user-2';
    await RedPacketLocalStore.instance.markOpened(
      orderId: 'server-order-1',
      ownerUserId: owner,
      aliasOrderIds: ['client-order-1'],
    );

    expect(
      await RedPacketLocalStore.instance.isOpened(
        orderId: 'client-order-1',
        ownerUserId: owner,
      ),
      isTrue,
    );
    expect(
      RedPacketLocalStore.instance.peekOpened(
        orderId: 'server-order-1',
        ownerUserId: owner,
      )?.claimed,
      isFalse,
    );
  });
}
