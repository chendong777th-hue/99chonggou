import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_demo/src/utils/c2c_blocked_outgoing_message_sync.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';

V2TimMessage _selfMessage({
  required String id,
  required int status,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': 1700000000,
    'message_msg_id': id,
    'message_is_from_self': true,
    'message_status': status,
    'message_elem_type': MessageElemType.V2TIM_ELEM_TYPE_TEXT,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.id = id;
  message.msgID = id;
  message.isSelf = true;
  message.status = status;
  return message;
}

void main() {
  group('C2cBlockedOutgoingMessageSync', () {
    test('reconcileInFlightMessage marks sending self messages as blocked fail', () {
      final sending = _selfMessage(
        id: 'local_1',
        status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
      );

      final reconciled =
          C2cBlockedOutgoingMessageSync.reconcileInFlightMessage(sending);

      expect(reconciled, isNotNull);
      expect(reconciled!.status, MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL);
      expect(
        ErrorMessageConverter.getSendFailCode(reconciled),
        C2cBlockedOutgoingMessageSync.blockedCode,
      );
    });

    test('reconcileInFlightMessage ignores non-sending and peer messages', () {
      final failed = _selfMessage(
        id: 'local_2',
        status: MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL,
      );
      final peer = V2TimMessage.fromJson(<String, dynamic>{
        'message_server_time': 1700000000,
        'message_msg_id': 'remote_1',
        'message_is_from_self': false,
        'message_status': MessageStatus.V2TIM_MSG_STATUS_SENDING,
        'message_elem_type': MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        'message_custom_str': '',
        'message_risk_type_identified': 0,
        'message_sender_group_member_info': <String, dynamic>{},
        'message_group_at_user_array': <String>[],
      })
        ..id = 'remote_1'
        ..msgID = 'remote_1'
        ..isSelf = false
        ..status = MessageStatus.V2TIM_MSG_STATUS_SENDING;

      expect(C2cBlockedOutgoingMessageSync.reconcileInFlightMessage(failed), isNull);
      expect(C2cBlockedOutgoingMessageSync.reconcileInFlightMessage(peer), isNull);
    });

    test('markInFlight requires explicit relation_blocked reason', () {
      expect(
        C2cBlockedOutgoingMessageSync.shouldMarkInFlight(reason: ''),
        isFalse,
      );
      expect(
        C2cBlockedOutgoingMessageSync.shouldMarkInFlight(reason: 'cache_miss'),
        isFalse,
      );
      expect(
        C2cBlockedOutgoingMessageSync.shouldMarkInFlight(
          reason: C2cBlockedOutgoingMessageSync.relationBlockedReason,
        ),
        isTrue,
      );
    });
  });
}
