import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

import 'api_client.dart';

/// 三公游戏 HTTP：经主服务统一代理 `/sangong`，鉴权为主服务 JWT + `X-Tenant-Id`。
class SangongGameHttp {
  SangongGameHttp._();

  static const String tenantHeader = 'X-Tenant-Id';

  /// Dio `Options.extra`：为 true 时不附带 `X-Tenant-Id`（租户列表等）。
  static const String extraSkipTenant = 'sangongSkipTenant';

  static const String _prefsTenantKey = 'sangong_active_tenant_id_v1';

  static Dio? _client;
  static String? _tenantId;
  static bool _tenantHydrated = false;

  /// 当前租户（`tenantId = imGroupGameId`）。
  static final ValueNotifier<String?> tenantIdListenable =
      ValueNotifier<String?>(null);

  static String? get tenantId => _tenantId;

  static bool get hasTenant {
    final id = _tenantId?.trim() ?? '';
    return id.isNotEmpty;
  }

  static bool get hasAuth =>
      ApiClient.isValidJwt(ApiClient.instance.token);

  /// 管理写接口本地前置条件：已登录且已选定租户（特权由服务端实时校验）。
  static bool get canCallAdmin => hasAuth && hasTenant;

  /// 兼容旧调用点；语义等同 [canCallAdmin]。
  @Deprecated('Use canCallAdmin')
  static bool get hasWriteKey => canCallAdmin;

  static String get baseUrl {
    const override = String.fromEnvironment('SANGONG_HTTP_BASE');
    final fromEnv = ApiClient.sanitizeBaseUrl(override);
    if (fromEnv != null) {
      return fromEnv;
    }
    final legacy = ApiClient.sanitizeBaseUrl(
      IMDemoConfig.sangongGameSettingsHttpBase,
    );
    if (legacy != null) {
      return legacy;
    }
    final main = ApiClient.resolveBaseUrl().replaceAll(RegExp(r'/$'), '');
    return '$main/sangong';
  }

  /// 运营与规则读写共用客户端（JWT + 租户头）。
  static Dio get client {
    final d = _client ??= _build();
    final nextBase = baseUrl;
    if (d.options.baseUrl != nextBase) {
      d.options.baseUrl = nextBase;
    }
    return d;
  }

  static Dio get adminClient => client;

  static Dio get publicClient => client;

  static Future<void> hydrateTenant() async {
    if (_tenantHydrated) {
      return;
    }
    _tenantHydrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsTenantKey)?.trim() ?? '';
      if (cached.isNotEmpty && (_tenantId == null || _tenantId!.isEmpty)) {
        _applyTenant(cached, persist: false, notify: true);
      }
    } catch (_) {}
  }

  /// 设置当前租户；空字符串清除。切租户时通知 [tenantIdListenable] 以便 SSE 重连。
  static void setTenantId(String? tenantId, {bool persist = true}) {
    final raw = tenantId?.trim() ?? '';
    final normalized = raw.isEmpty ? '' : ChatIdFormat.normalizeGroupId(raw);
    _applyTenant(normalized, persist: persist, notify: true);
  }

  static void clearTenant({bool persist = true}) {
    _applyTenant('', persist: persist, notify: true);
  }

  static void _applyTenant(
    String normalized, {
    required bool persist,
    required bool notify,
  }) {
    final next = normalized.trim().isEmpty ? null : normalized.trim();
    if (_tenantId == next) {
      return;
    }
    _tenantId = next;
    if (notify) {
      tenantIdListenable.value = next;
    }
    if (persist) {
      unawaited(_persistTenant(next));
    }
  }

  static Future<void> _persistTenant(String? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null || id.isEmpty) {
        await prefs.remove(_prefsTenantKey);
      } else {
        await prefs.setString(_prefsTenantKey, id);
      }
    } catch (_) {}
  }

  static Dio _build() {
    final d = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: 15000,
        receiveTimeout: 30000,
        contentType: 'application/json',
      ),
    );
    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 废弃 X-Settings-Key；改走主服务 JWT。
          options.headers.remove('X-Settings-Key');
          options.headers.remove('x-settings-key');

          final token = ApiClient.instance.token;
          if (ApiClient.isValidJwt(token)) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }

          final skipTenant = options.extra[extraSkipTenant] == true;
          if (skipTenant) {
            options.headers.remove(tenantHeader);
          } else {
            final tenant = _tenantId?.trim() ?? '';
            if (tenant.isNotEmpty) {
              options.headers[tenantHeader] = tenant;
            } else {
              options.headers.remove(tenantHeader);
            }
          }
          handler.next(options);
        },
      ),
    );
    return d;
  }
}
