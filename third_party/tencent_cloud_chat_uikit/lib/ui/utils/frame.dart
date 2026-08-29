// ignore_for_file: avoid_print

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/logger.dart';

/// Lightweight FPS sampler for profile builds.
///
/// [init] is **idempotent** and ref-counted. Calling it twice without
/// [destroy] must not chain [onReportTimings] onto itself (that caused
/// Stack Overflow in `docs/pro-scenario.md`).
class Frame {
  Frame._();

  static TimingsCallback? _previousCallback;
  static bool _installed = false;
  static int _installDepth = 0;
  static final Set<TimingsCallback> _timingsListeners = <TimingsCallback>{};

  /// Optional: log fps every [fpsLogEveryNFrames] reports (0 = never).
  @visibleForTesting
  static int fpsLogEveryNFrames = 0;

  static int _reportsSinceLog = 0;

  // Keep the last 25 frame timings for [fps].
  static const int maxFrames = 25;
  static final List<FrameTiming> lastFrames = <FrameTiming>[];

  static const Duration frameInterval =
      Duration(microseconds: Duration.microsecondsPerSecond ~/ 60);

  @visibleForTesting
  static bool get debugIsInstalled => _installed;

  @visibleForTesting
  static int get debugInstallDepth => _installDepth;

  static void init() {
    if (_installed) {
      _installDepth++;
      return;
    }
    final current = window.onReportTimings;
    // Never chain ourselves — double-init without destroy used to do this.
    _previousCallback =
        identical(current, onReportTimings) ? null : current;
    window.onReportTimings = onReportTimings;
    _installed = true;
    _installDepth = 1;
  }

  static void onReportTimings(List<FrameTiming> timings) {
    lastFrames.addAll(timings);
    if (lastFrames.length > maxFrames) {
      lastFrames.removeRange(0, lastFrames.length - maxFrames);
    }

    final prev = _previousCallback;
    if (prev != null && !identical(prev, onReportTimings)) {
      prev(timings);
    }

    // Keep additional probes off window.onReportTimings itself. There is only
    // one platform callback; replacing it for every Chat instance either
    // drops another consumer or recursively chains callbacks.
    for (final listener in _timingsListeners.toList(growable: false)) {
      listener(timings);
    }

    if (fpsLogEveryNFrames > 0) {
      _reportsSinceLog++;
      if (_reportsSinceLog >= fpsLogEveryNFrames) {
        _reportsSinceLog = 0;
        outputLogger.i('fps: $fps');
      }
    }
  }

  /// Registers a passive FrameTiming consumer without taking ownership of the
  /// platform callback. Repeated registrations of the same callback are
  /// intentionally idempotent.
  static void addTimingsListener(TimingsCallback listener) {
    _timingsListeners.add(listener);
  }

  static void removeTimingsListener(TimingsCallback listener) {
    _timingsListeners.remove(listener);
  }

  static double get fps {
    if (lastFrames.isEmpty) {
      return 60;
    }
    var sum = 0;
    for (final timing in lastFrames) {
      final duration =
          timing.timestampInMicroseconds(FramePhase.rasterFinish) -
              timing.timestampInMicroseconds(FramePhase.buildStart);
      if (duration < frameInterval.inMicroseconds) {
        sum += 1;
      } else {
        sum += (duration / frameInterval.inMicroseconds).ceil();
      }
    }
    if (sum == 0) {
      return 60;
    }
    return lastFrames.length / sum * 60;
  }

  static void destroy() {
    if (!_installed) {
      return;
    }
    _installDepth--;
    if (_installDepth > 0) {
      return;
    }
    window.onReportTimings = _previousCallback;
    _previousCallback = null;
    _installed = false;
    _installDepth = 0;
    lastFrames.clear();
    _reportsSinceLog = 0;
  }

  @visibleForTesting
  static void debugReset() {
    if (_installed) {
      window.onReportTimings = _previousCallback;
    }
    _previousCallback = null;
    _installed = false;
    _installDepth = 0;
    lastFrames.clear();
    _reportsSinceLog = 0;
    _timingsListeners.clear();
    fpsLogEveryNFrames = 0;
  }
}
