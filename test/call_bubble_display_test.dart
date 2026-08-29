import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_bubble_dedupe.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

V2TimMessage _callCustomMessage(String dataJson) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': 1784077600,
    'message_is_from_self': false,
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
  message.customElem = V2TimCustomElem(data: dataJson);
  message.timestamp = 1784077600;
  message.userID = 'peer_a';
  message.sender = 'peer_a';
  message.isSelf = false;
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('CallingMessageDataProvider call bubble visibility', () {
    test('lk_call hangup nested in data string displays in history', () {
      final payload = jsonEncode(<String, dynamic>{
        'inviteID': 'call_nested_hangup',
        'actionType': 1,
        'data': jsonEncode(<String, dynamic>{
          'action': 'hangup',
          'callId': 'call_nested_hangup',
          'duration': 32,
          'cmd': 'hangup',
          'callerId': 'self_a',
          'calleeId': 'peer_a',
        }),
      });
      final message = _callCustomMessage(payload);
      expect(CallingMessageDataProvider.looksLikeCallMessage(message), isTrue);

      final provider = CallingMessageDataProvider(message);
      expect(provider.isCallingSignal, isTrue);
      expect(provider.protocolType, CallProtocolType.hangup);
      expect(provider.shouldDisplayInHistory, isTrue);
      expect(provider.content, contains('32'));
    });

    test('invite-only c2c lk_call ringing state is visible', () {
      final payload = jsonEncode(<String, dynamic>{
        'businessID': 'lk_call',
        'action': 'invite',
        'callId': 'call_invite_only',
        'callerId': 'self_a',
        'calleeId': 'peer_a',
        'mediaType': 'video',
      });
      final message = _callCustomMessage(payload);
      final provider = CallingMessageDataProvider(message);
      expect(provider.isCallingSignal, isTrue);
      expect(provider.protocolType, CallProtocolType.send);
      expect(provider.shouldDisplayInHistory, isTrue);
    });

    test('callDirection marker incoming wins even when isSelf true', () {
      final payload = jsonEncode(<String, dynamic>{
        'businessID': 'lk_call',
        'action': 'hangup',
        'callId': 'call_dir_marker',
        'duration': 5,
        'callerId': 'peer_a',
        'calleeId': 'self_a',
      });
      final message = _callCustomMessage(payload);
      message.isSelf = true;
      message.sender = 'self_a';
      message.localCustomData = jsonEncode(<String, dynamic>{
        'localCallBubble': true,
        'callId': 'call_dir_marker',
        'conversationID': 'c2c_peer_a',
        'callDirection': 'incoming',
      });
      final provider = CallingMessageDataProvider(message);
      expect(provider.direction, CallMessageDirection.incoming);
    });

    test('callDirection marker outgoing wins even when isSelf false', () {
      final payload = jsonEncode(<String, dynamic>{
        'businessID': 'lk_call',
        'action': 'hangup',
        'callId': 'call_dir_out',
        'duration': 5,
        'callerId': 'self_a',
        'calleeId': 'peer_a',
      });
      final message = _callCustomMessage(payload);
      message.isSelf = false;
      message.localCustomData = jsonEncode(<String, dynamic>{
        'localCallBubble': true,
        'callId': 'call_dir_out',
        'conversationID': 'c2c_peer_a',
        'callDirection': 'outgoing',
      });
      final provider = CallingMessageDataProvider(message);
      expect(provider.direction, CallMessageDirection.outcoming);
    });
  });

  group('CallBubbleDedupe.normalizeCallHistoryMessages', () {
    test('same call lifecycle keeps terminal hangup over ringing', () {
      final invite = _callCustomMessage(
        jsonEncode(<String, dynamic>{
          'businessID': 'lk_call',
          'action': 'invite',
          'callId': 'call_pair_1',
        }),
      );
      final hangup = _callCustomMessage(
        jsonEncode(<String, dynamic>{
          'businessID': 'lk_call',
          'action': 'hangup',
          'callId': 'call_pair_1',
          'duration': 12,
        }),
      );
      final normalized = CallBubbleDedupe.normalizeCallHistoryMessages(
        <V2TimMessage>[invite, hangup],
      );
      expect(normalized.length, 1);
      final provider = CallingMessageDataProvider(normalized.single);
      expect(provider.shouldDisplayInHistory, isTrue);
      expect(provider.protocolType, CallProtocolType.hangup);
    });

    test('same callId prefers IM hangup over local marker bubble', () {
      final imHangup = _callCustomMessage(
        jsonEncode(<String, dynamic>{
          'businessID': 'lk_call',
          'action': 'hangup',
          'callId': 'call_prefer_im',
          'duration': 8,
          'callerId': 'self_a',
          'calleeId': 'peer_a',
        }),
      );
      imHangup.msgID = 'im_hangup_prefer';
      imHangup.timestamp = 1784077601;

      final local = _callCustomMessage(
        jsonEncode(<String, dynamic>{
          'businessID': 'av_call',
          'call_type': 1,
          'call_end': 8,
          'callerId': 'self_a',
        }),
      );
      local.msgID = 'local_marker_prefer';
      local.timestamp = 1784077602;
      local.localCustomData = jsonEncode(<String, dynamic>{
        'localCallBubble': true,
        'callId': 'call_prefer_im',
        'inviteID': 'call_prefer_im',
        'conversationID': 'c2c_peer_a',
        'call_end': 8,
        'durationSec': 8,
      });

      final normalized = CallBubbleDedupe.normalizeCallHistoryMessages(
        <V2TimMessage>[local, imHangup],
      );
      expect(normalized.length, 1);
      expect(normalized.single.msgID, 'im_hangup_prefer');
      expect(
        CallingMessageDataProvider(normalized.single).protocolType,
        CallProtocolType.hangup,
      );
    });

    test('three repeated c2c terminal rows collapse to one bubble', () {
      final rows = <V2TimMessage>[];
      for (var i = 0; i < 3; i++) {
        final row = _callCustomMessage(
          jsonEncode(<String, dynamic>{
            'businessID': 'lk_call',
            'action': 'hangup',
            'callId': 'call_repeated_c2c',
            'duration': 11,
            'callerId': 'self_a',
            'calleeId': 'peer_a',
          }),
        );
        row.msgID = 'im_hangup_repeated_$i';
        row.timestamp = 1784077600 + i;
        rows.add(row);
      }

      final normalized = CallBubbleDedupe.normalizeCallHistoryMessages(rows);

      expect(normalized, hasLength(1));
      expect(normalized.single.msgID, 'im_hangup_repeated_2');
      expect(CallBubbleDedupe.extractInviteId(normalized.single),
          'call_repeated_c2c');
    });

    test('local terminal plus two IM hangups collapse to one IM bubble', () {
      const callId = 'call_mixed_three_sources';
      final local = _callCustomMessage(
        jsonEncode(<String, dynamic>{
          'businessID': 'lk_call',
          'action': 'hangup',
          'callId': callId,
          'duration': 11,
        }),
      );
      local.msgID = 'local_call_bubble_$callId';
      local.timestamp = 1784077660;
      local.localCustomData = jsonEncode(<String, dynamic>{
        'localCallBubble': true,
        'callId': callId,
        'inviteID': callId,
        'conversationID': 'c2c_peer_a',
        'call_end': 11,
        'durationSec': 11,
      });

      final firstIm = _callCustomMessage(
        jsonEncode(<String, dynamic>{
          'businessID': 'lk_call',
          'action': 'hangup',
          'callId': callId,
          'duration': 11,
        }),
      );
      firstIm.msgID = 'im_hangup_mixed_1';
      firstIm.timestamp = 1784077661;

      final secondIm = _callCustomMessage(
        jsonEncode(<String, dynamic>{
          'businessID': 'lk_call',
          'action': 'hangup',
          'callId': callId,
          'duration': 11,
        }),
      );
      secondIm.msgID = 'im_hangup_mixed_2';
      secondIm.timestamp = 1784077662;

      final normalized = CallBubbleDedupe.normalizeCallHistoryMessages(
        <V2TimMessage>[local, firstIm, secondIm],
      );

      expect(normalized, hasLength(1));
      expect(normalized.single.msgID, 'im_hangup_mixed_2');
      expect(normalized.single.localCustomData, isEmpty);
    });

    test('late ringing tip cannot replace terminal row for same callId', () {
      const callId = 'call_terminal_monotonic';
      final terminal = _callCustomMessage(
        jsonEncode(<String, dynamic>{
          'businessID': 'lk_call',
          'action': 'hangup',
          'callId': callId,
          'duration': 11,
        }),
      );
      terminal.msgID = 'local_call_bubble_$callId';
      terminal.timestamp = 1784077670;
      terminal.localCustomData = jsonEncode(<String, dynamic>{
        'localCallBubble': true,
        'callId': callId,
        'conversationID': 'c2c_peer_a',
        'call_end': 11,
      });

      final lateInvite = _callCustomMessage(
        jsonEncode(<String, dynamic>{
          'businessID': 'lk_call',
          'action': 'invite',
          'callId': callId,
        }),
      );
      lateInvite.msgID = 'im_late_invite';
      lateInvite.timestamp = 1784077671;

      final normalized = CallBubbleDedupe.normalizeCallHistoryMessages(
        <V2TimMessage>[terminal, lateInvite],
        preserveTipIdentity: true,
      );

      expect(normalized, hasLength(1));
      expect(normalized.single.msgID, 'local_call_bubble_$callId');
      expect(
        CallingMessageDataProvider(normalized.single).protocolType,
        CallProtocolType.hangup,
      );
    });

    test('preserveTipIdentity keeps tip hangup over alternate same call', () {
      final tip = _callCustomMessage(
        jsonEncode(<String, dynamic>{
          'businessID': 'lk_call',
          'action': 'hangup',
          'callId': 'call_tip_stable',
          'duration': 7,
          'callerId': 'self_a',
          'calleeId': 'peer_a',
        }),
      );
      tip.msgID = 'tip_hangup_new';
      tip.timestamp = 1785756847;
      tip.userID = 'peer_a';

      final older = _callCustomMessage(
        jsonEncode(<String, dynamic>{
          'businessID': 'lk_call',
          'action': 'hangup',
          'callId': 'call_tip_stable',
          'duration': 7,
          'callerId': 'self_a',
          'calleeId': 'peer_a',
        }),
      );
      older.msgID = 'tip_hangup_old';
      older.timestamp = 1785756840;
      older.userID = 'peer_a';

      final normalized = CallBubbleDedupe.normalizeCallHistoryMessages(
        <V2TimMessage>[tip, older],
        preserveTipIdentity: true,
      );
      expect(normalized.length, 1);
      expect(normalized.single.msgID, 'tip_hangup_new');
    });

    test('open hold defers without throwing and clears via endOpenHold', () {
      CallBubbleDedupe.resetOpenHoldForTesting();
      CallBubbleDedupe.beginOpenHold('c2c_peer_hold');
      expect(CallBubbleDedupe.isOpenHeldForTesting('peer_hold'), isTrue);
      expect(CallBubbleDedupe.isOpenHeldForTesting('c2c_peer_hold'), isTrue);
      CallBubbleDedupe.endOpenHold('peer_hold');
      expect(CallBubbleDedupe.isOpenHeldForTesting('peer_hold'), isFalse);
      CallBubbleDedupe.resetOpenHoldForTesting();
    });
  });
}
