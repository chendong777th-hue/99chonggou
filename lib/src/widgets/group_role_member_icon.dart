import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

const _kViewBox = 1024.0;

const _memberHeadPathData =
    'M401.1 312.7m-193.8 0a193.8 193.8 0 1 0 387.6 0 193.8 193.8 0 1 0-387.6 0Z';

const _memberBodyAndPeerPathData =
    'M738.9 833.2c0 169.3-675.5 169.3-675.5 0S214.6 562 401.1 562s337.8 101.9 337.8 271.2zM644.7 63.5c-47.2 0-90.4 16.9-124 44.9 75.3 36.5 127.4 113.5 127.4 202.9 0 50.8-17 97.5-45.3 135.2 13.5 3 27.4 4.6 41.8 4.6 107 0 193.8-86.8 193.8-193.8S751.8 63.5 644.7 63.5z';

const _memberPeerBodyPathData =
    'M622.6 513.2c-20.4 0-83.1 6.1-104.2 16.1 131.8 26.8 275.1 129.3 275.1 293.1 0 25.6-10.4 48.2-28.7 67.9 110.1-18 195.5-58.2 195.5-120.6 0.1-175.4-151.2-256.5-337.7-256.5z';

Path? _cachedHeadPath;
Path? _cachedBodyAndPeerPath;
Path? _cachedPeerBodyPath;

Path _headPath() =>
    _cachedHeadPath ??= parseSvgPathData(_memberHeadPathData);

Path _bodyAndPeerPath() =>
    _cachedBodyAndPeerPath ??= parseSvgPathData(_memberBodyAndPeerPathData);

Path _peerBodyPath() =>
    _cachedPeerBodyPath ??= parseSvgPathData(_memberPeerBodyPathData);

/// 普通成员徽章图标，基于 SVG 路径，颜色由调用方传入。
class GroupRoleMemberIcon extends StatelessWidget {
  final Color color;
  final double size;

  const GroupRoleMemberIcon({
    super.key,
    required this.color,
    this.size = 13,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GroupRoleMemberPainter(color: color),
    );
  }
}

class _GroupRoleMemberPainter extends CustomPainter {
  _GroupRoleMemberPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _kViewBox;
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(_headPath(), paint);
    canvas.drawPath(_bodyAndPeerPath(), paint);
    canvas.drawPath(_peerBodyPath(), paint);
  }

  @override
  bool shouldRepaint(covariant _GroupRoleMemberPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
