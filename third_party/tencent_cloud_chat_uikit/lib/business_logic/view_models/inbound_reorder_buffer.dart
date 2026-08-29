import 'dart:async';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html)
      'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// Buffers out-of-order group messages when a seq gap is detected.
///
/// When a group message arrives with `seq > expectedSeq`, the missing
/// message may arrive shortly (server reordering). This buffer holds the
/// out-of-order message for up to [timeoutMs] before flushing it to the
/// visible list and triggering a cloud catch-up for the missing messages.
///
/// Only active for group chats after [markInitialHistoryLoaded]. C2C seq
/// is per-sender and has no global continuity, so the buffer is never used
/// for C2C conversations.
class InboundReorderBuffer {
  InboundReorderBuffer({
    required void Function(List<V2TimMessage> messages) onFlush,
    required void Function(int anchorSeq, String conversationID) onGapTimeout,
    Duration timeout = const Duration(milliseconds: 500),
    int maxPending = 50,
  })  : assert(maxPending > 0),
        _onFlush = onFlush,
        _onGapTimeout = onGapTimeout,
        _timeout = timeout,
        _maxPending = maxPending;

  final void Function(List<V2TimMessage> messages) _onFlush;
  final void Function(int anchorSeq, String conversationID) _onGapTimeout;
  final Duration _timeout;
  final int _maxPending;

  final List<V2TimMessage> _pending = [];
  final Set<int> _releasedAheadSeqs = <int>{};
  final Map<int, Set<String>> _releasedAheadMsgIDs = <int, Set<String>>{};
  Timer? _timer;
  int _expectedSeq = 0;
  bool _activated = false;
  String _conversationID = '';

  bool get isActivated => _activated;
  int get expectedSeq => _expectedSeq;
  int get releasedAheadCount => _releasedAheadSeqs.length;

  /// Called when initial history is loaded. Sets the expected next seq.
  void activate(String conversationID, int newestSeq) {
    _resetPendingState();
    _conversationID = conversationID;
    _expectedSeq = newestSeq > 0 ? newestSeq + 1 : 0;
    _activated = true;
  }

  /// Attempts to accept an incoming group message. Returns the list of
  /// messages to upsert immediately (contiguous from expected), or null
  /// if the message was buffered.
  ///
  /// Returns an empty list if the message was already seen (seq < expected)
  /// or was already released after a gap timeout.
  List<V2TimMessage>? accept(V2TimMessage msg) {
    if (!_activated || _conversationID.isEmpty) {
      return [msg];
    }

    final seq = int.tryParse(msg.seq?.trim() ?? '') ?? 0;
    if (seq <= 0) {
      return [msg];
    }

    if (seq < _expectedSeq) {
      return const [];
    }
    if (_releasedAheadSeqs.contains(seq)) {
      final msgID = msg.msgID?.trim() ?? '';
      final releasedIDs = _releasedAheadMsgIDs[seq];
      // A repeated callback for the same ahead row is idempotent. A different
      // msgID at the same server Seq is a protocol conflict and must reach the
      // reconciliation writer instead of being silently discarded.
      if (msgID.isEmpty || releasedIDs?.contains(msgID) == true) {
        return const [];
      }
      return [msg];
    }

    if (seq == _expectedSeq) {
      _expectedSeq = seq + 1;
      final contiguous = [msg];
      _advanceExpectedPastReleased();
      _drainContiguous(contiguous);
      return contiguous;
    }

    // seq > expectedSeq: gap detected, buffer.
    final msgID = msg.msgID?.trim() ?? '';
    final alreadyPending = _pending.any((pending) {
      final pendingSeq = int.tryParse(pending.seq?.trim() ?? '') ?? 0;
      if (pendingSeq != seq) return false;
      final pendingMsgID = pending.msgID?.trim() ?? '';
      return msgID.isEmpty || pendingMsgID.isEmpty || pendingMsgID == msgID;
    });
    if (alreadyPending) {
      return null;
    }
    _pending.add(msg);
    _timer ??= Timer(_timeout, _onTimeout);
    if (_pending.length >= _maxPending) {
      _onTimeout();
    }
    return null;
  }

  /// Drains contiguous messages from the pending buffer.
  void _drainContiguous(List<V2TimMessage> drainable) {
    if (_pending.isEmpty) return;
    _pending.sort((a, b) =>
        (int.tryParse(a.seq ?? '') ?? 0)
            .compareTo(int.tryParse(b.seq ?? '') ?? 0));
    while (_pending.isNotEmpty) {
      _advanceExpectedPastReleased();
      final next = _pending.first;
      final nextSeq = int.tryParse(next.seq?.trim() ?? '') ?? 0;
      if (nextSeq == _expectedSeq) {
        drainable.add(_pending.removeAt(0));
        _expectedSeq = nextSeq + 1;
      } else if (nextSeq < _expectedSeq ||
          _releasedAheadSeqs.contains(nextSeq)) {
        _pending.removeAt(0);
      } else {
        break;
      }
    }
    if (_pending.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _onTimeout() {
    _timer = null;
    if (_pending.isEmpty) return;

    final anchorSeq = _expectedSeq;
    final messages = List<V2TimMessage>.of(_pending);
    _pending.clear();
    messages.sort((a, b) =>
        (int.tryParse(a.seq ?? '') ?? 0)
            .compareTo(int.tryParse(b.seq ?? '') ?? 0));
    for (final message in messages) {
      final seq = int.tryParse(message.seq?.trim() ?? '') ?? 0;
      if (seq > _expectedSeq) {
        _rememberReleasedAhead(seq, message.msgID);
      }
    }

    _onFlush(messages);
    _onGapTimeout(anchorSeq, _conversationID);
  }

  void _rememberReleasedAhead(int seq, String? msgID) {
    _releasedAheadSeqs.add(seq);
    final normalizedMsgID = msgID?.trim() ?? '';
    if (normalizedMsgID.isNotEmpty) {
      _releasedAheadMsgIDs.putIfAbsent(seq, () => <String>{}).add(normalizedMsgID);
    }
    final maxTracked = _maxPending * 4;
    while (_releasedAheadSeqs.length > maxTracked) {
      final evicted = _releasedAheadSeqs.reduce(
        (left, right) => left > right ? left : right,
      );
      _releasedAheadSeqs.remove(evicted);
      _releasedAheadMsgIDs.remove(evicted);
    }
  }

  void _advanceExpectedPastReleased() {
    while (_releasedAheadSeqs.remove(_expectedSeq)) {
      _releasedAheadMsgIDs.remove(_expectedSeq);
      _expectedSeq += 1;
    }
  }

  void _resetPendingState() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
    _releasedAheadSeqs.clear();
    _releasedAheadMsgIDs.clear();
  }

  void dispose() {
    _resetPendingState();
    _conversationID = '';
    _expectedSeq = 0;
    _activated = false;
  }
}
