import 'dart:async';
import 'dart:collection';

import 'package:tencent_cloud_chat_demo/src/services/im/contracts/contracts.dart';

enum ImIngressLane { urgent, realtime, history, background }

typedef ImMailboxEventHandler = FutureOr<void> Function(
  EventEnvelope<dynamic> event,
);

/// Scope router with one serialized queue per logical event scope.
///
/// A mailbox never owns durable state and never performs network I/O itself.
/// It only orders already-accepted events before handing them to the core.
class ImMailboxRouter {
  ImMailboxRouter({
    required ImMailboxEventHandler handler,
    this.maxActiveMailboxes = 64,
  }) : _handler = handler {
    if (maxActiveMailboxes <= 0) {
      throw ArgumentError.value(
        maxActiveMailboxes,
        'maxActiveMailboxes',
        'must be positive',
      );
    }
  }

  final ImMailboxEventHandler _handler;
  final int maxActiveMailboxes;
  final Map<String, _ImMailbox> _mailboxes = <String, _ImMailbox>{};

  int get activeMailboxCount => _mailboxes.length;

  Future<void> dispatch<T>(
    EventEnvelope<T> event, {
    ImIngressLane lane = ImIngressLane.realtime,
  }) {
    final key = _mailboxKey(event);
    final existing = _mailboxes[key];
    late final _ImMailbox mailbox;
    if (existing != null) {
      mailbox = existing;
    } else {
      if (_mailboxes.length >= maxActiveMailboxes) {
        throw StateError('IM mailbox limit reached: $maxActiveMailboxes');
      }
      late final _ImMailbox created;
      created = _ImMailbox(
        handler: _handler,
        onIdle: () => _evictIfIdle(key, created),
      );
      mailbox = created;
      _mailboxes[key] = created;
    }
    return mailbox.enqueue(event, lane: lane);
  }

  Future<void> drain() async {
    final pending = _mailboxes.values
        .map((mailbox) => mailbox.drain())
        .toList(growable: false);
    await Future.wait<void>(pending);
  }

  String _mailboxKey(EventEnvelope<dynamic> event) {
    final scope = event.scope?.canonicalConversationId ?? '@account';
    return '${event.ownerUserId}|${event.eventNamespace}|$scope';
  }

  void _evictIfIdle(String key, _ImMailbox mailbox) {
    if (mailbox.isIdle && identical(_mailboxes[key], mailbox)) {
      _mailboxes.remove(key);
    }
  }
}

class _ImMailbox {
  _ImMailbox({required this.handler, required this.onIdle});

  final ImMailboxEventHandler handler;
  final void Function() onIdle;
  final Map<ImIngressLane, Queue<_QueuedEvent>> _queues = {
    ImIngressLane.urgent: Queue<_QueuedEvent>(),
    ImIngressLane.realtime: Queue<_QueuedEvent>(),
    ImIngressLane.history: Queue<_QueuedEvent>(),
    ImIngressLane.background: Queue<_QueuedEvent>(),
  };
  bool _running = false;

  bool get isIdle =>
      !_running && _queues.values.every((queue) => queue.isEmpty);

  Future<void> enqueue<T>(
    EventEnvelope<T> event, {
    required ImIngressLane lane,
  }) {
    final completer = Completer<void>();
    _queues[lane]!.add(
      _QueuedEvent(event: event, completer: completer),
    );
    unawaited(_pump());
    return completer.future;
  }

  Future<void> drain() async {
    while (!isIdle) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final next = _takeNext();
        if (next == null) return;
        try {
          await handler(next.event);
          next.completer.complete();
        } catch (error, stack) {
          if (!next.completer.isCompleted) {
            next.completer.completeError(error, stack);
          }
        }
      }
    } finally {
      _running = false;
      onIdle();
    }
  }

  _QueuedEvent? _takeNext() {
    for (final lane in ImIngressLane.values) {
      final queue = _queues[lane]!;
      if (queue.isNotEmpty) return queue.removeFirst();
    }
    return null;
  }
}

class _QueuedEvent {
  const _QueuedEvent({required this.event, required this.completer});

  final EventEnvelope<dynamic> event;
  final Completer<void> completer;
}
