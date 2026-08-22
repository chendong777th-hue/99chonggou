import 'dart:async';

typedef ChatPostOpenCanRun = bool Function();

/// Owns delayed post-open chat work so first-frame scheduling is visible in one
/// place instead of being scattered across `Future.delayed` calls.
class ChatPostOpenScheduler {
  static const Duration routeFallbackDelay = Duration(milliseconds: 1000);
  static const Duration p1Delay = Duration(milliseconds: 80);
  static const Duration p2Delay = Duration(milliseconds: 220);
  static const Duration idleDelay = Duration(milliseconds: 380);
  static const Duration muteNetworkDelay = Duration(milliseconds: 450);

  final Set<Timer> _timers = <Timer>{};
  int _generation = 0;

  int beginRun() {
    _cancelTimers();
    _generation++;
    return _generation;
  }

  void schedule({
    required int generation,
    required Duration delay,
    required ChatPostOpenCanRun canRun,
    required void Function() task,
  }) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (generation != _generation || !canRun()) {
        return;
      }
      task();
    });
    _timers.add(timer);
  }

  void cancelPending() {
    _cancelTimers();
    _generation++;
  }

  void dispose() {
    cancelPending();
  }

  void _cancelTimers() {
    if (_timers.isEmpty) {
      return;
    }
    for (final timer in _timers.toList(growable: false)) {
      timer.cancel();
    }
    _timers.clear();
  }
}
