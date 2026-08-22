import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';

V2TimMessage _msg({
  required String id,
  required int status,
  int timestamp = 100,
  bool isPeerRead = false,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': timestamp,
    'message_msg_id': id,
    'message_is_from_self': true,
    'message_status': status,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
  message.status = status;
  message.isPeerRead = isPeerRead;
  message.timestamp = timestamp;
  return message;
}

V2TimConversation _conv({
  required String id,
  V2TimMessage? last,
}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    lastMessage: last,
    unreadCount: 0,
  );
}

void main() {
  group('message status rank / upgrade', () {
    test('SENDING ranks below SUCC and FAIL', () {
      expect(
        GroupTipsMessageHelper.messageStatusRank(
          MessageStatus.V2TIM_MSG_STATUS_SENDING,
        ),
        lessThan(
          GroupTipsMessageHelper.messageStatusRank(
            MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          ),
        ),
      );
      expect(
        GroupTipsMessageHelper.shouldPreferIncomingMessageStatus(
          existingStatus: MessageStatus.V2TIM_MSG_STATUS_SENDING,
          incomingStatus: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
        ),
        isTrue,
      );
      expect(
        GroupTipsMessageHelper.shouldPreferIncomingMessageStatus(
          existingStatus: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          incomingStatus: MessageStatus.V2TIM_MSG_STATUS_SENDING,
        ),
        isFalse,
      );
    });

    test('pickPreferredLastMessage upgrades same id SENDING to SUCC', () {
      final sending = _msg(
        id: 'm1',
        status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
      );
      final succ = _msg(
        id: 'm1',
        status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      );
      final preferred = GroupTipsMessageHelper.pickPreferredLastMessage(
        existing: sending,
        incoming: succ,
      );
      expect(preferred?.status, MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC);
    });

    test('shouldUpgradeSameIdLastMessage treats revoke as upgrade', () {
      final succ = _msg(
        id: 'm1',
        status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      );
      final revoked = _msg(
        id: 'm1',
        status: MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED,
      );
      applyRevokedStateToMessage(revoked);
      expect(
        GroupTipsMessageHelper.shouldUpgradeSameIdLastMessage(
          existing: succ,
          incoming: revoked,
        ),
        isTrue,
      );
      expect(
        GroupTipsMessageHelper.shouldUpgradeSameIdLastMessage(
          existing: revoked,
          incoming: succ,
        ),
        isFalse,
      );
      final preferred = GroupTipsMessageHelper.pickPreferredLastMessage(
        existing: succ,
        incoming: revoked,
      );
      expect(isRevokedMessage(preferred), isTrue);
    });
  });

  group('conversationUiFingerprint includes status', () {
    test('SENDING and SUCC fingerprints differ for same msgID', () {
      final sending = _conv(
        id: 'c2c_u1',
        last: _msg(
          id: 'm1',
          status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
        ),
      );
      final succ = _conv(
        id: 'c2c_u1',
        last: _msg(
          id: 'm1',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
        ),
      );
      expect(
        ConversationListNotifier.conversationUiFingerprint(sending),
        isNot(ConversationListNotifier.conversationUiFingerprint(succ)),
      );
    });
  });

  group('applyLastMessageLocally status upgrade', () {
    late ConversationListNotifier notifier;

    setUp(() {
      notifier = ConversationListNotifier.instance;
      notifier.setConversationsForTest([
        _conv(
          id: 'c2c_u1',
          last: _msg(
            id: 'm1',
            status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
          ),
        ),
      ]);
    });

    test('same msgID SENDING to SUCC updates lastMessage', () {
      notifier.applyLastMessageLocally(
        conversationID: 'c2c_u1',
        message: _msg(
          id: 'm1',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
        ),
      );
      expect(
        notifier.conversations.single.lastMessage?.status,
        MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      );
    });

    test('same msgID SUCC to SENDING does not regress', () {
      notifier.setConversationsForTest([
        _conv(
          id: 'c2c_u1',
          last: _msg(
            id: 'm1',
            status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          ),
        ),
      ]);
      notifier.applyLastMessageLocally(
        conversationID: 'c2c_u1',
        message: _msg(
          id: 'm1',
          status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
        ),
      );
      expect(
        notifier.conversations.single.lastMessage?.status,
        MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      );
    });
  });
}
