import 'package:tencent_cloud_chat_demo/src/api/moments_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_settings_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_cover_cache.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_local_prefs.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

class MomentsSettingsService {
  MomentsSettingsService._();

  static final MomentsSettingsService instance = MomentsSettingsService._();

  MomentsSettings? _memoryCache;

  MomentsSettings? get cachedSettings => _memoryCache;

  Future<MomentsSettings> hydrateFromLocal() async {
    _memoryCache ??= await _readCachedSettings();
    MomentsCoverCache.prefetch(_memoryCache?.coverUrl);
    return _memoryCache!;
  }

  Future<MomentsSettings> loadSettings({bool forceRefresh = false}) async {
    if (_memoryCache == null) {
      await hydrateFromLocal();
    }
    if (!forceRefresh && _memoryCache != null) {
      MomentsCoverCache.prefetch(_memoryCache!.coverUrl);
      return _memoryCache!;
    }
    try {
      final remote = await MomentsApi.instance.fetchSettings();
      await _cacheSettings(remote);
      _memoryCache = remote;
      MomentsCoverCache.prefetch(remote.coverUrl);
      return remote;
    } catch (_) {
      final cached = _memoryCache ?? await _readCachedSettings();
      _memoryCache = cached;
      MomentsCoverCache.prefetch(cached.coverUrl);
      return cached;
    }
  }

  Future<MomentsSettings> updateSettings(MomentsSettingsPatch patch) async {
    final remote = await MomentsApi.instance.updateSettings(patch);
    await _cacheSettings(remote);
    _memoryCache = remote;
    MomentsCoverCache.prefetch(remote.coverUrl);
    return remote;
  }

  Future<int?> loadVisibleRangeDays() async {
    final settings = await loadSettings();
    return settings.visibleRangeDays;
  }

  Future<String?> loadCoverUrl() async {
    final settings = await loadSettings();
    return settings.coverUrl;
  }

  Future<List<String>> loadBlockedViewerIds() async {
    final settings = await loadSettings();
    return settings.blockedViewerIds;
  }

  Future<List<String>> loadHiddenAuthorIds() async {
    final settings = await loadSettings();
    return settings.hiddenAuthorIds;
  }

  Future<void> saveVisibleRangeDays(int days) async {
    await updateSettings(MomentsSettingsPatch(visibleRangeDays: days));
  }

  Future<void> saveBlockedViewerIds(List<String> ids) async {
    await updateSettings(
      MomentsSettingsPatch(
        blockedViewerIds: _normalizeIds(ids),
      ),
    );
  }

  Future<void> saveHiddenAuthorIds(List<String> ids) async {
    await updateSettings(
      MomentsSettingsPatch(
        hiddenAuthorIds: _normalizeIds(ids),
      ),
    );
  }

  Future<bool> isBlockedViewer(String userId) async {
    final id = _normalizeUserId(userId);
    if (id.isEmpty) return false;
    final ids = await loadBlockedViewerIds();
    return ids.any((item) => _normalizeUserId(item) == id);
  }

  Future<bool> isHiddenAuthor(String userId) async {
    final id = _normalizeUserId(userId);
    if (id.isEmpty) return false;
    final ids = await loadHiddenAuthorIds();
    return ids.any((item) => _normalizeUserId(item) == id);
  }

  Future<bool> setBlockedViewer(String userId, bool blocked) async {
    final id = _normalizeUserId(userId);
    if (id.isEmpty) return false;
    try {
      final current = await loadSettings();
      final ids = current.blockedViewerIds.map(_normalizeUserId).toSet();
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

  Future<bool> setHiddenAuthor(String userId, bool hidden) async {
    final id = _normalizeUserId(userId);
    if (id.isEmpty) return false;
    try {
      final current = await loadSettings();
      final ids = current.hiddenAuthorIds.map(_normalizeUserId).toSet();
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

  Future<String?> uploadAndSaveCover(String localPath) async {
    final coverUrl = await MomentsApi.instance.uploadCover(localPath);
    await updateSettings(MomentsSettingsPatch(coverUrl: coverUrl));
    MomentsCoverCache.prefetch(coverUrl);
    return coverUrl;
  }

  void clearMemoryCache() {
    _memoryCache = null;
    MomentsCoverCache.reset();
  }

  Future<void> _cacheSettings(MomentsSettings settings) async {
    await MomentsLocalPrefs.applySettings(settings);
  }

  Future<MomentsSettings> _readCachedSettings() async {
    return MomentsLocalPrefs.readCachedSettings();
  }

  String _normalizeUserId(String userId) =>
      ChatIdFormat.rawUserUid(userId.trim());

  List<String> _normalizeIds(List<String> ids) {
    return ids
        .map(_normalizeUserId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }
}
