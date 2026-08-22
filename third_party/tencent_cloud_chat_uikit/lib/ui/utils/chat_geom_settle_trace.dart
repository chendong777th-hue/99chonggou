import 'package:flutter/scheduler.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_jitter_diag.dart';

/// 进页消息几何 settle 探针。过滤关键字：`[ChatGeomSettle]`。
///
/// 从 [begin] 起每帧采样（含空壳，以便看见 `0→spacer_prime`）。
/// 连续 [stableFrameTarget] 帧全字段 `|Δ|≤[epsilonPx]` 才停采，但须同时满足 A+B：
/// - B：已 [markMessagesVisible]
/// - A：本帧 `pixels != null` 且 `contentH >= 0`
/// 空壳（n/a / contentH=-1）不计 stable。无时间硬顶；dispose 必须 [end]。
/// 测完请把 [enabled] 改回 false。
class ChatGeomSettleTrace {
  ChatGeomSettleTrace._();

  /// 进页几何 settle 探针。默认关闭：开启后每帧 print + scheduleFrame，debug/release 均会刷屏拖主线程。
  static const bool enabled = false;

  static const int stableFrameTarget = 8;
  static const double epsilonPx = 1.0;

  static bool _active = false;
  static bool _frameScheduled = false;
  static bool _messagesVisible = false;
  static bool _stableArmed = false;
  static int _openSeq = 0;
  static String _conv = '';
  static int _frameIndex = 0;
  static int _stableCount = 0;
  static String _lastReason = '';
  static ChatGeomSettleSnapshot? _prev;
  static ChatGeomSettleSnapshot? Function()? _capture;

  static void begin({
    required String conversationID,
    required int openSeq,
    required ChatGeomSettleSnapshot? Function() capture,
  }) {
    if (!enabled) {
      return;
    }
    end(reason: 'restart');
    _active = true;
    _frameScheduled = false;
    _messagesVisible = false;
    _stableArmed = false;
    _openSeq = openSeq;
    _conv = conversationID.trim();
    _frameIndex = 0;
    _stableCount = 0;
    _lastReason = 'begin';
    _prev = null;
    _capture = capture;
    _print(
      'begin',
      extras: <String, Object?>{
        'openSeq': _openSeq,
        'stableTarget': stableFrameTarget,
        'epsilonPx': epsilonPx,
      },
    );
    _scheduleFrame();
  }

  /// 与 [ChatOpenPerfLog.markMessagesFirstVisible] 同点调用（B 门）。
  static void markMessagesVisible({
    required String conversationID,
    required int messageCount,
    String source = 'list',
  }) {
    if (!enabled || !_active) {
      return;
    }
    if (messageCount <= 0) {
      return;
    }
    final id = conversationID.trim();
    if (_conv.isNotEmpty && id.isNotEmpty && id != _conv) {
      return;
    }
    if (_messagesVisible) {
      return;
    }
    _messagesVisible = true;
    _print(
      'messages_visible',
      extras: <String, Object?>{
        'openSeq': _openSeq,
        'messageCount': messageCount,
        'source': source,
      },
    );
  }

  static void end({required String reason}) {
    if (!_active && _capture == null) {
      return;
    }
    final wasActive = _active;
    _active = false;
    _frameScheduled = false;
    _capture = null;
    if (wasActive || reason != 'restart') {
      _print(
        'settle_end',
        extras: <String, Object?>{
          'openSeq': _openSeq,
          'reason': reason,
          'frames': _frameIndex,
          'stable': _stableCount,
          'lastReason': _lastReason,
          'visible': _messagesVisible,
          'armed': _stableArmed,
        },
      );
    }
    if (reason == 'restart') {
      return;
    }
    _prev = null;
    _lastReason = '';
    _messagesVisible = false;
    _stableArmed = false;
  }

  static void noteReason(
    String reason, {
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!enabled || !_active) {
      return;
    }
    _lastReason = reason;
    _print(
      'reason',
      extras: <String, Object?>{
        'openSeq': _openSeq,
        'reason': reason,
        ...extras,
      },
    );
  }

  static ChatGeomSettleSnapshot snapshot({
    required double? pixels,
    required double? minExtent,
    required double? maxExtent,
    required double? viewport,
    required double spacer,
    required double contentH,
    required bool latched,
  }) {
    return ChatGeomSettleSnapshot(
      pixels: pixels,
      minExtent: minExtent,
      maxExtent: maxExtent,
      viewport: viewport,
      spacer: spacer,
      contentH: contentH,
      latched: latched,
    );
  }

  static void _scheduleFrame() {
    if (!_active || _frameScheduled) {
      return;
    }
    _frameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      _onFrame();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  static bool _canCountStable(ChatGeomSettleSnapshot snap) {
    // A: 真实 pixels + contentH≥0；B: 已 messages_visible
    return _messagesVisible && snap.pixels != null && snap.contentH >= 0;
  }

  static void _onFrame() {
    if (!_active) {
      return;
    }
    final capture = _capture;
    if (capture == null) {
      end(reason: 'no_capture');
      return;
    }
    final snap = capture();
    if (snap == null) {
      end(reason: 'dispose');
      return;
    }
    _frameIndex++;
    final canCount = _canCountStable(snap);
    if (canCount && !_stableArmed) {
      _stableArmed = true;
      _prev = null;
      _stableCount = 0;
      _print(
        'arm_stable',
        extras: <String, Object?>{
          'openSeq': _openSeq,
          'frame': _frameIndex,
          'pixels': _fmt(snap.pixels),
          'spacer': _fmt(snap.spacer),
          'contentH': _fmt(snap.contentH),
        },
      );
    }

    final prev = _prev;
    final dPixels = _delta(prev?.pixels, snap.pixels);
    final dMin = _delta(prev?.minExtent, snap.minExtent);
    final dMax = _delta(prev?.maxExtent, snap.maxExtent);
    final dViewport = _delta(prev?.viewport, snap.viewport);
    final dSpacer = _delta(prev?.spacer, snap.spacer);
    final dContentH = _delta(prev?.contentH, snap.contentH);
    final changed = prev != null &&
        (dPixels.abs() > epsilonPx ||
            dMin.abs() > epsilonPx ||
            dMax.abs() > epsilonPx ||
            dViewport.abs() > epsilonPx ||
            dSpacer.abs() > epsilonPx ||
            dContentH.abs() > epsilonPx ||
            _presenceChanged(prev.pixels, snap.pixels) ||
            _presenceChanged(prev.minExtent, snap.minExtent) ||
            _presenceChanged(prev.maxExtent, snap.maxExtent) ||
            _presenceChanged(prev.viewport, snap.viewport) ||
            _presenceChanged(prev.spacer, snap.spacer) ||
            _presenceChanged(prev.contentH, snap.contentH));

    final counting = _stableArmed && canCount;
    if (!counting) {
      _stableCount = 0;
    } else if (prev == null || changed) {
      _stableCount = 0;
    } else {
      _stableCount++;
    }

    final elapsed = ChatJitterDiag.elapsedSinceOpenMs();
    final buffer = StringBuffer('[ChatGeomSettle] event=frame');
    if (_conv.isNotEmpty) {
      buffer.write(' conv=$_conv');
    }
    buffer.write(' openSeq=$_openSeq');
    if (elapsed >= 0) {
      buffer.write(' t+${elapsed}ms');
    }
    buffer.write(' frame=$_frameIndex');
    buffer.write(' pixels=${_fmt(snap.pixels)}');
    buffer.write(' min=${_fmt(snap.minExtent)}');
    buffer.write(' max=${_fmt(snap.maxExtent)}');
    buffer.write(' viewport=${_fmt(snap.viewport)}');
    buffer.write(' spacer=${_fmt(snap.spacer)}');
    buffer.write(' contentH=${_fmt(snap.contentH)}');
    buffer.write(' latched=${snap.latched}');
    buffer.write(' dPixels=${dPixels.toStringAsFixed(1)}');
    buffer.write(' dMin=${dMin.toStringAsFixed(1)}');
    buffer.write(' dMax=${dMax.toStringAsFixed(1)}');
    buffer.write(' dViewport=${dViewport.toStringAsFixed(1)}');
    buffer.write(' dSpacer=${dSpacer.toStringAsFixed(1)}');
    buffer.write(' dContentH=${dContentH.toStringAsFixed(1)}');
    buffer.write(' visible=${_messagesVisible ? 1 : 0}');
    buffer.write(' armed=${_stableArmed ? 1 : 0}');
    buffer.write(' counting=${counting ? 1 : 0}');
    buffer.write(' stable=$_stableCount');
    buffer.write(' reasonHint=$_lastReason');
    // ignore: avoid_print
    print(buffer.toString());
    _prev = snap;
    if (counting && _stableCount >= stableFrameTarget) {
      end(reason: 'stable');
      return;
    }
    _scheduleFrame();
  }

  static double _delta(double? a, double? b) {
    if (a == null || b == null) {
      return 0;
    }
    return b - a;
  }

  static bool _presenceChanged(double? a, double? b) {
    return (a == null) != (b == null);
  }

  static String _fmt(double? v) {
    if (v == null) {
      return 'n/a';
    }
    return v.toStringAsFixed(1);
  }

  static void _print(
    String event, {
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    final buffer = StringBuffer('[ChatGeomSettle] event=$event');
    if (_conv.isNotEmpty) {
      buffer.write(' conv=$_conv');
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

class ChatGeomSettleSnapshot {
  const ChatGeomSettleSnapshot({
    required this.pixels,
    required this.minExtent,
    required this.maxExtent,
    required this.viewport,
    required this.spacer,
    required this.contentH,
    required this.latched,
  });

  final double? pixels;
  final double? minExtent;
  final double? maxExtent;
  final double? viewport;
  final double spacer;
  final double contentH;
  final bool latched;
}
