import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/app_gallery_picker.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_background_file_access.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_chat_background_registry.dart';

class ChatBackgroundService {
  ChatBackgroundService._();

  static final ChatBackgroundService instance = ChatBackgroundService._();

  static const String _prefsKeyPrefix = 'chat_background_map_v1_';
  static const String globalBackgroundConversationId = 'global_chat_background';
  static const String filePrefix = 'file:';
  static const String assetPrefix = 'asset:';
  static const String colorPrefix = 'color:';

  String? _activeAccountScope;

  /// 登出或切换账号时清空内存缓存，避免串号。
  void clearSessionState() {
    _activeAccountScope = null;
    TIMUIKitChatBackgroundRegistry.clearAll();
  }

  /// 注销：删除该账号聊天背景 prefs（及本地背景文件目录）。
  Future<void> clearForOwner(String? ownerUserId) async {
    final scope = _sanitizeAccountScope(ownerUserId?.trim() ?? '');
    if (scope.isEmpty || scope == '_guest') {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(scope));
    if (_activeAccountScope == scope) {
      clearSessionState();
    }
    if (kIsWeb) {
      return;
    }
    try {
      final supportDir = await getApplicationSupportDirectory();
      final targetDirPath = '${supportDir.path}/chat_backgrounds/$scope';
      await chatBackgroundDeleteDirIfExists(targetDirPath);
    } catch (_) {}
  }

  /// 平台公众号会话不使用全局/单聊自定义背景。
  static bool isOfficialAccountConversationId(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return false;
    }
    if (PlatformOfficialAccountService.isPlatformOfficialAccount(id)) {
      return true;
    }
    if (id.startsWith('c2c_')) {
      final peer = id.substring(4);
      return PlatformOfficialAccountService.isPlatformOfficialAccount(peer);
    }
    return false;
  }

  String _prefsKey(String accountScope) => '$_prefsKeyPrefix$accountScope';

  String _sanitizeAccountScope(String userId) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      return '_guest';
    }
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  String _resolveAccountScopeSync() {
    final userId = ContactSocialCacheStore.safeLoginUserId();
    return _sanitizeAccountScope(userId);
  }

  bool _isScopeCurrent(String scope) =>
      scope != '_guest' && _resolveAccountScopeSync() == scope;

  Future<String> _ensureAccountScope() async {
    final scope = _resolveAccountScopeSync();
    if (_activeAccountScope != null && _activeAccountScope != scope) {
      TIMUIKitChatBackgroundRegistry.clearAll();
    }
    _activeAccountScope = scope;
    return scope;
  }

  Future<String> _backgroundFilesDir(String scope) async {
    if (!_isScopeCurrent(scope)) return '';
    final supportDir = await getApplicationSupportDirectory();
    if (!_isScopeCurrent(scope)) return '';
    final targetDirPath = '${supportDir.path}/chat_backgrounds/$scope';
    await chatBackgroundEnsureDir(targetDirPath);
    return targetDirPath;
  }

  Future<Map<String, String>> _readAll({String? expectedScope}) async {
    final scope = expectedScope ?? await _ensureAccountScope();
    if (!_isScopeCurrent(scope)) return <String, String>{};
    final prefs = await SharedPreferences.getInstance();
    if (!_isScopeCurrent(scope)) return <String, String>{};
    final raw = prefs.getString(_prefsKey(scope));
    if (raw == null || raw.isEmpty) {
      return <String, String>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(
            key.toString(),
            value?.toString() ?? '',
          ),
        );
      }
    } catch (_) {}
    return <String, String>{};
  }

  Future<void> _writeAll(
    Map<String, String> map, {
    required String expectedScope,
  }) async {
    if (!_isScopeCurrent(expectedScope)) return;
    final prefs = await SharedPreferences.getInstance();
    if (!_isScopeCurrent(expectedScope)) return;
    await prefs.setString(_prefsKey(expectedScope), jsonEncode(map));
  }

  Future<String?> getBackgroundPath(String conversationId) async {
    final scope = await _ensureAccountScope();
    return _getBackgroundPath(conversationId, scope: scope);
  }

  Future<String?> _getBackgroundPath(
    String conversationId, {
    required String scope,
  }) async {
    if (!_isScopeCurrent(scope)) return null;
    final id = conversationId.trim();
    if (id.isEmpty) return null;
    if (isOfficialAccountConversationId(id)) {
      TIMUIKitChatBackgroundRegistry.clearPath(id);
      return null;
    }
    final map = await _readAll(expectedScope: scope);
    if (!_isScopeCurrent(scope)) return null;
    final path = map[id]?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    if (path.startsWith(colorPrefix) || path.startsWith(assetPrefix)) {
      TIMUIKitChatBackgroundRegistry.setPath(id, path);
      return path;
    }
    final rawPath =
        path.startsWith(filePrefix) ? path.substring(filePrefix.length) : path;
    if (kIsWeb) {
      final normalized =
          rawPath.startsWith(filePrefix) ? rawPath : '$filePrefix$rawPath';
      TIMUIKitChatBackgroundRegistry.setPath(id, normalized);
      return normalized;
    }
    final exists = await chatBackgroundFileExists(rawPath);
    if (!_isScopeCurrent(scope)) return null;
    if (!exists) {
      map.remove(id);
      await _writeAll(map, expectedScope: scope);
      TIMUIKitChatBackgroundRegistry.clearPath(id);
      return null;
    }
    final normalized = '$filePrefix$rawPath';
    TIMUIKitChatBackgroundRegistry.setPath(id, normalized);
    return normalized;
  }

  Future<String?> getBackgroundPathWithGlobalFallback(
      String conversationId) async {
    final scope = await _ensureAccountScope();
    if (!_isScopeCurrent(scope)) return null;
    final id = conversationId.trim();
    if (id.isEmpty) return null;
    if (isOfficialAccountConversationId(id)) {
      TIMUIKitChatBackgroundRegistry.clearPath(id);
      return null;
    }

    final directPath = await _getBackgroundPath(id, scope: scope);
    if (directPath != null && directPath.isNotEmpty) {
      return directPath;
    }
    if (id == globalBackgroundConversationId) {
      TIMUIKitChatBackgroundRegistry.clearPath(id);
      return null;
    }

    final globalPath = await _getBackgroundPath(
      globalBackgroundConversationId,
      scope: scope,
    );
    if (!_isScopeCurrent(scope)) return null;
    if (globalPath == null || globalPath.isEmpty) {
      TIMUIKitChatBackgroundRegistry.clearPath(id);
      return null;
    }

    TIMUIKitChatBackgroundRegistry.setPath(id, globalPath);
    return globalPath;
  }

  Future<void> clearBackground(String conversationId) async {
    final scope = await _ensureAccountScope();
    if (!_isScopeCurrent(scope)) return;
    final id = conversationId.trim();
    if (id.isEmpty) return;
    final map = await _readAll(expectedScope: scope);
    final oldPath = map.remove(id);
    await _writeAll(map, expectedScope: scope);
    if (!_isScopeCurrent(scope)) return;
    TIMUIKitChatBackgroundRegistry.clearPath(id);
    if (!kIsWeb &&
        oldPath != null &&
        oldPath.isNotEmpty &&
        oldPath.startsWith(filePrefix)) {
      try {
        await chatBackgroundDeleteFile(oldPath.substring(filePrefix.length));
      } catch (_) {}
    }
  }

  Future<String?> saveBackgroundFromGallery(
      BuildContext context, String conversationId) async {
    final scope = await _ensureAccountScope();
    if (!_isScopeCurrent(scope)) return null;
    if (!context.mounted) return null;
    if (kIsWeb) {
      return null;
    }
    final id = conversationId.trim();
    if (id.isEmpty) return null;

    final allowed = await PermissionGuard.photosForPick(context);
    if (!allowed || !context.mounted || !_isScopeCurrent(scope)) return null;

    final picked = await AppGalleryPicker.pickSingleImage(context);
    final sourcePath = picked?.path;
    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }

    final targetDirPath = await _backgroundFilesDir(scope);
    if (targetDirPath.isEmpty || !_isScopeCurrent(scope)) return null;

    final extension = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.jpg';
    final sanitizedId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final targetPath =
        '$targetDirPath/$sanitizedId${DateTime.now().millisecondsSinceEpoch}$extension';

    final copiedPath = await chatBackgroundCopyFile(sourcePath, targetPath);
    if (!_isScopeCurrent(scope)) return null;
    final map = await _readAll(expectedScope: scope);
    final oldPath = map[id];
    map[id] = '$filePrefix$copiedPath';
    await _writeAll(map, expectedScope: scope);
    if (!_isScopeCurrent(scope)) return null;
    TIMUIKitChatBackgroundRegistry.setPath(id, '$filePrefix$copiedPath');

    if (oldPath != null &&
        oldPath.isNotEmpty &&
        oldPath.startsWith(filePrefix) &&
        oldPath.substring(filePrefix.length) != copiedPath) {
      try {
        await chatBackgroundDeleteFile(oldPath.substring(filePrefix.length));
      } catch (_) {}
    }

    return '$filePrefix$copiedPath';
  }

  Future<void> saveColorBackground(
    String conversationId,
    Color color,
  ) async {
    final scope = await _ensureAccountScope();
    if (!_isScopeCurrent(scope)) return;
    final id = conversationId.trim();
    if (id.isEmpty) return;
    final value = '$colorPrefix${color.toARGB32().toRadixString(16)}';
    final map = await _readAll(expectedScope: scope);
    final oldPath = map[id];
    map[id] = value;
    await _writeAll(map, expectedScope: scope);
    if (!_isScopeCurrent(scope)) return;
    TIMUIKitChatBackgroundRegistry.setPath(id, value);
    if (!kIsWeb &&
        oldPath != null &&
        oldPath.isNotEmpty &&
        oldPath.startsWith(filePrefix)) {
      try {
        await chatBackgroundDeleteFile(oldPath.substring(filePrefix.length));
      } catch (_) {}
    }
  }

  Future<void> saveAssetBackground(
    String conversationId,
    String assetPath,
  ) async {
    final scope = await _ensureAccountScope();
    if (!_isScopeCurrent(scope)) return;
    final id = conversationId.trim();
    if (id.isEmpty) return;
    final value = '$assetPrefix$assetPath';
    final map = await _readAll(expectedScope: scope);
    final oldPath = map[id];
    map[id] = value;
    await _writeAll(map, expectedScope: scope);
    if (!_isScopeCurrent(scope)) return;
    TIMUIKitChatBackgroundRegistry.setPath(id, value);
    if (!kIsWeb &&
        oldPath != null &&
        oldPath.isNotEmpty &&
        oldPath.startsWith(filePrefix)) {
      try {
        await chatBackgroundDeleteFile(oldPath.substring(filePrefix.length));
      } catch (_) {}
    }
  }
}
