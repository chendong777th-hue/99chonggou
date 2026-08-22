import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_notify_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';

void main() {
  group('ConversationNotifySyncService', () {
    test('recvOptToMuted treats unknown recvOpt as unmuted', () {
      expect(
        ConversationNotifySyncService.recvOptToMuted(null),
        isFalse,
      );
    });

    test('recvOptToMuted treats receive message as unmuted', () {
      expect(
        ConversationNotifySyncService.recvOptToMuted(
          ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE.index,
        ),
        isFalse,
      );
    });

    test('recvOptToMuted treats not notify as muted', () {
      expect(
        ConversationNotifySyncService.recvOptToMuted(
          ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE.index,
        ),
        isTrue,
      );
    });

    test('recvOptToMuted treats not receive as muted', () {
      expect(
        ConversationNotifySyncService.recvOptToMuted(
          ReceiveMsgOptEnum.V2TIM_NOT_RECEIVE_MESSAGE.index,
        ),
        isTrue,
      );
    });
  });
}
