import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_jitter_diag.dart';

/// 入站单条插入后，用 [ScrollPosition.correctBy] 缓动插值抵消瞬时跳变。
class ChatInboundScrollDeltaAnimator {
  ChatInboundScrollDeltaAnimator(this.tickerProvider);

  final TickerProvider tickerProvider;
  AnimationController? _controller;
  Future<void> _chain = Future<void>.value();
  ScrollPosition? _activePosition;
  int _revealSeq = 0;
  int _revealChainGeneration = 0;
  String? _pendingCancelReason;
  bool _pendingCancelSnapToBottom = true;
  double? _activeMaxAtAnimStart;
  double? _cumulativeExtentDelta;
  double _cumulativeRevealedPx = 0;

  static const double _bottomSnapEpsilonPx = 1.0;
  static const double _extentDriftEpsilonPx = 0.5;
  static const Duration _smoothSnapDuration = Duration(milliseconds: 96);
  /// 与手指匀速上拉一致：全程线性位移。
  static const Curve _revealEaseCurve = Curves.linear;
  static const double _msPerPx = 5.0;
  static const int _minRevealMs = 320;
  static const int _maxRevealMs = 560;

  bool get isAnimating => _controller?.isAnimating ?? false;

  bool get hasActiveReveal => isAnimating || _activePosition != null;

  static Duration durationForExtentDelta(
    double extentDelta, {
    Duration? baseDuration,
    bool isOutgoing = false,
  }) {
    final baseMs = baseDuration?.inMilliseconds ?? 260;
    final scale = isOutgoing ? 3.4 : _msPerPx;
    final scaled = (extentDelta.abs() * scale).round();
    // 配置时长作下限，大图按像素拉长，模拟匀速拖拽。
    final ms = scaled < baseMs
        ? baseMs
        : scaled.clamp(baseMs, _maxRevealMs);
    return Duration(milliseconds: ms.clamp(_minRevealMs, _maxRevealMs));
  }

  /// P1.6：中断进行中的 delta 动画，并按需钉底归位。
  void cancelActiveRevealAndSnap({
    required String reason,
    bool snapToNaturalBottom = true,
    bool flushQueuedReveals = false,
    String? convId,
    String? msgId,
  }) {
    if (!hasActiveReveal) {
      return;
    }
    _pendingCancelReason = reason;
    _pendingCancelSnapToBottom = snapToNaturalBottom;
    ChatJitterDiag.logScrollReveal(
      phase: 'delta_mutex_cancel',
      conv: convId,
      msgId: msgId,
      extras: <String, Object?>{
        'reason': reason,
        'snapToNaturalBottom': snapToNaturalBottom,
        'flushQueuedReveals': flushQueuedReveals,
        'seq': _revealSeq,
        if (_activePosition != null)
          'scroll': ChatJitterDiag.scrollPositionSnapshot(
            pixels: _activePosition!.pixels,
            minExtent: _activePosition!.minScrollExtent,
            maxExtent: _activePosition!.maxScrollExtent,
          ),
      },
    );
    _controller?.stop();
    if (flushQueuedReveals) {
      _revealChainGeneration++;
      _chain = Future<void>.value();
    }
  }

  /// 钉底时补偿动画期间 [maxScrollExtent] 的异步漂移（如图/视频晚到高度）。
  static bool compensateExtentDriftIfPinned({
    required ScrollPosition position,
    required double anchorMaxExtent,
    double bottomEpsilon = _bottomSnapEpsilonPx,
    String? convId,
    String? msgId,
    int? seq,
    String phase = 'delta_drift_compensate',
  }) {
    if (!position.hasContentDimensions || !position.hasPixels) {
      return false;
    }
    final offBottom = position.pixels - position.minScrollExtent;
    if (offBottom > bottomEpsilon) {
      return false;
    }
    final drift = position.maxScrollExtent - anchorMaxExtent;
    if (drift.abs() <= _extentDriftEpsilonPx) {
      return false;
    }
    position.correctBy(-drift);
    ChatJitterDiag.logScrollReveal(
      phase: phase,
      conv: convId,
      msgId: msgId,
      extras: <String, Object?>{
        if (seq != null) 'seq': seq,
        'anchorMax': anchorMaxExtent.toStringAsFixed(1),
        'drift': drift.toStringAsFixed(1),
        'correctedBy': (-drift).toStringAsFixed(1),
        'scroll': ChatJitterDiag.scrollPositionSnapshot(
          pixels: position.pixels,
          minExtent: position.minScrollExtent,
          maxExtent: position.maxScrollExtent,
        ),
      },
    );
    return true;
  }

  void dispose() {
    _controller?.stop();
    _controller?.dispose();
    _controller = null;
    _chain = Future<void>.value();
    _activePosition = null;
    _activeMaxAtAnimStart = null;
    _cumulativeExtentDelta = null;
    _cumulativeRevealedPx = 0;
    _pendingCancelReason = null;
  }

  Future<void> smoothRevealExtentDelta({
    required ScrollPosition position,
    required double extentDelta,
    Duration duration = const Duration(milliseconds: 280),
    Curve curve = _revealEaseCurve,
    bool smoothSnapToBottom = true,
    String? convId,
    String? msgId,
    bool? isOutgoing,
  }) {
    if (_tryMergeActiveReveal(
      position: position,
      extentDelta: extentDelta,
      duration: duration,
      convId: convId,
      msgId: msgId,
    )) {
      return _chain;
    }
    final generation = _revealChainGeneration;
    _chain = _chain.then((_) async {
      if (generation != _revealChainGeneration) {
        ChatJitterDiag.logScrollReveal(
          phase: 'delta_skip',
          conv: convId,
          msgId: msgId,
          extras: <String, Object?>{
            'reason': 'mutex_chain_stale',
            'generation': generation,
            'currentGeneration': _revealChainGeneration,
          },
        );
        return;
      }
      await _runReveal(
        position: position,
        extentDelta: extentDelta,
        duration: duration,
        curve: curve,
        convId: convId,
        msgId: msgId,
        isOutgoing: isOutgoing,
        smoothSnapToBottom: smoothSnapToBottom,
      );
    });
    return _chain;
  }

  bool _tryMergeActiveReveal({
    required ScrollPosition position,
    required double extentDelta,
    required Duration duration,
    String? convId,
    String? msgId,
  }) {
    if (extentDelta < _extentDriftEpsilonPx) {
      return false;
    }
    final controller = _controller;
    if (controller == null ||
        !controller.isAnimating ||
        _activePosition != position ||
        _cumulativeExtentDelta == null) {
      return false;
    }
    position.correctBy(-extentDelta);
    _cumulativeExtentDelta = _cumulativeExtentDelta! + extentDelta;
    final addMs = duration.inMilliseconds.clamp(80, 220);
    final remainMs =
        ((1.0 - controller.value) * controller.duration!.inMilliseconds)
            .round();
    controller.duration = Duration(
      milliseconds: (remainMs + addMs).clamp(_minRevealMs, _maxRevealMs),
    );
    ChatJitterDiag.logScrollReveal(
      phase: 'delta_merge',
      conv: convId,
      msgId: msgId,
      extras: <String, Object?>{
        'mergedDelta': extentDelta.toStringAsFixed(1),
        'totalDelta': _cumulativeExtentDelta!.toStringAsFixed(1),
        'durationMs': controller.duration!.inMilliseconds,
        'progress': controller.value.toStringAsFixed(2),
      },
    );
    return true;
  }

  Future<void> _runReveal({
    required ScrollPosition position,
    required double extentDelta,
    required Duration duration,
    required Curve curve,
    String? convId,
    String? msgId,
    bool? isOutgoing,
    bool smoothSnapToBottom = true,
  }) async {
    if (!position.hasContentDimensions) {
      ChatJitterDiag.logScrollReveal(
        phase: 'delta_skip',
        conv: convId,
        msgId: msgId,
        extras: <String, Object?>{
          'reason': 'no_content_dimensions',
          'extentDelta': extentDelta.toStringAsFixed(1),
        },
      );
      return;
    }
    if (extentDelta < -_extentDriftEpsilonPx) {
      ChatJitterDiag.logScrollReveal(
        phase: 'delta_skip',
        conv: convId,
        msgId: msgId,
        extras: <String, Object?>{
          'reason': 'negative_extent_delta',
          'extentDelta': extentDelta.toStringAsFixed(1),
          'scroll': ChatJitterDiag.scrollPositionSnapshot(
            pixels: position.pixels,
            minExtent: position.minScrollExtent,
            maxExtent: position.maxScrollExtent,
          ),
        },
      );
      return;
    }
    if (extentDelta.abs() < _extentDriftEpsilonPx) {
      ChatJitterDiag.logScrollReveal(
        phase: 'delta_skip',
        conv: convId,
        msgId: msgId,
        extras: <String, Object?>{
          'reason': 'delta_too_small',
          'extentDelta': extentDelta.toStringAsFixed(1),
        },
      );
      return;
    }

    final seq = ++_revealSeq;
    final beforePx = position.pixels;
    final beforeMax = position.maxScrollExtent;
    ChatJitterDiag.logScrollReveal(
      phase: 'delta_start',
      conv: convId,
      msgId: msgId,
      extras: <String, Object?>{
        'seq': seq,
        'extentDelta': extentDelta.toStringAsFixed(1),
        'durationMs': duration.inMilliseconds,
        'curve': curve.toString(),
        'isOutgoing': isOutgoing,
        'scroll': ChatJitterDiag.scrollPositionSnapshot(
          pixels: beforePx,
          minExtent: position.minScrollExtent,
          maxExtent: beforeMax,
        ),
      },
    );

    _controller?.stop();
    _controller?.dispose();
    _activePosition = position;
    _cumulativeExtentDelta = extentDelta;
    _cumulativeRevealedPx = 0;
    final maxAtAnimStart = position.maxScrollExtent;
    _activeMaxAtAnimStart = maxAtAnimStart;

    final controller = AnimationController(
      vsync: tickerProvider,
      duration: duration,
    );
    _controller = controller;
    final animation = CurvedAnimation(parent: controller, curve: curve);

    position.correctBy(-extentDelta);

    void tick() {
      final total = _cumulativeExtentDelta ?? extentDelta;
      final progress = animation.value;
      final revealed = total * progress;
      final step = revealed - _cumulativeRevealedPx;
      _cumulativeRevealedPx = revealed;
      if (step.abs() > 0.0001 && position.hasContentDimensions) {
        position.correctBy(step);
      }
    }

    animation.addListener(tick);
    var completedNormally = false;
    try {
      await controller.forward();
      completedNormally = controller.status == AnimationStatus.completed;
    } finally {
      animation.removeListener(tick);
      animation.dispose();
      controller.dispose();
      if (identical(_controller, controller)) {
        _controller = null;
      }
      final cancelReason = _pendingCancelReason;
      final snapToBottom = _pendingCancelSnapToBottom;
      _pendingCancelReason = null;
      _pendingCancelSnapToBottom = true;
      if (identical(_activePosition, position)) {
        _activePosition = null;
      }
      _cumulativeExtentDelta = null;
      _cumulativeRevealedPx = 0;
      final anchorMax = _activeMaxAtAnimStart ?? maxAtAnimStart;
      _activeMaxAtAnimStart = null;
      if (position.hasContentDimensions) {
        await compensateExtentDriftSmoothIfPinned(
          position: position,
          anchorMaxExtent: anchorMax,
          convId: convId,
          msgId: msgId,
          seq: seq,
          phase: cancelReason == null
              ? 'delta_drift_compensate'
              : 'delta_mutex_drift',
        );
      }
      if (snapToBottom) {
        await _snapToNaturalBottomIfNeeded(
          position: position,
          convId: convId,
          msgId: msgId,
          seq: seq,
          extentDelta: extentDelta,
          smooth: smoothSnapToBottom,
        );
      } else {
        ChatJitterDiag.logScrollReveal(
          phase: 'delta_done',
          conv: convId,
          msgId: msgId,
          extras: <String, Object?>{
            'seq': seq,
            'extentDelta': extentDelta.toStringAsFixed(1),
            'cancelled': cancelReason != null || !completedNormally,
            if (cancelReason != null) 'cancelReason': cancelReason,
            'offBottomBeforeSnap':
                (position.pixels - position.minScrollExtent).toStringAsFixed(1),
            'scroll': ChatJitterDiag.scrollPositionSnapshot(
              pixels: position.pixels,
              minExtent: position.minScrollExtent,
              maxExtent: position.maxScrollExtent,
            ),
          },
        );
      }
      if (cancelReason != null) {
        ChatJitterDiag.logScrollReveal(
          phase: 'delta_mutex_cancel_done',
          conv: convId,
          msgId: msgId,
          extras: <String, Object?>{
            'reason': cancelReason,
            'seq': seq,
            'completedNormally': completedNormally,
            'snapToNaturalBottom': snapToBottom,
            'scroll': ChatJitterDiag.scrollPositionSnapshot(
              pixels: position.pixels,
              minExtent: position.minScrollExtent,
              maxExtent: position.maxScrollExtent,
            ),
          },
        );
      }
    }
  }

  Future<void> compensateExtentDriftSmoothIfPinned({
    required ScrollPosition position,
    required double anchorMaxExtent,
    String? convId,
    String? msgId,
    int? seq,
    String phase = 'delta_drift_compensate',
  }) async {
    if (!position.hasContentDimensions || !position.hasPixels) {
      return;
    }
    final offBottom = position.pixels - position.minScrollExtent;
    if (offBottom > _bottomSnapEpsilonPx) {
      return;
    }
    final drift = position.maxScrollExtent - anchorMaxExtent;
    if (drift.abs() <= _extentDriftEpsilonPx) {
      return;
    }
    if (drift.abs() <= 72) {
      await _smoothCorrectBy(
        position: position,
        delta: -drift,
        duration: _smoothSnapDuration,
        convId: convId,
        msgId: msgId,
        phase: '${phase}_smooth',
        seq: seq,
      );
      return;
    }
    compensateExtentDriftIfPinned(
      position: position,
      anchorMaxExtent: anchorMaxExtent,
      convId: convId,
      msgId: msgId,
      seq: seq,
      phase: phase,
    );
  }

  Future<void> _snapToNaturalBottomIfNeeded({
    required ScrollPosition position,
    String? convId,
    String? msgId,
    required int seq,
    required double extentDelta,
    bool smooth = true,
  }) async {
    if (!position.hasContentDimensions || !position.hasPixels) {
      return;
    }
    final offBottom = position.pixels - position.minScrollExtent;
    ChatJitterDiag.logScrollReveal(
      phase: 'delta_done',
      conv: convId,
      msgId: msgId,
      extras: <String, Object?>{
        'seq': seq,
        'extentDelta': extentDelta.toStringAsFixed(1),
        'offBottomBeforeSnap': offBottom.toStringAsFixed(1),
        'scroll': ChatJitterDiag.scrollPositionSnapshot(
          pixels: position.pixels,
          minExtent: position.minScrollExtent,
          maxExtent: position.maxScrollExtent,
        ),
      },
    );
    if (offBottom.abs() <= _bottomSnapEpsilonPx) {
      return;
    }
    if (smooth && offBottom.abs() <= 96) {
      await _smoothCorrectBy(
        position: position,
        delta: -offBottom,
        duration: _smoothSnapDuration,
        convId: convId,
        msgId: msgId,
        phase: 'delta_snap_smooth',
        seq: seq,
      );
      return;
    }
    position.correctBy(-offBottom);
    ChatJitterDiag.logScrollReveal(
      phase: 'delta_snap',
      conv: convId,
      msgId: msgId,
      extras: <String, Object?>{
        'seq': seq,
        'correctedBy': (-offBottom).toStringAsFixed(1),
        'scroll': ChatJitterDiag.scrollPositionSnapshot(
          pixels: position.pixels,
          minExtent: position.minScrollExtent,
          maxExtent: position.maxScrollExtent,
        ),
      },
    );
  }

  Future<void> smoothSnapToNaturalBottom({
    required ScrollPosition position,
    double maxSmoothOffsetPx = 96,
    String? convId,
    String? msgId,
    String reason = 'pin_snap_smooth',
  }) async {
    if (!position.hasContentDimensions || !position.hasPixels) {
      return;
    }
    final offBottom = position.pixels - position.minScrollExtent;
    if (offBottom.abs() <= _bottomSnapEpsilonPx) {
      return;
    }
    if (offBottom.abs() <= maxSmoothOffsetPx) {
      await _smoothCorrectBy(
        position: position,
        delta: -offBottom,
        duration: _smoothSnapDuration,
        convId: convId,
        msgId: msgId,
        phase: reason,
      );
      return;
    }
    position.correctBy(-offBottom);
    ChatJitterDiag.logScrollReveal(
      phase: 'delta_snap',
      conv: convId,
      msgId: msgId,
      extras: <String, Object?>{
        'reason': reason,
        'correctedBy': (-offBottom).toStringAsFixed(1),
        'scroll': ChatJitterDiag.scrollPositionSnapshot(
          pixels: position.pixels,
          minExtent: position.minScrollExtent,
          maxExtent: position.maxScrollExtent,
        ),
      },
    );
  }

  Future<void> _smoothCorrectBy({
    required ScrollPosition position,
    required double delta,
    required Duration duration,
    String? convId,
    String? msgId,
    String phase = 'delta_smooth_correct',
    int? seq,
  }) async {
    if (delta.abs() < 0.5 || !position.hasContentDimensions) {
      return;
    }
    final controller = AnimationController(
      vsync: tickerProvider,
      duration: duration,
    );
    final animation =
        CurvedAnimation(parent: controller, curve: _revealEaseCurve);
    var lastProgress = 0.0;
    void tick() {
      final progress = animation.value;
      final step = delta * (progress - lastProgress);
      lastProgress = progress;
      if (step.abs() > 0.0001 && position.hasContentDimensions) {
        position.correctBy(step);
      }
    }

    animation.addListener(tick);
    try {
      await controller.forward();
    } finally {
      animation.removeListener(tick);
      animation.dispose();
      controller.dispose();
    }
    ChatJitterDiag.logScrollReveal(
      phase: phase,
      conv: convId,
      msgId: msgId,
      extras: <String, Object?>{
        if (seq != null) 'seq': seq,
        'correctedBy': delta.toStringAsFixed(1),
        'durationMs': duration.inMilliseconds,
        'scroll': ChatJitterDiag.scrollPositionSnapshot(
          pixels: position.pixels,
          minExtent: position.minScrollExtent,
          maxExtent: position.maxScrollExtent,
        ),
      },
    );
  }
}
