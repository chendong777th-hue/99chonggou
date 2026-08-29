/// Group governance operation traces. Off by default; set [enabled] to true.
class GroupGovernanceTrace {
  GroupGovernanceTrace._();

  static const bool enabled = false;
  static const _tag = 'GroupGovernance';

  static void log(
    String event, {
    Map<String, Object?> extras = const {},
  }) {
    if (!enabled) return;
    final line = formatLineForLog(event, extras: extras);
  }

  static String formatLineForLog(
    String event, {
    Map<String, Object?> extras = const {},
  }) {
    final buffer = StringBuffer('$_tag event=$event');
    for (final entry in extras.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      final text = value.toString();
      if (text.isEmpty) {
        continue;
      }
      buffer.write(' ${entry.key}=${_compact(text)}');
    }
    return buffer.toString();
  }

  static String _compact(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 500) {
      return normalized;
    }
    return '${normalized.substring(0, 500)}...';
  }
}
