import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_bubble_insert_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_record.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

V2TimMessage _inviteOnly(String callId) {
  final payload = jsonEncode(<String, dynamic>{
    'businessID': 'lk_call',
    'action': 'invite',
    'callId': callId,
  });
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': 100,
    'message_is_from_self': true,
    'message_status': 2,
    'message_custom_str': payload,
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
  message.customElem = V2TimCustomElem(data: payload);
  message.timestamp = 100;
  message.msgID = 'invite_$callId';
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('CallBubbleInsertService.buildTerminalBubbleMessage', () {
    test('hangup bubble is history-visible with duration', () {
      final record = CallResultRecord(
        callId: 'call_insert_1',
        conversationId: 'c2c_peer_a',
        callerUserId: 'self_a',
        operatorUserId: 'self_a',
        peerUserId: 'peer_a',
        protocolType: CallProtocolType.hangup,
        durationSec: 42,
        endedAtMs: 1784077700000,
        isOutgoing: true,
        mediaType: 'video',
      );
      final message = CallBubbleInsertService.buildTerminalBubbleMessage(record);
      expect(message, isNotNull);
      final provider = CallingMessageDataProvider(message!);
      expect(provider.shouldDisplayInHistory, isTrue);
      expect(provider.protocolType, CallProtocolType.hangup);
      expect(provider.content, contains('42'));
      expect(message.localCustomData, contains('localCallBubble'));
    });

    test('reject bubble displays without positive duration', () {
      final record = CallResultRecord(
        callId: 'call_insert_reject',
        conversationId: 'c2c_peer_a',
        callerUserId: 'peer_a',
        operatorUserId: 'self_a',
        peerUserId: 'peer_a',
        protocolType: CallProtocolType.reject,
        durationSec: 0,
        endedAtMs: 1784077700000,
        isOutgoing: false,
      );
      final message = CallBubbleInsertService.buildTerminalBubbleMessage(record);
      expect(message, isNotNull);
      final provider = CallingMessageDataProvider(message!);
      expect(provider.shouldDisplayInHistory, isTrue);
      expect(provider.protocolType, CallProtocolType.reject);
    });
  });

  group('CallBubbleInsertService.hasTerminalBubbleForCallId', () {
    test('invite-only mid-state does not block insert', () {
      expect(
        CallBubbleInsertService.hasTerminalBubbleForCallId(
          <V2TimMessage>[_inviteOnly('call_x')],
          callId: 'call_x',
        ),
        isFalse,
      );
    });

    test('local marker counts as terminal bubble', () {
      final record = CallResultRecord(
        callId: 'call_y',
        conversationId: 'c2c_peer_a',
        callerUserId: 'self_a',
        operatorUserId: 'self_a',
        peerUserId: 'peer_a',
        protocolType: CallProtocolType.hangup,
        durationSec: 3,
        endedAtMs: 1784077700000,
        isOutgoing: true,
      );
      final bubble =
          CallBubbleInsertService.buildTerminalBubbleMessage(record)!;
      expect(
        CallBubbleInsertService.hasTerminalBubbleForCallId(
          <V2TimMessage>[bubble],
          callId: 'call_y',
        ),
        isTrue,
      );
    });
  });
}
