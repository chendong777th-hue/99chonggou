import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';

/// Push 注册与监听收口（委托 [NotificationSettingsService]）。
class PushPlatform {
  PushPlatform._();

  static NotificationSettingsService get service =>
      NotificationSettingsService.instance;

  static Future<void> applyFromSettings() => service.applyFromSettings();

  static Future<void> resetForLogout() => service.resetForLogout();
}
