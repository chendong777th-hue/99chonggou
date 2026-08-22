import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_settings_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 朋友圈本地偏好（封面、可见范围等），后端 API 就绪前先用本地存储。
class MomentsLocalPrefs {
  MomentsLocalPrefs._();

  static const _coverPathKey = 'moments_cover_path_v1_';
  static const _visibleRangeKey = 'moments_visible_range_v1_';
  static const _blockedViewerIdsKey = 'moments_blocked_viewer_ids_v1_';
  static const _hiddenAuthorIdsKey = 'moments_hidden_author_ids_v1_';

  static String _scopedKey(String prefix) =>
      '$prefix${MomentsStore.accountScope()}';

  /// 注销：删除该账号朋友圈本地偏好。
  static Future<void> clearForOwner(String? ownerUserId) async {
    final scope = MomentsStore.accountScopeForUserId(ownerUserId);
    if (scope.isEmpty || scope == '_guest') {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_coverPathKey$scope');
    await prefs.remove('$_visibleRangeKey$scope');
    await prefs.remove('$_blockedViewerIdsKey$scope');
    await prefs.remove('$_hiddenAuthorIdsKey$scope');
  }

  static Future<String?> loadCoverPath() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scopedKey(_coverPathKey))?.trim() ?? '';
    return raw.isEmpty ? null : raw;
  }

  static Future<void> saveCoverPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey(_coverPathKey);
    final trimmed = path?.trim() ?? '';
    if (trimmed.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, trimmed);
  }

  /// 本地存储用 `0` 表示「全部」；未配置时返回 `null`。
  static const int visibleRangeAll = 0;

  static Future<bool> hasVisibleRangeConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_scopedKey(_visibleRangeKey));
  }

  static Future<int?> loadVisibleRangeDays() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey(_visibleRangeKey);
    if (!prefs.containsKey(key)) {
      return null;
    }
    return prefs.getInt(key) ?? visibleRangeAll;
  }

  static Future<void> saveVisibleRangeDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scopedKey(_visibleRangeKey), days);
  }

  static Future<List<String>> loadBlockedViewerIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_scopedKey(_blockedViewerIdsKey)) ?? const [];
  }

  static Future<void> saveBlockedViewerIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    await prefs.setStringList(_scopedKey(_blockedViewerIdsKey), normalized);
  }

  static Future<List<String>> loadHiddenAuthorIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_scopedKey(_hiddenAuthorIdsKey)) ?? const [];
  }

  static Future<void> saveHiddenAuthorIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    await prefs.setStringList(_scopedKey(_hiddenAuthorIdsKey), normalized);
  }

  static Future<void> applySettings(MomentsSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final coverKey = _scopedKey(_coverPathKey);
    final cover = settings.coverUrl?.trim() ?? '';
    if (cover.isEmpty) {
      await prefs.remove(coverKey);
    } else {
      await prefs.setString(coverKey, cover);
    }
    await prefs.setInt(_scopedKey(_visibleRangeKey), settings.visibleRangeDays);
    await saveBlockedViewerIds(settings.blockedViewerIds);
    await saveHiddenAuthorIds(settings.hiddenAuthorIds);
  }

  static Future<MomentsSettings> readCachedSettings() async {
    final cover = await loadCoverPath();
    final visibleRange = await loadVisibleRangeDays();
    return MomentsSettings(
      coverUrl: cover,
      visibleRangeDays: visibleRange ?? visibleRangeAll,
      blockedViewerIds: await loadBlockedViewerIds(),
      hiddenAuthorIds: await loadHiddenAuthorIds(),
    );
  }

  static String _normalizeUserId(String userId) =>
      ChatIdFormat.rawUserUid(userId.trim());

  static Future<bool> isBlockedViewer(String userId) async {
    final id = _normalizeUserId(userId);
    if (id.isEmpty) return false;
    final ids = await loadBlockedViewerIds();
    return ids.any((item) => _normalizeUserId(item) == id);
  }

  static Future<bool> isHiddenAuthor(String userId) async {
    final id = _normalizeUserId(userId);
    if (id.isEmpty) return false;
    final ids = await loadHiddenAuthorIds();
    return ids.any((item) => _normalizeUserId(item) == id);
  }

  static Future<bool> setBlockedViewer(String userId, bool blocked) async {
    final id = _normalizeUserId(userId);
    if (id.isEmpty) return false;
    try {
      final ids = (await loadBlockedViewerIds())
          .map(_normalizeUserId)
          .where((item) => item.isNotEmpty)
          .toSet();
      if (blocked) {
        ids.add(id);
      } else {
        ids.remove(id);
      }
      await saveBlockedViewerIds(ids.toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setHiddenAuthor(String userId, bool hidden) async {
    final id = _normalizeUserId(userId);
    if (id.isEmpty) return false;
    try {
      final ids = (await loadHiddenAuthorIds())
          .map(_normalizeUserId)
          .where((item) => item.isNotEmpty)
          .toSet();
      if (hidden) {
        ids.add(id);
      } else {
        ids.remove(id);
      }
      await saveHiddenAuthorIds(ids.toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  static String visibleRangeLabel(int? days) {
    switch (days) {
      case visibleRangeAll:
        return '全部';
      case 3:
        return '最近三天';
      case 90:
        return '最近三个月';
      case 180:
        return '最近半年';
      case 365:
        return '最近一年';
      default:
        return '全部';
    }
  }

  /// 个人页向本人展示的可见范围说明。
  static String visibleRangeFriendHint(int days) {
    switch (days) {
      case visibleRangeAll:
        return '仅对朋友展示全部内容';
      case 3:
        return '仅对朋友展示最近三天的内容';
      case 90:
        return '仅对朋友展示最近三个月的内容';
      case 180:
        return '仅对朋友展示最近半年的内容';
      case 365:
        return '仅对朋友展示最近一年的内容';
      default:
        return '仅对朋友展示全部内容';
    }
  }
}
