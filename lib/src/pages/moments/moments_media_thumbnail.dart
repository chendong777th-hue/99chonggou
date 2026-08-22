import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_mem_cache_utils.dart';

/// Size-bounded image used by Moments feeds/grids.
///
/// Feed thumbnails must never decode the source image at full resolution: a
/// single phone photo can otherwise consume tens of MB before being painted
/// into a ~100px cell.
class MomentsMediaThumbnail extends StatelessWidget {
  const MomentsMediaThumbnail({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.fallbackLogicalSize = 240,
    this.placeholderColor,
  });

  final String path;
  final BoxFit fit;
  final double fallbackLogicalSize;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheSize = ImageMemCacheSize.forBox(
          constraints,
          context,
          fallback: fallbackLogicalSize,
          max: 1080,
        );
        final raw = path.trim();
        if (raw.startsWith('assets/')) {
          return Image.asset(
            raw,
            fit: fit,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            filterQuality: FilterQuality.low,
          );
        }
        if (raw.startsWith('http')) {
          final resolved = MediaUrlResolver.resolve(raw) ?? raw;
          return CachedNetworkImage(
            imageUrl: resolved,
            cacheKey: resolved,
            fit: fit,
            httpHeaders: MediaUrlResolver.authHeadersFor(resolved),
            memCacheWidth: cacheSize,
            memCacheHeight: cacheSize,
            maxWidthDiskCache: cacheSize,
            maxHeightDiskCache: cacheSize,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            useOldImageOnUrlChange: true,
            placeholder: placeholderColor == null
                ? null
                : (_, __) => ColoredBox(color: placeholderColor!),
          );
        }
        return Image.file(
          File(raw),
          fit: fit,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      },
    );
  }
}
