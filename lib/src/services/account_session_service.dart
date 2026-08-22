// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/platform/listener_store.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/starred_friend_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/user_sticker_provider.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/agent_identity_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_background_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/privileged_game_user_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/sangong_my_config_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_entity_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_entry_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_bootstrap.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_system_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_preview_text_cache.dart';
import 'package:tencent_cloud_chat_demo/src/services/archived_conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_folder_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/desktop_login_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_session_cache.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/local_account_data_purge.dart';
import 'package:tencent_cloud_chat_demo/src/services/local_system_notification_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_registration_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/biometric_pay_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/constant.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_lifecycle_service.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_demo/src/services/call_lifecycle_service_web.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_peek_bootstrap.dart';
import 'package:tencent_cloud_chat_demo/src/services/c2c_friend_message_guard.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class AccountSessionService {
  AccountSessionService._();

  static const bool _sessionLogEnabled = false;

  void _sessionLog(String message) {
    if (!_sessionLogEnabled) return;
    print(message);
  }

  static final AccountSessionService instance = AccountSessionService._();

  Future<void>? _clearTask;

  Future<void> clearForLogout({
    String reason = 'logout',
    bool logoutIm = true,
    bool purgeOwnerDisk = false,
  }) {
    final running = _clearTask;
    if (running != null) {
      _sessionLog(
        'SESSION_LOG clearForLogout reuse '
        'reason=$reason logoutIm=$logoutIm purgeOwnerDisk=$purgeOwnerDisk',
      );
      return running;
    }

    _sessionLog(
      'SESSION_LOG clearForLogout schedule '
      'reason=$reason logoutIm=$logoutIm purgeOwnerDisk=$purgeOwnerDisk',
    );

    final task = _clear(
      reason: reason,
      logoutIm: logoutIm,
      purgeOwnerDisk: purgeOwnerDisk,
    );
    _clearTask = task.whenComplete(() {
      if (identical(_clearTask, task)) {
        _clearTask = null;
      }
    });
    return _clearTask!;
  }

  Future<void> _clear({
    required String reason,
    required bool logoutIm,
    required bool purgeOwnerDisk,
  }) async {
    final token = ApiClient.instance.token;
    final tokenValid = ApiClient.isValidJwt(token);
    // IM logout / clearToken 前固定 owner：注销清盘 + push 本地按号隔离共用。
    final logoutOwner =
        ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
    final ownerForPurge = purgeOwnerDisk ? logoutOwner : '';
    PushRegistrationService.instance.rememberLogoutOwner(logoutOwner);
    _sessionLog(
      'SESSION_LOG clear begin '
      'reason=$reason logoutIm=$logoutIm purgeOwnerDisk=$purgeOwnerDisk '
      'logoutOwner=$logoutOwner tokenValid=$tokenValid '
      'hasToken=${token != null && token.trim().isNotEmpty}',
    );
    ApiClient.instance.setLogoutInProgress(true);
    try {
      if (purgeOwnerDisk) {
        if (ownerForPurge.isEmpty) {
          _sessionLog(
            'SESSION_LOG purgeOwnerDisk skipped: empty owner '
            'reason=$reason',
          );
        } else {
          await _safe(
            () => LocalAccountDataPurge.instance.purgeOwnerDisk(ownerForPurge),
          );
        }
      }

      AuthSessionService.instance.resetAuthFlow();
      AuthBootstrapService.instance.resetImLoginState();
      AuthBootstrapService.instance.resetImSdkInitializationState(
        reason: reason,
      );
      PlatformOfficialAccountService.resetSessionState();

      // 11.3：先 DELETE /me/push-token，再退出 IM，最后停前台服务。
      await _safe(
        PushRegistrationService.instance.deletePushTokenBeforeImLogout,
      );

      if (logoutIm) {
        await _safe(() async {
          await TIMUIKitCore.getInstance().logout().timeout(
                const Duration(seconds: 6),
              );
        });
        await _safe(() async {
          await TencentImSDKPlugin.v2TIMManager.logout().timeout(
                const Duration(seconds: 6),
              );
        });
        await _safe(() async {
          await CallLifecycleService.instance.teardown().timeout(
                const Duration(seconds: 6),
              );
        });
      }

      await _safe(
        PushRegistrationService.instance.stopForegroundServiceOnLogout,
      );

      await _safe(
        () => ListenerStore.beforeLogout().timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        ),
      );

      await _safe(ApiClient.instance.clearToken);
      await _safe(ImSessionCache.instance.clear);
      await _safe(() => BiometricPayService.instance.disableAndClear());
      await _safe(_clearLegacyLoginPrefs);
      await _safe(LocalSystemNotificationService.instance.cancelAll);

      try {
        await FriendSyncService.instance.clearSession();
      } catch (_) {}
      try {
        await GroupMembershipSyncService.instance.clearSession();
      } catch (_) {}
      try {
        await GroupEntityIncrementalSyncService.instance.clearSession();
      } catch (_) {}
      try {
        GroupNoticeBootstrap.stopFallbackPolling();
      } catch (_) {}
      try {
        await GroupNoticeIncrementalSyncService.instance.clearSession();
      } catch (_) {}
      try {
        await GroupMemberIncrementalSyncService.instance.clearSession();
      } catch (_) {}
      try {
        GroupJoinApplicationService.instance.clearSession();
      } catch (_) {}
      try {
        GroupSystemNoticeService.instance.clearSession();
      } catch (_) {}
      try {
        GroupNoticeUnreadService.instance.clearSession();
      } catch (_) {}
      try {
        GroupNoticeEntrySettingsService.instance.clearSession();
      } catch (_) {}
      try {
        await ConversationSyncService.instance.clearSession();
      } catch (_) {}
      try {
        DesktopLoginSessionService.instance.clear();
      } catch (_) {}
      try {
        StarredFriendProvider.shared.clear();
      } catch (_) {}
      try {
        await ArchivedConversationSyncService.instance.clearSession();
      } catch (_) {}
      try {
        await ConversationFolderSyncService.instance.clearSession();
      } catch (_) {}
      try {
        await ConversationPinSyncService.instance.clearSession();
      } catch (_) {}
      try {
        PresenceProvider.clearActiveSessionState();
      } catch (_) {}
      try {
        UserStickerProvider.shared.clear();
      } catch (_) {}
      try {
        ChatBackgroundService.instance.clearSessionState();
      } catch (_) {}
      try {
        PrivilegedGameUserService.instance.clearSession();
      } catch (_) {}
      try {
        SangongMyConfigService.instance.clearSession();
      } catch (_) {}
      try {
        AgentIdentityService.instance.clearSession();
      } catch (_) {}

      try {
        DisplayNameStore.instance.clear(notify: false);
        GroupMemberStore.instance.clear(notify: false);
        ConversationPreviewTextCache.instance.clear();
      } catch (_) {}

      try {
        C2cFriendMessageGuard.clearSession();
      } catch (_) {}
      try {
        ChatHistoryPeekBootstrap.clearSession();
      } catch (_) {}
      try {
        MomentsSettingsService.instance.clearMemoryCache();
      } catch (_) {}

      try {
        serviceLocator<TUISearchViewModel>().clearSession(notify: false);
      } catch (_) {}
      try {
        serviceLocator<TUIConversationViewModel>().clearData();
      } catch (_) {}
      try {
        serviceLocator<TUIFriendShipViewModel>().clearData();
      } catch (_) {}
      try {
        serviceLocator<TUIChatGlobalModel>().clearData();
      } catch (_) {}

      ConversationRefreshBus.instance.requestRefresh(reason: reason);
      _sessionLog('SESSION_LOG clear finish reason=$reason');
    } finally {
      ApiClient.instance.setLogoutInProgress(false);
    }
  }

  Future<void> _clearLegacyLoginPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Const.DEV_LOGIN_USER_ID);
    await prefs.remove(Const.DEV_LOGIN_USER_SIG);
    await prefs.remove(Const.SMS_LOGIN_TOKEN);
    await prefs.remove(Const.SMS_LOGIN_PHONE);
  }

  Future<void> _safe(FutureOr<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (kDebugMode) {
        _sessionLog('AccountSessionService cleanup skipped: $e');
      }
    }
  }
}
