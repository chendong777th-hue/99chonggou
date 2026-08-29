import 'dart:math' as math;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_gesture_physics.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_resolution_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/tall_image_gallery_scroll_gate.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/tall_image_gesture_diag.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_slide_metrics.dart';

/// 长图手势轴向：未判定 / 竖向浏览（含下滑关闭）/ 横向翻页。
enum TallImageGestureAxis {
  undecided,
  vertical,
  horizontal,
}

/// 根据累计位移判定长图手势轴向；未过 [slop] 前保持未判定。
///
/// [horizontalDominance] > 1 时需更明显的横滑才锁定翻页，避免长图竖滑被对角线抢走。
TallImageGestureAxis resolveTallImageGestureAxis({
  required Offset totalDelta,
  double slop = 8.0,
  double horizontalDominance = 1.15,
}) {
  if (totalDelta.distance < slop) {
    return TallImageGestureAxis.undecided;
  }
  if (totalDelta.dx.abs() > totalDelta.dy.abs() * horizontalDominance) {
    return TallImageGestureAxis.horizontal;
  }
  return TallImageGestureAxis.vertical;
}

/// 长图/超长图浏览：默认竖向，仅近乎纯横滑才判定为翻页。
TallImageGestureAxis resolveTallImageScrollAxis({
  required Offset totalDelta,
  double slop = 8.0,
  double horizontalDominance = 2.4,
  double maxVerticalForPageFlip = 18.0,
}) {
  if (totalDelta.distance < slop) {
    return TallImageGestureAxis.undecided;
  }
  if (totalDelta.dx.abs() > totalDelta.dy.abs() * horizontalDominance &&
      totalDelta.dy.abs() < maxVerticalForPageFlip) {
    return TallImageGestureAxis.horizontal;
  }
  return TallImageGestureAxis.vertical;
}

/// 放大后图集翻页：须贴边且近似纯横滑，避免斜向拖动误切图。
///
/// 放大时门槛刻意严于图内平移：图内用较低 dominance 锁横轴看左右，
/// 切图仍要求「贴边 + 更长行程 + 更纯横滑」。
bool tallImageShouldRouteGalleryPage({
  required Offset totalDelta,
  required bool atHorizontalEdge,
  double minHorizontalTravel = 14.0,
  double maxVerticalRatio = 0.45,
  bool zoomed = false,
}) {
  if (!atHorizontalEdge) {
    return false;
  }
  final minTravel = zoomed ? 48.0 : minHorizontalTravel;
  final maxVertical = zoomed ? 0.22 : maxVerticalRatio;
  final dominance = zoomed ? 3.6 : 2.2;
  final maxVerticalForFlip = zoomed ? 10.0 : 22.0;
  if (totalDelta.dx.abs() < minTravel) {
    return false;
  }
  if (totalDelta.dy.abs() >= totalDelta.dx.abs() * maxVertical) {
    return false;
  }
  return resolveTallImageScrollAxis(
        totalDelta: totalDelta,
        horizontalDominance: dominance,
        maxVerticalForPageFlip: maxVerticalForFlip,
      ) ==
      TallImageGestureAxis.horizontal;
}

/// 1x 长图竖向可滚区间：顶部 translation.y = 0，底部为负值。
double tallImageMinTranslationY({
  required double viewportHeight,
  required double contentHeight,
}) {
  if (contentHeight <= viewportHeight) {
    return 0;
  }
  return viewportHeight - contentHeight;
}

/// 将 1x 竖滑位移夹紧到可滚区间。
double clampTallImageTranslationY({
  required double currentY,
  required double deltaY,
  required double viewportHeight,
  required double contentHeight,
}) {
  final minY = tallImageMinTranslationY(
    viewportHeight: viewportHeight,
    contentHeight: contentHeight,
  );
  return (currentY + deltaY).clamp(minY, 0.0);
}

/// 长图全屏预览：1x 竖滑由本组件接管，放大后才交给 [InteractiveViewer]。
///
/// 规避两点冲突：
/// 1. extended_image 在 1x 下忽略 offset；
/// 2. InteractiveViewer 与轴向锁定抢同一串指针（竖滑 / 翻页 / 下滑关闭）。
///
/// 图集内通过指针轴向锁定分流：竖滑浏览 / 顶部下拉关闭 / 横滑驱动
/// [ExtendedImageGesturePageView] 翻页（不依赖手势竞技场胜负）。
/// 长图顶部下拉关闭：宿主须走 preserveSlideBackdrop 的正规关闭，禁止 resetBackdrop。
typedef TallImageSlideDismissCallback = void Function(
  Offset releaseOffset, {
  ScaleEndDetails? details,
});

class TallImageScrollPreview extends StatefulWidget {
  const TallImageScrollPreview({
    required this.extendedImageState,
    required this.maxScale,
    required this.doubleTapTarget,
    required this.slidePageKey,
    required this.slideMetrics,
    required this.displayMode,
    this.inPageView = false,
    this.onTap,
    this.onSlideDismiss,
    this.onDismissGestureStarted,
    this.galleryScrollGate,
    Key? key,
  }) : super(key: key);

  final ExtendedImageState extendedImageState;
  final double maxScale;
  final double doubleTapTarget;
  final GlobalKey<ExtendedImageSlidePageState> slidePageKey;
  final MediaPreviewSlideMetrics slideMetrics;
  final ImagePreviewDisplayMode displayMode;
  final bool inPageView;
  final VoidCallback? onTap;
  /// 达关闭阈值时回调；为 null 则只回弹不关闭。
  final TallImageSlideDismissCallback? onSlideDismiss;
  /// 开始顶部下拉/竖向关闭手势时回调（用于图集打断横滑）。
  final VoidCallback? onDismissGestureStarted;
  /// 同步缩放与贴边状态，供图集 [canScrollPage] 按微信规则放行横滑翻页。
  final ValueNotifier<TallImageGalleryScrollGate>? galleryScrollGate;

  @override
  State<TallImageScrollPreview> createState() => _TallImageScrollPreviewState();
}

class _TallImageScrollPreviewState extends State<TallImageScrollPreview>
    with TickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  final MediaPreviewSlideSnapController _metricsSnapController =
      MediaPreviewSlideSnapController();
  AnimationController? _zoomAnimationController;
  AnimationController? _rubberSnapController;
  Animation<double>? _rubberSnapAnimation;
  Animation<Matrix4>? _zoomAnimation;
  double _accumulatedPanDistance = 0;
  /// 顶部下拉本地位移；遮罩透明度经 [slideMetrics.applySnapFrame] 同步，关闭禁止 resetBackdrop。
  double _rubberDy = 0;
  bool _dismissCommitted = false;
  TallImageGestureAxis _gestureAxis = TallImageGestureAxis.undecided;
  bool _routingPage = false;
  bool _topPullActive = false;
  bool _loggedScrollThisGesture = false;
  bool _mountLogged = false;
  bool _didRoutePageThisGesture = false;
  bool _didRouteDismissThisGesture = false;
  bool _pageRouteBlockedThisGesture = false;
  bool _pointerDownSeen = false;
  bool _gestureStartedAtLeftEdge = true;
  bool _gestureStartedAtRightEdge = true;
  bool _showScrollToTop = false;
  /// 放大后贴边翻页的位移基准；从中间滑到贴边时会重置为贴边时刻的手指位置。
  Offset? _pageRouteBaseline;
  int _activePointerCount = 0;
  bool _pinchActive = false;
  Offset _pointerStart = Offset.zero;
  Matrix4? _matrixFrozenForPageRoute;
  VelocityTracker? _velocityTracker;
  ExtendedImageGesturePageViewState? _pageViewState;
  Size _childDisplaySize = Size.zero;
  ImagePreviewPanMomentumRunner? _panMomentumRunner;
  ImagePreviewSpringReboundRunner? _springReboundRunner;
  ImagePreviewPanAxisLock _zoomedPanAxisLock = ImagePreviewPanAxisLock.undecided;
  Offset _zoomedPanGestureTotal = Offset.zero;
  bool _matrixPanFromMomentum = false;

  static const double _topPullResistance = 0.42;

  ImagePreviewGestureProfile get _profile =>
      imagePreviewGestureProfileFor(widget.displayMode);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onMatrixChanged);
    _onMatrixChanged();
  }

  void _onMatrixChanged() {
    _syncGalleryScrollGate();
    _updateScrollToTopVisibility();
  }

  void _updateScrollToTopVisibility() {
    if (!mounted) {
      return;
    }
    final shouldShow = !_atScrollTop &&
        _childDisplaySize.height > 0 &&
        _childDisplaySize.height >
            MediaQuery.sizeOf(context).height * 1.2;
    if (shouldShow != _showScrollToTop) {
      _showScrollToTop = shouldShow;
    }
  }

  void _scrollToTop() {
    _panMomentumRunner?.stop();
    _springReboundRunner?.stop();
    final current = _currentTranslation();
    if (current.dy.abs() < 0.5) {
      return;
    }
    final bounds = _matrixPanBounds(scale: 1.0);
    final target = Offset(bounds.clamp(current).dx, 0.0);
    _ensureSpringReboundRunner().animate(
      from: current,
      to: target,
      onUpdate: _setTranslation,
    );
  }

  void _syncGalleryScrollGate() {
    final notifier = widget.galleryScrollGate;
    if (notifier == null) {
      return;
    }
    final scale = _controller.value.getMaxScaleOnAxis();
    if (_childDisplaySize == Size.zero) {
      notifier.value = TallImageGalleryScrollGate(
        scale: scale,
        atLeftEdge: true,
        atRightEdge: true,
        hasHorizontalScroll: false,
      );
      return;
    }
    final bounds = _matrixPanBounds(scale: scale);
    final hasH = imagePreviewBoundsAllowHorizontalScroll(bounds);
    final tx = _currentTranslation().dx;
    const slop = 3.0;
    final atLeft = !hasH || tx <= bounds.minX + slop;
    final atRight = !hasH || tx >= bounds.maxX - slop;
    notifier.value = TallImageGalleryScrollGate(
      scale: scale,
      atLeftEdge: atLeft,
      atRightEdge: atRight,
      hasHorizontalScroll: hasH,
    );
    TallImageGestureDiag.gateSync(
      scale: scale,
      tx: tx,
      minX: bounds.minX,
      maxX: bounds.maxX,
      atLeftEdge: atLeft,
      atRightEdge: atRight,
      hasHorizontalScroll: hasH,
    );
  }

  ({double tx, double ty, ImagePreviewPanTranslationBounds bounds, bool hasH, bool hasV})
      _panDiagnostics() {
    final scale = _controller.value.getMaxScaleOnAxis();
    final translation = _currentTranslation();
    if (_childDisplaySize == Size.zero) {
      return (
        tx: translation.dx,
        ty: translation.dy,
        bounds: const ImagePreviewPanTranslationBounds(
          minX: 0,
          maxX: 0,
          minY: 0,
          maxY: 0,
        ),
        hasH: false,
        hasV: false,
      );
    }
    final bounds = _matrixPanBounds(scale: scale);
    return (
      tx: translation.dx,
      ty: translation.dy,
      bounds: bounds,
      hasH: imagePreviewBoundsAllowHorizontalScroll(bounds),
      hasV: imagePreviewBoundsAllowVerticalScroll(bounds),
    );
  }

  TallImageGalleryScrollGate? get _currentGalleryGate =>
      widget.galleryScrollGate?.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageViewState = widget.inPageView
        ? context.findAncestorStateOfType<ExtendedImageGesturePageViewState>()
        : null;
  }

  @override
  void didUpdateWidget(TallImageScrollPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inPageView != widget.inPageView) {
      _pageViewState = widget.inPageView
          ? context.findAncestorStateOfType<ExtendedImageGesturePageViewState>()
          : null;
    }
  }

  @override
  void dispose() {
    if (_routingPage) {
      _endPageRoute(cancelled: true);
    }
    _controller.removeListener(_onMatrixChanged);
    widget.galleryScrollGate?.value = TallImageGalleryScrollGate.initial;
    _detachDismissMetricsListener();
    _panMomentumRunner?.stop();
    _springReboundRunner?.stop();
    _metricsSnapController.dispose();
    _rubberSnapController?.dispose();
    _zoomAnimationController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _syncDismissVisualFromMetrics() {
    if (!mounted) {
      return;
    }
    // 离场动画会改 contentScale；即使位移不变也要重建以跟上缩放。
    if (_dismissCommitted) {
      final dy = widget.slideMetrics.slideOffset.dy;
      if ((dy - _rubberDy).abs() >= 0.5) {
        setState(() => _rubberDy = dy);
        return;
      }
    }
    if ((widget.slideMetrics.contentScale - 1.0).abs() > 0.001 ||
        _dismissCommitted) {
      setState(() {});
    }
  }

  void _attachDismissMetricsListener() {
    widget.slideMetrics.removeListener(_syncDismissVisualFromMetrics);
    widget.slideMetrics.addListener(_syncDismissVisualFromMetrics);
  }

  void _detachDismissMetricsListener() {
    widget.slideMetrics.removeListener(_syncDismissVisualFromMetrics);
  }

  bool get _nearMinScale =>
      _controller.value.getMaxScaleOnAxis() <= 1.05;

  bool get _isTallScrollMode =>
      widget.displayMode == ImagePreviewDisplayMode.tall ||
      widget.displayMode == ImagePreviewDisplayMode.extraTall;

  /// 1x 长图只响应纵向位移，避免斜滑带横向漂移再回弹。
  Offset _deltaForTallScroll(Offset delta, {required bool zoomed}) {
    if (!zoomed && _isTallScrollMode) {
      return Offset(0, delta.dy);
    }
    return delta;
  }

  bool get _atScrollTop {
    final matrix = _controller.value;
    return matrix.getMaxScaleOnAxis() <= 1.05 &&
        matrix.getTranslation().y >= -0.5;
  }

  bool get _canStartTopPull => _nearMinScale && _atScrollTop;

  /// 放大后平移由指针手动驱动（阻尼 + 边缘阻力 + 惯性 + 弹簧回弹）。
  ImagePreviewPanMomentumRunner _ensurePanMomentumRunner() {
    final profile = _profile;
    return _panMomentumRunner ??= ImagePreviewPanMomentumRunner(
      vsync: this,
      minVelocity: profile.inertialMinVelocity,
      decayPerFrame: profile.inertialDecayPerFrame,
      onDelta: (delta) {
        final before = _currentTranslation();
        _matrixPanFromMomentum = true;
        _applyMatrixPanDelta(
          _deltaForTallScroll(delta, zoomed: !_nearMinScale),
          zoomed: !_nearMinScale,
        );
        _matrixPanFromMomentum = false;
        final after = _currentTranslation();
        // 贴边吸收剩余惯性，避免空转后再弹簧回弹。
        if ((after - before).distance < 0.5 && delta.distance > 0.5) {
          _panMomentumRunner?.stop();
        }
      },
      onEnd: () {
        _matrixPanFromMomentum = false;
        _springReboundMatrix();
      },
    );
  }

  ImagePreviewSpringReboundRunner _ensureSpringReboundRunner() {
    return _springReboundRunner ??= ImagePreviewSpringReboundRunner(vsync: this);
  }

  Offset _currentTranslation() {
    final t = _controller.value.getTranslation();
    return Offset(t.x, t.y);
  }

  void _setTranslation(Offset translation) {
    final matrix = Matrix4.copy(_controller.value);
    final t = matrix.getTranslation();
    matrix.setTranslationRaw(translation.dx, translation.dy, t.z);
    _controller.value = matrix;
  }

  ImagePreviewPanTranslationBounds _matrixPanBounds({double? scale}) {
    if (!mounted) {
      return const ImagePreviewPanTranslationBounds(
        minX: 0,
        maxX: 0,
        minY: 0,
        maxY: 0,
      );
    }
    final viewSize = MediaQuery.sizeOf(context);
    final s = scale ?? _controller.value.getMaxScaleOnAxis();
    return imagePreviewMatrixPanBounds(
      viewport: viewSize,
      content: _childDisplaySize,
      scale: s,
      topAligned: true,
    );
  }

  void _applyMatrixPanDelta(Offset delta, {required bool zoomed}) {
    if (_childDisplaySize == Size.zero || delta == Offset.zero) {
      return;
    }
    if (zoomed) {
      _applyZoomedMatrixPan(delta);
      return;
    }
    var working = _deltaForTallScroll(delta, zoomed: false);
    final viewSize = MediaQuery.sizeOf(context);
    final scale = _controller.value.getMaxScaleOnAxis();
    final bounds = _matrixPanBounds(scale: scale);
    final current = _currentTranslation();
    final damped = imagePreviewDampedPanDelta(
      delta: working,
      translation: current,
      bounds: bounds,
      viewport: viewSize,
      panDamping: imagePreviewPanSpeed,
    );
    // 1x 浏览贴边硬夹：禁止大幅越界再慢回弹；顶部下拉关闭走 _applyTopPull。
    if (_isTallScrollMode) {
      final anchoredX = bounds.clamp(current).dx;
      final nextY = (current.dy + damped.dy).clamp(bounds.minY, bounds.maxY);
      _setTranslation(Offset(anchoredX, nextY));
      return;
    }
    _setTranslation(bounds.clamp(current + damped));
  }

  /// 放大后通过矩阵平移（与 InteractiveViewer 缩放矩阵兼容）。
  void _applyZoomedMatrixPan(Offset delta) {
    final viewSize = MediaQuery.sizeOf(context);
    final bounds = _matrixPanBounds();
    var working = delta;
    final scrollH = imagePreviewBoundsAllowHorizontalScroll(bounds);
    final scrollV = imagePreviewBoundsAllowVerticalScroll(bounds);
    if (scrollH && scrollV && _isTallScrollMode) {
      _zoomedPanGestureTotal += working;
      _zoomedPanAxisLock = imagePreviewLockPanAxisForGesture(
        current: _zoomedPanAxisLock,
        gestureTotalDelta: _zoomedPanGestureTotal,
        // 放大后图内平移用更低门槛锁横轴；切图门槛见 tallImageShouldRouteGalleryPage。
        dominance: imagePreviewTallZoomPanAxisDominance,
      );
      if (_zoomedPanAxisLock != ImagePreviewPanAxisLock.undecided) {
        working = imagePreviewApplyPanAxisLock(working, _zoomedPanAxisLock);
      }
    } else if (scrollH && scrollV) {
      _zoomedPanAxisLock = ImagePreviewPanAxisLock.free;
    } else {
      var lock = imagePreviewResolvePanAxisLock(bounds: bounds);
      if (lock == ImagePreviewPanAxisLock.undecided) {
        _zoomedPanGestureTotal += working;
        lock = imagePreviewLockPanAxisForGesture(
          current: _zoomedPanAxisLock,
          gestureTotalDelta: _zoomedPanGestureTotal,
        );
      }
      _zoomedPanAxisLock = lock;
      working = imagePreviewApplyPanAxisLock(working, lock);
    }
    final before = _currentTranslation();
    final damped = imagePreviewDampedPanDelta(
      delta: working,
      translation: before,
      bounds: bounds,
      viewport: viewSize,
      panDamping: imagePreviewZoomPanDamping(
        tallScrollMode: _isTallScrollMode,
        fromMomentum: _matrixPanFromMomentum,
        profile: _profile,
      ),
    );
    if (damped == Offset.zero) {
      if (!_loggedScrollThisGesture) {
        _loggedScrollThisGesture = true;
        TallImageGestureDiag.zoomPanFirst(
          fromX: before.dx,
          fromY: before.dy,
          toX: before.dx,
          toY: before.dy,
          scale: _controller.value.getMaxScaleOnAxis(),
          axisLock: _zoomedPanAxisLock.name,
          dampedZero: true,
        );
      }
      return;
    }
    final scale = _controller.value.getMaxScaleOnAxis();
    // 放大后贴边即停（无越界回弹）；中间区域仍 1:1 跟手。
    final next = _matrixPanBounds(scale: scale).clamp(before + damped);
    _setTranslation(next);
    if (!_loggedScrollThisGesture) {
      final after = _currentTranslation();
      if ((after - before).distance > 0.5) {
        _loggedScrollThisGesture = true;
        TallImageGestureDiag.zoomPanFirst(
          fromX: before.dx,
          fromY: before.dy,
          toX: after.dx,
          toY: after.dy,
          scale: scale,
          axisLock: _zoomedPanAxisLock.name,
        );
      }
    }
  }

  void _applyZoomedPan(Offset delta) {
    _applyMatrixPanDelta(delta, zoomed: true);
  }

  void _springReboundMatrix() {
    if (_childDisplaySize == Size.zero || !mounted) {
      return;
    }
    final bounds = _matrixPanBounds();
    final current = _currentTranslation();
    if (_nearMinScale && _isTallScrollMode) {
      final targetY = bounds.clamp(current).dy;
      if ((current.dy - targetY).abs() < 0.5) {
        return;
      }
      _ensureSpringReboundRunner().animate(
        from: current,
        to: Offset(bounds.clamp(current).dx, targetY),
        onUpdate: _setTranslation,
      );
      return;
    }
    final target = bounds.clamp(current);
    if ((current - target).distance < 0.5) {
      return;
    }
    _ensureSpringReboundRunner().animate(
      from: current,
      to: target,
      onUpdate: _setTranslation,
    );
  }

  void _finishMatrixPan() {
    final velocity =
        _velocityTracker?.getVelocity().pixelsPerSecond ?? Offset.zero;
    final zoomed = !_nearMinScale;
    final scaled = imagePreviewMomentumStartVelocity(
      velocityPixelsPerSecond: velocity,
      zoomed: zoomed,
      tallScrollMode: _isTallScrollMode,
      profile: _profile,
      bounds: _matrixPanBounds(),
      translation: _currentTranslation(),
    );
    if (zoomed && _isTallScrollMode) {
      // 不强制竖轴：保留本轮横/纵锁状态影响已结束，下一轮 pointerDown 再重置。
      _zoomedPanAxisLock = ImagePreviewPanAxisLock.undecided;
      _zoomedPanGestureTotal = Offset.zero;
    }
    _springReboundRunner?.stop();
    final runner = _ensurePanMomentumRunner();
    runner.start(scaled);
    TallImageGestureDiag.log(
      'inertia_start',
      extras: <String, Object?>{
        'running': runner.isRunning,
        'vx': scaled.dx.toStringAsFixed(1),
        'vy': scaled.dy.toStringAsFixed(1),
        'zoomed': zoomed,
      },
    );
    if (!runner.isRunning) {
      _springReboundMatrix();
    }
  }

  void _clearRubberBand({bool animate = false}) {
    _rubberSnapController?.stop();
    _rubberSnapController?.dispose();
    _rubberSnapController = null;
    _rubberSnapAnimation = null;
    if (!animate || _rubberDy.abs() < 1) {
      if (_rubberDy != 0 && mounted) {
        setState(() => _rubberDy = 0);
      } else {
        _rubberDy = 0;
      }
      _topPullActive = false;
      return;
    }
    final begin = _rubberDy;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _rubberSnapController = controller;
    _rubberSnapAnimation = Tween<double>(begin: begin, end: 0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        if (!mounted || _rubberSnapAnimation == null) {
          return;
        }
        setState(() => _rubberDy = _rubberSnapAnimation!.value);
      });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _rubberDy = 0;
        _topPullActive = false;
        _rubberSnapController?.dispose();
        _rubberSnapController = null;
        _rubberSnapAnimation = null;
        TallImageGestureDiag.dismissEnd();
        if (mounted) {
          setState(() {});
        }
      }
    });
    controller.forward();
  }

  bool _atZoomedHorizontalEdge(double dx) {
    if (_nearMinScale) {
      return true;
    }
    if (_childDisplaySize == Size.zero) {
      return false;
    }
    final bounds = _matrixPanBounds();
    final hasH = imagePreviewBoundsAllowHorizontalScroll(bounds);
    final tx = _currentTranslation().dx;
    final atEdge = tallImageAtHorizontalPanEdge(
      translationX: tx,
      minX: bounds.minX,
      maxX: bounds.maxX,
      hasHorizontalScroll: hasH,
      dragDx: dx,
    );
    return atEdge;
  }

  void _syncGestureEdgeSnapshot() {
    if (_nearMinScale || _childDisplaySize == Size.zero) {
      _gestureStartedAtLeftEdge = true;
      _gestureStartedAtRightEdge = true;
      return;
    }
    final bounds = _matrixPanBounds();
    final hasH = imagePreviewBoundsAllowHorizontalScroll(bounds);
    final tx = _currentTranslation().dx;
    const slop = 3.0;
    _gestureStartedAtLeftEdge = !hasH || tx <= bounds.minX + slop;
    _gestureStartedAtRightEdge = !hasH || tx >= bounds.maxX - slop;
  }

  void _armPageRouteBaselineIfNeeded(Offset pointerPosition, double travelDx) {
    if (_nearMinScale || _pageRouteBaseline != null) {
      return;
    }
    if (_gestureStartedAtLeftEdge || _gestureStartedAtRightEdge) {
      _pageRouteBaseline = _pointerStart;
      return;
    }
    if (_atZoomedHorizontalEdge(travelDx)) {
      _pageRouteBaseline = pointerPosition;
      TallImageGestureDiag.log(
        'page_route_arm',
        extras: <String, Object?>{
          'tx': _currentTranslation().dx.toStringAsFixed(1),
          'travelDx': travelDx.toStringAsFixed(1),
        },
      );
    }
  }

  Offset _pageRouteDelta(Offset pointerPosition) {
    final baseline = _pageRouteBaseline ?? _pointerStart;
    return pointerPosition - baseline;
  }

  bool _canRoutePageForDelta(double dx) {
    if (!widget.inPageView ||
        _pageViewState == null ||
        _topPullActive) {
      return false;
    }
    if (_nearMinScale) {
      return true;
    }
    return _atZoomedHorizontalEdge(dx);
  }

  ({bool allow, String reason}) _evaluatePageRoute(Offset totalDelta) {
    if (_pageRouteBlockedThisGesture) {
      return (allow: false, reason: 'blocked_this_gesture');
    }
    if (!widget.inPageView || _pageViewState == null) {
      return (allow: false, reason: 'no_page_view');
    }
    if (_topPullActive) {
      return (allow: false, reason: 'top_pull_active');
    }
    final canRouteDx = _canRoutePageForDelta(totalDelta.dx);
    if (!canRouteDx) {
      if (!_nearMinScale) {
        final diag = _panDiagnostics();
        final dragDx = totalDelta.dx;
        final edgeSide = dragDx < 0
            ? 'need_left_edge'
            : dragDx > 0
                ? 'need_right_edge'
                : 'zero_dx';
        return (
          allow: false,
          reason:
              'zoomed_not_at_edge($edgeSide tx=${diag.tx.toStringAsFixed(1)} armed=${_pageRouteBaseline != null})',
        );
      }
      return (allow: false, reason: 'cannot_route_for_delta');
    }
    final atEdge = _nearMinScale
        ? true
        : _atZoomedHorizontalEdge(totalDelta.dx);
    if (_nearMinScale && _isTallScrollMode) {
      // 轴向刚锁成横滑时行程常 < minTravel；先等待凑够行程，勿立刻改竖向。
      if (totalDelta.dx.abs() < kMediaPreviewPageDragSlop &&
          totalDelta.dx.abs() >= totalDelta.dy.abs() * 1.5) {
        return (allow: false, reason: '1x_tall_wait_travel');
      }
      if (tallImageShouldRouteGalleryPage(
        totalDelta: totalDelta,
        atHorizontalEdge: true,
      )) {
        return (allow: true, reason: 'ok_1x_tall_pure_horizontal');
      }
      return (allow: false, reason: '1x_tall_not_pure_horizontal');
    }
    if (!_nearMinScale) {
      if (tallImageShouldRouteGalleryPage(
        totalDelta: totalDelta,
        atHorizontalEdge: atEdge,
        zoomed: true,
      )) {
        return (allow: true, reason: 'ok_zoomed_edge_pure_horizontal');
      }
      return (allow: false, reason: 'zoomed_not_pure_horizontal');
    }
    if (totalDelta.dx.abs() >= kMediaPreviewPageDragSlop &&
        resolveTallImageGestureAxis(totalDelta: totalDelta) ==
            TallImageGestureAxis.horizontal) {
      return (allow: true, reason: 'ok_1x_horizontal');
    }
    return (allow: false, reason: '1x_not_horizontal_enough');
  }

  bool _shouldBeginGalleryPageRoute(Offset totalDelta) {
    final decision = _evaluatePageRoute(totalDelta);
    TallImageGestureDiag.pageRouteProbe(
      allow: decision.allow,
      reason: decision.reason,
      totalDx: totalDelta.dx,
      totalDy: totalDelta.dy,
      nearMinScale: _nearMinScale,
      atHorizontalEdge: _nearMinScale
          ? true
          : _atZoomedHorizontalEdge(totalDelta.dx),
      canRouteForDelta: _canRoutePageForDelta(totalDelta.dx),
      pageRouteBlocked: _pageRouteBlockedThisGesture,
      zoomed: !_nearMinScale,
    );
    return decision.allow;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointerDownSeen = true;
    _activePointerCount++;
    if (_activePointerCount >= 2) {
      _pinchActive = true;
      _endPageRoute(cancelled: true);
      return;
    }
    _clearRubberBand();
    _panMomentumRunner?.stop();
    _springReboundRunner?.stop();
    _zoomedPanAxisLock = ImagePreviewPanAxisLock.undecided;
    _zoomedPanGestureTotal = Offset.zero;
    _accumulatedPanDistance = 0;
    _loggedScrollThisGesture = false;
    _topPullActive = false;
    _didRoutePageThisGesture = false;
    _didRouteDismissThisGesture = false;
    _pageRouteBlockedThisGesture = false;
    _gestureAxis = TallImageGestureAxis.undecided;
    _routingPage = false;
    _matrixFrozenForPageRoute = null;
    _pageRouteBaseline = null;
    _pointerStart = event.position;
    _syncGestureEdgeSnapshot();
    if (!_nearMinScale &&
        (_gestureStartedAtLeftEdge || _gestureStartedAtRightEdge)) {
      _pageRouteBaseline = event.position;
    }
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _zoomAnimationController?.stop();
    final diag = _panDiagnostics();
    final gate = _currentGalleryGate;
    TallImageGestureDiag.pointerDown(
      nearMinScale: _nearMinScale,
      atTop: _atScrollTop,
      scale: _controller.value.getMaxScaleOnAxis(),
      inPageView: widget.inPageView,
      tx: diag.tx,
      ty: diag.ty,
      boundsMinX: diag.bounds.minX,
      boundsMaxX: diag.bounds.maxX,
      boundsMinY: diag.bounds.minY,
      boundsMaxY: diag.bounds.maxY,
      hasHorizontalScroll: diag.hasH,
      hasVerticalScroll: diag.hasV,
      gateAtLeft: gate?.atLeftEdge,
      gateAtRight: gate?.atRightEdge,
    );
    if (!_nearMinScale) {
      TallImageGestureDiag.log(
        'edge_at_down',
        extras: <String, Object?>{
          'startLeft': _gestureStartedAtLeftEdge,
          'startRight': _gestureStartedAtRightEdge,
          'tx': diag.tx.toStringAsFixed(1),
        },
      );
    }
  }

  void _logPointerUpSnapshot({
    required String axis,
    required bool routedPage,
    required bool routedDismiss,
    required double panDist,
  }) {
    final diag = _panDiagnostics();
    final gate = _currentGalleryGate;
    TallImageGestureDiag.pointerUp(
      axis: axis,
      routedPage: routedPage,
      routedDismiss: routedDismiss,
      panDist: panDist,
      scale: _controller.value.getMaxScaleOnAxis(),
      tx: diag.tx,
      ty: diag.ty,
      gateAtLeft: gate?.atLeftEdge,
      gateAtRight: gate?.atRightEdge,
    );
  }

  void _beginPageRoute(PointerEvent event) {
    final pageView = _pageViewState;
    if (pageView == null || _routingPage) {
      return;
    }
    _routingPage = true;
    _didRoutePageThisGesture = true;
    _matrixFrozenForPageRoute = Matrix4.copy(_controller.value);
    final total = _pageRouteDelta(event.position);
    final diag = _panDiagnostics();
    TallImageGestureDiag.pageBegin(
      scale: _controller.value.getMaxScaleOnAxis(),
      totalDx: total.dx,
      totalDy: total.dy,
      atEdge: _nearMinScale
          ? true
          : _atZoomedHorizontalEdge(total.dx),
      tx: diag.tx,
      minX: diag.bounds.minX,
      maxX: diag.bounds.maxX,
      trigger: _nearMinScale ? '1x' : 'zoomed',
    );
    if (mounted) {
      setState(() {});
    }
    pageView.onDragDown(DragDownDetails(globalPosition: event.position));
    pageView.onDragStart(DragStartDetails(globalPosition: event.position));
  }

  void _updatePageRoute(PointerEvent event, Offset delta) {
    final pageView = _pageViewState;
    if (pageView == null) {
      return;
    }
    final frozen = _matrixFrozenForPageRoute;
    if (frozen != null && _controller.value != frozen) {
      _controller.value = frozen;
    }
    pageView.onDragUpdate(DragUpdateDetails(
      globalPosition: event.position,
      delta: Offset(delta.dx, 0),
      primaryDelta: delta.dx,
    ));
  }

  void _endPageRoute({required bool cancelled}) {
    final pageView = _pageViewState;
    if (!_routingPage || pageView == null) {
      _routingPage = false;
      _matrixFrozenForPageRoute = null;
      return;
    }
    if (cancelled) {
      pageView.onDragCancel();
    } else {
      final velocity =
          _velocityTracker?.getVelocity() ?? Velocity.zero;
      pageView.onDragEnd(DragEndDetails(
        velocity: velocity,
        primaryVelocity: velocity.pixelsPerSecond.dx,
      ));
    }
    TallImageGestureDiag.pageEnd(cancelled: cancelled);
    _routingPage = false;
    _matrixFrozenForPageRoute = null;
    if (mounted) {
      setState(() {});
    }
  }

  void _applyVerticalScroll(double dy) {
    if (_childDisplaySize == Size.zero) {
      return;
    }
    final viewH = MediaQuery.sizeOf(context).height;
    final contentH = _childDisplaySize.height;
    if (contentH <= 0) {
      return;
    }
    final current = _controller.value.getTranslation().y;
    _applyMatrixPanDelta(Offset(0, dy), zoomed: false);
    final next = _controller.value.getTranslation().y;
    if ((next - current).abs() < 0.01) {
      return;
    }
    final minY = tallImageMinTranslationY(
      viewportHeight: viewH,
      contentHeight: contentH,
    );
    if (!_loggedScrollThisGesture) {
      _loggedScrollThisGesture = true;
      TallImageGestureDiag.scrollVerticalFirst(
        fromY: current,
        toY: next,
        hitTop: next >= -0.5,
        hitBottom: next <= minY + 0.5,
      );
    }
  }

  void _startVerticalFling() {
    _finishMatrixPan();
  }

  /// 顶部下拉：本地位移 + 同步遮罩透明度；关闭走 [onSlideDismiss]，禁止裸 resetBackdrop。
  void _applyTopPull(double dy) {
    if (_dismissCommitted) {
      return;
    }
    _metricsSnapController.interrupt();
    if (!_topPullActive) {
      _topPullActive = true;
      _didRouteDismissThisGesture = true;
      if (_routingPage) {
        TallImageGestureDiag.log(
          'page_route_cancel',
          extras: <String, Object?>{'reason': 'top_pull'},
        );
        _endPageRoute(cancelled: true);
      }
      widget.onDismissGestureStarted?.call();
      TallImageGestureDiag.log(
        'rubber_band_start',
        extras: <String, Object?>{'dy': dy.toStringAsFixed(1)},
      );
    }
    final size = MediaQuery.sizeOf(context);
    final maxPull = size.height * 0.38;
    final appliedDy = dy > 0 ? dy * _topPullResistance : dy;
    final next = _rubberDy + appliedDy;
    if (next <= 0) {
      _rubberDy = 0;
      _topPullActive = false;
      widget.slideMetrics.resetBackdrop();
      if (mounted) {
        setState(() {});
      }
      if (next < 0) {
        _applyVerticalScroll(next);
      }
      return;
    }
    _rubberDy = next.clamp(0.0, maxPull);
    // 只改透明度/位移状态，供 scrim 跟手；图片位移仍用本地 Transform。
    widget.slideMetrics.applySnapFrame(Offset(0, _rubberDy), size);
    if (mounted) {
      setState(() {});
    }
  }

  void _finishTopPull({required bool cancelled}) {
    if (_dismissCommitted) {
      return;
    }
    if (_rubberDy <= 0.5) {
      _clearRubberBand();
      widget.slideMetrics.resetBackdrop();
      return;
    }
    final pull = _rubberDy;
    final vy = _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    final release = Offset(0, pull);
    // 长图顶部下拉不用「12px + 极速」那档：横滑被误改成竖向时容易带着高速
    // 误触关闭并闪一下。要求更明确的下拉行程。
    final shouldDismiss = !cancelled &&
        widget.onSlideDismiss != null &&
        (pull > 96 || (pull > 48 && vy > 360));
    if (shouldDismiss) {
      _dismissCommitted = true;
      _metricsSnapController.interrupt();
      TallImageGestureDiag.dismissBegin(pullPx: pull);
      final size = MediaQuery.sizeOf(context);
      widget.slideMetrics.applySnapFrame(release, size);
      // 跟 metrics 惯性帧，图片与遮罩一起滑出（对齐普通图手感）。
      _attachDismissMetricsListener();
      // 宿主 startMetricsMomentumDismiss：preserve 遮罩 + 惯性 + pop。
      widget.onSlideDismiss!(
        release,
        details: ScaleEndDetails(
          velocity: Velocity(pixelsPerSecond: Offset(0, vy)),
        ),
      );
      // dismiss_end 表示已提交关闭回调；真正 pop 由宿主惯性动画结束触发。
      TallImageGestureDiag.dismissEnd();
      return;
    }
    TallImageGestureDiag.log(
      'snap_back',
      extras: <String, Object?>{'dy': pull.toStringAsFixed(1)},
    );
    final size = MediaQuery.sizeOf(context);
    _metricsSnapController.snapBack(
      vsync: this,
      metrics: widget.slideMetrics,
      size: size,
      onComplete: TallImageGestureDiag.dismissEnd,
    );
    _clearRubberBand(animate: pull >= 20 && !cancelled);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!mounted || !_pointerDownSeen) {
      return;
    }
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    _accumulatedPanDistance += event.delta.distance;

    // 多指捏合交给 InteractiveViewer，避免与手动平移抢矩阵。
    if (_pinchActive || _activePointerCount > 1) {
      return;
    }

    // 放大后：中间只平移；滑到贴边后继续纯横滑才翻页（贴边后重置翻页基准）。
    if (!_nearMinScale) {
      if (_routingPage) {
        if (event.delta.dy.abs() > event.delta.dx.abs() * 1.15) {
          TallImageGestureDiag.pageCancel(reason: 'vertical_dominates_while_routing');
          _endPageRoute(cancelled: true);
          _pageRouteBlockedThisGesture = true;
          _applyZoomedPan(event.delta);
          return;
        }
        _updatePageRoute(event, event.delta);
        return;
      }
      final travelDx = (event.position - _pointerStart).dx;
      _armPageRouteBaselineIfNeeded(event.position, travelDx);
      if (_pageRouteBaseline != null) {
        final routeDelta = _pageRouteDelta(event.position);
        if (_shouldBeginGalleryPageRoute(routeDelta)) {
          _beginPageRoute(event);
          _updatePageRoute(event, event.delta);
          return;
        }
      }
      _applyZoomedPan(event.delta);
      _armPageRouteBaselineIfNeeded(event.position, travelDx);
      return;
    }

    if (_gestureAxis == TallImageGestureAxis.undecided) {
      final nextAxis = _isTallScrollMode
          ? resolveTallImageScrollAxis(
              totalDelta: event.position - _pointerStart,
            )
          : resolveTallImageGestureAxis(
              totalDelta: event.position - _pointerStart,
            );
      if (nextAxis == TallImageGestureAxis.undecided) {
        return;
      }
      _gestureAxis = nextAxis;
      final total = event.position - _pointerStart;
      TallImageGestureDiag.axisLock(
        axis: nextAxis.name,
        dx: total.dx,
        dy: total.dy,
        nearMinScale: _nearMinScale,
        atTop: _atScrollTop,
      );
      // 竖轴锁定后立即取消已开始的横滑翻页，避免回弹关闭时顺带跳页。
      if (nextAxis == TallImageGestureAxis.vertical && _routingPage) {
        TallImageGestureDiag.log(
          'page_route_cancel',
          extras: <String, Object?>{'reason': 'axis_vertical'},
        );
        _endPageRoute(cancelled: true);
        widget.onDismissGestureStarted?.call();
      }
    }

    if (_gestureAxis == TallImageGestureAxis.horizontal) {
      // 一旦已经把横滑交给 PageView，本趟手势必须锁死横向，直到松手。
      // 否则斜向微抖会被判成 not_pure_horizontal，取消翻页并钉回当前页，
      // 表现为「第 3 页滑不回第 4 页视频」。
      if (_routingPage) {
        _updatePageRoute(event, event.delta);
        return;
      }
      final total = event.position - _pointerStart;
      final decision = _evaluatePageRoute(total);
      TallImageGestureDiag.pageRouteProbe(
        allow: decision.allow,
        reason: decision.reason,
        totalDx: total.dx,
        totalDy: total.dy,
        nearMinScale: _nearMinScale,
        atHorizontalEdge: true,
        canRouteForDelta: _canRoutePageForDelta(total.dx),
        pageRouteBlocked: _pageRouteBlockedThisGesture,
        zoomed: !_nearMinScale,
      );
      if (!decision.allow) {
        if (_isTallScrollMode) {
          // 行程不够、或横滑仍占优但暂不够“纯”：继续等，勿立刻改竖向。
          if (decision.reason == '1x_tall_wait_travel' ||
              decision.reason == '1x_tall_not_pure_horizontal') {
            return;
          }
          TallImageGestureDiag.pageRouteReject(
              reason: '1x_horizontal_fallback_vertical');
          _gestureAxis = TallImageGestureAxis.vertical;
          _applyVerticalScroll(event.delta.dy);
        }
        return;
      }
      _beginPageRoute(event);
      _updatePageRoute(event, event.delta);
      return;
    }

    if (_gestureAxis != TallImageGestureAxis.vertical) {
      return;
    }

    final dy = event.delta.dy;
    if (_topPullActive) {
      _applyTopPull(dy);
      return;
    }
    if (_canStartTopPull && dy > 0) {
      _applyTopPull(dy);
      return;
    }
    _applyVerticalScroll(dy);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointerCount <= 0) {
      return;
    }
    final wasPinching = _pinchActive;
    _activePointerCount = math.max(0, _activePointerCount - 1);
    if (_activePointerCount == 0) {
      _pinchActive = false;
      _pointerDownSeen = false;
    }
    _velocityTracker?.addPosition(event.timeStamp, event.position);

    final axisName = _gestureAxis.name;
    final panDist = _accumulatedPanDistance;
    final routedPage = _didRoutePageThisGesture;
    final routedDismiss = _didRouteDismissThisGesture;

    if (_routingPage) {
      final isTap = _accumulatedPanDistance < kMediaPreviewTapMaxDistance &&
          (_velocityTracker?.getVelocity().pixelsPerSecond.distance ?? 0) <
              kMediaPreviewTapMaxVelocity;
      _endPageRoute(cancelled: isTap);
      if (isTap && _nearMinScale) {
        TallImageGestureDiag.tap();
        widget.onTap?.call();
      }
      _logPointerUpSnapshot(
        axis: axisName,
        routedPage: routedPage && !isTap,
        routedDismiss: routedDismiss,
        panDist: panDist,
      );
      return;
    }

    if (_topPullActive || _rubberDy > 0.5) {
      _finishTopPull(cancelled: false);
      _logPointerUpSnapshot(
        axis: axisName,
        routedPage: routedPage,
        routedDismiss: routedDismiss,
        panDist: panDist,
      );
      return;
    }

    if (wasPinching) {
      _finishPinchScale(focalPoint: event.position);
    } else if (_nearMinScale &&
        !_topPullActive &&
        _gestureAxis == TallImageGestureAxis.vertical &&
        _rubberDy <= 0.5) {
      _startVerticalFling();
    } else if (!_nearMinScale && !_routingPage && !_topPullActive) {
      _finishMatrixPan();
    }

    if (_accumulatedPanDistance < 18 && _nearMinScale) {
      TallImageGestureDiag.tap();
      widget.onTap?.call();
    }
    _logPointerUpSnapshot(
      axis: axisName,
      routedPage: routedPage,
      routedDismiss: routedDismiss,
      panDist: panDist,
    );
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointerCount <= 0) {
      return;
    }
    final wasPinching = _pinchActive;
    _activePointerCount = math.max(0, _activePointerCount - 1);
    if (_activePointerCount == 0) {
      _pinchActive = false;
      _pointerDownSeen = false;
    }
    if (_routingPage) {
      _endPageRoute(cancelled: true);
      _logPointerUpSnapshot(
        axis: _gestureAxis.name,
        routedPage: _didRoutePageThisGesture,
        routedDismiss: _didRouteDismissThisGesture,
        panDist: _accumulatedPanDistance,
      );
      return;
    }
    if (_topPullActive || _rubberDy > 0.5) {
      _finishTopPull(cancelled: true);
      _logPointerUpSnapshot(
        axis: _gestureAxis.name,
        routedPage: _didRoutePageThisGesture,
        routedDismiss: _didRouteDismissThisGesture,
        panDist: _accumulatedPanDistance,
      );
      return;
    }
    if (wasPinching) {
      _finishPinchScale();
    } else if (!_nearMinScale && !_routingPage && !_topPullActive) {
      _finishMatrixPan();
    }
    _logPointerUpSnapshot(
      axis: _gestureAxis.name,
      routedPage: _didRoutePageThisGesture,
      routedDismiss: _didRouteDismissThisGesture,
      panDist: _accumulatedPanDistance,
    );
  }

  /// 双指松手：欠缩迅速弹回 1x；仍放大则只回弹平移边界。
  void _finishPinchScale({Offset? focalPoint}) {
    final scale = _controller.value.getMaxScaleOnAxis();
    if (scale < 0.995) {
      final screen = MediaQuery.sizeOf(context);
      final focus = focalPoint ??
          Offset(screen.width * 0.5, screen.height * 0.5);
      _animateToScale(
        1.0,
        focus,
        duration: imagePreviewScaleSnapDuration,
        curve: imagePreviewScaleSnapCurve,
      );
      return;
    }
    if (scale > 1.05) {
      _springReboundMatrix();
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final targetScale =
        currentScale <= 1.05 ? widget.doubleTapTarget : 1.0;
    final diag = _panDiagnostics();
    TallImageGestureDiag.doubleTap(
      fromScale: currentScale,
      toScale: targetScale,
      tx: diag.tx,
      ty: diag.ty,
    );
    _animateToScale(targetScale, details.localPosition);
  }

  void _animateToScale(
    double targetScale,
    Offset focalPoint, {
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeOutCubic,
  }) {
    _zoomAnimationController?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: duration,
    );
    _zoomAnimationController = controller;
    final begin = _controller.value;
    final end = _matrixForScale(targetScale, focalPoint);
    _zoomAnimation = Matrix4Tween(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _controller.value = _zoomAnimation!.value;
        }
      });
    // 缩放态切换会影响 panEnabled，需刷新。
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {});
      }
    });
    controller.forward();
  }

  Matrix4 _matrixForScale(double scale, Offset focalPoint) {
    if (scale <= 1.001) {
      if (_isTallScrollMode) {
        final bounds = _matrixPanBounds(scale: 1.0);
        final y = bounds.clamp(_currentTranslation()).dy;
        if (y.abs() > 0.5) {
          return Matrix4.identity()
            ..translateByDouble(0, y, 0, 1);
        }
      }
      return Matrix4.identity();
    }

    final current = _controller.value;
    final currentScale = current.getMaxScaleOnAxis();
    if (currentScale <= 1.001) {
      final ty = _currentTranslation().dy;
      return Matrix4.identity()
        ..translateByDouble(focalPoint.dx, focalPoint.dy + ty, 0, 1)
        ..scaleByDouble(scale, scale, scale, 1)
        ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1);
    }

    final scaleFactor = scale / currentScale;
    return Matrix4.copy(current)
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
      ..scaleByDouble(scaleFactor, scaleFactor, scaleFactor, 1)
      ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final info = widget.extendedImageState.extendedImageInfo;
    final image = info?.image;
    if (image == null) {
      return const SizedBox.shrink();
    }

    final imageWidget = widget.extendedImageState.imageWidget;
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final fit = widget.displayMode == ImagePreviewDisplayMode.extraTall ||
            widget.displayMode == ImagePreviewDisplayMode.tall
        ? BoxFit.fitWidth
        : BoxFit.contain;
    final displaySize = imagePreviewInitialDisplaySize(
      imageWidth: imgW.round(),
      imageHeight: imgH.round(),
      screenWidth: screenSize.width,
      screenHeight: screenSize.height,
      fit: fit,
    );
    final displayW = displaySize.width;
    final displayH = displaySize.height;
    _childDisplaySize = displaySize;
    if (!_mountLogged) {
      _mountLogged = true;
      TallImageGestureDiag.markMounted(
        inPageView: widget.inPageView,
        displayW: displayW,
        displayH: displayH,
        viewportH: screenSize.height,
      );
    }

    Widget viewer = InteractiveViewer(
      transformationController: _controller,
      alignment: Alignment.topLeft,
      constrained: false,
      boundaryMargin: EdgeInsets.zero,
      // 允许暂时欠缩，松手由 [_finishPinchScale] 迅速弹回 1x。
      minScale: imagePreviewAnimationMinScale,
      maxScale: math.max(widget.maxScale, 1.0),
      // 1x 禁平移，避免与轴向锁定抢指针；放大后才放开。
      panEnabled: false,
      scaleEnabled: !_routingPage && !_topPullActive,
      panAxis: PanAxis.free,
      clipBehavior: Clip.hardEdge,
      onInteractionEnd: (_) {
        if (!_pinchActive &&
            _controller.value.getMaxScaleOnAxis() < 0.995) {
          _finishPinchScale();
        }
      },
      child: SizedBox(
        width: displayW,
        height: displayH,
        child: RawImage(
          image: image,
          width: displayW,
          height: displayH,
          fit: BoxFit.fill,
          scale: info?.scale ?? 1.0,
          color: imageWidget.color,
          colorBlendMode: imageWidget.colorBlendMode,
          filterQuality: imageWidget.filterQuality,
        ),
      ),
    );

    // 本地下拉位移；遮罩由 slideMetrics 跟手，关闭由 onSlideDismiss 正规 pop。
    // 缩放作用在图片本体（与 GesturedImage 一致），避免全屏中心缩放。
    final contentScale = widget.slideMetrics.contentScale;
    if ((contentScale - 1.0).abs() > 0.001) {
      viewer = Transform.scale(
        scale: contentScale,
        filterQuality: FilterQuality.medium,
        child: viewer,
      );
    }
    if (_rubberDy.abs() > 0.5) {
      viewer = Transform.translate(
        offset: Offset(0, _rubberDy),
        child: viewer,
      );
    }

    return Stack(
      children: [
        Listener(
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          behavior: HitTestBehavior.opaque,
          child: GestureDetector(
            onDoubleTapDown: _handleDoubleTap,
            behavior: HitTestBehavior.opaque,
            child: viewer,
          ),
        ),
        if (_showScrollToTop)
          Positioned(
            top: screenSize.height * 0.08,
            right: 16,
            child: _ScrollToTopButton(onTap: _scrollToTop),
          ),
      ],
    );
  }
}

class _ScrollToTopButton extends StatelessWidget {
  const _ScrollToTopButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: 4),
            Text(
              '顶部',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
