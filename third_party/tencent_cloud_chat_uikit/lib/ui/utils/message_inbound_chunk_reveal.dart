import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

import 'chat_jitter_diag.dart';

typedef MessageInboundChunkRevealCallback = void Function(
  String conversationID,
  List<V2TimMessage> messages,
);

typedef MessageInboundChunkRevealDrainCallback = void Function(
  String conversationID,
  List<V2TimMessage> messages,
);

typedef MessageInboundChunkRevealSessionCallback = void Function(
  String conversationID,
);

/// Queues authoritative inbound messages for transaction-driven presentation.
///
/// A group is exposed immediately, then the queue waits for
/// [completeCurrentReveal]. This guarantees that only one shared row-height
/// animation can affect the sliver at a time.
class MessageInboundChunkedReveal {
  MessageInboundChunkedReveal({
    required this.onRevealChunk,
    required this.onDrainRemaining,
    this.onFastForward,
    this.onSupersede,
    required this.onSessionBegin,
    required this.onSessionEnd,
    Duration interval = const Duration(milliseconds: 30),
    int maxChunkSize = 24,
    bool alignToFrame = true,
    int burstBoostChunk = 4,
    Duration transactionTimeout = const Duration(seconds: 4),
    int maxAnimatedBacklog = 6,
  })  : _interval = interval,
        _maxChunkSize = maxChunkSize,
        _alignToFrame = alignToFrame,
        _transactionTimeout = transactionTimeout,
        _maxAnimatedBacklog = math.max(1, maxAnimatedBacklog);

  final MessageInboundChunkRevealCallback onRevealChunk;
  final MessageInboundChunkRevealDrainCallback onDrainRemaining;
  final MessageInboundChunkRevealCallback? onFastForward;
  /// Fired when an in-flight reveal is cancelled so only the newest message
  /// keeps its push animation. UI must abort the current slide without
  /// acknowledging the projection transaction — this class owns that ack.
  final MessageInboundChunkRevealSessionCallback? onSupersede;
  final MessageInboundChunkRevealSessionCallback onSessionBegin;
  final MessageInboundChunkRevealSessionCallback onSessionEnd;
  Duration _interval;
  int _maxChunkSize;
  bool _alignToFrame;
  final Duration _transactionTimeout;
  final int _maxAnimatedBacklog;

  Duration get interval => _interval;
  int get maxChunkSize => _maxChunkSize;

  /// Applies runtime compatibility settings without disturbing queued order.
  ///
  /// Visual pacing is driven by transaction completion; [interval] remains
  /// available for existing config consumers and diagnostics.
  void configure({
    required Duration interval,
    required int maxChunkSize,
    bool alignToFrame = true,
    int burstBoostChunk = 4,
  }) {
    _interval = interval.inMilliseconds <= 0
        ? const Duration(milliseconds: 1)
        : interval;
    _maxChunkSize = math.max(1, maxChunkSize);
    _alignToFrame = alignToFrame;
  }

  final Map<String, List<V2TimMessage>> _queues =
      <String, List<V2TimMessage>>{};
  final Set<String> _activeSessions = <String>{};
  final Set<String> _waitingForTransaction = <String>{};
  final Set<String> _scheduledTicks = <String>{};
  final Map<String, int> _generationByConv = <String, int>{};
  final Map<String, Timer> _transactionWatchdogs = <String, Timer>{};
  bool _disposed = false;

  bool isActiveFor(String conversationID) {
    final convId = conversationID.trim();
    if (convId.isEmpty) {
      return false;
    }
    final queue = _queues[convId];
    return _activeSessions.contains(convId) ||
        (queue != null && queue.isNotEmpty);
  }

  int pendingCountFor(String conversationID) =>
      _queues[conversationID.trim()]?.length ?? 0;

  void enqueueAll(String conversationID, List<V2TimMessage> messages) {
    if (_disposed) {
      return;
    }
    final convId = conversationID.trim();
    if (convId.isEmpty || messages.isEmpty) {
      return;
    }
    final queue = _queues.putIfAbsent(convId, () => <V2TimMessage>[]);
    final queueBefore = queue.length;
    final wasEmpty = queue.isEmpty;
    queue.addAll(messages);
    // Adaptive pacing: honor backlog so MaxChunk=1 configs do not stall floods.
    _applyAdaptivePacing(queue.length);
    ChatJitterDiag.logInboundFlow(
      action: 'queue_enqueue',
      conv: convId,
      extras: <String, Object?>{
        'added': messages.length,
        'queueBefore': queueBefore,
        'queueAfter': queue.length,
        'waiting': _waitingForTransaction.contains(convId),
        'maxChunk': _maxChunkSize,
        'intervalMs': _interval.inMilliseconds,
      },
    );
    if (wasEmpty) {
      _beginSession(convId);
      if (!_waitingForTransaction.contains(convId)) {
        _tick(convId);
      }
      return;
    }
    // Reveal in flight and more messages arrived: drop obsolete animation work
    // so only the newest bubble keeps a visible list-push.
    if (_waitingForTransaction.contains(convId)) {
      _supersedeInFlightReveal(convId);
    }
  }

  void _supersedeInFlightReveal(String convId) {
    if (!_waitingForTransaction.contains(convId)) {
      return;
    }
    final queue = _queues[convId];
    if (queue == null || queue.isEmpty) {
      return;
    }
    ChatJitterDiag.logInboundFlow(
      action: 'queue_supersede',
      conv: convId,
      extras: <String, Object?>{
        'queue': queue.length,
        'budget': _maxAnimatedBacklog,
      },
    );
    // UI aborts the current push without acking; we own the transaction ack.
    onSupersede?.call(convId);
    _invalidateGeneration(convId);
    _waitingForTransaction.remove(convId);
    _scheduledTicks.remove(convId);
    _transactionWatchdogs.remove(convId)?.cancel();

    final fastForward = onFastForward;
    if (fastForward != null && queue.length > _maxAnimatedBacklog) {
      final fastForwardCount = queue.length - _maxAnimatedBacklog;
      final skipped = List<V2TimMessage>.from(queue.take(fastForwardCount));
      queue.removeRange(0, fastForwardCount);
      ChatJitterDiag.logInboundFlow(
        action: 'queue_fast_forward',
        conv: convId,
        extras: <String, Object?>{
          'skipped': fastForwardCount,
          'animatedTail': queue.length,
          'budget': _maxAnimatedBacklog,
          'reason': 'supersede',
        },
      );
      fastForward(convId, skipped);
    }
    // Skip the pacing interval so the newest bubble starts immediately.
    _tick(convId);
  }

  void cancelToBuffer(String conversationID) {
    final convId = conversationID.trim();
    if (convId.isEmpty) {
      return;
    }
    _invalidateGeneration(convId);
    final remaining = _queues.remove(convId);
    _waitingForTransaction.remove(convId);
    _scheduledTicks.remove(convId);
    _transactionWatchdogs.remove(convId)?.cancel();
    ChatJitterDiag.logInboundFlow(
      action: 'queue_cancel_to_buffer',
      conv: convId,
      extras: <String, Object?>{'remaining': remaining?.length ?? 0},
    );
    _endSession(convId);
    if (remaining != null && remaining.isNotEmpty) {
      onDrainRemaining(convId, List<V2TimMessage>.from(remaining));
    }
  }

  void flushConversation(String conversationID) {
    final convId = conversationID.trim();
    if (convId.isEmpty) {
      return;
    }
    _invalidateGeneration(convId);
    final remaining = _queues.remove(convId);
    _waitingForTransaction.remove(convId);
    _scheduledTicks.remove(convId);
    _transactionWatchdogs.remove(convId)?.cancel();
    ChatJitterDiag.logInboundFlow(
      action: 'queue_flush',
      conv: convId,
      extras: <String, Object?>{'remaining': remaining?.length ?? 0},
    );
    if (remaining == null || remaining.isEmpty) {
      _endSession(convId);
      return;
    }
    onRevealChunk(convId, List<V2TimMessage>.from(remaining));
    _endSession(convId);
  }

  void cancelConversationSilently(String conversationID) {
    final convId = conversationID.trim();
    if (convId.isEmpty) {
      return;
    }
    _invalidateGeneration(convId);
    _queues.remove(convId);
    final wasActive = _activeSessions.remove(convId);
    _waitingForTransaction.remove(convId);
    _scheduledTicks.remove(convId);
    _transactionWatchdogs.remove(convId)?.cancel();
    ChatJitterDiag.logInboundFlow(
      action: 'queue_cancel_silent',
      conv: convId,
    );
    if (wasActive) {
      ChatJitterDiag.endInboundSession(convId);
    }
  }

  void cancelAllSilently() {
    final conversations = <String>{
      ..._queues.keys,
      ..._activeSessions,
      ..._waitingForTransaction,
      ..._scheduledTicks,
    };
    for (final conversationID in conversations) {
      cancelConversationSilently(conversationID);
    }
  }

  void dispose() {
    _disposed = true;
    cancelAllSilently();
    _queues.clear();
    _activeSessions.clear();
    _waitingForTransaction.clear();
    _scheduledTicks.clear();
    for (final timer in _transactionWatchdogs.values) {
      timer.cancel();
    }
    _transactionWatchdogs.clear();
    _generationByConv.clear();
  }

  void _invalidateGeneration(String convId) {
    _generationByConv[convId] = (_generationByConv[convId] ?? 0) + 1;
  }

  /// Backlog → pacing (same table as app `inboundRevealParams`).
  void _applyAdaptivePacing(int queueLen) {
    final n = queueLen < 0 ? 0 : queueLen;
    final int maxChunk;
    final int intervalMs;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (n <= 4) {
        maxChunk = 3;
        intervalMs = 60;
      } else if (n <= 12) {
        maxChunk = 6;
        intervalMs = 50;
      } else {
        maxChunk = 10;
        intervalMs = 40;
      }
    } else if (n <= 2) {
      maxChunk = 1;
      intervalMs = 160;
    } else if (n <= 8) {
      maxChunk = 3;
      intervalMs = 160;
    } else {
      maxChunk = 6;
      intervalMs = 80;
    }
    // Preserve Duration.zero / 1ms intervals used by flood drains and unit tests.
    final keepTightInterval = _interval.inMilliseconds <= 1;
    configure(
      interval: keepTightInterval
          ? _interval
          : Duration(milliseconds: intervalMs),
      maxChunkSize: maxChunk,
      alignToFrame: _alignToFrame,
    );
  }

  int _resolveChunkSize(int remaining) {
    if (remaining <= 0) {
      return 0;
    }
    // Pacing is owned by [_applyAdaptivePacing] / [configure]; take up to cap.
    return math.min(math.max(1, _maxChunkSize), remaining);
  }

  @visibleForTesting
  int resolveChunkSizeForTesting(int remaining) => _resolveChunkSize(remaining);

  void _beginSession(String convId) {
    if (_activeSessions.add(convId)) {
      _generationByConv.putIfAbsent(convId, () => 0);
      ChatJitterDiag.beginInboundSession(convId);
      onSessionBegin(convId);
    }
  }

  void _endSession(String convId) {
    if (_activeSessions.remove(convId)) {
      ChatJitterDiag.endInboundSession(convId);
      onSessionEnd(convId);
    }
    _waitingForTransaction.remove(convId);
    _scheduledTicks.remove(convId);
    _transactionWatchdogs.remove(convId)?.cancel();
  }

  /// Called by the message list after the current shared row-height animation
  /// has finished. Only then may the next projection group become visible.
  void completeCurrentReveal(String conversationID) {
    final convId = conversationID.trim();
    if (convId.isEmpty || !_waitingForTransaction.remove(convId)) {
      if (convId.isNotEmpty) {
        ChatJitterDiag.logInboundFlow(
          action: 'transaction_ack_ignored',
          conv: convId,
          extras: <String, Object?>{
            'waiting': _waitingForTransaction.contains(convId),
            'queue': _queues[convId]?.length ?? 0,
          },
          throttleKey: 'ack_ignored',
          minIntervalMs: 500,
        );
      }
      return;
    }
    _transactionWatchdogs.remove(convId)?.cancel();
    ChatJitterDiag.logInboundFlow(
      action: 'transaction_ack',
      conv: convId,
      extras: <String, Object?>{'queue': _queues[convId]?.length ?? 0},
    );
    if (_queues[convId]?.isNotEmpty == true) {
      _scheduleNextTick(convId);
    } else {
      _queues.remove(convId);
      _endSession(convId);
    }
  }

  bool isWaitingForTransaction(String conversationID) =>
      _waitingForTransaction.contains(conversationID.trim());

  void _scheduleNextTick(String convId) {
    if (_disposed || !_scheduledTicks.add(convId)) {
      return;
    }
    final generation = _generationByConv[convId] ?? 0;
    void revealNext() {
      _scheduledTicks.remove(convId);
      if (_disposed || _generationByConv[convId] != generation) {
        return;
      }
      _tick(convId);
    }

    void scheduleAlignedReveal() {
      if (_alignToFrame) {
        SchedulerBinding.instance.scheduleFrameCallback((_) => revealNext());
      } else {
        scheduleMicrotask(revealNext);
      }
    }

    // Transaction completion controls correctness; interval controls visual
    // cadence. Without this pause, short rows can start on consecutive frames
    // and sustained traffic becomes unreadably fast.
    if (_interval > Duration.zero) {
      Timer(_interval, scheduleAlignedReveal);
    } else {
      scheduleAlignedReveal();
    }
  }

  void _tick(String convId) {
    if (_disposed || _waitingForTransaction.contains(convId)) {
      return;
    }
    final queue = _queues[convId];
    if (queue == null || queue.isEmpty) {
      _queues.remove(convId);
      _endSession(convId);
      return;
    }
    // Keep animation latency bounded. Older presentation work is committed
    // immediately while the newest tail retains the full bubble animation.
    // The authoritative message list already contains every row, so this only
    // skips obsolete animation work and never drops message data.
    final fastForward = onFastForward;
    if (fastForward != null && queue.length > _maxAnimatedBacklog) {
      final fastForwardCount = queue.length - _maxAnimatedBacklog;
      final skipped = List<V2TimMessage>.from(queue.take(fastForwardCount));
      queue.removeRange(0, fastForwardCount);
      ChatJitterDiag.logInboundFlow(
        action: 'queue_fast_forward',
        conv: convId,
        extras: <String, Object?>{
          'skipped': fastForwardCount,
          'animatedTail': queue.length,
          'budget': _maxAnimatedBacklog,
        },
      );
      fastForward(convId, skipped);
      _scheduleNextTick(convId);
      return;
    }
    final chunkSize = _resolveChunkSize(queue.length);
    final chunk = List<V2TimMessage>.from(queue.take(chunkSize));
    queue.removeRange(0, chunkSize);
    if (queue.isEmpty) {
      _queues.remove(convId);
    }
    _waitingForTransaction.add(convId);
    ChatJitterDiag.beginInboundTransaction(convId);
    ChatJitterDiag.logInboundFlow(
      action: 'transaction_reveal',
      conv: convId,
      extras: <String, Object?>{
        'chunk': chunk.length,
        'queueAfter': queue.length,
        'timeoutMs': _transactionTimeout.inMilliseconds,
      },
    );
    _transactionWatchdogs.remove(convId)?.cancel();
    final generation = _generationByConv[convId] ?? 0;
    _transactionWatchdogs[convId] = Timer(_transactionTimeout, () {
      _transactionWatchdogs.remove(convId);
      if (_disposed ||
          _generationByConv[convId] != generation ||
          !_waitingForTransaction.contains(convId)) {
        return;
      }
      ChatJitterDiag.logInboundFlow(
        action: 'transaction_watchdog',
        conv: convId,
        extras: <String, Object?>{
          'queue': _queues[convId]?.length ?? 0,
          'timeoutMs': _transactionTimeout.inMilliseconds,
        },
      );
      completeCurrentReveal(convId);
    });
    onRevealChunk(convId, chunk);
  }
}
