import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/utils/client_device_info.dart';
import 'api_client.dart';

class AuthApi {
  AuthApi._();
  static final AuthApi instance = AuthApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<Map<String, String>> _authDeviceFields() async {
    await ApiClient.instance.ensureDeviceIdReady();
    final deviceModel = await ClientDeviceInfo.deviceModel();
    return {
      'deviceId': ApiClient.instance.deviceId,
      'deviceModel': deviceModel,
    };
  }

  Future<void> sendSms({
    required String phone,
    required String scene,
    String? phoneCountry,
    String? challengeId,
  }) async {
    final data = <String, dynamic>{
      'phone': phone.trim(),
      'scene': scene,
      if (phoneCountry?.trim().isNotEmpty == true)
        'phoneCountry': phoneCountry!.trim().toUpperCase(),
      if (challengeId != null) 'challengeId': challengeId,
    };
    await _dio.post('/sms/send', data: data);
  }

  Future<TokenResult> register({
    required String phone,
    required String smsCode,
    required String nickname,
    required String password,
    required String phoneCountry,
    String? avatarUrl,
  }) async {
    final device = await _authDeviceFields();
    final res = await _dio.post('/auth/register', data: {
      'phone': phone,
      'smsCode': smsCode,
      'nickname': nickname,
      'password': password,
      'phoneCountry': phoneCountry.trim().toUpperCase(),
      ...device,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
    });
    return TokenResult.fromJson(res.data);
  }

  Future<TokenResult> loginSms({
    required String phone,
    required String smsCode,
    required String phoneCountry,
  }) async {
    final device = await _authDeviceFields();
    final res = await _dio.post('/auth/login/sms', data: {
      'phone': phone,
      'smsCode': smsCode,
      'phoneCountry': phoneCountry.trim().toUpperCase(),
      ...device,
    });
    return TokenResult.fromJson(res.data);
  }

  Future<PasswordLoginResult> loginPassword({
    required String account,
    required String password,
    String phoneCountry = 'CN',
  }) async {
    final device = await _authDeviceFields();
    final data = {
      'account': account,
      'password': password,
      'phoneCountry': phoneCountry.trim().toUpperCase(),
      ...device,
    };
    final res = await _dio.post('/auth/login/password', data: data);
    return PasswordLoginResult.fromJson(res.data);
  }

  Future<TokenResult> loginPasswordVerify({
    required String challengeId,
    required String smsCode,
  }) async {
    final device = await _authDeviceFields();
    final res = await _dio.post('/auth/login/password/verify', data: {
      'challengeId': challengeId,
      'smsCode': smsCode,
      ...device,
    });
    return TokenResult.fromJson(res.data);
  }

  Future<TokenResult> resetPassword({
    required String phone,
    required String smsCode,
    required String password,
    String? phoneCountry,
  }) async {
    final res = await _dio.post('/auth/password/reset', data: {
      'phone': phone,
      'smsCode': smsCode,
      'password': password,
      if (phoneCountry?.trim().isNotEmpty == true)
        'phoneCountry': phoneCountry!.trim().toUpperCase(),
    });
    return TokenResult.fromJson(res.data);
  }

  /// 未绑定手机账号修改登录密码（旧密码 + 新密码）。
  Future<TokenResult> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final res = await _dio.post('/auth/password/change', data: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
    return TokenResult.fromJson(res.data);
  }

  Future<UserSigResult> fetchUserSig() async {
    final res = await _dio.get('/im/user-sig');
    return UserSigResult.fromJson(res.data);
  }

  Future<MeResult> fetchMe() async {
    final res = await _dio.get('/me');
    return MeResult.fromJson(res.data);
  }

  // --- Web 扫码登录契约 v1（服务端对齐用）---
  // 状态机：pending → scanned → confirmed | cancelled | expired
  // 二维码载荷：{"type":"web_login","sessionId":"...","v":1}

  /// Web：创建扫码登录会话。
  Future<QrLoginSession> createQrLoginSession() async {
    final device = await _authDeviceFields();
    final res = await _dio.post('/auth/login/qr/session', data: device);
    return QrLoginSession.fromJson(res.data);
  }

  /// Web：轮询会话状态；仅 `confirmed` 时带 TokenResult 字段。
  Future<QrLoginPollResult> pollQrLoginSession(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) {
      throw FormatException('QrLogin sessionId empty');
    }
    final res = await _dio.get('/auth/login/qr/session/$id');
    return QrLoginPollResult.fromJson(res.data);
  }

  /// App（需登录）：扫码登记，将会话标为 scanned。
  Future<QrLoginScanResult> scanQrLoginSession(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) {
      throw FormatException('QrLogin sessionId empty');
    }
    final res = await _dio.post('/auth/login/qr/scan', data: {
      'sessionId': id,
    });
    return QrLoginScanResult.fromJson(res.data);
  }

  /// App（需登录）：确认或取消网页登录。
  Future<QrLoginConfirmResult> confirmQrLoginSession({
    required String sessionId,
    required bool approve,
  }) async {
    final id = sessionId.trim();
    if (id.isEmpty) {
      throw FormatException('QrLogin sessionId empty');
    }
    final res = await _dio.post('/auth/login/qr/confirm', data: {
      'sessionId': id,
      'approve': approve,
    });
    return QrLoginConfirmResult.fromJson(res.data);
  }
}

/// `POST /auth/login/qr/session` 响应。
class QrLoginSession {
  QrLoginSession({
    required this.sessionId,
    required this.qrPayload,
    required this.expiresIn,
  });

  final String sessionId;
  final String qrPayload;
  final int expiresIn;

  factory QrLoginSession.fromJson(dynamic raw) {
    final j = _authMap(raw);
    final sessionId = _readString(j, const ['sessionId', 'session_id']) ?? '';
    final qrPayload = _readString(j, const ['qrPayload', 'qr_payload']) ?? '';
    if (sessionId.isEmpty || qrPayload.isEmpty) {
      throw FormatException('QrLoginSession missing sessionId/qrPayload');
    }
    return QrLoginSession(
      sessionId: sessionId,
      qrPayload: qrPayload,
      expiresIn: _readInt(j, const ['expiresIn', 'expires_in']) ?? 120,
    );
  }
}

/// `GET /auth/login/qr/session/{id}` 响应。
class QrLoginPollResult {
  QrLoginPollResult({
    required this.status,
    this.tokenResult,
    this.displayHint,
  });

  /// pending | scanned | confirmed | cancelled | expired
  final String status;
  final TokenResult? tokenResult;
  final String? displayHint;

  bool get isPending => status == 'pending';
  bool get isScanned => status == 'scanned';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => status == 'expired';
  bool get isTerminal => isConfirmed || isCancelled || isExpired;

  factory QrLoginPollResult.fromJson(dynamic raw) {
    final j = _authMap(raw);
    final status =
        (_readString(j, const ['status']) ?? 'pending').trim().toLowerCase();
    TokenResult? token;
    if (status == 'confirmed') {
      try {
        token = TokenResult.fromJson(j);
      } catch (_) {
        token = null;
      }
    }
    return QrLoginPollResult(
      status: status,
      tokenResult: token,
      displayHint: _readString(j, const ['displayHint', 'display_hint']),
    );
  }
}

/// `POST /auth/login/qr/scan` 响应。
class QrLoginScanResult {
  QrLoginScanResult({
    required this.sessionId,
    required this.status,
    this.siteLabel,
  });

  final String sessionId;
  final String status;
  final String? siteLabel;

  factory QrLoginScanResult.fromJson(dynamic raw) {
    final j = _authMap(raw);
    return QrLoginScanResult(
      sessionId: _readString(j, const ['sessionId', 'session_id']) ?? '',
      status: (_readString(j, const ['status']) ?? 'scanned').trim().toLowerCase(),
      siteLabel: _readString(j, const ['siteLabel', 'site_label']),
    );
  }
}

/// `POST /auth/login/qr/confirm` 响应。
class QrLoginConfirmResult {
  QrLoginConfirmResult({
    required this.sessionId,
    required this.status,
  });

  final String sessionId;
  final String status;

  factory QrLoginConfirmResult.fromJson(dynamic raw) {
    final j = _authMap(raw);
    return QrLoginConfirmResult(
      sessionId: _readString(j, const ['sessionId', 'session_id']) ?? '',
      status: (_readString(j, const ['status']) ?? '').trim().toLowerCase(),
    );
  }
}

class TokenResult {
  TokenResult({
    required this.token,
    required this.userId,
    required this.expiresIn,
    required this.nextStep,
  });

  final String token;
  final String userId;
  final int expiresIn;
  final String nextStep;

  factory TokenResult.fromJson(dynamic raw) {
    final j = _authMap(raw);
    final token = _readString(j, const ['token', 'accessToken', 'access_token']);
    final userId = _readString(j, const ['userId', 'user_id']);
    if (token == null || token.isEmpty) {
      throw FormatException('TokenResult missing token');
    }
    return TokenResult(
      token: token,
      userId: userId ?? '',
      expiresIn: _readInt(j, const ['expiresIn', 'expires_in']) ?? 604800,
      nextStep: _readString(j, const ['nextStep', 'next_step']) ?? 'OK',
    );
  }
}

class PasswordLoginResult {
  PasswordLoginResult({
    required this.nextStep,
    this.token,
    this.userId,
    this.expiresIn,
    this.challengeId,
    this.phone,
    this.phoneMasked,
  });

  final String nextStep; // OK | NEED_SMS
  final String? token;
  final String? userId;
  final int? expiresIn;
  final String? challengeId;
  final String? phone;
  final String? phoneMasked;

  bool get needSms => normalizeAuthNextStep(nextStep) == 'NEED_SMS';

  bool get isLoginOk => normalizeAuthNextStep(nextStep) == 'OK';

  factory PasswordLoginResult.fromJson(dynamic raw) {
    final j = _authMap(raw);
    return PasswordLoginResult(
      nextStep: _readString(j, const ['nextStep', 'next_step']) ?? 'OK',
      token: _readString(j, const ['token', 'accessToken', 'access_token']),
      userId: _readString(j, const ['userId', 'user_id']),
      expiresIn: _readInt(j, const ['expiresIn', 'expires_in']),
      challengeId:
          _readString(j, const ['challengeId', 'challenge_id']),
      phone: _readPhone(j),
      phoneMasked:
          _readString(j, const ['phoneMasked', 'phone_masked']),
    );
  }

  static String? _readPhone(Map<String, dynamic> j) {
    for (final key in [
      'phone',
      'boundPhone',
      'phoneE164',
      'phoneNumber',
      'mobile',
    ]) {
      final v = j[key];
      if (v is num) {
        final digits = v.toString().replaceAll(RegExp(r'\D'), '');
        if (digits.length >= 8 && digits.length <= 15) {
          return digits.startsWith('+') ? digits : '+$digits';
        }
      }
      if (v is String && v.trim().isNotEmpty && !v.contains('*')) {
        return v.trim();
      }
    }
    final data = j['data'];
    if (data is Map<String, dynamic>) {
      return _readPhone(data);
    }
    return null;
  }
}

class MeResult {
  MeResult({
    required this.userId,
    required this.phone,
    required this.phoneMasked,
    required this.nickname,
    this.avatarUrl,
    this.email,
    this.lastNicknameChangedAt,
    this.nextNicknameChangeableAt,
    this.bypassDeviceCheck = false,
  });

  final String userId;
  final String phone;
  final String phoneMasked;
  final String nickname;
  final String? avatarUrl;
  final String? email;
  final DateTime? lastNicknameChangedAt;
  final DateTime? nextNicknameChangeableAt;
  final bool bypassDeviceCheck;

  factory MeResult.fromJson(dynamic raw) {
    final j = _authMap(raw);
    return MeResult(
      userId: _readString(j, const ['userId', 'user_id']) ?? '',
      phone: _readString(j, const ['phone']) ?? '',
      phoneMasked:
          _readString(j, const ['phoneMasked', 'phone_masked']) ?? '',
      nickname: _readString(j, const ['nickname']) ?? '',
      avatarUrl: _readString(j, const ['avatarUrl', 'avatar_url']),
      email: _readString(j, const ['email']),
      lastNicknameChangedAt: _readDateTime(j, const [
        'lastNicknameChangedAt',
        'last_nickname_changed_at',
        'nicknameChangedAt',
        'nickname_changed_at',
        'nicknameUpdatedAt',
        'nickname_updated_at',
        'lastProfileNicknameChangedAt',
        'last_profile_nickname_changed_at',
      ]),
      nextNicknameChangeableAt: _readDateTime(j, const [
        'nextNicknameChangeableAt',
        'next_nickname_changeable_at',
        'nextNicknameChangeAt',
        'next_nickname_change_at',
        'nicknameNextChangeableAt',
        'nickname_next_changeable_at',
        'nicknameCooldownEndsAt',
        'nickname_cooldown_ends_at',
        'nicknameCanChangeAt',
        'nickname_can_change_at',
        'nextChangeableAt',
        'next_changeable_at',
      ]),
      bypassDeviceCheck:
          j['bypassDeviceCheck'] as bool? ??
              j['bypass_device_check'] as bool? ??
              false,
    );
  }


  static DateTime? _readDateTime(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final parsed = parseIsoDateTime(json[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? parseIsoDateTime(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    try {
      return DateTime.parse(text).toUtc();
    } catch (_) {
      return null;
    }
  }
}

class UserSigResult {
  UserSigResult({
    required this.sdkAppId,
    required this.userId,
    required this.userSig,
    required this.expiresIn,
  });

  final int sdkAppId;
  final String userId;
  final String userSig;
  final int expiresIn;

  factory UserSigResult.fromJson(dynamic raw) {
    final j = _authMap(raw);
    return UserSigResult(
      sdkAppId: _readInt(j, const ['sdkAppId', 'sdk_app_id']) ?? 0,
      userId: _readString(j, const ['userId', 'user_id']) ?? '',
      userSig: _readString(j, const ['userSig', 'user_sig']) ?? '',
      expiresIn: _readInt(j, const ['expiresIn', 'expires_in']) ?? 0,
    );
  }
}

/// 登录/鉴权响应解析：合并根对象与 `data` 内层，避免 unwrap 丢掉顶层 token。
Map<String, dynamic> _authMap(dynamic raw) {
  final root = _toAuthRootMap(raw);
  _throwIfBusinessError(root);

  final layers = <Map<String, dynamic>>[root];
  var current = root;
  for (var depth = 0; depth < 4; depth++) {
    final next = _unwrapAuthLayer(current);
    if (next == null) break;
    layers.add(next);
    current = next;
  }

  final merged = <String, dynamic>{};
  for (final layer in layers) {
    for (final entry in layer.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      final existing = merged[entry.key];
      if (existing == null ||
          (existing is String && existing.toString().trim().isEmpty)) {
        merged[entry.key] = value;
      }
    }
  }
  return merged;
}

Map<String, dynamic> _toAuthRootMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw FormatException('Empty auth response body');
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  throw FormatException('Expected JSON object, got $raw');
}

Map<String, dynamic>? _unwrapAuthLayer(Map<String, dynamic> map) {
  for (final key in const ['data', 'result', 'payload']) {
    final value = map[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return null;
}

bool _hasAuthSuccessShape(Map<String, dynamic> j) {
  return _readString(j, const ['nextStep', 'next_step']) != null ||
      _readString(j, const ['token', 'accessToken', 'access_token']) != null ||
      _readString(j, const ['challengeId', 'challenge_id']) != null ||
      _readString(j, const ['userSig', 'user_sig']) != null;
}

void _throwIfBusinessError(Map<String, dynamic> root) {
  if (_hasAuthSuccessShape(root)) return;

  var current = root;
  for (var depth = 0; depth < 4; depth++) {
    final next = _unwrapAuthLayer(current);
    if (next == null) break;
    if (_hasAuthSuccessShape(next)) return;
    current = next;
  }

  final code = root['code'];
  if (code == null) return;
  if (code is num) {
    if (code == 0 || (code >= 200 && code < 300)) return;
  }
  final codeStr = code.toString().trim();
  if (codeStr.isEmpty ||
      codeStr == '0' ||
      codeStr == '200' ||
      codeStr == '201' ||
      codeStr.toUpperCase() == 'OK' ||
      codeStr.toUpperCase() == 'SUCCESS') {
    return;
  }
  throw AuthApiBusinessException(codeStr);
}

String normalizeAuthNextStep(String? raw) {
  final step = raw?.trim() ?? '';
  if (step.isEmpty) return 'OK';
  final upper = step.toUpperCase().replaceAll('-', '_');
  if (upper == 'NEEDSMS') return 'NEED_SMS';
  return upper;
}

/// HTTP 200 但 body 为业务错误码（无 nextStep/token）时抛出。
class AuthApiBusinessException implements Exception {
  AuthApiBusinessException(this.code);
  final String code;
}

String? _readString(Map<String, dynamic> j, List<String> keys) {
  for (final key in keys) {
    final v = j[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

int? _readInt(Map<String, dynamic> j, List<String> keys) {
  for (final key in keys) {
    final v = j[key];
    if (v == null) continue;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final parsed = int.tryParse(v.toString().trim());
    if (parsed != null) return parsed;
  }
  return null;
}
