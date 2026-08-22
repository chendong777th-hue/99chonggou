import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_resolution_utils.dart';

/// 原图加载完成后，以屏幕中心为原点顺时针扇形展开。
class ImagePreviewOriginalFanReveal extends StatelessWidget {
  const ImagePreviewOriginalFanReveal({
    required this.imageProvider,
    required this.display,
    required this.progress,
    super.key,
  });

  final ImageProvider imageProvider;
  final ImagePreviewDisplayConfig display;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        return ClipPath(
          clipper: _FanRevealClipper(progress: progress.value),
          child: child,
        );
      },
      child: Image(
        image: imageProvider,
        fit: display.fit,
        alignment: display.alignment,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      ),
    );
  }
}

class _FanRevealClipper extends CustomClipper<Path> {
  const _FanRevealClipper({required this.progress});

  final double progress;

  @override
  Path getClip(Size size) {
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0) {
      return Path();
    }
    if (clamped >= 1) {
      return Path()..addRect(Offset.zero & size);
    }

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * clamped,
        false,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _FanRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
