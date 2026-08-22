import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_preview_center_loading_indicator.dart';

void main() {
  testWidgets('ImagePreviewCenterLoadingIndicator renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: ImagePreviewCenterLoadingIndicator(),
          ),
        ),
      ),
    );

    expect(find.byType(ImagePreviewCenterLoadingIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));

    final indicatorBox = tester.renderObject<RenderBox>(
      find.byType(ImagePreviewCenterLoadingIndicator),
    );
    expect(indicatorBox.size.width, 52);
    expect(indicatorBox.size.height, 52);
  });

  testWidgets('ImagePreviewLoadingLayer keeps indicator compact in expand stack',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: ImagePreviewLoadingLayer(),
        ),
      ),
    );

    final indicatorBox = tester.renderObject<RenderBox>(
      find.byType(ImagePreviewCenterLoadingIndicator),
    );
    expect(indicatorBox.size.width, 52);
    expect(indicatorBox.size.height, 52);
  });
}
