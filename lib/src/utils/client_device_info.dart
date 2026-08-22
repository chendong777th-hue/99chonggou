import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// 客户端机型，供注册/登录等业务接口上报。
class ClientDeviceInfo {
  ClientDeviceInfo._();

  static String? _cachedModel;
  static Future<void>? _loading;

  static Future<String> deviceModel() async {
    final cached = _cachedModel;
    if (cached != null) {
      return cached;
    }
    _loading ??= _load();
    await _loading;
    return _cachedModel ?? '';
  }

  static Future<void> _load() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await plugin.webBrowserInfo;
        final browser = web.browserName.name.trim();
        final platform = web.platform?.trim() ?? '';
        _cachedModel = [browser, platform]
            .where((part) => part.isNotEmpty)
            .join(' ');
      } else if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final model = info.model.trim();
        final brand = info.brand.trim();
        if (model.isEmpty) {
          _cachedModel = brand;
        } else if (brand.isNotEmpty &&
            !model.toLowerCase().contains(brand.toLowerCase())) {
          _cachedModel = '$brand $model';
        } else {
          _cachedModel = model;
        }
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final machine = info.utsname.machine.trim();
        _cachedModel =
            machine.isNotEmpty ? machine : info.model.trim();
      } else if (Platform.isMacOS) {
        _cachedModel = (await plugin.macOsInfo).model.trim();
      } else if (Platform.isWindows) {
        _cachedModel = (await plugin.windowsInfo).computerName.trim();
      } else if (Platform.isLinux) {
        _cachedModel = (await plugin.linuxInfo).prettyName.trim();
      } else {
        _cachedModel = '';
      }
    } catch (_) {
      _cachedModel = '';
    }
    _cachedModel ??= '';
  }
}
