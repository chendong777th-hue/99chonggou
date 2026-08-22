import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';

class LocationUploadResult {
  const LocationUploadResult({
    required this.accepted,
    required this.nextUploadAfterMs,
  });

  final bool accepted;
  final int nextUploadAfterMs;

  factory LocationUploadResult.fromJson(Map<String, dynamic> json) {
    final acceptedRaw = json['accepted'];
    final accepted = acceptedRaw is bool
        ? acceptedRaw
        : acceptedRaw?.toString().toLowerCase() == 'true';
    final nextRaw = json['nextUploadAfterMs'] ?? json['next_upload_after_ms'];
    var nextMs = 0;
    if (nextRaw is int) {
      nextMs = nextRaw;
    } else if (nextRaw is num) {
      nextMs = nextRaw.toInt();
    } else {
      nextMs = int.tryParse(nextRaw?.toString() ?? '') ?? 0;
    }
    if (nextMs <= 0) {
      nextMs = LocationApi.defaultNextUploadAfterMs;
    }
    return LocationUploadResult(
      accepted: accepted,
      nextUploadAfterMs: nextMs,
    );
  }
}

class LocationApi {
  LocationApi._();

  static final LocationApi instance = LocationApi._();

  /// 与后端默认限流一致：3 小时。
  static const int defaultNextUploadAfterMs = 3 * 60 * 60 * 1000;

  Dio get _dio => ApiClient.instance.dio;

  Future<LocationUploadResult> uploadLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? heading,
    double? speed,
    required int collectedAt,
    required String source,
    String? deviceId,
  }) async {
    final body = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'collectedAt': collectedAt,
      'source': source,
    };
    if (accuracy != null) {
      body['accuracy'] = accuracy;
    }
    if (altitude != null) {
      body['altitude'] = altitude;
    }
    if (heading != null) {
      body['heading'] = heading;
    }
    if (speed != null) {
      body['speed'] = speed;
    }
    final id = deviceId?.trim() ?? '';
    if (id.isNotEmpty) {
      body['deviceId'] = id;
    }

    final res = await _dio.put('/me/location', data: body);
    final raw = unwrapApiPayload(res.data);
    final map = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
    if (map.isEmpty) {
      return const LocationUploadResult(
        accepted: true,
        nextUploadAfterMs: defaultNextUploadAfterMs,
      );
    }
    return LocationUploadResult.fromJson(map);
  }
}
