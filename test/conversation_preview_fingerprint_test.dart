import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_text_elem.dart';

V2TimMessage _textMessage(String text) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_msg_id': 'm1',
    'message_server_time': 1,
    'message_is_from_self': true,
    'message_status': 1,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.msgID = 'm1';
  message.elemType = 1;
  message.textElem = V2TimTextElem(text: text);
  return message;
}

V2TimConversation _conversationWithPreview(String text) {
  return V2TimConversation(
    conversationID: 'c2c_alice',
    type: 1,
    userID: 'alice',
    lastMessage: _textMessage(text),
  );
}

void main() {
  test('same message ID with changed preview text invalidates row cache', () {
    final previous = _conversationWithPreview('旧预览');
    final updated = _conversationWithPreview('新预览');

    expect(
      ConversationListNotifier.conversationUiFingerprint(previous),
      isNot(ConversationListNotifier.conversationUiFingerprint(updated)),
    );
    expect(
      ConversationListNotifier.listsEqualForUi([previous], [updated]),
      isFalse,
    );
  });
}
