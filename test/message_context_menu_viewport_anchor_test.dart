import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('context menu restore happens in scroll physics before paint', () {
    final listSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();
    final itemSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart',
    ).readAsStringSync();

    expect(
      listSource.contains('shouldPreserveNewestInsertExtent:'),
      isTrue,
    );
    expect(itemSource.contains('_LongPressViewportAnchor'), isFalse);
    expect(itemSource.contains('_scheduleLongPressViewportRestore'), isFalse);
    expect(itemSource.contains('anchorViewportTop:'), isTrue);
    expect(listSource.contains('_scheduleContextMenuViewportRestore'), isTrue);
    expect(
      listSource.contains('_contextForContextMenuAnchor'),
      isTrue,
      reason:
          'restore must resolve the selected row by stable key, not ordinal',
    );
    expect(
      listSource.contains('scroll_mutation_blocked'),
      isTrue,
      reason: 'menu restore must own ScrollPosition writes',
    );
    expect(
      listSource.contains('_contextMenuFrozenLayoutUnreadCount'),
      isTrue,
    );
    expect(
      listSource.contains('_contextMenuFrozenVisibleMessages'),
      isTrue,
      reason: 'background producers must not mutate the visible sliver tree',
    );

    final globalModel = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();
    final end = globalModel.indexOf(
      'void endMessageContextMenuOverlay({String? conversationID})',
    );
    expect(end, greaterThanOrEqualTo(0));
    final body = globalModel.substring(end, end + 1800);
    expect(
        body.contains('_contextMenuViewportRestoreConversations.add'), isTrue);
    expect(body.contains('requestPinToBottom(convId)'), isFalse);
    expect(globalModel.contains('MessageContextMenuViewportAnchor'), isTrue);
    expect(
      globalModel.contains('messageContextMenuTransactionGeneration'),
      isTrue,
    );
    expect(
      globalModel.contains('completeContextMenuViewportRestore'),
      isTrue,
    );
  });
}
