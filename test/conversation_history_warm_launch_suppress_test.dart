import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_history_warm_scheduler.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ConversationHistoryWarmScheduler.instance.resetForTest();
  });

  tearDown(() {
    ConversationHistoryWarmScheduler.instance.resetForTest();
  });

  test('armLaunchWarmSuppress blocks viewport warm', () async {
    final warm = ConversationHistoryWarmScheduler.instance;
    warm.armLaunchWarmSuppress(duration: const Duration(seconds: 30));
    await warm.runViewportWarm(
      visibleOrdered: [
        V2TimConversation(
          conversationID: 'c2c_warm_1',
          type: 1,
          userID: 'u1',
        ),
      ],
      reason: 'test_launch_suppress',
    );
    expect(warm.isPausedForMembershipSync, isFalse);
  });

  test('setPausedForMembershipSync toggles flag', () {
    final warm = ConversationHistoryWarmScheduler.instance;
    warm.setPausedForMembershipSync(true, reason: 'test');
    expect(warm.isPausedForMembershipSync, isTrue);
    warm.setPausedForMembershipSync(false, reason: 'test_done');
    expect(warm.isPausedForMembershipSync, isFalse);
  });
}
