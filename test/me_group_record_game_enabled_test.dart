import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';

void main() {
  group('MeGroupRecord.gameEnabled', () {
    Map<String, dynamic> groupJson([Map<String, dynamic>? extra]) {
      return <String, dynamic>{
        'groupId': '@TGS#test',
        'groupType': 'Public',
        'groupName': '测试群',
        ...?extra,
      };
    }

    test('parses camelCase and snake_case values', () {
      expect(
        MeGroupRecord.fromJson(
          groupJson(<String, dynamic>{'gameEnabled': true}),
        ).gameEnabled,
        isTrue,
      );
      expect(
        MeGroupRecord.fromJson(
          groupJson(<String, dynamic>{'game_enabled': 1}),
        ).gameEnabled,
        isTrue,
      );
    });

    test('defaults missing and invalid values to false', () {
      expect(MeGroupRecord.fromJson(groupJson()).gameEnabled, isFalse);
      expect(
        MeGroupRecord.fromJson(
          groupJson(<String, dynamic>{'gameEnabled': 'invalid'}),
        ).gameEnabled,
        isFalse,
      );
    });

    test('copyWith preserves and updates value', () {
      final record = MeGroupRecord.fromJson(
        groupJson(<String, dynamic>{'gameEnabled': true}),
      );
      expect(record.copyWith().gameEnabled, isTrue);
      expect(record.copyWith(gameEnabled: false).gameEnabled, isFalse);
    });
  });
}
