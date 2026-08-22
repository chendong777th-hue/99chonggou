import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_kit_policy.dart';

void main() {
  test('callee must not start outgoing CallKit after media connected', () {
    expect(calleeMayStartOutgoingCallKitOnConnected(), isFalse);
  });

  group('iosCallKitAudioWaitDecision', () {
    test('App-in / caller — skip even if leftover latch is false', () {
      expect(
        iosCallKitAudioWaitDecision(
          callKitAnswerInFlight: false,
          activatedLatch: false,
        ),
        IosCallKitAudioWaitDecision.skip,
      );
    });

    test('App-in / caller — leftover latch must not apply', () {
      expect(
        iosCallKitAudioWaitDecision(
          callKitAnswerInFlight: false,
          activatedLatch: true,
        ),
        IosCallKitAudioWaitDecision.skip,
      );
    });

    test('CallKit answer + latch — alreadyReady', () {
      expect(
        iosCallKitAudioWaitDecision(
          callKitAnswerInFlight: true,
          activatedLatch: true,
        ),
        IosCallKitAudioWaitDecision.alreadyReady,
      );
    });

    test('CallKit answer without latch — waitPending', () {
      expect(
        iosCallKitAudioWaitDecision(
          callKitAnswerInFlight: true,
          activatedLatch: false,
        ),
        IosCallKitAudioWaitDecision.waitPending,
      );
    });
  });

  group('iosCallKitAllowMicPublish', () {
    test('non-CallKit path may publish without latch', () {
      expect(
        iosCallKitAllowMicPublish(
          isIosCalleeCallKitAnswer: false,
          activatedLatch: false,
        ),
        isTrue,
      );
    });

    test('CallKit callee + latch — allow', () {
      expect(
        iosCallKitAllowMicPublish(
          isIosCalleeCallKitAnswer: true,
          activatedLatch: true,
        ),
        isTrue,
      );
    });

    test('CallKit callee without latch — deny', () {
      expect(
        iosCallKitAllowMicPublish(
          isIosCalleeCallKitAnswer: true,
          activatedLatch: false,
        ),
        isFalse,
      );
    });
  });

  group('iosCallKitShouldApplyLiveKitSpeakerRoute', () {
    test('after dismiss / App-in / caller — apply', () {
      expect(
        iosCallKitShouldApplyLiveKitSpeakerRoute(
          callKitOwnsAudioSession: false,
        ),
        isTrue,
      );
    });

    test('CallKit system answer still owns session — skip', () {
      expect(
        iosCallKitShouldApplyLiveKitSpeakerRoute(
          callKitOwnsAudioSession: true,
        ),
        isFalse,
      );
    });
  });
}
