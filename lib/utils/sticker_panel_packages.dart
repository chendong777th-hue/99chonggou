import 'package:tencent_cloud_chat_demo/src/models/sticker_models.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tim_ui_kit_sticker_plugin/utils/tim_ui_kit_sticker_data.dart';

/// 微信风格底部表情包顺序：小黄脸 → Unicode → assets → 收藏+我的上传 → 其它服务端包。
List<CustomStickerPackage> buildWeChatStickerPanelPackages(
  StickerPanelConfig config, {
  List<FavoriteSticker> favorites = const [],
  List<StickerPack> extraServerPacks = const [],
}) {
  final packages = <CustomStickerPackage>[];

  if (config.useQQStickerPackage) {
    packages.add(_packageFromEmojiFaceData(
      TUIKitStickerConstData.emojiList.firstWhere((e) => e.name == '4349'),
    ));
  }

  if (config.unicodeEmojiList.isNotEmpty) {
    final defEmojiList = config.unicodeEmojiList.map((emojiItem) {
      return CustomSticker(index: 0, name: emojiItem.toString(), unicode: emojiItem);
    }).toList();
    packages.add(
      CustomStickerPackage(
        name: 'defaultEmoji',
        stickerList: defEmojiList,
        menuItem: defEmojiList.first,
      ),
    );
  }

  if (config.useTencentCloudChatStickerPackage) {
    packages.add(_packageFromEmojiFaceData(
      TUIKitStickerConstData.emojiList.firstWhere((e) => e.name == 'tcc1'),
    ));
  }

  for (final pack in config.customStickerPackages) {
    if (StickerConstants.visiblePanelAssetPackIds.contains(pack.name)) {
      packages.add(pack);
    }
  }

  final uploadStickers = extraServerPacks
      .where((p) => p.packId == StickerConstants.userUploadPackId)
      .expand((p) => p.stickers)
      .toList();
  packages.add(
    _networkStickerPackage(
      packId: StickerConstants.virtualPackFavorites,
      items: mergeFavoritesAndUploadStickers(
        favorites: favorites,
        uploads: uploadStickers,
      ),
    ),
  );

  for (final serverPack in extraServerPacks) {
    if (serverPack.packId.isEmpty ||
        serverPack.stickers.isEmpty ||
        serverPack.packId == StickerConstants.userUploadPackId ||
        StickerConstants.serverFavoritesPackIds.contains(serverPack.packId) ||
        StickerConstants.hiddenPanelAssetPackIds.contains(serverPack.packId)) {
      continue;
    }
    packages.add(_networkStickerPackage(
      packId: serverPack.packId,
      menuIconUrl: serverPack.iconUrl,
      items: serverPack.stickers,
    ));
  }

  return packages;
}

/// 收藏优先（按收藏时间倒序），再追加未重复的「我的上传」。
List<StickerItem> mergeFavoritesAndUploadStickers({
  required List<FavoriteSticker> favorites,
  required List<StickerItem> uploads,
}) {
  final seen = <String>{};
  final out = <StickerItem>[];

  final sortedFavorites = List<FavoriteSticker>.from(favorites)
    ..sort((a, b) {
      final ta = a.favoritedAt?.millisecondsSinceEpoch ?? 0;
      final tb = b.favoritedAt?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
  for (final fav in sortedFavorites) {
    final id = fav.stickerId.trim();
    if (id.isEmpty || seen.contains(id)) {
      continue;
    }
    seen.add(id);
    out.add(fav.toStickerItem());
  }

  final sortedUploads = List<StickerItem>.from(uploads)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  for (final item in sortedUploads) {
    final id = item.stickerId.trim();
    if (id.isEmpty || seen.contains(id)) {
      continue;
    }
    seen.add(id);
    out.add(item);
  }
  return out;
}

CustomStickerPackage _packageFromEmojiFaceData(CustomEmojiFaceData data) {
  return CustomStickerPackage(
    name: data.name,
    baseUrl: 'assets/custom_face_resource/${data.name}',
    isEmoji: data.isEmoji,
    isDefaultEmoji: true,
    stickerList: data.list
        .asMap()
        .keys
        .map((idx) => CustomSticker(index: idx, name: data.list[idx]))
        .toList(),
    menuItem: CustomSticker(
      index: 0,
      name: data.icon,
    ),
  );
}

CustomStickerPackage _networkStickerPackage({
  required String packId,
  required List<StickerItem> items,
  String menuIconUrl = '',
}) {
  final sorted = List<StickerItem>.from(items)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final firstThumb =
      sorted.isNotEmpty ? sorted.first.displayUrl(preferAnimated: false) : '';
  final tabIcon = menuIconUrl.isNotEmpty ? menuIconUrl : firstThumb;
  return CustomStickerPackage(
    name: packId,
    stickerList: sorted
        .asMap()
        .entries
        .map(
          (e) => CustomSticker(
            index: e.key,
            name: e.value.stickerId,
            url: e.value.displayUrl(preferAnimated: false),
            thumbUrl: e.value.thumbUrl,
            originUrl: e.value.originUrl,
            mediaType: e.value.mediaType,
          ),
        )
        .toList(),
    menuItem: CustomSticker(
      index: 0,
      name: 'menu',
      url: tabIcon.isNotEmpty ? tabIcon : null,
    ),
  );
}
