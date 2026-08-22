import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 入站突发消息时如何跟随滚动（只动 ScrollPosition，不动气泡）。
enum InboundScrollFollowMode {
  /// 每块 layout 后同帧 jumpTo 钉底（更接近微信）。
  instant,

  /// 仅滚动 offset 做短插值（非 per-message 动画）。
  smooth,
}

/// 微信式 Scroll Follow：chunk 写入后修正滚动位置，避免阶梯跳变。
class InboundScrollFollow {
  InboundScrollFollow({
    required this.scrollController,
    this.shouldFollow,
    this.defaultSmoothDuration = const Duration(milliseconds: 100),
  });

  final ScrollController scrollController;
  final bool Function()? shouldFollow;
  final Duration defaultSmoothDuration;

  static const double _pinEpsilon = 0.5;

  ScrollPosition? get _position {
    if (!scrollController.hasClients) {
      return null;
    }
    return scrollController.position;
  }

  void handleChunk({
    required List<V2TimMessage> chunk,
    required bool sessionEnding,
    required InboundScrollFollowMode mode,
    Duration? smoothDuration,
  }) {
    if (!(shouldFollow?.call() ?? true)) {
      return;
    }
    if (_position == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyAfterLayout(
        sessionEnding: sessionEnding,
        mode: mode,
        smoothDuration: smoothDuration ?? defaultSmoothDuration,
      );
    });
  }

  void _applyAfterLayout({
    required bool sessionEnding,
    required InboundScrollFollowMode mode,
    required Duration smoothDuration,
  }) {
    // A drag can start after handleChunk schedules this callback. Re-check at
    // execution time so a stale auto-follow never overrides the user's gesture.
    if (!(shouldFollow?.call() ?? true)) {
      return;
    }
    final position = _position;
    if (position == null || !position.hasContentDimensions) {
      return;
    }

    final target = position.minScrollExtent;
    final drift = (position.pixels - target).abs();

    if (sessionEnding) {
      if (drift > _pinEpsilon) {
        if (mode == InboundScrollFollowMode.smooth) {
          unawaited(_followSmooth(target, smoothDuration));
        } else {
          scrollController.jumpTo(target);
        }
      }
      return;
    }

    if (mode == InboundScrollFollowMode.smooth) {
      if (drift > _pinEpsilon) {
        unawaited(_followSmooth(target, smoothDuration));
      }
      return;
    }

    if (drift > _pinEpsilon) {
      scrollController.jumpTo(target);
    }
  }

  Future<void> _followSmooth(double target, Duration duration) {
    if (!scrollController.hasClients) {
      return Future<void>.value();
    }
    if ((scrollController.offset - target).abs() <= _pinEpsilon) {
      return Future<void>.value();
    }
    return scrollController.animateTo(
      target,
      duration: duration,
      curve: Curves.easeInOut,
    );
  }

  void dispose() {}
}
