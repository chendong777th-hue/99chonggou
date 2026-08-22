class CustomStickerPackage {
  CustomStickerPackage({
    required this.name,
    this.baseUrl,
    this.isEmoji = false,
    this.isDefaultEmoji = false,
    required this.stickerList,
    required this.menuItem,
  });

  final String name;
  final String? baseUrl;
  final List<CustomSticker> stickerList;
  final CustomSticker menuItem;
  bool? isEmoji;
  bool isDefaultEmoji;

  bool get isCustomSticker => menuItem.unicode == null;
  bool get isCustomEmojiSticker => isEmoji == true;
  bool get isDefaultEmojiSticker => isDefaultEmoji == true;
}

class CustomSticker {
  const CustomSticker({
    required this.name,
    required this.index,
    this.url,
    this.unicode,
    this.thumbUrl,
    this.originUrl,
    this.mediaType,
  });

  final int? unicode;
  final String name;
  final int index;
  final String? url;
  final String? thumbUrl;
  final String? originUrl;
  final String? mediaType;
}

/// 磁盘缓存 key（与 99chat StickerImage 规则一致）。
String stickerPanelImageCacheKey(String stickerId, String url) {
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

class StickerListUtil {
  StickerListUtil(this.customStickerList);
  final List<Map<String, dynamic>> customStickerList;

  StickerListUtil._(this.customStickerList);

  static StickerListUtil? _instance;
  StickerListUtil get instance =>
      _instance ??= StickerListUtil._(customStickerList);
}
