import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/frame.dart';

/// Lightweight bounded timings for chat-page frame pressure in debug/Profile.
class ChatMainThreadPerf {
  ChatMainThreadPerf._();

  static const String historyMergeMs = 'history_merge_ms';
  static const String setMessageListMs = 'set_message_list_ms';
  static const String groupMetadataApplyMs = 'group_metadata_apply_ms';
  static const String conversationReloadMs = 'conversation_reload_ms';
  static const String imageDecodeMs = 'image_decode_ms';
  static const String keyboardLayoutMs = 'keyboard_layout_ms';
  static const String frameBuildMs = 'frame_build_ms';
  static const String frameRasterMs = 'frame_raster_ms';
  static const String frameTotalMs = 'frame_total_ms';
  static const String openingPlaceholderFirstPaintMs =
      'opening_placeholder_first_paint_ms';
  static const String openingPlaceholderVisibleMs =
      'opening_placeholder_visible_ms';
  static const String messagesFirstVisibleMs = 'messages_first_visible_ms';

  // Keep debug builds quiet by default; Profile is the explicit performance
  // sampling build and should emit the bounded timings during capture.
  static const bool localProfileEnabled = false;
  static const bool enabledInProfile = true;
  static const int _maxSamplesPerMetric = 120;
  static const int _summaryEverySamples = 30;

  @visibleForTesting
  static bool debugForceEnabled = false;

  @visibleForTesting
  static void Function(String line)? debugSink;

  static bool get isEnabled =>
      !kReleaseMode &&
      (localProfileEnabled ||
          (kProfileMode && enabledInProfile) ||
          debugForceEnabled);

  static final Map<String, int> _counters = <String, int>{};
  static final Map<String, List<int>> _durationSamples = <String, List<int>>{};
  static final Map<String, int> _samplesSinceSummary = <String, int>{};
  static int _frameProbeDepth = 0;

  static void increment(String metric, {int amount = 1}) {
    if (!isEnabled || amount <= 0) return;
    _counters[metric] = (_counters[metric] ?? 0) + amount;
  }

  static Map<String, int> countersSnapshot() =>
      Map<String, int>.unmodifiable(_counters);

  /// Latest bounded duration samples, exposed only for deterministic tests.
  @visibleForTesting
  static List<int> durationSamplesForTest(String metric) =>
      List<int>.unmodifiable(_durationSamples[metric] ?? const <int>[]);

  @visibleForTesting
  static void resetCounters() {
    _counters.clear();
    _durationSamples.clear();
    _samplesSinceSummary.clear();
  }

  /// Frame's callback is process-global. Retain a shared passive listener for
  /// each live Chat instead of overwriting window.onReportTimings.
  static void retainFrameTimingProbe() {
    if (!isEnabled) return;
    _frameProbeDepth++;
    if (_frameProbeDepth == 1) {
      Frame.addTimingsListener(_onFrameTimings);
    }
  }

  static void releaseFrameTimingProbe() {
    if (_frameProbeDepth <= 0) return;
    _frameProbeDepth--;
    if (_frameProbeDepth == 0) {
      Frame.removeTimingsListener(_onFrameTimings);
    }
  }

  static void _onFrameTimings(List<FrameTiming> timings) {
    if (!isEnabled) return;
    for (final timing in timings) {
      recordDurationMicros(
        frameBuildMs,
        timing.buildDuration.inMicroseconds,
        source: 'frame',
      );
      recordDurationMicros(
        frameRasterMs,
        timing.rasterDuration.inMicroseconds,
        source: 'frame',
      );
      final total = timing.timestampInMicroseconds(FramePhase.rasterFinish) -
          timing.timestampInMicroseconds(FramePhase.buildStart);
      if (total >= 0) {
        recordDurationMicros(frameTotalMs, total, source: 'frame');
      }
    }
  }

  static String conversationTypeForId(String conversationId) {
    final value = conversationId.trim();
    return value.startsWith('group_') || value.startsWith('@TGS')
        ? 'group'
        : 'c2c';
  }

  static T measure<T>(
    String metric,
    T Function() operation, {
    int? count,
    String? source,
    String? conversationType,
  }) {
    if (!isEnabled) {
      return operation();
    }
    final stopwatch = Stopwatch()..start();
    try {
      return operation();
    } finally {
      stopwatch.stop();
      recordDurationMicros(
        metric,
        stopwatch.elapsedMicroseconds,
        count: count,
        source: source,
        conversationType: conversationType,
      );
    }
  }

  static Future<T> measureAsync<T>(
    String metric,
    Future<T> Function() operation, {
    int? count,
    String? source,
    String? conversationType,
  }) async {
    if (!isEnabled) {
      return operation();
    }
    final stopwatch = Stopwatch()..start();
    try {
      return await operation();
    } finally {
      stopwatch.stop();
      recordDurationMicros(
        metric,
        stopwatch.elapsedMicroseconds,
        count: count,
        source: source,
        conversationType: conversationType,
      );
    }
  }

  /// Records one completed operation. Individual timings remain available in
  /// Profile logs, with a p50/p95 line every bounded sample batch.
  static void recordDurationMicros(
    String metric,
    int elapsedMicros, {
    int? count,
    String? source,
    String? conversationType,
  }) {
    if (!isEnabled) return;
    // Frame-level sampling is intentionally silent. These callbacks run for
    // every rendered frame and their p50/p95 output overwhelms application
    // logs; operation-level metrics remain available.
    final suppressFrameLog = metric == frameBuildMs ||
        metric == frameRasterMs ||
        metric == frameTotalMs;
    final safeMicros = elapsedMicros < 0 ? 0 : elapsedMicros;
    if (!suppressFrameLog) {
      _emit(metric, safeMicros, count, source, conversationType);
    }
    final samples = _durationSamples.putIfAbsent(metric, () => <int>[]);
    samples.add(safeMicros);
    if (samples.length > _maxSamplesPerMetric) {
      samples.removeRange(0, samples.length - _maxSamplesPerMetric);
    }
    final sinceSummary = (_samplesSinceSummary[metric] ?? 0) + 1;
    _samplesSinceSummary[metric] = sinceSummary;
    if (sinceSummary < _summaryEverySamples || suppressFrameLog) return;
    _samplesSinceSummary[metric] = 0;
    _emitSummary(metric, samples);
  }

  static void _emitSummary(String metric, List<int> samples) {
    if (samples.isEmpty) return;
    final sorted = List<int>.of(samples)..sort();
    int percentile(double value) {
      final index = ((sorted.length - 1) * value).ceil();
      return sorted[index.clamp(0, sorted.length - 1)];
    }

    final fields = <String>[
      '[ChatMainPerf]',
      'metric=${_safeLabel(metric)}',
      'summary=p50_p95',
      'samples=${sorted.length}',
      'p50_ms=${(percentile(0.50) / 1000).toStringAsFixed(3)}',
      'p95_ms=${(percentile(0.95) / 1000).toStringAsFixed(3)}',
    ];
    final line = fields.join(' ');
    final sink = debugSink;
    if (sink != null) {
      sink(line);
    } else {
      debugPrint(line);
    }
  }

  static void _emit(
    String metric,
    int elapsedMicros,
    int? count,
    String? source,
    String? conversationType,
  ) {
    final fields = <String>[
      '[ChatMainPerf]',
      'metric=${_safeLabel(metric)}',
      'ms=${(elapsedMicros / 1000).toStringAsFixed(3)}',
      if (count != null) 'count=$count',
      if (source != null) 'source=${_safeLabel(source)}',
      if (conversationType != null) 'convType=${_safeLabel(conversationType)}',
    ];
    final line = fields.join(' ');
    final sink = debugSink;
    if (sink != null) {
      sink(line);
    } else {
      debugPrint(line);
    }
  }

  static String _safeLabel(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return sanitized.length <= 32 ? sanitized : sanitized.substring(0, 32);
  }
}
