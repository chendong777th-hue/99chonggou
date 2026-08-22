/// 置顶写库后：是否跳过再次 deferred 重排。
bool shouldSkipPinnedDeferredReorder({
  required bool currentPinnedMatchesTarget,
  required bool orderAlreadySorted,
}) {
  return currentPinnedMatchesTarget && orderAlreadySorted;
}

/// 掉队会话是否落在当前水合窗外（窗外才需要 forceReload）。
bool shouldForceReloadTypeHydrateAfterPin({
  required int? movedTypeIndex,
  required int hydrateStart,
  required int hydrateLength,
}) {
  if (movedTypeIndex == null || hydrateLength <= 0) {
    return false;
  }
  final end = hydrateStart + hydrateLength;
  return movedTypeIndex < hydrateStart || movedTypeIndex >= end;
}

/// 写库后 hydrate 的 center：优先视口锚点，其次水合中点，最后 fallback。
int resolvePinHydrateCenterIndex({
  required int? viewportAnchorTypeIndex,
  required int? hydrateMidTypeIndex,
  required int fallback,
}) {
  if (viewportAnchorTypeIndex != null && viewportAnchorTypeIndex >= 0) {
    return viewportAnchorTypeIndex;
  }
  if (hydrateMidTypeIndex != null && hydrateMidTypeIndex >= 0) {
    return hydrateMidTypeIndex;
  }
  return fallback < 0 ? 0 : fallback;
}
