import 'package:flutter/foundation.dart';

/// Opt-in counters for long-lived chat-page thermal profiling.
///
/// Release builds never emit these metrics. The counters contain only
/// aggregate numbers and safe labels; no message, account, group or path data.
class ChatThermalPerf {
  ChatThermalPerf._();

  static const bool profileEnabled = false;
  @visibleForTesting
  static bool debugForceEnabled = false;
  @visibleForTesting
  static void Function(String line)? debugSink;

  static bool get isEnabled =>
      !kReleaseMode && (profileEnabled || debugForceEnabled);

  static final Map<String, int> _counts = <String, int>{};

  static void increment(String metric, {int amount = 1}) {
    if (!isEnabled || amount <= 0) return;
    _counts[metric] = (_counts[metric] ?? 0) + amount;
  }

  static void record(String metric, num value) {
    if (!isEnabled) return;
    final safeMetric = _safe(metric);
    final line = '[ChatThermalPerf] metric=$safeMetric value=$value';
    final sink = debugSink;
    if (sink != null) {
      sink(line);
    } else {
      debugPrint(line);
    }
  }

  static Map<String, int> snapshot() => Map<String, int>.unmodifiable(_counts);

  @visibleForTesting
  static void reset() {
    _counts.clear();
  }

  static String _safe(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return sanitized.length <= 40 ? sanitized : sanitized.substring(0, 40);
  }
}
