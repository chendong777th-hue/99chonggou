/// Pure abutment checks for history pagination merges into an around-window.
///
/// Lists are **newest-first** (index 0 = newest), matching
/// `TUIChatGlobalModel.sortMessagesNewestFirst` / in-memory chat lists.
class HistoryPaginationContinuity {
  HistoryPaginationContinuity._();

  /// Default max hole (seconds) allowed on C2C / seq-less join edges.
  static const int defaultTimeAbutSec = 120;

  /// Whether [incomingNewerNewestFirst] may be prepended onto
  /// [existingNewestFirst] without inventing a seq/time gap.
  ///
  /// - Empty incoming → true (no-op merge).
  /// - Empty existing → true (replace/bootstrap).
  /// - Overlap on seq at the join edge → true.
  /// - Group-style positive seqs: existing newest seq must equal
  ///   incoming oldest seq, or incoming oldest == existing newest + 1
  ///   (incoming batch is strictly newer and contiguous).
  /// - Else timestamps: incoming oldest timestamp >= existing newest
  ///   timestamp, and delta <= [timeAbutSec] (unless overlap).
  static bool canPrependNewerBatch({
    required List<({int? seq, int? timestamp})> existingNewestFirst,
    required List<({int? seq, int? timestamp})> incomingNewerNewestFirst,
    int timeAbutSec = defaultTimeAbutSec,
  }) {
    if (incomingNewerNewestFirst.isEmpty || existingNewestFirst.isEmpty) {
      return true;
    }

    final existingNewest = existingNewestFirst.first;
    final incomingOldest = incomingNewerNewestFirst.last;

    final existingNewestSeq = _positiveSeq(existingNewest.seq);
    final incomingOldestSeq = _positiveSeq(incomingOldest.seq);

    if (existingNewestSeq != null && incomingOldestSeq != null) {
      if (incomingOldestSeq == existingNewestSeq) {
        return true; // overlap at edge
      }
      // Incoming page is newer: its oldest should be exactly one past
      // the window's newest.
      return incomingOldestSeq == existingNewestSeq + 1;
    }

    final existingTs = existingNewest.timestamp ?? 0;
    final incomingTs = incomingOldest.timestamp ?? 0;
    if (existingTs <= 0 || incomingTs <= 0) {
      // No seq and no usable time — allow merge (dedupe still applies).
      return true;
    }
    if (incomingTs < existingTs) {
      return false;
    }
    return (incomingTs - existingTs) <= timeAbutSec;
  }

  static int? _positiveSeq(int? seq) {
    if (seq == null || seq <= 0) {
      return null;
    }
    return seq;
  }
}
