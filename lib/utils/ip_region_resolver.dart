import 'dart:convert';

import 'package:dio/dio.dart';

/// 根据公网 IP 解析地区（带内存缓存），供登录设备等页面展示。
class IpRegionResolver {
  IpRegionResolver._();

  static final Map<String, String> _cache = <String, String>{};
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: 5000,
      receiveTimeout: 5000,
      responseType: ResponseType.plain,
    ),
  );

  static bool isPublicIp(String? ip) {
    final value = ip?.trim() ?? '';
    if (value.isEmpty) {
      return false;
    }
    final parts = value.split('.');
    if (parts.length != 4) {
      return false;
    }
    final octets = <int>[];
    for (final part in parts) {
      final parsed = int.tryParse(part);
      if (parsed == null || parsed < 0 || parsed > 255) {
        return false;
      }
      octets.add(parsed);
    }
    if (octets[0] == 10) return false;
    if (octets[0] == 127) return false;
    if (octets[0] == 192 && octets[1] == 168) return false;
    if (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) return false;
    if (octets[0] == 100 && octets[1] >= 64 && octets[1] <= 127) return false;
    return true;
  }

  static String? cached(String? ip) {
    final key = ip?.trim() ?? '';
    if (key.isEmpty) {
      return null;
    }
    final value = _cache[key];
    return value != null && value.isNotEmpty ? value : null;
  }

  static Future<String?> resolve(String? ip) async {
    final key = ip?.trim() ?? '';
    if (key.isEmpty || !isPublicIp(key)) {
      return null;
    }
    final hit = cached(key);
    if (hit != null) {
      return hit;
    }
    final region = await _resolveFromIpApi(key) ?? await _resolveFromIpWhoIs(key);
    if (region != null && region.isNotEmpty) {
      _cache[key] = region;
    }
    return region;
  }

  static Future<Map<String, String>> resolveMany(Iterable<String?> ips) async {
    final unique = <String>{
      for (final ip in ips)
        if (isPublicIp(ip)) ip!.trim(),
    };
    final pending = unique.where((ip) => cached(ip) == null).toList();
    for (final ip in pending) {
      await resolve(ip);
    }
    final out = <String, String>{};
    for (final ip in unique) {
      final region = cached(ip);
      if (region != null && region.isNotEmpty) {
        out[ip] = region;
      }
    }
    return out;
  }

  static Future<String?> _resolveFromIpApi(String ip) async {
    try {
      final res = await _dio.get<String>(
        'http://ip-api.com/json/$ip',
        queryParameters: const {
          'lang': 'zh-CN',
          'fields': 'status,country,regionName,city',
        },
      );
      final body = res.data?.trim() ?? '';
      if (body.isEmpty) {
        return null;
      }
      final json = jsonDecode(body);
      if (json is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(json);
      if (map['status']?.toString() != 'success') {
        return null;
      }
      return _formatRegion(
        country: _readText(map['country']),
        region: _readText(map['regionName']),
        city: _readText(map['city']),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _resolveFromIpWhoIs(String ip) async {
    try {
      final res = await _dio.get<String>('https://ipwho.is/$ip?lang=cn');
      final body = res.data?.trim() ?? '';
      if (body.isEmpty) {
        return null;
      }
      final json = jsonDecode(body);
      if (json is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(json);
      if (map['success'] == false) {
        return null;
      }
      return _formatRegion(
        country: _readText(map['country']),
        region: _readText(map['region']),
        city: _readText(map['city']),
      );
    } catch (_) {
      return null;
    }
  }

  static String _formatRegion({
    required String country,
    required String region,
    required String city,
  }) {
    final parts = <String>[];
    if (country.isNotEmpty &&
        country != '中国' &&
        country.toLowerCase() != 'china' &&
        country != 'CN') {
      parts.add(country);
    }
    if (region.isNotEmpty && region != city) {
      parts.add(region);
    }
    if (city.isNotEmpty) {
      parts.add(city);
    }
    if (parts.isEmpty) {
      return region.isNotEmpty ? region : country;
    }
    return parts.join('');
  }

  static String _readText(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }
}
