import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_feed_ui.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android pin anim duration is zero', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(conversationListRowPinAnimDuration(), Duration.zero);
    expect(
      conversationListRowPinAnimDuration(platform: TargetPlatform.android),
      Duration.zero,
    );
  });

  test('iOS pin anim duration is 80ms', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      conversationListRowPinAnimDuration(),
      const Duration(milliseconds: 80),
    );
    expect(
      conversationListRowPinAnimDuration(platform: TargetPlatform.iOS),
      const Duration(milliseconds: 80),
    );
  });
}
