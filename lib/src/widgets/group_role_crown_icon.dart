import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

const _kViewBox = 1024.0;

/// 皇冠 SVG 底栏路径（原 #FFAA22，由 [color] 渲染）。
const _crownBasePathData =
    'M816.49 909H211.21c-1.1 0-2-0.9-2-2v-68.18c0-1.1 0.9-2 2-2h605.28c1.1 0 2 0.9 2 2V907c0 1.1-0.9 2-2 2z';

/// 皇冠 SVG 主体路径（原 #FFD68D，由 [highlightColor] 渲染）。
const _crownBodyPathData =
    'M910.24 316.23c-27.11 0-49.1 22.52-49.1 50.31 0 7.28 1.58 14.16 4.3 20.4l-176.13 80.21-147.2-258.57c14.56-8.73 24.46-24.74 24.46-43.28 0-27.79-21.98-50.31-49.1-50.31s-49.1 22.52-49.1 50.31c0 17.99 9.29 33.66 23.15 42.55l-158.16 259.3-176.13-80.21c2.71-6.25 4.3-13.12 4.3-20.4 0-27.78-21.98-50.31-49.1-50.31s-49.1 22.52-49.1 50.31c0 27.78 21.98 50.31 49.1 50.31 3.99 0 7.82-0.62 11.53-1.54l86.65 366.28h601.43l86.65-366.28c3.71 0.92 7.54 1.54 11.53 1.54 27.12 0 49.1-22.52 49.1-50.31 0.01-27.78-21.97-50.31-49.08-50.31z';

Path? _cachedBasePath;
Path? _cachedBodyPath;

Path _basePath() =>
    _cachedBasePath ??= parseSvgPathData(_crownBasePathData);

Path _bodyPath() =>
    _cachedBodyPath ??= parseSvgPathData(_crownBodyPathData);

/// 群主徽章皇冠图标，基于 SVG 路径，颜色由调用方传入。
class GroupRoleCrownIcon extends StatelessWidget {
  final Color color;
  final Color? highlightColor;
  final double size;

  const GroupRoleCrownIcon({
    super.key,
    required this.color,
    this.highlightColor,
    this.size = 13,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GroupRoleCrownPainter(
        color: color,
        highlightColor: highlightColor,
      ),
    );
  }
}

class _GroupRoleCrownPainter extends CustomPainter {
  _GroupRoleCrownPainter({
    required this.color,
    Color? highlightColor,
  }) : highlightColor =
            highlightColor ?? Color.lerp(color, Colors.white, 0.42) ?? color;

  final Color color;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _kViewBox;
    canvas.scale(scale, scale);

    final basePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final bodyPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(_basePath(), basePaint);
    canvas.drawPath(_bodyPath(), bodyPaint);
  }

  @override
  bool shouldRepaint(covariant _GroupRoleCrownPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.highlightColor != highlightColor;
  }
}
