import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_mem_cache_utils.dart';

/// 进出聊天页时预热头像位图，降低大图挤掉 imageCache 后的可见闪动。
class AvatarImageWarm {
  AvatarImageWarm._();

  static const int _maxWarm = 24;
  static const Duration _timeout = Duration(milliseconds: 900);

  /// 预热一组头像 URL（逻辑尺寸按 [logicalSize] × DPR）。
  static Future<void> warmUrls(
    Iterable<String?> faceUrls, {
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
    for (final raw in faceUrls) {
      if (jobs.length >= _maxWarm) {
        break;
      }
      final resolved = UserAvatarHelper.resolveDisplayUrl(raw?.trim() ?? '');
      if (resolved == null || resolved.isEmpty) {
        continue;
      }
      if (resolved.startsWith('assets/')) {
        continue;
      }
      if (!seen.add(resolved)) {
        continue;
      }
      jobs.add(_warmOne(resolved, cacheSize));
    }
    if (jobs.isEmpty) {
      return;
    }
    try {
      await Future.wait(jobs).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> _warmOne(String url, int cacheSize) async {
    try {
      final headers = UserAvatarHelper.httpHeadersFor(url);
      final provider = ResizeImage(
        CachedNetworkImageProvider(
          url,
          headers: headers,
        ),
        width: cacheSize,
        height: cacheSize,
      );
      final stream = provider.resolve(const ImageConfiguration());
      final completer = Completer<void>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, __) {
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
      stream.removeListener(listener);
    } catch (_) {}
  }
}
