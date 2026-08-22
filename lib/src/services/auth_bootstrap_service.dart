import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_lifecycle_service.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_demo/src/services/call_lifecycle_service_web.dart';
import 'package:tencent_cloud_chat_demo/src/services/device_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_session_cache.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_error.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_permission_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_registration_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/push_identity_cache.dart';
import 'package:tencent_cloud_chat_demo/src/platform/listener_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_contact_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_entity_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/archived_conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_folder_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_notify_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_bootstrap.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/privileged_game_user_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/sangong_my_config_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_connect_status_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_snapshot_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_web_ready_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/ios_apns_push_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/native_post_home_bootstrap_queue.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/starred_friend_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/user_sticker_provider.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/init_step.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class AuthBootstrapService {
  AuthBootstrapService._();

  /// Debug 构建打开；关键失败路径另走 [_diag] 始终打印。
  static bool get _traceEnabled => kDebugMode;

  void _trace(String message) {
    if (!_traceEnabled) return;
    debugPrint(message);
  }

  /// 始终打到控制台（Xcode/rizhi 可看见），用于会话同步失败取证。
  void _diag(String message) {
    debugPrint(message);
  }

  static final AuthBootstrapService instance = AuthBootstrapService._();
  final ValueNotifier<bool> backgroundSyncing = ValueNotifier<bool>(false);

  /// Set when [TencentChatApp.initIMSDKAndAddIMListeners] completes.
  static bool imSdkInitialized = false;

  /// 当前已成功 init 的 sdkAppId（来自后端 UserSig / 缓存解析结果）。
  static int? initializedSdkAppId;

  Future<void> Function({int? sdkAppId})? _imSdkInitializer;
  Future<bool>? _ensureImSdkReadyTask;
  int? _ensureImSdkDesiredAppId;

  Future<bool>? _refreshUserSigTask;
  int _loginGeneration = 0;

  /// 与登录世代对齐：登出 / 清会话 / post-home reset 时递增并清 Done 标记。
  int _bootstrapGeneration = 0;
  bool conversationListBootstrapDone = false;
  bool friendSyncBootstrapDone = false;
  bool groupSyncBootstrapDone = false;
  Future<int>? _imLoginTask;
  String? _imLoginTaskKey;
  String? _lastImLoginKey;
  DateTime? _lastImLoginAt;

  int get bootstrapGeneration => _bootstrapGeneration;

  void bumpBootstrapGeneration({String reason = 'manual'}) {
    _bootstrapGeneration++;
    conversationListBootstrapDone = false;
    friendSyncBootstrapDone = false;
    groupSyncBootstrapDone = false;
    _trace(
      'AuthBootstrap: bumpBootstrapGeneration reason=$reason '
      'gen=$_bootstrapGeneration',
    );
  }

  void setImSdkInitializer(
    Future<void> Function({int? sdkAppId}) initializer,
  ) {
    _imSdkInitializer = initializer;
  }

  void resetImSdkInitializationState({String reason = 'unknown'}) {
    _trace(
      'AuthBootstrap: resetImSdkInitializationState reason=$reason',
    );
    imSdkInitialized = false;
    initializedSdkAppId = null;
    _ensureImSdkReadyTask = null;
    _ensureImSdkDesiredAppId = null;
  }

  /// 确保 IM SDK 已按 [sdkAppId] 初始化。
  ///
  /// [sdkAppId] 通常取后端 UserSig；为空时走缓存/配置兜底。
  /// 若已 init 但 AppID 不一致，会触发拆掉重装。
  Future<bool> ensureImSdkInitialized({int? sdkAppId}) async {
    final desired = (sdkAppId != null && sdkAppId > 0) ? sdkAppId : null;
    if (imSdkInitialized &&
        desired != null &&
        initializedSdkAppId != null &&
        initializedSdkAppId == desired) {
      return true;
    }
    if (imSdkInitialized && desired == null) {
      return true;
    }
    if (imSdkInitialized &&
        desired != null &&
        initializedSdkAppId != null &&
        initializedSdkAppId != desired) {
      _trace(
        'AuthBootstrap: ensureImSdkInitialized sdkAppId mismatch '
        'current=$initializedSdkAppId desired=$desired → reinit',
      );
      // 放开门闩，交给 initializer 执行 unInit + 新 AppID init。
      imSdkInitialized = false;
    }
    final running = _ensureImSdkReadyTask;
    if (running != null) {
      if (_ensureImSdkDesiredAppId == desired ||
          (desired == null && _ensureImSdkDesiredAppId == null)) {
        return running;
      }
      // 目标 AppID 变了：等旧任务结束后再按新 ID 初始化。
      await running;
      return ensureImSdkInitialized(sdkAppId: desired);
    }
    final initializer = _imSdkInitializer;
    if (initializer == null) {
      _trace('AuthBootstrap: IM SDK initializer missing');
      return false;
    }
    _ensureImSdkDesiredAppId = desired;
    final task = _ensureImSdkInitializedCore(
      initializer,
      sdkAppId: desired,
    );
    _ensureImSdkReadyTask = task.whenComplete(() {
      if (identical(_ensureImSdkReadyTask, task)) {
        _ensureImSdkReadyTask = null;
        _ensureImSdkDesiredAppId = null;
      }
    });
    return _ensureImSdkReadyTask!;
  }

  Future<bool> _ensureImSdkInitializedCore(
    Future<void> Function({int? sdkAppId}) initializer, {
    int? sdkAppId,
  }) async {
    _trace(
      'AuthBootstrap: ensureImSdkInitialized START sdkAppId=${sdkAppId ?? '-'}',
    );
    try {
      await initializer(sdkAppId: sdkAppId);
    } catch (e, st) {
      _trace('AuthBootstrap: ensureImSdkInitialized failed: $e\n$st');
      return false;
    }
    final ready = imSdkInitialized &&
        (sdkAppId == null ||
            sdkAppId <= 0 ||
            initializedSdkAppId == sdkAppId);
    _trace(
      'AuthBootstrap: ensureImSdkInitialized DONE ready=$ready '
      'initializedSdkAppId=${initializedSdkAppId ?? '-'}',
    );
    return ready;
  }

  Future<void> bootstrapLoggedInSession(BuildContext context) async {
    final me = await AuthApi.instance.fetchMe();
    await UserAvatarHelper.syncSelfAvatarFromBackend(me.avatarUrl);
    await PushIdentityCache.instance.refreshSelf();
    final sig = await AuthApi.instance.fetchUserSig();
    await ImSessionCache.instance.save(sig);

    final imCode = await _loginImStack(sig);
    if (imCode != 0) {
      resetImLoginState();
      await ListenerStore.beforeLogout();
      await ApiClient.instance.clearToken();
      await ImSessionCache.instance.clear();
      if (context.mounted) {
        InitStep.directToLogin(context);
      }
      return;
    }

    await ListenerStore.afterLogin();
    if (context.mounted) {
      InitStep.directToHomePage(context);
      await ImConnectStatusService.syncToLocalSetting(context);
    }

    PlatformOfficialAccountService.resetSessionState();
    try {
      await PlatformOfficialAccountService.ensureSubscribed().timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
    } catch (_) {}
    DeviceSyncService.instance.scheduleSyncAfterLogin();
    try {
      StarredFriendProvider.shared.refresh(force: true);
    } catch (_) {}
    try {
      await ArchivedConversationSyncService.instance.syncOnLogin();
    } catch (_) {}
    try {
      await ConversationFolderSyncService.instance.syncOnLogin();
    } catch (_) {}
    try {
      await ConversationPinSyncService.instance.syncOnLogin();
    } catch (_) {}
    try {
      await UserStickerProvider.shared.refresh(force: true);
      if (context.mounted) {
        await InitStep.publishStickerPackages(context);
      }
    } catch (_) {}
    try {
      await GroupNoticeBootstrap.install(refreshApplications: false);
    } catch (_) {}
  }

  static const int imKickedOfflineCode = 6208;

  static const Duration _imLoginTimeout = Duration(seconds: 25);
  static const Duration _uikitLoginWait = Duration(seconds: 8);
  static const List<Duration> _kickRetryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  /// 业务 token 已写入：先完成 IM/UIKit 与会话/通讯录模型，再进首页（避免 Tab 空白）。
  Future<bool> ensureImReadyForHome({
    String? registerNickname,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      return await _ensureImReadyForHomeCore(
        registerNickname: registerNickname,
      ).timeout(timeout, onTimeout: () {
        _diag('AuthBootstrap: ensureImReadyForHome timed out');
        return false;
      });
    } catch (e, st) {
      _diag('AuthBootstrap: ensureImReadyForHome failed: $e\n$st');
      return false;
    }
  }

  Future<bool> prepareReadySessionForHome({
    String? registerNickname,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    _setBackgroundSyncing(true);
    _setConnectStatus(ConnectStatus.connecting);
    var deferredOwnsSyncing = false;
    try {
      final sdkReady = await ensureImSdkInitialized();
      if (!sdkReady) {
        _trace(
          'AuthBootstrap: prepareReadySessionForHome abort '
          '(IM SDK not initialized)',
        );
        _setConnectStatus(ConnectStatus.failed);
        return false;
      }
      final ready = await _ensureImReadyWithRetry(
        registerNickname: registerNickname,
        timeout: timeout,
      );
      if (!ready) {
        _diag('AuthBootstrap: prepareReadySessionForHome IM not ready');
        _setConnectStatus(ConnectStatus.failed);
        return false;
      }
      if (kIsWeb) {
        await runPostLoginSideEffectsWithoutImListRefresh();
        _setConnectStatus(ConnectStatus.success);
        return true;
      }
      // 原生：IM 就绪即返回；列表/好友/群/副作用由进门后串行队列补全。
      _diag('AuthBootstrap: prepareReady OK → schedule post-home bootstrap');
      NativePostHomeBootstrapQueue.instance.schedule(
        reason: 'prepare_ready',
      );
      deferredOwnsSyncing = true;
      return true;
    } catch (e, st) {
      _diag('AuthBootstrap: prepareReadySessionForHome failed: $e\n$st');
      _setConnectStatus(ConnectStatus.failed);
      return false;
    } finally {
      if (!deferredOwnsSyncing) {
        _setBackgroundSyncing(false);
      }
    }
  }

  /// 原生进门后队列 Stage1（首屏会话）结束：放开同步态与连接成功。
  void applyNativePostHomeStage1Finished() {
    _setBackgroundSyncing(false);
    _setConnectStatus(ConnectStatus.success);
    LoginCoordinator.instance.markImReady(isHomeEntered: true);
  }

  Future<bool> _ensureImReadyWithRetry({
    String? registerNickname,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final ready = await ensureImReadyForHome(
      registerNickname: registerNickname,
      timeout: timeout,
    );
    if (ready) {
      return true;
    }
    _diag(
      'AuthBootstrap: foreground prepare first attempt failed, '
      'soft-retry login (no generation bump / no session wipe)',
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    // 软重试：只 logout，不 bump _loginGeneration，避免掐死仍在飞的登录。
    try {
      await TencentImSDKPlugin.v2TIMManager.logout().timeout(
            const Duration(seconds: 3),
          );
    } catch (_) {}
    final sdkReady = await ensureImSdkInitialized();
    if (!sdkReady) {
      _diag(
        'AuthBootstrap: foreground prepare retry abort '
        '(IM SDK not initialized)',
      );
      return false;
    }
    return ensureImReadyForHome(
      registerNickname: registerNickname,
      timeout: timeout,
    );
  }

  Future<bool> _ensureImReadyForHomeCore({String? registerNickname}) async {
    _diag('AuthBootstrap: ensure IM ready for home');
    LoginCoordinator.instance.markImConnecting();
    final results = await Future.wait<Object>([
      AuthApi.instance.fetchMe().timeout(const Duration(seconds: 10)),
      AuthApi.instance.fetchUserSig().timeout(const Duration(seconds: 10)),
    ]);
    final me = results[0] as MeResult;
    var sig = results[1] as UserSigResult;
    _diag(
      'AuthBootstrap: got me=${me.userId} sig=${sig.userId} '
      'sdkAppId=${sig.sdkAppId} sigLen=${sig.userSig.length}',
    );
    if (sig.userId.trim().isEmpty || sig.userSig.trim().isEmpty) {
      _diag('AuthBootstrap: abort empty userSig payload');
      return false;
    }
    // UserSig 是 IM 登录真源。/me 与 /im/user-sig 的 userId 若暂不一致，
    // 绝不能硬失败清会话——否则永远看不到 Login，首页会话/群/通讯录全空。
    if (!_isSameUserId(me.userId, sig.userId)) {
      _diag(
        'AuthBootstrap: WARN me/sig userId mismatch '
        '(me=${me.userId} sig=${sig.userId}); proceed with userSig',
      );
    }
    sig = _normalizeUserSig(sig);
    LoginCoordinator.instance.markImConnecting(userId: sig.userId);
    await ImSessionCache.instance.save(sig);

    _trace(
      'AuthBootstrap: _ensureImReadyForHomeCore calling completeImSessionAfterAuth '
      'userId=${sig.userId}',
    );
    var imCode = await completeImSessionAfterAuth(sig);
    _diag(
      'AuthBootstrap: completeImSessionAfterAuth code=$imCode '
      'userId=${sig.userId}',
    );
    imCode = await resolveImLoginCode(sig, imCode);
    _diag(
      'AuthBootstrap: resolveImLoginCode finalCode=$imCode '
      'userId=${sig.userId}',
    );
    if (imCode != 0) {
      _trace(
        'AuthBootstrap: ensureImReadyForHome imCode=$imCode, '
        'calling _recoverImReadyAfterTransientFailure',
      );
      final recovered = await _recoverImReadyAfterTransientFailure(sig);
      _trace(
        'AuthBootstrap: ensureImReadyForHome recovered=$recovered',
      );
      if (!recovered) {
        return false;
      }
    }

    if (!isCoreServicesUserReady()) {
      await primeUIKitSession(sig);
      if (!isCoreServicesUserReady()) {
        _trace(
          'AuthBootstrap: UIKit still not ready after prime userId=${sig.userId}',
        );
        return false;
      }
    }

    if (registerNickname != null && registerNickname.isNotEmpty) {
      try {
        await TIMUIKitCore.getInstance().setSelfInfo(
          userFullInfo: V2TimUserFullInfo(
            nickName: registerNickname,
            faceUrl: IMDemoConfig.defaultRegisterAvatarUrl,
          ),
        );
      } catch (_) {}
    }

    if (kIsWeb) {
      unawaited(refreshImUIKitLists());
      unawaited(_runWebPostImReadySideEffects(me: me));
      _trace('AuthBootstrap: IM ready for home (web deferred lists)');
      LoginCoordinator.instance.markImReady(userId: sig.userId);
      unawaited(NotificationSettingsService.instance.ensureListenersAttached());
      unawaited(
        NotificationSettingsService.instance.syncRemotePreferencesFromServer(),
      );
      return true;
    }

    // 原生：门禁只等到 IM/UIKit 可收发；列表与副作用由 NativePostHomeBootstrapQueue 串行补。
    _trace('AuthBootstrap: IM ready for home (native deferred lists)');
    LoginCoordinator.instance.markImReady(userId: sig.userId);
    unawaited(NotificationSettingsService.instance.ensureListenersAttached());
    unawaited(
      NotificationSettingsService.instance.syncRemotePreferencesFromServer(),
    );
    return true;
  }

  Future<void> _runWebPostImReadySideEffects({
    required MeResult me,
  }) async {
    try {
      await ConversationNotifySyncService.instance.syncAllOnLogin();
    } catch (_) {}
    try {
      await ArchivedConversationSyncService.instance.syncOnLogin();
    } catch (_) {}
    try {
      await ConversationFolderSyncService.instance.syncOnLogin();
    } catch (_) {}
    try {
      await ConversationPinSyncService.instance.syncOnLogin();
    } catch (_) {}
    try {
      await UserAvatarHelper.syncSelfAvatarFromBackend(me.avatarUrl);
      await PushIdentityCache.instance.refreshSelf();
    } catch (_) {}
  }

  Future<bool> _recoverImReadyAfterTransientFailure(UserSigResult sig) async {
    const retryDelays = <Duration>[
      Duration(milliseconds: 200),
      Duration(milliseconds: 500),
      Duration(milliseconds: 900),
    ];
    _trace(
      'AuthBootstrap: recoverImReadyAfterTransientFailure START '
      '(sig userId=${sig.userId})',
    );
    for (var i = 0; i < retryDelays.length; i++) {
      await Future<void>.delayed(retryDelays[i]);
      final nativeReady = await isNativeLoggedIn(sig);
      _trace(
        'AuthBootstrap: recover attempt $i nativeReady=$nativeReady '
        '(${retryDelays[i].inMilliseconds}ms elapsed)',
      );
      if (!nativeReady) {
        _trace('AuthBootstrap: recover attempt $i not ready, continue');
        continue;
      }
      _trace(
        'AuthBootstrap: recover attempt $i native=READY, priming UIKit',
      );
      await primeUIKitSession(sig);
      final uikitReady = isCoreServicesUserReady();
      _trace(
        'AuthBootstrap: recover attempt $i prime done uikitReady=$uikitReady',
      );
      if (uikitReady) {
        _trace(
          'AuthBootstrap: IM transient failure recovered '
          '(attempt=$i native=true uikit=true)',
        );
        return true;
      }
    }

    final nativeReady = await isNativeLoggedIn(sig);
    _trace(
      'AuthBootstrap: recover FINAL check nativeReady=$nativeReady',
    );
    if (!nativeReady) {
      _trace(
        'AuthBootstrap: recover giving up — native still not ready',
      );
      return false;
    }

    _trace('AuthBootstrap: recover final fallback — priming UIKit');
    await primeUIKitSession(sig);
    final uikitReady = isCoreServicesUserReady();
    _trace(
      'AuthBootstrap: IM transient failure fallback '
      '(native=true uikit=$uikitReady)',
    );
    return uikitReady;
  }

  /// 刷新 UIKit 会话列表与好友列表（首页/通讯录依赖这些 ViewModel）。
  ///
  /// On web, returns true once identity is ready even if list sync fails, so
  /// login is not trapped on the login page. Pass [scheduleWebRetry]=false from
  /// background retry to avoid recursive retries.
  Future<bool> refreshImUIKitLists({bool scheduleWebRetry = true}) async {
    final friendship = serviceLocator<TUIFriendShipViewModel>();
    final conversation = serviceLocator<TUIConversationViewModel>();
    var friendshipOk = true;
    var conversationOk = true;
    _trace('AuthBootstrap: refreshImUIKitLists START');
    if (kIsWeb) {
      // TIM Web login can return before getLoginUser / list APIs are usable.
      final imReady = await ImWebReadyGuard.instance.wait(
        timeout: const Duration(seconds: 12),
      );
      _trace('AuthBootstrap: refreshImUIKitLists web imReady=$imReady');
    }
    await Future.wait<void>([
      Future<void>(() async {
        try {
          await FriendSyncService.instance.syncFull(reason: 'bootstrap');
          friendSyncBootstrapDone = true;
          await FriendContactIncrementalSyncService.instance.sync(
            reason: 'bootstrap',
          );
          await GroupMembershipSyncService.instance
              .syncFull(reason: 'bootstrap');
          groupSyncBootstrapDone = true;
          await GroupEntityIncrementalSyncService.instance.sync(
            reason: 'bootstrap',
          );
          await GroupNoticeIncrementalSyncService.instance.sync(
            reason: 'bootstrap',
          );
          await GroupMemberIncrementalSyncService.instance.syncAllJoined(
            reason: 'bootstrap',
          );
          await friendship.loadContactListData();
          await FriendSyncService.instance.reseedC2cDisplayNamesFromLocalFriends();
          await friendship.loadContactApplicationData();
          if ((friendship.friendList?.isNotEmpty ?? false)) {
            await friendship.loadUserStatus();
          }
        } catch (e) {
          friendshipOk = false;
          _trace('AuthBootstrap: loadContactListData failed: $e');
        }
      }),
      Future<void>(() async {
        try {
          // sync 前先灌限量快照，避免进 Home 前只有空窗。
          await ConversationListNotifier.instance.reloadFromLocal();
          final meta = await ConversationLocalStore.instance.readSyncMeta();
          final rowCount = await ConversationLocalStore.instance.countRows();
          final owner = ChatIdFormat.rawUserUid(
            ContactSocialCacheStore.safeLoginUserId(),
          );
          if (ConversationSyncService
                  .shouldAttemptImSnapshotOnLoginBootstrap() &&
              owner.isNotEmpty) {
            ImSnapshotBootstrapService.instance.beginLoginBootstrapGate();
            try {
              debugPrint(
                'AuthBootstrap: login Snapshot try owner=$owner '
                'rows=$rowCount',
              );
              final snapOk = await ImSnapshotBootstrapService.instance
                  .tryBootstrapOnLogin(ownerUserId: owner);
              if (snapOk) {
                conversationListBootstrapDone = true;
                debugPrint(
                  'AuthBootstrap: Snapshot C2C priority ready; '
                  'SDK follow-up scheduled',
                );
                return;
              }
              debugPrint(
                'AuthBootstrap: Snapshot miss → bootstrap_snapshot_fallback',
              );
              await ConversationSyncService.instance.syncFromSdk(
                reason: 'bootstrap_snapshot_fallback',
                reset: !(meta.hasSyncedOnce && rowCount > 0),
                drainMode: ConversationSdkDrainMode.foregroundLimited,
              );
              conversationListBootstrapDone = true;
              return;
            } finally {
              ImSnapshotBootstrapService.instance.endLoginBootstrapGate();
            }
          }
          final shouldReset = !meta.hasSyncedOnce || rowCount == 0;
          debugPrint(
            'AuthBootstrap: skip Snapshot → local-first '
            'syncFromSdk reason=bootstrap reset=$shouldReset '
            'rows=$rowCount hasSyncedOnce=${meta.hasSyncedOnce}',
          );
          await ConversationSyncService.instance.syncFromSdk(
            reason: 'bootstrap',
            reset: shouldReset,
            drainMode: ConversationSdkDrainMode.foregroundLimited,
          );
          conversationListBootstrapDone = true;
        } catch (e) {
          conversationOk = false;
          _trace('AuthBootstrap: conversation sync failed: $e');
        }
      }),
    ]);
    final conversationCount =
        conversation.conversationList.where((item) => item != null).length;
    final friendCount = friendship.friendList?.length ?? 0;
    final ok = friendshipOk && conversationOk;
    debugPrint(
      'AuthBootstrap: refreshImUIKitLists DONE ok=$ok '
      'conversationCount=$conversationCount friendCount=$friendCount '
      'convDone=$conversationListBootstrapDone '
      'friendDone=$friendSyncBootstrapDone groupDone=$groupSyncBootstrapDone'
      '${kIsWeb ? ' webSoftPass=${!ok}' : ''}',
    );
    _trace(
      'AuthBootstrap: refreshImUIKitLists DONE ok=$ok '
      'conversationCount=$conversationCount friendCount=$friendCount '
      'convDone=$conversationListBootstrapDone '
      'friendDone=$friendSyncBootstrapDone groupDone=$groupSyncBootstrapDone'
      '${kIsWeb ? ' webSoftPass=${!ok}' : ''}',
    );
    // Web: never block home entry on HTTP friend sync / TIM list lag.
    // Background listeners will refill lists after enter.
    if (kIsWeb) {
      if (!ok && scheduleWebRetry) {
        unawaited(_retryWebListBootstrapInBackground());
      }
      return true;
    }
    return ok;
  }

  Future<void> _retryWebListBootstrapInBackground() async {
    if (!kIsWeb) {
      return;
    }
    try {
      await Future<void>.delayed(const Duration(seconds: 2));
      await ImWebReadyGuard.instance.wait(timeout: const Duration(seconds: 12));
      await refreshImUIKitLists(scheduleWebRetry: false);
      _trace('AuthBootstrap: web background list retry finished');
    } catch (e) {
      _trace('AuthBootstrap: web background list retry failed: $e');
    }
  }

  void enterHomeAfterBusinessAuth(
    BuildContext context, {
    bool syncingIm = true,
  }) {
    final ctx = AppNavigator.context ?? context;
    if (syncingIm) {
      LoginCoordinator.instance.markHomeEnteredSyncingIm();
    } else {
      LoginCoordinator.instance.markImReady(isHomeEntered: true);
    }
    try {
      Provider.of<LocalSetting>(ctx, listen: false).connectStatus =
          syncingIm ? ConnectStatus.connecting : ConnectStatus.success;
    } catch (_) {}
    _trace(
      'AuthBootstrap: enter home after business auth '
      '(syncingIm=$syncingIm)',
    );
    NotificationSettingsService.instance.endColdStartBannerSuppression();
    InitStep.leaveLaunchScreen(toHome: true, context: ctx);
  }

  Future<void> runPostLoginSideEffects() async {
    await _runPostLoginSideEffectsCore(includeImListRefresh: true);
  }

  Future<void> runPostLoginSideEffectsWithoutImListRefresh() async {
    await _runPostLoginSideEffectsCore(includeImListRefresh: false);
  }

  Future<void> _runPostLoginSideEffectsCore({
    required bool includeImListRefresh,
  }) async {
    try {
      await ListenerStore.afterLogin().timeout(const Duration(seconds: 8));
    } catch (_) {}

    final navContext = AppNavigator.context;
    if (navContext != null && navContext.mounted) {
      await ImConnectStatusService.syncToLocalSetting(navContext);
    }

    PlatformOfficialAccountService.resetSessionState();
    unawaited(
      PlatformOfficialAccountService.ensureSubscribed()
          .timeout(const Duration(seconds: 8), onTimeout: () => false)
          .catchError((_) => false),
    );
    DeviceSyncService.instance.scheduleSyncAfterLogin();
    try {
      StarredFriendProvider.shared.refresh(force: true);
    } catch (_) {}
    try {
      await ArchivedConversationSyncService.instance.syncOnLogin();
    } catch (_) {}
    try {
      await ConversationFolderSyncService.instance.syncOnLogin();
    } catch (_) {}
    try {
      await ConversationPinSyncService.instance.syncOnLogin();
    } catch (_) {}
    try {
      await UserStickerProvider.shared.refresh(force: true);
      if (navContext != null && navContext.mounted) {
        await InitStep.publishStickerPackages(navContext);
      }
    } catch (_) {}
    try {
      await GroupNoticeBootstrap.install();
    } catch (_) {}
    if (includeImListRefresh) {
      await refreshImUIKitLists();
    }
    try {
      await ConversationNotifySyncService.instance.syncAllOnLogin();
    } catch (_) {}
    try {
      await ArchivedConversationSyncService.instance.syncOnLogin();
    } catch (_) {}
    try {
      await ConversationFolderSyncService.instance.syncOnLogin();
    } catch (_) {}
    try {
      await ConversationPinSyncService.instance.syncOnLogin();
    } catch (_) {}
    unawaited(PrivilegedGameUserService.instance.activateSession());
    unawaited(SangongMyConfigService.instance.activateSession());

    if (navContext != null && navContext.mounted) {
      try {
        final localSetting =
            Provider.of<LocalSetting>(navContext, listen: false);
        unawaited(
          NotificationPermissionService.instance.ensureAfterLogin(
            localSetting: localSetting,
            context: navContext,
          ),
        );
      } catch (_) {}
    }
  }

  Future<void> syncImSessionAfterBusinessLogin(
      {String? registerNickname}) async {
    final ready = await prepareReadySessionForHome(
      registerNickname: registerNickname,
      timeout: const Duration(seconds: 20),
    );
    if (ready) {
      LoginCoordinator.instance.markImReady(isHomeEntered: true);
      _trace('AuthBootstrap: background IM sync done');
      return;
    }
    _trace('AuthBootstrap: background IM sync incomplete (IM not ready)');
    LoginCoordinator.instance.markFailed(
      LoginErrorType.imLoginFailed,
      message: 'IM not ready after business login',
      isBusinessAuthenticated: true,
      isHomeEntered: true,
    );
  }

  void _setBackgroundSyncing(bool value) {
    if (backgroundSyncing.value == value) {
      return;
    }
    backgroundSyncing.value = value;
  }

  void _setConnectStatus(ConnectStatus status) {
    final navContext = AppNavigator.context;
    if (navContext == null || !navContext.mounted) {
      return;
    }
    try {
      Provider.of<LocalSetting>(navContext, listen: false).connectStatus =
          status;
    } catch (_) {}
  }

  /// Password/SMS login: native IM 已匹配则不再走会挂死的 [loginImStack] 全量重登。
  Future<int> completeImSessionAfterAuth(UserSigResult sig) async {
    _trace(
      'AuthBootstrap: completeImSessionAfterAuth START userId=${sig.userId}',
    );
    final nativeUserId = await getNativeLoginUserId();
    if (nativeUserId != null && !_isSameUserId(nativeUserId, sig.userId)) {
      _trace(
        'AuthBootstrap: completeImSessionAfterAuth clearing stale native user '
        'native=$nativeUserId target=${sig.userId}',
      );
      await clearLocalImSession(
        reason: 'foreground_identity_mismatch',
        clearCachedSession: false,
      );
    }
    if (await isNativeLoggedIn(sig)) {
      _trace(
        'AuthBootstrap: completeImSessionAfterAuth FAST PATH (native already logged in)',
      );
      await primeUIKitSession(sig);
      _markImLoginSuccess(
        '${sig.sdkAppId}:${sig.userId}:${sig.userSig}',
        skipNetworkSideEffects: false,
      );
      unawaited(_refreshCallStack(sig));
      _trace(
        'AuthBootstrap: completeImSessionAfterAuth FAST PATH DONE code=0',
      );
      return 0;
    }

    _trace(
      'AuthBootstrap: completeImSessionAfterAuth SLOW PATH — calling loginImStack '
      'userId=${sig.userId}',
    );
    final code = await loginImStack(sig, forceLogin: true);
    _trace(
      'AuthBootstrap: completeImSessionAfterAuth loginImStack DONE code=$code',
    );
    return resolveImLoginCode(sig, code);
  }

  /// Native IM logged in as [sig.userId] (UIKit may still be initializing).
  Future<bool> isNativeLoggedIn(UserSigResult sig) async {
    return _isSameUserId(await getNativeLoginUserId(), sig.userId);
  }

  Future<String?> getNativeLoginUserId() async {
    final loginRes = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
    final userId = loginRes.data?.trim() ?? '';
    return userId.isEmpty ? null : userId;
  }

  Future<UserSigResult?> verifyBusinessImIdentity({
    String reason = 'identity_check',
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final results = await Future.wait<Object>([
      AuthApi.instance.fetchMe().timeout(timeout),
      AuthApi.instance.fetchUserSig().timeout(timeout),
    ]);
    final me = results[0] as MeResult;
    var sig = results[1] as UserSigResult;
    if (sig.userId.trim().isEmpty || sig.userSig.trim().isEmpty) {
      _diag('AuthBootstrap: identity check empty sig reason=$reason');
      return null;
    }
    if (!_isSameUserId(me.userId, sig.userId)) {
      _diag(
        'AuthBootstrap: identity WARN reason=$reason '
        'me=${me.userId} sig=${sig.userId}; keep userSig',
      );
    }
    sig = _normalizeUserSig(sig);
    final nativeUserId = await getNativeLoginUserId();
    if (nativeUserId != null && !_isSameUserId(nativeUserId, sig.userId)) {
      _diag(
        'AuthBootstrap: native identity mismatch reason=$reason '
        'native=$nativeUserId expected=${sig.userId}',
      );
      await clearLocalImSession(
        reason: '${reason}_native_mismatch',
        clearCachedSession: true,
      );
      return null;
    }
    await ImSessionCache.instance.save(sig);
    return sig;
  }

  Future<void> clearLocalImSession({
    required String reason,
    bool clearCachedSession = false,
  }) async {
    _trace('AuthBootstrap: clear local IM session ($reason)');
    NativePostHomeBootstrapQueue.instance.reset(reason: reason);
    _setBackgroundSyncing(false);
    resetImLoginState();
    // 只 logout，不要清 imSdkInitialized：否则下次 ensureImSdkInitialized
    // 会误判并 UnInit 仍在运行的 SDK，导致「会话同步失败」且日志无 Login。
    try {
      await TIMUIKitCore.getInstance().logout().timeout(
            const Duration(seconds: 3),
          );
    } catch (_) {}
    try {
      await TencentImSDKPlugin.v2TIMManager.logout().timeout(
            const Duration(seconds: 3),
          );
    } catch (_) {}
    try {
      await CallLifecycleService.instance.teardown();
    } catch (_) {}
    if (clearCachedSession) {
      await ImSessionCache.instance.clear();
    }
  }

  bool _isSameUserId(String? left, String? right) {
    final a = left?.trim() ?? '';
    final b = right?.trim() ?? '';
    return a.isNotEmpty && b.isNotEmpty && a == b;
  }

  /// If UIKit login returned non-zero but native IM is ready, treat as success.
  Future<int> resolveImLoginCode(UserSigResult sig, int imCode) async {
    _trace(
      'AuthBootstrap: resolveImLoginCode START imCode=$imCode userId=${sig.userId}',
    );
    if (imCode == 0) {
      _trace('AuthBootstrap: resolveImLoginCode imCode=0, returning 0');
      return 0;
    }
    final nativeReady = await isNativeLoggedIn(sig);
    _trace(
      'AuthBootstrap: resolveImLoginCode imCode=$imCode nativeReady=$nativeReady',
    );
    if (nativeReady) {
      _trace(
        'AuthBootstrap: resolveImLoginCode accept native session (code=$imCode)',
      );
      resetImLoginState();
      return 0;
    }
    _trace(
      'AuthBootstrap: resolveImLoginCode returning original code=$imCode',
    );
    return imCode;
  }

  Future<int> loginImStack(
    UserSigResult sig, {
    bool skipNetworkSideEffects = false,
    bool forceLogin = false,
  }) async {
    try {
      return await _loginImStack(
        sig,
        skipNetworkSideEffects: skipNetworkSideEffects,
        forceLogin: forceLogin,
      ).timeout(
        _imLoginTimeout,
        onTimeout: () => _recoverImLoginAfterTimeout(sig),
      );
    } catch (_) {
      return _recoverImLoginAfterTimeout(sig);
    }
  }

  /// 后端偶发漏带 sdkAppId 时回退到已 init / 配置值，避免直接 abort 永不 Login。
  UserSigResult _normalizeUserSig(UserSigResult sig) {
    if (sig.sdkAppId > 0) {
      return sig;
    }
    final fallback = initializedSdkAppId ?? IMDemoConfig.sdkAppID;
    _diag(
      'AuthBootstrap: userSig sdkAppId missing, fallback=$fallback',
    );
    return UserSigResult(
      sdkAppId: fallback,
      userId: sig.userId,
      userSig: sig.userSig,
      expiresIn: sig.expiresIn,
    );
  }

  Future<int> _loginImStack(
    UserSigResult sig, {
    bool skipNetworkSideEffects = false,
    bool forceLogin = false,
  }) async {
    sig = _normalizeUserSig(sig);
    if (sig.sdkAppId <= 0) {
      _diag('AuthBootstrap: _loginImStack abort invalid sdkAppId');
      return -1;
    }
    final sdkReady = await ensureImSdkInitialized(sdkAppId: sig.sdkAppId);
    if (!sdkReady) {
      _diag(
        'AuthBootstrap: _loginImStack abort IM SDK not ready '
        'for sdkAppId=${sig.sdkAppId}',
      );
      return -1;
    }

    final loginKey = '${sig.sdkAppId}:${sig.userId}:${sig.userSig}';

    final runningTask = _imLoginTask;
    if (runningTask != null) {
      // During iOS network switching the SDK and app can both trigger relogin.
      // Reuse the in-flight login instead of starting another one, otherwise the
      // SDK reports: send packet interrupt because of relogin, login ticket has changed.
      try {
        return await runningTask.timeout(
          _imLoginTimeout,
          onTimeout: () => _recoverImLoginAfterTimeout(sig),
        );
      } catch (_) {
        return _recoverImLoginAfterTimeout(sig);
      }
    }

    final currentUser = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
    final currentUserId = currentUser.data?.trim() ?? '';
    if (currentUser.code == 0 &&
        currentUserId.isNotEmpty &&
        currentUserId != sig.userId) {
      await clearLocalImSession(
        reason: 'native_user_mismatch_before_login',
        clearCachedSession: false,
      );
    }
    final now = DateTime.now();
    final lastLoginAt = _lastImLoginAt;
    final recentlyLoggedIn = lastLoginAt != null &&
        now.difference(lastLoginAt) < const Duration(seconds: 20);

    if (!forceLogin &&
        currentUser.code == 0 &&
        currentUser.data == sig.userId &&
        _lastImLoginKey != null &&
        recentlyLoggedIn) {
      // Only suppress a true duplicate login inside the same app runtime.
      // Do not use getLoginUser() alone as a reason to skip TIMUIKitCore.login:
      // after a cold start the native SDK may still know the user, while the
      // UIKit conversation/group models are not initialized yet. Skipping login
      // in that state makes the conversation list and group list look empty.
      await _refreshCallStack(sig);
      return 0;
    }

    _imLoginTaskKey = loginKey;
    _imLoginTask = _doLoginImStack(
      sig,
      loginKey: loginKey,
      skipNetworkSideEffects: skipNetworkSideEffects,
    );
    try {
      return await _imLoginTask!;
    } finally {
      if (_imLoginTaskKey == loginKey) {
        _imLoginTask = null;
        _imLoginTaskKey = null;
      }
    }
  }

  Future<int> _doLoginImStack(
    UserSigResult sig, {
    required String loginKey,
    required bool skipNetworkSideEffects,
  }) async {
    final gen = _loginGeneration;
    _trace(
      'AuthBootstrap: _doLoginImStack START gen=$gen loginKey=$loginKey',
    );

    final nativeOk = await isNativeLoggedIn(sig);
    _trace(
      'AuthBootstrap: _doLoginImStack nativeOk=$nativeOk gen=$gen',
    );

    if (nativeOk) {
      if (gen != _loginGeneration) {
        _trace('AuthBootstrap: _doLoginImStack gen changed, abort');
        return -1;
      }
      _trace('AuthBootstrap: _doLoginImStack FAST: native ok, priming UIKit');
      await primeUIKitSession(sig);
      if (gen != _loginGeneration) {
        _trace('AuthBootstrap: _doLoginImStack gen changed after prime, abort');
        return -1;
      }
      if (kDebugMode) {
        _trace(
          'AuthBootstrap: native IM ok, uikit primed=${isCoreServicesUserReady()}',
        );
      }
      unawaited(_refreshCallStack(sig));
      _markImLoginSuccess(
        loginKey,
        skipNetworkSideEffects: skipNetworkSideEffects,
      );
      _trace('AuthBootstrap: _doLoginImStack FAST path done, returning 0');
      return 0;
    }

    if (gen != _loginGeneration) {
      _trace(
          'AuthBootstrap: _doLoginImStack gen changed before slow path, abort');
      return -1;
    }

    _trace(
        'AuthBootstrap: _doLoginImStack SLOW: calling _loginImWithKickRetry');
    var code = await _loginImWithKickRetry(sig);
    _trace('AuthBootstrap: _doLoginImStack _loginImWithKickRetry code=$code');
    if (code != 0) {
      _trace('AuthBootstrap: _doLoginImStack kickRetry failed, recover');
      code = await _recoverImLoginAfterTimeout(sig);
      _trace(
          'AuthBootstrap: _doLoginImStack _recoverImLoginAfterTimeout code=$code');
    }
    if (code == 0) {
      await _refreshCallStack(sig);
      if (gen != _loginGeneration) {
        _trace(
            'AuthBootstrap: _doLoginImStack gen changed after refresh, abort');
        return -1;
      }
      _markImLoginSuccess(
        loginKey,
        skipNetworkSideEffects: skipNetworkSideEffects,
      );
    }
    _trace('AuthBootstrap: _doLoginImStack DONE code=$code gen=$gen');
    return code;
  }

  Future<int> _loginImWithKickRetry(UserSigResult sig) async {
    var lastCode = -1;
    for (var attempt = 0; attempt < _kickRetryDelays.length + 1; attempt++) {
      lastCode = await _tryTimUIKitLogin(sig);
      if (lastCode == 0 || lastCode != imKickedOfflineCode) {
        return lastCode;
      }
      if (attempt >= _kickRetryDelays.length) {
        break;
      }
      if (kDebugMode) {
        _trace(
          'AuthBootstrap: IM login kicked offline, retry ${attempt + 1}',
        );
      }
      await _resetLocalImSessionBeforeRetry();
      await Future<void>.delayed(_kickRetryDelays[attempt]);
    }
    return await resolveImLoginCode(sig, lastCode);
  }

  Future<void> _resetLocalImSessionBeforeRetry() async {
    await clearLocalImSession(
      reason: 'retry_after_kick',
      clearCachedSession: false,
    );
  }

  /// Ensures [CoreServicesImpl] has [userID] set (sync prefix of [login]).
  /// Native IM may already be online while the Dart [login] Future still hangs.
  Future<void> primeUIKitSession(UserSigResult sig) async {
    final loginFuture = TIMUIKitCore.getInstance()
        .login(userID: sig.userId, userSig: sig.userSig);
    await Future<void>.delayed(Duration.zero);
    try {
      final imRes = await loginFuture.timeout(_uikitLoginWait);
      if (imRes.code != 0 && kDebugMode) {
        _trace('AuthBootstrap: primeUIKitSession code=${imRes.code}');
      }
    } on TimeoutException {
      if (kDebugMode) {
        _trace('AuthBootstrap: primeUIKitSession timed out, continue');
      }
      unawaited(loginFuture);
    } catch (e) {
      if (kDebugMode) {
        _trace('AuthBootstrap: primeUIKitSession error: $e');
      }
      unawaited(loginFuture);
    }
  }

  bool isCoreServicesUserReady() {
    try {
      final id = TIMUIKitCore.getInstance().loginInfo.userID.trim();
      return id.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<int> _tryTimUIKitLogin(UserSigResult sig) async {
    _diag(
      'AuthBootstrap: _tryTimUIKitLogin START userId=${sig.userId}',
    );

    // Helper to attempt one login call.
    Future<dynamic> _attemptLogin() async {
      final loginFuture = TIMUIKitCore.getInstance()
          .login(userID: sig.userId, userSig: sig.userSig);
      await Future<void>.delayed(Duration.zero);
      try {
        return await loginFuture.timeout(_uikitLoginWait);
      } on TimeoutException {
        unawaited(loginFuture);
        return null;
      } catch (e) {
        unawaited(loginFuture);
        rethrow;
      }
    }

    final imRes = await _attemptLogin();

    // Timeout: native may already be logged in — check and treat as success.
    if (imRes == null) {
      _trace(
        'AuthBootstrap: _tryTimUIKitLogin TIMEOUT userId=${sig.userId}',
      );
      if (await isNativeLoggedIn(sig)) {
        _trace(
          'AuthBootstrap: _tryTimUIKitLogin timeout but native ready, priming',
        );
        await primeUIKitSession(sig);
        return 0;
      }
      _trace(
        'AuthBootstrap: _tryTimUIKitLogin TIMEOUT, native not ready, returning -1',
      );
      return -1;
    }

    _trace(
      'AuthBootstrap: _tryTimUIKitLogin got result code=${imRes.code} '
      'userId=${sig.userId}',
    );

    // Code 6013 (SDK busy / still initializing after logout): retry once.
    // This is observed to succeed on immediate retry when login follows logout.
    if (imRes.code == 6013) {
      _trace(
        'AuthBootstrap: _tryTimUIKitLogin code=6013, retrying once',
      );
      final retryRes = await _attemptLogin();
      if (retryRes != null && retryRes.code == 0) {
        _trace(
          'AuthBootstrap: _tryTimUIKitLogin retry OK code=0',
        );
        return 0;
      }
      // Retry also failed — return the original code to trigger kick-retry.
      if (retryRes != null) {
        _trace(
          'AuthBootstrap: _tryTimUIKitLogin retry FAIL code=${retryRes.code}',
        );
        return retryRes.code;
      }
      _trace('AuthBootstrap: _tryTimUIKitLogin retry TIMEOUT, returning -1');
      return -1;
    }

    if (imRes.code != 0) {
      _trace(
        'AuthBootstrap: _tryTimUIKitLogin FAIL code=${imRes.code} '
        'userId=${sig.userId}',
      );
      return imRes.code;
    }

    final uikitReady = isCoreServicesUserReady();
    _trace(
      'AuthBootstrap: _tryTimUIKitLogin OK code=0 uikitReady=$uikitReady '
      'userId=${sig.userId}',
    );
    return 0;
  }

  void _markImLoginSuccess(
    String loginKey, {
    required bool skipNetworkSideEffects,
  }) {
    _lastImLoginKey = loginKey;
    _lastImLoginAt = DateTime.now();
    unawaited(PushIdentityCache.instance.refreshSelf());
    if (!skipNetworkSideEffects) {
      unawaited(
        PushRegistrationService.instance.syncAfterLogin().catchError((_) {}),
      );
    }
  }

  /// TIMUIKitCore.login can outlive native IM login; clear the stuck task and
  /// accept success when the SDK already has the expected user.
  Future<int> _recoverImLoginAfterTimeout(UserSigResult sig) async {
    resetImLoginState();
    final loginRes = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
    final userId = loginRes.data?.trim() ?? '';
    if (loginRes.code == 0 && userId.isNotEmpty && userId == sig.userId) {
      _lastImLoginKey = '${sig.sdkAppId}:${sig.userId}:${sig.userSig}';
      _lastImLoginAt = DateTime.now();
      await primeUIKitSession(sig);
      await _refreshCallStack(sig);
      return 0;
    }
    return -1;
  }

  Future<void> _refreshCallStack(UserSigResult sig) async {
    _trace(
      'AuthBootstrap: _refreshCallStack CALLED userId=${sig.userId}',
    );
    try {
      unawaited(IosApnsPushService.instance.syncLoginUserId(sig.userId));
      await CallLifecycleService.instance.ensureObserversAttached();
      await CallLifecycleService.instance.ensureFloatWindowEnabled();
      _trace(
        'AuthBootstrap: _refreshCallStack LiveKit signaling READY userId=${sig.userId}',
      );
    } catch (_) {}
  }

  Future<bool> refreshUserSigAndRelogin() async {
    final running = _refreshUserSigTask;
    if (running != null) {
      return running;
    }
    final task = _doRefreshUserSigAndRelogin();
    _refreshUserSigTask = task.whenComplete(() {
      if (identical(_refreshUserSigTask, task)) {
        _refreshUserSigTask = null;
      }
    });
    return _refreshUserSigTask!;
  }

  Future<bool> _doRefreshUserSigAndRelogin() async {
    LoginCoordinator.instance.markSessionRefreshing();
    try {
      final me = await AuthApi.instance.fetchMe();
      var sig = await AuthApi.instance.fetchUserSig();
      if (sig.userId.trim().isEmpty || sig.userSig.trim().isEmpty) {
        LoginCoordinator.instance.markFailed(
          LoginErrorType.fetchUserSigFailed,
          message: 'empty userSig payload',
          isBusinessAuthenticated: true,
          isHomeEntered: true,
        );
        return false;
      }
      if (!_isSameUserId(me.userId, sig.userId)) {
        _diag(
          'AuthBootstrap: refresh WARN me/sig mismatch '
          'me=${me.userId} sig=${sig.userId}; proceed with userSig',
        );
      }
      sig = _normalizeUserSig(sig);
      LoginCoordinator.instance.markImConnecting(
        userId: sig.userId,
        isRecovering: true,
      );
      await ImSessionCache.instance.save(sig);
      final imCode = await _loginImStack(sig, forceLogin: true);
      if (imCode == 0) {
        await refreshImUIKitLists();
        LoginCoordinator.instance.markImReady(userId: sig.userId);
        return true;
      }
      LoginCoordinator.instance.markFailed(
        LoginErrorType.imLoginFailed,
        message: 'userSig refresh relogin failed',
        userId: sig.userId,
        isBusinessAuthenticated: true,
        isHomeEntered: true,
      );
      return false;
    } on DioError catch (_) {
      LoginCoordinator.instance.markFailed(
        LoginErrorType.fetchUserSigFailed,
        message: 'Failed to refresh userSig',
        isBusinessAuthenticated: true,
        isHomeEntered: true,
      );
      return false;
    } catch (e, st) {
      LoginCoordinator.instance.markFailed(
        LoginErrorType.imLoginFailed,
        message: 'Unexpected error while refreshing userSig',
        cause: e,
        stackTrace: st,
        isBusinessAuthenticated: true,
        isHomeEntered: true,
      );
      return false;
    }
  }

  void resetImLoginState() {
    _loginGeneration++;
    _imLoginTask = null;
    _imLoginTaskKey = null;
    _lastImLoginKey = null;
    _lastImLoginAt = null;
  }

  bool _pushWakeRestoring = false;

  /// Called when Android FCM data push wakes a killed process.
  Future<bool> restoreSessionForPushWake() async {
    if (_pushWakeRestoring) return false;
    _pushWakeRestoring = true;
    try {
      await ApiClient.instance.loadToken();
      final token = ApiClient.instance.token;
      if (!ApiClient.isValidJwt(token)) {
        return false;
      }

      final me = await AuthApi.instance.fetchMe().timeout(
            const Duration(seconds: 4),
          );
      final expectedUserId = me.userId.trim();
      if (expectedUserId.isEmpty) {
        return false;
      }

      final nativeUserId = await getNativeLoginUserId();
      if (nativeUserId != null && nativeUserId != expectedUserId) {
        await clearLocalImSession(
          reason: 'push_wake_native_user_mismatch',
          clearCachedSession: true,
        );
      }

      if (_isSameUserId(nativeUserId, expectedUserId)) {
        await _refreshCallStackForWake(expectedUserId: expectedUserId);
        return true;
      }

      UserSigResult sig;
      var usedCachedSig = false;
      final cached = await ImSessionCache.instance.loadIfValidForUser(
        expectedUserId,
      );
      if (cached != null) {
        sig = cached;
        usedCachedSig = true;
      } else {
        sig = await AuthApi.instance.fetchUserSig();
        if (!_isSameUserId(sig.userId, expectedUserId)) {
          await clearLocalImSession(
            reason: 'push_wake_sig_user_mismatch',
            clearCachedSession: true,
          );
          return false;
        }
        await ImSessionCache.instance.save(sig);
      }

      final imCode = await _loginImStack(sig, forceLogin: true);
      if (imCode == 0) {
        return true;
      }
      if (!usedCachedSig) {
        return false;
      }
      final refreshedSig = await AuthApi.instance.fetchUserSig();
      if (!_isSameUserId(refreshedSig.userId, expectedUserId)) {
        await clearLocalImSession(
          reason: 'push_wake_refresh_sig_user_mismatch',
          clearCachedSession: true,
        );
        return false;
      }
      await ImSessionCache.instance.save(refreshedSig);
      final refreshedCode = await _loginImStack(refreshedSig, forceLogin: true);
      return refreshedCode == 0;
    } catch (_) {
      return false;
    } finally {
      _pushWakeRestoring = false;
    }
  }

  Future<void> _refreshCallStackForWake(
      {required String expectedUserId}) async {
    UserSigResult? sig = await ImSessionCache.instance.loadIfValidForUser(
      expectedUserId,
    );
    try {
      sig ??= await AuthApi.instance.fetchUserSig();
    } catch (_) {
      if (sig == null) return;
    }
    final resolvedSig = sig;
    if (!_isSameUserId(resolvedSig.userId, expectedUserId)) {
      await clearLocalImSession(
        reason: 'call_stack_wake_sig_user_mismatch',
        clearCachedSession: true,
      );
      return;
    }
    await ImSessionCache.instance.save(resolvedSig);
    await CallLifecycleService.instance.ensureObserversAttached();
    await CallLifecycleService.instance.ensureFloatWindowEnabled();
  }
}
