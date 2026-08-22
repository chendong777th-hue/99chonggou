import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_presenter.dart';

void main() {
  test('scrim follows entrance until settled, then only slide backdrop', () {
    final latch = MediaPreviewEntranceLatch(onSettled: () {});
    const animation = AlwaysStoppedAnimation<double>(0.32);

    expect(latch.scrimOpacity(animation, 1.0), closeTo(0.32, 0.001));
    expect(latch.scrimOpacity(animation, 0.4), closeTo(0.128, 0.001));
    latch.dispose();
  });

  testWidgets('zero-duration route settles on first bind', (tester) async {
    var settled = 0;
    final latch = MediaPreviewEntranceLatch(onSettled: () => settled++);
    const animation = AlwaysStoppedAnimation<double>(0.0);

    await tester.pumpWidget(const SizedBox.shrink());
    latch.bind(animation, routeDuration: Duration.zero);
    expect(latch.settled, isTrue);
    expect(settled, 0);

    await tester.pump();
    expect(settled, 1);
    latch.dispose();
  });

  testWidgets('completed animation settles without waiting fallback',
      (tester) async {
    var settled = 0;
    final latch = MediaPreviewEntranceLatch(onSettled: () => settled++);
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    latch.bind(controller);
    expect(latch.settled, isTrue);
    await tester.pump();
    expect(settled, 1);

    latch.dispose();
    controller.dispose();
  });

  testWidgets('settled scrim follows slide backdrop only', (tester) async {
    final latch = MediaPreviewEntranceLatch(onSettled: () {});
    await tester.pumpWidget(const SizedBox.shrink());
    latch.bind(const AlwaysStoppedAnimation<double>(1.0));
    expect(latch.settled, isTrue);
    expect(
      latch.scrimOpacity(const AlwaysStoppedAnimation<double>(0.32), 1.0),
      1.0,
    );
    expect(
      latch.scrimOpacity(const AlwaysStoppedAnimation<double>(1.0), 0.4),
      0.4,
    );
    latch.dispose();
  });
}
