/// 90 天 IM 漫游下的本地+云端合并。
///
/// 对齐 QQ / Telegram：旧本地不从集合里丢掉，中间记成洞，用云端往前翻补上
/// 再并进时间线。首屏只展示最新连续一段，避免把月份级两截焊成假连续。
/// 云端背书允许已删 seq 跳号；未补上的旧本地留在集合里供后续翻页/补洞。
class RoamingContiguousWindow {
  RoamingContiguousWindow._();

  /// 产品配置：云端漫游覆盖天数。
  static const int roamingCoverageDays = 90;

  static List<T> mergeLocalCloudTakeNewest<T>({
    required List<T> local,
    required List<T> cloud,
    required int count,
    required String Function(T) idOf,
    required int Function(T) seqOf,
    required int Function(T) timestampSecOf,
  }) {
    final trustedIds = <String>{};
    for (final message in cloud) {
      final id = idOf(message);
      if (id.isNotEmpty) {
        trustedIds.add(id);
      }
    }
    final union = unionSorted(
      local,
      cloud,
      idOf: idOf,
      seqOf: seqOf,
      timestampSecOf: timestampSecOf,
    );
    return takeNewest(
      keepNewestContiguousSpine(
        ascending: union,
        trustedIds: trustedIds,
        idOf: idOf,
        seqOf: seqOf,
        timestampSecOf: timestampSecOf,
      ),
      count,
    );
  }

  /// 本地+云端去重排序，**保留**接不上的旧本地（洞留给云端补）。
  static List<T> unionSorted<T>(
    List<T> first,
    List<T> second, {
    required String Function(T) idOf,
    required int Function(T) seqOf,
    required int Function(T) timestampSecOf,
  }) {
    final merged = _dedupePreferSecond(
      first,
      second,
      idOf: idOf,
    );
    _sortAscending(
      merged,
      seqOf: seqOf,
      timestampSecOf: timestampSecOf,
      idOf: idOf,
    );
    return merged;
  }

  static List<T> mergeLocalCloudSpine<T>({
    required List<T> local,
    required List<T> cloud,
    required String Function(T) idOf,
    required int Function(T) seqOf,
    required int Function(T) timestampSecOf,
  }) {
    final trustedIds = <String>{};
    for (final message in cloud) {
      final id = idOf(message);
      if (id.isNotEmpty) {
        trustedIds.add(id);
      }
    }
    final merged = unionSorted(
      local,
      cloud,
      idOf: idOf,
      seqOf: seqOf,
      timestampSecOf: timestampSecOf,
    );
    return keepNewestContiguousSpine(
      ascending: merged,
      trustedIds: trustedIds,
      idOf: idOf,
      seqOf: seqOf,
      timestampSecOf: timestampSecOf,
    );
  }

  /// 更早一页是否该并进当前窗：严格相邻/重叠，或云端一页能对上的小跳号。
  /// 月份级旧本地（seq/时间跨度远超一页）返回 false，避免焊出空洞。
  ///
  /// [useSeqContiguity] 默认 true（群）。C2C seq 按发送方编号，必须传 false，
  /// 只认 msgID 重叠与 90 天时间窗。
  static bool shouldMergeOlderPage<T>({
    required List<T> newer,
    required List<T> older,
    required int pageSize,
    required String Function(T) idOf,
    required int Function(T) seqOf,
    required int Function(T) timestampSecOf,
    bool useSeqContiguity = true,
  }) {
    if (older.isEmpty) {
      return false;
    }
    if (newer.isEmpty) {
      return true;
    }
    if (connects(
      newer: newer,
      older: older,
      olderCloudBacked: false,
      idOf: idOf,
      seqOf: seqOf,
      useSeqContiguity: useSeqContiguity,
    )) {
      return true;
    }
    var olderMaxSeq = 0;
    var olderHasSeq = false;
    var olderMaxTs = 0;
    for (final message in older) {
      final seq = seqOf(message);
      if (seq > 0) {
        olderHasSeq = true;
        if (seq > olderMaxSeq) {
          olderMaxSeq = seq;
        }
      }
      final ts = timestampSecOf(message);
      if (ts > olderMaxTs) {
        olderMaxTs = ts;
      }
    }
    var newerMinSeq = 0;
    var newerHasSeq = false;
    var newerMinTs = 0;
    var newerHasTs = false;
    for (final message in newer) {
      final seq = seqOf(message);
      if (seq > 0) {
        if (!newerHasSeq || seq < newerMinSeq) {
          newerMinSeq = seq;
          newerHasSeq = true;
        }
      }
      final ts = timestampSecOf(message);
      if (ts > 0 && (!newerHasTs || ts < newerMinTs)) {
        newerMinTs = ts;
        newerHasTs = true;
      }
    }
    if (!useSeqContiguity) {
      return _timestampWindowConnects(
        newerHasTs: newerHasTs,
        newerMinTs: newerMinTs,
        olderMaxTs: olderMaxTs,
      );
    }
    final seqPageSlack = pageSize < 1 ? 1 : pageSize + 1;
    if (olderHasSeq && newerHasSeq && newerMinSeq > olderMaxSeq) {
      return newerMinSeq - olderMaxSeq <= seqPageSlack;
    }
    if (!olderHasSeq || !newerHasSeq) {
      return _timestampWindowConnects(
        newerHasTs: newerHasTs,
        newerMinTs: newerMinTs,
        olderMaxTs: olderMaxTs,
      );
    }
    return false;
  }

  /// C2C 旧页是否「看起来比 lastMsg 更早」。官方续拉已改走
  /// [HistoryPaginationAnchor.c2cOfficialOlderCursor]，补旧不再用本函数
  /// 做焊接门禁（整页 ts<=lastMsg 会把不相邻的旧页焊上）。
  static bool shouldMergeC2cOlderPageByLastMsg<T>({
    required List<T> newer,
    required List<T> older,
    required String lastMsgId,
    required int lastMsgTs,
    required String Function(T) idOf,
    required int Function(T) timestampSecOf,
  }) {
    if (older.isEmpty) {
      return false;
    }
    if (newer.isEmpty) {
      return true;
    }
    final newerIds = <String>{};
    for (final message in newer) {
      final id = idOf(message);
      if (id.isNotEmpty) {
        newerIds.add(id);
      }
    }
    final lastId = lastMsgId.trim();
    var olderMaxTs = 0;
    var olderMinTs = 0;
    var olderHasTs = false;
    for (final message in older) {
      final id = idOf(message);
      if (id.isNotEmpty && (newerIds.contains(id) || id == lastId)) {
        return true;
      }
      final ts = timestampSecOf(message);
      if (ts <= 0) {
        continue;
      }
      if (!olderHasTs || ts > olderMaxTs) {
        olderMaxTs = ts;
      }
      if (!olderHasTs || ts < olderMinTs) {
        olderMinTs = ts;
      }
      olderHasTs = true;
    }
    if (!olderHasTs || lastMsgTs <= 0) {
      return false;
    }
    if (olderMinTs > lastMsgTs) {
      return false;
    }
    return olderMaxTs <= lastMsgTs;
  }

  static bool _timestampWindowConnects({
    required bool newerHasTs,
    required int newerMinTs,
    required int olderMaxTs,
  }) {
    if (!newerHasTs || olderMaxTs <= 0) {
      return false;
    }
    final maxGap = roamingCoverageDays * 86400;
    if (olderMaxTs >= newerMinTs) {
      return olderMaxTs - newerMinTs <= maxGap;
    }
    final gap = newerMinTs - olderMaxTs;
    return gap > 0 && gap <= maxGap;
  }

  /// 把更早一页接到最新脊柱上；接不上（本地旧档跳号）则丢弃该页。
  static List<T> absorbOlderBatch<T>({
    required List<T> newerSpine,
    required List<T> olderBatch,
    required bool olderCloudBacked,
    required String Function(T) idOf,
    required int Function(T) seqOf,
    required int Function(T) timestampSecOf,
  }) {
    if (newerSpine.isEmpty) {
      return mergeLocalCloudSpine(
        local: olderCloudBacked ? const [] : olderBatch,
        cloud: olderCloudBacked ? olderBatch : const [],
        idOf: idOf,
        seqOf: seqOf,
        timestampSecOf: timestampSecOf,
      );
    }
    if (olderBatch.isEmpty) {
      return List<T>.of(newerSpine);
    }
    if (!connects(
      newer: newerSpine,
      older: olderBatch,
      olderCloudBacked: olderCloudBacked,
      idOf: idOf,
      seqOf: seqOf,
    )) {
      return List<T>.of(newerSpine);
    }
    final trustedIds = <String>{};
    for (final message in newerSpine) {
      final id = idOf(message);
      if (id.isNotEmpty) {
        trustedIds.add(id);
      }
    }
    if (olderCloudBacked) {
      for (final message in olderBatch) {
        final id = idOf(message);
        if (id.isNotEmpty) {
          trustedIds.add(id);
        }
      }
    }
    final merged = _dedupePreferSecond(
      olderBatch,
      newerSpine,
      idOf: idOf,
    );
    _sortAscending(
      merged,
      seqOf: seqOf,
      timestampSecOf: timestampSecOf,
      idOf: idOf,
    );
    return keepNewestContiguousSpine(
      ascending: merged,
      trustedIds: trustedIds,
      idOf: idOf,
      seqOf: seqOf,
      timestampSecOf: timestampSecOf,
    );
  }

  static bool connects<T>({
    required List<T> newer,
    required List<T> older,
    required bool olderCloudBacked,
    required String Function(T) idOf,
    required int Function(T) seqOf,
    bool useSeqContiguity = true,
  }) {
    if (older.isEmpty) {
      return false;
    }
    if (newer.isEmpty) {
      return true;
    }
    final newerIds = <String>{};
    for (final message in newer) {
      final id = idOf(message);
      if (id.isNotEmpty) {
        newerIds.add(id);
      }
    }
    for (final message in older) {
      final id = idOf(message);
      if (id.isNotEmpty && newerIds.contains(id)) {
        return true;
      }
    }
    if (!useSeqContiguity) {
      return false;
    }

    var olderMaxSeq = 0;
    var olderHasSeq = false;
    for (final message in older) {
      final seq = seqOf(message);
      if (seq > 0) {
        olderHasSeq = true;
        if (seq > olderMaxSeq) {
          olderMaxSeq = seq;
        }
      }
    }
    var newerMinSeq = 0;
    var newerHasSeq = false;
    for (final message in newer) {
      final seq = seqOf(message);
      if (seq > 0) {
        if (!newerHasSeq || seq < newerMinSeq) {
          newerMinSeq = seq;
          newerHasSeq = true;
        }
      }
    }
    if (olderHasSeq && newerHasSeq) {
      if (newerMinSeq <= olderMaxSeq) {
        return true;
      }
      if (newerMinSeq - olderMaxSeq == 1) {
        return true;
      }
      // 云端页允许已删 seq 造成的跳号，仍接上以便把窗口补满。
      // 旧本地页 olderCloudBacked=false，跳号时仍拒绝，避免月份级空洞。
      return olderCloudBacked;
    }
    return olderCloudBacked;
  }

  static List<T> keepNewestContiguousSpine<T>({
    required List<T> ascending,
    required Set<String> trustedIds,
    required String Function(T) idOf,
    required int Function(T) seqOf,
    required int Function(T) timestampSecOf,
  }) {
    if (ascending.length <= 1) {
      return List<T>.of(ascending);
    }
    var trustedOldestTs = 0;
    if (trustedIds.isNotEmpty) {
      for (final message in ascending) {
        final id = idOf(message);
        if (id.isEmpty || !trustedIds.contains(id)) {
          continue;
        }
        final ts = timestampSecOf(message);
        if (ts > 0 && (trustedOldestTs == 0 || ts < trustedOldestTs)) {
          trustedOldestTs = ts;
        }
      }
    }

    var start = ascending.length - 1;
    for (var j = ascending.length - 2; j >= 0; j--) {
      final older = ascending[j];
      final newer = ascending[j + 1];
      final olderSeq = seqOf(older);
      final newerSeq = seqOf(newer);
      if (olderSeq > 0 && newerSeq > 0) {
        if (newerSeq - olderSeq > 1) {
          final olderId = idOf(older);
          if (olderId.isNotEmpty && trustedIds.contains(olderId)) {
            start = j;
            continue;
          }
          break;
        }
        start = j;
        continue;
      }
      if (trustedIds.isEmpty) {
        start = j;
        continue;
      }
      final olderId = idOf(older);
      if (olderId.isNotEmpty && trustedIds.contains(olderId)) {
        start = j;
        continue;
      }
      final olderTs = timestampSecOf(older);
      if (trustedOldestTs > 0 && olderTs >= trustedOldestTs) {
        start = j;
        continue;
      }
      break;
    }
    return ascending.sublist(start);
  }

  static List<T> takeNewest<T>(List<T> ascending, int count) {
    if (count <= 0 || ascending.length <= count) {
      return List<T>.of(ascending);
    }
    return ascending.sublist(ascending.length - count);
  }

  static List<T> _dedupePreferSecond<T>(
    List<T> first,
    List<T> second, {
    required String Function(T) idOf,
  }) {
    final byId = <String, T>{};
    final anonymous = <T>[];
    void absorb(T message) {
      final id = idOf(message);
      if (id.isEmpty) {
        anonymous.add(message);
        return;
      }
      byId[id] = message;
    }

    for (final message in first) {
      absorb(message);
    }
    for (final message in second) {
      absorb(message);
    }
    return <T>[...byId.values, ...anonymous];
  }

  static void _sortAscending<T>(
    List<T> messages, {
    required int Function(T) seqOf,
    required int Function(T) timestampSecOf,
    required String Function(T) idOf,
  }) {
    messages.sort((a, b) {
      final ts = timestampSecOf(a).compareTo(timestampSecOf(b));
      if (ts != 0) {
        return ts;
      }
      final seqA = seqOf(a);
      final seqB = seqOf(b);
      if (seqA > 0 && seqB > 0 && seqA != seqB) {
        return seqA.compareTo(seqB);
      }
      return idOf(a).compareTo(idOf(b));
    });
  }
}
