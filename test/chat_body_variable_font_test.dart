import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat body is configured for the bundled variable CJK font at wght 450', () {
    final textStyleSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/message_bubble_text_color.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      textStyleSource,
      contains("variableCjkFontFamily = 'NotoSansSCVariable'"),
    );
    expect(textStyleSource, contains('messageBodyFontVariationWeight = 450'));
    expect(textStyleSource, contains('messageBodyFontSize = 16'));
    expect(
      textStyleSource,
      contains("FontVariation('wght', messageBodyFontVariationWeight)"),
    );
    expect(pubspec, contains('assets/fonts/NotoSansSC-Variable.ttf'));
  });
}
