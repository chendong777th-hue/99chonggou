/// Pure helpers for contacts data-source enter coalesce / debounce.
class ContactDataSourceEnterGate {
  ContactDataSourceEnterGate._();

  static const Duration defaultDebounce = Duration(seconds: 2);

  /// Whether the network Difference + UIKit refresh phase should run.
  static bool shouldRunNetworkPhase({
    required DateTime now,
    required DateTime? lastEnterAt,
    Duration debounce = defaultDebounce,
  }) {
    if (lastEnterAt == null) {
      return true;
    }
    return now.difference(lastEnterAt) >= debounce;
  }
}

/// Joins concurrent [run] calls onto a single in-flight [Future].
class ContactDataSourceEnterSingleFlight {
  Future<void>? _inFlight;

  bool get isInFlight => _inFlight != null;

  /// Starts [run] or returns the existing in-flight Future.
  Future<void> run(Future<void> Function() body) {
    final existing = _inFlight;
    if (existing != null) {
      return existing;
    }
    late final Future<void> started;
    started = Future<void>(() async {
      try {
        await body();
      } finally {
        if (identical(_inFlight, started)) {
          _inFlight = null;
        }
      }
    });
    _inFlight = started;
    return started;
  }
}
