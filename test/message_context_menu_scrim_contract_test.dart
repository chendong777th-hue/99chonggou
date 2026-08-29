import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String telegramController;
  late String listItem;
  late String tooltip;

  setUpAll(() {
    telegramController = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart',
    ).readAsStringSync();
    listItem = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart',
    ).readAsStringSync();
    tooltip = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_message_tooltip.dart',
    ).readAsStringSync();
  });

  test('telegram menu shell has no live BackdropFilter blur', () {
    expect(telegramController.contains('BackdropFilter'), isFalse);
    expect(telegramController.contains('ImageFilter.blur'), isFalse);
    expect(telegramController.contains('ColoredBox'), isTrue);
  });

  test('legacy tooltip blur overlay has no live BackdropFilter blur', () {
    expect(listItem.contains('BackdropFilter'), isFalse);
    expect(listItem.contains('ImageFilter.blur'), isFalse);
  });

  test('delete/revoke closes tooltip before confirm dialog', () {
    final onTapAt = tooltip.indexOf(
      'Future<void> _onTap(String operation, TUIChatSeparateViewModel model)',
    );
    expect(onTapAt, greaterThanOrEqualTo(0));
    final deleteBranch = tooltip.substring(onTapAt, onTapAt + 3500);
    final closeAt = deleteBranch.indexOf('widget.onCloseTooltip();');
    final confirmAt = deleteBranch.indexOf('showUIKitOverlayConfirmDialog');
    expect(closeAt, greaterThanOrEqualTo(0));
    expect(confirmAt, greaterThanOrEqualTo(0));
    expect(closeAt, lessThan(confirmAt));
  });

  test('light ops run immediately after menu close', () {
    expect(tooltip.contains('_yieldAfterMenuClose'), isFalse);
    final copyAt = tooltip.indexOf('case "copyMessage":');
    expect(copyAt, greaterThanOrEqualTo(0));
    final beforeCopy = tooltip.substring(0, copyAt);
    expect(beforeCopy.contains('widget.onCloseTooltip();'), isTrue);
  });

  test('menu close preserves deferred messages during viewport restoration',
      () {
    final globalModel = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'view_models/tui_chat_global_model.dart',
    ).readAsStringSync();
    final endAt = globalModel.indexOf(
      'void endMessageContextMenuOverlay({String? conversationID})',
    );
    expect(endAt, greaterThanOrEqualTo(0));
    final body = globalModel.substring(endAt, endAt + 1800);
    expect(
        body.contains('_contextMenuViewportRestoreConversations.add'), isTrue);
    expect(body.contains('flushDeferredIncomingMessages'), isFalse);
    expect(body.contains('close_defer'), isTrue);
  });
}
