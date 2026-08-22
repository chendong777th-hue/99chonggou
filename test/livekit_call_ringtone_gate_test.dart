import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_ringtone.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';

void main() {
  group('shouldPlayRingtone', () {
    test('ringingOut plays only without room', () {
      expect(
        shouldPlayRingtone(
          phase: LiveKitCallPhase.ringingOut,
          hasRoom: false,
        ),
        isTrue,
      );
      expect(
        shouldPlayRingtone(
          phase: LiveKitCallPhase.ringingOut,
          hasRoom: true,
        ),
        isFalse,
      );
    });

    test('ringingIn plays only without room', () {
      expect(
        shouldPlayRingtone(
          phase: LiveKitCallPhase.ringingIn,
          hasRoom: false,
        ),
        isTrue,
      );
      expect(
        shouldPlayRingtone(
          phase: LiveKitCallPhase.ringingIn,
          hasRoom: true,
        ),
        isFalse,
      );
    });

    test('connecting/connected/ended/idle never play', () {
      for (final phase in [
        LiveKitCallPhase.connecting,
        LiveKitCallPhase.connected,
        LiveKitCallPhase.ended,
        LiveKitCallPhase.idle,
      ]) {
        expect(
          shouldPlayRingtone(phase: phase, hasRoom: false),
          isFalse,
          reason: '$phase hasRoom=false',
        );
        expect(
          shouldPlayRingtone(phase: phase, hasRoom: true),
          isFalse,
          reason: '$phase hasRoom=true',
        );
      }
    });
  });
}
