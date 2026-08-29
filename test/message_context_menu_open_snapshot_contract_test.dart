import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String controller;
  late String listItem;

  setUpAll(() {
    controller = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart',
    ).readAsStringSync();
    listItem = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart',
    ).readAsStringSync();
  });

  test('menu capture soft-caps pixel ratio at 2.0', () {
    expect(controller.contains('menuCaptureMaxPixelRatio'), isTrue);
    expect(
        controller
            .contains('static const double menuCaptureMaxPixelRatio = 2.0'),
        isTrue);
    expect(controller.contains('double? maxPixelRatio'), isTrue);
  });

  test('ordinary path opens synchronously without raster capture', () {
    final presentAt = listItem.indexOf(
      'Future<void> _presentMobileTelegramContextMenu({',
    );
    expect(presentAt, greaterThanOrEqualTo(0));
    final present = listItem.substring(presentAt, presentAt + 6500);
    expect(present, contains('final useScrollableMenu = false;'));
    expect(present, contains('insertMenuOverlay();'));
    expect(present, isNot(contains('captureSnapshot(')));
    expect(present, isNot(contains('toImage(')));
  });
}
