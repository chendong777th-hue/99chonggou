// ignore_for_file: avoid_print

import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, kReleaseMode, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_http.dart';
import 'package:tencent_cloud_chat_demo/src/utils/client_device_info.dart';
import 'package:tencent_cloud_chat_demo/src/utils/dio_factory.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();
  static Future<void> Function()? onAuthExpired;

  /// 节点链路成功/传输失败回调（由 ApiNodeService 在 hydrate 时注入）。
  static void Function()? onTransportSuccess;
  static void Function()? onTransportFailure;

  bool _handlingAuthExpired = false;
  bool _suppressAuthExpired = false;
  bool _logoutInProgress = false;

  static const String _tokenKey = 'auth_token';
  static const String _tokenSecureKey = 'auth_token_secure';
  static const String _authUserIdSecureKey = 'auth_user_id_secure';
  static const String _deviceIdKey = 'device_id';

  /// 节点切换等运行时覆盖；优先于编译期默认值。
  static String? _runtimeBaseUrlOverride;

  static String resolveBaseUrl() {
    final runtime = sanitizeBaseUrl(_runtimeBaseUrlOverride);
    if (runtime != null) {
      return runtime;
    }

    final configured = sanitizeBaseUrl(IMDemoConfig.smsLoginHttpBase) ??
        IMDemoConfig.smsLoginHttpBase;

    const fromEnv = String.fromEnvironment('API_BASE_URL');
    final sanitizedEnv = sanitizeBaseUrl(fromEnv);

    // Web:
    // - 显式 --dart-define=API_BASE_URL 始终优先
    // - 本地 flutter run（非 release）：走线上主服务，避免打到 localhost
    // - 打包 release：同源 Uri.base.origin（部署域即后端网关）
    if (kIsWeb) {
      if (sanitizedEnv != null) {
        return sanitizedEnv;
      }
      if (!kReleaseMode) {
        return configured;
      }
      return Uri.base.origin.replaceAll(RegExp(r'/$'), '');
    }

    // Native/desktop: prefer non-loopback API_BASE_URL over stale local
    // --dart-define=API_BASE_URL=http://127.0.0.1:8081 from local dev runs.
    if (sanitizedEnv != null && !_isLoopbackBaseUrl(sanitizedEnv)) {
      return sanitizedEnv;
    }
    return configured;
  }

  /// 节点切换后更新 Dio baseUrl（须在 [bootstrap] 前/后都可调用）。
  static void applyRuntimeBaseUrl(String url) {
    final sanitized = sanitizeBaseUrl(url);
    if (sanitized == null) {
      return;
    }
    _runtimeBaseUrlOverride = sanitized;
    // dio 可能尚未首次访问；已构建则立刻改 options。
    try {
      instance.dio.options.baseUrl = sanitized;
    } catch (_) {}
  }

  static bool _isLoopbackBaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    final host = uri.host.trim().toLowerCase();
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == '::1';
  }

  static String? sanitizeBaseUrl(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null ||
        (scheme != 'https' && scheme != 'http') ||
        uri.host.trim().isEmpty) {
      return null;
    }
    return uri.toString().replaceAll(RegExp(r'/$'), '');
  }

  late final Dio dio = _build();

  String? _token;
  String? _authenticatedUserId;
  String? _deviceId;
  String? _clientVersion;
  String? _clientPlatform;
  Future<void> _tokenMutationTail = Future<void>.value();

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Dio _build() {
    final baseUrl = resolveBaseUrl();
    if (kIsWeb && _verboseLog) {
      print('API_LOG web baseUrl: $baseUrl');
    }
    final d = createAppDio(BaseOptions(
      baseUrl: baseUrl,
      // 生活缴费/远程接口偶发握手慢，10s 过短易误报 connectTimeout
      connectTimeout: 30000,
      receiveTimeout: 30000,
      contentType: 'application/json',
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = _requestPath(options);
        if (_isPublicPath(path)) {
          options.headers.remove('Authorization');
        } else {
          final token = _token;
          if (token != null && isValidJwt(token)) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }
        }
        final webPublicRequest = kIsWeb && _isPublicPath(path);
        if (webPublicRequest) {
          options.headers.remove('X-Client-Version');
          options.headers.remove('X-Client-Platform');
        } else {
          if (_clientVersion != null) {
            options.headers['X-Client-Version'] = _clientVersion;
          }
          final platform = resolveClientPlatformHeader(
            path: path,
            clientPlatform: _clientPlatform,
          );
          if (platform != null) {
            options.headers['X-Client-Platform'] = platform;
          }
        }
        // 代理反水：/me/agent/**、/me/rebate/** 自动带当前群 X-Group-Id。
        _applyAgentRebateGroupHeader(options, path);
        _logRequest(options);
        handler.next(options);
      },
      onResponse: (response, handler) {
        // 有正常响应说明当前节点链路可用，清零失败计数。
        onTransportSuccess?.call();
        _logResponse(response);
        handler.next(response);
      },
      onError: (error, handler) async {
        _logRequestError(error);
        if (_isNodeTransportFailure(error)) {
          onTransportFailure?.call();
        } else {
          // 业务错误（有响应）也说明节点可达。
          if (error.response != null) {
            onTransportSuccess?.call();
          }
        }
        if (_shouldNotifyAuthExpired(error)) {
          _logAuthExpiredTrigger(error);
          await _notifyAuthExpired();
        }
        handler.next(error);
      },
    ));
    return d;
  }

  /// 节点传输失败：无响应（超时/断连）或网关类 5xx。
  static bool _isNodeTransportFailure(DioError error) {
    if (error.response == null) {
      return true;
    }
    final code = error.response!.statusCode ?? 0;
    return code == 502 || code == 503 || code == 504;
  }

  bool _shouldNotifyAuthExpired(DioError error) {
    if (_logoutInProgress) {
      return false;
    }
    final status = error.response?.statusCode;
    if (status == null || _isPublicPath(error.requestOptions.path)) {
      return false;
    }

    if (!_requestUsedCurrentToken(error)) {
      return false;
    }

    if (_isExplicitAuthError(error)) {
      return true;
    }

    // Wallet and other fund-operation APIs can return 401/403 for business
    // failures such as an incorrect payment PIN. A bare 401/403 from these
    // paths must stay on the current page and let the caller show the wallet
    // error, otherwise a wrong pay password logs the user out.
    if (_isWalletPath(error.requestOptions.path)) {
      return false;
    }

    if (status == 401) {
      return !_isBusinessAuthError(error);
    }
    return false;
  }

  bool _requestUsedCurrentToken(DioError error) {
    final currentToken = _token;
    if (!isValidJwt(currentToken)) {
      return false;
    }

    final headerValue = error.requestOptions.headers['Authorization'] ??
        error.requestOptions.headers['authorization'];
    if (headerValue == null) {
      return false;
    }

    final values = headerValue is Iterable
        ? headerValue.map((e) => e.toString()).join(',')
        : headerValue.toString();
    final auth = values.trim();
    if (auth.isEmpty) {
      return false;
    }

    return auth == 'Bearer $currentToken';
  }

  bool _isExplicitAuthError(DioError error) {
    return isExplicitSessionExpiryError(error);
  }

  /// Shared by foreground recovery and the request interceptor.
  static bool isExplicitSessionExpiryError(DioError error) {
    final data = error.response?.data;
    var code = '';
    if (data is Map) {
      for (final key in const ['code', 'errorCode', 'errCode']) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          code = value.toString().trim();
          break;
        }
      }
      if (code.isEmpty && data['data'] is Map) {
        final inner = data['data'] as Map;
        for (final key in const ['code', 'errorCode', 'errCode']) {
          final value = inner[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            code = value.toString().trim();
            break;
          }
        }
      }
    }
    return isExplicitSessionExpiryResponse(
      statusCode: error.response?.statusCode,
      responseCode: code,
    );
  }

  /// 只把能够明确证明“当前登录凭证已失效”的响应升级为全局退出。
  ///
  /// 后端部分权限接口会用 HTTP 403 + `UNAUTHORIZED` 表示当前用户没有
  /// 访问某项业务的权限。它不是 token 失效，不能清空整个账号会话。
  /// 真正的 token/session 失效码仍允许在 401/403 等 4xx 下触发退出。
  @visibleForTesting
  static bool isExplicitSessionExpiryResponse({
    required int? statusCode,
    required String responseCode,
  }) {
    final status = statusCode ?? 0;
    if (status < 400 || status >= 500) {
      return false;
    }
    final code = responseCode.trim().toUpperCase();
    if (code.isEmpty) {
      return false;
    }
    if (code == 'UNAUTHORIZED') {
      return status == 401;
    }
    return code == 'AUTH_EXPIRED' ||
        code == 'TOKEN_EXPIRED' ||
        code == 'TOKEN_INVALID' ||
        code == 'INVALID_TOKEN' ||
        code == 'LOGIN_EXPIRED' ||
        code == 'SESSION_EXPIRED' ||
        code == 'SESSION_REVOKED';
  }

  bool _isBusinessAuthError(DioError error) {
    final code = _responseCode(error).toUpperCase();
    if (_isBusinessErrorCode(code)) {
      return true;
    }
    final message = _responseMessage(error).toLowerCase();
    return _looksLikeWalletBusinessMessage(message);
  }

  bool _isBusinessErrorCode(String code) {
    return code == 'PASSWORD_WRONG' ||
        code == 'PASSWORD_LOCKED' ||
        code == 'PAY_PIN_INVALID' ||
        code == 'INVALID_PAY_PIN' ||
        code == 'PAY_PIN_WRONG' ||
        code == 'PAY_PASSWORD_WRONG' ||
        code == 'PAY_PASSWORD_INVALID' ||
        code == 'TRADE_PASSWORD_WRONG' ||
        code == 'TRADE_PASSWORD_INVALID' ||
        code == 'FUND_PASSWORD_WRONG' ||
        code == 'PAY_PIN_LOCKED' ||
        code == 'PAY_PIN_NOT_SET' ||
        code == 'INSUFFICIENT_BALANCE' ||
        code == 'INSUFFICIENT_FEE' ||
        code == 'FEE_EXCEEDS_AMOUNT' ||
        code == 'DUPLICATE_SUBMIT' ||
        code == 'ALREADY_CLAIMED' ||
        code == 'LIMIT_EXCEEDED' ||
        code == 'INVALID_RECEIVER' ||
        code == 'INVALID_TRON_ADDRESS' ||
        code == 'RECIPIENT_NOT_FOUND' ||
        code == 'INVALID_AMOUNT';
  }

  String _responseCode(DioError error) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in const ['code', 'errorCode', 'errCode']) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      final inner = data['data'];
      if (inner is Map) {
        for (final key in const ['code', 'errorCode', 'errCode']) {
          final value = inner[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString().trim();
          }
        }
      }
    }
    return '';
  }

  String _responseMessage(DioError error) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in const ['message', 'msg', 'error', 'desc', 'detail']) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      final inner = data['data'];
      if (inner is Map) {
        for (final key in const ['message', 'msg', 'error', 'desc', 'detail']) {
          final value = inner[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString().trim();
          }
        }
      }
    }
    return error.message.trim();
  }

  bool _looksLikeWalletBusinessMessage(String text) {
    if (text.isEmpty) return false;
    return text.contains('支付密码') ||
        text.contains('交易密码') ||
        text.contains('资金密码') ||
        text.contains('pay pin') ||
        text.contains('payment password') ||
        text.contains('trade password') ||
        text.contains('insufficient balance') ||
        text.contains('余额不足') ||
        text.contains('重复提交') ||
        text.contains('duplicate submit');
  }

  bool _isWalletPath(String path) {
    final p = path.trim().toLowerCase();
    return p == '/wallet' || p.startsWith('/wallet/');
  }

  void setSuppressAuthExpired(bool value) {
    _suppressAuthExpired = value;
  }

  void setLogoutInProgress(bool value) {
    _logoutInProgress = value;
  }

  static bool isValidJwt(String? token) {
    if (token == null) return false;
    final t = token.trim();
    if (t.isEmpty) return false;
    if (_looksLikeJwt(t)) {
      return true;
    }
    return _looksLikeOpaqueToken(t);
  }

  static bool _looksLikeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3 || parts.any((part) => part.trim().isEmpty)) {
      return false;
    }
    if (!parts.every(_isBase64UrlLike)) {
      return false;
    }
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      return payload.trim().startsWith('{') && payload.trim().endsWith('}');
    } catch (_) {
      return false;
    }
  }

  static bool _looksLikeOpaqueToken(String token) {
    if (token.length < 32 || token.contains(' ')) {
      return false;
    }
    final safeOpaque = RegExp(r'^[A-Za-z0-9_\-~+/=]+$');
    return safeOpaque.hasMatch(token);
  }

  static bool _isBase64UrlLike(String part) {
    final base64UrlLike = RegExp(r'^[A-Za-z0-9\-_]+$');
    return base64UrlLike.hasMatch(part);
  }

  String _requestPath(RequestOptions options) {
    final path = options.path.trim();
    if (path.isNotEmpty) {
      return path.startsWith('/') ? path : '/$path';
    }
    final uriPath = options.uri.path.trim();
    return uriPath.isEmpty ? path : uriPath;
  }

  void _applyAgentRebateGroupHeader(RequestOptions options, String path) {
    final skip = options.extra[AgentRebateHttp.extraSkipGroup] == true;
    final normalized = path.startsWith('/') ? path : '/$path';
    final needsGroup = normalized.startsWith('/me/agent/') ||
        normalized.startsWith('/me/rebate/');
    if (skip || !needsGroup) {
      return;
    }
    if (AgentRebateHttp.hasGroup) {
      options.headers[AgentRebateHttp.groupHeader] = AgentRebateHttp.groupId;
    } else {
      options.headers.remove(AgentRebateHttp.groupHeader);
    }
  }

  Future<void> _notifyAuthExpired() async {
    if (_suppressAuthExpired) {
      return;
    }
    final callback = onAuthExpired;
    if (callback == null || _handlingAuthExpired) {
      return;
    }
    _handlingAuthExpired = true;
    try {
      await callback();
    } finally {
      Future<void>.delayed(const Duration(seconds: 2), () {
        _handlingAuthExpired = false;
      });
    }
  }

  static const bool _verboseLog = false;

  void _logAuthExpiredTrigger(DioError error) {
    // 诊断只在调试构建输出，发布版保持静默；不打印 token、响应正文或用户信息。
    if (!kDebugMode) return;
    final path = _requestPath(error.requestOptions);
    final status = error.response?.statusCode;
    final code = _responseCode(error);
    print(
      'API_LOG auth-expired trigger: '
      'path=$path status=$status code=${code.isEmpty ? '-' : code} '
      'suppressed=$_suppressAuthExpired handling=$_handlingAuthExpired',
    );
  }

  void _logRequest(RequestOptions options) {
    if (!_verboseLog) return;
    final method = options.method.toUpperCase();
    final path = _requestPath(options);
    final query = _safeLogValue(options.queryParameters);
    final data = _safeLogValue(options.data);
    print(
      'API_LOG request: '
      'method=$method path=$path url=${options.uri} '
      'query=${query.isEmpty ? '-' : query} '
      'body=${data.isEmpty ? '-' : data}',
    );
  }

  void _logResponse(Response response) {
    if (!_verboseLog) return;
    final method = response.requestOptions.method.toUpperCase();
    final path = _requestPath(response.requestOptions);
    final status = response.statusCode;
    final data = _safeLogValue(response.data);
    print(
      'API_LOG response: '
      'method=$method path=$path status=$status '
      'data=${data.isEmpty ? '-' : data}',
    );
  }

  void _logRequestError(DioError error) {
    if (!_verboseLog) return;
    final options = error.requestOptions;
    final method = options.method.toUpperCase();
    final path = _requestPath(options);
    final status = error.response?.statusCode;
    final type = error.type.toString();
    final message = _singleLine(error.message);
    final responseData = _safeLogValue(error.response?.data);
    final requestData = _safeLogValue(options.data);
    print(
      'API_LOG error: '
      'method=$method path=$path url=${options.uri} status=$status type=$type '
      'message=${message.isEmpty ? '-' : message} '
      'body=${requestData.isEmpty ? '-' : requestData} '
      'response=${responseData.isEmpty ? '-' : responseData}',
    );
    if (kIsWeb && status == null) {
      print(
        'API_LOG web transport hint: browser cannot read the API response. '
        'Check backend CORS / gateway settings for the current Web origin.',
      );
    }
  }

  String _singleLine(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _safeLogValue(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is List<int>) {
      return '<bytes:${value.length}>';
    }
    try {
      final sanitized = _sanitizeForLog(value);
      final text = sanitized is String ? sanitized : jsonEncode(sanitized);
      final singleLine = _singleLine(text);
      if (singleLine.length <= 600) {
        return singleLine;
      }
      return '${singleLine.substring(0, 597)}...';
    } catch (_) {
      return _singleLine(value.toString());
    }
  }

  Object? _sanitizeForLog(Object? value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, rawValue) {
        final keyText = key.toString();
        if (_shouldRedactLogField(keyText)) {
          result[keyText] = '***';
        } else {
          result[keyText] = _sanitizeForLog(rawValue);
        }
      });
      return result;
    }
    if (value is Iterable) {
      return value.map(_sanitizeForLog).toList();
    }
    return value;
  }

  bool _shouldRedactLogField(String key) {
    final lower = key.trim().toLowerCase();
    return lower == 'password' ||
        lower == 'token' ||
        lower == 'accesstoken' ||
        lower == 'access_token' ||
        lower == 'authorization' ||
        lower == 'smscode' ||
        lower == 'sms_code' ||
        lower == 'usersig' ||
        lower == 'user_sig';
  }

  bool _isPublicPath(String path) => isAnonymousAuthPath(path);

  /// 匿名鉴权白名单。`/auth/login/qr/scan`、`/confirm` **必须带** Bearer，
  /// 不可再用 `startsWith('/auth/login')` 一刀切，否则 401 会被误译成「验证已过期」。
  @visibleForTesting
  static bool isAnonymousAuthPath(String path) {
    final p = path.trim();
    final normalized = p.startsWith('/') ? p : '/$p';
    if (normalized == '/auth/login/qr/scan' ||
        normalized == '/auth/login/qr/confirm') {
      return false;
    }
    return normalized == '/sms/send' ||
        normalized == '/auth/slider/init' ||
        normalized == '/auth/slider/verify' ||
        normalized.toLowerCase() == '/nicknames/available' ||
        normalized.startsWith('/auth/login') ||
        normalized == '/auth/register' ||
        normalized == '/auth/password/reset' ||
        normalized == '/api/v1/platform/contact' ||
        normalized == '/api/v1/platform/customer-service' ||
        normalized == '/api/v1/platform/splash' ||
        normalized == '/platform/splash';
  }

  /// 后台 `/platform/contact` 按 `X-Client-Platform` 返回不同 version/build/downloadUrl。
  /// 安卓通道仍是旧值，检查更新与 iOS 对齐，统一走 iOS 发布信息。
  @visibleForTesting
  static String? resolveClientPlatformHeader({
    required String path,
    required String? clientPlatform,
  }) {
    final p = path.trim();
    final normalized = p.startsWith('/') ? p : '/$p';
    if (normalized == '/api/v1/platform/contact') {
      return 'iOS';
    }
    return clientPlatform;
  }

  Future<void> bootstrap() async {
    await loadToken();
    await _ensureDeviceId();
    await _loadClientInfo();
    unawaited(ClientDeviceInfo.deviceModel());
  }

  Future<void> loadToken() => _serializeTokenMutation(() async {
        _token = await _secure.read(key: _tokenSecureKey);
        _authenticatedUserId =
            (await _secure.read(key: _authUserIdSecureKey))?.trim();
        final prefs = await SharedPreferences.getInstance();
        final legacyToken = prefs.getString(_tokenKey);
        if ((_token == null || _token!.isEmpty) &&
            legacyToken != null &&
            legacyToken.isNotEmpty) {
          _token = legacyToken;
          await _secure.write(key: _tokenSecureKey, value: legacyToken);
        }
        if (legacyToken != null) {
          await prefs.remove(_tokenKey);
        }
      });

  Future<void> saveToken(String token, {String? userId}) =>
      _serializeTokenMutation(() async {
        final trimmed = token.trim();
        final previousToken = _token;
        var owner = userId?.trim() ?? '';
        if (owner.isEmpty && _sameToken(previousToken, trimmed)) {
          owner = _authenticatedUserId?.trim() ?? '';
        }
        owner = owner.isNotEmpty ? owner : _userIdFromJwt(trimmed);
        _logoutInProgress = false;
        _token = trimmed;
        await _secure.write(key: _tokenSecureKey, value: trimmed);
        if (owner.isNotEmpty) {
          _authenticatedUserId = owner;
          await _secure.write(key: _authUserIdSecureKey, value: owner);
        } else {
          // Never leave an old owner next to a newly issued opaque token. A
          // stale owner would make offline restore load another account's IM
          // cache and local database projection.
          _authenticatedUserId = null;
          await _secure.delete(key: _authUserIdSecureKey);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
      });

  Future<bool> saveAuthenticatedUserIdIfCurrent({
    required String? expectedToken,
    required String userId,
  }) async {
    final owner = userId.trim();
    if (owner.isEmpty) {
      return false;
    }
    var saved = false;
    await _serializeTokenMutation(() async {
      if (!_sameToken(_token, expectedToken)) {
        return;
      }
      _authenticatedUserId = owner;
      await _secure.write(key: _authUserIdSecureKey, value: owner);
      saved = true;
    });
    return saved;
  }

  Future<void> clearToken() => _serializeTokenMutation(_clearTokenUnlocked);

  /// Clears only the credential captured by the logout operation.
  ///
  /// A delayed logout from account A must not erase a token already saved for
  /// account B. Token mutations are serialized so the comparison and delete
  /// form one process-local transaction.
  Future<bool> clearTokenIfCurrent(String? expectedToken) async {
    var cleared = false;
    await _serializeTokenMutation(() async {
      if (!_sameToken(_token, expectedToken)) {
        return;
      }
      await _clearTokenUnlocked();
      cleared = true;
    });
    return cleared;
  }

  Future<void> _clearTokenUnlocked() async {
    _token = null;
    _authenticatedUserId = null;
    await _secure.delete(key: _tokenSecureKey);
    await _secure.delete(key: _authUserIdSecureKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<void> _serializeTokenMutation(
    Future<void> Function() mutation,
  ) {
    final next = _tokenMutationTail.then<void>(
      (_) => mutation(),
      onError: (_) => mutation(),
    );
    _tokenMutationTail = next;
    return next;
  }

  static bool _sameToken(String? left, String? right) {
    return (left?.trim() ?? '') == (right?.trim() ?? '');
  }

  static String _userIdFromJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return '';
    try {
      final raw = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final payload = jsonDecode(raw);
      if (payload is! Map) return '';
      for (final key in const ['userId', 'user_id', 'userID', 'uid', 'sub']) {
        final value = payload[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    } catch (_) {}
    return '';
  }

  String? get token => _token;

  String get authenticatedUserId => _authenticatedUserId?.trim() ?? '';

  String get deviceId => _deviceId ?? '';

  Future<void> ensureDeviceIdReady() => _ensureDeviceId();

  Future<void> _ensureDeviceId() async {
    String? id = await _secure.read(key: _deviceIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _secure.write(key: _deviceIdKey, value: id);
    }
    _deviceId = id;
  }

  Future<void> _loadClientInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _clientVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _clientVersion = null;
    }
    if (kIsWeb) {
      _clientPlatform = 'Web';
    } else if (Platform.isIOS) {
      _clientPlatform = 'iOS';
    } else if (Platform.isAndroid) {
      _clientPlatform = 'Android';
    } else if (Platform.isMacOS) {
      _clientPlatform = 'macOS';
    } else if (Platform.isWindows) {
      _clientPlatform = 'Windows';
    } else {
      _clientPlatform = 'Other';
    }
  }
}
