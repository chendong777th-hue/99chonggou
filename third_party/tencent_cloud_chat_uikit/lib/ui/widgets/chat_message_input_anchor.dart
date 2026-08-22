import 'package:flutter/material.dart';

/// 聊天页输入区锚点，供消息入场动画对齐到聊天列最底边（输入区底边）。
class ChatMessageInputAnchor extends InheritedWidget {
  const ChatMessageInputAnchor({
    super.key,
    required this.inputAnchorKey,
    required super.child,
  });

  final GlobalKey inputAnchorKey;

  static ChatMessageInputAnchor? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ChatMessageInputAnchor>();
  }

  @override
  bool updateShouldNotify(ChatMessageInputAnchor oldWidget) {
    return inputAnchorKey != oldWidget.inputAnchorKey;
  }
}

/// 聊天页键盘底部占位（输入栏下方），由 [TIMUIKitChat] 统一计算并下发，
/// 保证消息列表与输入栏在同一帧使用相同的键盘几何。
class ChatKeyboardLayoutScope extends InheritedWidget {
  const ChatKeyboardLayoutScope({
    super.key,
    required this.bottomInset,
    required this.layoutEpoch,
    required super.child,
  });

  /// 系统键盘在输入栏下方的有效占位高度。
  final double bottomInset;

  /// 每次键盘几何变化递增，确保依赖方同帧刷新。
  final int layoutEpoch;

  static ChatKeyboardLayoutScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ChatKeyboardLayoutScope>();
  }

  static double bottomInsetOf(BuildContext context) {
    return maybeOf(context)?.bottomInset ?? 0;
  }

  @override
  bool updateShouldNotify(ChatKeyboardLayoutScope oldWidget) {
    return layoutEpoch != oldWidget.layoutEpoch ||
        (bottomInset - oldWidget.bottomInset).abs() > 0.5;
  }
}
