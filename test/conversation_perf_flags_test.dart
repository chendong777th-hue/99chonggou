import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';

void main() {
  final originalTargetPlatform = debugDefaultTargetPlatformOverride;

  tearDown(() {
    debugDefaultTargetPlatformOverride = originalTargetPlatform;
  });

  test('allows scroll-time virtual hydration on iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(ConversationPerfFlags.virtualHydrateOnlyOnScrollSettle, isFalse);
  });

  test('keeps settle-only virtual hydrate on all Android tiers', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(ConversationPerfFlags.virtualHydrateOnlyOnScrollSettle, isTrue);
  });
}
