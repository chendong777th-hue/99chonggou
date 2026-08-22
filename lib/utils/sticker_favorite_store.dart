import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/models/sticker_models.dart';

/// 收藏列表本地缓存：后端 `GET /me/stickers/favorites` 未就绪或返回空时仍可展示。
class StickerFavoriteStore {
  StickerFavoriteStore._();

  static const String _key = 'sticker_favorites_v1';

  static Future<List<FavoriteSticker>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }
      return decoded
          .whereType<Map>()
          .map((e) => FavoriteSticker.fromJson(Map<String, dynamic>.from(e)))
          .where((f) => f.stickerId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<FavoriteSticker> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = favorites
        .map(
          (f) => {
            'stickerId': f.stickerId,
            'thumbUrl': f.thumbUrl,
            'originUrl': f.originUrl,
            'mediaType': f.mediaType,
            if (f.favoritedAt != null)
              'favoritedAt': f.favoritedAt!.toUtc().toIso8601String(),
          },
        )
        .toList();
    await prefs.setString(_key, jsonEncode(payload));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
