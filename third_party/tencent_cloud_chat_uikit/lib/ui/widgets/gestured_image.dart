import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_gesture_physics.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_resolution_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_slide_metrics.dart';

Map<Object?, GestureDetails?> _gestureDetailsCache =
    <Object?, GestureDetails?>{};

/// 图片预览页单击关闭回调（由 [ImageScreen] 注册）。
VoidCallback? imagePreviewTapToCloseCallback;

/// 下滑达关闭阈值时回调；由宿主播缩放淡出。返回 true 表示已接管，勿再调用
/// [ExtendedImageSlidePageState.endSlide]（否则会回弹到原点再消失）。
typedef ImagePreviewSlideDismissCallback = bool Function(
  ExtendedImageSlidePageState state,
  ScaleEndDetails details,
  Offset releaseOffset,
);

ImagePreviewSlideDismissCallback? imagePreviewSlideDismissCallback;

///clear the gesture details
void clearGestureDetailsCache() {
  _gestureDetailsCache.clear();
}

/// scale idea from https://github.com/flutter/flutter/blob/master/examples/layers/widgets/gestures.dart
/// zoom image
class GesturedImage extends ExtendedImageGesture {
  const GesturedImage(ExtendedImageState extendedImageState,
      {ImageBuilderForGesture? imageBuilder,
      CanScaleImage? canScaleImage,
      Key? key})
      : super(extendedImageState,
            imageBuilder: imageBuilder, canScaleImage: canScaleImage, key: key);

  @override
  GesturedImageState createState() => GesturedImageState();
}

class GesturedImageState extends ExtendedImageGestureState {
  ///details for gesture
  GestureDetails? _gestureDetails;
  late Offset _normalizedOffset;
  double? _startingScale;
  late Offset _startingOffset;
  Offset? _pointerDownPosition;
  late GestureAnimation _gestureAnimation;
  GestureConfig? _gestureConfig;
  ExtendedImageGesturePageViewState? _pageViewState;
  double _accumulatedPanDistance = 0;
  ImagePreviewPanMomentumRunner? _panMomentumRunner;
  ImagePreviewPanAxisLock _zoomPanAxisLock = ImagePreviewPanAxisLock.undecided;
  Offset _panGestureTotal = Offset.zero;
  AnimationController? _scaleSnapController;
  @override
  ExtendedImageSlidePageState? get extendedImageSlidePageState =>
      widget.extendedImageState.slidePageState;

  @override
  GestureDetails? get gestureDetails => _gestureDetails;

  @override
  set gestureDetails(GestureDetails? value) {
    if (mounted) {
      setState(() {
        _gestureDetails = value;
        _gestureConfig?.gestureDetailsIsChanged?.call(_gestureDetails);
      });
    }
  }

  @override
  GestureConfig? get imageGestureConfig => _gestureConfig;

  @override
  Offset? get pointerDownPosition => _pointerDownPosition;

  @override
  Widget build(BuildContext context) {
    if (_gestureConfig!.cacheGesture) {
      _gestureDetailsCache[widget.extendedImageState.imageStreamKey] =
          _gestureDetails;
    }

    Widget image = ExtendedRawImage(
      image: widget.extendedImageState.extendedImageInfo?.image,
      width: widget.extendedImageState.imageWidget.width,
      height: widget.extendedImageState.imageWidget.height,
      scale: widget.extendedImageState.extendedImageInfo?.scale ?? 1.0,
      color: widget.extendedImageState.imageWidget.color,
      colorBlendMode: widget.extendedImageState.imageWidget.colorBlendMode,
      fit: widget.extendedImageState.imageWidget.fit,
      alignment: widget.extendedImageState.imageWidget.alignment,
      repeat: widget.extendedImageState.imageWidget.repeat,
      centerSlice: widget.extendedImageState.imageWidget.centerSlice,
      matchTextDirection:
          widget.extendedImageState.imageWidget.matchTextDirection,
      invertColors: widget.extendedImageState.invertColors,
      filterQuality: widget.extendedImageState.imageWidget.filterQuality,
      beforePaintImage: widget.extendedImageState.imageWidget.beforePaintImage,
      afterPaintImage: widget.extendedImageState.imageWidget.afterPaintImage,
      gestureDetails: _gestureDetails,
    );

    if (extendedImageSlidePageState != null) {
      image = widget.extendedImageState.imageWidget.heroBuilderForSlidingPage
              ?.call(image) ??
          image;
      if (extendedImageSlidePageState!.widget.slideType ==
          SlideType.onlyImage) {
        // 跟手缩放作用在图片本体上（而非全屏外壳中心），小图拖走后不会往屏心回吸。
        final metrics = MediaPreviewSlideVisualScope.maybeMetricsOf(context);
        final pageOffset = extendedImageSlidePageState!.offset;
        // 关闭锁定后位移以 metrics 为准，避免 SlidePage 回弹把图拽回原点。
        final slideOffset =
            (metrics != null && metrics.dismissVisualLocked)
                ? metrics.slideOffset
                : pageOffset;
        final slideScale = metrics?.contentScale ?? 1.0;
        image = Transform.translate(
          offset: slideOffset,
          child: Transform.scale(
            scale: slideScale,
            filterQuality: FilterQuality.medium,
            child: image,
          ),
        );
      }
    }

    image = widget.imageBuilder?.call(image) ?? image;

    // 不要 wrapGestureWidget：它会按手势结果约束子组件尺寸，而 ExtendedRawImage
    // 绘制时还会再算一遍 gestureDetails，非全屏高的图会被二次放大，
    // 放大后拖动只能看到一小块。与 upstream ExtendedImageGesture 一致，只靠绘制变换。
    // 尺寸跟父级出画盒走，不要再撑成全屏，否则 Hero 落点与真实绘制会错开。
    final imageWidget = widget.extendedImageState.imageWidget;
    final screenSize = MediaQuery.sizeOf(context);
    final width = imageWidget.width ?? screenSize.width;
    final height = imageWidget.height ?? screenSize.height;

    return SizedBox(
      width: width,
      height: height,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerSignal: _handlePointerSignal,
        behavior: HitTestBehavior.opaque,
        child: GestureDetector(
          onScaleStart: handleScaleStart,
          onScaleUpdate: handleScaleUpdate,
          onScaleEnd: handleScaleEnd,
          onDoubleTap: _handleDoubleTap,
          behavior: HitTestBehavior.opaque,
          child: image,
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageViewState = null;
    if (_gestureConfig!.inPageView) {
      _pageViewState =
          context.findAncestorStateOfType<ExtendedImageGesturePageViewState>();
      _pageViewState?.extendedImageGestureState = this;
    }
  }

  @override
  void didUpdateWidget(GesturedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initGestureConfig();
    _pageViewState = null;
    if (_gestureConfig!.inPageView) {
      _pageViewState =
          context.findAncestorStateOfType<ExtendedImageGesturePageViewState>();
      _pageViewState?.extendedImageGestureState = this;
    }
  }

  @override
  void dispose() {
    _panMomentumRunner?.stop();
    _scaleSnapController?.dispose();
    _scaleSnapController = null;
    _gestureAnimation.stop();
    _gestureAnimation.dispose();
    _pageViewState?.extendedImageGestureStates.remove(this);
    super.dispose();
  }

  /// 欠缩/超限松手：固定短时长贴回，避免 extended_image fling 回弹拖沓。
  void _snapScaleTo(double targetScale) {
    final begin = _gestureDetails?.totalScale;
    if (begin == null) {
      return;
    }
    if ((begin - targetScale).abs() < 0.001) {
      return;
    }

    _gestureAnimation.stop();
    _scaleSnapController?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: imagePreviewScaleSnapDuration,
    );
    _scaleSnapController = controller;
    final animation = Tween<double>(begin: begin, end: targetScale).animate(
      CurvedAnimation(parent: controller, curve: imagePreviewScaleSnapCurve),
    );
    animation.addListener(() {
      if (!mounted || !identical(_scaleSnapController, controller)) {
        return;
      }
      gestureDetails = GestureDetails(
        offset: _gestureDetails!.offset,
        totalScale: animation.value,
        gestureDetails: _gestureDetails,
        actionType: ActionType.zoom,
        userOffset: false,
      );
    });
    controller.forward().whenCompleteOrCancel(() {
      if (identical(_scaleSnapController, controller)) {
        controller.dispose();
        _scaleSnapController = null;
      }
    });
  }

  @override
  void handleDoubleTap({double? scale, Offset? doubleTapPosition}) {
    doubleTapPosition ??= _pointerDownPosition;
    scale ??= _gestureConfig!.initialScale;
    //scale = scale.clamp(_gestureConfig.minScale, _gestureConfig.maxScale);
    handleScaleStart(ScaleStartDetails(focalPoint: doubleTapPosition!));
    handleScaleUpdate(ScaleUpdateDetails(
      focalPoint: doubleTapPosition,
      scale: scale / _startingScale!,
      focalPointDelta: Offset.zero,
    ));
    if (scale < _gestureConfig!.minScale || scale > _gestureConfig!.maxScale) {
      handleScaleEnd(ScaleEndDetails());
    }
  }

  @override
  void initState() {
    super.initState();
    _initGestureConfig();
  }

  @override
  void reset() {
    _gestureConfig = widget
            .extendedImageState.imageWidget.initGestureConfigHandler
            ?.call(widget.extendedImageState) ??
        GestureConfig();

    gestureDetails = GestureDetails(
      totalScale: _gestureConfig!.initialScale,
      offset: Offset.zero,
      initialAlignment: _gestureConfig!.initialAlignment,
    );
  }

  @override
  void slide() {
    if (!mounted || extendedImageSlidePageState == null) {
      return;
    }
    final nextOffset = extendedImageSlidePageState!.offset;
    if (_gestureDetails?.slidePageOffset == nextOffset) {
      return;
    }
    setState(() {
      _gestureDetails!.slidePageOffset = nextOffset;
    });
  }

  void _handleDoubleTap() {
    if (widget.extendedImageState.imageWidget.onDoubleTap != null) {
      widget.extendedImageState.imageWidget.onDoubleTap!(this);
      return;
    }

    if (!mounted) {
      return;
    }

    gestureDetails = GestureDetails(
      offset: Offset.zero,
      totalScale: _gestureConfig!.initialScale,
    );
  }

  void _handlePointerDown(PointerDownEvent pointerDownEvent) {
    _pointerDownPosition = pointerDownEvent.position;
    _gestureAnimation.stop();
    _scaleSnapController?.stop();
    _scaleSnapController?.dispose();
    _scaleSnapController = null;
    _panMomentumRunner?.stop();

    _pageViewState?.extendedImageGestureState = this;
  }

  void _endActivePageViewDrag() {
    final pageViewState = _pageViewState;
    if (pageViewState != null && pageViewState.isDraging) {
      pageViewState.onDragEnd(
        DragEndDetails(velocity: Velocity.zero),
      );
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && event.kind == PointerDeviceKind.mouse) {
      handleScaleStart(ScaleStartDetails(focalPoint: event.position));
      final double dy = event.scrollDelta.dy;
      final double dx = event.scrollDelta.dx;
      handleScaleUpdate(ScaleUpdateDetails(
          focalPoint: event.position,
          scale: 1.0 +
              _reverseIf((dy.abs() > dx.abs() ? dy : dx) *
                  _gestureConfig!.speed /
                  1000.0),
          focalPointDelta: Offset.zero));
      handleScaleEnd(ScaleEndDetails());
    }
  }

  @override
  void handleScaleEnd(ScaleEndDetails details) {
    if (extendedImageSlidePageState != null &&
        extendedImageSlidePageState!.isSliding) {
      final state = extendedImageSlidePageState!;
      final releaseOffset = state.offset;
      final vy = details.velocity.pixelsPerSecond.dy;
      final dismiss = imagePreviewSlideDismissCallback;
      // 达关闭阈值时不要走 endSlide：它在 return false 后会把 offset 置零并回弹。
      if (dismiss != null &&
          mediaPreviewShouldDismissForSlide(releaseOffset, vy) &&
          dismiss(state, details, releaseOffset)) {
        return;
      }
      state.endSlide(details);
      return;
    }

    if (_isPreviewTap(details)) {
      if (_pageViewState != null && _pageViewState!.isDraging) {
        _pageViewState!.onDragCancel();
      }
      imagePreviewTapToCloseCallback?.call();
      return;
    }

    if (_pageViewState != null && _pageViewState!.isDraging) {
      _pageViewState!.onDragEnd(DragEndDetails(
        velocity: details.velocity,
        primaryVelocity:
            _pageViewState!.widget.scrollDirection == Axis.horizontal
                ? details.velocity.pixelsPerSecond.dx
                : details.velocity.pixelsPerSecond.dy,
      ));
      return;
    }

    //animate back to maxScale if gesture exceeded the maxScale specified
    if (_gestureDetails!.totalScale!.greaterThan(_gestureConfig!.maxScale)) {
      _snapScaleTo(_gestureConfig!.maxScale);
      return;
    }

    //animate back to minScale if gesture fell smaller than the minScale specified
    if (_gestureDetails!.totalScale!.lessThan(_gestureConfig!.minScale)) {
      _snapScaleTo(_gestureConfig!.minScale);
      return;
    }

    if (_gestureDetails!.actionType == ActionType.pan) {
      _startPanMomentum(details.velocity.pixelsPerSecond);
    }
  }

  bool _isZoomedForPan() {
    final initialScale = _gestureConfig?.initialScale ?? 1.0;
    final totalScale = _gestureDetails?.totalScale ?? initialScale;
    return totalScale > initialScale * 1.05;
  }

  ImagePreviewDisplayConfig _currentDisplayConfig() {
    final info = widget.extendedImageState.extendedImageInfo;
    final screen = MediaQuery.sizeOf(context);
    return imagePreviewDisplayConfig(
      imageWidth: info?.image.width ?? 1,
      imageHeight: info?.image.height ?? 1,
      screenWidth: screen.width,
      screenHeight: screen.height,
      fitTallImagesToScreenWidth: ImagePreviewFitPolicyScope.of(context),
    );
  }

  ImagePreviewGestureProfile get _gestureProfile =>
      _currentDisplayConfig().gestureProfile;

  ImagePreviewPanMomentumRunner _ensurePanMomentumRunner() {
    final profile = _gestureProfile;
    return _panMomentumRunner ??= ImagePreviewPanMomentumRunner(
      vsync: this,
      minVelocity: profile.inertialMinVelocity,
      decayPerFrame: profile.inertialDecayPerFrame,
      onDelta: (delta) {
        if (!mounted || _gestureDetails == null) {
          return;
        }
        final current = _gestureDetails!.offset ?? Offset.zero;
        final next = current + _applyZoomedPanDelta(delta);
        gestureDetails = GestureDetails(
          offset: next,
          totalScale: _gestureDetails!.totalScale,
          gestureDetails: _gestureDetails,
          actionType: ActionType.pan,
        );
      },
    );
  }

  void _startPanMomentum(Offset velocityPixelsPerSecond) {
    final profile = _gestureProfile;
    final zoomed = _isZoomedForPan();
    final damping = zoomed ? profile.panDamping : imagePreviewPanSpeed;
    final scaledVelocity = Offset(
      velocityPixelsPerSecond.dx * damping,
      velocityPixelsPerSecond.dy * damping,
    );
    _ensurePanMomentumRunner().start(scaledVelocity);
  }

  ImagePreviewPanAxisLock _resolvePanAxisLock(Offset delta) {
    final profile = _gestureProfile;
    if (!_isZoomedForPan()) {
      return ImagePreviewPanAxisLock.free;
    }
    final details = _gestureDetails;
    if (details == null) {
      return imagePreviewAxisLockForPreference(
        preference: profile.panAxisPreference,
      );
    }
    return imagePreviewResolveZoomPanAxisLock(
      preference: profile.panAxisPreference,
      computeHorizontalBoundary: details.computeHorizontalBoundary,
      computeVerticalBoundary: details.computeVerticalBoundary,
      currentLock: _zoomPanAxisLock,
      gestureTotalDelta: _panGestureTotal,
      delta: delta,
    );
  }

  Offset _applyZoomedPanDelta(Offset delta) {
    if (delta == Offset.zero) {
      return Offset.zero;
    }
    final lock = _resolvePanAxisLock(delta);
    final working = imagePreviewApplyPanAxisLock(delta, lock);
    return _dampedPanDeltaForGesture(working);
  }

  Offset _dampedPanDeltaForGesture(Offset delta) {
    final details = _gestureDetails;
    if (details == null || delta == Offset.zero) {
      return Offset.zero;
    }
    final viewport = MediaQuery.sizeOf(context);
    final profile = _gestureProfile;
    final zoomed = _isZoomedForPan();
    final panDamping = zoomed ? profile.panDamping : imagePreviewPanSpeed;
    var dx = delta.dx * panDamping;
    var dy = delta.dy * panDamping;

    if (details.computeHorizontalBoundary) {
      if (details.boundary.left && delta.dx > 0) {
        dx *= imagePreviewEdgeDampingFactor(
          overscrollPx: delta.dx.abs(),
          viewportSpan: viewport.width,
        );
      }
      if (details.boundary.right && delta.dx < 0) {
        dx *= imagePreviewEdgeDampingFactor(
          overscrollPx: delta.dx.abs(),
          viewportSpan: viewport.width,
        );
      }
    }
    if (details.computeVerticalBoundary) {
      if (details.boundary.top && delta.dy > 0) {
        dy *= imagePreviewEdgeDampingFactor(
          overscrollPx: delta.dy.abs(),
          viewportSpan: viewport.height,
        );
      }
      if (details.boundary.bottom && delta.dy < 0) {
        dy *= imagePreviewEdgeDampingFactor(
          overscrollPx: delta.dy.abs(),
          viewportSpan: viewport.height,
        );
      }
    }
    return Offset(dx, dy);
  }

  bool _isPreviewTap(ScaleEndDetails details) {
    final initialScale = _gestureConfig?.initialScale ?? 1.0;
    final totalScale = _gestureDetails?.totalScale ?? initialScale;
    return mediaPreviewIsTapGesture(
      accumulatedDistance: _accumulatedPanDistance,
      totalScale: totalScale,
      initialScale: initialScale,
      velocityDistance: details.velocity.pixelsPerSecond.distance,
    );
  }

  @override
  void handleScaleStart(ScaleStartDetails details) {
    final slideState = extendedImageSlidePageState;
    if (slideState != null && slideState.backAnimationController.isAnimating) {
      slideState.backAnimationController.stop();
    }
    _gestureAnimation.stop();
    _panMomentumRunner?.stop();
    _zoomPanAxisLock = ImagePreviewPanAxisLock.undecided;
    _panGestureTotal = Offset.zero;
    _accumulatedPanDistance = 0;
    _normalizedOffset = (details.focalPoint - _gestureDetails!.offset!) /
        _gestureDetails!.totalScale!;
    _startingScale = _gestureDetails!.totalScale;
    _startingOffset = details.focalPoint;
  }

  @override
  void handleScaleUpdate(ScaleUpdateDetails details) {
    _accumulatedPanDistance += details.focalPointDelta.distance;
    final initialScale = _gestureConfig?.initialScale ?? 1.0;
    // 仅在未放大时走下滑关闭；放大后单指拖动用于平移图片。
    if (extendedImageSlidePageState != null &&
        details.scale == 1.0 &&
        (_gestureDetails!.totalScale ?? initialScale) <= initialScale * 1.05 &&
        _gestureDetails!.userOffset &&
        _gestureDetails!.actionType == ActionType.pan) {
      final slideAxis = extendedImageSlidePageState!.widget.slideAxis;
      final Offset totalDelta = details.focalPointDelta;
      bool updateGesture = false;
      if (!extendedImageSlidePageState!.isSliding) {
        final bool horizontalDominant =
            totalDelta.dx.abs().greaterThan(totalDelta.dy.abs());
        final bool verticalDominant =
            totalDelta.dy.abs() >= totalDelta.dx.abs() && totalDelta.dy != 0;

        if (horizontalDominant &&
            (slideAxis == SlideAxis.horizontal || slideAxis == SlideAxis.both)) {
          if (_gestureDetails!.computeHorizontalBoundary) {
            updateGesture = totalDelta.dx > 0
                ? _gestureDetails!.boundary.left
                : _gestureDetails!.boundary.right;
          } else {
            updateGesture = true;
          }
        } else if (verticalDominant &&
            (slideAxis == SlideAxis.vertical || slideAxis == SlideAxis.both)) {
          // 可纵滑长图：仅顶部继续下拉才进入关闭；上滑/中部拖动只用于浏览。
          final verticallyScrollable =
              _currentDisplayConfig().verticallyScrollable;
          if (verticallyScrollable) {
            updateGesture =
                totalDelta.dy > 0 && _gestureDetails!.boundary.top;
          } else if (_gestureDetails!.computeVerticalBoundary) {
            // 高度已铺满：贴边后把纵向手势交给关闭。
            updateGesture = totalDelta.dy < 0
                ? _gestureDetails!.boundary.bottom
                : _gestureDetails!.boundary.top;
          } else {
            // 高度未铺满（小图/上下黑边）：与 extended_image 一致，纵向即可关闭。
            updateGesture = true;
          }
        }
      } else {
        updateGesture = true;
      }

      final double dragDistance =
          (details.focalPoint - _startingOffset).distance;
      if (dragDistance.greaterThan(minGesturePageDelta) && updateGesture) {
        _endActivePageViewDrag();
        extendedImageSlidePageState!.slide(
          details.focalPointDelta,
          extendedImageGestureState: this,
        );
      }
    }

    if (extendedImageSlidePageState != null &&
        extendedImageSlidePageState!.isSliding) {
      return;
    }

    // 图集翻页：须先过 canScrollPage；竖向拖动时取消已开始的横滑，避免放大后无法上下平移。
    if (_pageViewState != null) {
      final ExtendedImageGesturePageViewState pageViewState = _pageViewState!;
      final Axis axis = pageViewState.widget.scrollDirection;
      final canScroll = pageViewState.widget.canScrollPage(_gestureDetails);
      final delta = details.focalPointDelta;
      final zoomed = _isZoomedForPan();
      final horizontalIntent = zoomed
          ? delta.dx.abs() > delta.dy.abs() * 1.15
          : delta.dx.abs() > delta.dy.abs();

      if (pageViewState.isDraging && (!canScroll || !horizontalIntent)) {
        pageViewState.onDragCancel();
      }

      if (canScroll && (horizontalIntent || pageViewState.isDraging)) {
        final bool movePage = mediaPreviewShouldBeginPageDrag(
              alreadyDragging: pageViewState.isDraging,
              horizontalIntent: horizontalIntent,
              pointerCount: details.pointerCount,
              scale: details.scale,
              accumulatedDistance: _accumulatedPanDistance,
            ) &&
            (pageViewState.isDraging ||
                _gestureDetails!.movePage(delta, axis));

        if (movePage) {
          if (!pageViewState.isDraging) {
            pageViewState.onDragDown(
                DragDownDetails(globalPosition: details.focalPoint));
            pageViewState.onDragStart(
                DragStartDetails(globalPosition: details.focalPoint));
          }
          final routedDelta = axis == Axis.horizontal
              ? Offset(delta.dx, 0)
              : Offset(0, delta.dy);

          pageViewState.onDragUpdate(DragUpdateDetails(
            globalPosition: details.focalPoint,
            delta: routedDelta,
            primaryDelta:
                axis == Axis.horizontal ? routedDelta.dx : routedDelta.dy,
          ));

          return;
        }
      }
    }
    final double? scale = widget.canScaleImage(_gestureDetails)
        ? clampScale(
            _startingScale! * details.scale * _gestureConfig!.speed,
            _gestureConfig!.animationMinScale,
            _gestureConfig!.animationMaxScale)
        : _gestureDetails!.totalScale;

    //Round the scale to three points after comma to prevent shaking
    //scale = roundAfter(scale, 3);
    //no more zoom
    if (details.scale != 1.0 &&
        ((_gestureDetails!.totalScale!
                    .equalTo(_gestureConfig!.animationMinScale) &&
                scale!.lessThanOrEqualTo(_gestureDetails!.totalScale!)) ||
            (_gestureDetails!.totalScale!
                    .equalTo(_gestureConfig!.animationMaxScale) &&
                scale!.greaterThanOrEqualTo(_gestureDetails!.totalScale!)))) {
      return;
    }

    final Offset offset;
    if (details.scale == 1.0) {
      if (!_gestureProfile.allowPanAt1x &&
          !_isZoomedForPan() &&
          _gestureDetails!.actionType == ActionType.pan) {
        return;
      }
      final current = _gestureDetails!.offset ?? Offset.zero;
      offset = current + _applyZoomedPanDelta(details.focalPointDelta);
    } else {
      offset = _startingOffset - _normalizedOffset * scale!;
    }

    if (mounted &&
        (offset != _gestureDetails!.offset ||
            scale != _gestureDetails!.totalScale)) {
      gestureDetails = GestureDetails(
          offset: offset,
          totalScale: scale,
          gestureDetails: _gestureDetails,
          actionType: details.scale != 1.0 ? ActionType.zoom : ActionType.pan);
    }
  }

  void _initGestureConfig() {
    final double? initialScale = _gestureConfig?.initialScale;
    final InitialAlignment? initialAlignment = _gestureConfig?.initialAlignment;
    _gestureConfig = widget
            .extendedImageState.imageWidget.initGestureConfigHandler
            ?.call(widget.extendedImageState) ??
        GestureConfig();

    if (_gestureDetails == null ||
        initialScale != _gestureConfig!.initialScale ||
        initialAlignment != _gestureConfig!.initialAlignment) {
      _gestureDetails = GestureDetails(
        totalScale: _gestureConfig!.initialScale,
        offset: Offset.zero,
        initialAlignment: _gestureConfig!.initialAlignment,
      );
    }

    if (_gestureConfig!.cacheGesture) {
      final GestureDetails? cache =
          _gestureDetailsCache[widget.extendedImageState.imageStreamKey];
      if (cache != null) {
        _gestureDetails = cache;
      }
    }
    _gestureDetails ??= GestureDetails(
      totalScale: _gestureConfig!.initialScale,
      offset: Offset.zero,
    );

    _gestureAnimation = GestureAnimation(this, offsetCallBack: (Offset value) {
      gestureDetails = GestureDetails(
          offset: value,
          totalScale: _gestureDetails!.totalScale,
          gestureDetails: _gestureDetails);
    }, scaleCallBack: (double scale) {
      gestureDetails = GestureDetails(
          offset: _gestureDetails!.offset,
          totalScale: scale,
          gestureDetails: _gestureDetails,
          actionType: ActionType.zoom,
          userOffset: false);
    });
  }

  double _reverseIf(double scaleDetal) {
    if (_gestureConfig?.reverseMousePointerScrollDirection ?? false) {
      return -scaleDetal;
    } else {
      return scaleDetal;
    }
  }
}
