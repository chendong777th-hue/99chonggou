import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// 通讯录相关本地缓存：星标好友、最近上线时间（按登录账号隔离）。
class ContactSocialCacheStore {
  ContactSocialCacheStore._();

  static const _starredPrefix = 'starred_friends_cache_v1_';
  static const _presencePrefix = 'presence_last_seen_cache_v1_';
  static const _presenceVisibilityPrefix =
      'presence_last_active_visibility_cache_v1_';

  static String? _invalidatedScope;

  /// IM SDK 未 init 时 [loginInfo] 会抛 LateError，启动阶段需安全读取。
  static String safeLoginUserId() {
    try {
      return TIMUIKitCore.getInstance().loginInfo.userID.trim();
    } catch (_) {
      return '';
    }
  }

  static String accountScope() {
    return accountScopeForUserId(safeLoginUserId());
  }

  /// 按显式 userId 生成 prefs 隔离后缀（注销 purge 时登录态可能已空）。
  static String accountScopeForUserId(String? userId) {
    final raw = (userId ?? '').trim();
    if (raw.isEmpty) {
      return '_guest';
    }
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static void invalidateSession() {
    _invalidatedScope = accountScope();
  }

  static bool consumeScopeInvalidation(String scope) {
    if (_invalidatedScope == null) {
      return false;
    }
    final invalidated = _invalidatedScope == scope;
    _invalidatedScope = null;
    return invalidated;
  }

  static Future<Map<String, DateTime>> readStarredFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_starredPrefix${accountScope()}');
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }
      final out = <String, DateTime>{};
      decoded.forEach((key, value) {
        final id = key.toString().trim();
        if (id.isEmpty) {
          return;
        }
        if (value is String) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) {
            out[id] = parsed.toUtc();
          }
          return;
        }
        if (value is num) {
          out[id] = DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> writeStarredFriends(Map<String, DateTime> map) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, String>{};
    map.forEach((key, value) {
      final id = key.trim();
      if (id.isEmpty) {
        return;
      }
      payload[id] = value.toUtc().toIso8601String();
    });
    await prefs.setString(
      '$_starredPrefix${accountScope()}',
      jsonEncode(payload),
    );
  }

  static Future<void> clearStarredFriends() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_starredPrefix${accountScope()}');
  }

  static Future<Map<String, int>> readPresenceLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_presencePrefix${accountScope()}');
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }
      final out = <String, int>{};
      decoded.forEach((key, value) {
        final id = key.toString().trim();
        if (id.isEmpty) {
          return;
        }
        if (value is num) {
          out[id] = value.toInt();
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> mergePresenceLastSeen(Map<String, int> updates) async {
    if (updates.isEmpty) {
      return;
    }
    final existing = await readPresenceLastSeen();
    existing.addAll(updates);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_presencePrefix${accountScope()}',
      jsonEncode(existing),
    );
  }

  static Future<Map<String, String>> readPresenceVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_presenceVisibilityPrefix${accountScope()}');
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }
      final out = <String, String>{};
      decoded.forEach((key, value) {
        final id = key.toString().trim();
        final visibility = value?.toString().trim() ?? '';
        if (id.isNotEmpty && visibility.isNotEmpty) {
          out[id] = visibility;
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> mergePresenceVisibility(
    Map<String, String> updates,
  ) async {
    if (updates.isEmpty) {
      return;
    }
    final existing = await readPresenceVisibility();
    existing.addAll(updates);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_presenceVisibilityPrefix${accountScope()}',
      jsonEncode(existing),
    );
  }

  static Future<void> clearPresenceLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_presencePrefix${accountScope()}');
  }

  static Future<void> clearPresenceVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_presenceVisibilityPrefix${accountScope()}');
  }

  static Future<void> clearAllForCurrentAccount() async {
    await clearStarredFriends();
    await clearPresenceLastSeen();
    await clearPresenceVisibility();
    invalidateSession();
  }

  /// 注销：按显式 owner 删除通讯录相关 prefs（不依赖当前 loginInfo）。
  static Future<void> clearAllForOwner(String? ownerUserId) async {
    final scope = accountScopeForUserId(ownerUserId);
    if (scope.isEmpty || scope == '_guest') {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_starredPrefix$scope');
    await prefs.remove('$_presencePrefix$scope');
    await prefs.remove('$_presenceVisibilityPrefix$scope');
  }
}
