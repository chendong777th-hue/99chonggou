import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registers AppNavigator fallback for chat overlay routes', () {
    final source =
        File('lib/src/widgets/forward_pick_pages.dart').readAsStringSync();
    expect(source, contains('appRootNavigator'));
    expect(source, contains('AppNavigator.key.currentState'));
  });

  test('message tooltip resolves root navigator with uikit helper', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_message_tooltip.dart',
    ).readAsStringSync();
    expect(source, contains('resolveUIKitRootNavigator(context)'));
    expect(source, contains('showUIKitOverlayConfirmDialog'));
    expect(
      source,
      isNot(contains('Navigator.maybeOf(context, rootNavigator: true)')),
    );
  });
}
