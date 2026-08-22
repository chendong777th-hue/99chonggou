import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_virtual_hydrate_policy.dart';

void main() {
  group('conversationVirtualHydrateCovered', () {
    test('inside window with margin → covered', () {
      expect(
        conversationVirtualHydrateCovered(
          center: 100,
          curStart: 20,
          curLength: 240,
          margin: 32,
        ),
        isTrue,
      );
    });

    test('near trailing edge → not covered', () {
      // curEnd = 260; curEnd - margin = 228; center 230 → 不覆盖
      expect(
        conversationVirtualHydrateCovered(
          center: 230,
          curStart: 20,
          curLength: 240,
          margin: 32,
        ),
        isFalse,
      );
    });

    test('near leading edge → not covered', () {
      expect(
        conversationVirtualHydrateCovered(
          center: 40,
          curStart: 20,
          curLength: 240,
          margin: 32,
        ),
        isFalse,
      );
    });

    test('window shorter than 2×margin → never covered', () {
      expect(
        conversationVirtualHydrateCovered(
          center: 30,
          curStart: 0,
          curLength: 60,
          margin: 32,
        ),
        isFalse,
      );
    });

    test('empty window → not covered', () {
      expect(
        conversationVirtualHydrateCovered(
          center: 10,
          curStart: 0,
          curLength: 0,
          margin: 32,
        ),
        isFalse,
      );
    });
  });

  group('conversationVirtualHydrateCenterStepAllows', () {
    test('first request always allowed', () {
      expect(
        conversationVirtualHydrateCenterStepAllows(
          lastCenter: null,
          center: 0,
          step: 8,
        ),
        isTrue,
      );
    });

    test('small delta blocked', () {
      expect(
        conversationVirtualHydrateCenterStepAllows(
          lastCenter: 100,
          center: 105,
          step: 8,
        ),
        isFalse,
      );
    });

    test('step reached allowed', () {
      expect(
        conversationVirtualHydrateCenterStepAllows(
          lastCenter: 100,
          center: 108,
          step: 8,
        ),
        isTrue,
      );
    });
  });

  group('conversationVirtualHydrateShouldJumpWindow', () {
    test('inside neighborhood stays put', () {
      expect(
        conversationVirtualHydrateShouldJumpWindow(
          viewportCenter: 100,
          curStart: 80,
          curLength: 40,
          radius: 20,
        ),
        isFalse,
      );
    });

    test('just past trailing neighborhood jumps', () {
      expect(
        conversationVirtualHydrateShouldJumpWindow(
          viewportCenter: 141,
          curStart: 80,
          curLength: 40,
          radius: 20,
        ),
        isTrue,
      );
    });

    test('just past leading neighborhood jumps', () {
      expect(
        conversationVirtualHydrateShouldJumpWindow(
          viewportCenter: 59,
          curStart: 80,
          curLength: 40,
          radius: 20,
        ),
        isTrue,
      );
    });

    test('equal to maxC does not jump', () {
      expect(
        conversationVirtualHydrateShouldJumpWindow(
          viewportCenter: 140,
          curStart: 80,
          curLength: 40,
          radius: 20,
        ),
        isFalse,
      );
    });

    test('empty window away from head jumps', () {
      expect(
        conversationVirtualHydrateShouldJumpWindow(
          viewportCenter: 80,
          curStart: 0,
          curLength: 0,
          radius: 20,
        ),
        isTrue,
      );
    });

    test('empty window at head does not jump', () {
      expect(
        conversationVirtualHydrateShouldJumpWindow(
          viewportCenter: 0,
          curStart: 0,
          curLength: 0,
          radius: 20,
        ),
        isFalse,
      );
    });
  });

  group('conversationVirtualHydrateShouldNotifyOnCoveredSkip', () {
    test('settle notify when window is non-empty', () {
      expect(
        conversationVirtualHydrateShouldNotifyOnCoveredSkip(
          forceNotify: true,
          slidingWindowUserExpanded: true,
          curStart: 80,
          curIsNotEmpty: true,
        ),
        isTrue,
      );
    });

    test('settle notify skipped on empty window', () {
      expect(
        conversationVirtualHydrateShouldNotifyOnCoveredSkip(
          forceNotify: true,
          slidingWindowUserExpanded: false,
          curStart: 0,
          curIsNotEmpty: false,
        ),
        isFalse,
      );
    });

    test('legacy unexpanded distant window still notifies', () {
      expect(
        conversationVirtualHydrateShouldNotifyOnCoveredSkip(
          forceNotify: false,
          slidingWindowUserExpanded: false,
          curStart: 40,
          curIsNotEmpty: true,
        ),
        isTrue,
      );
    });

    test('legacy expanded window without settle does not notify', () {
      expect(
        conversationVirtualHydrateShouldNotifyOnCoveredSkip(
          forceNotify: false,
          slidingWindowUserExpanded: true,
          curStart: 40,
          curIsNotEmpty: true,
        ),
        isFalse,
      );
    });
  });
}
