import 'dart:ui';

import 'package:flutter/material.dart';

/// iOS Messages 风格：发送时临时浮层气泡从输入区飞到列表目标位。
class ChatSendFlyOverlay extends StatefulWidget {
  const ChatSendFlyOverlay({
    super.key,
    required this.text,
    required this.start,
    required this.end,
    required this.backgroundColor,
    required this.textColor,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 180),
  });

  final String text;
  final Rect start;
  final Rect end;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onFinished;
  final Duration duration;

  @override
  State<ChatSendFlyOverlay> createState() => _ChatSendFlyOverlayState();
}

class _ChatSendFlyOverlayState extends State<ChatSendFlyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onFinished();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final left = lerpDouble(widget.start.left, widget.end.left, t)!;
        final top = lerpDouble(widget.start.top, widget.end.top, t)!;
        final width = lerpDouble(widget.start.width, widget.end.width, t)!;
        final height = lerpDouble(widget.start.height, widget.end.height, t)!;
        final opacity = lerpDouble(0.92, 1, t)!;
        return Positioned(
          left: left,
          top: top,
          width: width,
          child: Opacity(
            opacity: opacity,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(minHeight: height),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(2),
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ChatSendFlyOverlayHost extends StatelessWidget {
  const ChatSendFlyOverlayHost({
    super.key,
    required this.request,
    required this.inputAnchorKey,
    required this.onFinished,
    this.backgroundColor = const Color(0xFF95EC69),
    this.textColor = const Color(0xFF111111),
    this.duration = const Duration(milliseconds: 180),
  });

  final ChatSendFlyOverlayRequest? request;
  final GlobalKey inputAnchorKey;
  final VoidCallback onFinished;
  final Color backgroundColor;
  final Color textColor;
  final Duration duration;

  Rect? _inputStartRect() {
    final box =
        inputAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    final offset = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      offset.dx + 48,
      offset.dy + 6,
      box.size.width - 96,
      40,
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = request;
    if (req == null || req.targetRect == null) {
      return const SizedBox.shrink();
    }
    final start = _inputStartRect();
    final end = req.targetRect;
    if (start == null || end == null) {
      return const SizedBox.shrink();
    }
    return ChatSendFlyOverlay(
      text: req.text,
      start: start,
      end: end,
      backgroundColor: backgroundColor,
      textColor: textColor,
      duration: duration,
      onFinished: onFinished,
    );
  }
}

class ChatSendFlyOverlayRequest {
  const ChatSendFlyOverlayRequest({
    required this.messageKey,
    required this.text,
    required this.conversationId,
    this.targetRect,
  });

  final String messageKey;
  final String text;
  final String conversationId;
  final Rect? targetRect;

  ChatSendFlyOverlayRequest copyWith({Rect? targetRect}) {
    return ChatSendFlyOverlayRequest(
      messageKey: messageKey,
      text: text,
      conversationId: conversationId,
      targetRect: targetRect ?? this.targetRect,
    );
  }
}
