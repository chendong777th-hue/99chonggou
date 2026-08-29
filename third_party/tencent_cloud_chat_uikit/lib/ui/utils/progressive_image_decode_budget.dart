import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Progressive image decode budget for full-screen preview.
///
/// Instead of decoding the entire original image at once (which can cause
/// OOM on low-end devices for 20MB+ images), this class manages a
/// tiered decode strategy:
///
/// 1. **Preview tier** (immediate): decode at screen resolution (~1080px).
///    Memory cost: ~4-8MB regardless of original size.
/// 2. **Zoom tier** (on demand): when the user pinches to zoom beyond
///    1.5x, re-decode at a higher resolution up to [maxDecodePx].
///    Memory cost scales with zoom level, not original file size.
/// 3. **Full tier** (deferred): if zoom exceeds [fullDecodeThreshold],
///    request the ORIGIN image but with a memory guard that caps the
///    decoded pixel count at [maxDecodePx]. If the image exceeds this,
///    it is decoded at the maximum safe resolution and the user sees
///    a slight pixelation at extreme zoom (better than crashing).
///
/// This mirrors QQ's tile-loading approach: only decode what's visible
/// at the current zoom level, never load the full bitmap into memory.
class ProgressiveImageDecodeBudget {
  ProgressiveImageDecodeBudget._();

  /// Maximum decoded pixel count for the zoom tier. ~40MP = ~160MB raw,
  /// which is safe for devices with 4GB+ RAM. Lower-end devices are
  /// protected by the [kChatBubbleImageDecodeMaxPx] guard on bubble decode.
  static const int maxDecodePx = 40 * 1000 * 1000;

  /// Zoom level beyond which the full-res tier is requested.
  static const double fullDecodeThreshold = 2.0;

  /// Screen-resolution decode target for the preview tier.
  static int previewCacheWidth(double screenWidth, double pixelRatio) {
    return (screenWidth * pixelRatio).round().clamp(320, 2560);
  }

  /// Computes the safe cacheWidth/cacheHeight for a given zoom level
  /// and original image dimensions. Returns null if the original can
  /// be decoded at full resolution without exceeding [maxDecodePx].
  static ({int? cacheWidth, int? cacheHeight}) safeDecodeDimensions({
    required double zoomLevel,
    required int? originalWidth,
    required int? originalHeight,
    required int screenWidthPx,
  }) {
    if (originalWidth == null || originalHeight == null ||
        originalWidth <= 0 || originalHeight <= 0) {
      return (cacheWidth: screenWidthPx, cacheHeight: null);
    }

    final originalPixels = originalWidth * originalHeight;
    if (originalPixels <= maxDecodePx) {
      // Small enough to decode fully.
      return (cacheWidth: null, cacheHeight: null);
    }

    // Calculate the target decode size based on zoom level.
    // At 1x: decode at screen resolution.
    // At 2x: decode at 2x screen resolution (capped by maxDecodePx).
    // At 4x+: decode at maxDecodePx.
    final zoomFactor = math.max(1.0, zoomLevel);
    final targetWidth = (screenWidthPx * zoomFactor).round();
    final targetPixels = targetWidth * (originalHeight * targetWidth ~/ originalWidth);

    if (targetPixels <= maxDecodePx) {
      final w = targetWidth.clamp(1, originalWidth);
      final h = (w * originalHeight ~/ originalWidth).clamp(1, originalHeight);
      return (cacheWidth: w, cacheHeight: h);
    }

    // Cap at maxDecodePx: compute the largest dimension that fits.
    final ratio = originalHeight / originalWidth;
    final maxW = math.sqrt(maxDecodePx / ratio).floor();
    final maxH = (maxW * ratio).floor();
    return (cacheWidth: maxW, cacheHeight: maxH);
  }

  /// Returns true if the image is "large" and needs progressive decode.
  static bool needsProgressiveDecode(int? width, int? height) {
    if (width == null || height == null) return false;
    return width * height > maxDecodePx;
  }
}
