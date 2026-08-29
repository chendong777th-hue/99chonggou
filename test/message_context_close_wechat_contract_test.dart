import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('message context menu closes with WeChat-style priority', () {
    final controller = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart',
    ).readAsStringSync();
    final history = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();
    final listItem = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart',
    ).readAsStringSync();
    final globalModel = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart',
    ).readAsStringSync();

    expect(controller, contains('PopScope<void>'));
    expect(controller, contains('onPopInvokedWithResult'));
    expect(controller, contains('_dismissIfAllowed()'));
    expect(controller, contains('await Future<void>.delayed(remaining)'));
    expect(controller, contains('whenCompleteOrCancel'));
    expect(controller, contains('void _notifyDismissOnce()'));
    expect(controller, contains('onClose: _dismissFromAction'));
    expect(
      controller,
      isNot(contains('onClose: widget.onDismiss')),
    );
    expect(listItem, contains('Timer(remaining, closeTooltip)'));
    final dismissAllAt = globalModel.indexOf(
      'void dismissAllContextMenuOverlays()',
    );
    final endAt = globalModel.indexOf(
      'void endMessageContextMenuOverlay',
      dismissAllAt,
    );
    final dismissAllBody = globalModel.substring(dismissAllAt, endAt);
    expect(dismissAllBody, contains('_messageContextMenuOverlayDepth = 0'));
    expect(
      dismissAllBody,
      contains('_contextMenuViewportRestoreConversations.clear()'),
    );
    expect(
      dismissAllBody,
      contains('_contextMenuViewportRestoreTimers.clear()'),
    );
    expect(dismissAllBody, contains('setChatListUserScrolling(false)'));

    final endBody = globalModel.substring(endAt, endAt + 1800);
    expect(endBody, contains('setChatListUserScrolling(false)'));
    expect(history, contains('isMessageContextMenuOverlayOpen'));
    expect(history, contains('NeverScrollableScrollPhysics'));
    expect(history, isNot(contains('scroll_mutation type=jump')));
  });
}
