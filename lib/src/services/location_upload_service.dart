import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/location_api.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// 已授予定位权限时静默上报当前位置；不弹窗、不主动申请权限。
class LocationUploadService {
  LocationUploadService._();

  static final LocationUploadService instance = LocationUploadService._();

  static const String _prefsPrefix = 'me_location_next_allowed_ms_v1_';
  static const Duration _positionTimeout = Duration(seconds: 12);

  Future<void>? _inFlight;
  int? _memoryNextAllowedAtMs;
  String? _memoryScope;

  /// 登录后 / 回前台调用；内部自行节流与静默失败。
  Future<void> maybeUpload({String reason = 'unspecified'}) {
    final existing = _inFlight;
    if (existing != null) {
      return existing;
    }
    final future = _maybeUploadImpl(reason: reason).whenComplete(() {
      _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  /// 登出时清内存节流，避免串号；磁盘按 userScope 隔离。
  void clearSessionState() {
    _memoryNextAllowedAtMs = null;
    _memoryScope = null;
  }

  Future<void> _maybeUploadImpl({required String reason}) async {
    if (kIsWeb) {
      return;
    }
    if (!ApiClient.isValidJwt(ApiClient.instance.token)) {
      return;
    }

    final scope = _resolveScope();
    if (!await _isUploadDue(scope)) {
      return;
    }

    final permitted = await _hasLocationPermission();
    if (!permitted) {
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    final position = await _readPosition();
    if (position == null) {
      return;
    }
    if (!_isValidCoordinate(position.latitude, position.longitude)) {
      return;
    }

    try {
      await ApiClient.instance.ensureDeviceIdReady();
      final result = await LocationApi.instance.uploadLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy.isFinite ? position.accuracy : null,
        altitude: position.altitude.isFinite ? position.altitude : null,
        heading: position.heading.isFinite && position.heading >= 0
            ? position.heading
            : null,
        speed: position.speed.isFinite && position.speed >= 0
            ? position.speed
            : null,
        collectedAt: position.timestamp.millisecondsSinceEpoch,
        source: _mapSource(position),
        deviceId: ApiClient.instance.deviceId,
      );
      await _markNextAllowed(
        scope,
        DateTime.now().millisecondsSinceEpoch + result.nextUploadAfterMs,
      );
      if (kDebugMode) {
        debugPrint(
          'LocationUploadService: upload done '
          'reason=$reason accepted=${result.accepted} '
          'nextMs=${result.nextUploadAfterMs}',
        );
      }
    } catch (e) {
      // 失败也做短退避，避免权限已开时在弱网下狂打定位/接口。
      await _markNextAllowed(
        scope,
        DateTime.now().millisecondsSinceEpoch + (5 * 60 * 1000),
      );
      if (kDebugMode) {
        debugPrint('LocationUploadService: upload failed reason=$reason error=$e');
      }
    }
  }

  String _resolveScope() {
    try {
      final userId = TIMUIKitCore.getInstance().loginInfo.userID.trim();
      if (userId.isNotEmpty) {
        return userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      }
    } catch (_) {}
    return '_session';
  }

  Future<bool> _isUploadDue(String scope) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_memoryScope == scope &&
        _memoryNextAllowedAtMs != null &&
        now < _memoryNextAllowedAtMs!) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt('$_prefsPrefix$scope') ?? 0;
    if (stored > now) {
      _memoryScope = scope;
      _memoryNextAllowedAtMs = stored;
      return false;
    }
    return true;
  }

  Future<void> _markNextAllowed(String scope, int nextAllowedAtMs) async {
    _memoryScope = scope;
    _memoryNextAllowedAtMs = nextAllowedAtMs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefsPrefix$scope', nextAllowedAtMs);
  }

  Future<bool> _hasLocationPermission() async {
    try {
      final whenInUse = await Permission.locationWhenInUse.status;
      if (whenInUse.isGranted || whenInUse.isLimited) {
        return true;
      }
      final always = await Permission.locationAlways.status;
      if (always.isGranted || always.isLimited) {
        return true;
      }
      final location = await Permission.location.status;
      return location.isGranted || location.isLimited;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationUploadService: permission check failed: $e');
      }
      return false;
    }
  }

  Future<Position?> _readPosition() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          _isValidCoordinate(last.latitude, last.longitude) &&
          DateTime.now().difference(last.timestamp) < const Duration(hours: 6)) {
        return last;
      }
    } catch (_) {}

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: _positionTimeout,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationUploadService: getCurrentPosition failed: $e');
      }
      return null;
    }
  }

  static bool _isValidCoordinate(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0 && lng == 0);
  }

  static String _mapSource(Position position) {
    // geolocator 不直接暴露 provider；移动端统一按 fused 上报。
    final accuracy = position.accuracy;
    if (accuracy.isFinite && accuracy > 0 && accuracy <= 30) {
      return 'gps';
    }
    if (accuracy.isFinite && accuracy > 500) {
      return 'network';
    }
    return 'fused';
  }
}
