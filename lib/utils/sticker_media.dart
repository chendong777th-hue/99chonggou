/// 表情资源类型：静态图与 GIF 动图。
class StickerMediaType {
  StickerMediaType._();

  static const String image = 'image';
  static const String gif = 'gif';

  static String fromJson(dynamic value) {
    final v = value?.toString().toLowerCase().trim() ?? '';
    if (v == gif || v == 'animated' || v == 'video') {
      return gif;
    }
    return image;
  }

  static bool isGifMediaType(String mediaType) => mediaType == gif;

  static bool isGifUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.gif');
  }

  static bool isAnimated({
    required String mediaType,
    required String thumbUrl,
    required String originUrl,
  }) {
    if (isGifMediaType(mediaType)) {
      return true;
    }
    return isGifUrl(thumbUrl) || isGifUrl(originUrl);
  }
}
