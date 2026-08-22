import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/device_api.dart';
import 'package:tencent_cloud_chat_demo/src/utils/desktop_login_platform.dart';

UserDevice _device({
  required String id,
  required String platform,
  bool isCurrent = false,
  bool isOnline = true,
}) {
  return UserDevice(
    deviceId: id,
    platform: platform,
    isCurrent: isCurrent,
    isOnline: isOnline,
  );
}

void main() {
  group('desktop_login_platform', () {
    test('includes desktop sessions even when isOnline is false', () {
      final filtered = filterOnlineDesktopOthers([
        _device(id: 'phone', platform: 'iOS', isCurrent: true, isOnline: true),
        _device(id: 'web1', platform: 'Web', isOnline: false),
        _device(id: 'win', platform: 'Windows', isOnline: true),
        _device(id: 'android', platform: 'Android', isOnline: true),
        _device(id: 'linux', platform: 'linux', isOnline: false),
      ]);
      expect(filtered.map((e) => e.deviceId), ['web1', 'win', 'linux']);
    });

    test('banner text single platform', () {
      expect(
        buildDesktopLoginBannerText([
          _device(id: 'w', platform: 'web', isOnline: false),
        ]),
        '已在网页端登录',
      );
      expect(
        buildDesktopLoginBannerText([
          _device(id: 'm', platform: 'macOS'),
        ]),
        '已在Mac登录',
      );
    });

    test('banner text multi prefers Web then 等登录', () {
      expect(
        buildDesktopLoginBannerText([
          _device(id: 'm', platform: 'macos', isOnline: false),
          _device(id: 'w', platform: 'web', isOnline: false),
          _device(id: 'win', platform: 'windows', isOnline: false),
        ]),
        '已在网页端等登录',
      );
    });

    test('banner text empty when none', () {
      expect(
        buildDesktopLoginBannerText([
          _device(id: 'phone', platform: 'iOS', isCurrent: true),
        ]),
        isNull,
      );
    });
  });
}
