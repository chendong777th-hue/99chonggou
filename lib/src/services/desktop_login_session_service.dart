import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/device_api.dart';
import 'package:tencent_cloud_chat_demo/src/utils/desktop_login_platform.dart';

/// 移动端消息列表「电脑/网页已登录」横幅的数据源。
class DesktopLoginSessionService {
  DesktopLoginSessionService._();

  static final DesktopLoginSessionService instance =
      DesktopLoginSessionService._();

  static const _debounce = Duration(milliseconds: 1500);

  final ValueNotifier<List<UserDevice>> devices =
      ValueNotifier<List<UserDevice>>(const <UserDevice>[]);

  DateTime? _lastRefreshAt;
  Future<void>? _inFlight;

  String? get bannerText => buildDesktopLoginBannerText(devices.value);

  void clear() {
    if (devices.value.isEmpty) {
      return;
    }
    devices.value = const <UserDevice>[];
  }

  Future<void> refresh({String reason = 'manual', bool force = false}) {
    final existing = _inFlight;
    if (existing != null) {
      return existing;
    }
    final now = DateTime.now();
    final last = _lastRefreshAt;
    if (!force &&
        last != null &&
        now.difference(last) < _debounce &&
        devices.value.isNotEmpty) {
      return Future<void>.value();
    }
    final future = _doRefresh(reason: reason);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
  }

  Future<void> _doRefresh({required String reason}) async {
    if (!ApiClient.isValidJwt(ApiClient.instance.token)) {
      clear();
      return;
    }
    try {
      final result = await DeviceApi.instance.fetchDevices();
      final filtered = filterOnlineDesktopOthers(result.items);
      _lastRefreshAt = DateTime.now();
      devices.value = filtered;
      if (kDebugMode) {
        debugPrint(
          'DesktopLoginSessionService.refresh reason=$reason '
          'raw=${result.items.length} desktop=${filtered.length} '
          'online=${filtered.where((d) => d.isOnline).length}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DesktopLoginSessionService.refresh failed: $e');
      }
      // 静默保留旧数据。
    }
  }
}
