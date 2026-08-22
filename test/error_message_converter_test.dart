import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/c2c_peer_id.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';

V2TimMessage _failedSelfTextMessage() {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': 1700000000,
    'message_msg_id': 'fail_1',
    'message_is_from_self': true,
    'message_status': MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL,
    'message_elem_type': MessageElemType.V2TIM_ELEM_TYPE_TEXT,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.id = 'fail_1';
  message.msgID = 'fail_1';
  message.isSelf = true;
  message.status = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
  return message;
}

V2TimFriendInfo _friend(String userId, {Map<String, String>? custom}) {
  return V2TimFriendInfo(
    userID: userId,
    friendCustomInfo: custom,
  );
}

void main() {
  group('ErrorMessageConverter.shouldShowFriendDeletedHint', () {
    test('network send fail without code does not infer non-friend from c2c conv id',
        () {
      final message = _failedSelfTextMessage();
      final friends = [_friend('peer_a')];

      expect(
        ErrorMessageConverter.shouldShowFriendDeletedHint(
          message,
          c2cPeerUserId: 'c2c_peer_a',
          friendList: friends,
        ),
        isFalse,
      );
    });

    test('shows hint when sendFailCode is friend relation error', () {
      final message = _failedSelfTextMessage();
      ErrorMessageConverter.attachSendFailCode(message, 20011);

      expect(
        ErrorMessageConverter.shouldShowFriendDeletedHint(message),
        isTrue,
      );
    });

    test('shows hint when friend custom canMessage is blocked', () {
      final message = _failedSelfTextMessage();
      final friends = [
        _friend('peer_b', custom: {'canMessage': '0'}),
      ];

      expect(
        ErrorMessageConverter.shouldShowFriendDeletedHint(
          message,
          c2cPeerUserId: 'c2c_peer_b',
          friendList: friends,
        ),
        isTrue,
      );
    });

    test('does not show hint when peer is friend without block flags', () {
      final message = _failedSelfTextMessage();
      final friends = [
        _friend('peer_c', custom: {'canMessage': '1'}),
      ];

      expect(
        ErrorMessageConverter.shouldShowFriendDeletedHint(
          message,
          c2cPeerUserId: 'c2c_peer_c',
          friendList: friends,
        ),
        isFalse,
      );
    });

    test('does not show hint when peer missing from friend list without code',
        () {
      final message = _failedSelfTextMessage();

      expect(
        ErrorMessageConverter.shouldShowFriendDeletedHint(
          message,
          c2cPeerUserId: 'c2c_unknown',
          friendList: [_friend('other')],
        ),
        isFalse,
      );
    });

    test('normalizedPeerUserId strips c2c prefix', () {
      expect(
        ErrorMessageConverter.normalizedPeerUserId('c2c_Peer_A'),
        'peer_a',
      );
      expect(
        ErrorMessageConverter.normalizedPeerUserId('c2c_Peer_A'),
        C2cPeerId.normalize('c2c_Peer_A'),
      );
    });

    test('clearSendFailCode removes attached friend relation code', () {
      final message = _failedSelfTextMessage();
      ErrorMessageConverter.attachSendFailCode(message, 20011);
      expect(ErrorMessageConverter.getSendFailCode(message), 20011);
      ErrorMessageConverter.clearSendFailCode(message);
      expect(ErrorMessageConverter.getSendFailCode(message), isNull);
      expect(
        ErrorMessageConverter.shouldShowFriendDeletedHint(message),
        isFalse,
      );
    });
  });
}
