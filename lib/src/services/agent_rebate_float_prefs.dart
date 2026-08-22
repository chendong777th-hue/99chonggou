import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 代理查询浮窗的拖拽位置和展开状态。
class AgentRebateFloatPrefs {
  AgentRebateFloatPrefs._();

  static final AgentRebateFloatPrefs instance = AgentRebateFloatPrefs._();

  static const String _leftKey = 'agent_rebate_float_left_v1';
  static const String _topKey = 'agent_rebate_float_top_v1';
  static const String _expandedKey = 'agent_rebate_float_expanded_v1';

  Future<Offset?> readOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final left = prefs.getDouble(_leftKey);
    final top = prefs.getDouble(_topKey);
    if (left == null || top == null || !left.isFinite || !top.isFinite) {
      return null;
    }
    return Offset(left, top);
  }

  Future<void> writeOffset(Offset offset) async {
    if (!offset.dx.isFinite || !offset.dy.isFinite) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_leftKey, offset.dx);
    await prefs.setDouble(_topKey, offset.dy);
  }

  Future<bool> readExpanded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_expandedKey) ?? false;
  }

  Future<void> writeExpanded(bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expandedKey, expanded);
  }
}
