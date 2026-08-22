import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_slidable.dart';

void main() {
  group('conversationSlidableShouldArm', () {
    test('short vertical jitter does not arm actions', () {
      expect(
        conversationSlidableShouldArm(
          accumulatedDx: 4,
          accumulatedDy: 12,
        ),
        isFalse,
      );
      expect(
        conversationSlidableShouldArm(
          accumulatedDx: 2,
          accumulatedDy: 1,
        ),
        isFalse,
      );
    });

    test('clear horizontal swipe arms actions', () {
      expect(
        conversationSlidableShouldArm(
          accumulatedDx: 20,
          accumulatedDy: 6,
        ),
        isTrue,
      );
    });

    test('horizontal slop is larger than default vertical slop', () {
      expect(kConversationSlidableTouchSlop, greaterThan(18));
      expect(kConversationSlidableArmDistance, greaterThan(8));
    });
  });
}
