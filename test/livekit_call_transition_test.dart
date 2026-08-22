import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_navigator.dart';

void main() {
  test('call page enter fades; exit has zero reverse duration', () {
    expect(
      LiveKitCallNavigator.enterTransitionDuration,
      const Duration(milliseconds: 180),
    );
    expect(LiveKitCallNavigator.exitTransitionDuration, Duration.zero);
    expect(
      LiveKitCallNavigator.enterTransitionDuration >
          LiveKitCallNavigator.exitTransitionDuration,
      isTrue,
    );
  });

  testWidgets('waitForEnterSettled completes after enter window',
      (tester) async {
    var settled = false;
    final future = LiveKitCallNavigator.waitForEnterSettled().then((_) {
      settled = true;
    });
    expect(settled, isFalse);
    // Fake-async: advance past enter fade, then flush endOfFrame yields.
    await tester.pump(LiveKitCallNavigator.enterTransitionDuration);
    await tester.pump();
    await tester.pump();
    await future;
    expect(settled, isTrue);
  });
}
