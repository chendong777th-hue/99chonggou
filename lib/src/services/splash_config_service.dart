import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/platform_api.dart';

/// 远程启动图：冷启动只读本地缓存，后台拉取供下次使用。
class SplashConfigService {
  SplashConfigService._();

  static final SplashConfigService instance = SplashConfigService._();

  static const String defaultAsset = 'assets/splash_new.webp';
  static const String _prefsKey = 'platform_splash_cache_v1';
  static const int _maxBytes = 1024 * 1024;
  static const int _maxWidth = 1080;
  static const int _maxHeight = 1920;

  String? _cachedFilePath;
  bool _prepared = false;
  Future<void>? _refreshInFlight;

  /// 同步可读的本地缓存路径（[prepareForLaunch] 之后才可靠）。
  String? get cachedFilePath => _cachedFilePath;

  /// 冷启动前调用：仅读磁盘/偏好，不访问网络。
  Future<void> prepareForLaunch() async {
    if (kIsWeb) {
      _prepared = true;
      _cachedFilePath = null;
      return;
    }
    try {
      final meta = await _readMeta();
      if (meta == null ||
          !meta.config.hasDownloadableImage ||
          meta.localPath.trim().isEmpty) {
        await _clearLocalFiles();
        _cachedFilePath = null;
        _prepared = true;
        return;
      }
      final file = File(meta.localPath);
      if (!await file.exists()) {
        await _clearMeta();
        _cachedFilePath = null;
        _prepared = true;
        return;
      }
      final bytes = await file.readAsBytes();
      if (!_passesIntegrity(bytes, meta.config)) {
        await _clearAll();
        _cachedFilePath = null;
        _prepared = true;
        return;
      }
      _cachedFilePath = meta.localPath;
    } catch (_) {
      _cachedFilePath = null;
    } finally {
      _prepared = true;
    }
  }

  /// 后台刷新配置并按需下载；失败不影响当前启动。
  Future<void> refreshInBackground() {
    final existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _refreshInBackgroundImpl().whenComplete(() {
      _refreshInFlight = null;
    });
    _refreshInFlight = future;
    return future;
  }

  Future<void> _refreshInBackgroundImpl() async {
    if (kIsWeb) {
      return;
    }
    if (!_prepared) {
      await prepareForLaunch();
    }
    try {
      final query = await _buildQuery();
      final remote = await PlatformApi.instance.fetchSplash(
        platform: query.platform,
        appVersion: query.appVersion,
        channel: query.channel,
      );
      if (!remote.hasDownloadableImage) {
        await _clearAll();
        _cachedFilePath = null;
        return;
      }
      final current = await _readMeta();
      if (current != null &&
          current.config.version == remote.version &&
          current.config.imageUrl == remote.imageUrl &&
          current.config.imageMd5 == remote.imageMd5 &&
          await File(current.localPath).exists()) {
        _cachedFilePath = current.localPath;
        return;
      }
      final localPath = await _downloadAndPersist(remote);
      if (localPath == null) {
        return;
      }
      _cachedFilePath = localPath;
    } catch (_) {
      // Keep previous cache on any network/parse failure.
    }
  }

  Future<_SplashQuery> _buildQuery() async {
    var appVersion = '1.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      if (version.isNotEmpty) {
        appVersion = version;
      }
    } catch (_) {}

    String platform;
    if (Platform.isIOS) {
      platform = 'ios';
    } else if (Platform.isAndroid) {
      platform = 'android';
    } else if (Platform.isMacOS) {
      platform = 'ios';
    } else {
      platform = 'android';
    }

    return _SplashQuery(
      platform: platform,
      appVersion: appVersion,
      channel: IMDemoConfig.appChannel,
    );
  }

  Future<String?> _downloadAndPersist(PlatformSplashConfig config) async {
    final url = config.imageUrl!.trim();
    final res = await ApiClient.instance.dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );
    final data = res.data;
    if (data == null || data.isEmpty) {
      return null;
    }
    final bytes = Uint8List.fromList(data);
    if (!_passesIntegrity(bytes, config)) {
      return null;
    }

    final dir = await _splashDir();
    await dir.create(recursive: true);
    final ext = _extensionFor(config.contentType, url);
    final target = File('${dir.path}/splash_${_safeVersion(config.version)}$ext');
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await tmp.rename(target.path);

    final meta = _SplashCacheMeta(
      config: config,
      localPath: target.path,
    );
    await _writeMeta(meta);
    await _deleteOtherSplashFiles(keepPath: target.path);
    return target.path;
  }

  bool _passesIntegrity(Uint8List bytes, PlatformSplashConfig config) {
    if (bytes.isEmpty || bytes.lengthInBytes > _maxBytes) {
      return false;
    }
    final md5Hex = config.imageMd5?.trim().toLowerCase();
    if (md5Hex != null && md5Hex.isNotEmpty) {
      final digest = md5.convert(bytes).toString();
      if (digest != md5Hex) {
        return false;
      }
    } else {
      final expectedBytes = config.bytes;
      if (expectedBytes != null &&
          expectedBytes > 0 &&
          bytes.length != expectedBytes) {
        return false;
      }
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return false;
    }
    if (decoded.width > _maxWidth || decoded.height > _maxHeight) {
      return false;
    }
    final expectedW = config.width;
    final expectedH = config.height;
    if (expectedW != null && expectedW > 0 && decoded.width != expectedW) {
      return false;
    }
    if (expectedH != null && expectedH > 0 && decoded.height != expectedH) {
      return false;
    }
    return true;
  }

  Future<Directory> _splashDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/platform_splash');
  }

  Future<_SplashCacheMeta?> _readMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return _SplashCacheMeta.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMeta(_SplashCacheMeta meta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(meta.toJson()));
  }

  Future<void> _clearMeta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<void> _clearLocalFiles() async {
    try {
      final dir = await _splashDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> _clearAll() async {
    await _clearMeta();
    await _clearLocalFiles();
  }

  Future<void> _deleteOtherSplashFiles({required String keepPath}) async {
    try {
      final dir = await _splashDir();
      if (!await dir.exists()) {
        return;
      }
      await for (final entity in dir.list()) {
        if (entity is File && entity.path != keepPath) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  static String _safeVersion(String version) {
    final cleaned = version.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? 'default' : cleaned;
  }

  static String _extensionFor(String? contentType, String url) {
    final type = (contentType ?? '').toLowerCase();
    if (type.contains('webp')) {
      return '.webp';
    }
    if (type.contains('jpeg') || type.contains('jpg')) {
      return '.jpg';
    }
    if (type.contains('png')) {
      return '.png';
    }
    final lower = url.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return '.jpg';
    }
    if (lower.endsWith('.png')) {
      return '.png';
    }
    return '.webp';
  }
}

class _SplashQuery {
  const _SplashQuery({
    required this.platform,
    required this.appVersion,
    required this.channel,
  });

  final String platform;
  final String appVersion;
  final String channel;
}

class _SplashCacheMeta {
  const _SplashCacheMeta({
    required this.config,
    required this.localPath,
  });

  final PlatformSplashConfig config;
  final String localPath;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'config': config.toJson(),
      'localPath': localPath,
    };
  }

  factory _SplashCacheMeta.fromJson(Map<String, dynamic> json) {
    final configRaw = json['config'];
    final configMap = configRaw is Map<String, dynamic>
        ? configRaw
        : configRaw is Map
            ? Map<String, dynamic>.from(configRaw)
            : <String, dynamic>{};
    return _SplashCacheMeta(
      config: PlatformSplashConfig.fromJson(configMap),
      localPath: json['localPath']?.toString() ?? '',
    );
  }
}
