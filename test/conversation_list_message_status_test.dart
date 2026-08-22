import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/conversation_list_message_status.dart';

void main() {
  group('ConversationListMessageStatus.resolve', () {
    test('peer messages keep lastMessage snapshot', () {
      expect(
        ConversationListMessageStatus.resolve(
          isSelf: false,
          lastMessageStatus: MessageStatus.V2TIM_MSG_STATUS_SENDING,
          liveStatus: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
        ),
        MessageStatus.V2TIM_MSG_STATUS_SENDING,
      );
    });

    test('self messages prefer live memory status', () {
      expect(
        ConversationListMessageStatus.resolve(
          isSelf: true,
          lastMessageStatus: MessageStatus.V2TIM_MSG_STATUS_SENDING,
          liveStatus: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
        ),
        MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      );
    });

    test('self messages fall back to snapshot when chat list is not loaded', () {
      expect(
        ConversationListMessageStatus.resolve(
          isSelf: true,
          lastMessageStatus: MessageStatus.V2TIM_MSG_STATUS_SENDING,
          liveStatus: null,
        ),
        MessageStatus.V2TIM_MSG_STATUS_SENDING,
      );
    });
  });

  group('ConversationListMessageStatus icon kinds', () {
    test('sending snapshot still shows sending until live upgrades', () {
      final status = ConversationListMessageStatus.resolve(
        isSelf: true,
        lastMessageStatus: MessageStatus.V2TIM_MSG_STATUS_SENDING,
        liveStatus: null,
      );
      expect(ConversationListMessageStatus.showsSending(status), isTrue);
      expect(
        ConversationListMessageStatus.showsReceipt(
          isSelf: true,
          status: status,
        ),
        isFalse,
      );
    });

    test('live success switches to receipt without waiting lastMessage patch',
        () {
      final status = ConversationListMessageStatus.resolve(
        isSelf: true,
        lastMessageStatus: MessageStatus.V2TIM_MSG_STATUS_SENDING,
        liveStatus: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      );
      expect(ConversationListMessageStatus.showsSending(status), isFalse);
      expect(
        ConversationListMessageStatus.showsReceipt(
          isSelf: true,
          status: status,
        ),
        isTrue,
      );
    });
  });
}
