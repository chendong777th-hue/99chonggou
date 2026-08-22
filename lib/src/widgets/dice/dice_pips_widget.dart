import 'package:flutter/material.dart';

/// Classic dice pips face (1–6) drawn with [CustomPainter].
class DicePipsWidget extends StatelessWidget {
  const DicePipsWidget({
    super.key,
    required this.value,
    this.faceColor = const Color(0xFFFFF8F0),
    this.pipColor = const Color(0xFF1A1A1A),
    this.borderColor = const Color(0xFFD0D0D0),
  });

  final int value;
  final Color faceColor;
  final Color pipColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(1, 6);
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: DicePipsPainter(
          value: v,
          faceColor: faceColor,
          pipColor: pipColor,
          borderColor: borderColor,
        ),
      ),
    );
  }
}

class DicePipsPainter extends CustomPainter {
  DicePipsPainter({
    required this.value,
    required this.faceColor,
    required this.pipColor,
    required this.borderColor,
  });

  final int value;
  final Color faceColor;
  final Color pipColor;
  final Color borderColor;

  static const _positions = <int, List<Offset>>{
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.28, 0.28), Offset(0.72, 0.72)],
    3: [Offset(0.28, 0.28), Offset(0.5, 0.5), Offset(0.72, 0.72)],
    4: [
      Offset(0.28, 0.28),
      Offset(0.72, 0.28),
      Offset(0.28, 0.72),
      Offset(0.72, 0.72),
    ],
    5: [
      Offset(0.28, 0.28),
      Offset(0.72, 0.28),
      Offset(0.5, 0.5),
      Offset(0.28, 0.72),
      Offset(0.72, 0.72),
    ],
    6: [
      Offset(0.28, 0.28),
      Offset(0.72, 0.28),
      Offset(0.28, 0.5),
      Offset(0.72, 0.5),
      Offset(0.28, 0.72),
      Offset(0.72, 0.72),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    final radius = side * 0.16;
    final facePaint = Paint()..color = faceColor;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.03;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, facePaint);
    canvas.drawRRect(rrect, borderPaint);

    final pipRadius = side * 0.09;
    final pipPaint = Paint()..color = pipColor;
    final points = _positions[value] ?? _positions[1]!;
    for (final p in points) {
      canvas.drawCircle(
        Offset(rect.left + p.dx * rect.width, rect.top + p.dy * rect.height),
        pipRadius,
        pipPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DicePipsPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.faceColor != faceColor ||
        oldDelegate.pipColor != pipColor ||
        oldDelegate.borderColor != borderColor;
  }
}
