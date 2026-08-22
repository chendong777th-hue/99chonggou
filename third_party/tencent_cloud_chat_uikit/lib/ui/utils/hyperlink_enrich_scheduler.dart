import 'package:flutter/widgets.dart';

/// Caps how many deferred hyperlink upgrades run per frame after chat open.
///
/// [DeferredHyperlinkText] used to give every bubble its own post-frame
/// callback, so all visible rows enriched on the same next frame (RegExp
/// storm). Jobs are FIFO; at most [maxPerFrame] run per frame.
class HyperlinkEnrichScheduler {
  HyperlinkEnrichScheduler._();

  static final HyperlinkEnrichScheduler instance = HyperlinkEnrichScheduler._();

  /// Default enrich upgrades applied in a single frame.
  static const int defaultMaxPerFrame = 2;

  int maxPerFrame = defaultMaxPerFrame;

  final List<VoidCallback> _queue = <VoidCallback>[];
  bool _pumpScheduled = false;

  @visibleForTesting
  int get pendingCount => _queue.length;

  @visibleForTesting
  bool get isPumpScheduled => _pumpScheduled;

  void schedule(VoidCallback job) {
    _queue.add(job);
    _ensurePump();
  }

  void _ensurePump() {
    if (_pumpScheduled) {
      return;
    }
    _pumpScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pumpScheduled = false;
      _drainFrame();
      if (_queue.isNotEmpty) {
        _ensurePump();
      }
    });
  }

  void _drainFrame() {
    final limit = maxPerFrame < 1 ? 1 : maxPerFrame;
    var ran = 0;
    while (ran < limit && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      ran++;
      job();
    }
  }

  @visibleForTesting
  void debugReset() {
    _queue.clear();
    _pumpScheduled = false;
    maxPerFrame = defaultMaxPerFrame;
  }
}
