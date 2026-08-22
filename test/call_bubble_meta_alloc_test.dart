import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_bubble_dedupe.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

V2TimMessage _hangupMessage({
  required String callId,
  required int duration,
  required String msgId,
}) {
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
  message.customElem = V2TimCustomElem(
    data: jsonEncode(<String, dynamic>{
      'businessID': 'lk_call',
      'action': 'hangup',
      'callId': callId,
      'duration': duration,
      'callerId': 'self_a',
      'calleeId': 'peer_a',
    }),
  );
  message.timestamp = 1784077600;
  message.userID = 'peer_a';
  message.sender = 'peer_a';
  message.isSelf = false;
  message.msgID = msgId;
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  tearDown(() {
    CallBubbleDedupe.resetMetaCacheForTesting();
    CallBubbleDedupe.resetOpenHoldForTesting();
  });

  test('normalize hangups does not CallBubble-side jsonDecode customElem', () {
    // Invariant after plan 005: _buildMeta reads duration/room from
    // CallingMessageDataProvider (already decoded). CallBubbleDedupe's
    // _tryDecodeMap should not run for pure customElem hangups.
    final messages = <V2TimMessage>[
      for (var i = 0; i < 8; i++)
        _hangupMessage(
          callId: 'call_alloc_$i',
          duration: 10 + i,
          msgId: 'msg_alloc_$i',
        ),
    ];

    CallBubbleDedupe.resetMetaCacheForTesting();
    final normalized = CallBubbleDedupe.normalizeCallHistoryMessages(messages);

    expect(normalized.length, 8);
    expect(
      CallBubbleDedupe.debugJsonDecodeCount,
      0,
      reason: 'signal meta must not re-decode customElem after provider parse',
    );
  });

  test('local bubble marker decodes local JSON at most once per message', () {
    final local = V2TimMessage.fromJson(<String, dynamic>{
      'message_server_time': 1784077600,
      'message_is_from_self': false,
      'message_status': 2,
      'message_custom_str': '',
      'message_risk_type_identified': 0,
      'message_sender_group_member_info': <String, dynamic>{},
      'message_group_at_user_array': <String>[],
    });
    local.elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
    local.timestamp = 1784077600;
    local.userID = 'peer_a';
    local.sender = 'peer_a';
    local.isSelf = false;
    local.msgID = 'msg_local_once';
    // No customElem: duration + invite live entirely on local marker.
    local.localCustomData = jsonEncode(<String, dynamic>{
      'localCallBubble': true,
      'conversationID': 'c2c_peer_a',
      'callId': 'call_local_once',
      'call_end': 9,
    });

    CallBubbleDedupe.resetMetaCacheForTesting();
    final normalized =
        CallBubbleDedupe.normalizeCallHistoryMessages(<V2TimMessage>[local]);

    expect(normalized.length, 1);
    // One decode for localCustomData; no second pass via raw helpers.
    expect(CallBubbleDedupe.debugJsonDecodeCount, 1);
  });

  test('identical list normalize hits fingerprint cache (no extra jsonDecode)',
      () {
    final messages = <V2TimMessage>[
      for (var i = 0; i < 4; i++)
        _hangupMessage(
          callId: 'call_fp_$i',
          duration: 5 + i,
          msgId: 'msg_fp_$i',
        ),
    ];

    CallBubbleDedupe.resetMetaCacheForTesting();
    final first =
        CallBubbleDedupe.normalizeCallHistoryMessages(messages);
    final decodeAfterFirst = CallBubbleDedupe.debugJsonDecodeCount;
    expect(CallBubbleDedupe.debugNormalizeCacheSize(), greaterThan(0));

    final second =
        CallBubbleDedupe.normalizeCallHistoryMessages(messages);
    expect(
      identical(first, second) || listEquals(
        first.map((m) => m.msgID).toList(),
        second.map((m) => m.msgID).toList(),
      ),
      isTrue,
    );
    expect(
      CallBubbleDedupe.debugJsonDecodeCount,
      decodeAfterFirst,
      reason: 'second identical normalize must not rebuild metas',
    );

    messages[0].msgID = 'msg_fp_changed';
    CallBubbleDedupe.normalizeCallHistoryMessages(messages);
    // Fingerprint changed → may decode again for call-like rows that miss
    // meta cache; at minimum cache size stays bounded.
    expect(CallBubbleDedupe.debugNormalizeCacheSize(), lessThanOrEqualTo(8));
  });
}
