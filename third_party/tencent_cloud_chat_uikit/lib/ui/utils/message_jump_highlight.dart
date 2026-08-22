import 'dart:async';

import 'package:flutter/material.dart';

/// 定位到目标消息后的高亮色。
const Color kMessageJumpHighlightColor = Color.fromRGBO(245, 166, 35, 1);

/// 单次高亮持续时间（只闪一下）。
const Duration kMessageJumpHighlightDuration = Duration(milliseconds: 450);

/// 播放一次消息定位高亮，替代原先 6 次交替闪烁。
class MessageJumpHighlight {
  MessageJumpHighlight._();

  static Timer? play({
    required bool Function() mounted,
    required bool Function() getIsShining,
    required void Function(bool value) setIsShining,
    required void Function(void Function()) setState,
    required void Function(bool highlighted, {bool? border}) applyHighlight,
    required VoidCallback clearJump,
    bool Function()? shouldRun,
    Timer? previousTimer,
  }) {
    if (shouldRun != null && !shouldRun()) {
      return previousTimer;
    }
    if (getIsShining()) {
      return previousTimer;
    }
    setIsShining(true);
    setState(() => applyHighlight(true, border: true));
    clearJump();
    previousTimer?.cancel();
    return Timer(kMessageJumpHighlightDuration, () {
      if (mounted()) {
        setState(() => applyHighlight(false, border: false));
      }
      setIsShining(false);
    });
  }
}
