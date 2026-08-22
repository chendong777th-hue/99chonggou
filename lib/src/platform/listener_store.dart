import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/location_upload_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_focus_service.dart';
import 'package:tencent_cloud_chat_demo/src/platform/tim_web_script_loader.dart';
import 'package:tencent_cloud_chat_demo/src/platform/web_im_realtime_watchdog.dart';

class ListenerStore {
  ListenerStore._();

  static Future<void> afterLogin() async {
    FriendRequestNoticeService.instance.ensureRunning();
    if (kIsWeb) {
      // Web 不挂系统推送监听，但仍需保证 TIM JS MESSAGE_RECEIVED / 会话监听在线。
      TimWebScriptLoader.rebindRealtimeListeners();
      WebImRealtimeWatchdog.start();
    } else {
      await NotificationSettingsService.instance.ensureListenersAttached(
        forceMessageListener: true,
      );
    }
    unawaited(
      LocationUploadService.instance.maybeUpload(reason: 'after_login'),
    );
  }

  static Future<void> beforeLogout() async {
    if (kIsWeb) {
      WebImRealtimeWatchdog.stop();
    }
    LocationUploadService.instance.clearSessionState();
    await PushFocusService.instance.clearOnLogout();
    await FriendRequestNoticeService.instance.stop();
    await NotificationSettingsService.instance.resetForLogout();
    ActiveChatRegistry.instance.reset();
  }
}
