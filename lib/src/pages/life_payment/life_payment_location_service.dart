import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

enum LifePaymentLocationPhase {
  checking,
  ready,
  denied,
  serviceDisabled,
  failed,
}

class LifePaymentLocationData {
  const LifePaymentLocationData({
    required this.latitude,
    required this.longitude,
    required this.displayLabel,
    this.locality,
    this.administrativeArea,
  });

  final double latitude;
  final double longitude;
  final String? locality;
  final String? administrativeArea;
  final String displayLabel;
}

class LifePaymentLocationState {
  const LifePaymentLocationState({
    required this.phase,
    this.data,
  });

  final LifePaymentLocationPhase phase;
  final LifePaymentLocationData? data;

  bool get isReady => phase == LifePaymentLocationPhase.ready && data != null;
}

class LifePaymentLocationService {
  LifePaymentLocationService._();

  static Future<LifePaymentLocationState> resolveOnEnter(
    BuildContext context,
  ) async {
    if (kIsWeb) {
      return const LifePaymentLocationState(
        phase: LifePaymentLocationPhase.ready,
        data: LifePaymentLocationData(
          latitude: 0,
          longitude: 0,
          displayLabel: 'Web',
        ),
      );
    }

    final granted = await PermissionGuard.locationForLifePayment(context);
    if (!granted) {
      return const LifePaymentLocationState(
        phase: LifePaymentLocationPhase.denied,
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        await _promptEnableLocationService(context);
      }
      return const LifePaymentLocationState(
        phase: LifePaymentLocationPhase.serviceDisabled,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
      final label = await _resolveDisplayLabel(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      return LifePaymentLocationState(
        phase: LifePaymentLocationPhase.ready,
        data: LifePaymentLocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          locality: label.locality,
          administrativeArea: label.administrativeArea,
          displayLabel: label.displayLabel,
        ),
      );
    } catch (e) {
      debugPrint('LifePaymentLocationService: getCurrentPosition failed: $e');
      return const LifePaymentLocationState(
        phase: LifePaymentLocationPhase.failed,
      );
    }
  }

  static Future<_GeoLabel> _resolveDisplayLabel({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // 生活缴费城市名称统一请求中文结果，避免定位页出现 Beijing 等英文名称。
      // geocoding 4.x 使用全局 locale 设置，必须在逆地理编码前调用。
      try {
        await setLocaleIdentifier('zh_CN');
      } catch (e) {
        // 个别设备不支持切换 locale 时，仍继续走原有逆地理编码结果。
        debugPrint('LifePaymentLocationService: set Chinese locale failed: $e');
      }
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        return _GeoLabel(
          displayLabel: _formatCoordinate(latitude, longitude),
        );
      }
      final place = placemarks.first;
      final locality = _firstNonEmpty([
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
      ]);
      final administrativeArea = _firstNonEmpty([
        place.administrativeArea,
        place.country,
      ]);
      final display = locality ?? administrativeArea ?? _formatCoordinate(
        latitude,
        longitude,
      );
      return _GeoLabel(
        locality: locality,
        administrativeArea: administrativeArea,
        displayLabel: display,
      );
    } catch (e) {
      debugPrint('LifePaymentLocationService: reverse geocode failed: $e');
      return _GeoLabel(
        displayLabel: _formatCoordinate(latitude, longitude),
      );
    }
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static String _formatCoordinate(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(2)}, ${longitude.toStringAsFixed(2)}';
  }

  static Future<void> _promptEnableLocationService(BuildContext context) async {
    final i18n = AppI18n.of(context);
    final open = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '定位服务未开启',
        zhHant: '定位服務未開啟',
        en: 'Location services off',
        ja: '位置情報サービスがオフです',
        ko: '위치 서비스가 꺼져 있습니다',
      ),
      message: i18n.t(
        zhHans: '请在系统设置中开启定位服务，以便匹配当地缴费渠道。',
        zhHant: '請在系統設定中開啟定位服務，以便匹配當地繳費渠道。',
        en: 'Turn on location services in system settings to match local billing.',
        ja: '地域の料金サービスを表示するには位置情報サービスをオンにしてください。',
        ko: '지역 요금 서비스를 위해 시스템 설정에서 위치 서비스를 켜 주세요.',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      confirmText: i18n.t(
        zhHans: '去设置',
        zhHant: '去設定',
        en: 'Settings',
        ja: '設定へ',
        ko: '설정으로 이동',
      ),
    );
    if (open) {
      await Geolocator.openLocationSettings();
    }
  }
}

class _GeoLabel {
  const _GeoLabel({
    required this.displayLabel,
    this.locality,
    this.administrativeArea,
  });

  final String displayLabel;
  final String? locality;
  final String? administrativeArea;
}
