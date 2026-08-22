import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// 聊天页进场抖动专项诊断。过滤关键字：`[CHAT_JITTER]`。
///
/// 默认 [enabled]=false。发布版排查滑动/进页尖刺时临时改为 true
///（`print` 在 release 也会进 logcat）；测完务必改回 false，避免热路径刷屏。
class ChatJitterDiag {
  ChatJitterDiag._();

  /// 排查包临时 true；合入/日常默认 false。
  static const bool enabled = false;

  /// 气泡 decode 运行时探针（需同时 [enabled]=true）。
  static const bool decodeProbeEnabled = kDebugMode;

  static int _openSeq = 0;

  /// 当前进页序号，供 `[ChatGeomSettle]` 等探针对齐。
  static int get openSeq => _openSeq;
  static String _openConv = '';
  static int _openAtMs = 0;
  static int _inboundSessionSeq = 0;
  static int _inboundTransactionSeq = 0;
  static final Map<String, int> _inboundSessionByConv = <String, int>{};
  static final Map<String, int> _inboundTransactionByConv = <String, int>{};
  static final Map<String, int> _lastRateLimitedLogAtMs = <String, int>{};
  static final Map<String, String> _avatarFaceCache = <String, String>{};
  static final Set<String> _bubbleDecodeLoggedKeys = <String>{};
  static int _scrollIdleSampleCount = 0;
  static const Set<int> _scrollIdleMilestones = <int>{20, 50, 100};

  /// 每次进入聊天页时由宿主调用，重置计时基准。
  static void markChatOpen(String? conversationID) {
    if (!enabled) return;
    _openSeq++;
    _openConv = conversationID?.trim() ?? '';
    _openAtMs = DateTime.now().millisecondsSinceEpoch;
    _avatarFaceCache.clear();
    _bubbleDecodeLoggedKeys.clear();
    _scrollIdleSampleCount = 0;
    log(
      'chat_open',
      conv: _openConv,
      extras: <String, Object?>{
        'openSeq': _openSeq,
        'frame': SchedulerBinding.instance.schedulerPhase.name,
      },
    );
    logImageCache('chat_open');
  }

  static int elapsedSinceOpenMs() {
    if (_openAtMs <= 0) return -1;
    return DateTime.now().millisecondsSinceEpoch - _openAtMs;
  }

  static void log(
    String event, {
    String? conv,
    String? msgId,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!enabled) return;
    final buffer = StringBuffer('[CHAT_JITTER] event=$event');
    final id = conv?.trim() ?? '';
    if (id.isNotEmpty) {
      buffer.write(' conv=$id');
    } else if (_openConv.isNotEmpty) {
      buffer.write(' conv=$_openConv');
    }
    if (_openSeq > 0) {
      buffer.write(' openSeq=$_openSeq');
    }
    final elapsed = elapsedSinceOpenMs();
    if (elapsed >= 0) {
      buffer.write(' t+${elapsed}ms');
    }
    final mid = msgId?.trim() ?? '';
    if (mid.isNotEmpty) {
      buffer.write(' msgId=$mid');
    }
    for (final entry in extras.entries) {
      final value = entry.value;
      if (value == null) continue;
      buffer.write(' ${entry.key}=$value');
    }
    // ignore: avoid_print
    print(buffer.toString());
  }

  static int beginInboundSession(String conversationID) {
    if (!enabled) return 0;
    final convId = conversationID.trim();
    final session = ++_inboundSessionSeq;
    _inboundSessionByConv[convId] = session;
    _inboundTransactionByConv.remove(convId);
    logInboundFlow(
      action: 'session_begin',
      conv: convId,
      extras: <String, Object?>{'session': session},
    );
    return session;
  }

  static int beginInboundTransaction(String conversationID) {
    if (!enabled) return 0;
    final convId = conversationID.trim();
    final transaction = ++_inboundTransactionSeq;
    _inboundTransactionByConv[convId] = transaction;
    return transaction;
  }

  static void endInboundSession(String conversationID) {
    if (!enabled) return;
    final convId = conversationID.trim();
    logInboundFlow(action: 'session_end', conv: convId);
    _inboundSessionByConv.remove(convId);
    _inboundTransactionByConv.remove(convId);
    _lastRateLimitedLogAtMs.removeWhere(
      (key, _) => key.startsWith('$convId:'),
    );
  }

  /// Structured lifecycle trace for inbound queue, projection and scrolling.
  ///
  /// Never put message text or other user content in [extras]. Counts, stable
  /// state names and geometry are enough to reproduce presentation races.
  static void logInboundFlow({
    required String action,
    String? conv,
    Map<String, Object?> extras = const <String, Object?>{},
    String? throttleKey,
    int minIntervalMs = 0,
  }) {
    if (!enabled) return;
    final convId = conv?.trim() ?? _openConv;
    if (throttleKey != null && minIntervalMs > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final key = '$convId:$throttleKey';
      final previous = _lastRateLimitedLogAtMs[key] ?? 0;
      if (now - previous < minIntervalMs) return;
      _lastRateLimitedLogAtMs[key] = now;
    }
    final session = _inboundSessionByConv[convId];
    final transaction = _inboundTransactionByConv[convId];
    var schedulerPhase = 'unbound';
    try {
      schedulerPhase = SchedulerBinding.instance.schedulerPhase.name;
    } catch (_) {
      // Queue unit tests and early startup may run before a Flutter binding
      // exists. Diagnostics must never initialize or break application state.
    }
    log(
      'inbound_flow',
      conv: convId,
      extras: <String, Object?>{
        'action': action,
        if (session != null) 'session': session,
        if (transaction != null) 'tx': transaction,
        'phase': schedulerPhase,
        ...extras,
      },
    );
  }

  static void logImageCache(
    String label, {
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!enabled) return;
    final cache = PaintingBinding.instance.imageCache;
    log(
      'image_cache',
      extras: <String, Object?>{
        'label': label,
        'count': cache.currentSize,
        'maxCount': cache.maximumSize,
        'bytes': cache.currentSizeBytes,
        'maxBytes': cache.maximumSizeBytes,
        'live': cache.liveImageCount,
        ...extras,
      },
    );
  }

  /// 用户松手 idle：采样 ImageCache；第 20/50/100 次 idle 用独立 label。
  static void noteScrollIdle({
    double? pixels,
    int? rawMessageCount,
  }) {
    if (!enabled) return;
    _scrollIdleSampleCount++;
    final idleCount = _scrollIdleSampleCount;
    final label = _scrollIdleMilestones.contains(idleCount)
        ? 'scroll_idle_$idleCount'
        : 'scroll_idle';
    logImageCache(
      label,
      extras: <String, Object?>{
        'idleCount': idleCount,
        if (pixels != null) 'pixels': pixels.toStringAsFixed(1),
        if (rawMessageCount != null) 'rawMessageCount': rawMessageCount,
      },
    );
  }

  /// 气泡解出帧后记录 cache 目标边 vs 实际 Bitmap 像素。
  static void logBubbleDecode({
    required String msgId,
    required String source,
    required String pathOrUrlKey,
    required double displayW,
    required double displayH,
    required int cacheW,
    required int cacheH,
    required int decodedW,
    required int decodedH,
    required bool sync,
    required bool deferHeavy,
    required double dpr,
    String? sdkType,
    int? fileW,
    int? fileH,
  }) {
    if (!enabled || !decodeProbeEnabled) return;
    final mid = msgId.trim();
    final key =
        '$mid|$pathOrUrlKey|$cacheW|$cacheH|$decodedW|$decodedH';
    if (!_bubbleDecodeLoggedKeys.add(key)) {
      return;
    }
    log(
      'bubble_decode',
      msgId: mid.isEmpty ? null : mid,
      extras: <String, Object?>{
        'source': source,
        'pathOrUrlKey': pathOrUrlKey,
        if (sdkType != null && sdkType.isNotEmpty) 'sdkType': sdkType,
        'displayW': displayW.toStringAsFixed(1),
        'displayH': displayH.toStringAsFixed(1),
        'cacheW': cacheW,
        'cacheH': cacheH,
        'decodedW': decodedW,
        'decodedH': decodedH,
        'sync': sync,
        'deferHeavy': deferHeavy,
        'dpr': dpr.toStringAsFixed(2),
        if (fileW != null) 'fileW': fileW,
        if (fileH != null) 'fileH': fileH,
      },
    );
  }

  static void logRouteVisible({
    required bool visible,
    String? source,
    int? deferredFrames,
  }) {
    log(
      'route_visible',
      extras: <String, Object?>{
        'visible': visible,
        if (source != null) 'source': source,
        if (deferredFrames != null) 'deferredFrames': deferredFrames,
      },
    );
    if (visible) {
      logImageCache('route_visible_true');
    }
  }

  static void logTickerTask({
    required String widget,
    required bool tickerEnabled,
    required bool deferred,
    String? msgId,
  }) {
    log(
      'ticker_task',
      msgId: msgId,
      extras: <String, Object?>{
        'widget': widget,
        'tickerEnabled': tickerEnabled,
        'deferred': deferred,
      },
    );
  }

  static void logAvatar({
    required String sender,
    required String faceUrl,
    required String source,
    String? prevFaceUrl,
    String? cacheKey,
  }) {
    final key = cacheKey ?? sender;
    final prev = prevFaceUrl ?? _avatarFaceCache[key] ?? '';
    final next = faceUrl.trim();
    if (prev == next && prev.isNotEmpty) return;
    _avatarFaceCache[key] = next;
    log(
      'avatar_face',
      extras: <String, Object?>{
        'sender': sender,
        'source': source,
        'prev': _shortUrl(prev),
        'next': _shortUrl(next),
        'becameEmpty': prev.isNotEmpty && next.isEmpty,
        'becameNonEmpty': prev.isEmpty && next.isNotEmpty,
        'changed': prev != next,
      },
    );
  }

  static void logMediaLayout({
    required String kind,
    String? msgId,
    double? width,
    double? height,
    required String reason,
    double? prevW,
    double? prevH,
  }) {
    log(
      'media_layout',
      msgId: msgId,
      extras: <String, Object?>{
        'kind': kind,
        'w': width?.toStringAsFixed(1),
        'h': height?.toStringAsFixed(1),
        'prevW': prevW?.toStringAsFixed(1),
        'prevH': prevH?.toStringAsFixed(1),
        'reason': reason,
      },
    );
  }

  static void logSetState({
    required String widget,
    required String reason,
    String? msgId,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    log(
      'set_state',
      msgId: msgId,
      extras: <String, Object?>{
        'widget': widget,
        'reason': reason,
        ...extras,
      },
    );
  }

  static void logScroll({
    required String reason,
    double? pixels,
    double? maxExtent,
    double? minExtent,
    bool? userScrolling,
    bool? pinnedBottom,
  }) {
    log(
      'scroll',
      extras: <String, Object?>{
        'reason': reason,
        if (pixels != null) 'pixels': pixels.toStringAsFixed(1),
        if (maxExtent != null) 'maxExtent': maxExtent.toStringAsFixed(1),
        if (minExtent != null) 'minExtent': minExtent.toStringAsFixed(1),
        if (userScrolling != null) 'userScrolling': userScrolling,
        if (pinnedBottom != null) 'pinnedBottom': pinnedBottom,
      },
    );
  }

  /// 上滑看历史时收到新消息：分区延迟、滚动补偿、滚底拦截。
  static void logReadingHistoryIncoming({
    required String action,
    String? conv,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    log(
      'reading_history_incoming',
      conv: conv,
      extras: <String, Object?>{
        'action': action,
        ...extras,
      },
    );
  }

  static void logListRebuild({
    required String reason,
    int? readLen,
    int? rawLen,
    int? revision,
    double? scrollPixels,
    double? maxExtent,
    double? viewport,
    double? spacer,
    String? caller,
  }) {
    log(
      'list_rebuild',
      extras: <String, Object?>{
        'reason': reason,
        if (readLen != null) 'readLen': readLen,
        if (rawLen != null) 'rawLen': rawLen,
        if (revision != null) 'revision': revision,
        if (scrollPixels != null) 'scrollPx': scrollPixels.toStringAsFixed(1),
        if (maxExtent != null) 'maxExtent': maxExtent.toStringAsFixed(1),
        if (viewport != null) 'viewport': viewport.toStringAsFixed(1),
        if (spacer != null) 'spacer': spacer.toStringAsFixed(1),
        if (caller != null && caller.isNotEmpty) 'caller': caller,
      },
    );
  }

  /// 短历史底部 spacer / 视口高度变化——进页抖动高频嫌疑。
  static void logLayoutPulse({
    required String reason,
    double? viewport,
    double? spacer,
    double? contentH,
    double? scrollPixels,
    double? maxExtent,
    bool? latched,
  }) {
    log(
      'layout_pulse',
      extras: <String, Object?>{
        'reason': reason,
        if (viewport != null) 'viewport': viewport.toStringAsFixed(1),
        if (spacer != null) 'spacer': spacer.toStringAsFixed(1),
        if (contentH != null) 'contentH': contentH.toStringAsFixed(1),
        if (scrollPixels != null) 'scrollPx': scrollPixels.toStringAsFixed(1),
        if (maxExtent != null) 'maxExtent': maxExtent.toStringAsFixed(1),
        if (latched != null) 'latched': latched,
      },
    );
  }

  static String compactStack({int maxFrames = 4}) {
    final lines = StackTrace.current
        .toString()
        .split('\n')
        .where((line) =>
            line.contains('tim_uikit_chat') ||
            line.contains('chat.dart') ||
            line.contains('RouteVisibility') ||
            line.contains('tui_chat'))
        .take(maxFrames)
        .map((line) {
      final trimmed = line.trim();
      if (trimmed.length <= 96) return trimmed;
      return trimmed.substring(0, 96);
    }).toList();
    if (lines.isEmpty) return 'n/a';
    return lines.join(' | ');
  }

  /// dispose/deactivate 专用：保留 Flutter framework 帧，用来定位「谁卸掉了列表」。
  static String disposeStack({int maxFrames = 12}) {
    final lines = StackTrace.current
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) =>
            !line.contains('chat_jitter_diag.dart') &&
            !line.contains('ChatJitterDiag.'))
        .take(maxFrames)
        .map((line) {
      if (line.length <= 120) return line;
      return line.substring(0, 120);
    }).toList();
    if (lines.isEmpty) return 'n/a';
    return lines.join(' || ');
  }

  static void logWidgetLifecycle({
    required String widget,
    required String phase,
    required int stateHash,
    String? conv,
    int? livedMs,
    String? keyDebug,
    String? ancestors,
  }) {
    log(
      'chat_widget_lifecycle',
      conv: conv,
      extras: <String, Object?>{
        'phase': phase,
        'widget': widget,
        'stateHash': stateHash,
        if (livedMs != null) 'livedMs': livedMs,
        if (keyDebug != null && keyDebug.isNotEmpty) 'key': keyDebug,
        if (ancestors != null && ancestors.isNotEmpty) 'ancestors': ancestors,
        if (phase == 'dispose' || phase == 'deactivate')
          'stack': disposeStack(),
      },
    );
  }

  static void logGroupMemberStore({
    required String action,
    String? groupId,
    int? memberCount,
    bool? notify,
  }) {
    log(
      'group_member_store',
      extras: <String, Object?>{
        'action': action,
        if (groupId != null) 'groupId': groupId,
        if (memberCount != null) 'memberCount': memberCount,
        if (notify != null) 'notify': notify,
      },
    );
  }

  static String _shortUrl(String url) {
    if (url.isEmpty) return '(empty)';
    if (url.length <= 48) return url;
    return '${url.substring(0, 24)}…${url.substring(url.length - 16)}';
  }
}
