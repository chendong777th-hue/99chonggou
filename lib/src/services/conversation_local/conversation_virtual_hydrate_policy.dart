/// 虚拟列表水合窗是否已舒适覆盖视口中心（可跳过读库/rebuild）。
///
/// [margin] 为距窗缘的安全带；窗长 ≤ 2×margin 时永不视为已覆盖（逼近扩窗）。
bool conversationVirtualHydrateCovered({
  required int center,
  required int curStart,
  required int curLength,
  required int margin,
}) {
  if (curLength <= 0 || margin < 0) {
    return false;
  }
  final curEnd = curStart + curLength;
  if (curEnd <= curStart) {
    return false;
  }
  if (curLength <= margin * 2) {
    return false;
  }
  return center >= curStart + margin && center < curEnd - margin;
}

/// 滚动侧：相对上次请求的中心步进是否足以再发起水合。
bool conversationVirtualHydrateCenterStepAllows({
  required int? lastCenter,
  required int center,
  required int step,
}) {
  if (lastCenter == null || step <= 0) {
    return true;
  }
  return (center - lastCenter).abs() >= step;
}

/// Skeleton rows must not bypass the scroll-settle hydration policy.
///
/// A fast fling can build several missing rows in one frame. Allowing every
/// row to start a SQLite hydrate causes query/merge/rebuild work to compete
/// with rasterization on low-end devices.
bool conversationVirtualSkeletonMayRequestHydrate({
  required bool onlyOnScrollSettle,
  required bool isScrolling,
}) {
  return !onlyOnScrollSettle || !isScrolling;
}

/// 停滑时：视口中心已离开旧窗 ± [radius]，才允许跳窗。
/// 滑动中仍禁止瞬移；空窗且中心不在 0 也要跳，否则远端 offset 永为骨架。
bool conversationVirtualHydrateShouldJumpWindow({
  required int viewportCenter,
  required int curStart,
  required int curLength,
  required int radius,
}) {
  if (radius < 0) {
    return true;
  }
  if (curLength <= 0) {
    return viewportCenter > 0;
  }
  final curEnd = curStart + curLength;
  return viewportCenter < curStart - radius ||
      viewportCenter > curEnd + radius;
}

/// 舒适区 skip 是否仍要 notify：停滑后即使窗已覆盖，也要重画 cache-only 骨架。
bool conversationVirtualHydrateShouldNotifyOnCoveredSkip({
  required bool forceNotify,
  required bool slidingWindowUserExpanded,
  required int curStart,
  required bool curIsNotEmpty,
}) {
  if (forceNotify && curIsNotEmpty) {
    return true;
  }
  return !slidingWindowUserExpanded && curStart > 0 && curIsNotEmpty;
}
