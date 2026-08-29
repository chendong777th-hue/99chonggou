// Based on full_swipe_back_gesture (MIT). Local copy with perf + root-route guards.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 栈底一级页：不参与全屏右滑（首页 Tab 容器、登录页）。
const Set<String> kRootRoutesWithoutBackGesture = {
  '/homePage',
  '/login',
};

/// 全屏右滑返回 [PageRoute]：左边缘条带触发，不与消息列表垂直滚动竞争。
class FullScreenBackPageRoute<T> extends PageRouteBuilder<T> {
  FullScreenBackPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool maintainState = true,
    bool allowSnapshotting = false,
    this.edgeStartWidthPx = 24.0,
    this.pushCurve = Curves.fastEaseInToSlowEaseOut,
    this.popCurve = Curves.fastEaseInToSlowEaseOut,
    this.enableFullScreenBackGesture = true,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Duration reverseTransitionDuration = const Duration(milliseconds: 300),
  }) : super(
          settings: settings,
          maintainState: maintainState,
          allowSnapshotting: allowSnapshotting,
          opaque: true,
          barrierColor: Colors.transparent,
          barrierDismissible: false,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: reverseTransitionDuration,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final isReverse = animation.status == AnimationStatus.reverse;
            final curve = isReverse ? popCurve : pushCurve;
            final slide = animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: curve)),
            );
            return SlideTransition(
              position: slide,
              child: _FullScreenBackInteractor(
                edgeStartWidthPx: edgeStartWidthPx,
                enableBackGesture: enableFullScreenBackGesture,
                child: child,
              ),
            );
          },
        );

  final double edgeStartWidthPx;
  final Curve pushCurve;
  final Curve popCurve;
  final bool enableFullScreenBackGesture;

  @override
  bool get popGestureEnabled => false;

  AnimationController? get routeAnimationController => controller;
}

class _RouteBackGestureDriver {
  _RouteBackGestureDriver({
    required this.navigator,
    required this.controller,
  }) {
    navigator.didStartUserGesture();
  }

  final NavigatorState navigator;
  final AnimationController controller;

  static const Duration _cancelDuration = Duration(milliseconds: 120);
  static const Curve _cancelCurve = Curves.fastEaseInToSlowEaseOut;

  void dragUpdate(double delta) {
    controller.value = (controller.value - delta).clamp(0.0, 1.0);
  }

  void dragEnd({required bool shouldPop}) {
    if (shouldPop) {
      if (navigator.canPop()) {
        navigator.pop();
      }
      _stopUserGesture();
      return;
    }

    controller.animateTo(
      1.0,
      duration: _cancelDuration,
      curve: _cancelCurve,
    );
    _stopUserGestureWhenSettled();
  }

  /// 已在 pop/reverse 时只配对结束 userGesture，禁止 animateTo(1) 把页往回拉。
  void stopUserGestureOnly() {
    _stopUserGesture();
  }

  void _stopUserGestureWhenSettled() {
    if (controller.isAnimating) {
      late AnimationStatusListener listener;
      listener = (AnimationStatus status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          _stopUserGesture();
          controller.removeStatusListener(listener);
        }
      };
      controller.addStatusListener(listener);
    } else {
      _stopUserGesture();
    }
  }

  void _stopUserGesture() {
    if (navigator.mounted) {
      navigator.didStopUserGesture();
    }
  }
}

class _FullScreenBackInteractor extends StatefulWidget {
  const _FullScreenBackInteractor({
    required this.child,
    required this.edgeStartWidthPx,
    required this.enableBackGesture,
  });

  final Widget child;
  final double edgeStartWidthPx;
  final bool enableBackGesture;

  @override
  State<_FullScreenBackInteractor> createState() =>
      _FullScreenBackInteractorState();
}

class _FullScreenBackInteractorState extends State<_FullScreenBackInteractor> {
  late final _FullScreenBackRecognizer _recognizer;
  bool _popRequested = false;
  _RouteBackGestureDriver? _gestureDriver;
  NavigatorState? _navigator;

  AnimationController? _routeAnimationController() {
    final route = ModalRoute.of(context);
    if (route is FullScreenBackPageRoute) {
      return route.routeAnimationController;
    }
    return null;
  }

  bool _isPopTransitionInProgress() {
    final route = ModalRoute.of(context);
    return route?.animation?.status == AnimationStatus.reverse;
  }

  /// [allowingActiveDrag]：已有 driver 跟手时，不因 controller.isAnimating 误杀本次拖动。
  bool _gestureAllowed({bool allowingActiveDrag = false}) {
    if (!widget.enableBackGesture || !mounted) return false;
    if (_popRequested) return false;
    final route = ModalRoute.of(context);
    final name = route?.settings.name;
    if (name != null && kRootRoutesWithoutBackGesture.contains(name)) {
      return false;
    }
    if (route != null && !route.isCurrent) {
      return false;
    }
    if (route?.animation?.status == AnimationStatus.reverse) {
      return false;
    }
    if (!allowingActiveDrag) {
      final controller = _routeAnimationController();
      if (controller != null &&
          controller.isAnimating &&
          _gestureDriver == null) {
        return false;
      }
    }
    if (route?.isFirst == true) {
      final nav = Navigator.maybeOf(context);
      if (nav == null || !nav.canPop()) {
        return false;
      }
    }
    final nav = Navigator.maybeOf(context);
    return nav != null && nav.canPop();
  }

  void _releaseDriver({required bool allowSnapBack}) {
    final driver = _gestureDriver;
    if (driver == null) {
      return;
    }
    _gestureDriver = null;
    if (allowSnapBack) {
      driver.dragEnd(shouldPop: false);
    } else {
      driver.stopUserGestureOnly();
    }
  }

  @override
  void initState() {
    super.initState();
    _recognizer = _FullScreenBackRecognizer(
      onAccepted: () {
        if (!_gestureAllowed() || !mounted || _gestureDriver != null) {
          return;
        }
        final nav = Navigator.of(context);
        final controller = _routeAnimationController();
        if (controller == null) {
          if (kDebugMode) {
            debugPrint(
              'FullScreenBack: ModalRoute.controller is null, gesture ignored',
            );
          }
          return;
        }
        _gestureDriver = _RouteBackGestureDriver(
          navigator: nav,
          controller: controller,
        );
      },
      onDelta: (deltaDx) {
        if (!mounted) return;
        final driver = _gestureDriver;
        if (driver == null) return;
        if (_popRequested || _isPopTransitionInProgress()) {
          _releaseDriver(allowSnapBack: false);
          return;
        }
        if (!_gestureAllowed(allowingActiveDrag: true)) {
          _releaseDriver(allowSnapBack: true);
          return;
        }
        final width = MediaQuery.sizeOf(context).width;
        if (width <= 0) return;
        driver.dragUpdate(deltaDx / width);
      },
      onEnd: (totalDx, velocity) {
        if (!mounted) {
          return;
        }
        if (_popRequested) {
          _releaseDriver(allowSnapBack: false);
          return;
        }
        final driver = _gestureDriver;
        if (driver == null) return;
        if (_isPopTransitionInProgress()) {
          _releaseDriver(allowSnapBack: false);
          return;
        }
        if (!_gestureAllowed(allowingActiveDrag: true)) {
          _releaseDriver(allowSnapBack: true);
          return;
        }
        final width = MediaQuery.sizeOf(context).width;
        if (width <= 0) {
          _releaseDriver(allowSnapBack: true);
          return;
        }
        final shouldPop = velocity > 320 || totalDx > width * 0.16;
        if (shouldPop) {
          if (!Navigator.of(context).canPop()) {
            _releaseDriver(allowSnapBack: true);
            return;
          }
          _popRequested = true;
          _gestureDriver = null;
          driver.dragEnd(shouldPop: true);
          return;
        }
        _releaseDriver(allowSnapBack: true);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.maybeOf(context);
  }

  @override
  void dispose() {
    _releaseDriver(allowSnapBack: false);
    final nav = _navigator;
    if (nav != null && nav.mounted && nav.userGestureInProgress) {
      nav.didStopUserGesture();
    }
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = RepaintBoundary(child: widget.child);
    // Keep this wrapper structurally stable for the whole route lifetime.
    // When the push transition completes, [_gestureAllowed] changes from false
    // to true. Returning a bare [content] before that point and a [Stack]
    // afterwards reparents the entire chat subtree, which deactivates the
    // history list precisely when its first history request is completing.
    final gestureEnabled = _gestureAllowed() || _gestureDriver != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: widget.edgeStartWidthPx,
          child: IgnorePointer(
            ignoring: !gestureEnabled,
            child: RawGestureDetector(
              behavior: HitTestBehavior.translucent,
              gestures: {
                _FullScreenBackRecognizer:
                    GestureRecognizerFactoryWithHandlers<_FullScreenBackRecognizer>(
                  () => _recognizer,
                  (_) {},
                ),
              },
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullScreenBackRecognizer extends OneSequenceGestureRecognizer {
  _FullScreenBackRecognizer({
    required this.onAccepted,
    required this.onDelta,
    required this.onEnd,
  });

  final VoidCallback onAccepted;
  final void Function(double deltaDx) onDelta;
  final void Function(double totalDx, double velocity) onEnd;

  Offset? _startGlobal;
  bool _accepted = false;
  double _totalDx = 0.0;
  final VelocityTracker _tracker = VelocityTracker.withKind(
    PointerDeviceKind.touch,
  );

  static const double _minDistance = 0.1;

  @override
  void addPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer);
    _startGlobal = event.position;
    _accepted = false;
    _totalDx = 0.0;
    _tracker.addPosition(event.timeStamp, event.position);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _tracker.addPosition(event.timeStamp, event.position);
      if (_startGlobal == null) return;
      final delta = event.position - _startGlobal!;
      final dx = delta.dx;
      final dy = delta.dy.abs();

      if (!_accepted) {
        final movedEnough = delta.distance >= _minDistance;
        final isRight = dx > 0;
        final horizontalDominant = dx.abs() > dy * 0.8;

        if (movedEnough && isRight && horizontalDominant) {
          _accepted = true;
          resolve(GestureDisposition.accepted);
          onAccepted();
        } else if (movedEnough && !horizontalDominant) {
          resolve(GestureDisposition.rejected);
          stopTrackingPointer(event.pointer);
        } else if (movedEnough && !isRight && horizontalDominant) {
          resolve(GestureDisposition.rejected);
          stopTrackingPointer(event.pointer);
        }
      }

      if (_accepted) {
        _totalDx += event.delta.dx;
        onDelta(event.delta.dx);
      }
    } else if (event is PointerUpEvent) {
      final vx = _tracker.getVelocity().pixelsPerSecond.dx;
      if (_accepted) {
        onEnd(_totalDx, vx);
      } else {
        // 轻点（如点返回键）必须 reject，否则手势竞技场一直占着指针，
        // 左侧边缘条带会吞掉 AppBar 返回按钮的点击。
        resolve(GestureDisposition.rejected);
      }
      stopTrackingPointer(event.pointer);
      _accepted = false;
      _startGlobal = null;
      _totalDx = 0.0;
    } else if (event is PointerCancelEvent) {
      if (_accepted) {
        onEnd(_totalDx, _tracker.getVelocity().pixelsPerSecond.dx);
      } else {
        resolve(GestureDisposition.rejected);
      }
      stopTrackingPointer(event.pointer);
      _accepted = false;
      _startGlobal = null;
      _totalDx = 0.0;
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void acceptGesture(int pointer) {
    // Arena 已 accepted；保持跟踪，由 handleEvent 继续收 move/up。
  }

  @override
  void rejectGesture(int pointer) {
    // 竞技场败北时必须松手，否则会吞掉后续点击/滚动，表现为进页后手势全死。
    stopTrackingPointer(pointer);
    _accepted = false;
    _startGlobal = null;
    _totalDx = 0.0;
  }

  @override
  String get debugDescription => 'FullScreenBack';
}
