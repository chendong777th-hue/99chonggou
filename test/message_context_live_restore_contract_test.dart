import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('context menu keeps selected message visible for viewport restoration',
      () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart',
    ).readAsStringSync();
    expect(source, contains('selected message stays live'));
    expect(source, contains('insertMenuOverlay();'));
    expect(source, isNot(contains('_isBubbleExtracted = true')));
    expect(source, contains('_contextMenuAnchorViewportTop()'));
  });
}
