import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

const String _groupNoticeEntryPinnedKey = 'groupNoticeEntryPinned';
const String _groupNoticeEntryMutedKey = 'groupNoticeEntryMuted';
const String _groupNoticeEntryDismissWatermarkKey =
    'groupNoticeEntryDismissWatermarkMs';

/// 会话列表「群通知」入口的置顶 / 免打扰 / 删除（隐藏）状态。
class GroupNoticeEntrySettingsService extends ChangeNotifier {
  GroupNoticeEntrySettingsService._();

  static final GroupNoticeEntrySettingsService instance =
      GroupNoticeEntrySettingsService._();

  bool _isPinned = false;
  bool _isMuted = false;
  int _dismissWatermarkMs = 0;
  bool _loaded = false;
  String _loadedOwner = '';
  final Map<String, Future<void>> _loadingByOwner = <String, Future<void>>{};

  bool get isPinned => _isPinned;
  bool get isMuted => _isMuted;
  int get dismissWatermarkMs => _dismissWatermarkMs;
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) {
      return Future<void>.value();
    }
    if (_loaded && _loadedOwner == identity.ownerUserId) {
      return Future<void>.value();
    }
    return _loadingByOwner[identity.ownerUserId] ??= _load(identity);
  }

  Future<void> _load(SessionIdentity identity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!SessionIdentityService.instance.isCurrent(identity)) return;
      _isPinned = prefs.getBool(_scopedKeyForOwner(
              _groupNoticeEntryPinnedKey, identity.ownerUserId)) ??
          false;
      _isMuted = prefs.getBool(_scopedKeyForOwner(
              _groupNoticeEntryMutedKey, identity.ownerUserId)) ??
          false;
      _dismissWatermarkMs = prefs.getInt(_scopedKeyForOwner(
            _groupNoticeEntryDismissWatermarkKey,
            identity.ownerUserId,
          )) ??
          0;
      _loaded = true;
      _loadedOwner = identity.ownerUserId;
      notifyListeners();
    } finally {
      _loadingByOwner.remove(identity.ownerUserId);
    }
  }

  Future<void> setPinned(bool value) async {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return;
    await ensureLoaded();
    if (!SessionIdentityService.instance.isCurrent(identity) ||
        _loadedOwner != identity.ownerUserId) return;
    if (_isPinned == value) {
      return;
    }
    _isPinned = value;
    await _persist(identity);
    if (!SessionIdentityService.instance.isCurrent(identity)) return;
    notifyListeners();
  }

  Future<void> togglePinned() => setPinned(!_isPinned);

  Future<void> setMuted(bool value) async {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return;
    await ensureLoaded();
    if (!SessionIdentityService.instance.isCurrent(identity) ||
        _loadedOwner != identity.ownerUserId) return;
    if (_isMuted == value) {
      return;
    }
    _isMuted = value;
    await _persist(identity);
    if (!SessionIdentityService.instance.isCurrent(identity)) return;
    notifyListeners();
  }

  Future<void> toggleMuted() => setMuted(!_isMuted);

  Future<void> dismissEntry({required int latestNoticeMs}) async {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return;
    await ensureLoaded();
    if (!SessionIdentityService.instance.isCurrent(identity) ||
        _loadedOwner != identity.ownerUserId) return;
    final watermark = latestNoticeMs > 0
        ? latestNoticeMs
        : DateTime.now().millisecondsSinceEpoch;
    if (_dismissWatermarkMs == watermark) {
      return;
    }
    _dismissWatermarkMs = watermark;
    await _persist(identity);
    if (!SessionIdentityService.instance.isCurrent(identity)) return;
    notifyListeners();
  }

  void clearSession() {
    _isPinned = false;
    _isMuted = false;
    _dismissWatermarkMs = 0;
    _loaded = false;
    _loadedOwner = '';
    _loadingByOwner.clear();
    notifyListeners();
  }

  Future<void> clearForOwner(String? ownerUserId) async {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    clearSession();
    if (owner.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedKeyForOwner(_groupNoticeEntryPinnedKey, owner));
    await prefs.remove(_scopedKeyForOwner(_groupNoticeEntryMutedKey, owner));
    await prefs.remove(
      _scopedKeyForOwner(_groupNoticeEntryDismissWatermarkKey, owner),
    );
  }

  String _scopedKeyForOwner(String base, String userId) {
    final owner = ChatIdFormat.rawUserUid(userId);
    if (owner.isEmpty) {
      return base;
    }
    return '${base}_$owner';
  }

  Future<void> _persist(SessionIdentity identity) async {
    if (!SessionIdentityService.instance.isCurrent(identity) ||
        _loadedOwner != identity.ownerUserId) return;
    final prefs = await SharedPreferences.getInstance();
    if (!SessionIdentityService.instance.isCurrent(identity)) return;
    await prefs.setBool(
      _scopedKeyForOwner(_groupNoticeEntryPinnedKey, identity.ownerUserId),
      _isPinned,
    );
    await prefs.setBool(
      _scopedKeyForOwner(_groupNoticeEntryMutedKey, identity.ownerUserId),
      _isMuted,
    );
    await prefs.setInt(
      _scopedKeyForOwner(
        _groupNoticeEntryDismissWatermarkKey,
        identity.ownerUserId,
      ),
      _dismissWatermarkMs,
    );
  }
}
