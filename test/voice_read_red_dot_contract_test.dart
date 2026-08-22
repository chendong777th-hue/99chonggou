import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual voice play marks read via alias-aware localCustomInt update', () {
    final sound = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitMessageItem/tim_uikit_chat_sound_elem.dart',
    ).readAsStringSync();
    final globalModel = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();
    final listItem = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart',
    ).readAsStringSync();

    expect(sound.contains('unawaited(_markVoiceReadIfNeeded())'), isTrue);
    expect(sound.contains('widget.message.localCustomInt = HistoryMessageDartConstant.read'),
        isTrue);
    expect(sound.contains('if (widget.isFromSelf || widget.msgID.isEmpty)'),
        isFalse);

    final methodStart = globalModel.indexOf('Future<bool> setLocalCustomInt(');
    final methodEnd = globalModel.indexOf('Future<V2TimValueCallback<V2TimMessage>> _sendMessage(', methodStart);
    final method = globalModel.substring(methodStart, methodEnd);
    expect(method.contains('_resolveMessageListStorageKey(conversationID)'),
        isTrue);
    expect(method.contains('rawMessageList(conversationID)'), isTrue);
    expect(method.contains("item.id?.trim() ?? ''"), isTrue);
    expect(method.contains("_bumpMessageListRevisionFor("), isTrue);
    expect(method.contains('_markNeedsNotify()'), isTrue);
    expect(method.contains('_messageListMap[conversationID] ?? []'), isFalse);
    expect(method.contains('setMessageList(conversationID, messageList'),
        isFalse);

    expect(
      listItem.contains('message.localCustomInt != HistoryMessageDartConstant.read'),
      isTrue,
    );
  });
}
