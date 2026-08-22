import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String menu;

  setUpAll(() {
    menu = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_mobile_telegram_message_menu.dart',
    ).readAsStringSync();
  });

  test('every reactionBarOnly shell disables live BackdropFilter', () {
    var from = 0;
    var count = 0;
    while (true) {
      final at = menu.indexOf(
        'layout: TelegramMobileTooltipLayout.reactionBarOnly',
        from,
      );
      if (at < 0) {
        break;
      }
      count++;
      final windowStart = at > 400 ? at - 400 : 0;
      final window = menu.substring(windowStart, at);
      expect(
        window.contains('useBackdropBlur: false'),
        isTrue,
        reason: 'reactionBarOnly #$count missing useBackdropBlur: false nearby',
      );
      from = at + 1;
    }
    expect(count, greaterThanOrEqualTo(2));
  });

  test('action menu shell still disables live BackdropFilter', () {
    expect(menu.contains('useBackdropBlur: false'), isTrue);
    expect(
      menu.contains('TelegramMobileTooltipLayout.actionMenuOnly'),
      isTrue,
    );
  });
}
