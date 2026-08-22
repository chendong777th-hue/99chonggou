import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_image.dart';

/// 从图片字节流探测真实宽高；按 URL 内存缓存，避免重复解码。
class StickerImageSizeProbe {
  StickerImageSizeProbe._();

  static final StickerImageSizeProbe instance = StickerImageSizeProbe._();

  final Map<String, Size> _cache = {};
  final Map<String, Future<Size?>> _inflight = {};

  Size? cached(String url) {
    final key = url.trim();
    if (key.isEmpty) {
      return null;
    }
    return _cache[key];
  }

  /// 探测 [url] 对应图片像素尺寸；失败返回 `null`。
  Future<Size?> probe(
    String url, {
    String stickerId = '',
    ImageProvider? provider,
    Duration timeout = const Duration(seconds: 8),
  }) {
    if (kIsWeb) {
      return Future<Size?>.value(null);
    }
    final key = url.trim();
    if (key.isEmpty) {
      return Future<Size?>.value(null);
    }
    final hit = _cache[key];
    if (hit != null) {
      return Future<Size?>.value(hit);
    }
    final running = _inflight[key];
    if (running != null) {
      return running;
    }
    final task = _probeProvider(
      provider ??
          CachedNetworkImageProvider(
            key,
            cacheKey: stickerNetworkImageCacheKey(stickerId, key),
          ),
    ).timeout(timeout, onTimeout: () => null);
    final tracked = task.then((size) {
      if (size != null && size.width > 0 && size.height > 0) {
        _cache[key] = size;
      }
      return size;
    }).whenComplete(() {
      _inflight.remove(key);
    });
    _inflight[key] = tracked;
    return tracked;
  }

  Future<Size?> _probeProvider(ImageProvider provider) {
    final completer = Completer<Size?>();
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        stream.removeListener(listener);
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        info.dispose();
        if (!completer.isCompleted) {
          completer.complete(size);
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// 测试 / 登出时可清空。
  void clear() {
    _cache.clear();
    _inflight.clear();
  }
}
