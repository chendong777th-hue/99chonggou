/// Continuity check for prepending a newer batch onto the existing window.
///
/// Lists are **newest-first** (index 0 = newest), matching
/// `TUIChatGlobalModel.sortMessagesNewestFirst` / in-memory chat lists.
///
/// Plan 097铁律：SDK 是唯一权威。应用层不做 seq 连续性判断，
/// 不做时间窗邻接检查。`lastMsg` 游标天然无重复（SDK 返回不含 lastMsg
/// 本身），`dedupeMessages` 处理 msgID 重叠。这里只拒绝时间方向错误的
/// 批次（incoming 比 existing 更旧时不应 prepend 到 newer 端）。
class HistoryPaginationContinuity {
  HistoryPaginationContinuity._();

  /// Whether [incomingNewerNewestFirst] may be prepended onto
  /// [existingNewestFirst].
  ///
  /// - Empty incoming → true (no-op merge).
  /// - Empty existing → true (replace/bootstrap).
  /// - Incoming oldest timestamp < existing newest timestamp → false
  ///   (direction error: incoming batch is older, should not prepend to
  ///   the newer side).
  /// - Otherwise → true (trust SDK lastMsg cursor; dedupeMessages handles
  ///   any overlap; C2C seq is per-sender and has no global continuity so
  ///   seq checks are intentionally absent).
  static bool canPrependNewerBatch({
    required List<({int? seq, int? timestamp})> existingNewestFirst,
    required List<({int? seq, int? timestamp})> incomingNewerNewestFirst,
    int timeAbutSec = 0,
  }) {
    if (incomingNewerNewestFirst.isEmpty || existingNewestFirst.isEmpty) {
      return true;
    }

    final existingNewest = existingNewestFirst.first;
    final incomingOldest = incomingNewerNewestFirst.last;

    final existingTs = existingNewest.timestamp ?? 0;
    final incomingTs = incomingOldest.timestamp ?? 0;
    if (existingTs > 0 && incomingTs > 0 && incomingTs < existingTs) {
      return false;
    }
    return true;
  }
}
