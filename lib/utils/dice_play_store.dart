import 'package:shared_preferences/shared_preferences.dart';

/// 本机记录「骰子 Face 已播放过动画」的消息键，跨进出会话仍有效。
class DicePlayStore {
  DicePlayStore._();

  static final DicePlayStore instance = DicePlayStore._();

  static const _prefsKey = 'dice_face_played_ids';

  Set<String>? _played;
  Future<void>? _loading;

  Future<void> ensureLoaded() async {
    if (_played != null) {
      return;
    }
    _loading ??= _load();
    await _loading;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? const <String>[];
    _played = list.toSet();
  }

  bool hasPlayed(String key) {
    final k = key.trim();
    if (k.isEmpty) {
      return false;
    }
    return _played?.contains(k) ?? false;
  }

  Future<void> markPlayed(String key) async {
    final k = key.trim();
    if (k.isEmpty) {
      return;
    }
    await ensureLoaded();
    final set = _played!;
    if (!set.add(k)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, set.toList(growable: false));
  }

  /// 主气泡用的稳定键：优先云端 msgID，否则本地 id。
  static String? playKeyForMessage({
    String? msgID,
    Object? localId,
  }) {
    final cloud = msgID?.trim() ?? '';
    if (cloud.isNotEmpty) {
      return cloud;
    }
    if (localId == null) {
      return null;
    }
    final local = localId.toString().trim();
    return local.isEmpty ? null : local;
  }
}
