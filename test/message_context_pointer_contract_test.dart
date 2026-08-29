import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile context menu has a directional pointer to the message', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_mobile_telegram_message_menu.dart',
    ).readAsStringSync();
    expect(source, contains('_MenuPointerPainter'));
    expect(source, contains('pointsDown: !layout.menuBelowBubble'));
    expect(source, contains('pointerLeft'));
  });
}
