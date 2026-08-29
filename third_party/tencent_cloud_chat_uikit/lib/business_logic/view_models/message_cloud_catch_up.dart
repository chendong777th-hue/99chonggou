import 'dart:async';

enum MessageCloudCatchUpDisposition {
  complete,
  settled,
  retry,
  offline,
  continuation,
  stalled,
}

class MessageCloudCatchUpAttempt {
  MessageCloudCatchUpAttempt({
    required this.number,
    required bool Function() isCurrent,
  }) : _isCurrent = isCurrent;

  final int number;
  final bool Function() _isCurrent;
  void Function()? _onInvalidated;

  /// A timed-out SDK future cannot be cancelled. Callers must check this
  /// before committing its eventual result through the message writer.
  bool get isCurrent => _isCurrent();

  void onInvalidated(void Function() callback) {
    _onInvalidated = callback;
  }

  void invalidate() {
    _onInvalidated?.call();
    _onInvalidated = null;
  }
}

class MessageCloudCatchUpResult {
  const MessageCloudCatchUpResult({
    required this.disposition,
    required this.attempts,
    required this.timedOut,
  });

  final MessageCloudCatchUpDisposition disposition;
  final int attempts;
  final bool timedOut;

  bool get completed => disposition == MessageCloudCatchUpDisposition.complete;
  bool get settled => disposition == MessageCloudCatchUpDisposition.settled;
  bool get needsContinuation =>
      disposition == MessageCloudCatchUpDisposition.continuation;
}

typedef MessageCloudCatchUpOperation = Future<MessageCloudCatchUpDisposition>
    Function(
  MessageCloudCatchUpAttempt attempt,
);

/// Coalesces reconnect/open/foreground reconciliation for one conversation.
///
/// The controller owns only retry, timeout and single-flight policy. Message
/// fetching and the authoritative commit remain with the reconciliation
/// writer. This separation also makes a late, non-cancellable SDK completion
/// harmless: its [MessageCloudCatchUpAttempt.isCurrent] becomes false.
class BoundedMessageCloudCatchUp {
  BoundedMessageCloudCatchUp({
    this.maxAttempts = 3,
    this.attemptTimeout = const Duration(seconds: 4),
    this.maxDuration = const Duration(seconds: 10),
    this.retryDelays = const <Duration>[
      Duration.zero,
      Duration(milliseconds: 300),
      Duration(milliseconds: 900),
    ],
    Future<void> Function(Duration delay)? delay,
  })  : assert(maxAttempts > 0),
        _delay = delay ?? Future<void>.delayed;

  final int maxAttempts;
  final Duration attemptTimeout;
  final Duration maxDuration;
  final List<Duration> retryDelays;
  final Future<void> Function(Duration delay) _delay;

  final Map<String, Future<MessageCloudCatchUpResult>> _inFlight =
      <String, Future<MessageCloudCatchUpResult>>{};
  final Map<String, Object> _activeAttemptTokens = <String, Object>{};

  bool isInFlight(String conversationID) =>
      _inFlight.containsKey(_key(conversationID));

  Future<MessageCloudCatchUpResult> run({
    required String conversationID,
    required MessageCloudCatchUpOperation operation,
  }) {
    final key = _key(conversationID);
    final existing = _inFlight[key];
    if (existing != null) {
      return existing;
    }
    late final Future<MessageCloudCatchUpResult> task;
    task = _run(key, operation).whenComplete(() {
      if (identical(_inFlight[key], task)) {
        _inFlight.remove(key);
        _activeAttemptTokens.remove(key);
      }
    });
    _inFlight[key] = task;
    return task;
  }

  Future<MessageCloudCatchUpResult> _run(
    String key,
    MessageCloudCatchUpOperation operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    var timedOut = false;
    var lastDisposition = MessageCloudCatchUpDisposition.retry;
    var attempts = 0;
    for (var index = 0; index < maxAttempts; index++) {
      final remaining = maxDuration - stopwatch.elapsed;
      if (remaining <= Duration.zero) {
        timedOut = true;
        break;
      }
      final delay = index < retryDelays.length
          ? retryDelays[index]
          : retryDelays.isEmpty
              ? Duration.zero
              : retryDelays.last;
      if (delay > Duration.zero) {
        if (delay >= remaining) {
          timedOut = true;
          break;
        }
        await _delay(delay);
      }

      final token = Object();
      attempts += 1;
      _activeAttemptTokens[key] = token;
      final attempt = MessageCloudCatchUpAttempt(
        number: index + 1,
        isCurrent: () => identical(_activeAttemptTokens[key], token),
      );
      final timeout = attemptTimeout < (maxDuration - stopwatch.elapsed)
          ? attemptTimeout
          : maxDuration - stopwatch.elapsed;
      try {
        lastDisposition = await operation(attempt).timeout(timeout);
      } on TimeoutException {
        timedOut = true;
        lastDisposition = MessageCloudCatchUpDisposition.retry;
        attempt.invalidate();
      } catch (_) {
        lastDisposition = MessageCloudCatchUpDisposition.retry;
      } finally {
        if (identical(_activeAttemptTokens[key], token)) {
          _activeAttemptTokens.remove(key);
        }
      }
      if (lastDisposition == MessageCloudCatchUpDisposition.complete ||
          lastDisposition == MessageCloudCatchUpDisposition.settled ||
          lastDisposition == MessageCloudCatchUpDisposition.offline ||
          lastDisposition == MessageCloudCatchUpDisposition.stalled) {
        return MessageCloudCatchUpResult(
          disposition: lastDisposition,
          attempts: attempts,
          timedOut: timedOut,
        );
      }
    }
    return MessageCloudCatchUpResult(
      disposition: lastDisposition,
      attempts: attempts,
      timedOut: timedOut,
    );
  }

  void invalidate(String conversationID) {
    _activeAttemptTokens.remove(_key(conversationID));
  }

  void invalidateAll() {
    _activeAttemptTokens.clear();
  }

  static String _key(String conversationID) {
    final key = conversationID.trim();
    if (key.isEmpty) {
      throw ArgumentError.value(conversationID, 'conversationID');
    }
    return key;
  }
}
