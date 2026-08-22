import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/chat_history_recovery_satisfaction.dart';

void main() {
  group('isRecoveryAlreadySatisfied', () {
    test('returns true when messages exist, preview aligned, no change', () {
      expect(
        isRecoveryAlreadySatisfied(
          changed: false,
          hasMessages: true,
          previewAhead: false,
        ),
        isTrue,
      );
    });

    test('returns false when history changed', () {
      expect(
        isRecoveryAlreadySatisfied(
          changed: true,
          hasMessages: true,
          previewAhead: false,
        ),
        isFalse,
      );
    });

    test('returns false when no messages', () {
      expect(
        isRecoveryAlreadySatisfied(
          changed: false,
          hasMessages: false,
          previewAhead: false,
        ),
        isFalse,
      );
    });

    test('returns false when preview is ahead', () {
      expect(
        isRecoveryAlreadySatisfied(
          changed: false,
          hasMessages: true,
          previewAhead: true,
        ),
        isFalse,
      );
    });

    test('returns false when deferred incoming remains after background', () {
      expect(
        isRecoveryAlreadySatisfied(
          changed: false,
          hasMessages: true,
          previewAhead: false,
          hasDeferredIncoming: true,
        ),
        isFalse,
      );
    });

    test('returns false when cloud catch-up required but not attempted', () {
      expect(
        isRecoveryAlreadySatisfied(
          changed: false,
          hasMessages: true,
          previewAhead: false,
          cloudCatchUpRequired: true,
          cloudCatchUpAttempted: false,
        ),
        isFalse,
      );
    });

    test('returns true when cloud catch-up required and attempted with no change',
        () {
      expect(
        isRecoveryAlreadySatisfied(
          changed: false,
          hasMessages: true,
          previewAhead: false,
          cloudCatchUpRequired: true,
          cloudCatchUpAttempted: true,
        ),
        isTrue,
      );
    });
  });
}
