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
    expect(controller.contains('static const double menuCaptureMaxPixelRatio = 2.0'),
        isTrue);
    expect(controller.contains('double? maxPixelRatio'), isTrue);
  });

  test('list item uses menuCaptureMaxPixelRatio at capture site', () {
    expect(listItem.contains('menuCaptureMaxPixelRatio'), isTrue);
  });

  test('non-scrollable path inserts overlay before awaiting toImage', () {
    final presentAt = listItem.indexOf(
      'Future<void> _presentMobileTelegramContextMenu({',
    );
    expect(presentAt, greaterThanOrEqualTo(0));
    final present = listItem.substring(presentAt, presentAt + 6500);

    final scrollableBranch = present.indexOf('if (useScrollableMenu)');
    expect(scrollableBranch, greaterThanOrEqualTo(0));

    // After the scrollable branch returns, ordinary path must insert first.
    final afterScrollable = present.substring(scrollableBranch);
    final insertAt = afterScrollable.indexOf('insertMenuOverlay();');
    final unawaitedCaptureAt = afterScrollable.indexOf('unawaited(() async');
    expect(insertAt, greaterThanOrEqualTo(0));
    expect(unawaitedCaptureAt, greaterThan(insertAt));
    expect(afterScrollable.contains('markNeedsBuild()'), isTrue);
  });
}
