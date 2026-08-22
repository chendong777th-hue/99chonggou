import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_my_config.dart';

void main() {
  group('SangongMyConfig', () {
    test('parses unconfigured payload', () {
      final config = SangongMyConfig.fromJson({
        'ok': true,
        'configured': false,
      });
      expect(config.configured, isFalse);
      expect(config.canEditConfig, isFalse);
      expect(config.imGroupGameId, isEmpty);
    });

    test('parses owner config and save body', () {
      final config = SangongMyConfig.fromJson({
        'ok': true,
        'configured': true,
        'tenantId': '@TGS#GAME_A',
        'name': '一号厅',
        'imGroupGameId': '@TGS#GAME_A',
        'imGroupAdminStatsId': '@TGS#REPORT_A',
        'imGroupWaterId': '@TGS#WATER_A',
        'imBotUserId': 'bot_a',
        'myRole': 'owner',
        'canEditConfig': true,
        'canManageMembers': true,
      });
      expect(config.configured, isTrue);
      expect(config.isOwner, isTrue);
      expect(config.canEditConfig, isTrue);
      expect(config.canManageMembers, isTrue);
      expect(config.imGroupWaterId, '@TGS#WATER_A');
      expect(
        config.toSaveBody(),
        {
          'name': '一号厅',
          'imGroupGameId': '@TGS#GAME_A',
          'imGroupAdminStatsId': '@TGS#REPORT_A',
          'imGroupWaterId': '@TGS#WATER_A',
          'imBotUserId': 'bot_a',
        },
      );
    });

    test('admin defaults canEdit/canManage to false when omitted', () {
      final config = SangongMyConfig.fromJson({
        'configured': true,
        'imGroupGameId': '@TGS#GAME_A',
        'myRole': 'admin',
      });
      expect(config.isAdmin, isTrue);
      expect(config.canEditConfig, isFalse);
      expect(config.canManageMembers, isFalse);
    });
  });

  group('SangongTenantAccessMember', () {
    test('parses members', () {
      final member = SangongTenantAccessMember.fromJson({
        'imUserId': '100001',
        'role': 'admin',
        'isDefault': true,
      });
      expect(member.imUserId, '100001');
      expect(member.isAdmin, isTrue);
      expect(member.isDefault, isTrue);
    });
  });
}
