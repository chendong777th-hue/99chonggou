import 'package:flutter/material.dart';

/// 首页 AppBar 右上角加号：自定义资源图，支持按 90° 步进顺时针旋转。
class HomeNavPlusIcon extends StatelessWidget {
  const HomeNavPlusIcon({
    super.key,
    required this.turns,
    this.size = 24,
  });

  static const String assetPath = 'assets/home_nav_plus.png';

  /// 旋转圈数，0.25 = 90°。
  final double turns;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: turns,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
