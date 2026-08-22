import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/utils/object_url_normalize.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_media.dart';

class StickerItem {
  StickerItem({
    required this.stickerId,
    required this.thumbUrl,
    required this.originUrl,
    this.mediaType = StickerMediaType.image,
    this.width,
    this.height,
    this.sortOrder = 0,
  });

  final String stickerId;
  final String thumbUrl;
  final String originUrl;

  /// `image` | `gif`（与后端 [mediaType] 一致）
  final String mediaType;
  final int? width;
  final int? height;
  final int sortOrder;

  bool get hasIntrinsicSize =>
      width != null && height != null && width! > 0 && height! > 0;

  bool get isAnimated => StickerMediaType.isAnimated(
        mediaType: mediaType,
        thumbUrl: thumbUrl,
        originUrl: originUrl,
      );

  /// [preferAnimated] true 时 GIF 优先 [originUrl]（聊天播放动图）。
  String displayUrl({required bool preferAnimated}) {
    if (isAnimated) {
      if (preferAnimated) {
        return originUrl.isNotEmpty ? originUrl : thumbUrl;
      }
      return thumbUrl.isNotEmpty ? thumbUrl : originUrl;
    }
    return thumbUrl.isNotEmpty ? thumbUrl : originUrl;
  }

  StickerItem copyWithSize({required int width, required int height}) {
    return StickerItem(
      stickerId: stickerId,
      thumbUrl: thumbUrl,
      originUrl: originUrl,
      mediaType: mediaType,
      width: width,
      height: height,
      sortOrder: sortOrder,
    );
  }

  factory StickerItem.fromJson(Map<String, dynamic> json) => StickerItem(
        stickerId: json['stickerId']?.toString() ?? '',
        thumbUrl: json['thumbUrl']?.toString() ?? '',
        originUrl: json['originUrl']?.toString() ?? '',
        mediaType: StickerMediaType.fromJson(json['mediaType']),
        width: _readPositiveInt(json['width']),
        height: _readPositiveInt(json['height']),
        sortOrder: json['sortOrder'] as int? ?? 0,
      );
}

int? _readPositiveInt(dynamic raw) {
  if (raw is int) {
    return raw > 0 ? raw : null;
  }
  if (raw is num) {
    final value = raw.toInt();
    return value > 0 ? value : null;
  }
  final parsed = int.tryParse(raw?.toString() ?? '');
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

class StickerPack {
  StickerPack({
    required this.packId,
    required this.name,
    required this.iconUrl,
    required this.source,
    required this.sortOrder,
    required this.removable,
    required this.stickers,
  });

  final String packId;
  final String name;
  final String iconUrl;
  final String source;
  final int sortOrder;
  final bool removable;
  final List<StickerItem> stickers;

  factory StickerPack.fromJson(Map<String, dynamic> json) {
    final rawStickers = json['stickers'];
    final stickers = rawStickers is List
        ? rawStickers
            .whereType<Map>()
            .map((e) => StickerItem.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.stickerId.isNotEmpty)
            .toList()
        : <StickerItem>[];
    return StickerPack(
      packId: json['packId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      iconUrl: json['iconUrl']?.toString() ?? '',
      source: json['source']?.toString() ?? 'custom',
      sortOrder: json['sortOrder'] as int? ?? 0,
      removable: json['removable'] as bool? ?? true,
      stickers: stickers,
    );
  }
}

class FavoriteSticker {
  FavoriteSticker({
    required this.stickerId,
    required this.thumbUrl,
    required this.originUrl,
    this.mediaType = StickerMediaType.image,
    this.favoritedAt,
  });

  final String stickerId;
  final String thumbUrl;
  final String originUrl;
  final String mediaType;
  final DateTime? favoritedAt;

  StickerItem toStickerItem() => StickerItem(
        stickerId: stickerId,
        thumbUrl: thumbUrl,
        originUrl: originUrl,
        mediaType: mediaType,
      );

  factory FavoriteSticker.fromJson(Map<String, dynamic> json) {
    var map = Map<String, dynamic>.from(json);
    final nested = map['sticker'];
    if (nested is Map) {
      map = {
        ...Map<String, dynamic>.from(nested),
        ...map,
      };
    }
    final stickerId = (map['stickerId'] ?? map['id'] ?? '').toString().trim();
    var thumbUrl = (map['thumbUrl'] ??
            map['thumbnail'] ??
            map['thumb'] ??
            map['url'] ??
            '')
        .toString();
    var originUrl = (map['originUrl'] ?? map['origin'] ?? map['url'] ?? '')
        .toString();
    if (thumbUrl.isEmpty && originUrl.isNotEmpty) {
      thumbUrl = originUrl;
    }
    if (originUrl.isEmpty && thumbUrl.isNotEmpty) {
      originUrl = thumbUrl;
    }
    thumbUrl = normalizeObjectUrl(thumbUrl);
    originUrl = normalizeObjectUrl(originUrl);
    return FavoriteSticker(
      stickerId: stickerId,
      thumbUrl: thumbUrl,
      originUrl: originUrl,
      mediaType: StickerMediaType.fromJson(map['mediaType']),
      favoritedAt: MeResult.parseIsoDateTime(
        map['favoritedAt'] ?? map['createdAt'] ?? map['favoriteAt'],
      ),
    );
  }

  /// 用已知的 [StickerItem] 补全缺失的缩略图 URL。
  FavoriteSticker mergeUrlsFrom(StickerItem? item) {
    if (item == null) {
      return this;
    }
    return FavoriteSticker(
      stickerId: stickerId,
      thumbUrl: thumbUrl.isNotEmpty ? thumbUrl : item.thumbUrl,
      originUrl: originUrl.isNotEmpty ? originUrl : item.originUrl,
      mediaType: mediaType != StickerMediaType.image
          ? mediaType
          : item.mediaType,
      favoritedAt: favoritedAt,
    );
  }
}

/// 合并收藏列表并按 stickerId 去重（保留 [primary] 中较早出现的项）。
List<FavoriteSticker> mergeFavoriteStickerLists(
  List<FavoriteSticker> primary,
  List<FavoriteSticker> extra,
) {
  final seen = <String>{};
  final out = <FavoriteSticker>[];
  for (final list in [primary, extra]) {
    for (final fav in list) {
      final id = fav.stickerId.trim();
      if (id.isEmpty || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      out.add(fav);
    }
  }
  return out;
}
