import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/platform/web_im_catch_up_policy.dart';

void main() {
  final now = DateTime(2026, 8, 17, 8, 30);

  test('first catch-up is never throttled', () {
    expect(
      WebImCatchUpPolicy.isThrottled(now: now, lastCatchUpAt: null),
      isFalse,
    );
    expect(
      WebImCatchUpPolicy.shouldSkipFullCatchUp(
        now: now,
        lastCatchUpAt: null,
        openConversationEmpty: false,
      ),
      isFalse,
    );
  });

  test('throttled full catch-up is skipped when the open chat already has messages', () {
    expect(
      WebImCatchUpPolicy.shouldSkipFullCatchUp(
        now: now,
        lastCatchUpAt: now.subtract(const Duration(seconds: 1)),
        openConversationEmpty: false,
      ),
      isTrue,
    );
  });

  test('throttled empty open chat still allows a session-level catch-up', () {
    expect(
      WebImCatchUpPolicy.shouldSkipFullCatchUp(
        now: now,
        lastCatchUpAt: now.subtract(const Duration(seconds: 1)),
        openConversationEmpty: true,
      ),
      isFalse,
    );
    expect(
      WebImCatchUpPolicy.shouldSessionCatchUpWhileThrottled(
        throttled: true,
        openConversationEmpty: true,
      ),
      isTrue,
    );
    expect(
      WebImCatchUpPolicy.shouldSessionCatchUpWhileThrottled(
        throttled: true,
        openConversationEmpty: false,
      ),
      isFalse,
    );
  });

  test('after minInterval a full catch-up is allowed again', () {
    expect(
      WebImCatchUpPolicy.shouldSkipFullCatchUp(
        now: now,
        lastCatchUpAt: now.subtract(const Duration(seconds: 3)),
        openConversationEmpty: false,
      ),
      isFalse,
    );
  });
}
