import 'package:flutter/foundation.dart';

/// 会话聊天背景路径内存缓存；变更时通知聊天页重建。
class TIMUIKitChatBackgroundRegistry extends ChangeNotifier {
  TIMUIKitChatBackgroundRegistry._();

  static final TIMUIKitChatBackgroundRegistry instance =
      TIMUIKitChatBackgroundRegistry._();

  final Map<String, String> _paths = <String, String>{};

  static String? getPath(String conversationId) {
    return instance._getPath(conversationId);
  }

  String? _getPath(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return null;
    final path = _paths[id]?.trim();
    if (path == null || path.isEmpty) return null;
    return path;
  }

  static void setPath(String conversationId, String path) {
    instance._setPath(conversationId, path);
  }

  void _setPath(String conversationId, String path) {
    final id = conversationId.trim();
    if (id.isEmpty) return;
    final normalized = path.trim();
    if (normalized.isEmpty) {
      if (_paths.remove(id) != null) {
        notifyListeners();
      }
      return;
    }
    final previous = _paths[id];
    _paths[id] = normalized;
    if (previous != normalized) {
      notifyListeners();
    }
  }

  static void clearPath(String conversationId) {
    instance._clearPath(conversationId);
  }

  void _clearPath(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return;
    if (_paths.remove(id) != null) {
      notifyListeners();
    }
  }

  static void clearAll() {
    instance._clearAll();
  }

  void _clearAll() {
    if (_paths.isEmpty) return;
    _paths.clear();
    notifyListeners();
  }
}
