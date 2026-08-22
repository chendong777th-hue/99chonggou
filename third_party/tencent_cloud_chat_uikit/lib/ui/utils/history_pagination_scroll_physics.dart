import 'package:flutter/widgets.dart';

/// 聊天历史上拉分页专用 ScrollPhysics。
///
/// 在 [ScrollPhysics.adjustPositionForNewDimensions] 阶段补偿 maxScrollExtent
/// 变化，使视口内消息在「头部插入旧消息 / 异步撑高 / spacer 变化」时保持
/// 相对位置。这是 Flutter 推荐的 scroll 维持方式，等同
/// maintainVisibleContentPosition 的内部机制，不依赖 post-frame jumpTo。
class HistoryPaginationScrollPhysics extends ScrollPhysics {
  const HistoryPaginationScrollPhysics({
    super.parent,
    this.shouldCompensate,
    this.pinnedNearTopTolerancePx = 160.0,
  });

  /// 返回 true 时启用补偿（上拉分页加载窗口内）。
  final bool Function()? shouldCompensate;

  /// 与上拉触发阈值一致：贴顶时不做 extent+=growth（会落到新批次最旧一条），改由消息锚点恢复。
  final double pinnedNearTopTolerancePx;

  @override
  HistoryPaginationScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return HistoryPaginationScrollPhysics(
      parent: buildParent(ancestor),
      shouldCompensate: shouldCompensate,
      pinnedNearTopTolerancePx: pinnedNearTopTolerancePx,
    );
  }

  /// 上拉分页 prepend 后，按加载前 scroll 与 max 的差值补偿 extent 增长。
  static double? computeExtentDeltaRestorePixels({
    required double anchorPixels,
    required double anchorMaxExtent,
    required double newMaxScrollExtent,
    required double minScrollExtent,
  }) {
    if (anchorMaxExtent <= 0) {
      return null;
    }
    final delta = newMaxScrollExtent - anchorMaxExtent;
    if (delta <= 0.5) {
      return null;
    }
    return (anchorPixels + delta).clamp(minScrollExtent, newMaxScrollExtent);
  }

  /// 加载触发时是否处于 iOS 回弹 overscroll（pixels 超过 max）。
  static bool wasOverscrollingPastTop({
    required double anchorPixels,
    required double anchorMaxExtent,
    double tolerancePx = 2.0,
  }) {
    return anchorMaxExtent > 0 &&
        anchorPixels > anchorMaxExtent + tolerancePx;
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    var pixels = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
    if (!(shouldCompensate?.call() ?? false)) {
      return pixels;
    }

    // 上拉分页窗口内：即使用户仍在拖拽，也要补偿 prepend 带来的 extent 增长，
    // 否则 Web 上 load 常在 isScrolling==true 时完成，视口会跳到更旧消息。
    final maxGrowth = newPosition.maxScrollExtent - oldPosition.maxScrollExtent;
    final pinnedToOldMax = oldPosition.maxScrollExtent > 0 &&
        oldPosition.pixels >=
            oldPosition.maxScrollExtent - pinnedNearTopTolerancePx;
    if (maxGrowth > 0.5 && !pinnedToOldMax) {
      // 中部上翻：同步补偿 prepend 高度，视口内消息不动、新历史从顶部插入。
      pixels += maxGrowth;
    }

    final maxShrink = oldPosition.maxScrollExtent - newPosition.maxScrollExtent;
    if (maxShrink > 0.5) {
      pixels -= maxShrink;
    }

    return pixels.clamp(
      newPosition.minScrollExtent,
      newPosition.maxScrollExtent,
    );
  }
}
