import 'package:flutter/widgets.dart';

/// 按逻辑展示尺寸 × DPR 计算内存/磁盘缓存像素，避免大图解码进小头像。
class ImageMemCacheSize {
  ImageMemCacheSize._();

  static int forLogicalSize(
    double logicalSize,
    BuildContext context, {
    int min = 1,
    int max = 2048,
  }) {
    if (!logicalSize.isFinite || logicalSize <= 0) {
      return max;
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (logicalSize * dpr).round().clamp(min, max);
  }

  static int forBox(
    BoxConstraints constraints,
    BuildContext context, {
    double fallback = 48,
    int min = 1,
    int max = 2048,
  }) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : fallback;
    final height = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : fallback;
    final side = (width.isFinite && height.isFinite)
        ? (width < height ? width : height)
        : fallback;
    return forLogicalSize(side, context, min: min, max: max);
  }
}
