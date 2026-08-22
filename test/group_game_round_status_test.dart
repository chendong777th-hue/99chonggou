import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_game_round_status.dart';

void main() {
  group('GroupGameRoundStatus', () {
    test('formats banker line without group name', () {
      const status = GroupGameRoundStatus(
        bankerName: '亚多利财务（新）不推名片',
        bankerDoor: 1,
        totalBetCount: 0,
      );
      expect(
        status.formatStatusLine(),
        '庄【亚多利财务（新）不推名片】1包共0注',
      );
    });

    test('leaves banker name blank when missing', () {
      const status = GroupGameRoundStatus(
        bankerDoor: 3,
        totalBetCount: 12,
      );
      expect(status.formatStatusLine(), '庄【】3包共12注');
    });

    test('leaves door blank when missing', () {
      const status = GroupGameRoundStatus(
        bankerName: '张三',
        totalBetCount: 5,
      );
      expect(status.formatStatusLine(), '庄【张三】包共5注');
    });

    test('leaves banker and door blank when both missing', () {
      const status = GroupGameRoundStatus();
      expect(status.formatStatusLine(), '庄【】包共0注');
    });

    test('shows banker limit when set', () {
      const status = GroupGameRoundStatus(
        bankerName: '用户199392001',
        bankerDoor: 6,
        bankerLimit: 5000,
        totalBetCount: 0,
      );
      expect(
        status.formatStatusLine(),
        '庄【用户199392001】6包共0注 限制5000注',
      );
    });

    test('door values follow configured door count', () {
      const status = GroupGameRoundStatus(
        doorBetTotals: [1, 2, 3, 4, 5, 6],
      );
      expect(status.doorValuesForCount(6), [1, 2, 3, 4, 5, 6]);
      expect(status.doorValuesForCount(4), [0, 0, 0, 0]);
    });
  });
}
