import 'package:dio/dio.dart';

import 'api_client.dart';

class PushTokenApi {
  PushTokenApi._();

  static final PushTokenApi instance = PushTokenApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<PushTokenRegisterResult> registerAndroidToken({
    required String token,
  }) async {
    return _registerToken(platform: 'ANDROID', token: token);
  }

  Future<PushTokenRegisterResult> registerIosToken({
    required String token,
    String? voipToken,
    String? bundleId,
    String? apsEnvironment,
  }) async {
    return _registerToken(
      platform: 'IOS',
      token: token,
      voipToken: voipToken,
      bundleId: bundleId,
      apsEnvironment: apsEnvironment,
    );
  }

  Future<PushTokenRegisterResult> registerVoipToken({
    required String token,
    String? bundleId,
    String? apsEnvironment,
  }) async {
    final deviceId = ApiClient.instance.deviceId.trim();
    if (deviceId.isEmpty) {
      throw const PushTokenApiException('INVALID_DEVICE');
    }
    final voipToken = token.trim();
    if (voipToken.isEmpty) {
      throw const PushTokenApiException('INVALID_TOKEN');
    }

    final payload = <String, dynamic>{
      'deviceId': deviceId,
      'token': voipToken,
    };
    final bid = bundleId?.trim() ?? '';
    if (bid.isNotEmpty) {
      payload['bundleId'] = bid;
    }
    final env = apsEnvironment?.trim() ?? '';
    if (env.isNotEmpty) {
      payload['apsEnvironment'] = env;
    }

    final res = await _dio.post('/me/voip-push-token', data: payload);
    return PushTokenRegisterResult.fromJson(res.data);
  }

  Future<PushTokenRegisterResult> _registerToken({
    required String platform,
    required String token,
    String? voipToken,
    String? bundleId,
    String? apsEnvironment,
  }) async {
    final deviceId = ApiClient.instance.deviceId.trim();
    final pushToken = token.trim();
    if (deviceId.isEmpty) {
      throw const PushTokenApiException('INVALID_DEVICE');
    }
    if (pushToken.isEmpty) {
      throw const PushTokenApiException('INVALID_TOKEN');
    }

    final payload = <String, dynamic>{
      'deviceId': deviceId,
      'platform': platform,
      'token': pushToken,
    };
    final voip = voipToken?.trim() ?? '';
    if (voip.isNotEmpty) {
      payload['voipToken'] = voip;
    }
    final bid = bundleId?.trim() ?? '';
    if (bid.isNotEmpty) {
      payload['bundleId'] = bid;
    }
    final env = apsEnvironment?.trim() ?? '';
    if (env.isNotEmpty) {
      payload['apsEnvironment'] = env;
    }

    final res = await _dio.post('/me/push-token', data: payload);
    return PushTokenRegisterResult.fromJson(res.data);
  }

  Future<void> deleteCurrentDeviceToken() async {
    final deviceId = ApiClient.instance.deviceId.trim();
    if (deviceId.isEmpty) {
      return;
    }
    await _dio.delete('/me/push-token', data: <String, dynamic>{
      'deviceId': deviceId,
    });
  }
}

class PushTokenRegisterResult {
  const PushTokenRegisterResult({
    required this.ok,
    required this.platform,
    required this.provider,
    required this.hasVoipToken,
  });

  final bool ok;
  final String platform;
  final String provider;
  final bool hasVoipToken;

  factory PushTokenRegisterResult.fromJson(dynamic raw) {
    final map = _unwrap(raw);
    return PushTokenRegisterResult(
      ok: _readBool(map['ok']) ?? false,
      platform: map['platform']?.toString() ?? '',
      provider: map['provider']?.toString() ?? '',
      hasVoipToken: _readBool(map['hasVoipToken']) ?? false,
    );
  }

  static Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return raw;
    }
    if (raw is Map) {
      final result = <String, dynamic>{};
      raw.forEach((key, value) => result[key.toString()] = value);
      final data = result['data'];
      if (data is Map) {
        final inner = <String, dynamic>{};
        data.forEach((key, value) => inner[key.toString()] = value);
        return inner;
      }
      return result;
    }
    return const <String, dynamic>{};
  }

  static bool? _readBool(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
  }
}

class PushTokenApiException implements Exception {
  const PushTokenApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
