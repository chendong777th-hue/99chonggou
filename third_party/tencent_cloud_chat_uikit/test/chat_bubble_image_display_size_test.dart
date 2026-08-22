import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';

void main() {
  group('resolveChatBubbleImageLayoutLimits', () {
    test('uses compact limits on narrow or short phones', () {
      final narrow = resolveChatBubbleImageLayoutLimits(
        screenWidth: 359,
        screenHeight: 844,
        isDesktop: false,
      );
      final short = resolveChatBubbleImageLayoutLimits(
        screenWidth: 390,
        screenHeight: 699,
        isDesktop: false,
      );

      expect(narrow.maxWidth, 132);
      expect(narrow.maxHeight, 150);
      expect(short.maxWidth, 132);
      expect(short.maxHeight, 150);
    });

    test('uses standard and tall phone limits by screen height', () {
      final standard = resolveChatBubbleImageLayoutLimits(
        screenWidth: 390,
        screenHeight: 800,
        isDesktop: false,
      );
      final tall = resolveChatBubbleImageLayoutLimits(
        screenWidth: 390,
        screenHeight: 844,
        isDesktop: false,
      );

      expect(standard.maxWidth, 144);
      expect(standard.maxHeight, 160);
      expect(tall.maxWidth, 156);
      expect(tall.maxHeight, 176);
    });

    test('keeps existing desktop limits on tablets and desktops', () {
      final tablet = resolveChatBubbleImageLayoutLimits(
        screenWidth: 600,
        screenHeight: 900,
        isDesktop: false,
      );
      final desktop = resolveChatBubbleImageLayoutLimits(
        screenWidth: 390,
        screenHeight: 844,
        isDesktop: true,
      );

      expect(tablet.maxWidth, kChatBubbleImageMaxWidthDesktop);
      expect(tablet.maxHeight, kChatBubbleImageMaxHeight);
      expect(desktop.maxWidth, kChatBubbleImageMaxWidthDesktop);
      expect(desktop.maxHeight, kChatBubbleImageMaxHeight);
    });
  });

  group('resolveChatBubbleImageDisplaySize', () {
    test('keeps landscape aspect after width cap', () {
      final size = resolveChatBubbleImageDisplaySize(
        maxWidth: 180,
        maxHeight: kChatBubbleImageMaxHeight,
        sourceWidth: 1200,
        sourceHeight: 800,
      );
      expect(size.width, closeTo(180, 0.01));
      expect(size.height, closeTo(120, 0.01));
      expect(size.width / size.height, closeTo(1200 / 800, 0.001));
    });

    test('images taller than 3x width use crop box', () {
      final size = resolveChatBubbleImageDisplaySize(
        maxWidth: 180,
        maxHeight: kChatBubbleImageMaxHeight,
        sourceWidth: 720,
        sourceHeight: 6400,
      );
      expect(size.width, kChatBubbleLongImageCropBoxWidth);
      expect(size.height, kChatBubbleLongImageCropBoxHeight);
    });

    test('ranking tables around 1024px tall use crop box not full width', () {
      final size = resolveChatBubbleImageDisplaySize(
        maxWidth: 240,
        maxHeight: kChatBubbleImageMaxHeight,
        sourceWidth: 255,
        sourceHeight: 1024,
      );
      expect(size.width, kChatBubbleLongImageCropBoxWidth);
      expect(size.height, kChatBubbleLongImageCropBoxHeight);
      expect(size.width, lessThan(240));
    });

    test('settlement tables around 383x1024 use crop box not contain strip',
        () {
      final size = resolveChatBubbleImageDisplaySize(
        maxWidth: 240,
        maxHeight: kChatBubbleImageMaxHeight,
        sourceWidth: 383,
        sourceHeight: 1024,
      );
      expect(size.width, kChatBubbleLongImageCropBoxWidth);
      expect(size.height, kChatBubbleLongImageCropBoxHeight);
    });

    test('height-capped skinny strips use crop box even under 3:1', () {
      final size = resolveChatBubbleImageDisplaySize(
        maxWidth: 220,
        maxHeight: kChatBubbleImageMaxHeight,
        sourceWidth: 900,
        sourceHeight: 2400,
      );
      expect(size.width, kChatBubbleLongImageCropBoxWidth);
      expect(size.height, kChatBubbleLongImageCropBoxHeight);
    });

    test('2:1 screenshots are not cropped', () {
      final size = resolveChatBubbleImageDisplaySize(
        maxWidth: 220,
        maxHeight: kChatBubbleImageMaxHeight,
        sourceWidth: 720,
        sourceHeight: 1600,
      );
      expect(size.height, closeTo(kChatBubbleImageMaxHeight, 0.01));
      expect(size.width / size.height, closeTo(720 / 1600, 0.001));
    });

    test('wide panoramas are not cropped', () {
      final size = resolveChatBubbleImageDisplaySize(
        maxWidth: 220,
        maxHeight: kChatBubbleImageMaxHeight,
        sourceWidth: 4000,
        sourceHeight: 900,
      );
      expect(size.width, 220);
      expect(size.width / size.height, closeTo(4000 / 900, 0.001));
    });

    test('keeps ordinary portrait photos proportional', () {
      final size = resolveChatBubbleImageDisplaySize(
        maxWidth: 220,
        maxHeight: kChatBubbleImageMaxHeight,
        sourceWidth: 900,
        sourceHeight: 1200,
      );
      expect(size.width, closeTo(172.5, 0.01));
      expect(size.height, closeTo(kChatBubbleImageMaxHeight, 0.01));
      expect(size.width / size.height, closeTo(900 / 1200, 0.001));
    });

    test('crop display flag follows crop box not source ratio', () {
      expect(
        isChatBubbleLongImageCropDisplay(
          const Size(
            kChatBubbleLongImageCropBoxWidth,
            kChatBubbleLongImageCropBoxHeight,
          ),
          maxWidth: 240,
          maxHeight: kChatBubbleImageMaxHeight,
        ),
        isTrue,
      );
      expect(
        isChatBubbleLongImageCropDisplay(
          const Size(80, 230),
          maxWidth: 240,
          maxHeight: kChatBubbleImageMaxHeight,
        ),
        isFalse,
      );
    });

    test('keeps compact phone images and crop boxes within limits', () {
      const maxWidth = 132.0;
      const maxHeight = 150.0;
      final portrait = resolveChatBubbleImageDisplaySize(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        sourceWidth: 900,
        sourceHeight: 1200,
      );
      final tall = resolveChatBubbleImageDisplaySize(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        sourceWidth: 720,
        sourceHeight: 6400,
      );

      expect(portrait.width, closeTo(112.5, 0.01));
      expect(portrait.height, maxHeight);
      expect(tall.width, kChatBubbleLongImageCropBoxWidth);
      expect(tall.height, maxHeight);
    });
  });

  group('resolveChatBubbleImageDecodeSide', () {
    test('scales by dpr and clamps to bubble decode max', () {
      expect(resolveChatBubbleImageDecodeSide(200, 3), 600);
      expect(
        resolveChatBubbleImageDecodeSide(800, 3),
        kChatBubbleImageDecodeMaxPx,
      );
    });
  });

  group('resolveChatBubbleImageDecodeSideForChatList', () {
    test('caps to scroll-defer max when deferring heavy decode', () {
      expect(
        resolveChatBubbleImageDecodeSideForChatList(300, 3,
            deferHeavyDecode: true),
        kChatBubbleImageDecodeScrollDeferMaxPx,
      );
      expect(
        resolveChatBubbleImageDecodeSideForChatList(80, 2,
            deferHeavyDecode: true),
        160,
      );
    });

    test('keeps normal bubble decode max when not deferring', () {
      expect(
        resolveChatBubbleImageDecodeSideForChatList(200, 3,
            deferHeavyDecode: false),
        600,
      );
    });
  });

  group('resolveChatBubbleImageDecodeTarget', () {
    test('does not stretch decode to both bubble axes', () {
      final landscape = resolveChatBubbleImageDecodeTarget(
        displayWidth: 180,
        displayHeight: 120,
        devicePixelRatio: 3,
        deferHeavyDecode: false,
      );
      expect(landscape.width, 540);
      expect(landscape.height, isNull);

      final portrait = resolveChatBubbleImageDecodeTarget(
        displayWidth: 126,
        displayHeight: 230,
        devicePixelRatio: 3,
        deferHeavyDecode: false,
      );
      expect(portrait.width, isNull);
      expect(portrait.height, 690);
    });

    test('tall cover crop decodes by width so only the top stays sharp', () {
      final target = resolveChatBubbleImageDecodeTarget(
        displayWidth: kChatBubbleLongImageCropBoxWidth,
        displayHeight: kChatBubbleLongImageCropBoxHeight,
        devicePixelRatio: 3,
        deferHeavyDecode: false,
        coverCropTallImage: true,
      );
      expect(target.width, 276);
      expect(target.height, isNull);
    });

    test('open/scroll defer clamps long edge to scroll budget', () {
      final deferred = resolveChatBubbleImageDecodeTarget(
        displayWidth: 180,
        displayHeight: 120,
        devicePixelRatio: 3,
        deferHeavyDecode: true,
      );
      expect(deferred.width, lessThanOrEqualTo(kChatBubbleImageDecodeScrollDeferMaxPx));
      expect(deferred.height, isNull);
    });
  });

  group('kChatBubbleImageSdkTypePriority', () {
    test('lists THUMB before LARGE and ORIGINAL', () {
      expect(kChatBubbleImageSdkTypePriority, <int>[1, 2, 0]);
      expect(isChatBubbleSdkThumbType(1), isTrue);
      expect(isChatBubbleSdkThumbType(2), isFalse);
    });
  });
}
