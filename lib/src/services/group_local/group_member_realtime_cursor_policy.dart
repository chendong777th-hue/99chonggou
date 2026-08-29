abstract final class GroupMemberRealtimeCursorPolicy {
  static bool shouldApply({
    required int cursor,
    required int seq,
  }) {
    return seq <= 0 || seq > cursor;
  }

  static bool shouldAdvance({
    required int cursor,
    required int seq,
  }) {
    return seq == cursor + 1;
  }
}
