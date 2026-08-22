/// 相邻可锚点消息之间的空洞（升序列表中的 A→B）。
class ArchiveHistoryGapProbe {
  const ArchiveHistoryGapProbe({
    required this.olderIndex,
    required this.newerIndex,
    required this.olderId,
    required this.newerId,
    required this.olderTimestampSec,
    required this.newerTimestampSec,
    required this.reason,
  });

  final int olderIndex;
  final int newerIndex;
  final String olderId;
  final String newerId;
  final int olderTimestampSec;
  final int newerTimestampSec;
  final String reason;
}

/// 洞检测 / 区间过滤用的轻量锚点（避免单测依赖原生 IM SDK）。
class ArchiveMessageProbe {
  const ArchiveMessageProbe({
    required this.id,
    required this.timestampSec,
    this.seq = -1,
    this.isLocalTip = false,
  });

  final String id;
  final int timestampSec;
  final int seq;
  final bool isLocalTip;

  int get timestampMs => timestampSec <= 0 ? 0 : timestampSec * 1000;
}

/// 首屏满窗校对 / 洞检测：纯函数工具（不发网络）。
class ArchiveWindowReconciler {
  ArchiveWindowReconciler._();

  /// C2C / 无 seq 时的时间洞阈值（秒）。
  static const int timeGapThresholdSec = 300;

  /// 单次打开最多补几个洞。
  static const int maxGapsPerOpen = 3;

  /// 每个洞最多翻几页归档。
  static const int maxPagesPerGap = 2;

  /// 每个洞最多云拉页数（IM 按洞；与归档翻页分开）。
  /// 90 天漫游下小洞一次可补约 8×40 条；更大的跳号由 peek 向云端翻页补，再与旧本地合并。
  static const int maxCloudPagesPerGap = 8;

  /// 群 seq 列表补洞上限；超过则只从 newer 端翻页，避免一次打开打几千个 seq。
  static const int maxMissingSeqsToFill = 80;

  /// 群 seq 洞：缺失的中间 seq（不含 older/newer 端点）。
  static List<int> missingGroupSeqs({
    required int olderSeq,
    required int newerSeq,
  }) {
    if (olderSeq <= 0 || newerSeq <= 0 || newerSeq - olderSeq <= 1) {
      return const <int>[];
    }
    final out = <int>[];
    for (var s = olderSeq + 1; s < newerSeq; s++) {
      out.add(s);
    }
    return out;
  }

  /// C2C / 无双端 seq：CLOUD_OLDER 的 timeBegin/timePeriod（秒）。
  /// 区间为 【timeBegin-timePeriod, timeBegin】= 【olderSec, newerSec】。
  static ({int timeBegin, int timePeriod}) cloudTimeRangeForGap({
    required int olderSec,
    required int newerSec,
  }) {
    final begin = newerSec > 0 ? newerSec : 0;
    final period = newerSec > olderSec ? (newerSec - olderSec) : 1;
    return (timeBegin: begin, timePeriod: period < 1 ? 1 : period);
  }

  static bool isAnchorCandidate(ArchiveMessageProbe message) {
    if (message.isLocalTip) {
      return false;
    }
    return message.timestampSec > 0;
  }

  /// 升序列表上检测空洞。群优先 seq；否则时间阈值。
  static List<ArchiveHistoryGapProbe> detectGaps(
    List<ArchiveMessageProbe> ascending, {
    required bool isGroup,
    int timeGapThresholdSec = timeGapThresholdSec,
    int maxGaps = maxGapsPerOpen,
  }) {
    final anchorIndexes = <int>[];
    for (var i = 0; i < ascending.length; i++) {
      if (isAnchorCandidate(ascending[i])) {
        anchorIndexes.add(i);
      }
    }
    if (anchorIndexes.length < 2 || maxGaps <= 0) {
      return const <ArchiveHistoryGapProbe>[];
    }
    final gaps = <ArchiveHistoryGapProbe>[];
    for (var i = 0; i < anchorIndexes.length - 1; i++) {
      if (gaps.length >= maxGaps) {
        break;
      }
      final olderIndex = anchorIndexes[i];
      final newerIndex = anchorIndexes[i + 1];
      final older = ascending[olderIndex];
      final newer = ascending[newerIndex];
      if (isGroup && older.seq > 0 && newer.seq > 0) {
        if (newer.seq - older.seq > 1) {
          gaps.add(ArchiveHistoryGapProbe(
            olderIndex: olderIndex,
            newerIndex: newerIndex,
            olderId: older.id,
            newerId: newer.id,
            olderTimestampSec: older.timestampSec,
            newerTimestampSec: newer.timestampSec,
            reason: 'seq_${older.seq}_${newer.seq}',
          ));
        }
        continue;
      }
      if (newer.timestampSec - older.timestampSec >= timeGapThresholdSec) {
        gaps.add(ArchiveHistoryGapProbe(
          olderIndex: olderIndex,
          newerIndex: newerIndex,
          olderId: older.id,
          newerId: newer.id,
          olderTimestampSec: older.timestampSec,
          newerTimestampSec: newer.timestampSec,
          reason: 'time_${older.timestampSec}_${newer.timestampSec}',
        ));
      }
    }
    return gaps;
  }

  /// 落在开区间 (olderSec, newerSec) 内。
  static List<T> filterStrictlyBetweenSec<T>(
    Iterable<T> messages, {
    required int olderSec,
    required int newerSec,
    required int Function(T) timestampSecOf,
  }) {
    if (olderSec <= 0 || newerSec <= 0 || newerSec <= olderSec) {
      return const [];
    }
    return messages
        .where((m) {
          final ts = timestampSecOf(m);
          return ts > olderSec && ts < newerSec;
        })
        .toList(growable: false);
  }

  /// 校对：窗内 (oldest, newest] ∪ 严格更早于 oldest。
  static List<T> filterForWindowReconcile<T>(
    Iterable<T> messages, {
    required int oldestSec,
    required int newestSec,
    required int Function(T) timestampSecOf,
  }) {
    if (newestSec <= 0) {
      return messages.where((m) => timestampSecOf(m) > 0).toList(growable: false);
    }
    return messages.where((m) {
      final ts = timestampSecOf(m);
      if (ts <= 0) {
        return false;
      }
      if (oldestSec <= 0) {
        return ts <= newestSec;
      }
      return ts < oldestSec || (ts > oldestSec && ts <= newestSec);
    }).toList(growable: false);
  }

  static ArchiveMessageProbe? oldestAnchor(List<ArchiveMessageProbe> ascending) {
    for (final m in ascending) {
      if (isAnchorCandidate(m)) {
        return m;
      }
    }
    return null;
  }

  static ArchiveMessageProbe? newestAnchor(List<ArchiveMessageProbe> ascending) {
    for (var i = ascending.length - 1; i >= 0; i--) {
      final m = ascending[i];
      if (isAnchorCandidate(m)) {
        return m;
      }
    }
    return null;
  }
}

/// 暖开后异步补齐决策（纯函数，便于单测）。
class WarmOpenReconcilePlan {
  const WarmOpenReconcilePlan({
    required this.willCloudMerge,
    required this.willArchiveReconcile,
    required this.gapCount,
  });

  /// 有洞时执行按洞 IM 云补（非整窗「条数不足才 CLOUD」peek）。
  final bool willCloudMerge;
  final bool willArchiveReconcile;
  final int gapCount;

  /// 有消息的暖窗：有洞则按洞 IM 云补；随后（或无洞时）挂归档窗校对。
  static WarmOpenReconcilePlan decide({required int gapCount}) {
    final gaps = gapCount < 0 ? 0 : gapCount;
    return WarmOpenReconcilePlan(
      willCloudMerge: gaps > 0,
      willArchiveReconcile: true,
      gapCount: gaps,
    );
  }
}
