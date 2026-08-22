import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_video_layer.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';

void main() {
  group('shouldShowLiveKitVideoLayer', () {
    test('connected video call shows layer', () {
      expect(
        shouldShowLiveKitVideoLayer(
          isVideo: true,
          phase: LiveKitCallPhase.connected,
          role: AppCallRole.callee,
          hasRoom: true,
        ),
        isTrue,
      );
    });

    test('connecting callee with room shows layer', () {
      expect(
        shouldShowLiveKitVideoLayer(
          isVideo: true,
          phase: LiveKitCallPhase.connecting,
          role: AppCallRole.callee,
          hasRoom: true,
        ),
        isTrue,
      );
    });

    test('ringingOut caller with room shows layer', () {
      expect(
        shouldShowLiveKitVideoLayer(
          isVideo: true,
          phase: LiveKitCallPhase.ringingOut,
          role: AppCallRole.caller,
          hasRoom: true,
        ),
        isTrue,
      );
    });

    test('ringingIn callee hides layer until connect', () {
      expect(
        shouldShowLiveKitVideoLayer(
          isVideo: true,
          phase: LiveKitCallPhase.ringingIn,
          role: AppCallRole.callee,
          hasRoom: false,
        ),
        isFalse,
      );
    });

    test('audio call never shows layer', () {
      expect(
        shouldShowLiveKitVideoLayer(
          isVideo: false,
          phase: LiveKitCallPhase.connected,
          role: AppCallRole.caller,
          hasRoom: true,
        ),
        isFalse,
      );
    });
  });
}
