import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

typedef AppNetworkImagePlaceholderBuilder = Widget Function(
  BuildContext context,
  String url,
);

typedef AppNetworkImageErrorBuilder = Widget Function(
  BuildContext context,
  String url,
  Object error,
);

/// Web 跨域 OSS/CDN 图：CachedNetworkImage 默认走 createImageCodecFromUrl（带
/// crossOrigin，需要 OSS 配 CORS）。无自定义 headers 时改用 HTML `<img>` 展示。
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.headers,
    this.cacheKey,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.fadeInDuration = Duration.zero,
    this.fadeOutDuration = Duration.zero,
    this.useOldImageOnUrlChange = true,
    this.placeholder,
    this.errorWidget,
    this.imageBuilder,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Map<String, String>? headers;
  final String? cacheKey;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final bool useOldImageOnUrlChange;
  final AppNetworkImagePlaceholderBuilder? placeholder;
  final AppNetworkImageErrorBuilder? errorWidget;
  final ImageWidgetBuilder? imageBuilder;

  bool get _preferWebHtmlElement =>
      kIsWeb && (headers == null || headers!.isEmpty);

  @override
  Widget build(BuildContext context) {
    if (_preferWebHtmlElement) {
      // Web + OSS：走 HTML <img>，且不要 cacheWidth/Height——否则会回落到
      // canvas 解码并带 crossOrigin，触发 DevTools CORS 报错。
      Widget image = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: placeholder == null
            ? null
            : (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return placeholder!(context, url);
              },
        errorBuilder: errorWidget == null
            ? null
            : (context, error, stackTrace) =>
                errorWidget!(context, url, error),
      );
      if (imageBuilder != null) {
        image = imageBuilder!(
          context,
          NetworkImage(
            url,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          ),
        );
      }
      return image;
    }

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: cacheKey ?? url,
      httpHeaders: headers,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
      useOldImageOnUrlChange: useOldImageOnUrlChange,
      placeholder: placeholder == null
          ? null
          : (context, _) => placeholder!(context, url),
      errorWidget: errorWidget == null
          ? null
          : (context, _, error) => errorWidget!(context, url, error),
      imageBuilder: imageBuilder,
    );
  }
}
