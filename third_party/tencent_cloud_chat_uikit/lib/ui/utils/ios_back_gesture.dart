import 'dart:math' show max;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const double _kBackGestureWidth = 20.0;
const double _kMinFlingVelocity = 1.0;
const Duration _kDroppedSwipePageAnimationDuration =
    Duration(milliseconds: 350);

/// 支持挂载左边缘右滑返回手势的 [PageRoute]。
abstract interface class IosBackGestureRoute {
  Widget wrapWithIosBackGesture(Widget child);
}

/// 在 [PageRoute] 子类中挂载左边缘右滑返回手势。
mixin IosBackGestureRouteMixin<T> on PageRoute<T> implements IosBackGestureRoute {
  @override
  Widget wrapWithIosBackGesture(Widget child) {
    if (isFirst || navigator == null || controller == null) {
      return child;
    }
    return IosBackGestureDetector<T>(
      enabledCallback: () {
        if (isFirst) return false;
        final nav = navigator;
        if (nav == null || controller == null) return false;
        if (nav.userGestureInProgress) return true;
        return nav.canPop();
      },
      onStartPopGesture: () => IosBackGestureController<T>(
        navigator: navigator!,
        controller: controller!,
        getIsActive: () => isActive,
        getIsCurrent: () => isCurrent,
      ),
      child: child,
    );
  }
}

/// iOS 风格左边缘右滑返回手势控制器。
class IosBackGestureController<T> {
  IosBackGestureController({
    required this.navigator,
    required this.controller,
    required this.getIsActive,
    required this.getIsCurrent,
  }) {
    navigator.didStartUserGesture();
  }

  final AnimationController controller;
  final NavigatorState navigator;
  final ValueGetter<bool> getIsActive;
  final ValueGetter<bool> getIsCurrent;

  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  void dragEnd(double velocity) {
    const Curve animationCurve = Curves.fastEaseInToSlowEaseOut;
    final isCurrent = getIsCurrent();
    final bool animateForward;

    if (!isCurrent) {
      animateForward = getIsActive();
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      controller.animateTo(
        1.0,
        duration: _kDroppedSwipePageAnimationDuration,
        curve: animationCurve,
      );
    } else {
      if (isCurrent) {
        navigator.pop();
      }
      if (controller.isAnimating) {
        controller.animateBack(
          0.0,
          duration: _kDroppedSwipePageAnimationDuration,
          curve: animationCurve,
        );
      }
    }

    if (controller.isAnimating) {
      late AnimationStatusListener listener;
      listener = (AnimationStatus status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(listener);
      };
      controller.addStatusListener(listener);
    } else {
      navigator.didStopUserGesture();
    }
  }
}

class IosBackGestureDetector<T> extends StatefulWidget {
  const IosBackGestureDetector({
    super.key,
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
  });

  final Widget child;
  final ValueGetter<bool> enabledCallback;
  final ValueGetter<IosBackGestureController<T>> onStartPopGesture;

  @override
  State<IosBackGestureDetector<T>> createState() =>
      _IosBackGestureDetectorState<T>();
}

class _IosBackGestureDetectorState<T> extends State<IosBackGestureDetector<T>> {
  IosBackGestureController<T>? _controller;
  late HorizontalDragGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    if (_controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller?.navigator.mounted ?? false) {
          _controller?.navigator.didStopUserGesture();
        }
        _controller = null;
      });
    }
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _controller = widget.onStartPopGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final width = context.size?.width;
    if (width == null || width <= 0 || _controller == null) {
      return;
    }
    _controller!.dragUpdate(
      _convertToLogical(details.primaryDelta! / width),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    final width = context.size?.width;
    if (width == null || width <= 0 || _controller == null) {
      return;
    }
    _controller!.dragEnd(
      _convertToLogical(details.velocity.pixelsPerSecond.dx / width),
    );
    _controller = null;
  }

  void _handleDragCancel() {
    _controller?.dragEnd(0.0);
    _controller = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.enabledCallback()) {
      _recognizer.addPointer(event);
    }
  }

  double _convertToLogical(double value) {
    return switch (Directionality.of(context)) {
      TextDirection.rtl => -value,
      TextDirection.ltr => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dragAreaWidth = switch (Directionality.of(context)) {
      TextDirection.rtl => MediaQuery.paddingOf(context).right,
      TextDirection.ltr => MediaQuery.paddingOf(context).left,
    };
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          width: max(dragAreaWidth, _kBackGestureWidth),
          top: 0,
          bottom: 0,
          child: Listener(
            onPointerDown: _handlePointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}

/// 透明全屏页（图片/视频预览等），支持左边缘右滑返回。
class TransparentIosBackGesturePageRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T>, IosBackGestureRouteMixin<T> {
  TransparentIosBackGesturePageRoute({
    required this.pageBuilder,
    super.settings,
    this.opaque = false,
  });

  final RoutePageBuilder pageBuilder;

  @override
  final bool opaque;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildContent(BuildContext context) {
    return pageBuilder(context, animation!, secondaryAnimation!);
  }

  @override
  String? get title => null;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return wrapWithIosBackGesture(child);
  }
}

/// 在自定义 [transitionsBuilder] 外包一层边缘返回手势。
RouteTransitionsBuilder withIosBackGesture(RouteTransitionsBuilder builder) {
  return (
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final route = ModalRoute.of(context);
    final wrapped = route is IosBackGestureRoute
        ? (route as IosBackGestureRoute).wrapWithIosBackGesture(child)
        : child;
    return builder(context, animation, secondaryAnimation, wrapped);
  };
}

/// 页面内挂载左边缘右滑返回（路由层手势被列表等组件干扰时的兜底）。
class PageIosBackGestureScope extends StatelessWidget {
  const PageIosBackGestureScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route is IosBackGestureRoute) {
      return (route as IosBackGestureRoute).wrapWithIosBackGesture(child);
    }
    return child;
  }
}
