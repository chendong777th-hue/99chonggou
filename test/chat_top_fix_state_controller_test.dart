import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_top_fix_state_controller.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_game_round_status.dart';

void main() {
  test('setSnapshot notifies only when top fixed snapshot changes', () {
    final controller = ChatTopFixStateController();
    var notifyCount = 0;
    controller.addListener(() => notifyCount++);

    controller.setSnapshot(
      noticeText: ' hello ',
      showGroupGameBanner: true,
      doorCount: 12,
      roundStatus: const GroupGameRoundStatus(
        bankerName: 'Alice',
        bankerDoor: 2,
        totalBetCount: 8,
        doorBetTotals: [1, 7],
      ),
    );
    expect(notifyCount, 1);
    expect(controller.noticeText, 'hello');
    expect(controller.doorCount, 10);

    controller.setSnapshot(
      noticeText: 'hello',
      showGroupGameBanner: true,
      doorCount: 10,
      roundStatus: const GroupGameRoundStatus(
        bankerName: 'Alice',
        bankerDoor: 2,
        totalBetCount: 8,
        doorBetTotals: [1, 7],
      ),
    );
    expect(notifyCount, 1);

    controller.setSnapshot(
      noticeText: 'hello',
      showGroupGameBanner: true,
      doorCount: 10,
      roundStatus: const GroupGameRoundStatus(
        bankerName: 'Alice',
        bankerDoor: 2,
        totalBetCount: 9,
        doorBetTotals: [2, 7],
      ),
    );
    expect(notifyCount, 2);

    controller.setSnapshot(
      noticeText: '',
      showGroupGameBanner: false,
      doorCount: 1,
      roundStatus: const GroupGameRoundStatus(),
      notify: false,
    );
    expect(notifyCount, 2);
    expect(controller.noticeText, '');
    expect(controller.showGroupGameBanner, isFalse);
    expect(controller.doorCount, 2);

    controller.dispose();
  });
}
