import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';

class StickerRecentStore {
  StickerRecentStore._();

  static const String _key = 'sticker_recent_ids_v1';

  static Future<List<String>> loadIds() async {
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
      return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(String stickerId) async {
    final id = stickerId.trim();
    if (id.isEmpty) {
      return;
    }
    final list = await loadIds();
    list.remove(id);
    list.insert(0, id);
    while (list.length > StickerConstants.recentMaxCount) {
      list.removeLast();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
