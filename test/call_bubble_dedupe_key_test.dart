import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_bubble_dedupe_key.dart';

void main() {
  group('CallBubbleDedupeKey.c2cHangup', () {
    test('uses conversation and duration without minute bucket', () {
      expect(
        CallBubbleDedupeKey.c2cHangup(
          conversationId: 'c2c_peer123',
          durationSec: 22,
        ),
        'call-hangup:c2c_peer123:22',
      );
    });

    test('includes roomId when present', () {
      expect(
        CallBubbleDedupeKey.c2cHangup(
          conversationId: 'c2c_peer123',
          durationSec: 24,
          roomId: '9988',
        ),
        'call-hangup:c2c_peer123:9988:24',
      );
    });

    test('returns empty for invalid input', () {
      expect(
        CallBubbleDedupeKey.c2cHangup(
          conversationId: '',
          durationSec: 22,
        ),
        '',
      );
      expect(
        CallBubbleDedupeKey.c2cHangup(
          conversationId: 'c2c_peer123',
          durationSec: 0,
        ),
        '',
      );
    });
  });
}
