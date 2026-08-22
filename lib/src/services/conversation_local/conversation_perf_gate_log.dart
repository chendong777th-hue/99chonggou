import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';

/// 会话性能验收探针。过滤：`[ConvPerfGate]`
///
/// 与 `[SqfliteLock]` 并列；正式包可关 [enabled]。
class ConversationPerfGateLog {
  ConversationPerfGateLog._();

  /// 验收包默认开；收工可改 `false`。
  static bool enabled = false;

  static int _seq = 0;

  /// conversationID → 消息侧首次打点毫秒（realtime 三段耗时）。
  static final Map<String, int> _msgRecvAtMsByConv = <String, int>{};

  @visibleForTesting
  static final Map<String, int> eventCountsForTest = <String, int>{};

  @visibleForTesting
  static void resetCountsForTest() => eventCountsForTest.clear();

  @visibleForTesting
  static bool skipUnreadAggregateScheduleForTest = false;

  static void log(
    String event, {
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    eventCountsForTest[event] = (eventCountsForTest[event] ?? 0) + 1;
    if (!enabled) {
      return;
    }
    final seq = ++_seq;
    final t = DateTime.now().millisecondsSinceEpoch;
    final buf = StringBuffer('[ConvPerfGate] #$seq t=$t event=$event');
    for (final entry in extras.entries) {
      buf.write(' ${entry.key}=${entry.value}');
    }
    // ignore: avoid_print
    print(buf.toString());
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
