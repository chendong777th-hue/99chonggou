import 'dart:async';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

typedef MessageInboundBatchFlush = void Function(
  String conversationID,
  List<V2TimMessage> messages,
);

/// Coalesces SDK [onRecvNewMessage] callbacks into batched UI commits.
///
/// Aligns with Telegram-style `notifyItemRangeInserted`: wait for a quiet
/// window or cap batch size, then flush once.
class MessageInboundBatchCoalescer {
  MessageInboundBatchCoalescer({
    required this.onFlush,
    this.maxBatchSize = 50,
    this.maxDelay = const Duration(milliseconds: 50),
  });

  final MessageInboundBatchFlush onFlush;
  final int maxBatchSize;
  final Duration maxDelay;

  final Map<String, List<V2TimMessage>> _pendingByConv = {};
  final Map<String, Timer> _timersByConv = {};

  void enqueue(String conversationID, V2TimMessage message) {
    final convId = conversationID.trim();
    if (convId.isEmpty) {
      return;
    }
    final pending = _pendingByConv.putIfAbsent(convId, () => <V2TimMessage>[]);
    pending.add(message);
    if (pending.length >= maxBatchSize) {
      _flush(convId);
      return;
    }
    _timersByConv[convId]?.cancel();
    _timersByConv[convId] = Timer(maxDelay, () => _flush(convId));
  }

  void flushConversation(String conversationID) {
    _flush(conversationID.trim());
  }

  void flushAll() {
    for (final convId in List<String>.from(_pendingByConv.keys)) {
      _flush(convId);
    }
  }

  void cancelAllSilently() {
    for (final timer in _timersByConv.values) {
      timer.cancel();
    }
    _timersByConv.clear();
    _pendingByConv.clear();
  }

  void dispose() => cancelAllSilently();

  int pendingCountFor(String conversationID) =>
      _pendingByConv[conversationID.trim()]?.length ?? 0;

  void _flush(String convId) {
    if (convId.isEmpty) {
      return;
    }
    _timersByConv.remove(convId)?.cancel();
    final pending = _pendingByConv.remove(convId);
    if (pending == null || pending.isEmpty) {
      return;
    }
    onFlush(convId, List<V2TimMessage>.from(pending));
  }
}
