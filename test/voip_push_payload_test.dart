import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_cloud_chat_demo/src/utils/voip_push_payload.dart';

/// 模拟 iOS AppDelegate + Flutter 层对服务端 payload 的解析结果。
String resolveDisplayNameLikeNative({
  required Map<String, dynamic> data,
  Map<String, String> cachedNames = const {},
}) {
  final callerId =
      VoipPushPayload.normalizeUserId(data['callerId']?.toString());
  if (callerId.isEmpty) {
    return '';
  }
  final fromPush = VoipPushPayload.readCallerName(data);
  if (fromPush.isNotEmpty) {
    return fromPush;
  }
  final cached = cachedNames[callerId]?.trim() ?? '';
  if (cached.isNotEmpty && !cached.contains('#')) {
    return cached;
  }
  return callerId;
}

void main() {
  group('VoipPushPayload', () {
    test('isCallPushType accepts lk_call only for LiveKit cutover', () {
      expect(VoipPushPayload.isCallPushType('lk_call'), isTrue);
      expect(VoipPushPayload.isCallPushType('av_call'), isFalse);
      expect(VoipPushPayload.isCallPushType('rtc_call'), isFalse);
      expect(VoipPushPayload.isLegacyTrtcCallPushType('av_call'), isTrue);
      expect(VoipPushPayload.isCallPushType('chat_message'), isFalse);
    });

    test('normalizeUserId strips TRTC composite id', () {
      expect(
        VoipPushPayload.normalizeUserId('acnj6oxey9#0#0#rqwm8onw3j'),
        'acnj6oxey9',
      );
      expect(
        VoipPushPayload.normalizeUserId('c2c_acnj6oxey9#0#0#rqwm8onw3j'),
        'acnj6oxey9',
      );
      expect(
        CallUserId.normalizeCallUserId('acnj6oxey9#0#0#rqwm8onw3j'),
        'acnj6oxey9',
      );
    });

    test('readCallerName prefers callerName and rejects composite ids', () {
      expect(
        VoipPushPayload.readCallerName(<String, dynamic>{
          'callerName': '张三',
          'callerId': 'acnj6oxey9#0#0#rqwm8onw3j',
        }),
        '张三',
      );
      expect(
        VoipPushPayload.readCallerName(<String, dynamic>{
          'callerName': 'acnj6oxey9#0#0#rqwm8onw3j',
        }),
        '',
      );
    });

    test('shouldEndCall detects cancel/end push types', () {
      expect(
        VoipPushPayload.shouldEndCall(
            <String, dynamic>{'type': 'av_call_cancel'}),
        isTrue,
      );
      expect(
        VoipPushPayload.shouldEndCall(<String, dynamic>{
          'type': 'lk_call',
          'action': 'hangup',
        }),
        isTrue,
      );
      expect(
        VoipPushPayload.shouldEndCall(<String, dynamic>{'type': 'lk_call'}),
        isFalse,
      );
    });

    test('shouldEndCall handles answered_elsewhere and call_end', () {
      expect(
        VoipPushPayload.shouldEndCall(<String, dynamic>{
          'type': 'lk_call',
          'action': 'answered_elsewhere',
        }),
        isTrue,
      );
      expect(
        VoipPushPayload.shouldEndCall(<String, dynamic>{
          'type': 'lk_call',
          'call_end': 1,
        }),
        isTrue,
      );
      expect(
        VoipPushPayload.shouldEndCall(<String, dynamic>{
          'type': 'lk_call',
          'action': 'invite',
        }),
        isFalse,
      );
      expect(
        VoipPushPayload.shouldEndCall(<String, dynamic>{
          'type': 'lk_call',
          'action': 'reject',
        }),
        isTrue,
      );
    });

    test('isCalleeForCurrentUser validates calleeId', () {
      const payload = <String, dynamic>{
        'calleeId': 'user_b',
      };
      expect(
        VoipPushPayload.isCalleeForCurrentUser(payload, 'user_b'),
        isTrue,
      );
      expect(
        VoipPushPayload.isCalleeForCurrentUser(payload, 'user_a'),
        isFalse,
      );
    });

    test('expired cached invite is not presented on next app start', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1786752000000);
      expect(
        VoipPushPayload.isExpiredInvite(
          <String, dynamic>{
            'type': 'lk_call',
            'action': 'invite',
            'timeoutSec': 60,
            '_receivedAtMs':
                now.subtract(const Duration(minutes: 2)).millisecondsSinceEpoch,
          },
          now: now,
        ),
        isTrue,
      );
    });

    test('fresh invite remains presentable within timeout and grace', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1786752000000);
      expect(
        VoipPushPayload.isExpiredInvite(
          <String, dynamic>{
            'action': 'invite',
            'timeoutSec': 60,
            'timestamp': now
                    .subtract(const Duration(seconds: 30))
                    .millisecondsSinceEpoch ~/
                1000,
          },
          now: now,
        ),
        isFalse,
      );
    });

    test('payload without a trustworthy timestamp is not falsely rejected', () {
      expect(
        VoipPushPayload.isExpiredInvite(
          const <String, dynamic>{'action': 'invite', 'timeoutSec': 60},
        ),
        isFalse,
      );
    });

    test('resolveDisplayNameLikeNative prefers push then cache', () {
      expect(
        resolveDisplayNameLikeNative(
          data: <String, dynamic>{
            'callerId': 'u1',
            'callerName': 'Alice',
          },
        ),
        'Alice',
      );
      expect(
        resolveDisplayNameLikeNative(
          data: <String, dynamic>{'callerId': 'u1'},
          cachedNames: const {'u1': 'Cached'},
        ),
        'Cached',
      );
    });
  });
}
