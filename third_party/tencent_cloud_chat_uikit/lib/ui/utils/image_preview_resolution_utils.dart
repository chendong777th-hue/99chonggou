import 'dart:math' as math;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// extended_image 在 [totalScale] <= 1.0 时忽略平移 offset；长图需略高于 1 才能纵向滑动。
const double imagePreviewPanEnabledMinScale = 1.001;

/// 1x 预览拖动与手指 1:1（未放大）。
const double imagePreviewPanSpeed = 1.0;

/// 双指可暂时缩到此比例（欠缩橡胶带），松手后弹回 fit（1x）。
/// 微信手感：允许缩到 0.55x，松手平稳回弹，无 overshoot/bounce。
const double imagePreviewAnimationMinScale = 0.55;

/// 欠缩 / 超限回弹动画时长。微信风格：稳快顺，100ms 内贴回，无过冲。
const Duration imagePreviewScaleSnapDuration = Duration(milliseconds: 100);

/// 欠缩 / 超限回弹曲线：平稳缓出（微信手感），无过冲/弹簧感。
const Curve imagePreviewScaleSnapCurve = Curves.easeOut;

/// 长图进入预览时的初始缩放（视觉上等同 1x，但允许平移）。
double imagePreviewInitialScale({required bool verticallyScrollable}) {
  return verticallyScrollable ? imagePreviewPanEnabledMinScale : 1.0;
}

/// 预览图片展示类型。
enum ImagePreviewDisplayMode {
  /// 普通图：接近屏幕比例。
  normal,
  /// 长图：高度 ≥ 宽度×2.2，顶部开始显示。
  tall,
  /// 超长图（聊天截图等）：FitWidth。
  extraTall,
  /// 横图（含超宽全景）：宽度 ≥ 高度×1.6。
  /// 先 contain 完整入画；双击再按高度铺满细读，手势偏横向。
  wide,
  /// 小图：屏上占比很小。
  small,
}

/// 长图：高宽比下限（height ≥ width × 2.2）。
const double imagePreviewTallAspectRatio = 2.2;

/// 超长图：高宽比下限（聊天长截图，FitWidth）。
const double imagePreviewExtraTallAspectRatio = 3.5;

/// 横图：宽高比下限（width ≥ height × 1.6）。
const double imagePreviewWideAspectRatio = 1.6;

/// 小图判定：contain 后屏上面积占比上限。
const double imagePreviewSmallDisplayCoverage = 0.42;

/// 小图判定：原图较短边相对屏幕较短边比例。
const double imagePreviewSmallNativeShortSideFactor = 0.38;

/// 超大图较长边像素阈值（分阶段解码）。
const int imagePreviewHugeLongestSidePx = 2000;

/// 预览解码相对屏幕的放大系数（留出缩放余量；1.45 较 1.3 更清晰，内存增幅有限）。
const double imagePreviewDecodeScreenFactor = 1.45;

/// 平移主轴偏好。
enum ImagePreviewPanAxisPreference {
  free,
  vertical,
  horizontal,
}

/// 各图片类型的手势物理配置。
class ImagePreviewGestureProfile {
  const ImagePreviewGestureProfile({
    required this.panDamping,
    required this.inertialMinVelocity,
    required this.inertialDecayPerFrame,
    required this.panAxisPreference,
    required this.allowPanAt1x,
    required this.inertialSpeed,
  });

  final double panDamping;
  final double inertialMinVelocity;
  final double inertialDecayPerFrame;
  final ImagePreviewPanAxisPreference panAxisPreference;
  final bool allowPanAt1x;
  final double inertialSpeed;
}

ImagePreviewGestureProfile imagePreviewGestureProfileFor(
  ImagePreviewDisplayMode mode,
) {
  switch (mode) {
    case ImagePreviewDisplayMode.normal:
      return const ImagePreviewGestureProfile(
        panDamping: 0.80,
        inertialMinVelocity: 300,
        inertialDecayPerFrame: 0.95,
        panAxisPreference: ImagePreviewPanAxisPreference.free,
        allowPanAt1x: true,
        inertialSpeed: 400,
      );
    case ImagePreviewDisplayMode.tall:
    case ImagePreviewDisplayMode.extraTall:
      // 与普通图同款阻尼/惯性，轴向仍偏竖向以便长图浏览与翻页分流。
      return const ImagePreviewGestureProfile(
        panDamping: 0.80,
        inertialMinVelocity: 300,
        inertialDecayPerFrame: 0.95,
        panAxisPreference: ImagePreviewPanAxisPreference.vertical,
        allowPanAt1x: true,
        inertialSpeed: 400,
      );
    case ImagePreviewDisplayMode.wide:
      return const ImagePreviewGestureProfile(
        panDamping: 0.78,
        inertialMinVelocity: 300,
        inertialDecayPerFrame: 0.93,
        panAxisPreference: ImagePreviewPanAxisPreference.horizontal,
        allowPanAt1x: true,
        inertialSpeed: 320,
      );
    case ImagePreviewDisplayMode.small:
      return const ImagePreviewGestureProfile(
        panDamping: 0.80,
        inertialMinVelocity: 300,
        inertialDecayPerFrame: 0.95,
        panAxisPreference: ImagePreviewPanAxisPreference.free,
        allowPanAt1x: false,
        inertialSpeed: 400,
      );
  }
}

/// 预览展示策略：按 [mode] 选择 fit/对齐/是否可纵滑。
class ImagePreviewDisplayConfig {
  const ImagePreviewDisplayConfig({
    required this.mode,
    required this.fit,
    required this.alignment,
    required this.initialAlignment,
    required this.verticallyScrollable,
    required this.isTallImage,
    this.isWideImage = false,
    this.isSmallImage = false,
    this.isExtraTallImage = false,
    this.imageWidth = 0,
    this.imageHeight = 0,
  });

  final ImagePreviewDisplayMode mode;
  final BoxFit fit;
  final Alignment alignment;
  final InitialAlignment initialAlignment;
  final bool verticallyScrollable;
  final bool isTallImage;
  final bool isWideImage;
  final bool isSmallImage;
  final bool isExtraTallImage;
  final int imageWidth;
  final int imageHeight;

  ImagePreviewGestureProfile get gestureProfile =>
      imagePreviewGestureProfileFor(mode);

  /// 布局相关字段是否一致（用于判断是否需要重建 ExtendedImage）。
  bool layoutEquals(ImagePreviewDisplayConfig other) {
    return mode == other.mode &&
        fit == other.fit &&
        alignment == other.alignment &&
        initialAlignment == other.initialAlignment &&
        verticallyScrollable == other.verticallyScrollable &&
        imageWidth == other.imageWidth &&
        imageHeight == other.imageHeight;
  }
}

ImagePreviewDisplayMode imagePreviewResolveDisplayMode({
  required int imageWidth,
  required int imageHeight,
  required double screenWidth,
  required double screenHeight,
}) {
  if (imageWidth <= 0 ||
      imageHeight <= 0 ||
      screenWidth <= 0 ||
      screenHeight <= 0) {
    return ImagePreviewDisplayMode.normal;
  }

  final aspect = imageHeight / imageWidth;
  final inverseAspect = imageWidth / imageHeight;

  if (aspect >= imagePreviewExtraTallAspectRatio) {
    return ImagePreviewDisplayMode.extraTall;
  }
  if (aspect >= imagePreviewTallAspectRatio) {
    return ImagePreviewDisplayMode.tall;
  }

  final containDisplay = imagePreviewInitialDisplaySize(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    screenWidth: screenWidth,
    screenHeight: screenHeight,
    fit: BoxFit.contain,
  );
  if (inverseAspect >= imagePreviewWideAspectRatio) {
    return ImagePreviewDisplayMode.wide;
  }

  final nativeShortest = math.min(imageWidth, imageHeight).toDouble();
  final screenShortest = math.min(screenWidth, screenHeight);
  if (nativeShortest <
      screenShortest * imagePreviewSmallNativeShortSideFactor) {
    return ImagePreviewDisplayMode.small;
  }

  final screenArea = screenWidth * screenHeight;
  final displayArea = containDisplay.width * containDisplay.height;
  final smallByDisplay = containDisplay.width < screenWidth * 0.55 &&
      containDisplay.height < screenHeight * 0.55 &&
      displayArea <= screenArea * imagePreviewSmallDisplayCoverage;
  if (smallByDisplay) {
    return ImagePreviewDisplayMode.small;
  }
  return ImagePreviewDisplayMode.normal;
}

ImagePreviewDisplayConfig imagePreviewDisplayConfig({
  required int imageWidth,
  required int imageHeight,
  required double screenWidth,
  required double screenHeight,
  /// 聊天消息预览为 true：长图贴宽（可放大）避免黑边。
  /// 头像 / 群头像 / 朋友圈等为 false：长图只 scaleDown，不拉成全屏宽。
  bool fitTallImagesToScreenWidth = true,
}) {
  if (imageWidth <= 0 ||
      imageHeight <= 0 ||
      screenWidth <= 0 ||
      screenHeight <= 0) {
    return const ImagePreviewDisplayConfig(
      mode: ImagePreviewDisplayMode.normal,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      initialAlignment: InitialAlignment.center,
      verticallyScrollable: false,
      isTallImage: false,
    );
  }

  final mode = imagePreviewResolveDisplayMode(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    screenWidth: screenWidth,
    screenHeight: screenHeight,
  );
  final BoxFit fit;
  final Alignment alignment;
  final InitialAlignment initialAlignment;
  switch (mode) {
    case ImagePreviewDisplayMode.tall:
    case ImagePreviewDisplayMode.extraTall:
      if (fitTallImagesToScreenWidth) {
        // 聊天长图：按屏宽铺满，窄长截图也放大贴宽，避免两侧（或单侧）黑边。
        fit = BoxFit.fitWidth;
        alignment = Alignment.topCenter;
        initialAlignment = InitialAlignment.topCenter;
      } else {
        // 头像 / 朋友圈：保持原比例，不贴宽放大。
        fit = BoxFit.scaleDown;
        alignment = Alignment.center;
        initialAlignment = InitialAlignment.center;
      }
      break;
    case ImagePreviewDisplayMode.wide:
    case ImagePreviewDisplayMode.small:
    case ImagePreviewDisplayMode.normal:
      // contain: 大图等比缩入屏内（长边贴边、短边留黑）；小图不放大。
      // 之前用 scaleDown 导致竖图按高度缩后两侧露出全屏黑底，观感差。
      fit = BoxFit.contain;
      alignment = Alignment.center;
      initialAlignment = InitialAlignment.center;
      break;
  }
  final display = imagePreviewInitialDisplaySize(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    screenWidth: screenWidth,
    screenHeight: screenHeight,
    fit: fit,
  );
  // 仅聊天长图路径强制竖滑；头像/朋友圈即使判为 tall 也不因 mode 强制贴宽竖滑。
  final verticallyScrollable = (fitTallImagesToScreenWidth &&
          (mode == ImagePreviewDisplayMode.tall ||
              mode == ImagePreviewDisplayMode.extraTall)) ||
      display.height > screenHeight + 1;

  return ImagePreviewDisplayConfig(
    mode: mode,
    fit: fit,
    alignment: alignment,
    initialAlignment: initialAlignment,
    verticallyScrollable: verticallyScrollable,
    isTallImage: mode == ImagePreviewDisplayMode.tall ||
        mode == ImagePreviewDisplayMode.extraTall,
    isWideImage: mode == ImagePreviewDisplayMode.wide,
    isSmallImage: mode == ImagePreviewDisplayMode.small,
    isExtraTallImage: mode == ImagePreviewDisplayMode.extraTall,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
}

/// 元数据与解码像素宽高比是否对不上（EXIF 旋转等），对不上时以解码为准。
bool imagePreviewPixelAspectMismatch({
  required Size meta,
  required int decodedWidth,
  required int decodedHeight,
  double relativeEpsilon = 0.12,
}) {
  if (meta.width <= 0 ||
      meta.height <= 0 ||
      decodedWidth <= 0 ||
      decodedHeight <= 0) {
    return false;
  }
  final metaAspect = meta.width / meta.height;
  final decodedAspect = decodedWidth / decodedHeight;
  final relative = (metaAspect - decodedAspect).abs() /
      math.max(metaAspect, decodedAspect);
  return relative > relativeEpsilon;
}

/// 布局用像素：同比时用原图/元数据，避免 ResizeImage 放大解码后把小图二次铺满。
Size imagePreviewPreferredPixelSize({
  Size? meta,
  int decodedWidth = 0,
  int decodedHeight = 0,
}) {
  final hasMeta = meta != null && meta.width > 0 && meta.height > 0;
  final hasDecoded = decodedWidth > 0 && decodedHeight > 0;
  if (hasMeta && hasDecoded) {
    if (imagePreviewPixelAspectMismatch(
      meta: meta,
      decodedWidth: decodedWidth,
      decodedHeight: decodedHeight,
    )) {
      return Size(decodedWidth.toDouble(), decodedHeight.toDouble());
    }
    return meta;
  }
  if (hasMeta) {
    return meta;
  }
  if (hasDecoded) {
    return Size(decodedWidth.toDouble(), decodedHeight.toDouble());
  }
  return Size.zero;
}

ImagePreviewDisplayConfig imagePreviewDisplayConfigResolved({
  required V2TimMessage? sourceMessage,
  required double screenWidth,
  required double screenHeight,
  int decodedWidth = 0,
  int decodedHeight = 0,
  bool fitTallImagesToScreenWidth = true,
}) {
  final pixels = imagePreviewPreferredPixelSize(
    meta: imagePreviewMetaSizeFromMessage(sourceMessage),
    decodedWidth: decodedWidth,
    decodedHeight: decodedHeight,
  );
  return imagePreviewDisplayConfig(
    imageWidth: pixels.width.round(),
    imageHeight: pixels.height.round(),
    screenWidth: screenWidth,
    screenHeight: screenHeight,
    fitTallImagesToScreenWidth: fitTallImagesToScreenWidth,
  );
}

/// 预览绘制 [BoxFit]。
///
/// 非长图始终用 [display.fit]（contain）。之前对聊天普通图用 fill 是为了
/// 消除 boxSize 与图片比例的亚像素间隙，但 fill 会把图片锁死在框内，
/// 放大时无法超出框边界——contain 让手势变换自然溢出框外。
BoxFit imagePreviewPaintFit(
  ImagePreviewDisplayConfig display, {
  bool fitTallImagesToScreenWidth = true,
}) {
  return display.fit;
}

Size imagePreviewBoxSizeFor({
  required ImagePreviewDisplayConfig display,
  required double screenWidth,
  required double screenHeight,
}) {
  if (display.verticallyScrollable) {
    return Size(screenWidth, screenHeight);
  }
  return imagePreviewHeroDestSize(
    displaySize: imagePreviewInitialDisplaySize(
      imageWidth: display.imageWidth,
      imageHeight: display.imageHeight,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      fit: display.fit,
    ),
    viewport: Size(screenWidth, screenHeight),
  );
}

/// 从消息元数据读取图片像素尺寸（打开预览时即可决定 fit/对齐）。
///
/// 优先原图(0)/大图(2)尺寸；缩略图(1)的宽高常为方图，易把横图误判成 tall。
Size? imagePreviewMetaSizeFromMessage(V2TimMessage? message) {
  final images = message?.imageElem?.imageList;
  if (images == null || images.isEmpty) {
    return null;
  }

  Size? sizeOf(int preferredType) {
    for (final image in images) {
      if (image?.type != preferredType) {
        continue;
      }
      final width = image?.width;
      final height = image?.height;
      if (width == null || height == null || width <= 0 || height <= 0) {
        continue;
      }
      return Size(width.toDouble(), height.toDouble());
    }
    return null;
  }

  // V2TIM_IMAGE_TYPE: ORIGIN=0, THUMB=1, LARGE=2
  final original = sizeOf(0);
  if (original != null) {
    return original;
  }
  final large = sizeOf(2);
  if (large != null) {
    return large;
  }

  var bestArea = 0;
  int? bestWidth;
  int? bestHeight;
  for (final image in images) {
    final width = image?.width;
    final height = image?.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      continue;
    }
    final area = width * height;
    if (area > bestArea) {
      bestArea = area;
      bestWidth = width;
      bestHeight = height;
    }
  }
  if (bestWidth == null || bestHeight == null) {
    return null;
  }
  return Size(bestWidth.toDouble(), bestHeight.toDouble());
}

/// 解码后的布局与当前 ExtendedImage 声明的 fit/alignment 是否一致。
bool imagePreviewWidgetLayoutMatchesDisplay({
  required BoxFit? widgetFit,
  required AlignmentGeometry? widgetAlignment,
  required ImagePreviewDisplayConfig display,
}) {
  return widgetFit == display.fit && widgetAlignment == display.alignment;
}

ImagePreviewDisplayConfig imagePreviewDisplayConfigForItem({
  required V2TimMessage? sourceMessage,
  required double screenWidth,
  required double screenHeight,
  bool fitTallImagesToScreenWidth = true,
}) {
  final meta = imagePreviewMetaSizeFromMessage(sourceMessage);
  return imagePreviewDisplayConfig(
    imageWidth: meta?.width.round() ?? 0,
    imageHeight: meta?.height.round() ?? 0,
    screenWidth: screenWidth,
    screenHeight: screenHeight,
    fitTallImagesToScreenWidth: fitTallImagesToScreenWidth,
  );
}

ImagePreviewDisplayConfig imagePreviewDisplayConfigForState(
  ExtendedImageState state,
  double screenWidth,
  double screenHeight, {
  bool fitTallImagesToScreenWidth = true,
}) {
  final info = state.extendedImageInfo;
  return imagePreviewDisplayConfig(
    imageWidth: info?.image.width ?? 1,
    imageHeight: info?.image.height ?? 1,
    screenWidth: screenWidth,
    screenHeight: screenHeight,
    fitTallImagesToScreenWidth: fitTallImagesToScreenWidth,
  );
}

/// 预览页策略：是否对长图做贴宽放大（聊天开；头像/朋友圈关）。
class ImagePreviewFitPolicyScope extends InheritedWidget {
  const ImagePreviewFitPolicyScope({
    required this.fitTallImagesToScreenWidth,
    required super.child,
    super.key,
  });

  final bool fitTallImagesToScreenWidth;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ImagePreviewFitPolicyScope>()
            ?.fitTallImagesToScreenWidth ??
        true;
  }

  @override
  bool updateShouldNotify(ImagePreviewFitPolicyScope oldWidget) {
    return fitTallImagesToScreenWidth != oldWidget.fitTallImagesToScreenWidth;
  }
}

/// 全屏预览解码像素是否明显低于屏幕可用像素（疑似缩略图）。
bool isImagePreviewResolutionTooLow({
  required int imageWidth,
  required int imageHeight,
  required BuildContext context,
  double screenCoverage = 0.85,
}) {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return true;
  }
  final mq = MediaQuery.of(context);
  final dpr = mq.devicePixelRatio;
  final aspect = imageHeight / imageWidth;
  // FitWidth 长图：清晰度由「解码宽度 vs 屏宽像素」决定，不能用最长边（高度）误判够清。
  if (aspect >= imagePreviewTallAspectRatio) {
    final targetWidth = (mq.size.width * dpr * screenCoverage).round();
    return imageWidth < targetWidth;
  }
  final targetPixels =
      (mq.size.shortestSide * dpr * screenCoverage).round();
  final longestSide = imageWidth > imageHeight ? imageWidth : imageHeight;
  return longestSide < targetPixels;
}

/// 预览初始贴屏尺寸（与 [BoxFit] 一致，用于手势倍数与 Hero 落点）。
///
/// - [BoxFit.fitWidth] / [BoxFit.fitHeight]：按对应边铺满视口（允许放大），
///   供长图贴宽、避免窄长截图两侧黑边。
/// - [BoxFit.contain]：大图等比缩入屏内（短边贴边、长边不超），小图不放大。
/// - [BoxFit.scaleDown]：仅缩小不放大，小图保持原比例居中。
Size imagePreviewInitialDisplaySize({
  required int imageWidth,
  required int imageHeight,
  required double screenWidth,
  required double screenHeight,
  BoxFit fit = BoxFit.contain,
}) {
  if (imageWidth <= 0 ||
      imageHeight <= 0 ||
      screenWidth <= 0 ||
      screenHeight <= 0) {
    // Unknown size: keep the viewport as the layout box. Callers must paint
    // with contain/scaleDown (see [imagePreviewPaintFit]), never fill, or the
    // image will be stretched to fullscreen.
    if (screenWidth > 0 && screenHeight > 0) {
      return Size(screenWidth, screenHeight);
    }
    return Size.zero;
  }
  if (fit == BoxFit.fitWidth) {
    final scale = screenWidth / imageWidth;
    return Size(imageWidth * scale, imageHeight * scale);
  }
  if (fit == BoxFit.fitHeight) {
    final scale = screenHeight / imageHeight;
    return Size(imageWidth * scale, imageHeight * scale);
  }
  final containScale = math.min(
    screenWidth / imageWidth,
    screenHeight / imageHeight,
  );
  // contain: 大图缩小到屏内（长边贴边），小图保持原尺寸不放大。
  final scale = fit == BoxFit.scaleDown
      ? math.min(1.0, containScale)
      : containScale;
  return Size(imageWidth * scale, imageHeight * scale);
}

/// Hero 落点：初始展示尺寸夹在视口内，供飞行层停在「该显示的框」而不是整屏。
Size imagePreviewHeroDestSize({
  required Size displaySize,
  required Size viewport,
}) {
  if (viewport.width <= 0 || viewport.height <= 0) {
    return displaySize;
  }
  return Size(
    math.min(displaySize.width, viewport.width),
    math.min(displaySize.height, viewport.height),
  );
}

/// 把全屏 Hero 盒收成实际出画矩形（居中或顶对齐）。
Rect imagePreviewHeroDestRect({
  required Rect heroBox,
  required Size displaySize,
  Alignment alignment = Alignment.center,
}) {
  final w = displaySize.width.clamp(0.0, heroBox.width);
  final h = displaySize.height.clamp(0.0, heroBox.height);
  final origin = alignment.alongOffset(
    Offset(heroBox.width - w, heroBox.height - h),
  );
  return Rect.fromLTWH(
    heroBox.left + origin.dx,
    heroBox.top + origin.dy,
    w,
    h,
  );
}

/// 预览页告诉 Hero：飞行终点是出画尺寸，不是 SlidePage 的整屏盒。
class MediaPreviewHeroLayout extends InheritedWidget {
  const MediaPreviewHeroLayout({
    required this.displaySize,
    required this.alignment,
    required super.child,
    super.key,
  });

  final Size displaySize;
  final Alignment alignment;

  static MediaPreviewHeroLayout? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MediaPreviewHeroLayout>();
  }

  Rect inset(Rect heroBox) {
    return imagePreviewHeroDestRect(
      heroBox: heroBox,
      displaySize: displaySize,
      alignment: alignment,
    );
  }

  @override
  bool updateShouldNotify(MediaPreviewHeroLayout oldWidget) {
    return displaySize != oldWidget.displaySize ||
        alignment != oldWidget.alignment;
  }
}

/// 预览图落在应显示的框里，避免全屏壳 + scaleDown 造成 Hero 落地后再跳一次。
class ImagePreviewDisplayBox extends StatelessWidget {
  const ImagePreviewDisplayBox({
    super.key,
    required this.displaySize,
    required this.alignment,
    required this.child,
  });

  final Size displaySize;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final width = displaySize.width <= 0
        ? viewport.width
        : math.min(displaySize.width, viewport.width);
    final height = displaySize.height <= 0
        ? viewport.height
        : math.min(displaySize.height, viewport.height);
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: width,
        height: height,
        child: child,
      ),
    );
  }
}

RectTween mediaPreviewHeroRectTween({
  required Rect? begin,
  required Rect? end,
  MediaPreviewHeroLayout? layout,
}) {
  if (begin == null || end == null || layout == null) {
    return RectTween(begin: begin, end: end);
  }
  final pushing = end.width * end.height >= begin.width * begin.height;
  if (pushing) {
    return RectTween(begin: begin, end: layout.inset(end));
  }
  return RectTween(begin: layout.inset(begin), end: end);
}

/// 预览手势最大缩放：相对「进入预览时的屏上尺寸」再放大，不受原图像素宽高卡住。
double imagePreviewMaxScale({
  required int imageWidth,
  required int imageHeight,
  required double screenWidth,
  required double screenHeight,
  BoxFit fit = BoxFit.contain,
  double hardCap = 10.0,
  double minZoomFromInitial = 4.0,
  double beyondNativeFactor = 1.5,
}) {
  if (imageWidth <= 0 ||
      imageHeight <= 0 ||
      screenWidth <= 0 ||
      screenHeight <= 0) {
    return minZoomFromInitial;
  }

  final display = imagePreviewInitialDisplaySize(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    screenWidth: screenWidth,
    screenHeight: screenHeight,
    fit: fit,
  );
  if (display.width <= 0 || display.height <= 0) {
    return minZoomFromInitial;
  }

  // 相对初始显示，放大到原图像素 1:1 所需的倍数（小图可能 < 1）。
  final scaleToNative = math.max(
    imageWidth / display.width,
    imageHeight / display.height,
  );
  // contain 横图常已铺满屏宽：至少允许放到高度铺满，便于横滑细读结算表等。
  final fillHeightScale = display.height > 0 ? screenHeight / display.height : 1.0;
  final allowFillHeight = display.width >= screenWidth - 0.5 &&
      fillHeightScale > minZoomFromInitial + 0.05;
  final minAllowed =
      allowFillHeight ? fillHeightScale : minZoomFromInitial;
  // 至少允许 minAllowed 倍数字放大；大图额外给到原图像素附近。
  return math.min(
    hardCap,
    math.max(minAllowed, scaleToNative * beyondNativeFactor),
  );
}

/// 双击放大目标：按展示类型选择铺满宽/高或舒适倍数。
double imagePreviewDoubleTapScale({
  required int imageWidth,
  required int imageHeight,
  required double screenWidth,
  required double screenHeight,
  BoxFit fit = BoxFit.contain,
  ImagePreviewDisplayMode? mode,
  ImagePreviewDisplayConfig? display,
}) {
  final resolvedMode =
      mode ?? display?.mode ?? ImagePreviewDisplayMode.normal;
  final resolvedFit = display?.fit ?? fit;
  final maxScale = imagePreviewMaxScale(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    screenWidth: screenWidth,
    screenHeight: screenHeight,
    fit: resolvedFit,
  );
  if (imageWidth <= 0 || imageHeight <= 0) {
    return math.min(2.0, maxScale);
  }
  final initialDisplay = imagePreviewInitialDisplaySize(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    screenWidth: screenWidth,
    screenHeight: screenHeight,
    fit: resolvedFit,
  );
  if (initialDisplay.width <= 0 || initialDisplay.height <= 0) {
    return math.min(2.0, maxScale);
  }

  double target;
  switch (resolvedMode) {
    case ImagePreviewDisplayMode.normal:
      target = 2.0;
      break;
    case ImagePreviewDisplayMode.tall:
      target = 1.75;
      break;
    case ImagePreviewDisplayMode.extraTall:
      target = 1.5;
      break;
    case ImagePreviewDisplayMode.wide:
      final fillWidth = screenWidth / initialDisplay.width;
      final fillHeight = screenHeight / initialDisplay.height;
      // contain 后通常已铺满屏宽；此时双击改为高度铺满（横向细读），但限制
      // 在 3x 内，避免极宽图一次跳变到 10x+ 造成迷失感。
      target = (fillWidth > 1.05 ? fillWidth : fillHeight).clamp(1.0, 3.0);
      break;
    case ImagePreviewDisplayMode.small:
      target = 2.0;
      break;
  }
  return math.min(maxScale, math.max(1.0, target));
}

/// 预览解码目标：按屏幕像素上限缩放，超大图标记分阶段加载。
class ImagePreviewDecodeTarget {
  const ImagePreviewDecodeTarget({
    this.width,
    this.height,
    this.staged = false,
  });

  final int? width;
  final int? height;

  /// 原图像素极高，首屏先用受限解码，停稳后再升级。
  final bool staged;

  bool get shouldResize => width != null || height != null;
}

bool imagePreviewIsHugeImage({
  required int imageWidth,
  required int imageHeight,
}) {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return false;
  }
  final longest = math.max(imageWidth, imageHeight);
  return longest >= imagePreviewHugeLongestSidePx;
}

/// 超长图解码最长边硬顶（防极端截图 OOM）；超过则等比压长边并标 staged。
const int imagePreviewTallDecodeMaxLongestSidePx = 8192;

ImagePreviewDecodeTarget imagePreviewDecodeTarget({
  required double screenWidth,
  required double screenHeight,
  required double devicePixelRatio,
  required int imageWidth,
  required int imageHeight,
  bool preferFullResolution = false,
}) {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return const ImagePreviewDecodeTarget();
  }
  final staged = imagePreviewIsHugeImage(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
  if (preferFullResolution && !staged) {
    return ImagePreviewDecodeTarget(staged: staged);
  }

  final capW =
      (screenWidth * devicePixelRatio * imagePreviewDecodeScreenFactor).round();
  final capH =
      (screenHeight * devicePixelRatio * imagePreviewDecodeScreenFactor).round();

  // 长图 / 超长图预览用 FitWidth：屏上宽度≈屏宽，高度可跨多屏。
  // 若仍用 min(capW/w, capH/h) 把整图塞进「一屏像素盒」，宽度会被严重下采样，
  // 贴宽放大后文字发糊（聊天长截图典型症状）。
  final aspect = imageHeight / imageWidth;
  final tallFitWidth = aspect >= imagePreviewTallAspectRatio;
  if (tallFitWidth) {
    return _tallFitWidthDecodeTarget(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      capW: capW,
      staged: staged,
    );
  }

  if (imageWidth <= capW && imageHeight <= capH) {
    return ImagePreviewDecodeTarget(staged: staged);
  }

  final scale = math.min(capW / imageWidth, capH / imageHeight);
  return ImagePreviewDecodeTarget(
    width: math.max(1, (imageWidth * scale).round()),
    height: math.max(1, (imageHeight * scale).round()),
    staged: staged,
  );
}

ImagePreviewDecodeTarget _tallFitWidthDecodeTarget({
  required int imageWidth,
  required int imageHeight,
  required int capW,
  required bool staged,
}) {
  // 宽度贴齐屏宽像素预算；高度按比例保留，保证 FitWidth 后文字清晰。
  final widthScale = imageWidth <= capW ? 1.0 : capW / imageWidth;
  var outW = math.max(1, (imageWidth * widthScale).round());
  var outH = math.max(1, (imageHeight * widthScale).round());
  var outStaged = staged;
  final longest = math.max(outW, outH);
  if (longest > imagePreviewTallDecodeMaxLongestSidePx) {
    final hard = imagePreviewTallDecodeMaxLongestSidePx / longest;
    outW = math.max(1, (outW * hard).round());
    outH = math.max(1, (outH * hard).round());
    outStaged = true;
  }
  if (outW >= imageWidth && outH >= imageHeight) {
    return ImagePreviewDecodeTarget(staged: outStaged);
  }
  return ImagePreviewDecodeTarget(
    width: outW,
    height: outH,
    staged: outStaged,
  );
}

/// 将网络/文件图包装为屏尺寸解码，降低内存峰值。
ImageProvider imagePreviewDecodedProvider(
  ImageProvider provider, {
  required ImagePreviewDecodeTarget target,
}) {
  if (!target.shouldResize) {
    return provider;
  }
  if (provider is ResizeImage) {
    return provider;
  }
  return ResizeImage(
    provider,
    width: target.width,
    height: target.height,
  );
}

ImagePreviewDecodeTarget imagePreviewDecodeTargetForMessage(
  BuildContext context, {
  required V2TimMessage? message,
  bool preferFullResolution = false,
}) {
  final meta = imagePreviewMetaSizeFromMessage(message);
  final mq = MediaQuery.of(context);
  return imagePreviewDecodeTarget(
    screenWidth: mq.size.width,
    screenHeight: mq.size.height,
    devicePixelRatio: mq.devicePixelRatio,
    imageWidth: meta?.width.round() ?? 0,
    imageHeight: meta?.height.round() ?? 0,
    preferFullResolution: preferFullResolution,
  );
}

/// 全屏预览统一手势参数（普通图 [GesturedImage] / [ExtendedImageGesture] 共用）。
GestureConfig buildImagePreviewGestureConfig({
  required bool inPageView,
  required ImagePreviewDisplayConfig display,
  required double maxScale,
}) {
  final panScale = imagePreviewInitialScale(
    verticallyScrollable: display.verticallyScrollable,
  );
  final profile = display.gestureProfile;
  return GestureConfig(
    inPageView: inPageView,
    minScale: panScale,
    // 允许暂时欠缩，松手由 GesturedImage / TallImageScrollPreview 迅速弹回。
    animationMinScale: math.min(panScale, imagePreviewAnimationMinScale),
    maxScale: maxScale,
    animationMaxScale: maxScale + 0.5,
    speed: imagePreviewPanSpeed,
    inertialSpeed: profile.inertialSpeed,
    initialScale: panScale,
    initialAlignment: display.initialAlignment,
    hitTestBehavior: HitTestBehavior.opaque,
    cacheGesture: false,
  );
}
