/// Pure helpers for group 「@我」 tongue jump (around-seq window).
class AtMeJump {
  AtMeJump._();

  /// Returns null when [raw] cannot be used as `lastMsgSeq`.
  static int? parseTargetSeq(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    return int.tryParse(text);
  }

  /// Canonical seq string for list lookup (`"1081"` not `" 1081 "`).
  static String? canonicalSeqString(String? raw) {
    final n = parseTargetSeq(raw);
    return n?.toString();
  }
}
