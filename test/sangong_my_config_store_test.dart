import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_my_config.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/sangong_my_config_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/sangong_my_config_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SangongMyConfigStore', () {
    test('write and read round-trip', () async {
      const owner = 'user_sangong_cfg_test';
      const config = SangongMyConfig(
        configured: true,
        tenantId: '@TGS#GAME_A',
        name: '一号厅',
        imGroupGameId: '@TGS#GAME_A',
        imGroupAdminStatsId: '@TGS#REPORT_A',
        imBotUserId: 'bot_a',
        myRole: 'owner',
        canEditConfig: true,
        canManageMembers: true,
      );
      await SangongMyConfigStore.instance.write(
        ownerUserId: owner,
        config: config,
      );
      final loaded = await SangongMyConfigStore.instance.read(
        ownerUserId: owner,
      );
      expect(loaded, isNotNull);
      expect(loaded!.isSameAs(config), isTrue);

      await SangongMyConfigStore.instance.clearOwner(owner);
      final cleared = await SangongMyConfigStore.instance.read(
        ownerUserId: owner,
      );
      expect(cleared, isNull);
    });
  });

  group('SangongMyConfigService.resolveGroupAccess', () {
    test('needs setup when not configured', () {
      final access = SangongMyConfigService.resolveGroupAccess(
        config: const SangongMyConfig(configured: false),
        groupId: '@TGS#ANY',
        userPrivileged: true,
      );
      expect(access.needsSetup, isTrue);
      expect(access.hasOpsAccess, isFalse);
    });

    test('ops when current group matches bound game group', () {
      final access = SangongMyConfigService.resolveGroupAccess(
        config: const SangongMyConfig(
          configured: true,
          imGroupGameId: '@TGS#GAME_A',
          tenantId: '@TGS#GAME_A',
          myRole: 'owner',
          canEditConfig: true,
          canManageMembers: true,
        ),
        groupId: '@TGS#GAME_A',
        userPrivileged: true,
      );
      expect(access.configured, isTrue);
      expect(access.hasOpsAccess, isTrue);
      expect(access.canEditConfig, isTrue);
    });

    test('hidden when group mismatches', () {
      final access = SangongMyConfigService.resolveGroupAccess(
        config: const SangongMyConfig(
          configured: true,
          imGroupGameId: '@TGS#GAME_A',
        ),
        groupId: '@TGS#OTHER',
        userPrivileged: true,
      );
      expect(access.hasEntry, isFalse);
    });
  });
}
