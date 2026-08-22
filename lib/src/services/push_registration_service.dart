import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/push_token_api.dart';
import 'package:tencent_cloud_chat_demo/src/platform/push_handler.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/android_jpush_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/android_keep_alive_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/ios_apns_push_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_token_local/push_token_upload_local_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

/// 登录成功后同步自建 Push token（后端接口不变：/me/push-token）。
class PushRegistrationService {
  PushRegistrationService._();

  static final PushRegistrationService instance = PushRegistrationService._();

  /// IM logout 后 loginUser 可能已空；登出前由 [rememberLogoutOwner] 固定。
  String? _pendingLogoutOwnerUserId;

  /// 在 clearToken / IM logout 之前调用，供后续本地 push 清盘按号隔离。
  void rememberLogoutOwner(String? ownerUserId) {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    _pendingLogoutOwnerUserId = owner;
  }

  @visibleForTesting
  String? debugPendingLogoutOwnerUserId() => _pendingLogoutOwnerUserId;

  @visibleForTesting
  void debugResetPendingLogoutOwner() {
    _pendingLogoutOwnerUserId = null;
  }

  Future<void> syncAfterLogin({LocalSetting? settings}) async {
    if (kIsWeb || !IMDemoConfig.selfHostedPushEnabled) {
      return;
    }
    await ApiClient.instance.ensureDeviceIdReady();
    if (!ApiClient.isValidJwt(ApiClient.instance.token)) {
      return;
    }

    final localSetting = settings;
    if (localSetting != null &&
        !PushHandler.needsTimPush(localSetting)) {
      return;
    }

    await NotificationSettingsService.instance.applyFromSettings();

    if (Platform.isIOS) {
      final loginRes = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
      final userId = loginRes.data?.trim() ?? '';
      if (userId.isNotEmpty) {
        await IosApnsPushService.instance.syncLoginUserId(userId);
      }
      await IosApnsPushService.instance.syncTokens(reason: 'login_success');
      return;
    }
    if (Platform.isAndroid && IMDemoConfig.androidJPushEnabled) {
      await AndroidJPushService.instance.syncRegistrationId(
        reason: 'login_success',
      );
    }
  }

  /// 文档 11.3 第一步：先 DELETE /me/push-token（需在 IM logout 前、JWT 仍有效时调用）。
  Future<void> deletePushTokenBeforeImLogout() async {
    if (kIsWeb || !IMDemoConfig.selfHostedPushEnabled) {
      return;
    }
    // JWT/IM 仍可能可用：尽量记住 owner，避免后续 clearLocal 落到空号。
    final fromStore =
        ChatIdFormat.rawUserUid(PushTokenUploadLocalStore.instance.currentOwnerUserId());
    final liveOwner = fromStore.isNotEmpty
        ? fromStore
        : ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
    rememberLogoutOwner(liveOwner);

    if (!ApiClient.isValidJwt(ApiClient.instance.token)) {
      return;
    }
    final shouldDelete = Platform.isIOS ||
        (Platform.isAndroid && IMDemoConfig.androidJPushEnabled);
    if (!shouldDelete) {
      return;
    }
    await ApiClient.instance.ensureDeviceIdReady();
    try {
      await PushTokenApi.instance.deleteCurrentDeviceToken();
      if (kDebugMode) {
        debugPrint('PushRegistration: DELETE /me/push-token ok');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PushRegistration: DELETE /me/push-token failed ($e)');
      }
    }
  }

  /// 文档 11.3 第三步：IM logout 后停止 Android 前台保活服务。
  Future<void> stopForegroundServiceOnLogout() async {
    if (!Platform.isAndroid) {
      return;
    }
    await AndroidKeepAliveService.instance.stop(reason: 'logout');
  }

  /// 清理本地 Push 状态（服务端 token 应已由 [deletePushTokenBeforeImLogout] 删除）。
  ///
  /// 多账号共存：只按 pending/current owner 删行；owner 空时跳过 SQLite，禁止 clearAll。
  Future<void> clearLocalPushStateOnLogout() async {
    if (kIsWeb || !IMDemoConfig.selfHostedPushEnabled) {
      return;
    }
    final pending = ChatIdFormat.rawUserUid(_pendingLogoutOwnerUserId);
    final current =
        ChatIdFormat.rawUserUid(PushTokenUploadLocalStore.instance.currentOwnerUserId());
    final owner = pending.isNotEmpty ? pending : current;
    _pendingLogoutOwnerUserId = null;
    if (owner.isNotEmpty) {
      await PushTokenUploadLocalStore.instance.clearForOwner(owner);
    }
    if (Platform.isIOS) {
      await IosApnsPushService.instance.clearLocalStateOnLogout();
      return;
    }
    if (Platform.isAndroid) {
      await AndroidJPushService.instance.clearLocalStateOnLogout();
    }
  }

  Future<void> unregisterForLogout() async {
    await deletePushTokenBeforeImLogout();
    await clearLocalPushStateOnLogout();
    await stopForegroundServiceOnLogout();
  }
}
