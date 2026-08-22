import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart';
import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';

/// 朋友圈封面磁盘 / 内存预热，与 [CachedNetworkImage] 使用同一 cacheKey。
class MomentsCoverCache {
  MomentsCoverCache._();

  static String? _lastPrefetched;

  /// 单测关闭预热，避免 CacheManager / path_provider 插件通道报错。
  static bool debugDisablePrefetch = false;

  static String? resolvedUrl(String? url) {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty || raw.startsWith('assets/')) {
      return null;
    }
    if (!(raw.startsWith('http://') ||
        raw.startsWith('https://') ||
        raw.startsWith('/'))) {
      return null;
    }
    final resolved = MediaUrlResolver.resolve(raw)?.trim() ?? '';
    if (resolved.isEmpty ||
        !(resolved.startsWith('http://') || resolved.startsWith('https://'))) {
      return null;
    }
    return resolved;
  }

  static String? cacheKeyFor(String? url) => resolvedUrl(url);

  static void reset() {
    _lastPrefetched = null;
  }

  static void prefetch(String? url) {
    if (kIsWeb || debugDisablePrefetch) {
      return;
    }
    final resolved = resolvedUrl(url);
    if (resolved == null) {
      return;
    }
    if (_lastPrefetched == resolved) {
      return;
    }
    _lastPrefetched = resolved;
    final provider = CachedNetworkImageProvider(
      resolved,
      headers: MediaUrlResolver.authHeadersFor(resolved),
      cacheKey: resolved,
    );
    unawaited(_warm(provider));
  }

  static Future<void> _warm(ImageProvider provider) async {
    try {
      final stream = provider.resolve(const ImageConfiguration());
      final done = Completer<void>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, __) {
          if (!done.isCompleted) {
            done.complete();
          }
          stream.removeListener(listener);
        },
        onError: (_, __) {
          if (!done.isCompleted) {
            done.complete();
          }
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      await done.future;
    } catch (_) {}
  }
}
