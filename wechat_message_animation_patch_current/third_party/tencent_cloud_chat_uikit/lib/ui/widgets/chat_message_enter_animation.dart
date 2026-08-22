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
  });

  final Duration duration;
  final Curve slideCurve;
  final double slideDistance;
  final double startOpacity;
  final bool slideFromInputAnchor;

  factory MessageEnterAnimationParams.fromStyle(
    MessageEnterAnimationStyle style,
  ) {
    switch (style) {
      case MessageEnterAnimationStyle.telegram:
        return const MessageEnterAnimationParams(
          duration: Duration(milliseconds: 400),
          slideCurve: Curves.easeOutBack,
          slideDistance: 64,
          startOpacity: 0.06,
          slideFromInputAnchor: true,
        );
      case MessageEnterAnimationStyle.wechat:
        return const MessageEnterAnimationParams(
          duration: Duration(milliseconds: 240),
          slideCurve: Curves.easeOutCubic,
          slideDistance: 16,
          startOpacity: 0.82,
          slideFromInputAnchor: false,
        );
    }
  }
}

/// 消息顶边从聊天区最底部（输入区底边）向上滑入并淡入（发送与接收一致）。
class ChatMessageEnterAnimation extends StatefulWidget {
  const ChatMessageEnterAnimation({
    super.key,
    required this.child,
    required this.onFinished,
    this.enabled = true,
    this.fallbackSlideDistance = 64,
    this.startOpacity = 0.06,
    this.slideFromInputAnchor = true,
    this.duration = const Duration(milliseconds: 680),
    this.slideCurve = Curves.easeOutCubic,
  });

  final Widget child;
  final VoidCallback onFinished;
  final bool enabled;

  /// 无法测量输入框时的回退位移（像素）。
  final double fallbackSlideDistance;
  final double startOpacity;
  final bool slideFromInputAnchor;
  final Duration duration;
  final Curve slideCurve;

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.addStatusListener(_onStatusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
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

  double _resolveSlideDistanceFromBottom() {
    if (!widget.slideFromInputAnchor) {
      return widget.fallbackSlideDistance;
    }
    final anchor = ChatMessageInputAnchor.maybeOf(context);
    final messageBox =
        _messageMeasureKey.currentContext?.findRenderObject() as RenderBox?;
    final inputBox = anchor?.inputAnchorKey.currentContext
        ?.findRenderObject() as RenderBox?;
    if (messageBox == null || inputBox == null || !messageBox.hasSize) {
      return widget.fallbackSlideDistance;
    }

    final messageTop = messageBox.localToGlobal(Offset.zero).dy;
    final messageBottom =
        messageBox.localToGlobal(Offset(0, messageBox.size.height)).dy;
    // 聊天列最底边 = 输入区底边（含工具栏/安全区）
    final chatAreaBottom =
        inputBox.localToGlobal(Offset(0, inputBox.size.height)).dy;

    // 消息顶边起点对齐最底边，再动画到列表中的最终位置（translateY → 0 即向上滑出）。
    final distance = chatAreaBottom - messageTop;
    if (distance <= 0) {
      return widget.fallbackSlideDistance;
    }

    final maxSlide = MediaQuery.sizeOf(context).height * 0.9;
    // 远离底部的消息（例如在未读分隔上方）不做整屏位移，避免飞入感过强
    const nearBottomThreshold = 200.0;
    if (chatAreaBottom - messageBottom > nearBottomThreshold) {
      return widget.fallbackSlideDistance.clamp(0, maxSlide);
    }
    return distance.clamp(widget.fallbackSlideDistance, maxSlide);
  }

  void _measureAndStart() {
    if (!mounted || _animationStarted) {
      return;
    }
    final slideDistance = widget.enabled
        ? _resolveSlideDistanceFromBottom()
        : 0.0;
    final slideCurve = CurvedAnimation(
      parent: _controller,
      curve: widget.slideCurve,
    );
    final fadeCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.92, curve: Curves.easeOut),
    );
    _slideOffsetAnimation = Tween<double>(
      begin: slideDistance,
      end: 0,
    ).animate(slideCurve);
    _fadeAnimation = Tween<double>(
      begin: widget.startOpacity,
      end: 1,
    ).animate(fadeCurve);
    _animationStarted = true;
    if (widget.enabled) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
      _notifyFinished();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    _notifyFinished();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slideAnim = _slideOffsetAnimation;
    final fadeAnim = _fadeAnimation;
    if (!_animationStarted || slideAnim == null || fadeAnim == null) {
      return KeyedSubtree(
        key: _messageMeasureKey,
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: fadeAnim.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, slideAnim.value),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: _messageMeasureKey,
        child: widget.child,
      ),
    );
  }
}
