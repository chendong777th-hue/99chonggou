import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:tencent_cloud_chat_uikit/ui/utils/chat_jitter_diag.dart';

import 'app_route_lifecycle.dart';
import 'route_visibility.dart';

/// 根据路由转场状态向子树广播可见性；恢复可见时延后若干帧再启用 [TickerMode]。
///
/// 注意：转场 [Animation] 每帧都会回调 listener。若每次回调都重新
/// `++generation` 再 schedule，会把「延后可见」一直取消到动画结束（约 300ms），
/// 进聊天页就会出现整页晚亮 + 列表/头像/图片一起爆发的抖动。
class RouteVisibilityHost extends StatefulWidget {
  final Widget child;
  final int deferredFrameCount;

  const RouteVisibilityHost({
    super.key,
    required this.child,
    this.deferredFrameCount = 1,
  });

  @override
  State<RouteVisibilityHost> createState() => _RouteVisibilityHostState();
}

class _RouteVisibilityHostState extends State<RouteVisibilityHost> {
  bool _isVisible = false;
  bool _enableScheduled = false;
  int _enableGeneration = 0;
  int _cancelledDeferredCount = 0;
  Animation<double>? _animation;
  Animation<double>? _secondaryAnimation;
  VoidCallback? _animationListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindRouteAnimations();
    _applyVisibilityTarget();
  }

  @override
  void dispose() {
    _unbindRouteAnimations();
    super.dispose();
  }

  void _bindRouteAnimations() {
    final route = ModalRoute.of(context);
    if (route == null) {
      return;
    }
    if (_animation == route.animation &&
        _secondaryAnimation == route.secondaryAnimation) {
      return;
    }
    _unbindRouteAnimations();
    _animation = route.animation;
    _secondaryAnimation = route.secondaryAnimation;
    _animationListener = _applyVisibilityTarget;
    _animation?.addListener(_animationListener!);
    _secondaryAnimation?.addListener(_animationListener!);
  }

  void _unbindRouteAnimations() {
    final listener = _animationListener;
    if (listener != null) {
      _animation?.removeListener(listener);
      _secondaryAnimation?.removeListener(listener);
    }
    _animationListener = null;
    _animation = null;
    _secondaryAnimation = null;
  }

  bool _targetVisible() => routeAcceptsUserInput(context);

  Map<String, Object?> _routeAnimExtras() {
    final anim = _animation;
    return <String, Object?>{
      'animStatus': anim?.status.name,
      'animValue': anim?.value.toStringAsFixed(3),
      'phase': SchedulerBinding.instance.schedulerPhase.name,
      'enableScheduled': _enableScheduled,
      'gen': _enableGeneration,
      'cancelledDeferred': _cancelledDeferredCount,
    };
  }

  void _applyVisibilityTarget() {
    if (!mounted) {
      return;
    }
    final target = _targetVisible();
    if (!target) {
      if (_enableScheduled || _isVisible) {
        ChatJitterDiag.log(
          'route_visible_target',
          extras: <String, Object?>{
            'target': false,
            'wasVisible': _isVisible,
            'wasScheduled': _enableScheduled,
            ..._routeAnimExtras(),
          },
        );
      }
      _enableGeneration++;
      _enableScheduled = false;
      if (_isVisible) {
        ChatJitterDiag.logRouteVisible(
          visible: false,
          source: 'route_visibility_host',
        );
        setState(() => _isVisible = false);
      }
      return;
    }

    // 已可见：动画帧继续 tick 时不要反复打日志/重入。
    if (_isVisible) {
      return;
    }

    // Web 零时长转场：不再延后一帧，避免 generation 被动画 tick 取消导致首帧空白。
    if (widget.deferredFrameCount <= 0) {
      ChatJitterDiag.logRouteVisible(
        visible: true,
        source: 'route_visibility_host',
        deferredFrames: 0,
      );
      _enableScheduled = false;
      setState(() => _isVisible = true);
      return;
    }

    // 关键：转场动画每帧都会进这里；已有 pending 延后启用时绝不能再 ++generation。
    if (_enableScheduled) {
      return;
    }

    ChatJitterDiag.log(
      'route_visible_schedule',
      extras: <String, Object?>{
        'deferredFrames': widget.deferredFrameCount,
        ..._routeAnimExtras(),
      },
    );
    _scheduleDeferredEnable();
  }

  void _scheduleDeferredEnable() {
    _enableScheduled = true;
    final generation = ++_enableGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (generation != _enableGeneration) {
        _cancelledDeferredCount++;
        ChatJitterDiag.log(
          'route_visible_cancel',
          extras: <String, Object?>{
            'reason': 'generation_mismatch',
            'expectedGen': generation,
            'currentGen': _enableGeneration,
            'cancelledDeferred': _cancelledDeferredCount,
            ..._routeAnimExtras(),
          },
        );
        return;
      }
      _enableAfterDeferredFrames(
        generation: generation,
        remainingFrames: widget.deferredFrameCount,
      );
    });
  }

  void _enableAfterDeferredFrames({
    required int generation,
    required int remainingFrames,
  }) {
    if (!mounted || generation != _enableGeneration) {
      if (generation != _enableGeneration) {
        _cancelledDeferredCount++;
        _enableScheduled = false;
        ChatJitterDiag.log(
          'route_visible_cancel',
          extras: <String, Object?>{
            'reason': 'generation_mismatch_frame',
            'remainingFrames': remainingFrames,
            'expectedGen': generation,
            'currentGen': _enableGeneration,
            'cancelledDeferred': _cancelledDeferredCount,
            ..._routeAnimExtras(),
          },
        );
      }
      return;
    }
    if (!_targetVisible()) {
      _enableScheduled = false;
      return;
    }
    if (_isVisible) {
      _enableScheduled = false;
      return;
    }
    if (remainingFrames <= 0) {
      ChatJitterDiag.logRouteVisible(
        visible: true,
        source: 'route_visibility_host',
        deferredFrames: widget.deferredFrameCount,
      );
      ChatJitterDiag.log(
        'route_visible_enabled',
        extras: _routeAnimExtras(),
      );
      _enableScheduled = false;
      setState(() => _isVisible = true);
      return;
    }
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _enableAfterDeferredFrames(
        generation: generation,
        remainingFrames: remainingFrames - 1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return RouteVisibility(
      isVisible: _isVisible,
      child: widget.child,
    );
  }
}
