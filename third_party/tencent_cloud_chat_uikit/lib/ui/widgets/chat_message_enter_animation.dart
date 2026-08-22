import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_chat_config.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_message_input_anchor.dart';

/// 从 [MessageEnterAnimationStyle] 解析单条入场动画参数。
class MessageEnterAnimationParams {
  const MessageEnterAnimationParams({
    required this.duration,
    required this.slideCurve,
    required this.slideDistance,
    required this.startOpacity,
    required this.slideFromInputAnchor,
    required this.useOpacityFade,
    this.slideBelowInputOffset = 0,
  });

  final Duration duration;
  final Curve slideCurve;
  final double slideDistance;
  final double startOpacity;
  final bool slideFromInputAnchor;
  final bool useOpacityFade;

  /// 在输入区底边之外再下移的起笔偏移；≤0 表示自动取消息高度。
  final double slideBelowInputOffset;

  factory MessageEnterAnimationParams.fromStyle(
    MessageEnterAnimationStyle style, {
    bool isOutgoing = false,
  }) {
    switch (style) {
      case MessageEnterAnimationStyle.telegram:
        return MessageEnterAnimationParams(
          duration: Duration(milliseconds: isOutgoing ? 320 : 400),
          slideCurve: isOutgoing ? Curves.easeOutCubic : Curves.easeOutBack,
          slideDistance: 64,
          startOpacity: 0.06,
          slideFromInputAnchor: true,
          useOpacityFade: true,
        );
      case MessageEnterAnimationStyle.wechat:
        return const MessageEnterAnimationParams(
          duration: Duration(milliseconds: 240),
          slideCurve: Curves.easeOutCubic,
          slideDistance: 64,
          startOpacity: 0.82,
          slideFromInputAnchor: true,
          useOpacityFade: true,
        );
    }
  }
}

/// 新消息入场动画。微信风格与 Telegram 风格参数见 [MessageEnterAnimationParams]。
class ChatMessageEnterAnimation extends StatefulWidget {
  const ChatMessageEnterAnimation({
    super.key,
    required this.child,
    required this.onFinished,
    this.enabled = true,
    this.fallbackSlideDistance = 64,
    this.startOpacity = 0.06,
    this.slideFromInputAnchor = true,
    this.useOpacityFade = true,
    this.duration = const Duration(milliseconds: 680),
    this.slideCurve = Curves.easeOutCubic,
    this.listPushSlideDistance,
    this.slideBelowInputOffset = 0,
    this.animateExtent = false,
    this.extentCurve = Curves.easeInOutCubic,
  });

  final Widget child;
  final VoidCallback onFinished;
  final bool enabled;

  /// 无法测量输入框时的回退位移（像素）。
  final double fallbackSlideDistance;
  final double startOpacity;
  final bool slideFromInputAnchor;
  final bool useOpacityFade;
  final Duration duration;
  final Curve slideCurve;

  /// 与列表 list-push 同步的位移（微信模式传入，使新旧消息同速顶起）。
  final double? listPushSlideDistance;

  /// 起笔点在输入区底边之外再下移的像素；≤0 时自动取消息高度。
  final double slideBelowInputOffset;

  /// 从底部展开行高，让旧消息随布局平滑上移而非瞬间跳位。
  final bool animateExtent;
  final Curve extentCurve;

  @override
  State<ChatMessageEnterAnimation> createState() =>
      _ChatMessageEnterAnimationState();
}

class _ChatMessageEnterAnimationState extends State<ChatMessageEnterAnimation>
    with SingleTickerProviderStateMixin {
  final GlobalKey _messageMeasureKey = GlobalKey();
  late final AnimationController _controller;
  Animation<double>? _slideOffsetAnimation;
  Animation<double>? _fadeAnimation;
  bool _finishedNotified = false;
  bool _animationStarted = false;
  double _resolvedSlideDistance = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.addStatusListener(_onStatusChanged);
    if (widget.slideFromInputAnchor) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
    } else {
      _startAnimation(
        widget.listPushSlideDistance ?? widget.fallbackSlideDistance,
      );
    }
  }

  @override
  void didUpdateWidget(ChatMessageEnterAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _notifyFinished();
    }
  }

  void _notifyFinished() {
    if (_finishedNotified) {
      return;
    }
    _finishedNotified = true;
    widget.onFinished();
  }

  double _resolveBelowInputOffset(double messageHeight) {
    if (widget.slideBelowInputOffset > 0) {
      return widget.slideBelowInputOffset;
    }
    return messageHeight.clamp(24.0, 240.0);
  }

  double _resolveSlideDistanceFromBottom() {
    if (!widget.slideFromInputAnchor) {
      return widget.listPushSlideDistance ?? widget.fallbackSlideDistance;
    }
    final anchor = ChatMessageInputAnchor.maybeOf(context);
    final messageBox =
        _messageMeasureKey.currentContext?.findRenderObject() as RenderBox?;
    final inputBox =
        anchor?.inputAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (messageBox == null || inputBox == null || !messageBox.hasSize) {
      return widget.fallbackSlideDistance + 48;
    }

    final messageTop = messageBox.localToGlobal(Offset.zero).dy;
    final messageBottom =
        messageBox.localToGlobal(Offset(0, messageBox.size.height)).dy;
    final chatAreaBottom =
        inputBox.localToGlobal(Offset(0, inputBox.size.height)).dy;
    final belowInputOffset = _resolveBelowInputOffset(messageBox.size.height);

    // 气泡顶边从输入区底边再往下起笔，再滑入最终位置。
    final distance = chatAreaBottom - messageTop + belowInputOffset;
    if (distance <= 0) {
      return widget.fallbackSlideDistance + belowInputOffset;
    }

    final maxSlide = MediaQuery.sizeOf(context).height * 0.9;
    const nearBottomThreshold = 200.0;
    if (chatAreaBottom - messageBottom > nearBottomThreshold) {
      return (widget.fallbackSlideDistance + belowInputOffset)
          .clamp(0, maxSlide);
    }
    return distance.clamp(
      widget.fallbackSlideDistance + belowInputOffset,
      maxSlide,
    );
  }

  void _startAnimation(double slideDistance) {
    if (!mounted || _animationStarted) {
      return;
    }
    _resolvedSlideDistance = widget.enabled ? slideDistance : 0.0;
    final slideCurve = CurvedAnimation(
      parent: _controller,
      curve: widget.slideCurve,
    );
    final fadeCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.85, curve: Curves.easeOut),
    );
    _slideOffsetAnimation = Tween<double>(
      begin: _resolvedSlideDistance,
      end: 0,
    ).animate(slideCurve);
    _fadeAnimation = Tween<double>(
      begin: widget.useOpacityFade ? widget.startOpacity : 1,
      end: 1,
    ).animate(fadeCurve);
    _animationStarted = true;
    if (widget.enabled && _resolvedSlideDistance > 0) {
      _controller.forward(from: 0);
    } else if (widget.enabled && widget.useOpacityFade) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
      _notifyFinished();
    }
    setState(() {});
  }

  void _measureAndStart({int attempt = 0}) {
    if (!mounted || _animationStarted) {
      return;
    }
    final messageBox =
        _messageMeasureKey.currentContext?.findRenderObject() as RenderBox?;
    if (messageBox == null || !messageBox.hasSize) {
      if (attempt < 4) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _measureAndStart(attempt: attempt + 1),
        );
      } else {
        _startAnimation(widget.fallbackSlideDistance + 48);
      }
      return;
    }
    _startAnimation(_resolveSlideDistanceFromBottom());
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    _notifyFinished();
    super.dispose();
  }

  Widget _wrapMeasuredChild(Widget child) {
    return KeyedSubtree(
      key: _messageMeasureKey,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slideAnim = _slideOffsetAnimation;
    final fadeAnim = _fadeAnimation;
    if (!_animationStarted || slideAnim == null || fadeAnim == null) {
      final pendingDistance = widget.slideFromInputAnchor
          ? widget.fallbackSlideDistance + 48
          : (widget.listPushSlideDistance ?? widget.fallbackSlideDistance);
      Widget pending = Transform.translate(
        offset: Offset(0, pendingDistance),
        child: Opacity(
          opacity: widget.useOpacityFade ? widget.startOpacity : 1,
          child: _wrapMeasuredChild(widget.child),
        ),
      );
      if (widget.animateExtent) {
        pending = ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 0,
            child: pending,
          ),
        );
      }
      return pending;
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          Widget animated = Transform.translate(
            offset: Offset(0, slideAnim.value),
            child: child,
          );
          if (widget.useOpacityFade) {
            animated = Opacity(
              opacity: fadeAnim.value.clamp(0, 1),
              child: animated,
            );
          }
          if (widget.animateExtent) {
            animated = ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                // Incoming messages pass a gentle S-curve so existing rows
                // keep moving instead of finishing most of the shift early.
                heightFactor: widget.extentCurve
                    .transform(_controller.value)
                    .clamp(0.0, 1.0)
                    .toDouble(),
                child: animated,
              ),
            );
          }
          return animated;
        },
        child: _wrapMeasuredChild(widget.child),
      ),
    );
  }
}
