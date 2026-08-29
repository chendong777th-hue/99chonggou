import 'dart:async';

/// Transient UI locks for top/bottom history pagination on the message list.
class ChatListPaginationUiGate {
  static const loadLatestCooldownMs = 300;
  static const loadPreviousDebounceMs = 120;
  static const loadPreviousCooldownMs = 320;
  static const historyScrollProtectMs = 520;
  static const loadPreviousScrollUnlockMs = 360;
  static const scrollPaginationCompensationMs = 1200;
  static const incomingWhileReadingCompensationMs = 800;
  static const readingHistoryThresholdPx = 80.0;
  static const loadPreviousTopReachResetPx = 320.0;
  static const loadPreviousTopNearPx = 160.0;
  static const loadPreviousOverscrollTolerancePx = 2.0;
  static const minTopHistoryLoadingVisibleMs = 280;

  bool isLoadingPrevious = false;
  bool pendingLoadPrevious = false;
  bool silentTopHistoryLoading = false;
  bool triedPreviousAfterNoMore = false;
  int lastLoadPreviousCompletedAtMs = 0;
  int ignoreScrollLoadPrevious = 0;
  int historyScrollProtectUntilMs = 0;
  String? previousLoadInFlightAnchorKey;
  bool previousLoadConsumedThisTopReach = false;
  String? lastTopReachConsumedAnchorKey;
  int lastScrollBlockLogMs = 0;
  Future<void>? loadPreviousTask;
  bool isLoadingLatest = false;
  int lastLoadLatestCompletedAtMs = 0;
  int topHistoryLoadingShownAtMs = 0;
  Timer? loadPreviousDebounce;
  Timer? loadLatestDebounce;
  Timer? loadingIndicatorTimer;
  int latestLoadSuppressedUntilMs = 0;
  int scrollPaginationCompensationUntilMs = 0;
  int scrollPaginationCompensationGeneration = 0;

  /// 上拉分页前列表最老可翻页消息，用于 prepend 后贴顶时按消息恢复视口。
  String? paginationRestoreAnchorMsgID;
  int? paginationRestoreAnchorSeq;

  /// 贴顶上拉：滚动补偿完成前隐藏新 prepend 行，避免历史条直接跳出来。
  bool paginationPrependRevealPending = false;

  /// [paginationPrependRevealPending] 时，globalIndex >= 该值的行暂不可见。
  int paginationPrependRevealFromGlobalIndex = 0;

  bool isHistoryScrollProtected({
    required bool mediaPreviewRestoring,
    int? nowMs,
  }) {
    if (mediaPreviewRestoring) {
      return false;
    }
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return isLoadingPrevious ||
        ignoreScrollLoadPrevious > 0 ||
        now < historyScrollProtectUntilMs;
  }

  void beginHistoryScrollProtection({int? milliseconds, int? nowMs}) {
    final protectMs = milliseconds ?? historyScrollProtectMs;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final until = now + protectMs;
    if (until > historyScrollProtectUntilMs) {
      historyScrollProtectUntilMs = until;
    }
  }

  bool canScheduleLoadPrevious({
    required bool searchJumpStabilizing,
    required bool historyScrollProtected,
    int? nowMs,
  }) {
    if (isLoadingPrevious || searchJumpStabilizing || historyScrollProtected) {
      return false;
    }
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return now - lastLoadPreviousCompletedAtMs >= loadPreviousCooldownMs;
  }

  /// 本次贴顶是否已消费过上拉分页。
  /// 离开顶部、成功翻页，或遇到可重试零增长页时再允许。
  bool shouldAllowLoadPreviousAtTopReach(
      {bool bypassTopReachConsumed = false}) {
    if (bypassTopReachConsumed) {
      return true;
    }
    return !previousLoadConsumedThisTopReach;
  }

  void markTopReachConsumedForPreviousLoad(String anchorKey) {
    previousLoadConsumedThisTopReach = true;
    lastTopReachConsumedAnchorKey = anchorKey;
  }

  void resetTopReachConsumedIfScrolledAway({
    required double pixels,
    required double maxScrollExtent,
  }) {
    if (maxScrollExtent <= 0) {
      return;
    }
    if (pixels < maxScrollExtent - loadPreviousTopReachResetPx) {
      previousLoadConsumedThisTopReach = false;
      lastTopReachConsumedAnchorKey = null;
    }
  }

  /// 分页请求结束：只清 in-flight，保留贴顶消费位（防同顶连拉）。
  void finishPreviousLoadInFlight() {
    previousLoadInFlightAnchorKey = null;
  }

  /// 成功翻到更早一页且模型仍有更早历史：放开同一次贴顶消费位。
  /// 已确认到底的空批仍保持消费位（见 [finishPreviousLoadInFlight]）。
  void releaseTopReachConsumedAfterSuccessfulPage({
    required bool haveMoreData,
  }) {
    if (!haveMoreData) {
      return;
    }
    previousLoadConsumedThisTopReach = false;
    lastTopReachConsumedAnchorKey = null;
  }

  /// A request that returned a retryable zero-growth page must not consume
  /// the current top reach forever. The normal scroll/cooldown protections
  /// still prevent a tight request loop, while the next deliberate upward
  /// gesture can retry with a repaired cursor.
  void releaseTopReachConsumedAfterRetryableNoGrowth({
    required bool haveMoreData,
  }) {
    if (!haveMoreData) {
      return;
    }
    previousLoadConsumedThisTopReach = false;
    lastTopReachConsumedAnchorKey = null;
  }

  bool canScheduleLoadLatest({int? nowMs}) {
    if (isLoadingLatest) {
      return false;
    }
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return now - lastLoadLatestCompletedAtMs >= loadLatestCooldownMs;
  }

  /// Debounce previous-load scheduling. Returns true if a timer was (re)armed.
  bool armLoadPreviousDebounce({
    required Duration delay,
    required void Function() onFire,
  }) {
    if (loadPreviousDebounce?.isActive ?? false) {
      return false;
    }
    loadPreviousDebounce = Timer(delay, onFire);
    return true;
  }

  void armLoadLatestDebounce({
    required Duration delay,
    required void Function() onFire,
  }) {
    loadLatestDebounce?.cancel();
    loadLatestDebounce = Timer(delay, onFire);
  }

  void disposeTimers() {
    loadPreviousDebounce?.cancel();
    loadPreviousDebounce = null;
    loadLatestDebounce?.cancel();
    loadLatestDebounce = null;
    loadingIndicatorTimer?.cancel();
    loadingIndicatorTimer = null;
  }
}
