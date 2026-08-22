import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

const _kViewBox = 1024.0;

/// 超级大群火焰路径（源 SVG fill=#F55522）。
const _flamePathData =
    'M848.887 606.917C734.191 357.827 808.188 277.93 808.988 277.03c1.29995-1.29995 1.39994-3.29987 0.49998-4.89981-0.99996-1.49994-2.99988-2.09992-4.79981-1.39994-1.69993 0.599976-161.294 67.2973-141.194 215.191C619.696 446.423 415.204 243.931 540.399 5.8406c0.799968-1.49994 0.49998-3.29987-0.599976-4.49982-1.09996-1.29995-2.89988-1.69993-4.39983-0.99996-2.69989 1.09996-66.4974 28.4989-117.395 97.5961-46.8981 63.5975-90.5964 176.193-31.7987 350.386 21.3991 81.8967-18.8992 148.394-40.5984 176.593 5.29979-19.4992 11.9995-52.3979 10.8996-90.1964-1.69993-55.2978-21.5991-131.795-106.696-181.293-1.29995-0.799968-2.99988-0.699972-4.29983 0.199992-1.29995 0.99996-1.89992 2.4999-1.49994 4.09984 0.299988 1.39994 32.0987 146.994-23.6991 214.391-48.1981 58.1977-95.3962 159.294-69.8972 252.99 21.3991 78.2969 88.2965 138.094 198.792 177.693 28.2989 8.69965 55.4978 15.3994 85.4966 20.9992 1.89992 0.399984 3.89984-0.799968 4.49982-2.5999 0.49998-1.99992-0.399984-4.09984-2.19991-4.89981-56.7977-24.699-115.295-76.097-71.7971-180.493 41.3983-89.9964 33.9986-136.395 25.699-156.294 21.3991 12.0995 63.8975 43.4983 53.2979 98.6961-0.299988 1.59994 0.399984 3.29987 1.79993 4.09984 1.39994 0.899964 3.19987 0.799968 4.49982-0.299988 1.39994-0.99996 129.195-106.596 71.0972-235.891 28.5989 16.5993 104.596 74.497 59.7976 207.492-14.8994 57.1977 25.699 98.2961 27.3989 100.096 1.39994 1.29995 3.39986 1.59994 4.9998 0.49998 1.49994-0.899964 2.09992-2.89988 1.39994-4.69981-1.29995-3.59986-31.5987-85.3966 34.0986-130.595-3.49986 20.9992-8.99964 72.9971 14.4994 101.296 21.0992 25.499 41.4983 67.2973 35.2986 108.196-4.39983 28.6989-21.2992 52.8979-50.498 71.8971-1.69993 1.19995-2.29991 3.19987-1.39994 5.0998 0.799968 1.79993 2.89988 2.5999 4.79981 2.09992 72.1971-23.999 166.793-71.4971 207.992-162.194C890.785 778.41 886.985 698.213 848.887 606.917Z';

Path? _cachedFlamePath;

Path _flamePath() => _cachedFlamePath ??= parseSvgPathData(_flamePathData);

/// 超级大群昵称后火焰图标（#F55522）。
class SuperLargeGroupFlameIcon extends StatelessWidget {
  static const Color flameColor = Color(0xFFF55522);

  final double size;
  final Color color;

  const SuperLargeGroupFlameIcon({
    super.key,
    this.size = 14,
    this.color = flameColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SuperLargeGroupFlamePainter(color: color),
    );
  }
}

class _SuperLargeGroupFlamePainter extends CustomPainter {
  _SuperLargeGroupFlamePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _kViewBox;
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(_flamePath(), paint);
  }

  @override
  bool shouldRepaint(covariant _SuperLargeGroupFlamePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
