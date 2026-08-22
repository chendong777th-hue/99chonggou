/// 长图页向图集同步的翻页门禁（对齐微信：放大后仅左右贴边可横滑切图）。
class TallImageGalleryScrollGate {
  const TallImageGalleryScrollGate({
    required this.scale,
    required this.atLeftEdge,
    required this.atRightEdge,
    required this.hasHorizontalScroll,
  });

  static const TallImageGalleryScrollGate initial = TallImageGalleryScrollGate(
    scale: 1.0,
    atLeftEdge: true,
    atRightEdge: true,
    hasHorizontalScroll: false,
  );

  final double scale;
  final bool atLeftEdge;
  final bool atRightEdge;
  final bool hasHorizontalScroll;

  /// 当前平移是否已贴到可横滑翻页的左缘（继续左滑看下一张）。
  bool get canFlipToNextPage => !hasHorizontalScroll || atLeftEdge;

  /// 当前平移是否已贴到可横滑翻页的右缘（继续右滑看上一张）。
  bool get canFlipToPreviousPage => !hasHorizontalScroll || atRightEdge;
}

/// 放大后是否已在指定横滑方向的贴边（供 [TallImageScrollPreview] 翻页判定）。
bool tallImageAtHorizontalPanEdge({
  required double translationX,
  required double minX,
  required double maxX,
  required bool hasHorizontalScroll,
  required double dragDx,
  double slop = 3.0,
}) {
  if (!hasHorizontalScroll) {
    return true;
  }
  // 手指左滑（dx<0）看下一张 → 须已滑到 pan 左界
  if (dragDx < 0) {
    return translationX <= minX + slop;
  }
  // 手指右滑（dx>0）看上一张 → 须已滑到 pan 右界
  if (dragDx > 0) {
    return translationX >= maxX - slop;
  }
  return false;
}
