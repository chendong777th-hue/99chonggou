import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final globalModel = File(
    'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
    'tui_chat_global_model.dart',
  ).readAsStringSync();
  final tongue = File(
    'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
    'TIMUIKItMessageList/TIMUIKitTongue/'
    'tim_uikit_chat_history_message_list_tongue_container.dart',
  ).readAsStringSync();

  test('bottom transaction outlives its timestamp fallback until explicit end',
      () {
    expect(
        globalModel, contains('_userScrollToBottomTransactionActive = true'));
    expect(
      globalModel,
      contains(
        'return _userScrollToBottomTransactionActive ||\n'
        '        DateTime.now().millisecondsSinceEpoch < _userScrollToBottomUntilMs;',
      ),
    );
    expect(
        globalModel, contains('_userScrollToBottomTransactionActive = false'));
  });

  test(
      'bottom completion drains coalesced and deferred inbound messages before cleanup',
      () {
    final drainMethod =
        'flushPendingIncomingMessagesForUserBottom(conversationID)';
    final drainMethodWithReceiver = 'globalModel.$drainMethod';
    final firstDrain = tongue.indexOf(drainMethodWithReceiver);
    final secondDrain = tongue.indexOf(drainMethodWithReceiver, firstDrain + 1);
    final cleanup = tongue.indexOf(
      'globalModel.unlockEntryUnreadForTongue(',
      secondDrain,
    );

    expect(firstDrain, greaterThanOrEqualTo(0));
    expect(secondDrain, greaterThan(firstDrain));
    expect(cleanup, greaterThan(secondDrain));
    expect(
      globalModel,
      contains('_inboundBatchCoalescer.flushConversation(key);'),
    );
    expect(
      globalModel,
      contains('if (state.bufferedMessages.isNotEmpty) {'),
    );
  });
}
