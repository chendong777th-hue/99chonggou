import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/call_message_visual.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';

void main() {
  group('CallMessageVisual.outcomeFor', () {
    test('hangup is answered', () {
      expect(
        CallMessageVisual.outcomeFor(
          protocolType: CallProtocolType.hangup,
          participantRole: CallParticipantRole.caller,
        ),
        CallMessageOutcome.answered,
      );
    });

    test('reject is rejected', () {
      expect(
        CallMessageVisual.outcomeFor(
          protocolType: CallProtocolType.reject,
          participantRole: CallParticipantRole.callee,
        ),
        CallMessageOutcome.rejected,
      );
    });

    test('timeout caller is noAnswer', () {
      expect(
        CallMessageVisual.outcomeFor(
          protocolType: CallProtocolType.timeout,
          participantRole: CallParticipantRole.caller,
        ),
        CallMessageOutcome.noAnswer,
      );
    });

    test('timeout callee is missed', () {
      expect(
        CallMessageVisual.outcomeFor(
          protocolType: CallProtocolType.timeout,
          participantRole: CallParticipantRole.callee,
        ),
        CallMessageOutcome.missed,
      );
    });
  });

  group('CallMessageVisual.iconAsset', () {
    test('video outgoing uses self asset', () {
      expect(
        CallMessageVisual.iconAsset(
          mediaType: CallStreamMediaType.video,
          isOutgoing: true,
        ),
        'assets/calling_message/video_call_self.png',
      );
    });

    test('audio uses voice asset', () {
      expect(
        CallMessageVisual.iconAsset(
          mediaType: CallStreamMediaType.audio,
          isOutgoing: false,
        ),
        'assets/calling_message/voice_call.png',
      );
    });
  });

  group('CallMessageVisual.isNegativeOutcome', () {
    test('missed and rejected are negative', () {
      expect(CallMessageVisual.isNegativeOutcome(CallMessageOutcome.missed), isTrue);
      expect(CallMessageVisual.isNegativeOutcome(CallMessageOutcome.rejected), isTrue);
      expect(CallMessageVisual.isNegativeOutcome(CallMessageOutcome.cancelled), isTrue);
      expect(CallMessageVisual.isNegativeOutcome(CallMessageOutcome.answered), isFalse);
    });
  });
}
