/// Pure helpers for entry 「xxx条未读」→ first-unread jump (plan 010).
class FirstUnreadJumpTarget {
  const FirstUnreadJumpTarget({
    required this.strategy,
    this.seq,
    this.timestampSec,
  });

  /// `group_read_seq` | `seq_from_unread` | `locked_seq` | `c2c_read_ts` | `count_fallback`
  final String strategy;
  final int? seq;
  final int? timestampSec;

  /// Last-read cursor seq for group strategies (first unread = this + 1).
  int? get groupReadCursorSeq {
    final first = seq;
    if (first == null || first <= 1) {
      return null;
    }
    if (strategy == 'group_read_seq' ||
        strategy == 'seq_from_unread' ||
        strategy == 'locked_seq') {
      return first - 1;
    }
    return null;
  }
}

class FirstUnreadJump {
  FirstUnreadJump._();

  /// Max unread for which count-chase / count_fallback is allowed.
  static const int maxCountFallbackUnread = 200;

  /// Entry tip count display: full int through 99, then `99+`.
  static String formatEntryUnreadCount(int count) {
    if (count > 99) {
      return '99+';
    }
    if (count < 0) {
      return '0';
    }
    return count.toString();
  }

  /// When [groupReadSequence] is missing on the UI conversation object,
  /// estimate first-unread seq as `lastMessageSeq - unreadCount + 1`.
  ///
  /// Matches TIM native math: unread ≈ latestSeq - groupReadSequence
  /// (see OnGetConversationInfo: latest/read/unread).
  static int? estimateFirstUnreadSeq({
    required int unreadCount,
    required int lastMessageSeq,
  }) {
    if (unreadCount <= 0 || lastMessageSeq <= 0) {
      return null;
    }
    final first = lastMessageSeq - unreadCount + 1;
    if (first <= 0 || first > lastMessageSeq) {
      return null;
    }
    return first;
  }

  /// Freeze first-unread seq at conversation open (before mark-read).
  static int? resolveLockedFirstUnreadSeq({
    required int unreadCount,
    required bool isGroup,
    int? groupReadSequence,
    int? lastMessageSeq,
  }) {
    if (!isGroup || unreadCount <= 0) {
      return null;
    }
    final readSeq = groupReadSequence ?? 0;
    final lastSeq = lastMessageSeq ?? 0;
    if (readSeq > 0 && (lastSeq <= 0 || readSeq < lastSeq)) {
      return readSeq + 1;
    }
    return estimateFirstUnreadSeq(
      unreadCount: unreadCount,
      lastMessageSeq: lastSeq,
    );
  }

  /// Resolve where to open the around-window for the first unread.
  ///
  /// Returns null when there is nothing to jump to (no unread / fully read /
  /// large unread without a usable read cursor or seq estimate).
  static FirstUnreadJumpTarget? resolve({
    required int unreadCount,
    required bool isGroup,
    int? groupReadSequence,
    int? c2cReadTimestamp,
    int? lastMessageSeq,
    int? lastMessageTimestamp,
    int? lockedFirstUnreadSeq,
  }) {
    if (unreadCount <= 0) {
      return null;
    }

    final locked = lockedFirstUnreadSeq ?? 0;
    if (isGroup && locked > 0) {
      final lastSeq = lastMessageSeq ?? 0;
      if (lastSeq <= 0 || locked <= lastSeq) {
        return FirstUnreadJumpTarget(
          strategy: 'locked_seq',
          seq: locked,
        );
      }
    }

    if (isGroup) {
      final readSeq = groupReadSequence ?? 0;
      if (readSeq > 0) {
        final lastSeq = lastMessageSeq ?? 0;
        // 进会话后 SDK 常把读游标推到最新，但入口 tip 仍锁着未读数。
        // 此时不能直接判「已读完」返回 null，要落到 seq_from_unread。
        if (lastSeq <= 0 || readSeq < lastSeq) {
          return FirstUnreadJumpTarget(
            strategy: 'group_read_seq',
            seq: readSeq + 1,
          );
        }
      }

      final estimated = estimateFirstUnreadSeq(
        unreadCount: unreadCount,
        lastMessageSeq: lastMessageSeq ?? 0,
      );
      if (estimated != null) {
        return FirstUnreadJumpTarget(
          strategy: 'seq_from_unread',
          seq: estimated,
        );
      }
    } else {
      final readTs = c2cReadTimestamp ?? 0;
      if (readTs > 0) {
        final lastTs = lastMessageTimestamp ?? 0;
        if (lastTs > 0 && readTs >= lastTs) {
          return null;
        }
        return FirstUnreadJumpTarget(
          strategy: 'c2c_read_ts',
          timestampSec: readTs,
        );
      }
    }

    if (unreadCount <= maxCountFallbackUnread) {
      return const FirstUnreadJumpTarget(strategy: 'count_fallback');
    }
    return null;
  }
}
