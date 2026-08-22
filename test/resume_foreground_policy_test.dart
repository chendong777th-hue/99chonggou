import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/resume_foreground_policy.dart';

void main() {
  group('ResumeForegroundPolicy.intensityFor', () {
    test('null background is full', () {
      expect(
        ResumeForegroundPolicy.intensityFor(null),
        ResumeIntensity.full,
      );
    });

    test('under 15s is light', () {
      expect(
        ResumeForegroundPolicy.intensityFor(const Duration(seconds: 14)),
        ResumeIntensity.light,
      );
    });

    test('15s and above is full', () {
      expect(
        ResumeForegroundPolicy.intensityFor(const Duration(seconds: 15)),
        ResumeIntensity.full,
      );
      expect(
        ResumeForegroundPolicy.intensityFor(const Duration(seconds: 20)),
        ResumeIntensity.full,
      );
    });
  });

  group('ResumeForegroundPolicy phase constants', () {
    test('hold and phase delays match plan', () {
      expect(
        ResumeForegroundPolicy.conversationHoldDuration,
        const Duration(seconds: 3),
      );
      expect(
        ResumeForegroundPolicy.phase1Delay,
        const Duration(milliseconds: 800),
      );
      expect(
        ResumeForegroundPolicy.phase2Delay,
        const Duration(milliseconds: 2000),
      );
    });
  });

  group('ResumeForegroundPolicy side-effect gates', () {
    test('phase0 never runs chat refresh', () {
      expect(
        ResumeForegroundPolicy.shouldRunChatRefreshInPhase0(
          ResumeIntensity.light,
        ),
        isFalse,
      );
      expect(
        ResumeForegroundPolicy.shouldRunChatRefreshInPhase0(
          ResumeIntensity.full,
        ),
        isFalse,
      );
    });

    test('heavy side effects only for full', () {
      expect(
        ResumeForegroundPolicy.shouldRunHeavySideEffects(ResumeIntensity.light),
        isFalse,
      );
      expect(
        ResumeForegroundPolicy.shouldRunHeavySideEffects(ResumeIntensity.full),
        isTrue,
      );
    });
  });

  group('ResumeForegroundPolicy.chatRecoveryRetryDelays', () {
    test('warm chat without preview ahead is single zero delay', () {
      expect(
        ResumeForegroundPolicy.chatRecoveryRetryDelays(
          hasVisibleMessages: true,
          previewAhead: false,
        ),
        const <Duration>[Duration.zero],
      );
    });

    test('cloud catch-up required keeps three delays even when warm', () {
      expect(
        ResumeForegroundPolicy.chatRecoveryRetryDelays(
          hasVisibleMessages: true,
          previewAhead: false,
          cloudCatchUpRequired: true,
        ),
        const <Duration>[
          Duration.zero,
          Duration(milliseconds: 800),
          Duration(milliseconds: 2000),
        ],
      );
    });

    test('empty or preview-ahead uses shortened three delays', () {
      expect(
        ResumeForegroundPolicy.chatRecoveryRetryDelays(
          hasVisibleMessages: false,
          previewAhead: false,
        ),
        const <Duration>[
          Duration.zero,
          Duration(milliseconds: 800),
          Duration(milliseconds: 2000),
        ],
      );
      expect(
        ResumeForegroundPolicy.chatRecoveryRetryDelays(
          hasVisibleMessages: true,
          previewAhead: true,
        ),
        const <Duration>[
          Duration.zero,
          Duration(milliseconds: 800),
          Duration(milliseconds: 2000),
        ],
      );
    });
  });
}
