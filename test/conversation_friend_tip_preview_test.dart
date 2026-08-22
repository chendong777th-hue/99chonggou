import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_preview_text_cache.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_last_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_text_elem.dart';

V2TimMessage _textMessage({
  required String msgID,
  required String text,
  required String peerUserId,
  required int ts,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_msg_id': msgID,
    'message_server_time': ts,
    'message_is_from_self': false,
    'message_status': 1,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.msgID = msgID;
  message.timestamp = ts;
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
  message.textElem = V2TimTextElem(text: text);
  message.userID = peerUserId;
  return message;
}

V2TimMessage _friendTipMessage({
  required String msgID,
  required String peerUserId,
  required int ts,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_msg_id': msgID,
    'message_server_time': ts,
    'message_is_from_self': true,
    'message_status': 1,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.msgID = msgID;
  message.timestamp = ts;
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
  message.userID = peerUserId;
  message.customElem = V2TimCustomElem(
    data:
        '{"businessID":"$kFriendBecameFriendsBusinessID","text":"你们已成为好友，现在可以开始聊天了"}',
  );
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ConversationPreviewTextCache.instance.clear();
  });

  test('老会话有缓存聊天摘要时，成友 tip 不覆盖列表预览', () {
    const peer = 'qiu_old_friend';
    const convId = 'c2c_$peer';
    final chat = _textMessage(
      msgID: 'chat1',
      text: '看看是不是比较顺畅，丝滑',
      peerUserId: peer,
      ts: 100,
    );
    conversationListLastMessageAbstract(chat, const []);
    final tip = _friendTipMessage(
      msgID: 'tip1',
      peerUserId: peer,
      ts: 200,
    );
    final preview = conversationListLastMessageAbstract(tip, const []);
    expect(preview, '看看是不是比较顺畅，丝滑');
  });

  test('新会话无成友前缓存时，仍显示成友 tip 预览', () {
    const peer = 'peer_new';
    final tip = _friendTipMessage(
      msgID: 'tip1',
      peerUserId: peer,
      ts: 1,
    );
    final preview = conversationListLastMessageAbstract(tip, const []);
    expect(preview, contains('你们已成为好友'));
  });
}
