import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/models/sticker_models.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_network_image.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_media.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// 磁盘缓存 key（与聊天图片缩略图区分；同一 sticker 的 GIF/缩略图分别缓存）。
String stickerNetworkImageCacheKey(String stickerId, String url) {
  final id = stickerId.trim();
  final normalized = url.trim();
  if (id.isNotEmpty && normalized.isNotEmpty) {
    return 'sticker:$id:${normalized.hashCode}';
  }
  if (id.isNotEmpty) {
    return 'sticker:$id';
  }
  if (normalized.isNotEmpty) {
    return 'sticker:url:${normalized.hashCode}';
  }
  return 'sticker:unknown';
}

/// 表情缩略图/动图展示；GIF 使用 [originUrl] 以保证动画播放。
class StickerImage extends StatelessWidget {
  const StickerImage({
    super.key,
    required this.item,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.preferAnimated = true,
    this.pauseWhenOffscreen = false,
  });

  StickerImage.url({
    super.key,
    required String url,
    String fallbackUrl = '',
    String mediaType = StickerMediaType.image,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.preferAnimated = true,
    this.pauseWhenOffscreen = false,
  }) : item = _UrlOnlyStickerItem(
          url: url,
          fallbackUrl: fallbackUrl,
          mediaType: mediaType,
        );

  final StickerItem item;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// true：优先 [originUrl] 播放 GIF；false：优先 [thumbUrl] 静态缩略图。
  final bool preferAnimated;

  /// 聊天列表等场景：滚出视口后改用静态缩略图，停止 GIF 解码。
  final bool pauseWhenOffscreen;

  @override
  Widget build(BuildContext context) {
    if (pauseWhenOffscreen && item.isAnimated) {
      return _StickerImageVisibilityGate(
        item: item,
        fit: fit,
        width: width,
        height: height,
        preferAnimated: preferAnimated,
      );
    }
    return _StickerImageContent(
      item: item,
      fit: fit,
      width: width,
      height: height,
      preferAnimated: preferAnimated,
    );
  }
}

class _StickerImageVisibilityGate extends StatefulWidget {
  const _StickerImageVisibilityGate({
    required this.item,
    required this.fit,
    required this.width,
    required this.height,
    required this.preferAnimated,
  });

  final StickerItem item;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool preferAnimated;

  @override
  State<_StickerImageVisibilityGate> createState() =>
      _StickerImageVisibilityGateState();
}

class _StickerImageVisibilityGateState extends State<_StickerImageVisibilityGate> {
  static const _visibilityThreshold = 0.01;

  /// 乐观默认为可见，保证首屏 GIF 立即播放；屏外项在首次 visibility 回调后暂停。
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    final primaryUrl = widget.item.displayUrl(preferAnimated: widget.preferAnimated);
    return VisibilityDetector(
      key: ValueKey(
        stickerNetworkImageCacheKey(widget.item.stickerId, primaryUrl),
      ),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > _visibilityThreshold;
        if (visible != _isVisible && mounted) {
          setState(() => _isVisible = visible);
        }
      },
      child: _StickerImageContent(
        item: widget.item,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        preferAnimated: widget.preferAnimated && _isVisible,
      ),
    );
  }
}

class _StickerImageContent extends StatelessWidget {
  const _StickerImageContent({
    required this.item,
    required this.fit,
    required this.width,
    required this.height,
    required this.preferAnimated,
  });

  final StickerItem item;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool preferAnimated;

  @override
  Widget build(BuildContext context) {
    final url = item.displayUrl(preferAnimated: preferAnimated);
    if (url.isEmpty) {
      return _stickerImagePlaceholder(width: width, height: height);
    }
    return _buildCachedImage(
      url: url,
      fallbackUrl: preferAnimated ? item.thumbUrl : item.originUrl,
    );
  }

  Widget _buildCachedImage({
    required String url,
    required String fallbackUrl,
  }) {
    if (kIsWeb) {
      return AppNetworkImage(
        url: url,
        cacheKey: stickerNetworkImageCacheKey(item.stickerId, url),
        fit: fit,
        width: width,
        height: height,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        errorWidget: (_, __, ___) {
          if (fallbackUrl.isNotEmpty && fallbackUrl != url) {
            return _buildCachedImage(url: fallbackUrl, fallbackUrl: '');
          }
          return _stickerImagePlaceholder(width: width, height: height);
        },
      );
    }
    return Image(
      image: CachedNetworkImageProvider(
        url,
        cacheKey: stickerNetworkImageCacheKey(item.stickerId, url),
      ),
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) {
        if (fallbackUrl.isNotEmpty && fallbackUrl != url) {
          return _buildCachedImage(url: fallbackUrl, fallbackUrl: '');
        }
        return _stickerImagePlaceholder(width: width, height: height);
      },
    );
  }
}

Widget _stickerImagePlaceholder({double? width, double? height}) {
  return SizedBox(
    width: width ?? 40,
    height: height ?? 40,
    child: const Icon(Icons.emoji_emotions_outlined),
  );
}

class _UrlOnlyStickerItem extends StickerItem {
  _UrlOnlyStickerItem({
    required String url,
    required String fallbackUrl,
    required String mediaType,
  }) : super(
          stickerId: '',
          thumbUrl: fallbackUrl.isNotEmpty ? fallbackUrl : url,
          originUrl: url,
          mediaType: mediaType,
        );
}
