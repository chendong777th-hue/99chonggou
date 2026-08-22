import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_resolution_utils.dart';

/// 全屏预览手势物理参数（企业级手感调优区间的中位值）。
const double imagePreviewPanDamping = 0.80;

/// 贴边时额外阻尼下限 / 上限（随越界深度在二者间插值）。
/// 越界越深阻力越大，尽快刹住，避免拖出大片空白再回弹。
const double imagePreviewEdgeDampingMin = 0.08;
const double imagePreviewEdgeDampingMax = 0.35;

/// 触发惯性滑动的最小速度（px/s）。
const double imagePreviewInertialMinVelocity = 300.0;

/// 惯性每帧速度衰减（60fps 基准）。
const double imagePreviewInertialDecayPerFrame = 0.95;

/// 边界回弹弹簧（偏硬偏快，避免大幅越界后缓慢漂移回弹）。
const SpringDescription imagePreviewBoundarySpring = SpringDescription(
  mass: 1,
  stiffness: 420,
  damping: 36,
);

/// 平移可活动区间（屏幕坐标系下的 translation 范围）。
class ImagePreviewPanTranslationBounds {
  const ImagePreviewPanTranslationBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  Offset clamp(Offset translation) {
    return Offset(
      translation.dx.clamp(minX, maxX),
      translation.dy.clamp(minY, maxY),
    );
  }

  /// 越界量（各轴 ≥ 0）。
  Offset overscroll(Offset translation) {
    return Offset(
      _axisOverscroll(translation.dx, minX, maxX),
      _axisOverscroll(translation.dy, minY, maxY),
    );
  }

  static double _axisOverscroll(double value, double min, double max) {
    if (value < min) {
      return min - value;
    }
    if (value > max) {
      return value - max;
    }
    return 0;
  }
}

/// 顶对齐长图 / InteractiveViewer 矩阵平移边界。
ImagePreviewPanTranslationBounds imagePreviewMatrixPanBounds({
  required Size viewport,
  required Size content,
  required double scale,
  bool topAligned = true,
}) {
  final scaledW = content.width * scale;
  final scaledH = content.height * scale;
  double minX;
  double maxX;
  if (scaledW > viewport.width) {
    minX = viewport.width - scaledW;
    maxX = 0;
  } else {
    final centered = (viewport.width - scaledW) * 0.5;
    minX = centered;
    maxX = centered;
  }

  double minY;
  double maxY;
  if (scaledH > viewport.height) {
    minY = viewport.height - scaledH;
    maxY = 0;
  } else if (topAligned) {
    minY = 0;
    maxY = 0;
  } else {
    final centered = (viewport.height - scaledH) * 0.5;
    minY = centered;
    maxY = centered;
  }
  return ImagePreviewPanTranslationBounds(
    minX: minX,
    maxX: maxX,
    minY: minY,
    maxY: maxY,
  );
}

/// 根据越界深度计算边缘阻尼系数（0.2～0.5）。
double imagePreviewEdgeDampingFactor({
  required double overscrollPx,
  required double viewportSpan,
}) {
  if (overscrollPx <= 0 || viewportSpan <= 0) {
    return 1.0;
  }
  final depth = (overscrollPx / (viewportSpan * 0.10)).clamp(0.0, 1.0);
  return imagePreviewEdgeDampingMax +
      (imagePreviewEdgeDampingMin - imagePreviewEdgeDampingMax) * depth;
}

/// 长图 1x 浏览的竖向优先 dominance（与 [resolveTallImageScrollAxis] 一致）。
const double imagePreviewTallScrollAxisDominance = 2.4;

/// 长图放大后图内平移的轴锁定 dominance：低于 1x，让左右看图更易锁横轴。
/// 图集翻页仍走更严的 [tallImageShouldRouteGalleryPage]，二者解耦。
const double imagePreviewTallZoomPanAxisDominance = 1.2;

/// 放大后手动拖动阻尼：长图与 1x 同为 1:1；普通宽图仍用 profile 阻尼。
double imagePreviewZoomPanDamping({
  required bool tallScrollMode,
  required bool fromMomentum,
  required ImagePreviewGestureProfile profile,
}) {
  if (fromMomentum) {
    return 1.0;
  }
  if (tallScrollMode) {
    return imagePreviewPanSpeed;
  }
  return profile.panDamping;
}

/// 惯性启动阈值：任一轴达到 [minVelocity] 即可（避免单轴清零后 distance 不足）。
bool imagePreviewMomentumMeetsMinVelocity(Offset velocity, double minVelocity) {
  return math.max(velocity.dx.abs(), velocity.dy.abs()) >= minVelocity;
}

/// 抬手后用于惯性 runner 的速度（含阻尼 / 长图竖向优先 / 贴边横漂抑制）。
Offset imagePreviewMomentumStartVelocity({
  required Offset velocityPixelsPerSecond,
  required bool zoomed,
  required bool tallScrollMode,
  required ImagePreviewGestureProfile profile,
  required ImagePreviewPanTranslationBounds bounds,
  required Offset translation,
}) {
  final damping = zoomed ? profile.panDamping : imagePreviewPanSpeed;
  var scaled = Offset(
    velocityPixelsPerSecond.dx * damping,
    velocityPixelsPerSecond.dy * damping,
  );
  if (!zoomed && tallScrollMode) {
    return Offset(0, scaled.dy);
  }
  if (zoomed && tallScrollMode) {
    // 放大后图内横/纵均 1:1 惯性；贴边且朝界外的横速清零，避免惯性“甩出”像要切图。
    // 真正切图仍由贴边 + 纯横滑门槛决定，不靠惯性翻页。
    var vx = velocityPixelsPerSecond.dx * imagePreviewPanSpeed;
    final vy = velocityPixelsPerSecond.dy * imagePreviewPanSpeed;
    final hasH = imagePreviewBoundsAllowHorizontalScroll(bounds);
    if (hasH) {
      final tx = translation.dx;
      const slop = 3.0;
      final atLeft = tx <= bounds.minX + slop;
      final atRight = tx >= bounds.maxX - slop;
      // 左缘继续左甩 / 右缘继续右甩 → 清零；滑回图内保留。
      if (atLeft && vx < 0) {
        vx = 0;
      } else if (atRight && vx > 0) {
        vx = 0;
      }
    }
    return Offset(vx, vy);
  }
  if (zoomed) {
    final hasH = imagePreviewBoundsAllowHorizontalScroll(bounds);
    if (hasH) {
      final tx = translation.dx;
      const slop = 3.0;
      final atLeft = tx <= bounds.minX + slop;
      final atRight = tx >= bounds.maxX - slop;
      if (!atLeft && !atRight) {
        scaled = Offset(0, scaled.dy);
      } else if (atRight && scaled.dx < 0) {
        scaled = Offset(0, scaled.dy);
      } else if (atLeft && scaled.dx > 0) {
        scaled = Offset(0, scaled.dy);
      }
    }
    final boost = profile.inertialSpeed / 400.0;
    scaled = Offset(scaled.dx * boost, scaled.dy * boost);
  }
  return scaled;
}

/// 带基础阻尼 + 边缘阻尼的平移增量。
Offset imagePreviewDampedPanDelta({
  required Offset delta,
  required Offset translation,
  required ImagePreviewPanTranslationBounds bounds,
  required Size viewport,
  double panDamping = imagePreviewPanDamping,
}) {
  if (delta == Offset.zero) {
    return Offset.zero;
  }
  var dx = delta.dx * panDamping;
  var dy = delta.dy * panDamping;

  final nextX = translation.dx + dx;
  final nextY = translation.dy + dy;
  final overscroll = bounds.overscroll(Offset(nextX, nextY));

  if (overscroll.dx > 0) {
    dx *= imagePreviewEdgeDampingFactor(
      overscrollPx: overscroll.dx,
      viewportSpan: viewport.width,
    );
  }
  if (overscroll.dy > 0) {
    dy *= imagePreviewEdgeDampingFactor(
      overscrollPx: overscroll.dy,
      viewportSpan: viewport.height,
    );
  }
  return Offset(dx, dy);
}

/// 放大后平移轴：未判定 / 仅横 / 仅竖 / 双轴自由。
enum ImagePreviewPanAxisLock {
  undecided,
  horizontal,
  vertical,
  free,
}

bool imagePreviewBoundsAllowHorizontalScroll(
  ImagePreviewPanTranslationBounds bounds,
) {
  return (bounds.maxX - bounds.minX).abs() > 0.5;
}

bool imagePreviewBoundsAllowVerticalScroll(
  ImagePreviewPanTranslationBounds bounds,
) {
  return (bounds.maxY - bounds.minY).abs() > 0.5;
}

/// 根据可滚动方向解析轴锁定（单轴可滚时直接锁定，双轴可滚则保持未判定）。
ImagePreviewPanAxisLock imagePreviewResolvePanAxisLock({
  required ImagePreviewPanTranslationBounds bounds,
}) {
  final scrollH = imagePreviewBoundsAllowHorizontalScroll(bounds);
  final scrollV = imagePreviewBoundsAllowVerticalScroll(bounds);
  if (scrollH && !scrollV) {
    return ImagePreviewPanAxisLock.horizontal;
  }
  if (scrollV && !scrollH) {
    return ImagePreviewPanAxisLock.vertical;
  }
  if (!scrollH && !scrollV) {
    return ImagePreviewPanAxisLock.free;
  }
  return ImagePreviewPanAxisLock.undecided;
}

/// 双轴可滚时，按本手势累计位移锁定主轴，减少斜向漂移。
ImagePreviewPanAxisLock imagePreviewLockPanAxisForGesture({
  required ImagePreviewPanAxisLock current,
  required Offset gestureTotalDelta,
  double slop = 8.0,
  double dominance = 1.15,
}) {
  if (current != ImagePreviewPanAxisLock.undecided) {
    return current;
  }
  if (gestureTotalDelta.distance < slop) {
    return current;
  }
  if (gestureTotalDelta.dx.abs() >
      gestureTotalDelta.dy.abs() * dominance) {
    return ImagePreviewPanAxisLock.horizontal;
  }
  if (gestureTotalDelta.dy.abs() >
      gestureTotalDelta.dx.abs() * dominance) {
    return ImagePreviewPanAxisLock.vertical;
  }
  return current;
}

Offset imagePreviewApplyPanAxisLock(
  Offset delta,
  ImagePreviewPanAxisLock lock,
) {
  switch (lock) {
    case ImagePreviewPanAxisLock.horizontal:
      return Offset(delta.dx, 0);
    case ImagePreviewPanAxisLock.vertical:
      return Offset(0, delta.dy);
    case ImagePreviewPanAxisLock.undecided:
    case ImagePreviewPanAxisLock.free:
      return delta;
  }
}

/// 按类型主轴偏好解析轴锁定（放大后减少斜向漂移）。
ImagePreviewPanAxisLock imagePreviewAxisLockForPreference({
  required ImagePreviewPanAxisPreference preference,
  ImagePreviewPanAxisLock gestureLock = ImagePreviewPanAxisLock.undecided,
}) {
  switch (preference) {
    case ImagePreviewPanAxisPreference.vertical:
      return ImagePreviewPanAxisLock.vertical;
    case ImagePreviewPanAxisPreference.horizontal:
      return ImagePreviewPanAxisLock.horizontal;
    case ImagePreviewPanAxisPreference.free:
      return gestureLock;
  }
}

/// 普通图 [GesturedImage] 放大后平移轴：双轴可滚且 free 偏好时不锁轴。
ImagePreviewPanAxisLock imagePreviewResolveZoomPanAxisLock({
  required ImagePreviewPanAxisPreference preference,
  required bool computeHorizontalBoundary,
  required bool computeVerticalBoundary,
  required ImagePreviewPanAxisLock currentLock,
  required Offset gestureTotalDelta,
  required Offset delta,
  double dominance = 1.15,
}) {
  ImagePreviewPanAxisLock gestureLock = ImagePreviewPanAxisLock.undecided;
  if (computeHorizontalBoundary && !computeVerticalBoundary) {
    gestureLock = ImagePreviewPanAxisLock.horizontal;
  } else if (!computeHorizontalBoundary && computeVerticalBoundary) {
    gestureLock = ImagePreviewPanAxisLock.vertical;
  } else if (computeHorizontalBoundary && computeVerticalBoundary) {
    // 放大后双轴可滚：一律二维平移（横图/全景也能滑到底部）。
    return ImagePreviewPanAxisLock.free;
  }
  return imagePreviewAxisLockForPreference(
    preference: preference,
    gestureLock: gestureLock,
  );
}

/// 逐帧衰减的惯性平移（松手后）。
class ImagePreviewPanMomentumRunner {
  ImagePreviewPanMomentumRunner({
    required TickerProvider vsync,
    required this.onDelta,
    this.onEnd,
    this.minVelocity = imagePreviewInertialMinVelocity,
    this.decayPerFrame = imagePreviewInertialDecayPerFrame,
  }) : _vsync = vsync;

  final TickerProvider _vsync;
  final void Function(Offset delta) onDelta;
  final VoidCallback? onEnd;
  final double minVelocity;
  final double decayPerFrame;

  Ticker? _ticker;
  Offset _velocity = Offset.zero;
  Duration? _lastElapsed;

  bool get isRunning => _ticker?.isActive ?? false;

  void stop() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _lastElapsed = null;
    _velocity = Offset.zero;
  }

  void start(Offset velocityPixelsPerSecond) {
    stop();
    if (!imagePreviewMomentumMeetsMinVelocity(
      velocityPixelsPerSecond,
      minVelocity,
    )) {
      return;
    }
    _velocity = velocityPixelsPerSecond;
    _ticker = _vsync.createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final last = _lastElapsed;
    _lastElapsed = elapsed;
    if (last == null) {
      return;
    }
    final dt = (elapsed - last).inMicroseconds / 1000000.0;
    if (dt <= 0) {
      return;
    }
    final delta = _velocity * dt;
    onDelta(delta);

    // 按帧衰减：v *= decay^frames
    final frames = dt * 60.0;
    final decay = math.pow(decayPerFrame, frames).toDouble();
    _velocity = _velocity * decay;

    if (_velocity.distance < 28) {
      stop();
      onEnd?.call();
    }
  }
}

/// 越界后弹簧回弹到合法区间。
class ImagePreviewSpringReboundRunner {
  ImagePreviewSpringReboundRunner({required TickerProvider vsync})
      : _vsync = vsync;

  final TickerProvider _vsync;
  Ticker? _ticker;
  SpringSimulation? _simX;
  SpringSimulation? _simY;
  double _startSeconds = 0;
  Duration? _startElapsed;
  void Function(Offset translation)? _onUpdate;
  VoidCallback? _onEnd;

  bool get isRunning => _ticker?.isActive ?? false;

  void stop() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _simX = null;
    _simY = null;
    _startElapsed = null;
    _onUpdate = null;
    _onEnd = null;
  }

  void animate({
    required Offset from,
    required Offset to,
    Offset velocity = Offset.zero,
    required void Function(Offset translation) onUpdate,
    VoidCallback? onEnd,
    SpringDescription spring = imagePreviewBoundarySpring,
  }) {
    stop();
    if ((from - to).distance < 0.5) {
      onEnd?.call();
      return;
    }
    _onUpdate = onUpdate;
    _onEnd = onEnd;
    _simX = SpringSimulation(spring, from.dx, to.dx, velocity.dx);
    _simY = SpringSimulation(spring, from.dy, to.dy, velocity.dy);
    _startSeconds = 0;
    _startElapsed = null;
    _ticker = _vsync.createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final start = _startElapsed;
    if (start == null) {
      _startElapsed = elapsed;
      return;
    }
    final t = (elapsed - start).inMicroseconds / 1000000.0;
    final simX = _simX!;
    final simY = _simY!;
    final next = Offset(simX.x(t), simY.x(t));
    _onUpdate?.call(next);
    if (simX.isDone(t) && simY.isDone(t)) {
      final end = _onEnd;
      stop();
      end?.call();
    }
  }
}

/// 单击判定：位移小、未缩放、速度低。须优先于图集 onDragEnd，否则轻点会翻页。
const double kMediaPreviewTapMaxDistance = 18;
const double kMediaPreviewTapMaxVelocity = 280;

/// 图集横滑翻页 slop：低于此值不当作翻页。
const double kMediaPreviewPageDragSlop = 24;

bool mediaPreviewIsTapGesture({
  required double accumulatedDistance,
  required double totalScale,
  required double initialScale,
  required double velocityDistance,
}) {
  return accumulatedDistance < kMediaPreviewTapMaxDistance &&
      totalScale <= initialScale * 1.05 &&
      velocityDistance < kMediaPreviewTapMaxVelocity;
}

bool mediaPreviewShouldBeginPageDrag({
  required bool alreadyDragging,
  required bool horizontalIntent,
  required int pointerCount,
  required double scale,
  required double accumulatedDistance,
}) {
  if (alreadyDragging) {
    return true;
  }
  return pointerCount == 1 &&
      scale == 1 &&
      horizontalIntent &&
      accumulatedDistance >= kMediaPreviewPageDragSlop;
}
