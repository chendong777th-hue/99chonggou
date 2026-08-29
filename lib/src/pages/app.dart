// ignore_for_file: avoid_print, prefer_typing_uninitialized_variables, unused_import,  prefer_final_fields, unused_field

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:tencent_chat_i18n_tool/tools/i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/chat.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/launch_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/home_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/login.dart';
import 'package:tencent_cloud_chat_demo/src/api/presence_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_diagnostics.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_recovery_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_host.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lock_profile_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/account_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_sdk_app_id_resolver.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_session_cache.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_error.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_connect_status_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_recovery_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/location_upload_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/network_status_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/device_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/resume_foreground_policy.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/app_search_bar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/forward_pick_pages.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_mutual_utils.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_image_message_prefetch.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/platform/listener_store.dart';
import 'package:tencent_cloud_chat_demo/src/platform/tim_web_script_loader.dart';
import 'package:tencent_cloud_chat_demo/src/platform/uikit_avatar_preview_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/platform/web_im_realtime_watchdog.dart';
import 'package:tencent_cloud_chat_demo/src/provider/custom_sticker_package.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/language_switch_sheet.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/routes.dart';
import 'package:tencent_cloud_chat_demo/utils/constant.dart';
import 'package:tencent_cloud_chat_demo/utils/init_step.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_config.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/emoji.dart';
import 'package:audio_session/audio_session.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/sound_record.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/sound_player_voice_route_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_output_route_service.dart';

bool isInitScreenUtils = false;

class TencentChatApp extends StatefulWidget {
  const TencentChatApp({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _TencentChatAppState();
}

class _TencentChatAppState extends State<TencentChatApp>
    with WidgetsBindingObserver {
  void _sessionLog(String message) {
    SessionDiagnostics.log(message);
  }

  var subscription;
  final CoreServicesImpl _coreInstance = TIMUIKitCore.getInstance();
  final V2TIMManager _sdkInstance = TIMUIKitCore.getSDKInstance();
  final ConversationService _conversationService =
      serviceLocator<ConversationService>();
  bool _initialURILinkHandled = false;
  bool _isInitIMSDK = false;
  int? _initializedSdkAppId;
  BuildContext? cachedBuildContext;
  VoidCallback? _routeListener;
  PresenceProvider? _presence;
  Timer? _resumeTimer;
  Timer? _resumePhase1Timer;
  Timer? _resumePhase2Timer;
  Future<void>? _resumeTask;
  DateTime? _lastResumeCheckAt;
  DateTime? _lastLoggedInSideEffectAt;
  DateTime? _lastForegroundRecoveryAt;
  DateTime? _lastEnteredBackgroundAt;
  Future<bool>? _officialAccountTask;
  bool _refreshingUserSig = false;
  Timer? _splashWatchdog;
  Future<void>? _initSdkTask;
  int _startupAttempt = 0;
  bool _startupSettled = false;

  static const Duration _connectSuccessDedupWindow = Duration(seconds: 20);
  static const Duration _resumeCheckDelay = Duration(milliseconds: 200);
  static const Duration _loggedInSideEffectMinInterval = Duration(seconds: 12);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _presence = Provider.of<PresenceProvider>(context, listen: false);
    } catch (_) {
      _presence = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    scheduleSqfliteLifecycle(state);
    ChatImageMessagePrefetch.handleAppLifecycleState(state);
    SqfliteLockProfileLog.lifecycle(state);
    NotificationSettingsService.instance.setLifecycle(state);
    DeviceSyncService.instance.setAppLifecycle(state);
    FriendRequestNoticeService.instance.onAppLifecycleChanged(state);

    if (state == AppLifecycleState.resumed) {
      if (kIsWeb) {
        unawaited(
            WebImRealtimeWatchdog.catchUpNow(reason: 'lifecycle_resumed'));
      }
      _scheduleResumeCheck();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ChatHistoryRecoveryCoordinator.instance.invalidateLifecycle();
      ConversationSyncService.instance.invalidateLifecycle();
      _lastEnteredBackgroundAt = DateTime.now();
      _resumeTimer?.cancel();
      _resumePhase1Timer?.cancel();
      _resumePhase2Timer?.cancel();
      _presence?.stopHeartbeat();
      unawaited(SoundPlayer.stop());
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (kDebugMode) {
      FriendRequestNoticeService.instance.ensureRunning();
    }
    if (kIsWeb) {
      WebImRealtimeWatchdog.start();
      unawaited(WebImRealtimeWatchdog.catchUpNow(reason: 'reassemble'));
      unawaited(ListenerStore.afterLogin());
    }
  }

  void _scheduleResumeCheck() {
    final now = DateTime.now();
    final last = _lastResumeCheckAt;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return;
    }

    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeCheckDelay, () {
      if (!mounted) return;
      _lastResumeCheckAt = DateTime.now();
      _resumeTask ??= _checkIfConnected().whenComplete(() {
        _resumeTask = null;
      });
    });
  }

  Future<void> _checkIfConnected() async {
    final sessionGeneration = SessionIdentityService.instance.generation;
    final recovery = await LoginCoordinator.instance.recoverOnForeground();
    if (!mounted ||
        !SessionIdentityService.instance
            .isGenerationCurrent(sessionGeneration)) {
      return;
    }

    switch (recovery.action) {
      case LoginRecoveryAction.goLogin:
        if (AuthSessionService.instance.isInAuthFlow) return;
        InitStep.directToLogin(cachedBuildContext ?? context);
        return;
      case LoginRecoveryAction.stayOnHome:
      case LoginRecoveryAction.goHome:
        ImConnectStatusService.beginSocketHandshake(
          context: cachedBuildContext ?? context,
        );
        if (NetworkStatusService.instance.status.value ==
            NetworkReachability.offline) {
          _setConnectStatus(ConnectStatus.connecting);
        } else {
          unawaited(
            ImConnectStatusService.reconcileAfterNetworkOnline(
              cachedBuildContext ?? context,
              gracePeriod: const Duration(seconds: 12),
            ),
          );
        }
        _lastForegroundRecoveryAt = DateTime.now();
        _onImLoggedInForSession(
          runForegroundRecovery: true,
          expectedIdentity: SessionIdentityService.instance.capture(
            ownerUserId: recovery.userId,
          ),
        );
        return;
      case LoginRecoveryAction.restartColdStart:
        await initIMSDKAndAddIMListeners();
        if (!mounted) return;
        unawaited(
          InitStep.checkLogin(
            cachedBuildContext ?? context,
            initIMSDKAndAddIMListeners,
          ),
        );
        return;
    }
  }

  void _setConnectStatus(ConnectStatus status) {
    if (!mounted) return;
    try {
      Provider.of<LocalSetting>(context, listen: false).connectStatus = status;
    } catch (_) {}
  }

  void _onImLoggedInForSession({
    required bool runForegroundRecovery,
    required SessionIdentity expectedIdentity,
    int? listenerEpoch,
  }) {
    bool isCurrent() =>
        _isListenerSessionCurrent(expectedIdentity, listenerEpoch);
    if (!isCurrent()) {
      return;
    }
    _presence?.startHeartbeat();
    unawaited(ListenerStore.afterLogin(expectedIdentity: expectedIdentity));
    unawaited(
        NotificationSettingsService.instance.consumePendingConversationOpen());
    if (runForegroundRecovery) {
      _runLoggedInSideEffects(
        expectedIdentity: expectedIdentity,
        listenerEpoch: listenerEpoch,
      );
    }
  }

  bool _isListenerSessionCurrent(
    SessionIdentity identity,
    int? listenerEpoch,
  ) {
    return (listenerEpoch == null ||
            AuthBootstrapService.instance.isImListenerEpochCurrent(
              listenerEpoch,
            )) &&
        SessionIdentityService.instance.isCurrent(identity);
  }

  bool _shouldSkipConnectSuccessRecovery() {
    final last = _lastForegroundRecoveryAt;
    if (last == null) {
      return false;
    }
    return DateTime.now().difference(last) < _connectSuccessDedupWindow;
  }

  void _runLoggedInSideEffects({
    required SessionIdentity expectedIdentity,
    int? listenerEpoch,
  }) {
    bool isCurrent() =>
        _isListenerSessionCurrent(expectedIdentity, listenerEpoch);
    if (!isCurrent()) {
      return;
    }
    unawaited(ListenerStore.afterLogin(expectedIdentity: expectedIdentity));
    final backgroundAt = _lastEnteredBackgroundAt;
    _lastEnteredBackgroundAt = null;
    final background =
        backgroundAt == null ? null : DateTime.now().difference(backgroundAt);
    final intensity = ResumeForegroundPolicy.intensityFor(background);

    ConversationRefreshBus.instance.hold(
      duration: ConversationPerfFlags.resumeQuietDuration > Duration.zero
          ? ConversationPerfFlags.resumeQuietDuration
          : ResumeForegroundPolicy.conversationHoldDuration,
      reason: 'app_resumed',
    );
    ConversationSyncService.instance.beginResumeQuietWindow(
      duration: ConversationPerfFlags.resumeQuietDuration > Duration.zero
          ? ConversationPerfFlags.resumeQuietDuration
          : ResumeForegroundPolicy.conversationHoldDuration,
    );

    final now = DateTime.now();
    final last = _lastLoggedInSideEffectAt;
    if (last != null && now.difference(last) < _loggedInSideEffectMinInterval) {
      return;
    }
    _lastLoggedInSideEffectAt = now;

    unawaited(PresenceApi.instance.heartbeat().catchError((_) {}));

    _resumePhase1Timer?.cancel();
    _resumePhase2Timer?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !isCurrent()) return;
      _resumePhase1Timer = Timer(ResumeForegroundPolicy.phase1Delay, () {
        if (!mounted || !isCurrent()) return;
        unawaited(() async {
          if (!isCurrent()) return;
          await NotificationSettingsService.instance.applyFromSettings();
          if (!isCurrent()) return;
          await NotificationSettingsService.instance
              .consumePendingConversationOpen();
          if (!isCurrent()) return;
          await ImRecoveryService.instance.afterOnline(
            reason: 'app_resumed',
            intensity: intensity,
          );
          if (!isCurrent()) return;
        }()
            .catchError((_) {}));
      });

      _resumePhase2Timer = Timer(ResumeForegroundPolicy.phase2Delay, () {
        if (!mounted || !isCurrent()) return;
        DeviceSyncService.instance.onAppResumed();
        if (isCurrent() &&
            ResumeForegroundPolicy.shouldRunHeavySideEffects(intensity)) {
          unawaited(
            LocationUploadService.instance.maybeUpload(reason: 'app_resumed'),
          );
          _scheduleOfficialAccountEnsure();
        }
      });
    });
  }

  void _scheduleOfficialAccountEnsure() {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) {
      return;
    }
    _officialAccountTask ??= Future<void>.delayed(
      Duration.zero,
    )
        .then((_) async {
          if (!SessionIdentityService.instance.isCurrent(identity)) {
            return false;
          }
          final login = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
          final userId = login.data?.trim() ?? '';
          if (userId.isEmpty ||
              userId != identity.ownerUserId ||
              !SessionIdentityService.instance.isCurrent(identity)) {
            return false;
          }
          await PlatformOfficialAccountService.loadDismissedState();
          if (!SessionIdentityService.instance.isCurrent(identity)) {
            return false;
          }
          return PlatformOfficialAccountService.ensureSubscribed();
        })
        .catchError((_) => false)
        .whenComplete(() {
          _officialAccountTask = null;
        });
  }

  Future<void> onKickedOffline({
    bool updateLoginState = true,
    SessionIdentity? expectedIdentity,
  }) async {
    try {
      if (expectedIdentity == null &&
          AuthSessionService.instance.isInAuthFlow) {
        return;
      }
      final identity =
          expectedIdentity ?? SessionIdentityService.instance.capture();
      if (identity.ownerUserId.isEmpty ||
          !SessionIdentityService.instance.isCurrent(identity)) {
        return;
      }
      if (updateLoginState) {
        LoginCoordinator.instance.markKickedOffline(
          message: TIM_t("您的账号已在其它终端登录"),
        );
      }
      if (!SessionIdentityService.instance.isCurrent(identity)) {
        return;
      }
      await AccountSessionService.instance.clearForLogout(
        reason: 'kicked_offline',
        expectedIdentity: identity,
      );
      if (mounted) {
        InitStep.directToLogin(cachedBuildContext ?? context);
      }
      InitStep.removeLocalSetting();
    } catch (_) {}
  }

  Future<void> _confirmKickedOffline(
    SessionIdentity identity, {
    required int listenerEpoch,
  }) async {
    // The SDK callback has no user id. Give an account-boundary logout a
    // chance to finish, then reject callbacks that belong to a superseded
    // session before touching token or local data.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted ||
        !AuthBootstrapService.instance
            .isImListenerEpochCurrent(listenerEpoch) ||
        !SessionIdentityService.instance.isCurrent(identity)) {
      return;
    }
    final nativeUserId =
        await AuthBootstrapService.instance.getNativeLoginUserId();
    if (nativeUserId == null || nativeUserId.isEmpty) {
      // This callback has no user id of its own. Without a live native owner
      // there is no safe account to clear.
      SessionDiagnostics.log('SESSION_LOG kick ignored native_owner_empty');
      return;
    }
    if (nativeUserId != identity.ownerUserId) {
      SessionDiagnostics.log(
        'SESSION_LOG kick ignored native_owner_changed '
        'captured=${identity.ownerUserId} native=$nativeUserId',
      );
      return;
    }
    if (!AuthBootstrapService.instance
            .isImListenerEpochCurrent(listenerEpoch) ||
        !SessionIdentityService.instance.isCurrent(identity) ||
        AuthSessionService.instance.isInAuthFlow) {
      return;
    }
    await onKickedOffline(expectedIdentity: identity);
  }

  Future<String> getLanguage() async {
    return "zh-Hans";
  }

  Future<void> getLoginUserInfo() async {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) {
      return;
    }
    final res = await _sdkInstance.getLoginUser();
    final nativeUserId = ChatIdFormat.rawUserUid(res.data);
    if (res.code == 0 &&
        nativeUserId == identity.ownerUserId &&
        SessionIdentityService.instance.isCurrent(identity)) {
      final result = await _sdkInstance.getUsersInfo(userIDList: [res.data!]);

      if (result.code == 0 &&
          result.data != null &&
          result.data!.isNotEmpty &&
          ChatIdFormat.rawUserUid(result.data!.first.userID) ==
              identity.ownerUserId &&
          SessionIdentityService.instance.isCurrent(identity)) {
        Provider.of<LoginUserInfo>(context, listen: false)
            .setLoginUserInfo(result.data![0]);
      }
    }
  }

  bool _shouldSuppressTUIKitToast(String? message) {
    if (ToastUtils.shouldSuppress(message)) return true;
    if (_shouldSuppressBenignSdkError(message)) {
      return true;
    }
    if (_shouldSuppressTransientImNotReadyError(message: message)) {
      return true;
    }
    final normalized = message?.trim().toLowerCase() ?? '';
    // The SDK sometimes reports a plain English "fail" while reconnecting.
    // It does not help users; the offline banner already shows the real state.
    return normalized == 'fail' || normalized == 'failed';
  }

  bool _shouldSuppressBenignSdkError(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.contains('illegal api') &&
        normalized.contains('setexcludefromhistorymessage');
  }

  void _showTUIKitToast(String? message) {
    if (_shouldSuppressTUIKitToast(message)) return;
    final text = message!.trim();
    final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
    ToastUtils.toast(
        hasChinese ? text : ToastUtils.friendlyErrorMessage(-1, text));
  }

  bool _shouldSuppressTransientImNotReadyError({
    int? code,
    String? message,
    String? recommendText,
  }) {
    final looksLikeNotLogin = code == 6013 ||
        code == 6014 ||
        _looksLikeImInitRaceText(message) ||
        _looksLikeImInitRaceText(recommendText) ||
        _looksLikeNotLoginText(message) ||
        _looksLikeNotLoginText(recommendText) ||
        _looksLikeReloginText(message) ||
        _looksLikeReloginText(recommendText);
    if (!looksLikeNotLogin) {
      return false;
    }

    final syncing = AuthBootstrapService.instance.backgroundSyncing.value;
    final uikitReady = AuthBootstrapService.instance.isCoreServicesUserReady();
    final transitional = syncing ||
        _refreshingUserSig ||
        AuthSessionService.instance.isInAuthFlow ||
        !uikitReady;
    if (!transitional) {
      return false;
    }

    return true;
  }

  bool _looksLikeImInitRaceText(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.contains('sdk not initialized') ||
        normalized.contains('sdk uninitialized') ||
        normalized.contains('sdk is not initialized') ||
        normalized.contains('not initialized') ||
        normalized.contains('未初始化') ||
        normalized.contains('初始化') && normalized.contains('失败') ||
        normalized.contains('6013');
  }

  bool _looksLikeReloginText(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.contains('登录失败') ||
        normalized.contains('登陆失败') ||
        normalized.contains('请重新登录') ||
        normalized.contains('请重新登陆') ||
        normalized.contains('重新登入') ||
        normalized.contains('登录已失效') ||
        normalized.contains('登录状态无效') ||
        normalized.contains('账号已过期') ||
        normalized.contains('session expired') ||
        normalized.contains('invalid session') ||
        normalized.contains('login failed') ||
        normalized.contains('log in again') ||
        normalized.contains('sign in again');
  }

  bool _looksLikeNotLoginText(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.contains('not login') ||
        normalized.contains('not logged in') ||
        normalized.contains('please login') ||
        normalized.contains('please log in') ||
        normalized.contains('login first') ||
        normalized.contains('未登录') ||
        normalized.contains('請先登入') ||
        normalized.contains('请先登录');
  }

  Future<void> _handleUserSigExpiredForIdentity(
    SessionIdentity expectedIdentity, {
    required int listenerEpoch,
  }) async {
    if (!AuthBootstrapService.instance
            .isImListenerEpochCurrent(listenerEpoch) ||
        !SessionIdentityService.instance.isCurrent(expectedIdentity)) {
      return;
    }
    if (_refreshingUserSig) return;
    _refreshingUserSig = true;
    LoginCoordinator.instance.markSessionRefreshing();
    _setConnectStatus(ConnectStatus.connecting);
    try {
      final ok = await AuthBootstrapService.instance.refreshUserSigAndRelogin();
      if (!AuthBootstrapService.instance
              .isImListenerEpochCurrent(listenerEpoch) ||
          !SessionIdentityService.instance.isCurrent(expectedIdentity)) {
        return;
      }
      if (ok) {
        final res = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
        LoginCoordinator.instance.markImReady(userId: res.data?.trim());
        _setConnectStatus(ConnectStatus.success);
        _onImLoggedInForSession(
          runForegroundRecovery: true,
          expectedIdentity: expectedIdentity,
          listenerEpoch: listenerEpoch,
        );
        return;
      }
      if (!AuthBootstrapService.instance.lastUserSigRefreshWasAuthFailure) {
        // 网络抖动或 IM 临时重连失败不能清空业务登录态。
        LoginCoordinator.instance.markFailed(
          LoginErrorType.imLoginFailed,
          message: 'UserSig refresh temporarily unavailable',
          isBusinessAuthenticated: true,
          isHomeEntered: true,
        );
        _setConnectStatus(ConnectStatus.failed);
        return;
      }
      LoginCoordinator.instance.markSessionExpired(
        message: TIM_t("账号已过期，请重新登录"),
      );
      ToastUtils.toast(TIM_t("账号已过期，请重新登录"));
      await onKickedOffline(
        updateLoginState: false,
        expectedIdentity: expectedIdentity,
      );
    } catch (e, st) {
      LoginCoordinator.instance.markFailed(
        LoginErrorType.imLoginFailed,
        message: 'Failed while refreshing userSig session',
        cause: e,
        stackTrace: st,
        isBusinessAuthenticated: true,
        isHomeEntered: true,
      );
      _setConnectStatus(ConnectStatus.failed);
    } finally {
      _refreshingUserSig = false;
    }
  }

  Future<void> initIMSDKAndAddIMListeners({int? sdkAppId}) async {
    final resolved = await _resolveImSdkAppId(sdkAppId);
    if (_initSdkTask != null) {
      _sessionLog('SESSION_LOG IM_INIT await_inflight');
      await _initSdkTask;
    }
    // 以本页 init 门闩为准：SDK 已按同 AppID 初始化时只同步标志，绝不因
    // AuthBootstrap 标志被误清而 UnInit（否则登录重试会拆掉仍在跑的 IM）。
    if (_isInitIMSDK &&
        _initializedSdkAppId == resolved &&
        AuthBootstrapService.imSdkInitialized &&
        AuthBootstrapService.initializedSdkAppId == resolved) {
      _sessionLog(
        'SESSION_LOG IM_INIT skip reason=already_initialized '
        'sdkAppId=$resolved',
      );
      return;
    }
    if (_isInitIMSDK &&
        (!AuthBootstrapService.imSdkInitialized ||
            AuthBootstrapService.initializedSdkAppId != resolved)) {
      // Another account boundary may have called unInitSDK. The per-widget
      // marker must follow the native SDK, otherwise the next login returns
      // early without actually initializing it again.
      _isInitIMSDK = false;
      _initializedSdkAppId = null;
      _sessionLog('SESSION_LOG IM_INIT local marker stale; reinitialize');
    }
    final needsTeardown = _isInitIMSDK ||
        AuthBootstrapService.imSdkInitialized ||
        _initializedSdkAppId != null;
    if (needsTeardown) {
      final reason =
          (_initializedSdkAppId != null && _initializedSdkAppId != resolved)
              ? 'sdk_app_id_changed_${_initializedSdkAppId}_to_$resolved'
              : 'reinit_before_init_$resolved';
      await _teardownImSdkForReinit(reason: reason);
    }
    _sessionLog('SESSION_LOG IM_INIT start sdkAppId=$resolved');
    ImConnectStatusService.resetLaunchSession();
    _initSdkTask = _initIMSDKAndAddIMListenersImpl(resolved);
    try {
      await _initSdkTask;
    } finally {
      _initSdkTask = null;
    }
  }

  Future<int> _resolveImSdkAppId(int? preferred) async {
    final cached = await ImSessionCache.instance.readCachedSdkAppId();
    return resolveImSdkAppId(preferred: preferred, cached: cached);
  }

  Future<void> _teardownImSdkForReinit({required String reason}) async {
    _sessionLog('SESSION_LOG IM_INIT teardown reason=$reason');
    AuthBootstrapService.instance.invalidateImListenerEpoch();
    try {
      await _coreInstance.logout().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await _coreInstance.unInit();
    } catch (e) {
      _sessionLog('SESSION_LOG IM_INIT unInit error: $e');
    }
    _isInitIMSDK = false;
    _initializedSdkAppId = null;
    AuthBootstrapService.instance.resetImSdkInitializationState(
      reason: reason,
    );
  }

  Future<void> _initIMSDKAndAddIMListenersImpl(int sdkAppId) async {
    if (_isInitIMSDK &&
        AuthBootstrapService.imSdkInitialized &&
        _initializedSdkAppId == sdkAppId) {
      return;
    }
    _isInitIMSDK = true;
    final listenerEpoch =
        AuthBootstrapService.instance.registerImListenerEpoch();
    final rootContext = AppNavigator.context ?? cachedBuildContext;
    if (rootContext == null) {
      _isInitIMSDK = false;
      _sessionLog(
          'SESSION_LOG IM_INIT done success=false reason=no_root_context');
      return;
    }
    final LocalSetting localSetting =
        Provider.of<LocalSetting>(rootContext, listen: false);
    await localSetting.loadSettingsFromLocal();
    final language = LocalSetting.normalizeLanguage(localSetting.language);
    localSetting.updateLanguageWithoutWriteLocal(language);
    LocaleSettings.setLocale(LanguageSwitchSheet.toAppLocale(language));

    if (PlatformUtils().isWeb) {
      await TimWebScriptLoader.ensureLoaded();
    }

    String? logPath;
    if (!PlatformUtils().isWeb) {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final packageInfo = await PackageInfo.fromPlatform();
      final pkgName = packageInfo.packageName;
      final timeName =
          "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
      logPath = p.join(documentsDirectory.path, ".TencentCloudChat", pkgName,
          "uikit_log", 'Flutter-TUIKit-$timeName.log');
    }

    final isInitSuccess = await _coreInstance.init(
      onWebLoginSuccess: getLoginUserInfo,
      uikitLogPath: logPath,
      config: TIMUIKitConfig(
        isShowOnlineStatus: true,
        isCheckDiskStorageSpace: true,
        defaultAvatarAssetPath: 'assets/default_group_avatar.svg',
        defaultAvatarBorderRadius: BorderRadius.all(Radius.circular(999)),
        shouldHideUserFromPickers:
            PlatformOfficialAccountService.shouldHideFromContactAndPickers,
        saveAvatarPreview: UikitAvatarPreviewBridge.savePreview,
        prepareWebAvatarPreviewUrl:
            UikitAvatarPreviewBridge.prepareWebPreviewUrl,
      ),
      onTUIKitCallbackListener: (TIMCallback callbackValue) {
        switch (callbackValue.type) {
          case TIMCallbackType.INFO:
            _showTUIKitToast(callbackValue.infoRecommendText);
            break;
          case TIMCallbackType.API_ERROR:
            // SDK/API 错误不再弹全局提示。用户可感知的业务提示由具体页面自行处理，
            // 避免 IM 内部重连、下载、查找消息等错误打断聊天体验。
            return;

          case TIMCallbackType.FLUTTER_ERROR:
          default:
            // Flutter/SDK 内部异常统一静默，不弹全局错误框。
            return;
        }
      },
      sdkAppID: sdkAppId,
      // 关闭 IM SDK 控制台日志（含 debug）；需要排查时再改回 V2TIM_LOG_DEBUG。
      loglevel: LogLevelEnum.V2TIM_LOG_NONE,
      listener: V2TimSDKListener(
        onConnectFailed: (code, error) {
          if (!AuthBootstrapService.instance
              .isImListenerEpochCurrent(listenerEpoch)) {
            return;
          }
          ImConnectStatusService.markSocketDisconnected();
          if (NetworkStatusService.instance.status.value ==
              NetworkReachability.offline) {
            _setConnectStatus(ConnectStatus.connecting);
            return;
          }
          if (LoginCoordinator.instance.state.isImReady) {
            _setConnectStatus(ConnectStatus.connecting);
            return;
          }
          _setConnectStatus(ConnectStatus.failed);
        },
        onConnectSuccess: () {
          if (!AuthBootstrapService.instance
              .isImListenerEpochCurrent(listenerEpoch)) {
            return;
          }
          final connectListenerEpoch = listenerEpoch;
          final connectIdentity = SessionIdentityService.instance.capture();
          if (connectIdentity.ownerUserId.isEmpty ||
              !_isListenerSessionCurrent(
                connectIdentity,
                connectListenerEpoch,
              )) {
            return;
          }
          bool isCurrent() => _isListenerSessionCurrent(
                connectIdentity,
                connectListenerEpoch,
              );
          if (kIsWeb) {
            // 先尽量重绑（listener 已在则立刻生效）；afterLogin 后再 force 一次，
            // 覆盖「连接成功时 Dart listener 尚未挂上」的竞态。
            TimWebScriptLoader.rebindRealtimeListeners();
            unawaited(
              ListenerStore.afterLogin(expectedIdentity: connectIdentity)
                  .then((_) {
                if (isCurrent()) {
                  TimWebScriptLoader.rebindRealtimeListeners();
                }
              }),
            );
          }
          final needsCatchUp =
              ImConnectStatusService.consumeNeedsHistoryCatchUp();
          ImConnectStatusService.onSdkConnectSuccess(
            context: cachedBuildContext ?? context,
          );
          if (!isCurrent()) return;
          LoginCoordinator.instance.markImReady();
          if (kIsWeb) {
            // 首屏先渲染，再补会话列表，避免与 bootstrap 抢主线程。
            // 断线重连时也要 reset 补拉，避免漏掉断线窗口内的会话更新。
            unawaited(
              Future<void>.delayed(const Duration(milliseconds: 400), () {
                if (!isCurrent()) return Future<void>.value();
                return ConversationSyncService.instance.syncFromSdk(
                  reason: needsCatchUp
                      ? 'web_im_reconnected'
                      : 'web_connect_success',
                  reset: true,
                  drainMode: ConversationSdkDrainMode.foregroundLimited,
                );
              }),
            );
          }
          if (!ImConnectStatusService.isHandshakePending) {
            _setConnectStatus(ConnectStatus.success);
          }
          final recoveryReason =
              needsCatchUp ? 'im_reconnected' : 'connect_success';
          if (_shouldSkipConnectSuccessRecovery() && !needsCatchUp) {
            if (!kIsWeb) {
              unawaited(
                Future<void>(() async {
                  if (!isCurrent()) return;
                  await ListenerStore.afterLogin(
                    expectedIdentity: connectIdentity,
                  );
                }),
              );
            }
            unawaited(
              Future<void>(() async {
                if (!isCurrent()) return;
                await ImRecoveryService.instance
                    .refreshForegroundChatIfNeeded(reason: recoveryReason);
              }),
            );
            return;
          }
          ToastUtils.log(TIM_t("即时通信服务连接成功"));
          _onImLoggedInForSession(
            runForegroundRecovery: true,
            expectedIdentity: connectIdentity,
            listenerEpoch: connectListenerEpoch,
          );
          if (needsCatchUp) {
            unawaited(
              Future<void>(() async {
                if (!isCurrent()) return;
                await ImRecoveryService.instance.refreshForegroundChatIfNeeded(
                  reason: 'im_reconnected',
                );
              }),
            );
          }
        },
        onConnecting: () {
          if (!AuthBootstrapService.instance
              .isImListenerEpochCurrent(listenerEpoch)) {
            return;
          }
          if (AuthSessionService.instance.isInAuthFlow) return;
          ImConnectStatusService.onSdkConnecting(
            context: cachedBuildContext ?? context,
          );
          _setConnectStatus(ConnectStatus.connecting);
        },
        onKickedOffline: () {
          if (!AuthBootstrapService.instance
              .isImListenerEpochCurrent(listenerEpoch)) {
            return;
          }
          if (AuthSessionService.instance.isInAuthFlow) {
            return;
          }
          final identity = SessionIdentityService.instance.capture();
          if (identity.ownerUserId.isEmpty) {
            return;
          }
          ToastUtils.toast(TIM_t("您的账号已在其它终端登录"));
          unawaited(
            _confirmKickedOffline(
              identity,
              listenerEpoch: listenerEpoch,
            ),
          );
        },
        onSelfInfoUpdated: (info) {
          if (!AuthBootstrapService.instance
              .isImListenerEpochCurrent(listenerEpoch)) {
            return;
          }
          final current = SessionIdentityService.instance.capture();
          final infoUserId = ChatIdFormat.rawUserUid(info.userID);
          if (current.ownerUserId.isEmpty ||
              infoUserId.isEmpty ||
              current.ownerUserId != infoUserId) {
            return;
          }
          Provider.of<LoginUserInfo>(rootContext, listen: false)
              .setLoginUserInfo(info);
        },
        onUserSigExpired: () {
          if (!AuthBootstrapService.instance
              .isImListenerEpochCurrent(listenerEpoch)) {
            return;
          }
          final identity = SessionIdentityService.instance.capture();
          if (identity.ownerUserId.isNotEmpty) {
            unawaited(
              _handleUserSigExpiredForIdentity(
                identity,
                listenerEpoch: listenerEpoch,
              ),
            );
          }
        },
        onUserStatusChanged: (statusList) {
          if (!AuthBootstrapService.instance
              .isImListenerEpochCurrent(listenerEpoch)) {
            return;
          }
          final ids =
              statusList.map((s) => s.userID).whereType<String>().toList();
          if (ids.isEmpty) return;
          _presence?.refresh(ids, urgent: true);
        },
      ),
    );
    if (isInitSuccess == null || !isInitSuccess) {
      _isInitIMSDK = false;
      _initializedSdkAppId = null;
      AuthBootstrapService.imSdkInitialized = false;
      AuthBootstrapService.initializedSdkAppId = null;
      _sessionLog(
        'SESSION_LOG IM_INIT done success=false sdkAppId=$sdkAppId',
      );
      ToastUtils.toast(TIM_t("即时通信 SDK初始化失败"));
      return;
    }
    _initializedSdkAppId = sdkAppId;
    AuthBootstrapService.initializedSdkAppId = sdkAppId;
    AuthBootstrapService.imSdkInitialized = true;
    _sessionLog(
      'SESSION_LOG IM_INIT done success=true sdkAppId=$sdkAppId',
    );
    serviceLocator<TUIChatGlobalModel>().appSearchBarBuilder =
        (context, controller, onChanged) {
      return buildAppSearchBarInset(
        context: context,
        controller: controller,
        onChanged: onChanged,
      );
    };
    installForwardPickPages();
    serviceLocator<TUIChatGlobalModel>().appContactPresenceBridgeBuilder =
        (context) {
      final localSetting = Provider.of<LocalSetting>(context, listen: false);
      if (!localSetting.isShowOnlineStatus) {
        return const AppContactPresenceBridge();
      }
      final presence = Provider.of<PresenceProvider>(context, listen: false);
      final friendship = serviceLocator<TUIFriendShipViewModel>();
      return AppContactPresenceBridge(
        presenceListenable: presence,
        presenceLabelBuilder: (userId, imOnline) => presence.listLabelFor(
          userId: userId,
          imOnline: imOnline,
          isMutualFriend: friendCanMessage(friendship, userId),
        ),
        presenceLoadingChecker: (userId, imOnline) =>
            presence.isLastSeenLoading(userId: userId, imOnline: imOnline),
        presenceOnlineResolver: (userId, imOnline) =>
            presence.resolveOnline(userId: userId, imOnline: imOnline),
        onContactListLoaded: (userIds) {
          presence.ensure(userIds);
        },
      );
    };
    if (!PlatformUtils().isWeb) {
      unawaited(
        NotificationSettingsService.instance.ensureListenersAttached(),
      );
    }
  }

  void initApp() {
    final attempt = ++_startupAttempt;
    _startupSettled = false;
    _splashWatchdog?.cancel();
    _splashWatchdog = Timer(const Duration(seconds: 12), () {
      unawaited(_escalateIfStillOnSplash(attempt));
    });
    final startup = InitStep.checkLogin(context, initIMSDKAndAddIMListeners);
    unawaited(startup.whenComplete(() {
      if (!mounted || attempt != _startupAttempt) return;
      _startupSettled = true;
      _splashWatchdog?.cancel();
      _splashWatchdog = null;
      _sessionLog('SESSION_LOG startup settled attempt=$attempt');
    }));
  }

  initScreenUtils() {
    if (isInitScreenUtils) return;

    ScreenUtil.init(
      context,
      designSize: const Size(750, 1624),
      minTextAdapt: true,
    );
    isInitScreenUtils = true;
  }

  initRouteListener() {
    if (_routeListener != null) return;
    final routes = Routes();
    void listener() {
      final pageType = routes.pageType;
      if (pageType == "loginPage") {
        InitStep.directToLogin(cachedBuildContext ?? context);
      }

      if (pageType == "homePage") {
        InitStep.directToHomePage(cachedBuildContext ?? context);
      }
    }

    _routeListener = listener;
    routes.addListener(listener);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _installVoiceRouteBridge();
    if (kIsWeb) {
      WebImRealtimeWatchdog.start();
    }
    AuthBootstrapService.instance.setImSdkInitializer(
      initIMSDKAndAddIMListeners,
    );
    initApp();
    initRouteListener();
  }

  /// 注入 UIKit 的语音路由桥接——app 层 VoiceOutputRouteService 的适配器。
  void _installVoiceRouteBridge() {
    SoundPlayerVoiceRouteBridge.install(_AppVoiceRouteBridge());
  }

  Future<void> _escalateIfStillOnSplash(int attempt) async {
    if (!mounted || attempt != _startupAttempt || _startupSettled) return;
    // The watchdog is observational. The restore task owns navigation and
    // credential deletion; a slow network/IM response must never be mistaken
    // for an invalid account and clear a valid token.
    final token = ApiClient.instance.token;
    _sessionLog(
      'SESSION_LOG startup watchdog pending attempt=$attempt '
      'tokenValid=${ApiClient.isValidJwt(token)} '
      'hasOwner=${ApiClient.instance.authenticatedUserId.isNotEmpty} '
      'route=${AppNavigator.currentRouteName ?? 'root'}',
    );
  }

  @override
  dispose() {
    ChatHistoryRecoveryCoordinator.instance.invalidateLifecycle();
    ConversationSyncService.instance.invalidateLifecycle();
    _splashWatchdog?.cancel();
    _resumeTimer?.cancel();
    _resumePhase1Timer?.cancel();
    _resumePhase2Timer?.cancel();
    if (kIsWeb) {
      WebImRealtimeWatchdog.stop();
    }
    WidgetsBinding.instance.removeObserver(this);
    final listener = _routeListener;
    if (listener != null) {
      Routes().removeListener(listener);
      _routeListener = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    cachedBuildContext ??= context;
    initScreenUtils();
    ToastUtils.init(context);
    // Web 跳过全屏启动图，鉴权完成后直接进入登录/首页。
    if (PlatformUtils().isWeb) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: 0.85,
                  ),
            ),
          ),
        ),
      );
    }
    return const LaunchPage();
  }
}

/// app 层 VoiceOutputRouteService 的 UIKit bridge 适配器。
class _AppVoiceRouteBridge implements SoundPlayerVoiceRouteBridge {
  @override
  SoundPlayerVoiceRoute get currentRoute =>
      VoiceOutputRouteService.currentRoute == VoiceOutputRoute.speaker
          ? SoundPlayerVoiceRoute.speaker
          : SoundPlayerVoiceRoute.earpiece;

  @override
  bool get isSpeaker => VoiceOutputRouteService.isSpeaker;

  @override
  ValueListenable<SoundPlayerVoiceRoute> get routeNotifier {
    final source = VoiceOutputRouteService.routeNotifier;
    return _RouteNotifierAdapter(source);
  }

  @override
  AudioSessionConfiguration playbackConfigFor(SoundPlayerVoiceRoute route) {
    final mapped = _mapRoute(route);
    return VoiceOutputRouteService.playbackConfigFor(mapped);
  }

  @override
  AudioSessionConfiguration voiceChatConfigFor(SoundPlayerVoiceRoute route) {
    final mapped = _mapRoute(route);
    return VoiceOutputRouteService.voiceChatConfigFor(mapped);
  }

  @override
  Future<bool> applyCurrentRoute({
    bool configureSession = false,
    bool forRecording = false,
    bool activate = false,
  }) {
    return VoiceOutputRouteService.applyCurrentRoute(
      configureSession: configureSession,
      forRecording: forRecording,
      activate: activate,
    );
  }

  @override
  Future<bool> setRoute(
    SoundPlayerVoiceRoute target, {
    bool configureSession = true,
    bool forRecording = false,
    bool activate = true,
    bool forceApply = false,
  }) {
    return VoiceOutputRouteService.setRoute(
      _mapRoute(target),
      configureSession: configureSession,
      forRecording: forRecording,
      activate: activate,
      forceApply: forceApply,
    );
  }

  static VoiceOutputRoute _mapRoute(SoundPlayerVoiceRoute route) {
    return route == SoundPlayerVoiceRoute.speaker
        ? VoiceOutputRoute.speaker
        : VoiceOutputRoute.earpiece;
  }
}

class _RouteNotifierAdapter extends ValueNotifier<SoundPlayerVoiceRoute> {
  _RouteNotifierAdapter(ValueListenable<VoiceOutputRoute> source)
      : super(_map(source.value)) {
    source.addListener(_onChanged);
    _source = source;
  }

  ValueListenable<VoiceOutputRoute>? _source;

  void _onChanged() {
    final source = _source;
    if (source != null) {
      value = _map(source.value);
    }
  }

  static SoundPlayerVoiceRoute _map(VoiceOutputRoute route) {
    return route == VoiceOutputRoute.speaker
        ? SoundPlayerVoiceRoute.speaker
        : SoundPlayerVoiceRoute.earpiece;
  }
}
