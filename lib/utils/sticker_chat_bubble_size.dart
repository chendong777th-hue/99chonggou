import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// 会话气泡中收藏/自定义表情的展示尺寸。
///
/// 优先使用资源原始宽高（与后端 `StickerItem.width/height` 一致），
/// 先按 [kStickerChatBubbleDisplayScale] 略缩小，再在超出屏宽上限时等比收敛。
const double kStickerChatBubbleDisplayScale = 0.82;

/// 主气泡相对屏宽的最大宽度比例。
const double kStickerChatBubbleMaxWidthFactor = 0.55;

Size resolveStickerChatBubbleSize({
  required double screenWidth,
  required double maxWidthFactor,
  int? intrinsicWidth,
  int? intrinsicHeight,
}) {
  final maxW = screenWidth *
      (maxWidthFactor >= 0.3
          ? kStickerChatBubbleMaxWidthFactor
          : maxWidthFactor);
  final maxH = maxW * 1.35;

  final ow = intrinsicWidth;
  final oh = intrinsicHeight;
  if (ow != null && oh != null && ow > 0 && oh > 0) {
    var w = ow.toDouble() * kStickerChatBubbleDisplayScale;
    var h = oh.toDouble() * kStickerChatBubbleDisplayScale;
    if (w > maxW || h > maxH) {
      final scale = math.min(maxW / w, maxH / h);
      w *= scale;
      h *= scale;
    }
    return Size(w, h);
  }

  // 无原始尺寸时退回按屏宽比例的方块（引用预览更小）。
  final side = maxWidthFactor >= 0.3
      ? (screenWidth * maxWidthFactor * 0.85).clamp(120.0, 180.0)
      : (screenWidth * maxWidthFactor).clamp(72.0, 140.0);
  return Size(side, side);
}
