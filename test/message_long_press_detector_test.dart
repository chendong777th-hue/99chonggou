import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart';

void main() {
  Widget buildHarness({
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: TelegramMessageLongPressDetector(
            onLongPress: onLongPress,
            child: GestureDetector(
              key: const ValueKey<String>('message-bubble'),
              onTap: onTap,
              child: const SizedBox(width: 180, height: 80),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('long press wins without activating the bubble tap',
      (tester) async {
    var taps = 0;
    var longPresses = 0;
    await tester.pumpWidget(buildHarness(
      onTap: () => taps++,
      onLongPress: () => longPresses++,
    ));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('message-bubble'))),
    );
    await tester.pump(const Duration(milliseconds: 499));
    expect(longPresses, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(longPresses, 1);

    await gesture.up();
    await tester.pump();
    expect(longPresses, 1);
    expect(taps, 0);
  });

  testWidgets('drag intent rejects the pending long press', (tester) async {
    var longPresses = 0;
    await tester.pumpWidget(buildHarness(
      onTap: () {},
      onLongPress: () => longPresses++,
    ));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('message-bubble'))),
    );
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();

    expect(longPresses, 0);
  });
}
