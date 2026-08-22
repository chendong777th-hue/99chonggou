import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the constraint contract of [LiveKitCallPage] small-video PiP:
/// [Positioned] must pin both width and height, otherwise flutter_webrtc's
/// [RTCVideoView] expands to constraints.maxHeight (often Infinity).
void main() {
  testWidgets('PiP Positioned with width+height stays 110x216', (tester) async {
    Size? childSize;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 88,
                right: 20,
                width: 110,
                height: 216,
                child: LayoutBuilder(
                  builder: (context, pipConstraints) {
                    childSize = Size(
                      pipConstraints.maxWidth,
                      pipConstraints.maxHeight,
                    );
                    // Simulate RTCVideoView: fill max constraints.
                    return ColoredBox(
                      color: Colors.black54,
                      child: SizedBox(
                        width: pipConstraints.maxWidth,
                        height: pipConstraints.maxHeight,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(childSize, const Size(110, 216));
  });

  testWidgets(
    'PiP Positioned with only top/right yields unbounded maxHeight',
    (tester) async {
      BoxConstraints? childConstraints;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 88,
                  right: 20,
                  // Bug signature: no width/height on Positioned.
                  child: SizedBox(
                    width: 110,
                    child: LayoutBuilder(
                      builder: (context, pipConstraints) {
                        childConstraints = pipConstraints;
                        // Do not expand to Infinity — only capture constraints.
                        return const ColoredBox(color: Colors.black54);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(childConstraints, isNotNull);
      expect(childConstraints!.maxWidth, 110);
      // This is what RTCVideoView consumes as its height → full-screen strip.
      expect(childConstraints!.hasBoundedHeight, isFalse);
    },
  );
}
