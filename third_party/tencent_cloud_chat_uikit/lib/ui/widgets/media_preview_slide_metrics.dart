import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_video_utils.dart';

/// 下滑关闭预览：回弹时长（短于 extended_image 默认 500ms，手感更跟手）。
const Duration mediaPreviewSlideResetDuration = Duration(milliseconds: 180);

/// 微信式关闭：从当前跟手状态连续缩放淡出。
const Duration mediaPreviewScaleFadeExitDuration = Duration(milliseconds: 180);

/// 微信式关闭结束时的内容缩放下限。
const double mediaPreviewScaleFadeEndScale = 0.36;

/// 向子树（[GesturedImage] / 长图）下发跟手缩放，避免在全屏中心缩放造成小图漂移。
class MediaPreviewSlideVisualScope
    extends InheritedNotifier<MediaPreviewSlideMetrics> {
  const MediaPreviewSlideVisualScope({
    super.key,
    required MediaPreviewSlideMetrics metrics,
    required super.child,
  }) : super(notifier: metrics);

  static double contentScaleOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<MediaPreviewSlideVisualScope>();
    return scope?.notifier?.contentScale ?? 1.0;
  }

  static MediaPreviewSlideMetrics? maybeMetricsOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MediaPreviewSlideVisualScope>()
        ?.notifier;
  }
}

typedef MediaPreviewSlideEndCallback = void Function(Velocity velocity);

enum MediaPreviewCloseMode {
  normalBack,
  slideDismiss,
  switchItem,
}

/// 与 [VideoScreen] / [ImageScreen] 下滑关闭阈值保持一致（上/下均可关闭）。
bool mediaPreviewShouldDismissForSlide(Offset offset, double velocityDy) {
  final oy = offset.dy.abs();
  final vy = velocityDy.abs();
  if (oy > 96) {
    return true;
  }
  if (oy > 48 && vy > 360) {
    return true;
  }
  if (oy > 12 && vy > 900) {
    return true;
  }
  return false;
}

/// 滑动遮罩/工具栏状态：避免滑动中 setState 重建手势层导致断触。
class MediaPreviewSlideMetrics extends ChangeNotifier {
  double backdropOpacity = 1.0;
  double chromeOpacity = 1.0;
  Offset slideOffset = Offset.zero;

  /// 跟手与离场共用：唯一缩放/内容透明度来源（SlidePage 不再二次缩放）。
  double contentScale = 1.0;
  double contentOpacity = 1.0;

  /// 下滑关闭已接管：图片位移改读 [slideOffset]，忽略 SlidePage 回弹置零。
  bool dismissVisualLocked = false;

  void lockDismissVisuals() {
    if (dismissVisualLocked) {
      return;
    }
    dismissVisualLocked = true;
    notifyListeners();
  }

  void updateFromSlide(ExtendedImageSlidePageState state, Size size) {
    syncDragVisuals(
      state.offset,
      size,
      sliding: state.isSliding || state.offset.distance > 0.5,
    );
  }

  /// 视频预览专用：直接跟手更新位移，不经过 [ExtendedImageSlidePage.slide] 的 setState。
  void applyVerticalDrag(double dy, Size size) {
    if (dy == 0) {
      return;
    }
    syncDragVisuals(Offset(0, slideOffset.dy + dy), size, sliding: true);
  }

  void applySnapFrame(Offset offset, Size size) {
    syncDragVisuals(offset, size, sliding: offset.distance > 0.5);
  }

  /// 跟手帧：位移 / 缩放 / 遮罩 / 内容透明度一次写齐，保证松手离场可无缝衔接。
  void syncDragVisuals(
    Offset offset,
    Size size, {
    bool sliding = true,
  }) {
    final nextScale = mediaPreviewWeChatSlideScale(offset);
    final nextBackdrop =
        mediaPreviewScrimOpacityForSlideOffset(offset, size).clamp(0.0, 1.0);
    final nextContentOpacity =
        mediaPreviewWeChatDragContentOpacity(offset, size: size);
    final nextChrome = sliding ? 0.0 : 1.0;
    final changed = slideOffset != offset ||
        (contentScale - nextScale).abs() > 0.001 ||
        (backdropOpacity - nextBackdrop).abs() > 0.008 ||
        (contentOpacity - nextContentOpacity).abs() > 0.008 ||
        (chromeOpacity - nextChrome).abs() > 0.001;
    slideOffset = offset;
    contentScale = nextScale;
    backdropOpacity = nextBackdrop;
    contentOpacity = nextContentOpacity;
    chromeOpacity = nextChrome;
    if (changed) {
      notifyListeners();
    }
  }

  void applyExitFrame({
    required double scale,
    required double contentOpacity,
    required double backdropOpacity,
    Offset? slideOffset,
  }) {
    contentScale = scale.clamp(0.01, 1.0);
    this.contentOpacity = contentOpacity.clamp(0.0, 1.0);
    this.backdropOpacity = backdropOpacity.clamp(0.0, 1.0);
    if (slideOffset != null) {
      this.slideOffset = slideOffset;
    }
    chromeOpacity = 0.0;
    notifyListeners();
  }

  void hideChromeForSlide() {
    if (chromeOpacity == 0.0) {
      return;
    }
    chromeOpacity = 0.0;
    notifyListeners();
  }

  void resetBackdrop() {
    if (backdropOpacity == 1.0 &&
        chromeOpacity == 1.0 &&
        slideOffset == Offset.zero &&
        contentScale == 1.0 &&
        contentOpacity == 1.0 &&
        !dismissVisualLocked) {
      return;
    }
    backdropOpacity = 1.0;
    chromeOpacity = 1.0;
    slideOffset = Offset.zero;
    contentScale = 1.0;
    contentOpacity = 1.0;
    dismissVisualLocked = false;
    notifyListeners();
  }
}

/// 下滑未达关闭阈值时的回弹动画（不触发 ExtendedImageSlidePage）。
class MediaPreviewSlideSnapController {
  AnimationController? _controller;

  void interrupt() {
    _controller?.stop();
    _controller?.dispose();
    _controller = null;
  }

  void dispose() {
    interrupt();
  }

  void snapBack({
    required TickerProvider vsync,
    required MediaPreviewSlideMetrics metrics,
    required Size size,
    Duration duration = mediaPreviewSlideResetDuration,
    VoidCallback? onComplete,
  }) {
    interrupt();
    final startDy = metrics.slideOffset.dy;
    if (startDy == 0) {
      metrics.resetBackdrop();
      onComplete?.call();
      return;
    }
    final controller = AnimationController(vsync: vsync, duration: duration);
    _controller = controller;
    controller.addListener(() {
      final t = Curves.easeOutCubic.transform(controller.value);
      metrics.applySnapFrame(Offset(0, startDy * (1 - t)), size);
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        metrics.resetBackdrop();
        interrupt();
        onComplete?.call();
      }
    });
    controller.forward();
  }
}

void interruptMediaPreviewSlideSnapBack(
  GlobalKey<ExtendedImageSlidePageState> slidePageKey,
) {
  _interruptSlideSnapBack(slidePageKey);
}

class MediaPreviewSlideDismissController {
  AnimationController? _exitController;
  Timer? _safetyTimer;

  void dispose() {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    _exitController?.stop();
    _exitController?.dispose();
    _exitController = null;
  }

  void startMomentumDismiss({
    required TickerProvider vsync,
    required BuildContext context,
    required GlobalKey<ExtendedImageSlidePageState> slidePageKey,
    required MediaPreviewSlideMetrics metrics,
    required bool Function() isMounted,
    required bool Function() isClosing,
    required bool Function() prepareForClose,
    required VoidCallback popRoute,
    ScaleEndDetails? details,
    required Offset releaseOffset,
  }) {
    if (isClosing()) {
      return;
    }
    interruptMediaPreviewSlideSnapBack(slidePageKey);
    slidePageKey.currentState?.backAnimationController.stop();
    // 松手前先按释放位移对齐跟手视觉，避免离场首帧跳变。
    final size = MediaQuery.sizeOf(context);
    final aligned = releaseOffset.dy.abs() > metrics.slideOffset.dy.abs()
        ? releaseOffset
        : metrics.slideOffset;
    metrics.syncDragVisuals(aligned, size, sliding: true);
    metrics.lockDismissVisuals();
    if (!prepareForClose()) {
      return;
    }
    _scheduleSafetyPop(
      isMounted: isMounted,
      isClosing: isClosing,
      popRoute: popRoute,
    );
    _runScaleFadeExit(
      vsync: vsync,
      metrics: metrics,
      isMounted: isMounted,
      isClosing: isClosing,
      popRoute: popRoute,
      details: details,
      releaseOffset: aligned,
    );
  }

  /// 长图等自定义层：只动画 [MediaPreviewSlideMetrics]（从当前跟手状态连续缩放淡出）。
  void startMetricsMomentumDismiss({
    required TickerProvider vsync,
    required BuildContext context,
    required MediaPreviewSlideMetrics metrics,
    required bool Function() isMounted,
    required bool Function() isClosing,
    required bool Function() prepareForClose,
    required VoidCallback popRoute,
    ScaleEndDetails? details,
    required Offset releaseOffset,
  }) {
    if (isClosing()) {
      return;
    }
    final size = MediaQuery.sizeOf(context);
    final aligned = releaseOffset.dy.abs() > metrics.slideOffset.dy.abs()
        ? releaseOffset
        : metrics.slideOffset;
    metrics.syncDragVisuals(aligned, size, sliding: true);
    metrics.lockDismissVisuals();
    if (!prepareForClose()) {
      return;
    }
    _scheduleSafetyPop(
      isMounted: isMounted,
      isClosing: isClosing,
      popRoute: popRoute,
    );
    _runScaleFadeExit(
      vsync: vsync,
      metrics: metrics,
      isMounted: isMounted,
      isClosing: isClosing,
      popRoute: popRoute,
      details: details,
      releaseOffset: aligned,
    );
  }

  void _scheduleSafetyPop({
    required bool Function() isMounted,
    required bool Function() isClosing,
    required VoidCallback popRoute,
  }) {
    _safetyTimer?.cancel();
    _safetyTimer = Timer(const Duration(milliseconds: 360), () {
      if (isMounted() && isClosing()) {
        _popNow(isClosing: isClosing, popRoute: popRoute);
      }
    });
  }

  void _popNow({
    required bool Function() isClosing,
    required VoidCallback popRoute,
  }) {
    if (!isClosing()) {
      return;
    }
    _safetyTimer?.cancel();
    _safetyTimer = null;
    _exitController?.stop();
    _exitController?.dispose();
    _exitController = null;
    popRoute();
  }

  /// 从当前跟手缩放/透明度连续离场，不再重置到 1.0 再播动画。
  void _runScaleFadeExit({
    required TickerProvider vsync,
    required MediaPreviewSlideMetrics metrics,
    required bool Function() isMounted,
    required bool Function() isClosing,
    required VoidCallback popRoute,
    ScaleEndDetails? details,
    required Offset releaseOffset,
  }) {
    final startOffset = metrics.slideOffset.dy.abs() > 0.5
        ? metrics.slideOffset
        : releaseOffset;
    final startScale = metrics.contentScale.clamp(0.55, 1.0);
    final startContentOpacity = metrics.contentOpacity.clamp(0.5, 1.0);
    final startBackdrop = metrics.backdropOpacity.clamp(0.0, 1.0);

    final vy = details?.velocity.pixelsPerSecond.dy ?? 0;
    // 点击关闭（几乎无位移）少带惯性位移，避免小图空荡荡地往下飘。
    final fromRest = startOffset.dy.abs() < 8 && startScale > 0.92;
    final continueDy = fromRest
        ? 0.0
        : (vy > 120 ? vy * 0.08 : 48.0).clamp(24.0, 120.0);
    final endOffset = Offset(
      startOffset.dx,
      startOffset.dy + (startOffset.dy >= 0 ? continueDy : -continueDy),
    );
    // 统一收到 ~0.36：点击关闭也明显缩小，而不是只淡到 0.7。
    final endScale = mediaPreviewScaleFadeEndScale.clamp(0.01, startScale);

    final durationMs =
        (fromRest ? 170 : 155 + (1.0 - startScale) * 35).round().clamp(150, 200);
    _exitController?.dispose();
    final controller = AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: durationMs),
    );
    _exitController = controller;

    void onTick() {
      if (!isMounted()) {
        return;
      }
      final t = Curves.easeInCubic.transform(controller.value);
      metrics.applyExitFrame(
        scale: startScale + (endScale - startScale) * t,
        contentOpacity: startContentOpacity * (1.0 - t),
        backdropOpacity: startBackdrop * (1.0 - Curves.easeOut.transform(t)),
        slideOffset: Offset(
          startOffset.dx,
          startOffset.dy + (endOffset.dy - startOffset.dy) * t,
        ),
      );
    }

    // 立即推一帧，避免等待 vsync 造成停顿感。
    onTick();
    controller.addListener(onTick);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.removeListener(onTick);
        _exitController?.dispose();
        _exitController = null;
        _popNow(isClosing: isClosing, popRoute: popRoute);
      }
    });
    controller.forward(from: 0);
  }
}

void _interruptSlideSnapBack(
    GlobalKey<ExtendedImageSlidePageState> slidePageKey) {
  final slideState = slidePageKey.currentState;
  if (slideState == null) {
    return;
  }
  final controller = slideState.backAnimationController;
  if (controller.isAnimating) {
    controller.stop();
  }
}

/// 仅纵向拖拽关闭，不抢占横向翻页手势（图集视频用）。
///
/// 当传入 [metrics] 时走轻量跟手路径，避免 [ExtendedImageSlidePage.slide] 每帧 setState。
class MediaPreviewVerticalDismissLayer extends StatelessWidget {
  const MediaPreviewVerticalDismissLayer({
    super.key,
    this.slidePageKey,
    this.metrics,
    required this.child,
    this.onSlideStart,
    this.onSlideEnd,
    this.onSlideEndWithVelocity,
    this.onInterruptSnapBack,
    this.onQuickDismiss,
    this.quickDismissDistance = 0,
  }) : assert(
          slidePageKey != null || metrics != null,
          'slidePageKey or metrics is required',
        );

  final GlobalKey<ExtendedImageSlidePageState>? slidePageKey;
  final MediaPreviewSlideMetrics? metrics;
  final Widget child;
  final VoidCallback? onSlideStart;
  final VoidCallback? onSlideEnd;
  final MediaPreviewSlideEndCallback? onSlideEndWithVelocity;
  final VoidCallback? onInterruptSnapBack;
  final VoidCallback? onQuickDismiss;
  final double quickDismissDistance;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    var quickDismissTriggered = false;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        VerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
          VerticalDragGestureRecognizer.new,
          (VerticalDragGestureRecognizer instance) {
            instance.dragStartBehavior = DragStartBehavior.down;
            instance
              ..onStart = (_) {
                quickDismissTriggered = false;
                onInterruptSnapBack?.call();
                final slidePageKey = this.slidePageKey;
                if (slidePageKey != null) {
                  _interruptSlideSnapBack(slidePageKey);
                }
                onSlideStart?.call();
              }
              ..onUpdate = (details) {
                final delta = details.primaryDelta ?? details.delta.dy;
                if (delta == 0) {
                  return;
                }
                final metrics = this.metrics;
                if (metrics != null) {
                  metrics.applyVerticalDrag(delta, size);
                } else {
                  slidePageKey?.currentState?.slide(Offset(0, delta));
                }
                if (delta > 0 &&
                    onQuickDismiss != null &&
                    !quickDismissTriggered &&
                    quickDismissDistance <= 0) {
                  quickDismissTriggered = true;
                  onQuickDismiss?.call();
                }
              }
              ..onEnd = (details) {
                final metrics = this.metrics;
                if (metrics != null) {
                  onSlideEndWithVelocity?.call(details.velocity);
                } else {
                  slidePageKey?.currentState?.endSlide(
                    ScaleEndDetails(velocity: details.velocity),
                  );
                }
                onSlideEnd?.call();
              }
              ..onCancel = () {
                final metrics = this.metrics;
                if (metrics != null) {
                  onSlideEndWithVelocity?.call(Velocity.zero);
                } else {
                  slidePageKey?.currentState?.endSlide(ScaleEndDetails());
                }
                onSlideEnd?.call();
              };
          },
        ),
      },
      child: child,
    );
  }
}

enum _MediaPreviewPanAxis { vertical, horizontalEdge }

/// 统一 Pan 手势：锁定纵向下滑关闭，避免与横向边缘返回抢手势。
class MediaPreviewPanDismissLayer extends StatefulWidget {
  const MediaPreviewPanDismissLayer({
    super.key,
    required this.slidePageKey,
    required this.child,
    this.onSlideStart,
    this.onEdgeBack,
    this.onQuickVerticalDismiss,
    this.quickVerticalDismissDistance = 28,
  });

  final GlobalKey<ExtendedImageSlidePageState> slidePageKey;
  final Widget child;
  final VoidCallback? onSlideStart;
  final VoidCallback? onEdgeBack;
  final VoidCallback? onQuickVerticalDismiss;
  final double quickVerticalDismissDistance;

  @override
  State<MediaPreviewPanDismissLayer> createState() =>
      _MediaPreviewPanDismissLayerState();
}

class _MediaPreviewPanDismissLayerState
    extends State<MediaPreviewPanDismissLayer> {
  _MediaPreviewPanAxis? _axis;
  Offset _accumulated = Offset.zero;
  double _edgeDx = 0;
  bool _edgeCandidate = false;
  bool _quickVerticalDismissTriggered = false;

  static const double _axisLockDistance = 2;

  bool _isLeftEdge(Offset globalPosition) => globalPosition.dx <= 56;

  void _interruptSnapBackIfNeeded() {
    _interruptSlideSnapBack(widget.slidePageKey);
  }

  void _onPanStart(DragStartDetails details) {
    _axis = null;
    _accumulated = Offset.zero;
    _edgeDx = 0;
    _edgeCandidate = _isLeftEdge(details.globalPosition);
    _quickVerticalDismissTriggered = false;
    _interruptSnapBackIfNeeded();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _accumulated += details.delta;
    if (_axis == null) {
      if (_accumulated.distance < _axisLockDistance) {
        return;
      }
      if (_accumulated.dy.abs() >= _accumulated.dx.abs()) {
        _axis = _MediaPreviewPanAxis.vertical;
        widget.onSlideStart?.call();
        if (widget.onQuickVerticalDismiss != null &&
            widget.quickVerticalDismissDistance <= 0) {
          _quickVerticalDismissTriggered = true;
          widget.onQuickVerticalDismiss?.call();
          return;
        }
      } else if (_edgeCandidate && _accumulated.dx > 0) {
        _axis = _MediaPreviewPanAxis.horizontalEdge;
      } else {
        return;
      }
    }

    if (_axis == _MediaPreviewPanAxis.vertical) {
      final delta = details.delta.dy;
      if (delta != 0) {
        widget.slidePageKey.currentState?.slide(Offset(0, delta));
      }
      if (!_quickVerticalDismissTriggered &&
          widget.onQuickVerticalDismiss != null &&
          _accumulated.dy > widget.quickVerticalDismissDistance) {
        _quickVerticalDismissTriggered = true;
        widget.onQuickVerticalDismiss?.call();
      }
      return;
    }

    if (_axis == _MediaPreviewPanAxis.horizontalEdge) {
      _edgeDx += details.delta.dx;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    final axis = _axis;
    _axis = null;
    _accumulated = Offset.zero;
    _quickVerticalDismissTriggered = false;

    if (axis == _MediaPreviewPanAxis.vertical) {
      widget.slidePageKey.currentState?.endSlide(
        ScaleEndDetails(velocity: details.velocity),
      );
      return;
    }

    if (axis == _MediaPreviewPanAxis.horizontalEdge) {
      final vx = details.velocity.pixelsPerSecond.dx;
      if (_edgeDx > 72 || vx > 520) {
        widget.onEdgeBack?.call();
      }
      _edgeDx = 0;
    }
  }

  void _onPanCancel() {
    final axis = _axis;
    _axis = null;
    _accumulated = Offset.zero;
    _edgeDx = 0;
    if (axis == _MediaPreviewPanAxis.vertical) {
      widget.slidePageKey.currentState?.endSlide(ScaleEndDetails());
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
