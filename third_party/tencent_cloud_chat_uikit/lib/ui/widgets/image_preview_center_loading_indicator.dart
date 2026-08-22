import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 全屏图片预览居中加载：白环 + 扇形填充，对齐 iOS 相册式加载反馈。
class ImagePreviewCenterLoadingIndicator extends StatefulWidget {
  const ImagePreviewCenterLoadingIndicator({
    super.key,
    this.size = 52,
    this.strokeWidth = 2.4,
    this.progress,
  });

  final double size;
  final double strokeWidth;

  /// `null` 为不确定进度动画；`0..1` 为确定进度。
  final double? progress;

  @override
  State<ImagePreviewCenterLoadingIndicator> createState() =>
      _ImagePreviewCenterLoadingIndicatorState();
}

class _ImagePreviewCenterLoadingIndicatorState
    extends State<ImagePreviewCenterLoadingIndicator>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.progress == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(ImagePreviewCenterLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress == null && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..repeat();
    } else if (widget.progress != null && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indicatorSize = Size.square(widget.size);
    if (widget.progress != null) {
      return SizedBox.fromSize(
        size: indicatorSize,
        child: CustomPaint(
          size: indicatorSize,
          painter: _ImagePreviewLoadingPainter(
            progress: widget.progress!.clamp(0.0, 1.0),
            rotation: 0,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final rotation = t;
        final sweep = 0.18 + 0.16 * math.sin(t * math.pi * 2);
        return SizedBox.fromSize(
          size: indicatorSize,
          child: CustomPaint(
            size: indicatorSize,
            painter: _ImagePreviewLoadingPainter(
              progress: sweep,
              rotation: rotation,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        );
      },
    );
  }
}

class _ImagePreviewLoadingPainter extends CustomPainter {
  const _ImagePreviewLoadingPainter({
    required this.progress,
    required this.rotation,
    required this.strokeWidth,
  });

  final double progress;
  final double rotation;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = (size.width * 0.5) - strokeWidth;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final clamped = progress.clamp(0.04, 0.92);
    final startAngle = -math.pi / 2 + rotation * math.pi * 2;
    final sweepAngle = math.pi * 2 * clamped;

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final fillPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
      )
      ..close();
    canvas.drawPath(fillPath, fillPaint);

    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ImagePreviewLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rotation != rotation ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// 全屏预览加载层：先铺底图（气泡缩略图），再叠居中扇形指示器。
class ImagePreviewLoadingLayer extends StatelessWidget {
  const ImagePreviewLoadingLayer({
    super.key,
    this.placeholder,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.progress,
    this.showSpinner = true,
  });

  final ImageProvider? placeholder;
  final BoxFit fit;
  final Alignment alignment;
  final double? progress;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (placeholder != null)
          Image(
            image: placeholder!,
            fit: fit,
            alignment: alignment,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            // 内存命中时首帧即显示，避免底图未就绪时先黑一拍。
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                return child;
              }
              return const SizedBox.expand();
            },
          ),
        if (showSpinner)
          Center(
            child: ImagePreviewCenterLoadingIndicator(progress: progress),
          ),
      ],
    );
  }
}
