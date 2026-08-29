import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';

/// 会话性能验收计数器；不向控制台输出。
class ConversationPerfGateLog {
  ConversationPerfGateLog._();

  static bool enabled = false;

  /// conversationID → 消息侧首次打点毫秒（realtime 三段耗时）。
  static final Map<String, int> _msgRecvAtMsByConv = <String, int>{};

  @visibleForTesting
  static final Map<String, int> eventCountsForTest = <String, int>{};

  @visibleForTesting
  static void resetCountsForTest() => eventCountsForTest.clear();

  static bool skipUnreadAggregateScheduleForTest = false;

  static String _traceHash(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return '';
    }
    return sha256.convert(utf8.encode(normalized)).toString().substring(0, 12);
  }

  /// Plan 093 monotonic-preview trace. Never include message bodies or raw IDs.
  static void traceConversationProjection({
    required String stage,
    required String conversationId,
    String messageId = '',
    int timestamp = 0,
    int orderkey = 0,
    String source = '',
    int sequence = 0,
    String decision = '',
  }) {
    final traceId = _traceHash('$conversationId\u001f$messageId');
    log(
      'conversation_projection_trace',
      extras: <String, Object?>{
        'stage': stage,
        'trace': traceId,
        'conversation': _traceHash(conversationId),
        'message': _traceHash(messageId),
        'timestamp': timestamp,
        'orderkey': orderkey,
        'source': source,
        'sequence': sequence,
        'decision': decision,
      },
    );
  }

  static void log(
    String event, {
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    eventCountsForTest[event] = (eventCountsForTest[event] ?? 0) + 1;
  }

  /// 消息通道（横幅/通知）到达。
  static void markRealtimeMsgRecv({
    required String conversationId,
    String? msgId,
  }) {
    if (!ConversationPerfFlags.conversationRealtimeLatencyLogEnabled) {
      return;
    }
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    _msgRecvAtMsByConv[id] = now;
    log(
      'realtime_latency',
      extras: <String, Object?>{
        'stage': 'msg_recv',
        'convId': id,
        'msgId': msgId ?? '',
      },
    );
  }

  /// SDK 会话回调进入 persist。
  static void markRealtimeConversationCallback({
    required String conversationId,
    required String reason,
  }) {
    if (!ConversationPerfFlags.conversationRealtimeLatencyLogEnabled) {
      return;
    }
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final recv = _msgRecvAtMsByConv[id];
    log(
      'realtime_latency',
      extras: <String, Object?>{
        'stage': 'conversation_callback',
        'convId': id,
        'reason': reason,
        'msgToCallbackMs': recv == null ? -1 : now - recv,
      },
    );
  }

  /// 本地写库完成、准备灌 UI。
  static void markRealtimePersistDone({
    required String conversationId,
    required String reason,
  }) {
    if (!ConversationPerfFlags.conversationRealtimeLatencyLogEnabled) {
      return;
    }
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final recv = _msgRecvAtMsByConv[id];
    log(
      'realtime_latency',
      extras: <String, Object?>{
        'stage': 'persist_done',
        'convId': id,
        'reason': reason,
        'msgToPersistMs': recv == null ? -1 : now - recv,
      },
    );
  }

  /// Feed `notifyListeners` 实际发出。
  static void markRealtimeUiNotify({
    required String reason,
  }) {
    if (!ConversationPerfFlags.conversationRealtimeLatencyLogEnabled) {
      return;
    }
    log(
      'realtime_latency',
      extras: <String, Object?>{
        'stage': 'ui_notify',
        'reason': reason,
      },
    );
  }
}
