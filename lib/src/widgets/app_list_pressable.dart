import 'package:flutter/material.dart';

/// 列表行点击反馈，与群聊列表 [TIMUIKitGroup] 一致的标准 Material 水波纹。
class AppListPressable extends StatelessWidget {
  const AppListPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.onLongPress,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final VoidCallback? onLongPress;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onTapDown: onTapDown,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }
}
