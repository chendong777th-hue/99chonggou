import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_game_api.dart';

void main() {
  group('GroupGameStatus', () {
    test('parses gameEnabled from camelCase', () {
      final status = GroupGameStatus.fromJson({'gameEnabled': true});
      expect(status.gameEnabled, isTrue);
    });

    test('parses gameEnabled from snake_case', () {
      final status = GroupGameStatus.fromJson({'game_enabled': true});
      expect(status.gameEnabled, isTrue);
    });

    test('defaults to false when field missing', () {
      const status = GroupGameStatus(gameEnabled: false);
      expect(status.gameEnabled, isFalse);
      expect(
        GroupGameStatus.fromJson(const {}).gameEnabled,
        isFalse,
      );
    });

    test('parses string boolean values', () {
      expect(
        GroupGameStatus.fromJson({'gameEnabled': 'true'}).gameEnabled,
        isTrue,
      );
      expect(
        GroupGameStatus.fromJson({'gameEnabled': 'false'}).gameEnabled,
        isFalse,
      );
    });
  });
}
