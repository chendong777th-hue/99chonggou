import 'package:flutter/foundation.dart';

/// Opt-in wall-time probe for RegExp hotspots.
class RegExpProbe {
  RegExpProbe._();

  static const bool enabled = false;
  // Profile builds are the production-like sampling build used for hitch
  // capture. Keep debug builds quiet unless a test explicitly forces probes.
  static const bool enabledInProfile = true;
  static const int _maxSamplesPerSite = 120;

  static bool get isEnabled =>
      enabled || (kProfileMode && enabledInProfile) || _debugForceEnabled;

  /// Test-only override. Production code must leave this false.
  @visibleForTesting
  static bool debugForceEnabled = false;

  static bool get _debugForceEnabled => debugForceEnabled;

  static final Map<String, _RegExpProbeSite> _sites =
      <String, _RegExpProbeSite>{};

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
      final elapsedUs = sw.elapsedMicroseconds;
      entry.elapsedUs += elapsedUs;
      entry.samples.add(elapsedUs);
      if (entry.samples.length > _maxSamplesPerSite) {
        entry.samples.removeRange(
          0,
          entry.samples.length - _maxSamplesPerSite,
        );
      }
    }
  }

  static void recordMatch(String site, {int count = 1}) {
    if (!isEnabled || count <= 0) {
      return;
    }
    final entry = _sites.putIfAbsent(site, _RegExpProbeSite.new);
    entry.matchInvocations += count;
  }

  /// Records cache activity without timing the cache lookup itself. This
  /// keeps the probe useful for distinguishing repeated regex work from cache
  /// churn while adding only one integer increment to the hot path.
  static void recordCacheHit(String site, {int count = 1}) {
    if (!isEnabled || count <= 0) {
      return;
    }
    final entry = _sites.putIfAbsent(site, _RegExpProbeSite.new);
    entry.cacheHits += count;
  }

  static void recordCacheMiss(String site, {int count = 1}) {
    if (!isEnabled || count <= 0) {
      return;
    }
    final entry = _sites.putIfAbsent(site, _RegExpProbeSite.new);
    entry.cacheMisses += count;
  }

  static void reset() {
    _sites.clear();
  }

  /// Emits a bounded diagnostic snapshot. Deliberately called at lifecycle or
  /// batch boundaries instead of every invocation, so Profile logging does not
  /// perturb the frame being measured.
  static void dump({String reason = ''}) {
    if (!isEnabled || _sites.isEmpty) {
      return;
    }
    final sites = _sites.entries.toList()
      ..sort((a, b) => b.value.elapsedUs.compareTo(a.value.elapsedUs));
    _emit(
        '[RegExpProbe] dump reason=${_safeLabel(reason)} sites=${sites.length}');
    for (final entry in sites) {
      final site = entry.value;
      final samples = List<int>.of(site.samples)..sort();
      final p50 = _percentile(samples, 0.50);
      final p95 = _percentile(samples, 0.95);
      _emit(
        '[RegExpProbe] site=${_safeLabel(entry.key)} '
        'calls=${site.calls} matches=${site.matchInvocations} '
        'cacheHits=${site.cacheHits} cacheMisses=${site.cacheMisses} '
        'totalUs=${site.elapsedUs} p50Us=$p50 p95Us=$p95',
      );
    }
  }

  static int _percentile(List<int> sorted, double fraction) {
    if (sorted.isEmpty) {
      return 0;
    }
    final index = ((sorted.length - 1) * fraction).ceil();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  static void _emit(String line) {
    final sink = debugSink;
    if (sink != null) {
      sink(line);
    } else {
      debugPrint(line);
    }
  }

  static String _safeLabel(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return sanitized.length <= 64 ? sanitized : sanitized.substring(0, 64);
  }

  @visibleForTesting
  static void Function(String line)? debugSink;

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
  int cacheHits = 0;
  int cacheMisses = 0;
  final List<int> samples = <int>[];
}
