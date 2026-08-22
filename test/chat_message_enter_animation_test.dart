import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_message_enter_animation.dart';

void main() {
  testWidgets('wechat extent animation grows row instead of jumping',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ChatMessageEnterAnimation(
                duration: const Duration(milliseconds: 240),
                slideFromInputAnchor: false,
                fallbackSlideDistance: 12,
                startOpacity: 0.72,
                animateExtent: true,
                onFinished: () => finished = true,
                child: const SizedBox(height: 100, width: 100),
              ),
            ],
          ),
        ),
      ),
    );

    final animation = find.byType(ChatMessageEnterAnimation);
    expect(tester.getSize(animation).height, 0);

    await tester.pump(const Duration(milliseconds: 120));
    final middleHeight = tester.getSize(animation).height;
    expect(middleHeight, greaterThan(0));
    expect(middleHeight, lessThan(100));

    await tester.pumpAndSettle();
    expect(tester.getSize(animation).height, 100);
    expect(finished, isTrue);
  });
}
