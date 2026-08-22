import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_chat_bubble_size.dart';

void main() {
  group('resolveStickerChatBubbleSize', () {
    test('scales intrinsic size by display scale when within cap', () {
      final size = resolveStickerChatBubbleSize(
        screenWidth: 390,
        maxWidthFactor: 0.4,
        intrinsicWidth: 240,
        intrinsicHeight: 180,
      );
      expect(size.width, closeTo(240 * kStickerChatBubbleDisplayScale, 0.1));
      expect(size.height, closeTo(180 * kStickerChatBubbleDisplayScale, 0.1));
    });

    test('scales down proportionally when exceeding max', () {
      final size = resolveStickerChatBubbleSize(
        screenWidth: 390,
        maxWidthFactor: 0.4,
        intrinsicWidth: 800,
        intrinsicHeight: 400,
      );
      // maxW = 0.55 * 390 = 214.5
      expect(size.width, closeTo(214.5, 0.1));
      expect(size.height, closeTo(107.25, 0.1));
    });

    test('falls back to square when intrinsic missing', () {
      final size = resolveStickerChatBubbleSize(
        screenWidth: 390,
        maxWidthFactor: 0.4,
      );
      expect(size.width, size.height);
      // 390 * 0.4 * 0.85 = 132.6
      expect(size.width, closeTo(132.6, 0.1));
    });
  });
}
