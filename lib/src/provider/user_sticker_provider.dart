import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/sticker_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/sticker_models.dart';
import 'package:tencent_cloud_chat_demo/src/provider/custom_sticker_package.dart';
import 'package:tencent_cloud_chat_demo/src/repository/sticker_repository.dart';
import 'package:tencent_cloud_chat_demo/utils/constant.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_favorite_store.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_recent_store.dart';
import 'package:tim_ui_kit_sticker_plugin/utils/tim_ui_kit_sticker_data.dart';

/// [favorite] 的返回结果，用于区分「新收藏」与「已在收藏中」。
enum StickerFavoriteOutcome {
  added,
  alreadyExists,
  invalidId,
}

class UserStickerProvider extends ChangeNotifier {
  UserStickerProvider._();
  static final UserStickerProvider shared = UserStickerProvider._();

  List<StickerPack> _serverPacks = [];
  List<FavoriteSticker> _favorites = [];
  List<String> _recentIds = [];
  bool _loaded = false;

  List<StickerPack> get serverPacks => List.unmodifiable(_serverPacks);
  List<FavoriteSticker> get favorites => List.unmodifiable(_favorites);
  List<String> get recentIds => List.unmodifiable(_recentIds);
  bool get loaded => _loaded;

  StickerItem? findStickerById(String stickerId) {
    final id = stickerId.trim();
    final cached = StickerRepository.instance.getCached(id);
    if (cached != null) {
      return cached;
    }
    for (final fav in _favorites) {
      if (fav.stickerId == id) {
        return fav.toStickerItem();
      }
    }
    for (final pack in _serverPacks) {
      for (final s in pack.stickers) {
        if (s.stickerId == id) {
          return s;
        }
      }
    }
    return null;
  }

  Future<void> refresh({bool force = false}) async {
    if (_loaded && !force) {
      return;
    }
    List<StickerPack> packs = List<StickerPack>.from(_serverPacks);
    List<FavoriteSticker> apiFavorites = [];
    List<String> recentIds = List<String>.from(_recentIds);
    Object? packsError;
    Object? favoritesError;

    try {
      packs = await StickerApi.instance.listMyPacks();
    } catch (e, st) {
      packsError = e;
      if (kDebugMode) {
        debugPrint('[Sticker] listMyPacks failed: $e\n$st');
      }
    }

    try {
      apiFavorites = await StickerApi.instance.listFavorites();
    } catch (e, st) {
      favoritesError = e;
      if (kDebugMode) {
        debugPrint('[Sticker] listFavorites failed: $e\n$st');
      }
    }

    final localFavorites = await StickerFavoriteStore.load();
    var favorites = mergeFavoriteStickerLists(
      apiFavorites,
      StickerApi.instance.favoritesFromPacks(packs),
    );
    favorites = mergeFavoriteStickerLists(favorites, localFavorites);
    favorites = mergeFavoriteStickerLists(favorites, _favorites);
    favorites = _enrichFavoritesWithPackStickers(favorites, packs);
    favorites = await _hydrateFavoriteUrls(favorites);

    try {
      recentIds = await StickerRecentStore.loadIds();
    } catch (_) {}

    _serverPacks = packs;
    _favorites = favorites;
    _recentIds = recentIds;
    StickerRepository.instance.putCaches(
      _serverPacks.expand((p) => p.stickers),
    );
    StickerRepository.instance.putCaches(
      _favorites.map((f) => f.toStickerItem()),
    );
    await StickerFavoriteStore.save(_favorites);
    _loaded = true;
    if (kDebugMode) {
      debugPrint(
        '[Sticker] refresh done packs=${packs.length} '
        'apiFav=${apiFavorites.length} mergedFav=${favorites.length} '
        'localFav=${localFavorites.length} '
        'packsErr=$packsError favErr=$favoritesError',
      );
    }
    notifyListeners();
  }

  Future<List<FavoriteSticker>> _hydrateFavoriteUrls(
    List<FavoriteSticker> favorites,
  ) async {
    final out = <FavoriteSticker>[];
    for (final fav in favorites) {
      if (fav.thumbUrl.isNotEmpty || fav.originUrl.isNotEmpty) {
        out.add(fav);
        continue;
      }
      final cached = findStickerById(fav.stickerId);
      if (cached != null &&
          (cached.thumbUrl.isNotEmpty || cached.originUrl.isNotEmpty)) {
        out.add(fav.mergeUrlsFrom(cached));
        continue;
      }
      try {
        final item = await StickerApi.instance.getSticker(fav.stickerId);
        StickerRepository.instance.putCache(item);
        out.add(fav.mergeUrlsFrom(item));
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[Sticker] hydrate favorite ${fav.stickerId} failed: $e',
          );
        }
        out.add(fav);
      }
    }
    return out;
  }

  List<FavoriteSticker> _enrichFavoritesWithPackStickers(
    List<FavoriteSticker> favorites,
    List<StickerPack> packs,
  ) {
    final byId = <String, StickerItem>{};
    for (final pack in packs) {
      for (final s in pack.stickers) {
        byId[s.stickerId] = s;
      }
    }
    return favorites
        .map((f) => f.mergeUrlsFrom(byId[f.stickerId]))
        .toList();
  }

  Future<StickerFavoriteOutcome> favorite(String stickerId) async {
    final id = stickerId.trim();
    if (id.isEmpty) {
      return StickerFavoriteOutcome.invalidId;
    }
    final existing = _favorites.indexWhere((f) => f.stickerId == id);
    if (existing >= 0) {
      return StickerFavoriteOutcome.alreadyExists;
    }
    final item = findStickerById(id);
    final optimistic = FavoriteSticker(
      stickerId: id,
      thumbUrl: item?.thumbUrl ?? '',
      originUrl: item?.originUrl ?? '',
      favoritedAt: DateTime.now().toUtc(),
    );
    _favorites = [..._favorites, optimistic];
    await StickerFavoriteStore.save(_favorites);
    notifyListeners();
    try {
      await StickerApi.instance.addFavorite(id);
      await refresh(force: true);
      if (_favorites.every((f) => f.stickerId != id)) {
        _favorites = [..._favorites, optimistic];
        await StickerFavoriteStore.save(_favorites);
        notifyListeners();
      }
    } catch (e) {
      _favorites = _favorites.where((f) => f.stickerId != id).toList();
      await StickerFavoriteStore.save(_favorites);
      notifyListeners();
      rethrow;
    }
    return StickerFavoriteOutcome.added;
  }

  Future<void> unfavorite(String stickerId) async {
    final id = stickerId.trim();
    if (id.isEmpty) {
      return;
    }
    final previous = List<FavoriteSticker>.from(_favorites);
    _favorites = _favorites.where((f) => f.stickerId != id).toList();
    notifyListeners();
    try {
      await StickerApi.instance.removeFavorite(id);
      await StickerFavoriteStore.save(_favorites);
      notifyListeners();
    } catch (e) {
      _favorites = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> afterUpload(StickerItem item) async {
    StickerRepository.instance.putCache(item);
    try {
      await StickerApi.instance.addToCustomPack(item.stickerId);
    } catch (_) {}
    await refresh(force: true);
  }

  Future<void> removeUpload(String stickerId) async {
    await StickerApi.instance.removeFromCustomPack(stickerId);
    await refresh(force: true);
  }

  Future<void> uninstallPack(String packId) async {
    await StickerApi.instance.uninstallPack(packId);
    await refresh(force: true);
  }

  Future<void> updatePackOrder(List<String> packIds) async {
    await StickerApi.instance.updatePackOrder(packIds);
    await refresh(force: true);
  }

  void clear() {
    _serverPacks = [];
    _favorites = [];
    _recentIds = [];
    _loaded = false;
    StickerRepository.instance.clear();
    StickerFavoriteStore.clear();
    notifyListeners();
  }

  List<CustomStickerPackage> buildCustomStickerPackages() {
    final packages = <CustomStickerPackage>[];

    packages.addAll(Const.emojiList.map((customEmojiPackage) {
      return CustomStickerPackage(
        name: customEmojiPackage.name,
        baseUrl: 'assets/custom_face_resource/${customEmojiPackage.name}',
        isEmoji: customEmojiPackage.isEmoji,
        stickerList: customEmojiPackage.list
            .asMap()
            .keys
            .map(
              (idx) => CustomSticker(
                index: idx,
                name: customEmojiPackage.list[idx],
              ),
            )
            .toList(),
        menuItem: CustomSticker(
          index: 0,
          name: customEmojiPackage.icon,
        ),
      );
    }));

    final sortedServer = List<StickerPack>.from(_serverPacks)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final pack in sortedServer) {
      if (pack.packId.isEmpty || pack.stickers.isEmpty) {
        continue;
      }
      packages.add(_packToCustom(pack));
    }

    final recentItems = <StickerItem>[];
    for (final id in _recentIds) {
      final item = findStickerById(id);
      if (item != null && item.thumbUrl.isNotEmpty) {
        recentItems.add(item);
      }
    }
    if (recentItems.isNotEmpty) {
      packages.add(
        CustomStickerPackage(
          name: StickerConstants.virtualPackRecent,
          baseUrl: '',
          stickerList: recentItems
              .asMap()
              .entries
              .map(
                (e) => CustomSticker(
                  index: e.key,
                  name: e.value.stickerId,
                ),
              )
              .toList(),
          menuItem: const CustomSticker(index: 0, name: 'menu@2x.png'),
        ),
      );
    }

    if (_favorites.isNotEmpty) {
      packages.add(
        CustomStickerPackage(
          name: StickerConstants.virtualPackFavorites,
          baseUrl: '',
          stickerList: _favorites
              .asMap()
              .entries
              .map(
                (e) => CustomSticker(
                  index: e.key,
                  name: e.value.stickerId,
                ),
              )
              .toList(),
          menuItem: const CustomSticker(index: 0, name: 'menu@2x.png'),
        ),
      );
    }

    return packages;
  }

  CustomStickerPackage _packToCustom(StickerPack pack) {
    final sorted = List<StickerItem>.from(pack.stickers)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return CustomStickerPackage(
      name: pack.packId,
      baseUrl: pack.iconUrl.isNotEmpty ? pack.iconUrl : '',
      stickerList: sorted
          .asMap()
          .entries
          .map(
            (e) => CustomSticker(
              index: e.key,
              name: e.value.stickerId,
            ),
          )
          .toList(),
      menuItem: CustomSticker(
        index: 0,
        name: pack.packId,
      ),
    );
  }

  void publishTo(CustomStickerPackageData target) {
    target.customStickerPackageList = buildCustomStickerPackages();
  }
}
