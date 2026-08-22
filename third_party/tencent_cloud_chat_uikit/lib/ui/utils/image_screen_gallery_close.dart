import 'package:extended_image/extended_image.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/tall_image_gallery_scroll_gate.dart';

/// 放大后仅左右贴边时允许图集横滑翻页（微信式）。
bool canScrollMediaPreviewGalleryPage({
  required GestureDetails? details,
  required double baselineScale,
  TallImageGalleryScrollGate? tallImageGate,
  bool tallImageVerticallyScrollable = false,
}) {
  if (tallImageVerticallyScrollable && tallImageGate != null) {
    return canScrollMediaPreviewGalleryPageAtScale(
      totalScale: tallImageGate.scale,
      baselineScale: baselineScale,
      computeHorizontalBoundary: tallImageGate.hasHorizontalScroll,
      atLeftEdge: tallImageGate.atLeftEdge,
      atRightEdge: tallImageGate.atRightEdge,
    );
  }
  if (details == null) {
    return true;
  }
  return canScrollMediaPreviewGalleryPageAtScale(
    totalScale: details.totalScale,
    baselineScale: baselineScale,
    computeHorizontalBoundary: details.computeHorizontalBoundary,
    atLeftEdge: details.boundary.left,
    atRightEdge: details.boundary.right,
  );
}

/// 供 [canScrollMediaPreviewGalleryPage] 与单测共用。
bool canScrollMediaPreviewGalleryPageAtScale({
  required double? totalScale,
  required double baselineScale,
  required bool computeHorizontalBoundary,
  required bool atLeftEdge,
  required bool atRightEdge,
}) {
  if (totalScale == null) {
    return true;
  }
  if (totalScale <= baselineScale + 0.05) {
    return true;
  }
  if (!computeHorizontalBoundary) {
    return false;
  }
  return atLeftEdge || atRightEdge;
}

/// 图集预览关闭索引与 Hero 降级策略（可单测）。
int resolveMediaPreviewGalleryIndex({
  required bool useGallery,
  required int currentIndex,
  required int itemCount,
  double? page,
}) {
  if (!useGallery || itemCount <= 0) {
    return 0;
  }
  if (page != null) {
    return page.round().clamp(0, itemCount - 1);
  }
  return currentIndex.clamp(0, itemCount - 1);
}

/// Hero 关闭仅当目标 tag 非空且源 widget 仍在树中（可见或已构建）。
bool canHeroDismissToTarget({
  required String heroTag,
  required bool targetIsLive,
}) {
  if (heroTag.isEmpty) {
    return false;
  }
  return targetIsLive;
}
