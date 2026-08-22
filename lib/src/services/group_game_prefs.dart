import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 群游戏浮窗入口的本地显示偏好（按群维度）与拖拽位置 / 展开态（全局）。
class GroupGamePrefs {
  GroupGamePrefs._();

  static final GroupGamePrefs instance = GroupGamePrefs._();

  static const String _floatVisiblePrefix = 'group_game_float_visible_';
  static const String _floatLeftKey = 'group_game_float_left_v1';
  static const String _floatTopKey = 'group_game_float_top_v1';
  static const String _floatExpandedKey = 'group_game_float_expanded_v1';

  String _key(String groupId) => '$_floatVisiblePrefix${groupId.trim()}';

  Future<bool> isFloatVisible(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(id)) ?? true;
  }

  Future<void> setFloatVisible(String groupId, bool visible) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(id), visible);
  }

  /// 读取浮窗左上角坐标；从未拖动过则返回 `null`。
  Future<Offset?> readFloatOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final left = prefs.getDouble(_floatLeftKey);
    final top = prefs.getDouble(_floatTopKey);
    if (left == null || top == null) {
      return null;
    }
    if (!left.isFinite || !top.isFinite) {
      return null;
    }
    return Offset(left, top);
  }

  Future<void> writeFloatOffset(Offset offset) async {
    if (!offset.dx.isFinite || !offset.dy.isFinite) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_floatLeftKey, offset.dx);
    await prefs.setDouble(_floatTopKey, offset.dy);
  }

  /// 浮窗是否展开；从未设置过则默认收起。
  Future<bool> readFloatExpanded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_floatExpandedKey) ?? false;
  }

  Future<void> writeFloatExpanded(bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_floatExpandedKey, expanded);
  }
}
