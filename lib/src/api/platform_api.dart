import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';

class PlatformApi {
  PlatformApi._();

  static final PlatformApi instance = PlatformApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<PlatformContactInfo> fetchContact() async {
    final res = await _dio.get('/api/v1/platform/contact');
    final raw = unwrapApiPayload(res.data);
    final map = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
    return PlatformContactInfo.fromJson(map);
  }

  /// 获取在线客服 H5 页面地址（公开接口，无需 Token）。
  Future<String> fetchCustomerServiceUrl() async {
    final res = await _dio.get('/api/v1/platform/customer-service');
    final raw = unwrapApiPayload(res.data);
    final map = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
    return map['url']?.toString().trim() ?? '';
  }

  /// 冷启动图配置（公开接口，无需 Token）。
  Future<PlatformSplashConfig> fetchSplash({
    required String platform,
    required String appVersion,
    String channel = 'official',
  }) async {
    final res = await _dio.get(
      '/api/v1/platform/splash',
      queryParameters: <String, dynamic>{
        'platform': platform,
        'appVersion': appVersion,
        'channel': channel,
      },
    );
    final raw = unwrapApiPayload(res.data);
    final map = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
    return PlatformSplashConfig.fromJson(map);
  }
}

class PlatformContactInfo {
  const PlatformContactInfo({
    required this.website,
    required this.email,
    required this.version,
    required this.build,
    required this.downloadUrl,
  });

  final String website;
  final String email;
  final String version;
  final String build;
  final String downloadUrl;

  factory PlatformContactInfo.fromJson(Map<String, dynamic> json) {
    return PlatformContactInfo(
      website: json['website']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      build: json['build']?.toString() ?? '',
      downloadUrl: json['downloadUrl']?.toString() ?? '',
    );
  }
}

class PlatformSplashConfig {
  const PlatformSplashConfig({
    required this.enabled,
    required this.version,
    this.imageUrl,
    this.imageMd5,
    this.contentType,
    this.width,
    this.height,
    this.bytes,
    this.fit = 'cover',
    this.startAt,
    this.endAt,
    this.minAppVersion,
    this.updatedAt,
  });

  static const PlatformSplashConfig disabled = PlatformSplashConfig(
    enabled: false,
    version: 'default',
    imageUrl: null,
  );

  final bool enabled;
  final String version;
  final String? imageUrl;
  final String? imageMd5;
  final String? contentType;
  final int? width;
  final int? height;
  final int? bytes;
  final String fit;
  final String? startAt;
  final String? endAt;
  final String? minAppVersion;
  final String? updatedAt;

  bool get hasDownloadableImage {
    final url = imageUrl?.trim() ?? '';
    return enabled && url.isNotEmpty && version.trim().isNotEmpty;
  }

  factory PlatformSplashConfig.fromJson(Map<String, dynamic> json) {
    final enabledRaw = json['enabled'];
    final enabled = enabledRaw is bool
        ? enabledRaw
        : enabledRaw?.toString().toLowerCase() == 'true';
    final imageUrl = json['imageUrl']?.toString().trim();
    return PlatformSplashConfig(
      enabled: enabled,
      version: json['version']?.toString().trim().isNotEmpty == true
          ? json['version'].toString().trim()
          : 'default',
      imageUrl: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
      imageMd5: _nullableTrim(json['imageMd5'] ?? json['image_md5']),
      contentType: _nullableTrim(json['contentType'] ?? json['content_type']),
      width: _asPositiveInt(json['width']),
      height: _asPositiveInt(json['height']),
      bytes: _asPositiveInt(json['bytes']),
      fit: _nullableTrim(json['fit']) ?? 'cover',
      startAt: _nullableTrim(json['startAt'] ?? json['start_at']),
      endAt: _nullableTrim(json['endAt'] ?? json['end_at']),
      minAppVersion:
          _nullableTrim(json['minAppVersion'] ?? json['min_app_version']),
      updatedAt: _nullableTrim(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'version': version,
      'imageUrl': imageUrl,
      'imageMd5': imageMd5,
      'contentType': contentType,
      'width': width,
      'height': height,
      'bytes': bytes,
      'fit': fit,
      'startAt': startAt,
      'endAt': endAt,
      'minAppVersion': minAppVersion,
      'updatedAt': updatedAt,
    };
  }

  static String? _nullableTrim(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static int? _asPositiveInt(dynamic value) {
    if (value is int) {
      return value > 0 ? value : null;
    }
    if (value is num) {
      final n = value.toInt();
      return n > 0 ? n : null;
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }
}
