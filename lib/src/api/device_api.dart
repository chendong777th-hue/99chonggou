import 'package:dio/dio.dart';

import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';

class DeviceApi {
  DeviceApi._();
  static final DeviceApi instance = DeviceApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<UserDevicesResult> fetchDevices() async {
    final res = await _dio.get('/me/devices');
    return UserDevicesResult.fromJson(_payloadMap(res.data));
  }

  Future<KickDeviceResult> kickDevice(String deviceId) async {
    final id = deviceId.trim();
    final res = await _dio.post('/me/devices/$id/kick');
    return KickDeviceResult.fromJson(_payloadMap(res.data));
  }

  Future<KickOthersResult> kickOthers({String? currentDeviceId}) async {
    final id = currentDeviceId?.trim() ?? '';
    final res = await _dio.post(
      '/me/devices/kick-others',
      data: id.isNotEmpty ? {'deviceId': id} : null,
    );
    return KickOthersResult.fromJson(_payloadMap(res.data));
  }
}

Map<String, dynamic> _payloadMap(dynamic raw) {
  final payload = unwrapApiPayload(raw);
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }
  return const <String, dynamic>{};
}

class UserDevice {
  UserDevice({
    required this.deviceId,
    required this.platform,
    this.model,
    this.appVersion,
    this.lastLoginAt,
    this.lastLoginIp,
    this.lastLoginIpRegion,
    this.isTrusted = false,
    this.isCurrent = false,
    this.isOnline = false,
  });

  final String deviceId;
  final String platform;
  final String? model;
  final String? appVersion;
  final DateTime? lastLoginAt;
  final String? lastLoginIp;
  final String? lastLoginIpRegion;
  final bool isTrusted;
  final bool isCurrent;
  final bool isOnline;

  factory UserDevice.fromJson(Map<String, dynamic> json) {
    return UserDevice(
      deviceId: _readString(json, const ['deviceId', 'device_id']) ?? '',
      platform: _readString(json, const ['platform', 'clientPlatform']) ?? '',
      model: _readString(json, const ['model', 'deviceModel']),
      appVersion:
          _readString(json, const ['appVersion', 'app_version', 'clientVersion']),
      lastLoginAt: MeResult.parseIsoDateTime(
        json['lastLoginAt'] ?? json['last_login_at'],
      ),
      lastLoginIp:
          _readString(json, const ['lastLoginIp', 'last_login_ip', 'ip']),
      lastLoginIpRegion: _readIpRegion(json),
      isTrusted: _readBool(json, const ['isTrusted', 'is_trusted']) ?? false,
      isCurrent: _readBool(json, const ['isCurrent', 'is_current']) ?? false,
      isOnline: _readBool(json, const ['isOnline', 'is_online']) ?? false,
    );
  }
}

class UserDevicesResult {
  UserDevicesResult({
    required this.items,
    required this.total,
  });

  final List<UserDevice> items;
  final int total;

  factory UserDevicesResult.fromJson(Map<String, dynamic> json) {
    final rawItems = extractApiList(json);
    final items = rawItems
        .whereType<Map>()
        .map((e) => UserDevice.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.deviceId.isNotEmpty)
        .toList();
    return UserDevicesResult(
      items: items,
      total: _readInt(json, const ['total']) ?? items.length,
    );
  }
}

class KickDeviceResult {
  KickDeviceResult({
    required this.ok,
    required this.deviceId,
  });

  final bool ok;
  final String deviceId;

  factory KickDeviceResult.fromJson(Map<String, dynamic> json) {
    return KickDeviceResult(
      ok: _readBool(json, const ['ok']) ?? true,
      deviceId: _readString(json, const ['deviceId', 'device_id']) ?? '',
    );
  }
}

class KickOthersResult {
  KickOthersResult({
    required this.ok,
    required this.kickedCount,
  });

  final bool ok;
  final int kickedCount;

  factory KickOthersResult.fromJson(Map<String, dynamic> json) {
    return KickOthersResult(
      ok: _readBool(json, const ['ok']) ?? true,
      kickedCount: _readInt(json, const ['kickedCount', 'kicked_count']) ?? 0,
    );
  }
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

bool? _readBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
  }
  return null;
}

int? _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString().trim() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

String? _readIpRegion(Map<String, dynamic> json) {
  final direct = _readString(json, const [
    'lastLoginIpRegion',
    'last_login_ip_region',
    'ipRegion',
    'ip_region',
    'lastLoginLocation',
    'last_login_location',
    'loginLocation',
    'login_location',
    'ipLocation',
    'ip_location',
    'location',
    'region',
  ]);
  if (direct != null) {
    return direct;
  }
  for (final key in const [
    'lastLoginIpLocation',
    'last_login_ip_location',
    'ipLocationInfo',
    'ip_location_info',
  ]) {
    final nested = json[key];
    if (nested is Map) {
      final formatted = _formatLocationMap(Map<String, dynamic>.from(nested));
      if (formatted != null) {
        return formatted;
      }
    }
  }
  return null;
}

String? _formatLocationMap(Map<String, dynamic> json) {
  final direct = _readString(json, const [
    'display',
    'label',
    'text',
    'name',
    'location',
    'region',
    'address',
  ]);
  if (direct != null) {
    return direct;
  }
  final country = _readString(json, const ['country', 'countryName']) ?? '';
  final province =
      _readString(json, const ['province', 'region', 'regionName', 'state']) ??
          '';
  final city = _readString(json, const ['city', 'cityName']) ?? '';
  final parts = <String>[];
  if (country.isNotEmpty &&
      country != '中国' &&
      country.toLowerCase() != 'china' &&
      country != 'CN') {
    parts.add(country);
  }
  if (province.isNotEmpty && province != city) {
    parts.add(province);
  }
  if (city.isNotEmpty) {
    parts.add(city);
  }
  if (parts.isEmpty) {
    return null;
  }
  return parts.join('');
}
