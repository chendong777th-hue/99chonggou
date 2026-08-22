import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_mem_cache_utils.dart';

/// 收藏项缩略图/预览：支持本地路径与网络 URL。
class FavoriteMediaPreview extends StatelessWidget {
  const FavoriteMediaPreview({
    super.key,
    required this.pathOrUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.dark = false,
  });

  final String? pathOrUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool dark;

  bool get _isNetwork {
    final p = pathOrUrl?.trim() ?? '';
    return p.startsWith('http://') || p.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final raw = pathOrUrl?.trim() ?? '';
    Widget child;
    if (raw.isEmpty) {
      child = _placeholder();
    } else if (_isNetwork) {
      final url = MediaUrlResolver.resolve(raw) ?? raw;
      final logicalWidth = width ?? height ?? 96;
      final logicalHeight = height ?? width ?? 96;
      final cacheWidth = ImageMemCacheSize.forLogicalSize(logicalWidth, context);
      final cacheHeight = ImageMemCacheSize.forLogicalSize(logicalHeight, context);
      child = CachedNetworkImage(
        imageUrl: url,
        httpHeaders: MediaUrlResolver.authHeadersFor(url),
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        maxWidthDiskCache: cacheWidth,
        maxHeightDiskCache: cacheHeight,
        placeholder: (_, __) => _placeholder(loading: true),
        errorWidget: (_, __, ___) => _placeholder(broken: true),
      );
    } else {
      final file = File(raw);
      final logicalWidth = width ?? height ?? 96;
      final logicalHeight = height ?? width ?? 96;
      final cacheWidth = ImageMemCacheSize.forLogicalSize(logicalWidth, context);
      final cacheHeight = ImageMemCacheSize.forLogicalSize(logicalHeight, context);
      child = Image.file(
        file,
        fit: fit,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (_, __, ___) => _placeholder(broken: true),
      );
    }

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder({bool loading = false, bool broken = false}) {
    return ColoredBox(
      color: AppColors.line(dark: dark),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                broken ? Icons.broken_image_outlined : Icons.image_outlined,
                color: AppColors.subText(dark: dark),
                size: 28,
              ),
      ),
    );
  }
}
