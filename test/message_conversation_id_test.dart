import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';

V2TimMessage _message({String? groupID, String? userID, String? sender}) {
  return V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': 1,
    'message_msg_id': 'm1',
    'message_is_from_self': false,
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  })
    ..groupID = groupID
    ..userID = userID
    ..sender = sender;
}

void main() {
  group('MessageConversationId.sameConversation', () {
    test('matches canonical and bare ids', () {
      expect(
        MessageConversationId.sameConversation('c2c_alice', 'alice'),
        isTrue,
      );
      expect(
        MessageConversationId.sameConversation('alice', 'c2c_alice'),
        isTrue,
      );
      expect(
        MessageConversationId.sameConversation('group_g1', 'g1'),
        isTrue,
      );
      expect(
        MessageConversationId.sameConversation('c2c_alice', 'c2c_alice'),
        isTrue,
      );
    });

    test('matches public group id aliases', () {
      expect(
        MessageConversationId.sameConversation(
          'group_@TGS#2C33QXM5CX',
          'group_2C33QXM5CX',
        ),
        isTrue,
      );
      expect(
        MessageConversationId.sameConversation(
          '@TGS#2C33QXM5CX',
          '2C33QXM5CX',
        ),
        isTrue,
      );
    });

    test('rejects different conversations', () {
      expect(
        MessageConversationId.sameConversation('c2c_alice', 'c2c_bob'),
        isFalse,
      );
      expect(
        MessageConversationId.sameConversation('group_g1', 'group_g2'),
        isFalse,
      );
    });

    test('rejects c2c vs group with same bare suffix', () {
      expect(
        MessageConversationId.sameConversation('c2c_x', 'group_x'),
        isFalse,
      );
      expect(
        MessageConversationId.sameConversation('group_x', 'c2c_x'),
        isFalse,
      );
    });

    test('treats dirty group_c2c_ as c2c peer', () {
      expect(
        MessageConversationId.looksLikeC2cConversationId('group_c2c_alice'),
        isTrue,
      );
      expect(
        MessageConversationId.sameConversation(
          'c2c_alice',
          'group_c2c_alice',
        ),
        isTrue,
      );
      expect(
        MessageConversationId.sameConversation(
          'group_c2c_alice',
          'group_alice',
        ),
        isFalse,
      );
    });
  });

  group('MessageConversationId.messageBelongsToConversation', () {
    test('rejects a group message attached to another group row', () {
      final message = _message(groupID: 'group-b');
      expect(
        MessageConversationId.messageBelongsToConversation(
          message,
          'group_group-a',
        ),
        isFalse,
      );
    });

    test('rejects C2C message attached to another peer row', () {
      final message = _message(userID: 'bob', sender: 'bob');
      expect(
        MessageConversationId.messageBelongsToConversation(
          message,
          'c2c_alice',
          loginUserId: 'me',
        ),
        isFalse,
      );
    });

    test('accepts equivalent group id forms', () {
      final message = _message(groupID: 'room-1');
      expect(
        MessageConversationId.messageBelongsToConversation(
          message,
          'group_room-1',
        ),
        isTrue,
      );
    });
  });
}
