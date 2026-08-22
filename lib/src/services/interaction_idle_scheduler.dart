import 'dart:async';

import 'package:flutter/scheduler.dart';

/// Coalesces non-critical work and starts it after the current interaction.
///
/// Startup/resume callers use stable keys so repeated lifecycle signals do not
/// launch the same image, network and database work in one frame window.
class InteractionIdleScheduler {
  InteractionIdleScheduler._();

  static final InteractionIdleScheduler instance = InteractionIdleScheduler._();

  final Map<String, Timer> _timers = <String, Timer>{};

  void schedule(
    String key, {
    required Duration delay,
    required FutureOr<void> Function() task,
  }) {
    _timers.remove(key)?.cancel();
    _timers[key] = Timer(delay, () {
      _timers.remove(key);
      SchedulerBinding.instance.scheduleTask<void>(
        () {
          unawaited(Future<void>.sync(() async => task()));
        },
        Priority.idle,
        debugLabel: 'interaction_idle_$key',
      );
    });
  }

  void cancel(String key) => _timers.remove(key)?.cancel();

  void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
