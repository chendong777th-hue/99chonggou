import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_resolution_utils.dart';

void main() {
  group('imagePreviewMaxScale', () {
    test('allows zoom beyond contain-fit for large images', () {
      final maxScale = imagePreviewMaxScale(
        imageWidth: 4000,
        imageHeight: 3000,
        screenWidth: 390,
        screenHeight: 844,
      );
      expect(maxScale, greaterThan(4.0));
      expect(maxScale, lessThanOrEqualTo(10.0));
    });

    test('100px wide thumbnail can zoom beyond native pixel width', () {
      const screenWidth = 390.0;
      const screenHeight = 844.0;
      final maxScale = imagePreviewMaxScale(
        imageWidth: 100,
        imageHeight: 100,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        fit: BoxFit.contain,
      );
      final initial = imagePreviewInitialDisplaySize(
        imageWidth: 100,
        imageHeight: 100,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        fit: BoxFit.contain,
      );
      expect(initial.width, 100);
      expect(initial.height, 100);
      expect(maxScale, greaterThan(1.0));
      expect(initial.width * maxScale, greaterThan(100));
    });

    test('keeps a reasonable minimum for tiny thumbnails', () {
      final maxScale = imagePreviewMaxScale(
        imageWidth: 120,
        imageHeight: 120,
        screenWidth: 390,
        screenHeight: 844,
      );
      expect(maxScale, greaterThanOrEqualTo(4.0));
    });
  });

  group('imagePreviewDisplayConfig', () {
    test('tall image uses fitWidth top alignment', () {
      const screenWidth = 390.0;
      const screenHeight = 844.0;
      final config = imagePreviewDisplayConfig(
        imageWidth: 1080,
        imageHeight: 2600,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(config.mode, ImagePreviewDisplayMode.tall);
      expect(config.fit, BoxFit.fitWidth);
      expect(config.alignment, Alignment.topCenter);
      expect(config.verticallyScrollable, isTrue);
      final display = imagePreviewInitialDisplaySize(
        imageWidth: 1080,
        imageHeight: 2600,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        fit: config.fit,
      );
      expect(display.width, screenWidth);
      expect(display.height, greaterThan(screenHeight));
    });

    test('extra tall chat screenshot uses fitWidth', () {
      final config = imagePreviewDisplayConfig(
        imageWidth: 1080,
        imageHeight: 8000,
        screenWidth: 390,
        screenHeight: 844,
      );
      expect(config.mode, ImagePreviewDisplayMode.extraTall);
      expect(config.fit, BoxFit.fitWidth);
      expect(config.isExtraTallImage, isTrue);
      expect(config.verticallyScrollable, isTrue);
    });

    test('narrow tall screenshot upscales to fill screen width', () {
      const screenWidth = 390.0;
      const screenHeight = 844.0;
      final config = imagePreviewDisplayConfig(
        imageWidth: 280,
        imageHeight: 2200,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(config.mode, ImagePreviewDisplayMode.extraTall);
      expect(config.fit, BoxFit.fitWidth);
      final display = imagePreviewInitialDisplaySize(
        imageWidth: 280,
        imageHeight: 2200,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        fit: config.fit,
      );
      expect(display.width, screenWidth);
      expect(display.height, closeTo(screenWidth * 2200 / 280, 0.5));
      expect(display.height, greaterThan(screenHeight));
    });

    test('avatar/moments tall images do not upscale to screen width', () {
      const screenWidth = 390.0;
      const screenHeight = 844.0;
      final config = imagePreviewDisplayConfig(
        imageWidth: 280,
        imageHeight: 2200,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        fitTallImagesToScreenWidth: false,
      );
      expect(config.mode, ImagePreviewDisplayMode.extraTall);
      expect(config.fit, BoxFit.scaleDown);
      expect(config.alignment, Alignment.center);
      expect(config.verticallyScrollable, isFalse);
      final display = imagePreviewInitialDisplaySize(
        imageWidth: 280,
        imageHeight: 2200,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        fit: config.fit,
      );
      expect(display.width, lessThan(screenWidth));
      expect(display.height, lessThanOrEqualTo(screenHeight));
    });

    test('uses contain for normal photos', () {
      final config = imagePreviewDisplayConfig(
        imageWidth: 3000,
        imageHeight: 2000,
        screenWidth: 390,
        screenHeight: 844,
      );
      expect(config.mode, ImagePreviewDisplayMode.normal);
      expect(config.fit, BoxFit.scaleDown);
      expect(config.alignment, Alignment.center);
    });

    test('detects wide images', () {
      final config = imagePreviewDisplayConfig(
        imageWidth: 3200,
        imageHeight: 2000,
        screenWidth: 390,
        screenHeight: 844,
      );
      expect(config.mode, ImagePreviewDisplayMode.wide);
      expect(config.isWideImage, isTrue);
    });

    test('detects panorama images', () {
      final config = imagePreviewDisplayConfig(
        imageWidth: 4000,
        imageHeight: 1200,
        screenWidth: 390,
        screenHeight: 844,
      );
      expect(config.mode, ImagePreviewDisplayMode.panorama);
      expect(config.fit, BoxFit.scaleDown);
      expect(config.isPanorama, isTrue);
    });

    test('ultra-wide settlement sheet shows full image without height-crop', () {
      const screenWidth = 390.0;
      const screenHeight = 844.0;
      final config = imagePreviewDisplayConfig(
        imageWidth: 1024,
        imageHeight: 295,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(config.mode, ImagePreviewDisplayMode.panorama);
      expect(config.fit, BoxFit.scaleDown);
      final display = imagePreviewInitialDisplaySize(
        imageWidth: 1024,
        imageHeight: 295,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        fit: config.fit,
      );
      // contain 应铺满屏宽，高度按比例缩放，整张结算表可见。
      expect(display.width, screenWidth);
      expect(display.height, closeTo(screenWidth * 295 / 1024, 0.5));
      expect(display.height, lessThan(screenHeight * 0.5));
    });

    test('detects small images', () {
      final config = imagePreviewDisplayConfig(
        imageWidth: 120,
        imageHeight: 120,
        screenWidth: 390,
        screenHeight: 844,
      );
      expect(config.mode, ImagePreviewDisplayMode.small);
      expect(config.isSmallImage, isTrue);
      expect(config.fit, BoxFit.scaleDown);
      expect(config.gestureProfile.allowPanAt1x, isFalse);
      final display = imagePreviewInitialDisplaySize(
        imageWidth: 120,
        imageHeight: 120,
        screenWidth: 390,
        screenHeight: 844,
        fit: config.fit,
      );
      expect(display, const Size(120, 120));
    });

    test('large photo letterboxes instead of filling the screen', () {
      const screenWidth = 390.0;
      const screenHeight = 844.0;
      final display = imagePreviewInitialDisplaySize(
        imageWidth: 3000,
        imageHeight: 2000,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(display.width, screenWidth);
      expect(display.height, closeTo(screenWidth * 2000 / 3000, 0.5));
      expect(display.height, lessThan(screenHeight));
    });

    test('hero dest rect stops at letterboxed image not the full slide page',
        () {
      const heroBox = Rect.fromLTWH(0, 0, 390, 844);
      final rect = imagePreviewHeroDestRect(
        heroBox: heroBox,
        displaySize: const Size(390, 260),
      );
      expect(rect.width, 390);
      expect(rect.height, 260);
      expect(rect.top, closeTo((844 - 260) / 2, 0.5));
    });

    test('keeps original pixels when decode is upscaled with the same aspect',
        () {
      final pixels = imagePreviewPreferredPixelSize(
        meta: const Size(200, 200),
        decodedWidth: 565,
        decodedHeight: 565,
      );
      expect(pixels, const Size(200, 200));
      final display = imagePreviewDisplayConfig(
        imageWidth: pixels.width.round(),
        imageHeight: pixels.height.round(),
        screenWidth: 390,
        screenHeight: 844,
      );
      final box = imagePreviewBoxSizeFor(
        display: display,
        screenWidth: 390,
        screenHeight: 844,
      );
      expect(box, const Size(200, 200));
    });

    test('uses decoded pixels when EXIF rotation flips the aspect', () {
      final pixels = imagePreviewPreferredPixelSize(
        meta: const Size(1920, 1080),
        decodedWidth: 1080,
        decodedHeight: 1920,
      );
      expect(pixels, const Size(1080, 1920));
    });

    test('display box matches hero dest so enlarge does not jump twice', () {
      const screenWidth = 390.0;
      const screenHeight = 844.0;
      final display = imagePreviewDisplayConfig(
        imageWidth: 3000,
        imageHeight: 2000,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      final box = imagePreviewBoxSizeFor(
        display: display,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      const heroBox = Rect.fromLTWH(0, 0, 390, 844);
      final dest = imagePreviewHeroDestRect(
        heroBox: Rect.fromCenter(
          center: heroBox.center,
          width: box.width,
          height: box.height,
        ),
        displaySize: box,
      );
      expect(dest.size, box);
      expect(box.width, screenWidth);
      expect(box.height, lessThan(screenHeight));
    });

    test('tall and extraTall share normal gesture physics', () {
      final normal = imagePreviewGestureProfileFor(ImagePreviewDisplayMode.normal);
      final tall = imagePreviewGestureProfileFor(ImagePreviewDisplayMode.tall);
      final extraTall =
          imagePreviewGestureProfileFor(ImagePreviewDisplayMode.extraTall);
      expect(tall.panDamping, normal.panDamping);
      expect(tall.inertialSpeed, normal.inertialSpeed);
      expect(tall.inertialDecayPerFrame, normal.inertialDecayPerFrame);
      expect(tall.panAxisPreference, ImagePreviewPanAxisPreference.vertical);
      expect(extraTall.panDamping, normal.panDamping);
      expect(extraTall.inertialSpeed, normal.inertialSpeed);
      expect(
        extraTall.panAxisPreference,
        ImagePreviewPanAxisPreference.vertical,
      );
    });
  });

  group('imagePreviewInitialScale', () {
    test('uses slightly above 1 for vertically scrollable images', () {
      expect(
        imagePreviewInitialScale(verticallyScrollable: true),
        imagePreviewPanEnabledMinScale,
      );
      expect(imagePreviewInitialScale(verticallyScrollable: false), 1.0);
    });
  });

  group('imagePreviewDoubleTapScale', () {
    test('never exceeds max scale', () {
      const screenWidth = 390.0;
      const screenHeight = 844.0;
      final maxScale = imagePreviewMaxScale(
        imageWidth: 4000,
        imageHeight: 3000,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      final doubleTap = imagePreviewDoubleTapScale(
        imageWidth: 4000,
        imageHeight: 3000,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(doubleTap, lessThanOrEqualTo(maxScale));
      expect(doubleTap, greaterThanOrEqualTo(1.0));
    });

    test('normal image double tap around 2.75x', () {
      final doubleTap = imagePreviewDoubleTapScale(
        imageWidth: 3000,
        imageHeight: 2000,
        screenWidth: 390,
        screenHeight: 844,
        display: imagePreviewDisplayConfig(
          imageWidth: 3000,
          imageHeight: 2000,
          screenWidth: 390,
          screenHeight: 844,
        ),
      );
      expect(doubleTap, closeTo(2.75, 0.01));
    });

    test('wide/panorama on portrait phone double-tap fills height for reading', () {
      const screenWidth = 390.0;
      const screenHeight = 844.0;
      // 竖屏 contain 横图时通常已铺满屏宽，双击改为铺高以便横滑细读。
      for (final size in [
        (3200, 2000),
        (1024, 295),
      ]) {
        final display = imagePreviewDisplayConfig(
          imageWidth: size.$1,
          imageHeight: size.$2,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
        );
        final initial = imagePreviewInitialDisplaySize(
          imageWidth: size.$1,
          imageHeight: size.$2,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          fit: display.fit,
        );
        expect(initial.width, screenWidth);
        final doubleTap = imagePreviewDoubleTapScale(
          imageWidth: size.$1,
          imageHeight: size.$2,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          display: display,
        );
        expect(doubleTap, closeTo(screenHeight / initial.height, 0.05));
        expect(doubleTap, greaterThan(2.0));
      }
    });

    test('small images double tap around 3.5x', () {
      final doubleTap = imagePreviewDoubleTapScale(
        imageWidth: 120,
        imageHeight: 120,
        screenWidth: 390,
        screenHeight: 844,
        display: imagePreviewDisplayConfig(
          imageWidth: 120,
          imageHeight: 120,
          screenWidth: 390,
          screenHeight: 844,
        ),
      );
      expect(doubleTap, closeTo(3.5, 0.01));
    });
  });

  group('imagePreviewDecodeTarget', () {
    test('caps decode for images larger than screen', () {
      final target = imagePreviewDecodeTarget(
        screenWidth: 390,
        screenHeight: 844,
        devicePixelRatio: 3,
        imageWidth: 8000,
        imageHeight: 6000,
      );
      expect(target.shouldResize, isTrue);
      expect(target.width, lessThan(8000));
      expect(target.height, lessThan(6000));
      expect(target.staged, isTrue);
    });

    test('marks 2000px+ as staged huge image', () {
      expect(
        imagePreviewIsHugeImage(imageWidth: 2200, imageHeight: 1100),
        isTrue,
      );
      expect(
        imagePreviewIsHugeImage(imageWidth: 1200, imageHeight: 800),
        isFalse,
      );
    });

    test('extra-tall FitWidth keeps width near screen budget, not squashed by screenH',
        () {
      // Chat long screenshot: ~750×12000. Old min(capW/w, capH/h) crushed width.
      const imageW = 750;
      const imageH = 12000;
      const screenW = 390.0;
      const screenH = 844.0;
      const dpr = 3.0;
      final target = imagePreviewDecodeTarget(
        screenWidth: screenW,
        screenHeight: screenH,
        devicePixelRatio: dpr,
        imageWidth: imageW,
        imageHeight: imageH,
      );
      final capW =
          (screenW * dpr * imagePreviewDecodeScreenFactor).round();
      final oldSquashScale = math.min(
        capW / imageW,
        (screenH * dpr * imagePreviewDecodeScreenFactor).round() / imageH,
      );
      final oldW = (imageW * oldSquashScale).round();
      expect(target.shouldResize, isTrue);
      expect(target.width, greaterThan(oldW));
      expect(target.width, lessThanOrEqualTo(capW));
      // Aspect preserved.
      final outAspect = target.height! / target.width!;
      expect(outAspect, closeTo(imageH / imageW, 0.02));
    });

    test('extra-tall under width cap does not resize by screen height alone', () {
      final target = imagePreviewDecodeTarget(
        screenWidth: 390,
        screenHeight: 844,
        devicePixelRatio: 3,
        imageWidth: 1080,
        imageHeight: 8000,
      );
      // 1080 < capW (~1696), so width need not shrink; height follows ratio.
      expect(target.shouldResize, isFalse);
    });
  });

  group('imagePreviewMetaSizeFromMessage', () {
    V2TimMessage imageMessage(List<V2TimImage?> imageList) {
      final message = V2TimMessage.fromJson({
        'msgID': 'msg-wide',
        'timestamp': 1,
        'message_is_from_self': false,
        'message_risk_type_identified': 0,
      });
      message.elemType = MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
      message.imageElem = V2TimImageElem(imageList: imageList);
      return message;
    }

    test('prefers original size over larger-area square thumb', () {
      final size = imagePreviewMetaSizeFromMessage(
        imageMessage([
          // THUMB=1 may falsely report a square crop larger than some fields.
          V2TimImage(type: 1, width: 2000, height: 2000, url: 't'),
          V2TimImage(type: 0, width: 3200, height: 1800, url: 'o'),
        ]),
      );
      expect(size, const Size(3200, 1800));
    });

    test('falls back to large then largest area when original missing', () {
      expect(
        imagePreviewMetaSizeFromMessage(
          imageMessage([
            V2TimImage(type: 1, width: 200, height: 200, url: 't'),
            V2TimImage(type: 2, width: 1600, height: 900, url: 'l'),
          ]),
        ),
        const Size(1600, 900),
      );
      expect(
        imagePreviewMetaSizeFromMessage(
          imageMessage([
            V2TimImage(type: 1, width: 1080, height: 1080, url: 't'),
          ]),
        ),
        const Size(1080, 1080),
      );
    });
  });

  group('ImagePreviewDisplayConfig.layoutEquals', () {
    test('detects fit/alignment mismatch for rebuild', () {
      final tall = imagePreviewDisplayConfig(
        imageWidth: 1080,
        imageHeight: 2600,
        screenWidth: 390,
        screenHeight: 844,
      );
      final wide = imagePreviewDisplayConfig(
        imageWidth: 3200,
        imageHeight: 1800,
        screenWidth: 390,
        screenHeight: 844,
      );
      expect(tall.layoutEquals(tall), isTrue);
      expect(tall.layoutEquals(wide), isFalse);
      expect(
        imagePreviewWidgetLayoutMatchesDisplay(
          widgetFit: tall.fit,
          widgetAlignment: tall.alignment,
          display: tall,
        ),
        isTrue,
      );
      expect(
        imagePreviewWidgetLayoutMatchesDisplay(
          widgetFit: tall.fit,
          widgetAlignment: tall.alignment,
          display: wide,
        ),
        isFalse,
      );
    });
  });

  group('imagePreviewPaintFit', () {
    test('avatar/moments never use fill for ordinary images', () {
      final small = imagePreviewDisplayConfig(
        imageWidth: 120,
        imageHeight: 120,
        screenWidth: 390,
        screenHeight: 844,
        fitTallImagesToScreenWidth: false,
      );
      expect(small.verticallyScrollable, isFalse);
      expect(
        imagePreviewPaintFit(
          small,
          fitTallImagesToScreenWidth: false,
        ),
        BoxFit.scaleDown,
      );

      final photo = imagePreviewDisplayConfig(
        imageWidth: 3000,
        imageHeight: 2000,
        screenWidth: 390,
        screenHeight: 844,
        fitTallImagesToScreenWidth: false,
      );
      expect(
        imagePreviewPaintFit(
          photo,
          fitTallImagesToScreenWidth: false,
        ),
        BoxFit.scaleDown,
      );
    });

    test('chat ordinary photos still fill the letterboxed gesture box', () {
      final photo = imagePreviewDisplayConfig(
        imageWidth: 3000,
        imageHeight: 2000,
        screenWidth: 390,
        screenHeight: 844,
      );
      expect(photo.verticallyScrollable, isFalse);
      expect(imagePreviewPaintFit(photo), BoxFit.fill);
    });

    test('unknown size uses contain instead of fill', () {
      final unknown = imagePreviewDisplayConfig(
        imageWidth: 0,
        imageHeight: 0,
        screenWidth: 390,
        screenHeight: 844,
      );
      expect(unknown.imageWidth, 0);
      expect(
        imagePreviewPaintFit(unknown),
        BoxFit.contain,
      );
      expect(
        imagePreviewPaintFit(
          unknown,
          fitTallImagesToScreenWidth: false,
        ),
        BoxFit.contain,
      );
    });
  });
}
