import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_theme.dart';

/// 页面底部柔和波浪装饰。
class LifePaymentWaveDecoration extends StatelessWidget {
  const LifePaymentWaveDecoration({
    super.key,
    required this.dark,
    this.height = 120,
  });

  final bool dark;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(
          color: LifePaymentTheme.accent(dark).withValues(alpha: dark ? 0.08 : 0.06),
          secondary: LifePaymentTheme.accent(dark).withValues(alpha: dark ? 0.04 : 0.03),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.color, required this.secondary});

  final Color color;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color;
    final paint2 = Paint()..color = secondary;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.55);
    for (var x = 0.0; x <= size.width; x += 4) {
      final y = size.height * 0.55 +
          math.sin((x / size.width) * math.pi * 2) * 10;
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.72);
    for (var x = 0.0; x <= size.width; x += 4) {
      final y = size.height * 0.72 +
          math.sin((x / size.width) * math.pi * 2 + 1.2) * 7;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => false;
}

/// 右上角点阵纹理装饰。
class LifePaymentDotTexture extends StatelessWidget {
  const LifePaymentDotTexture({super.key, required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: dark ? 0.35 : 0.55,
        child: SvgPicture.asset(
          'assets/life_payment/bg_dots.svg',
          width: 96,
          height: 96,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// 左侧时间轴竖线装饰（缴费记录用）。
class LifePaymentTimelineRail extends StatelessWidget {
  const LifePaymentTimelineRail({
    super.key,
    required this.dark,
    required this.color,
    this.isLast = false,
  });

  final bool dark;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Column(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: LifePaymentTheme.inkFaint.withValues(alpha: dark ? 0.25 : 0.45),
              ),
            ),
        ],
      ),
    );
  }
}
