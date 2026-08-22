import 'package:flutter/foundation.dart';

/// 发布版可见：进入聊天页耗时追踪。过滤关键字：`[ChatOpenPerf]`
///
/// 用法：Xcode / `flutter logs` / Android logcat 搜 `ChatOpenPerf`。
/// 每条含 `elapsedMs`（距点击）与 `deltaMs`（距上一里程碑），以及 `region` 中文阶段名。
/// 追完沉重感后把 [enabled] 改回 false。
class ChatOpenPerfLog {
  ChatOpenPerfLog._();

  /// 发布版进页追沉重感时保持 true；收工后改 false。
  static const bool enabled = false;

  /// Profile 构建下默认可开，便于真机采进页里程碑。
  static const bool enabledInProfile = false;

  static bool get isEnabled =>
      enabled || (kProfileMode && enabledInProfile);

  static String _sessionId = '';
  static int _t0Ms = 0;
  static int _lastMarkMs = 0;
  static String _lastEvent = '';
  static String _convId = '';
  static bool _firstMessagesVisibleLogged = false;
  static bool _historyListBuiltLogged = false;

  static String get sessionId => _sessionId;

  /// 点会话 / 即将打开聊天时调用，开启一轮会话时钟。
  static void beginOpen({
    required String conversationID,
    required String phase,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!isEnabled) {
      return;
    }
    final id = conversationID.trim();
    _convId = id;
    _t0Ms = DateTime.now().millisecondsSinceEpoch;
    _lastMarkMs = _t0Ms;
    _lastEvent = 'session_begin';
    _firstMessagesVisibleLogged = false;
    _historyListBuiltLogged = false;
    _sessionId =
        'open_${_t0Ms.toRadixString(36)}_${id.hashCode.toRadixString(16)}';
    _print(
      'session_begin',
      extras: <String, Object?>{
        'phase': phase,
        'session': _sessionId,
        'region': regionOf('session_begin'),
        'elapsedMs': 0,
        'deltaMs': 0,
        ...extras,
      },
    );
  }

  /// 相对 [beginOpen] 的里程碑（含 elapsedMs + deltaMs）。
  static void mark(
    String event, {
    String? conversationID,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!isEnabled) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = _t0Ms > 0 ? now - _t0Ms : -1;
    final delta = _lastMarkMs > 0 ? now - _lastMarkMs : -1;
    _print(
      event,
      conversationID: conversationID,
      extras: <String, Object?>{
        'session': _sessionId.isEmpty ? '-' : _sessionId,
        'region': regionOf(event),
        'elapsedMs': elapsed,
        'deltaMs': delta,
        'prev': _lastEvent.isEmpty ? '-' : _lastEvent,
        ...extras,
      },
    );
    _lastMarkMs = now;
    _lastEvent = event;
  }

  /// 历史列表 Widget 首次 build（可能仍空壳）。每 session 一次。
  static void markHistoryListBuilt({
    required String conversationID,
    required int messageCount,
    required bool initialLoaded,
    bool bootstrapping = false,
  }) {
    if (!isEnabled || _historyListBuiltLogged) {
      return;
    }
    _historyListBuiltLogged = true;
    mark(
      'history_list_first_build',
      conversationID: conversationID,
      extras: <String, Object?>{
        'messageCount': messageCount,
        'initialLoaded': initialLoaded,
        'bootstrapping': bootstrapping,
      },
    );
  }

  /// 消息列表首次非空并完成一帧绘制。每 session 一次 —— 这是「消息出现」主指标。
  static void markMessagesFirstVisible({
    required String conversationID,
    required int messageCount,
    String source = 'list',
  }) {
    if (!isEnabled || _firstMessagesVisibleLogged) {
      return;
    }
    if (messageCount <= 0) {
      return;
    }
    _firstMessagesVisibleLogged = true;
    mark(
      'messages_first_visible',
      conversationID: conversationID,
      extras: <String, Object?>{
        'messageCount': messageCount,
        'source': source,
        'note': '首屏消息对用户可见（post-frame）',
      },
    );
    _printSummary();
  }

  static void _printSummary() {
    if (!isEnabled || _t0Ms <= 0) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    // ignore: avoid_print
    print(
      '[ChatOpenPerf] event=open_summary '
      'conv=$_convId session=$_sessionId '
      'region=${regionOf('open_summary')} '
      'totalMs=${now - _t0Ms} '
      'note=从点击会话到消息首次可见',
    );
  }

  /// 阶段中文名，方便在 logcat 里扫。
  static String regionOf(String event) {
    switch (event) {
      case 'session_begin':
        return '①点击会话';
      case 'bootstrap_before_await':
        return '②进页前bootstrap开始';
      case 'bootstrap_peek_start':
        return '②peek拉历史开始';
      case 'bootstrap_peek_done':
        return '②peek拉历史结束';
      case 'bootstrap_url_resolve_done':
        return '②图片URL补全';
      case 'bootstrap_warm_skip':
        return '②暖窗已就绪跳过重灌';
      case 'bootstrap_after_await':
        return '②进页前bootstrap结束';
      case 'cold_bootstrap_timeout_before_push':
        return '②冷开push前bootstrap超时';
      case 'page_bootstrap_warm_skip':
        return '②页内bootstrap暖跳过';
      case 'navigator_push_begin':
        return '③开始push路由';
      case 'navigator_pop_back':
        return '③从聊天返回';
      case 'embedded_chat_switch':
        return '③嵌入态切换会话';
      case 'chat_init_state':
        return '④Chat页initState';
      case 'chat_first_frame':
        return '④Chat页首帧';
      case 'history_gate_warm_shell':
        return '⑤历史gate暖壳';
      case 'history_gate_cold_shell':
        return '⑤历史gate冷壳';
      case 'history_gate_thin_window':
        return '⑤历史gate薄窗';
      case 'history_gate_timeout_1_2s':
        return '⑤历史gate冷开超时1.2s';
      case 'history_gate_thin_timeout_1_2s':
        return '⑤历史gate薄窗超时1.2s';
      case 'history_gate_tips_merge_timeout':
        return '⑤历史gate tip合并超时';
      case 'history_gate_content_ready_skip':
        return '⑤有内容跳过整页gate';
      case 'prepare_gate_after_inflight_wait':
        return '⑤等待inflight结束';
      case 'prepare_gate_complete':
        return '⑤prepareGate完成';
      case 'history_list_first_build':
        return '⑥消息列表首次build';
      case 'messages_first_visible':
        return '⑦消息首次可见';
      case 'open_summary':
        return '⑧打开汇总';
      case 'group_member_open_shell':
        return '群成员开页壳';
      case 'group_member_full_load_start':
        return '群成员全量开始';
      case 'avatar_warm_done':
        return '头像预热完成';
      case 'mute_network_fetch_start':
        return '禁言网络拉取开始';
      default:
        if (event.startsWith('bootstrap_')) {
          return '②bootstrap/$event';
        }
        if (event.startsWith('prepare_') || event.startsWith('history_')) {
          return '⑤历史/$event';
        }
        if (event.startsWith('chat_')) {
          return '④Chat/$event';
        }
        return event;
    }
  }

  static void _print(
    String event, {
    String? conversationID,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    final buffer = StringBuffer('[ChatOpenPerf] event=$event');
    final id = (conversationID ?? _convId).trim();
    if (id.isNotEmpty) {
      buffer.write(' conv=$id');
    }
    for (final entry in extras.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      buffer.write(' ${entry.key}=$value');
    }
    // ignore: avoid_print
    print(buffer.toString());
  }
}
