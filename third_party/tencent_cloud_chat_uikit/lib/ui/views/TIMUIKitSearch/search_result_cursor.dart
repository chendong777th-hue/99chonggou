/// 搜索结果独立页的内存快照 Cursor 窗口（Phase 2）。
///
/// cursor = 已展示条数下标；不是 SQL OFFSET。
class SearchResultCursor {
  SearchResultCursor({
    required this.total,
    this.pageSize = defaultPageSize,
  })  : assert(pageSize > 0),
        displayedCount = _initialDisplayed(total: total, pageSize: pageSize);

  static const int defaultPageSize = 80;

  final int total;
  final int pageSize;
  int displayedCount;
  bool _loadingMore = false;

  static int _initialDisplayed({
    required int total,
    required int pageSize,
  }) {
    if (total <= 0) {
      return 0;
    }
    return total < pageSize ? total : pageSize;
  }

  bool get hasMore => displayedCount < total;

  bool get isLoadingMore => _loadingMore;

  /// 追加一页；无更多或正在加载时返回 false。
  bool loadMore() {
    if (!hasMore || _loadingMore) {
      return false;
    }
    _loadingMore = true;
    try {
      displayedCount = nextDisplayedCount(
        current: displayedCount,
        total: total,
        pageSize: pageSize,
      );
      return true;
    } finally {
      _loadingMore = false;
    }
  }
}

/// 纯函数：给定当前展示数，计算 loadMore 后的展示数。
int nextDisplayedCount({
  required int current,
  required int total,
  required int pageSize,
}) {
  if (total <= 0) {
    return 0;
  }
  if (current >= total) {
    return total;
  }
  if (pageSize <= 0) {
    return current.clamp(0, total);
  }
  final next = current + pageSize;
  return next < total ? next : total;
}

/// 是否接近列表底部，应触发 loadMore。
bool shouldLoadMoreByScroll({
  required double pixels,
  required double maxScrollExtent,
  required double itemExtent,
  int thresholdItems = 3,
}) {
  if (maxScrollExtent <= 0) {
    return true;
  }
  final threshold = itemExtent * thresholdItems;
  return pixels >= maxScrollExtent - threshold;
}
