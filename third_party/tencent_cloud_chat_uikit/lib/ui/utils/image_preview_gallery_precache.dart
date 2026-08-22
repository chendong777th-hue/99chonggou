import 'dart:async';

import 'package:flutter/widgets.dart';

/// 图集相邻页图片预解码（半径默认 2，与 [ImageScreen] 缓存修剪对齐）。
class ImagePreviewGalleryPrecache {
  int _generation = 0;

  void precacheAdjacent({
    required BuildContext context,
    required int centerIndex,
    required int itemCount,
    required ImageProvider? Function(int index) resolveProvider,
    int radius = 2,
  }) {
    if (radius <= 0 || itemCount <= 0) {
      return;
    }
    final generation = ++_generation;
    for (var offset = -radius; offset <= radius; offset++) {
      if (offset == 0) {
        continue;
      }
      final index = centerIndex + offset;
      if (index < 0 || index >= itemCount) {
        continue;
      }
      final provider = resolveProvider(index);
      if (provider == null) {
        continue;
      }
      unawaited(() async {
        if (generation != _generation) {
          return;
        }
        try {
          await precacheImage(provider, context);
        } catch (_) {}
      }());
    }
  }

  void invalidate() {
    _generation++;
  }
}
