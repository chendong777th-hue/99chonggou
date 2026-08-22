import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/models/livekit_call_credentials.dart';
import 'package:tencent_cloud_chat_demo/src/models/livekit_call_telemetry.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

class LiveKitCallApiException implements Exception {
  LiveKitCallApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message.isNotEmpty ? message : code;
}

class LiveKitCallApi {
  LiveKitCallApi._();

  static final LiveKitCallApi instance = LiveKitCallApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<LiveKitCallCredentials> invite({
    required String calleeUserId,
    required bool video,
  }) async {
    try {
      final res = await _dio.post(
        '/calls/livekit/invite',
        data: <String, dynamic>{
          'calleeUserId': calleeUserId.trim(),
          'mediaType': video ? 'video' : 'audio',
        },
      );
      return _parseCredentials(res.data);
    } on DioError catch (e) {
      throw _mapDio(e);
    }
  }

  Future<LiveKitCallCredentials> accept({required String callId}) async {
    try {
      final res = await _dio.post(
        '/calls/livekit/accept',
        data: <String, dynamic>{'callId': callId.trim()},
      );
      return _parseCredentials(res.data);
    } on DioError catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> reject({required String callId}) =>
      _postAction('/calls/livekit/reject', callId);

  Future<void> cancel({required String callId}) =>
      _postAction('/calls/livekit/cancel', callId);

  Future<void> hangup({required String callId}) =>
      _postAction('/calls/livekit/hangup', callId);

  Future<LiveKitCallCredentials> fetchToken({required String callId}) async {
    try {
      final res = await _dio.get(
        '/calls/livekit/token',
        queryParameters: <String, dynamic>{'callId': callId.trim()},
      );
      return _parseCredentials(res.data);
    } on DioError catch (e) {
      throw _mapDio(e);
    }
  }

  /// Best-effort client telemetry; failures must not affect the call UI.
  Future<void> reportTelemetry(LiveKitCallTelemetry payload) async {
    try {
      await _dio.post(
        '/calls/livekit/telemetry',
        data: payload.toJson(),
      );
    } on DioError catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> _postAction(String path, String callId) async {
    try {
      await _dio.post(
        path,
        data: <String, dynamic>{'callId': callId.trim()},
      );
    } on DioError catch (e) {
      throw _mapDio(e);
    }
  }

  LiveKitCallCredentials _parseCredentials(dynamic raw) {
    final payload = unwrapApiPayload(raw);
    if (payload is! Map) {
      throw LiveKitCallApiException('INVALID_RESPONSE', '通话凭证无效');
    }
    final creds = LiveKitCallCredentials.fromJson(
      Map<String, dynamic>.from(payload),
    );
    if (creds.callId.isEmpty || creds.url.isEmpty || creds.token.isEmpty) {
      throw LiveKitCallApiException('INVALID_RESPONSE', '通话凭证不完整');
    }
    return creds;
  }

  LiveKitCallApiException _mapDio(DioError e) {
    if (_isDioTimeout(e)) {
      final dioMessage = e.message.toString().trim();
      return LiveKitCallApiException(
        'REQUEST_TIMEOUT',
        dioMessage.isNotEmpty ? dioMessage : '网络超时，请稍后重试',
      );
    }
    final data = e.response?.data;
    String code = '';
    final dioMessage = e.message.toString().trim();
    String message = dioMessage.isNotEmpty ? dioMessage : '通话请求失败';
    if (data is Map) {
      code = data['code']?.toString() ?? data['error']?.toString() ?? '';
      message = data['message']?.toString() ??
          data['msg']?.toString() ??
          message;
    }
    if (e.response?.statusCode == 409 && code.isEmpty) {
      code = 'CALL_ALREADY_ANSWERED';
    }
    switch (code) {
      case 'LIVEKIT_NOT_CONFIGURED':
        message = '通话服务未配置';
        break;
      case 'NOT_FRIENDS':
        message = '仅好友之间可以通话';
        break;
      case 'CALLEE_BUSY':
        message = '对方忙线中';
        break;
      case 'CANNOT_CALL_SELF':
        message = '不能呼叫自己';
        break;
      case 'CALL_ALREADY_ANSWERED':
        message = message.isNotEmpty ? message : '通话已在其它端接听';
        break;
    }
    return LiveKitCallApiException(code, message);
  }

  static bool _isDioTimeout(DioError e) {
    return e.type == DioErrorType.connectTimeout ||
        e.type == DioErrorType.sendTimeout ||
        e.type == DioErrorType.receiveTimeout;
  }
}

/// Test double for [resolveAcceptCredentials] unit tests.
@visibleForTesting
class LiveKitCallApiOverride extends LiveKitCallApi {
  LiveKitCallApiOverride({
    required this.acceptFn,
    required this.fetchTokenFn,
  }) : super._();

  final Future<LiveKitCallCredentials> Function({required String callId}) acceptFn;
  final Future<LiveKitCallCredentials> Function({required String callId}) fetchTokenFn;

  @override
  Future<LiveKitCallCredentials> accept({required String callId}) =>
      acceptFn(callId: callId);

  @override
  Future<LiveKitCallCredentials> fetchToken({required String callId}) =>
      fetchTokenFn(callId: callId);
}
