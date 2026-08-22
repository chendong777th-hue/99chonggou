import 'package:tencent_cloud_chat_demo/src/api/device_api.dart';

bool isDesktopLoginPlatform(String platform) {
  switch (platform.trim().toLowerCase()) {
    case 'web':
    case 'windows':
    case 'macos':
    case 'mac':
    case 'linux':
    case 'desktop':
      return true;
    default:
      return false;
  }
}

/// Lower is higher priority. Web > Windows > macOS/Mac > Linux/desktop.
int desktopPlatformPriority(String platform) {
  switch (platform.trim().toLowerCase()) {
    case 'web':
      return 0;
    case 'windows':
      return 1;
    case 'macos':
    case 'mac':
      return 2;
    case 'linux':
    case 'desktop':
      return 3;
    default:
      return 99;
  }
}

/// Banner / detail short name（横幅用「Mac」而非 macOS）。
String desktopPlatformDisplayName(String platform) {
  switch (platform.trim().toLowerCase()) {
    case 'web':
      return '网页端';
    case 'windows':
      return 'Windows';
    case 'macos':
    case 'mac':
      return 'Mac';
    case 'linux':
      return 'Linux';
    case 'desktop':
      return '电脑端';
    default:
      final raw = platform.trim();
      return raw.isEmpty ? '电脑端' : raw;
  }
}

String normalizeDesktopPlatformKey(String platform) {
  final key = platform.trim().toLowerCase();
  if (key == 'mac') {
    return 'macos';
  }
  return key;
}

/// 他端桌面/网页：有会话即可展示，**不**用 [UserDevice.isOnline] 当门闩（对接文档 §14）。
List<UserDevice> filterOnlineDesktopOthers(List<UserDevice> all) {
  return all
      .where(
        (device) =>
            device.deviceId.trim().isNotEmpty &&
            !device.isCurrent &&
            isDesktopLoginPlatform(device.platform),
      )
      .toList(growable: false);
}

/// Distinct desktop platforms sorted by [desktopPlatformPriority].
List<String> orderedDesktopPlatformKeys(List<UserDevice> devices) {
  final keys = <String>{};
  for (final device in devices) {
    if (!isDesktopLoginPlatform(device.platform)) {
      continue;
    }
    keys.add(normalizeDesktopPlatformKey(device.platform));
  }
  final list = keys.toList(growable: true);
  list.sort(
    (a, b) => desktopPlatformPriority(a).compareTo(desktopPlatformPriority(b)),
  );
  return list;
}

String? buildDesktopLoginBannerText(List<UserDevice> devices) {
  final filtered = filterOnlineDesktopOthers(devices);
  final platforms = orderedDesktopPlatformKeys(filtered);
  if (platforms.isEmpty) {
    return null;
  }
  final primary = desktopPlatformDisplayName(platforms.first);
  if (platforms.length == 1) {
    return '已在$primary登录';
  }
  return '已在$primary等登录';
}
