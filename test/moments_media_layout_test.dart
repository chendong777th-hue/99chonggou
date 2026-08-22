import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_media_layout.dart';

MomentAttachment image(int width, int height) => MomentAttachment(
      type: MomentMediaType.image,
      path: 'image.jpg',
      width: width,
      height: height,
    );

void main() {
  test('single image keeps normal ratio within safe feed bounds', () {
    expect(MomentsMediaLayout.singleAspectRatio(image(1200, 1000)), 1.2);
    expect(MomentsMediaLayout.singleAspectRatio(image(1000, 1200)),
        closeTo(5 / 6, 0.0001));
  });

  test('extreme image ratios are capped', () {
    expect(MomentsMediaLayout.singleAspectRatio(image(3000, 1000)), 16 / 9);
    expect(MomentsMediaLayout.singleAspectRatio(image(1000, 3000)), 3 / 4);
  });

  test('long image detection requires a two-to-one portrait image', () {
    expect(MomentsMediaLayout.isLongImage(image(1000, 2000)), isTrue);
    expect(MomentsMediaLayout.isLongImage(image(1000, 1999)), isFalse);
  });

  testWidgets('long image frame keeps its real ratio within max height',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 300,
        child: MomentsSingleMediaFrame(
          item: image(600, 2400),
          maxLongImageHeight: 400,
          child: const ColoredBox(
            key: Key('long-image-content'),
            color: Colors.red,
          ),
        ),
      ),
    ));
    final box = tester.getSize(find.byKey(const Key('long-image-content')));
    expect(box.width, 100);
    expect(box.height, 400);
  });
}
