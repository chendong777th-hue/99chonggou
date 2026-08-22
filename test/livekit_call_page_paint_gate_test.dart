import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_page_paint_gate.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';

LiveKitCallPagePaintSnapshot _snap({
  LiveKitCallPhase phase = LiveKitCallPhase.connected,
  AppCallRole role = AppCallRole.caller,
  bool isVideo = true,
  bool hasRoom = true,
  bool showVideoLayer = true,
  String localTrackId = 'l1',
  String remoteTrackId = 'r1',
  bool micEnabled = true,
  bool camEnabled = true,
  bool speakerOn = true,
  String peerUserId = 'peer',
}) {
  return LiveKitCallPagePaintSnapshot(
    phase: phase,
    role: role,
    isVideo: isVideo,
    hasRoom: hasRoom,
    showVideoLayer: showVideoLayer,
    localTrackId: localTrackId,
    remoteTrackId: remoteTrackId,
    micEnabled: micEnabled,
    camEnabled: camEnabled,
    speakerOn: speakerOn,
    peerUserId: peerUserId,
  );
}

void main() {
  group('LiveKitCallPagePaintSnapshot.shouldRebuild', () {
    test('identical snapshots → false', () {
      final a = _snap();
      final b = _snap();
      expect(
        LiveKitCallPagePaintSnapshot.shouldRebuild(previous: a, next: b),
        isFalse,
      );
    });

    test('null previous → true', () {
      expect(
        LiveKitCallPagePaintSnapshot.shouldRebuild(
          previous: null,
          next: _snap(),
        ),
        isTrue,
      );
    });

    test('phase change → true', () {
      expect(
        LiveKitCallPagePaintSnapshot.shouldRebuild(
          previous: _snap(phase: LiveKitCallPhase.connecting),
          next: _snap(phase: LiveKitCallPhase.connected),
        ),
        isTrue,
      );
    });

    test('track id null→non-null → true', () {
      expect(
        LiveKitCallPagePaintSnapshot.shouldRebuild(
          previous: _snap(localTrackId: ''),
          next: _snap(localTrackId: 'sid'),
        ),
        isTrue,
      );
    });

    test('mic toggle → true', () {
      expect(
        LiveKitCallPagePaintSnapshot.shouldRebuild(
          previous: _snap(micEnabled: true),
          next: _snap(micEnabled: false),
        ),
        isTrue,
      );
    });
  });

  group('liveKitCallHeavyBgDelay', () {
    const enter = Duration(milliseconds: 180);

    test('audio-only = enter + 250ms', () {
      expect(
        liveKitCallHeavyBgDelay(isVideo: false, enterTransition: enter),
        const Duration(milliseconds: 430),
      );
    });

    test('video = enter + 250ms + 200ms', () {
      expect(
        liveKitCallHeavyBgDelay(isVideo: true, enterTransition: enter),
        const Duration(milliseconds: 630),
      );
    });
  });

  group('liveKitCallHeavyBgMemCachePx', () {
    test('clamps half shortest side into 360..720', () {
      expect(liveKitCallHeavyBgMemCachePx(2000), 720);
      expect(liveKitCallHeavyBgMemCachePx(800), 400);
      expect(liveKitCallHeavyBgMemCachePx(400), 360);
      expect(liveKitCallHeavyBgMemCachePx(0), 720);
    });
  });
}
