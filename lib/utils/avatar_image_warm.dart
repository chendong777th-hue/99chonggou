import 'dart:async';
import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_mem_cache_utils.dart';

class AvatarImageWarmSource {
  const AvatarImageWarmSource({required this.url, this.cacheKey});

  final String? url;
  final String? cacheKey;
}

/// 进出聊天页时预热头像位图，降低大图挤掉 imageCache 后的可见闪动。
class AvatarImageWarm {
  AvatarImageWarm._();

  static const int _maxWarm = 24;
  // A 200x200 thumb is at most ~160 KB decoded. Keep enough conversation
  // avatars alive for a long up/down scroll while retaining a firm bound.
  static const int _maxRetainedDecoded = 160;
  static const int _maxRetainedDecodedBytes = 20 << 20;
  static const Duration _timeout = Duration(milliseconds: 900);
  static final LinkedHashMap<String, _RetainedAvatarImage> _retainedDecoded =
      LinkedHashMap<String, _RetainedAvatarImage>();
  static final Set<String> _warmingDecoded = <String>{};
  static int _retainedDecodedBytes = 0;

  /// Canonical thumb provider shared by predictive warming and visible rows.
  /// Keeping this construction in one place prevents subtle ImageCache key
  /// drift from ResizeImage or disk-resize dimensions.
  static ImageProvider<Object> providerFor({
    required String url,
    required int cacheSize,
    String? cacheKey,
    Map<String, String>? headers,
  }) {
    return ResizeImage(
      CachedNetworkImageProvider(
        url,
        cacheKey: cacheKey,
        maxWidth: cacheSize,
        maxHeight: cacheSize,
        headers: headers,
      ),
      width: cacheSize,
      height: cacheSize,
    );
  }

  /// 预热一组头像 URL（逻辑尺寸按 [logicalSize] × DPR）。
  static Future<void> warmUrls(
    Iterable<String?> faceUrls, {
    required BuildContext context,
    double logicalSize = 40,
  }) {
    return warmSources(
      faceUrls.map((url) => AvatarImageWarmSource(url: url)),
      context: context,
      logicalSize: logicalSize,
    );
  }

  /// Uses the visible avatar's semantic cache key when one is available.
  static Future<void> warmSources(
    Iterable<AvatarImageWarmSource> sources, {
    required BuildContext context,
    double logicalSize = 40,
  }) async {
    // Web 跨域 OSS 无 CORS 头；CachedNetworkImageProvider 预热必失败且刷红 DevTools。
    if (kIsWeb) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final cacheSize = ImageMemCacheSize.forLogicalSize(logicalSize, context);
    final jobs = <Future<void>>[];
    final seen = <String>{};
    for (final source in sources) {
      if (jobs.length >= _maxWarm) {
        break;
      }
      final resolved =
          UserAvatarHelper.resolveDisplayUrl(source.url?.trim() ?? '');
      if (resolved == null || resolved.isEmpty) {
        continue;
      }
      if (resolved.startsWith('assets/')) {
        continue;
      }
      final semanticIdentity = source.cacheKey?.trim().isNotEmpty == true
          ? source.cacheKey!.trim()
          : resolved;
      // ResizeImage includes target dimensions in its ImageCache key. A thumb
      // warmed for a 40 logical-pixel chat header cannot satisfy a 54 logical-
      // pixel conversation row, even when owner/version are identical.
      final decodedIdentity = '$semanticIdentity@$cacheSize';
      if (!seen.add(decodedIdentity)) {
        continue;
      }
      final retained = _retainedDecoded.remove(decodedIdentity);
      if (retained != null) {
        _retainedDecoded[decodedIdentity] = retained;
        continue;
      }
      if (!_warmingDecoded.add(decodedIdentity)) {
        continue;
      }
      jobs.add(
        _warmOne(
          resolved,
          cacheSize,
          decodedIdentity: decodedIdentity,
          cacheKey: source.cacheKey,
        ),
      );
    }
    if (jobs.isEmpty) {
      return;
    }
    try {
      await Future.wait(jobs).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> _warmOne(
    String url,
    int cacheSize, {
    required String decodedIdentity,
    String? cacheKey,
  }) async {
    try {
      final headers = UserAvatarHelper.httpHeadersFor(url);
      final provider = providerFor(
        url: url,
        cacheKey: cacheKey,
        cacheSize: cacheSize,
        headers: headers,
      );
      final stream = provider.resolve(const ImageConfiguration());
      final completer = Completer<void>();
      var decoded = false;
      var decodedBytes = cacheSize * cacheSize * 4;
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, __) {
          decoded = true;
          decodedBytes = info.image.width * info.image.height * 4;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (_, __) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );
      stream.addListener(listener);
      await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
      if (decoded) {
        _retainDecoded(
          decodedIdentity,
          stream,
          listener,
          decodedBytes: decodedBytes,
        );
      } else {
        stream.removeListener(listener);
      }
    } catch (_) {
      // A cold/failed thumb keeps the normal avatar fallback visible.
    } finally {
      _warmingDecoded.remove(decodedIdentity);
    }
  }

  static void _retainDecoded(
    String identity,
    ImageStream stream,
    ImageStreamListener listener, {
    required int decodedBytes,
  }) {
    final previous = _retainedDecoded.remove(identity);
    if (previous != null) {
      previous.stream.removeListener(previous.listener);
      _retainedDecodedBytes -= previous.decodedBytes;
    }
    final retained = _RetainedAvatarImage(
      stream,
      listener,
      decodedBytes: decodedBytes,
    );
    _retainedDecoded[identity] = retained;
    _retainedDecodedBytes += retained.decodedBytes;
    while (_retainedDecoded.length > _maxRetainedDecoded ||
        _retainedDecodedBytes > _maxRetainedDecodedBytes) {
      final oldestKey = _retainedDecoded.keys.first;
      final oldest = _retainedDecoded.remove(oldestKey);
      if (oldest != null) {
        oldest.stream.removeListener(oldest.listener);
        _retainedDecodedBytes -= oldest.decodedBytes;
      }
    }
  }

  /// Releases the dedicated decoded-thumb pins during memory-pressure
  /// lifecycle transitions. Visible Image widgets keep their own listeners.
  static void clearRetainedDecoded() {
    for (final retained in _retainedDecoded.values) {
      retained.stream.removeListener(retained.listener);
    }
    _retainedDecoded.clear();
    _retainedDecodedBytes = 0;
  }
}

class _RetainedAvatarImage {
  const _RetainedAvatarImage(
    this.stream,
    this.listener, {
    required this.decodedBytes,
  });

  final ImageStream stream;
  final ImageStreamListener listener;
  final int decodedBytes;
}
