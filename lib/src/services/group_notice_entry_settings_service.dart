import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

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
  Future<void>? _loading;

  bool get isPinned => _isPinned;
  bool get isMuted => _isMuted;
  int get dismissWatermarkMs => _dismissWatermarkMs;
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPinned = prefs.getBool(_scopedKey(_groupNoticeEntryPinnedKey)) ?? false;
      _isMuted = prefs.getBool(_scopedKey(_groupNoticeEntryMutedKey)) ?? false;
      _dismissWatermarkMs =
          prefs.getInt(_scopedKey(_groupNoticeEntryDismissWatermarkKey)) ?? 0;
      _loaded = true;
      notifyListeners();
    } finally {
      _loading = null;
    }
  }

  Future<void> setPinned(bool value) async {
    await ensureLoaded();
    if (_isPinned == value) {
      return;
    }
    _isPinned = value;
    await _persist();
    notifyListeners();
  }

  Future<void> togglePinned() => setPinned(!_isPinned);

  Future<void> setMuted(bool value) async {
    await ensureLoaded();
    if (_isMuted == value) {
      return;
    }
    _isMuted = value;
    await _persist();
    notifyListeners();
  }

  Future<void> toggleMuted() => setMuted(!_isMuted);

  Future<void> dismissEntry({required int latestNoticeMs}) async {
    await ensureLoaded();
    final watermark = latestNoticeMs > 0
        ? latestNoticeMs
        : DateTime.now().millisecondsSinceEpoch;
    if (_dismissWatermarkMs == watermark) {
      return;
    }
    _dismissWatermarkMs = watermark;
    await _persist();
    notifyListeners();
  }

  void clearSession() {
    _isPinned = false;
    _isMuted = false;
    _dismissWatermarkMs = 0;
    _loaded = false;
    _loading = null;
    notifyListeners();
  }

  String _scopedKey(String base) {
    final userId = ChatIdFormat.rawUserUid(
      serviceLocator<CoreServicesImpl>().loginUserInfo?.userID ?? '',
    );
    if (userId.isEmpty) {
      return base;
    }
    return '${base}_$userId';
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_groupNoticeEntryPinnedKey), _isPinned);
    await prefs.setBool(_scopedKey(_groupNoticeEntryMutedKey), _isMuted);
    await prefs.setInt(
      _scopedKey(_groupNoticeEntryDismissWatermarkKey),
      _dismissWatermarkMs,
    );
  }
}
