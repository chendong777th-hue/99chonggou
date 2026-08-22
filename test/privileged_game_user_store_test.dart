import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/privileged_game_user_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PrivilegedGameUserStore', () {
    test('write and read round-trip', () async {
      const owner = 'user_priv_test';
      await PrivilegedGameUserStore.instance.write(
        ownerUserId: owner,
        gameEnabled: true,
      );
      final enabled = await PrivilegedGameUserStore.instance.read(
        ownerUserId: owner,
      );
      expect(enabled, isTrue);

      await PrivilegedGameUserStore.instance.write(
        ownerUserId: owner,
        gameEnabled: false,
      );
      final disabled = await PrivilegedGameUserStore.instance.read(
        ownerUserId: owner,
      );
      expect(disabled, isFalse);

      await PrivilegedGameUserStore.instance.clearOwner(owner);
      final cleared = await PrivilegedGameUserStore.instance.read(
        ownerUserId: owner,
      );
      expect(cleared, isNull);
    });
  });
}
