import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/chat_list_viewport_insert_controller.dart';

void main() {
  test('CVP waits 8 frames to measure queued insert row heights', () {
    expect(
      ChatListViewportInsertController.continuousViewportPushMeasureMaxAttempts,
      8,
    );

    final list = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();
    expect(list.contains('_continuousViewportPushMeasureMaxAttempts'), isTrue);
    expect(list.contains('if (attempt < 4)'), isFalse);
  });

  test('CVP measure miss force-pins and skips insert windows', () {
    final list = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();

    expect(list.contains('forcePinOnMiss: true'), isTrue);
    expect(list.contains('cvp_measure_miss_force_pin'), isTrue);
    expect(
      list.contains(
        '_scheduleForcePinScrollToBottom(ignoreInsertWindows: true)',
      ),
      isTrue,
    );
    expect(list.contains('_forcePinIgnoreInsertWindows'), isTrue);
    expect(
      list.contains('bool ignoreInsertWindows = false'),
      isTrue,
    );
  });
}
