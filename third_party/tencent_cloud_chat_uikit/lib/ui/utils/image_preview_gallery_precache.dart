import 'dart:async';

import 'package:flutter/widgets.dart';

/// Gallery adjacent-image precaching with directional priority.
///
/// Strategy inspired by Telegram's gallery:
/// 1. **Directional prefetch**: if the user moved from index A to index B,
///    prioritize prefetching B+1 (the next direction) over B-1 (behind).
/// 2. **Sequential decode**: one precache at a time to avoid decode spikes.
/// 3. **Generation guard**: a new navigation cancels in-flight precaches.
/// 4. **Small source warm-up**: the preview-tier image (small cacheWidth)
///    primes the SDK/byte cache so the full-res decode is a fast hit.
class ImagePreviewGalleryPrecache {
  int _generation = 0;
  int _lastCenterIndex = -1;
  int _lastDirection = 0;
  Completer<void>? _currentDecode;

  void precacheAdjacent({
    required BuildContext context,
    required int centerIndex,
    required int itemCount,
    required ImageProvider? Function(int index) resolveProvider,
    int radius = 3,
  }) {
    if (radius <= 0 || itemCount <= 0) {
      return;
    }

    // Detect direction: if centerIndex increased, user is moving forward;
    // prioritize next (forward) over prev (backward).
    final direction = centerIndex > _lastCenterIndex
        ? 1
        : centerIndex < _lastCenterIndex
            ? -1
            : _lastDirection;
    _lastCenterIndex = centerIndex;
    _lastDirection = direction;

    final generation = ++_generation;
    _currentDecode?.complete();
    _currentDecode = null;

    // Build the prefetch order: direction-first, then the rest.
    final indices = <int>[];
    for (var offset = 1; offset <= radius; offset++) {
      // Forward direction first.
      final forward = centerIndex + direction * offset;
      if (forward >= 0 && forward < itemCount) {
        indices.add(forward);
      }
      // Backward direction second.
      final backward = centerIndex - direction * offset;
      if (backward >= 0 && backward < itemCount && backward != forward) {
        indices.add(backward);
      }
    }

    // Sequential decode: process one at a time to avoid decode spikes.
    unawaited(_decodeSequential(
      context: context,
      indices: indices,
      resolveProvider: resolveProvider,
      generation: generation,
    ));
  }

  Future<void> _decodeSequential({
    required BuildContext context,
    required List<int> indices,
    required ImageProvider? Function(int index) resolveProvider,
    required int generation,
  }) async {
    for (final index in indices) {
      if (generation != _generation) {
        return; // Cancelled by a new navigation.
      }
      final provider = resolveProvider(index);
      if (provider == null) {
        continue;
      }
      final completer = Completer<void>();
      _currentDecode = completer;
      try {
        await precacheImage(provider, context).timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
      } catch (_) {
        // Best-effort: one failed precache shouldn't stop the rest.
      }
      completer.complete();
      if (generation != _generation) {
        return;
      }
    }
  }

  void invalidate() {
    _generation++;
    _currentDecode?.complete();
    _currentDecode = null;
  }
}
