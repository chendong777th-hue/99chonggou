import 'package:flutter/foundation.dart';

/// Profile-gated wall-time probe for Main-thread RegExp hotspots.
///
/// Filter keyword: `[RegExpProbe]`.
/// Default off in release; on in profile builds via [enabledInProfile].
class RegExpProbe {
  RegExpProbe._();

  static const bool enabled = false;
  /// On for profile builds so list→chat RegExp sites show in device logs
  /// (`[RegExpProbe]`). Release stays off via [enabled].
  static const bool enabledInProfile = true;

  static bool get isEnabled =>
      enabled || (kProfileMode && enabledInProfile) || _debugForceEnabled;

  /// Test-only override. Production code must leave this false.
  @visibleForTesting
  static bool debugForceEnabled = false;

  static bool get _debugForceEnabled => debugForceEnabled;

  static final Map<String, _RegExpProbeSite> _sites = <String, _RegExpProbeSite>{};

  static T measure<T>(String site, T Function() body) {
    if (!isEnabled) {
      return body();
    }
    final sw = Stopwatch()..start();
    try {
      return body();
    } finally {
      sw.stop();
      final entry = _sites.putIfAbsent(site, _RegExpProbeSite.new);
      entry.calls += 1;
      entry.elapsedUs += sw.elapsedMicroseconds;
    }
  }

  static void recordMatch(String site, {int count = 1}) {
    if (!isEnabled || count <= 0) {
      return;
    }
    final entry = _sites.putIfAbsent(site, _RegExpProbeSite.new);
    entry.matchInvocations += count;
  }

  static void reset() {
    _sites.clear();
  }

  static void dump({String reason = ''}) {
    if (!isEnabled) {
      return;
    }
    final ranked = _sites.entries.toList()
      ..sort((a, b) => b.value.elapsedUs.compareTo(a.value.elapsedUs));
    final reasonPart = reason.trim().isEmpty ? '' : ' reason=$reason';
    if (ranked.isEmpty) {
      // ignore: avoid_print
      print('[RegExpProbe] dump$reasonPart (empty)');
      return;
    }
    final buffer = StringBuffer('[RegExpProbe] dump$reasonPart');
    for (final e in ranked) {
      buffer.write(
        ' | ${e.key}: calls=${e.value.calls} '
        'us=${e.value.elapsedUs} matches=${e.value.matchInvocations}',
      );
    }
    // ignore: avoid_print
    print(buffer.toString());
  }

  @visibleForTesting
  static Map<String, ({int calls, int elapsedUs, int matchInvocations})>
      snapshotForTesting() {
    return <String, ({int calls, int elapsedUs, int matchInvocations})>{
      for (final e in _sites.entries)
        e.key: (
          calls: e.value.calls,
          elapsedUs: e.value.elapsedUs,
          matchInvocations: e.value.matchInvocations,
        ),
    };
  }
}

class _RegExpProbeSite {
  int calls = 0;
  int elapsedUs = 0;
  int matchInvocations = 0;
}
