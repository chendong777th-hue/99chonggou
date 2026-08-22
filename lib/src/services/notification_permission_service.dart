import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/android_battery_optimization_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

/// 系统通知权限的商业闭环：登录后引导授权、拒绝后设置页可跳转系统设置。
class NotificationPermissionService {
  NotificationPermissionService._();

  static final NotificationPermissionService instance =
      NotificationPermissionService._();

  Future<bool> isGranted() async {
    if (!PlatformUtils().isMobile) {
      return true;
    }
    final status = await Permission.notification.status;
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  Future<bool> isPermanentlyDenied() async {
    if (!PlatformUtils().isMobile) {
      return false;
    }
    final status = await Permission.notification.status;
    return status.isPermanentlyDenied || status.isRestricted;
  }

  Future<bool> requestSystemPermission() async {
    if (!PlatformUtils().isMobile) {
      return true;
    }
    try {
      var status = await Permission.notification.status;
      if (status.isGranted || status.isLimited || status.isProvisional) {
        return true;
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        return false;
      }
      status = await Permission.notification.request();
      return status.isGranted || status.isLimited || status.isProvisional;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationPermission: request failed ($e)');
      }
      return false;
    }
  }

  Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  /// 登录成功后：说明价值 → 请求权限 → 授权后注册自建 Push（APNs / 极光）。
  Future<void> ensureAfterLogin({
    required LocalSetting localSetting,
    BuildContext? context,
  }) async {
    if (!PlatformUtils().isMobile) {
      return;
    }

    if (await isGranted()) {
      await NotificationSettingsService.instance.applyFromSettings();
      await _ensureBatteryOptimizationGuided(
        localSetting: localSetting,
        context: context,
      );
      return;
    }

    if (localSetting.notificationPermissionPromptShown) {
      return;
    }
    localSetting.notificationPermissionPromptShown = true;

    final navContext = context ?? AppNavigator.context;
    if (navContext == null || !navContext.mounted) {
      final granted = await requestSystemPermission();
      if (granted) {
        await NotificationSettingsService.instance.applyFromSettings();
        await _ensureBatteryOptimizationGuided(
          localSetting: localSetting,
          context: context,
        );
      }
      return;
    }

    final i18n = AppI18n.of(navContext);
    final accepted = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '开启消息通知',
        zhHant: '開啟訊息通知',
        en: 'Enable Notifications',
        ja: '通知を有効にする',
        ko: '알림 사용',
      ),
      message: i18n.t(
        zhHans: '开启后可在锁屏和后台及时收到新消息与通话提醒。您可随时在系统设置中关闭。',
        zhHant: '開啟後可在鎖屏與背景及時收到新訊息與通話提醒。您可隨時在系統設定中關閉。',
        en: 'Get new messages and call alerts on the lock screen and in the background. You can turn this off anytime in system settings.',
        ja: 'ロック画面やバックグラウンドでも新着メッセージと通話通知を受け取れます。システム設定でいつでもオフにできます。',
        ko: '잠금 화면과 백그라운드에서도 새 메시지와 통화 알림을 받을 수 있습니다. 시스템 설정에서 언제든 끌 수 있습니다.',
      ),
      cancelText: i18n.t(
        zhHans: '暂不开启',
        zhHant: '暫不開啟',
        en: 'Not now',
        ja: '後で',
        ko: '나중에',
      ),
      confirmText: i18n.t(
        zhHans: '去开启',
        zhHant: '去開啟',
        en: 'Enable',
        ja: '有効にする',
        ko: '사용',
      ),
    );
    if (!accepted) {
      return;
    }

    final granted = await requestSystemPermission();
    if (granted) {
      await NotificationSettingsService.instance.applyFromSettings();
      await _ensureBatteryOptimizationGuided(
        localSetting: localSetting,
        context: navContext,
      );
      return;
    }

    if (await isPermanentlyDenied() && navContext.mounted) {
      await AppDialog.alert(
        title: i18n.t(
          zhHans: '通知权限未开启',
          zhHant: '通知權限未開啟',
          en: 'Notifications Disabled',
          ja: '通知が無効です',
          ko: '알림이 꺼져 있습니다',
        ),
        message: i18n.t(
          zhHans: '请在系统设置中为本应用开启通知，否则无法收到离线消息与通话提醒。',
          zhHant: '請在系統設定中為本應用開啟通知，否則無法收到離線訊息與通話提醒。',
          en: 'Turn on notifications for this app in system settings to receive offline messages and call alerts.',
          ja: 'オフラインのメッセージと通話通知を受け取るには、システム設定でこのアプリの通知をオンにしてください。',
          ko: '오프라인 메시지와 통화 알림을 받으려면 시스템 설정에서 이 앱의 알림을 켜 주세요.',
        ),
        buttonText: i18n.t(
          zhHans: '前往设置',
          zhHant: '前往設定',
          en: 'Open Settings',
          ja: '設定を開く',
          ko: '설정 열기',
        ),
      );
      await openSystemSettings();
    }
  }

  Future<void> _ensureBatteryOptimizationGuided({
    required LocalSetting localSetting,
    BuildContext? context,
  }) async {
    if (!Platform.isAndroid ||
        !IMDemoConfig.androidBatteryOptGuideEnabled ||
        localSetting.batteryOptimizationGuideShown) {
      return;
    }
    if (await AndroidBatteryOptimizationService.instance.isIgnoring()) {
      localSetting.batteryOptimizationGuideShown = true;
      return;
    }

    final navContext = context ?? AppNavigator.context;
    if (navContext == null || !navContext.mounted) {
      await AndroidBatteryOptimizationService.instance.requestIgnore();
      localSetting.batteryOptimizationGuideShown = true;
      return;
    }

    final i18n = AppI18n.of(navContext);
    final accepted = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '关闭电池优化',
        zhHant: '關閉電池優化',
        en: 'Disable Battery Optimization',
        ja: 'バッテリー最適化をオフ',
        ko: '배터리 최적화 끄기',
      ),
      message: i18n.t(
        zhHans: '为保证后台和 App 关闭后仍能收到消息，建议将 99chat 设为不受电池优化限制。',
        zhHant: '為確保背景及 App 關閉後仍能收到訊息，建議將 99chat 設為不受電池優化限制。',
        en: 'To keep receiving messages after the app is closed, allow 99chat to ignore battery optimization.',
        ja: 'アプリ終了後もメッセージを受け取るには、99chat のバッテリー最適化をオフにしてください。',
        ko: '앱을 종료한 뒤에도 메시지를 받으려면 99chat의 배터리 최적화 예외를 허용해 주세요.',
      ),
      cancelText: i18n.t(
        zhHans: '稍后',
        zhHant: '稍後',
        en: 'Later',
        ja: '後で',
        ko: '나중에',
      ),
      confirmText: i18n.t(
        zhHans: '去设置',
        zhHant: '去設定',
        en: 'Open Settings',
        ja: '設定へ',
        ko: '설정 열기',
      ),
    );
    localSetting.batteryOptimizationGuideShown = true;
    if (!accepted) {
      return;
    }
    await AndroidBatteryOptimizationService.instance.requestIgnore();
  }
}
