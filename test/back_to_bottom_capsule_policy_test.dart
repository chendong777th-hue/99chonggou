import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/back_to_bottom_capsule_policy.dart';

void main() {
  test('hides when physically at bottom even if logical position is stale', () {
    expect(
      BackToBottomCapsulePolicy.shouldShow(
        physicallyAtBottom: true,
        leftBottomByOneScreen: false,
        missingNewerThanViewport: false,
        presentationBottomLocked: false,
        programmaticScrollToBottom: false,
      ),
      isFalse,
    );
  });

  test('hides slightly-off-bottom without a one-screen leave', () {
    expect(
      BackToBottomCapsulePolicy.isPhysicallyAtBottom(23),
      isTrue,
    );
    expect(
      BackToBottomCapsulePolicy.isPhysicallyAtBottom(25),
      isFalse,
    );
    expect(
      BackToBottomCapsulePolicy.shouldShow(
        physicallyAtBottom: false,
        leftBottomByOneScreen: false,
        missingNewerThanViewport: false,
        presentationBottomLocked: false,
        programmaticScrollToBottom: false,
      ),
      isFalse,
    );
  });

  test('shows after an active one-screen leave', () {
    expect(
      BackToBottomCapsulePolicy.shouldShow(
        physicallyAtBottom: false,
        leftBottomByOneScreen: true,
        missingNewerThanViewport: false,
        presentationBottomLocked: false,
        programmaticScrollToBottom: false,
      ),
      isTrue,
    );
  });

  test('keeps the capsule at the physical bottom when newer data is missing',
      () {
    expect(
      BackToBottomCapsulePolicy.shouldShow(
        physicallyAtBottom: true,
        leftBottomByOneScreen: false,
        missingNewerThanViewport: true,
        presentationBottomLocked: false,
        programmaticScrollToBottom: false,
      ),
      isTrue,
    );
  });

  test('viewport settling at bottom ignores a stale leave latch', () {
    expect(
      BackToBottomCapsulePolicy.shouldShow(
        physicallyAtBottom: true,
        leftBottomByOneScreen: true,
        missingNewerThanViewport: false,
        presentationBottomLocked: false,
        programmaticScrollToBottom: false,
      ),
      isFalse,
    );
  });

  test('locks hide the capsule during inbound pin or return-to-bottom', () {
    expect(
      BackToBottomCapsulePolicy.shouldShow(
        physicallyAtBottom: false,
        leftBottomByOneScreen: true,
        missingNewerThanViewport: false,
        presentationBottomLocked: true,
        programmaticScrollToBottom: false,
      ),
      isFalse,
    );
    expect(
      BackToBottomCapsulePolicy.shouldShow(
        physicallyAtBottom: true,
        leftBottomByOneScreen: false,
        missingNewerThanViewport: true,
        presentationBottomLocked: false,
        programmaticScrollToBottom: true,
      ),
      isFalse,
    );
  });
}
