import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video full-screen preview does not pass the gallery action', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/widgets/video_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('onOpenMedia: null'),
    );
  });
}
