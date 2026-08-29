import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile message context menu follows WeChat interaction contract', () {
    final detector = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart',
    ).readAsStringSync();
    final tooltip = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_message_tooltip.dart',
    ).readAsStringSync();

    expect(detector, contains('const Duration(milliseconds: 500)'));
    expect(detector, contains('The live selected message remains'));
    expect(detector, isNot(contains('_buildExtractedMessageRow(extracted')));
    expect(tooltip, contains('scrollDirection: Axis.horizontal'));
    expect(tooltip, contains('mobileTooltipRows = 2'));
    expect(tooltip, contains('mobileTooltipItemsPerPage'));
    expect(
      tooltip,
      contains('height: mobileWeChatMenuCellHeight * mobileTooltipRows'),
    );
  });
}
