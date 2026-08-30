import 'dart:async';
import 'dart:convert';

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/android_performance_profile.dart';
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/services/android_jpush_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/android_keep_alive_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/incoming_call_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/incoming_call_push_handler.dart';
import 'package:tencent_cloud_chat_demo/src/services/ios_apns_push_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_registration_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_msgkey_dedup.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_notification_router.dart';
import 'package:tencent_cloud_chat_demo/src/services/in_app_notification_sound.dart';
import 'package:tencent_cloud_chat_demo/src/services/in_app_notification_vibration.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_chat_notification_clear_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_chat_notification_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/local_system_notification_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/me_notification_settings_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/in_app_message_notification_banner.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/src/utils/voip_push_payload.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_lifecycle_service.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_demo/src/services/call_lifecycle_service_web.dart';
import 'package:tencent_cloud_chat_demo/src/services/external_chat_entry_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/app_badge_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_permission_service.dart';
import 'package:tencent_cloud_chat_demo/src/models/notification_display_mode.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/utils/push_identity_cache.dart';
import 'package:tencent_cloud_chat_demo/src/utils/notification_push_text.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_conversation_unread_helper.dart';
import 'package:tencent_cloud_chat_demo/src/utils/typing_status_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/life_payment_order_update_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/red_packet_claim_notice_message.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_change_event_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tips_operator_live_cache.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_push/common/tim_push_listener.dart';
import 'package:tencent_cloud_chat_push/common/tim_push_message.dart';
import 'package:tencent_cloud_chat_push/tencent_cloud_chat_push.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_at_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_at_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_demo/src/platform/call_state_display_name_bridge.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_demo/src/platform/push_handler.dart';
import 'package:tencent_cloud_chat_demo/src/platform/route_handler.dart';

typedef NotificationClickHandler = void Function({
  required String ext,
  String? groupID,
  String? userID,
});

class NotificationSettingsService {
  NotificationSettingsService._();

  static final NotificationSettingsService instance =
      NotificationSettingsService._();

  LocalSetting? _localSetting;
  NotificationClickHandler? _onNotificationClicked;
  final Set<String> _inflightMsgKeys = <String>{};
  bool _pushListenerAttached = false;
  bool _pushRegistered = false;
  Future<void>? _pushRegisterTask;
  DateTime? _pushRegisterBlockedUntil;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  bool _suppressColdStartForegroundBanner = true;
  DateTime? _allowForegroundBannerAfter;
  final Map<String, DateTime> _lastSystemNotificationAt = <String, DateTime>{};
  static const Duration _systemNotificationMinInterval = Duration(seconds: 2);

  final TIMPushListener _pushListener = TIMPushListener(
    onRecvPushMessage: (message) {
      instance._onRecvPushMessage(message);
    },
  );

  void attach(LocalSetting localSetting) {
    _localSetting = localSetting;
    configureCallStateDisplayNameResolver();
    DisplayNameStore.instance.addListener(_syncVoipDisplayNameCache);
    _syncVoipDisplayNameCache();
    beginColdStartBannerSuppression();
    localSetting.onNotificationSettingsChanged = applyFromSettings;
    AppBadgeSyncService.instance.ensureListenersAttached();
    if (_onNotificationClicked == null) {
      setNotificationClickHandler(_handleDefaultNotificationClick);
    }
    // Web 端不挂移动端通知/通话监听。
    // Tencent IM Web SDK 在未登录或未 SDK_READY 时添加 AdvancedMsgListener
    // 会触发 submitMessageReactionChanged 空值异常；Web 聊天页自身会拉取会话和历史。
    if (kIsWeb) {
      return;
    }
    unawaited(ensureListenersAttached());
    unawaited(LocalSystemNotificationService.instance.initializeTapBridge(
      onNotificationTap: _handleLocalSystemNotificationTap,
    ));
  }

  void setNotificationClickHandler(NotificationClickHandler handler) {
    _onNotificationClicked = handler;
  }

  void _syncVoipDisplayNameCache() {
    if (kIsWeb || !PlatformUtils().isIOS) {
      return;
    }
    unawaited(
      IosApnsPushService.instance.syncDisplayNameCache(
        DisplayNameStore.instance.snapshotC2C(),
      ),
    );
  }

  void beginColdStartBannerSuppression() {
    _suppressColdStartForegroundBanner = true;
    _allowForegroundBannerAfter = null;
  }

  void endColdStartBannerSuppression({
    Duration grace = const Duration(seconds: 2),
  }) {
    _suppressColdStartForegroundBanner = false;
    _allowForegroundBannerAfter = DateTime.now().add(grace);
    unawaited(
      ImChatNotificationClearService.instance.clearAllImChatNotifications(
        reason: 'cold_start_ready',
      ),
    );
  }

  void setLifecycle(AppLifecycleState state) {
    final previous = _lifecycle;
    _lifecycle = state;
    AppBadgeSyncService.instance.setLifecycle(state);
    ActiveChatRegistry.instance.setLifecycleForeground(
      state == AppLifecycleState.resumed,
    );
    _traceMsgBanner('lifecycle_state previous=$previous next=$state');

    final enteredForeground = state == AppLifecycleState.resumed &&
        (previous == AppLifecycleState.paused ||
            previous == AppLifecycleState.hidden ||
            previous == AppLifecycleState.detached ||
            previous == AppLifecycleState.inactive);

    if (enteredForeground) {
      unawaited(LocalSystemNotificationService.instance.consumePendingTap());
      unawaited(
        ImChatNotificationClearService.instance.onAppEnteredForeground(
          reason: 'lifecycle_resumed',
        ),
      );
      unawaited(applyFromSettings());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (!kIsWeb && Platform.isAndroid) {
        AndroidPerformanceProfile.instance.trimImageCacheForBackground();
      }
      unawaited(
        AppBadgeSyncService.instance.syncForBackground(
          reason: 'lifecycle_$state',
        ),
      );
    }

    CallLifecycleService.instance.onLifecycleChanged(state);
  }

  Future<void> ensureListenersAttached(
      {bool forceMessageListener = false}) async {
    if (kIsWeb) {
      return;
    }
    if (PlatformUtils().isIOS && !_useSelfHostedPush) {
      await _ensurePushListenerAttached();
    }
  }

  /// Compatibility entry retained for bootstrap callers. The ordinary
  /// message listener is owned by ConversationSyncService's adapter.
  Future<void> ensureMessageListenerReady({bool force = false}) async {
    // Ordinary IM messages are delivered by ConversationSyncService's single
    // TencentAdvancedMessageAdapter. Keep this method as a compatibility no-op
    // for existing bootstrap callers while push listeners remain independent.
  }

  bool get _useSelfHostedPush => IMDemoConfig.selfHostedPushEnabled;

  // 前台系统横幅排查：真机对照 MSG_BANNER_TRACE / show_result；稳定后可改回 false。
  static const bool _msgBannerTraceEnabled = false;

  void _traceMsgBanner(String message) {
    if (!_msgBannerTraceEnabled) return;
    // ignore: avoid_print
    print('MSG_BANNER_TRACE $message');
  }

  Future<void> _ensurePushListenerAttached() async {
    if (_pushListenerAttached) {
      return;
    }
    _pushListenerAttached = true;
    await TencentCloudChatPush().addPushListener(listener: _pushListener);
  }

  Future<void> applyFromSettings() async {
    final settings = _localSetting;
    if (settings == null || kIsWeb) {
      return;
    }

    await ensureListenersAttached();
    await CallLifecycleService.instance.ensureObserversAttached();

    if (PlatformUtils().isAndroid) {
      if (PushHandler.needsTimPush(settings)) {
        // Android 13+ 通知栏权限未授权时，后台在线消息可到达 IM SDK，
        // 但本地系统通知会被系统拦截，表现为“后台收不到通知”。
        await NotificationPermissionService.instance.requestSystemPermission();
      }
      if (_useSelfHostedPush && IMDemoConfig.androidJPushEnabled) {
        AndroidJPushService.instance.setInForegroundResolver(_isInForeground);
        await AndroidJPushService.instance.applyFromSettings(
          settings,
          onNotificationTap: _handleAndroidJPushNotificationTap,
        );
      } else if (_useSelfHostedPush) {
        await AndroidJPushService.instance.disableForAppPolicy();
      } else if (IMDemoConfig.androidJPushEnabled) {
        AndroidJPushService.instance.setInForegroundResolver(_isInForeground);
        await AndroidJPushService.instance.applyFromSettings(
          settings,
          onNotificationTap: _handleAndroidJPushNotificationTap,
        );
      } else {
        await AndroidJPushService.instance.disableForAppPolicy();
      }
      await AndroidKeepAliveService.instance.applyFromSettings(settings);
      if (PushHandler.needsTimPush(settings)) {
        unawaited(
          AndroidKeepAliveService.instance.ensureRunning(
            reason: 'apply_settings',
          ),
        );
      }
    } else if (PlatformUtils().isIOS) {
      if (PushHandler.needsTimPush(settings)) {
        await NotificationPermissionService.instance.requestSystemPermission();
      }
      if (_useSelfHostedPush) {
        await IosApnsPushService.instance.applyFromSettings(
          settings,
          onNotificationTap: handleSelfHostedPushTap,
          onVoipPush: _handleVoipPushPayload,
          onRemoteNotificationReceived: _handleRemoteNotificationReceived,
        );
      } else {
        await _syncTimPushRegistration(settings);
        await TencentCloudChatPush().disablePostNotificationInForeground(
          disable: true,
        );
      }
    } else if (PlatformUtils().isMobile) {
      await _syncTimPushRegistration(settings);
      await TencentCloudChatPush().disablePostNotificationInForeground(
        disable: true,
      );
    }

    // 通话浮窗/最小化与通知横幅解耦，避免关闭通知后无法后台浮窗。
    await CallLifecycleService.instance.ensureFloatWindowEnabled();
    unawaited(syncCallNotificationPreferenceToNative());
    await _syncOfflinePushPresence(settings);
    unawaited(consumePendingConversationOpen());
  }

  /// 登录后或进入设置页时，从服务端拉取「未打开时」通知偏好。
  Future<void> syncRemotePreferencesFromServer() async {
    final settings = _localSetting;
    if (settings == null || kIsWeb) {
      return;
    }
    try {
      await MeNotificationSettingsSyncService.instance.fetchAndApply(settings);
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint(
          'NotificationSettings: sync remote preferences failed: $error\n$stack',
        );
      }
    }
  }

  Future<void> _syncTimPushRegistration(LocalSetting settings) async {
    if (_useSelfHostedPush) {
      if (_pushRegistered) {
        await TencentCloudChatPush().unRegisterPush();
        _pushRegistered = false;
      }
      return;
    }
    final needsPush = PushHandler.needsTimPush(settings);
    final blockedUntil = _pushRegisterBlockedUntil;
    if (blockedUntil != null && DateTime.now().isBefore(blockedUntil)) {
      return;
    }
    if (!needsPush) {
      if (_pushRegistered) {
        await TencentCloudChatPush().unRegisterPush();
        _pushRegistered = false;
      }
      return;
    }

    final permissionGranted =
        await NotificationPermissionService.instance.requestSystemPermission();
    if (!permissionGranted) {
      if (kDebugMode) {
        debugPrint(
            'NotificationSettings: system notification permission denied');
      }
      return;
    }

    final loginRes = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
    if (loginRes.data == null || loginRes.data!.isEmpty) {
      return;
    }

    if (_pushRegistered) {
      return;
    }

    final runningTask = _pushRegisterTask;
    if (runningTask != null) {
      await runningTask;
      return;
    }

    final task = _registerPushOnce();
    _pushRegisterTask = task;
    try {
      await task;
    } finally {
      _pushRegisterTask = null;
    }
  }

  Future<void> _registerPushOnce() async {
    final handler = _onNotificationClicked ?? _handleDefaultNotificationClick;
    final result = await TencentCloudChatPush().registerPush(
      onNotificationClicked: handler,
      apnsCertificateID: kReleaseMode
          ? IMDemoConfig.apnsCertificateIDRelease
          : IMDemoConfig.apnsCertificateIDDebug,
    );
    if (result.code == 0) {
      _pushRegistered = true;
      _pushRegisterBlockedUntil = null;
      return;
    }

    final code = result.code;
    var message = '';
    try {
      message = ((result as dynamic).errorMessage.toString()).toLowerCase();
    } catch (_) {}
    if (code == 22001 ||
        message.contains('offline push certificates') ||
        message.contains('invalid business')) {
      _pushRegisterBlockedUntil =
          DateTime.now().add(const Duration(minutes: 10));
    }
  }

  Future<void> _syncOfflinePushPresence(LocalSetting settings) async {
    if (!PlatformUtils().isMobile) {
      return;
    }
    final inForeground = _isInForeground();
    if (inForeground || !PushHandler.needsTimPush(settings)) {
      await AppBadgeSyncService.instance.syncForForeground(
        reason: 'offline_push_presence',
      );
      return;
    }
    await AppBadgeSyncService.instance.syncForBackground(
      reason: 'offline_push_presence',
    );
  }

  void _handleDefaultNotificationClick({
    required String ext,
    String? groupID,
    String? userID,
  }) {
    if (NotificationPushText.isCallPush(ext: ext)) {
      return;
    }
    unawaited(openConversationFromPushClick(
      ext: ext,
      groupID: groupID,
      userID: userID,
      source: 'offline_push_click',
    ));
  }

  Future<void> ensureSelfHostedPushTapHandler() async {
    if (kIsWeb || !_useSelfHostedPush) {
      return;
    }
    if (PlatformUtils().isIOS) {
      await IosApnsPushService.instance.install(
        onNotificationTap: handleSelfHostedPushTap,
        onVoipPush: _handleVoipPushPayload,
        onRemoteNotificationReceived: _handleRemoteNotificationReceived,
      );
      await IosApnsPushService.instance.consumePendingNotificationTap();
    }
  }

  Future<void> _handleRemoteNotificationReceived(
    Map<String, dynamic> data,
  ) async {
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    if (type != 'im_chat' && type != 'chat_message') {
      return;
    }
    final msgKey = PushMsgKeyDedup.instance.normalizeKey(data['msgKey']);
    if (msgKey == null) {
      return;
    }
    await PushMsgKeyDedup.instance.ensureReady();

    if (_isInForeground()) {
      // 前台横幅已改为本地系统通知；勿清掉同 msgKey 的本地条。
      // 远程 Push 在 willPresent 里已被压掉且不再对本地点火本回调。
      PushMsgKeyDedup.instance.trace('foreground_skip_clear', msgKey, 'apns');
      return;
    }

    if (PushMsgKeyDedup.instance.wasHandled(msgKey)) {
      PushMsgKeyDedup.instance.trace('clear_push', msgKey, 'apns');
      await ImChatNotificationClearService.instance.cancelByMsgKey(msgKey);
      return;
    }

    if (!PushMsgKeyDedup.instance.tryClaim(msgKey)) {
      PushMsgKeyDedup.instance.trace('claim_failed', msgKey, 'apns');
      await ImChatNotificationClearService.instance.cancelByMsgKey(msgKey);
      return;
    }

    await IosApnsPushService.instance.syncHandledMsgKey(msgKey);
  }

  Future<void> handleSelfHostedPushTap(Map<String, dynamic> data) async {
    final source = data['_source']?.toString() ?? 'self_hosted_push_tap';
    final payload = Map<String, dynamic>.from(data)..remove('_source');
    if (kDebugMode) {
      debugPrint(
        'NotificationSettings: push tap source=$source payload=$payload',
      );
    }
    await PushNotificationRouter.handleTap(
      rawData: payload,
      source: source,
      openConversation: ({
        ext,
        conversationID,
        groupID,
        userID,
        required String source,
      }) {
        return openConversationFromPushClick(
          ext: ext ?? '',
          conversationID: conversationID,
          groupID: groupID,
          userID: userID,
          source: source,
        );
      },
    );
  }

  Future<void> openConversationFromPushClick({
    required String ext,
    String? conversationID,
    String? groupID,
    String? userID,
    String source = 'push_click',
  }) async {
    await ImChatNotificationClearService.instance.clearAllImChatNotifications(
      reason: 'push_click',
    );
    await _enqueueExternalConversationOpen(
      source: source,
      ext: ext,
      conversationID: conversationID,
      groupID: groupID,
      userID: userID,
    );
  }

  void _onRecvPushMessage(TimPushMessage message) {
    // 前台普通消息通知统一交给 V2TimAdvancedMsgListener.onRecvNewMessage 处理。
    // TIMPushListener.onRecvPushMessage 在同账号多端同步时拿不到可靠 sender，
    // 如果这里也弹横幅，会出现“自己另一台设备发的消息仍然通知”的问题。
    // 后台/锁屏 APNS 点击仍由 registerPush(onNotificationClicked) 处理，不受影响。
    final settings = _localSetting;
    if (settings == null || !settings.notifySystemMessage) {
      return;
    }

    final isCall = NotificationPushText.isCallPush(
      title: message.title,
      desc: message.desc,
      ext: message.ext,
    );
    if (isCall) {
      return;
    }

    if (_isInForeground()) {
      return;
    }
  }

  String? _cachedLoginUserId;
  _PendingConversationOpen? _pendingConversationOpen;
  Timer? _pendingConversationTimer;
  bool _consumingPendingConversation = false;
  bool _consumePendingAgain = false;
  bool _homeRouteReady = false;
  static const Duration _pendingConversationTtl = Duration(minutes: 5);
  static const Duration _pendingVisibilityTimeout = Duration(seconds: 4);

  void markHomeRouteReady() {
    if (_homeRouteReady) {
      return;
    }
    _homeRouteReady = true;
    final pending = _pendingConversationOpen;
    ExternalChatEntryService.instance.logFlow(
      'home_route_ready',
      source: 'home_page',
      conversationID: pending?.conversationID,
    );
    if (pending != null) {
      _schedulePendingConversationConsume(Duration.zero);
    }
  }

  void markHomeRouteNotReady() {
    _homeRouteReady = false;
  }

  Future<String?> _currentLoginUserId() async {
    try {
      final res = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
      final userId = res.data?.trim();
      if (userId != null && userId.isNotEmpty) {
        _cachedLoginUserId = userId;
        return userId;
      }
    } catch (_) {}
    return _cachedLoginUserId;
  }

  Future<bool> _isMessageFromCurrentLoginUser(
    V2TimMessage message, {
    String? loginUserId,
  }) async {
    if (message.isSelf == true) {
      return true;
    }

    final loginUser = loginUserId ?? await _currentLoginUserId();
    if (loginUser == null || loginUser.isEmpty) {
      return false;
    }

    if (GroupTipsMessageHelper.isSelfOperated(message, loginUser)) {
      return true;
    }

    for (final candidate in <String?>[
      message.sender,
      message.userID,
    ]) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty && value == loginUser) {
        return true;
      }
    }

    return false;
  }

  Future<bool> _shouldSuppressForConversationDisturb({
    required V2TimMessage message,
    required String? conversationId,
    int? recvOpt,
  }) async {
    final id = conversationId?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }

    var opt = recvOpt;
    if (opt == null) {
      final convRes = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getConversation(conversationID: id);
      opt = convRes.data?.recvOpt ??
          ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE.index;
    }

    if (opt == ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE.index) {
      return false;
    }

    if (opt ==
            ReceiveMsgOptEnum
                .V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE_EXCEPT_AT.index ||
        opt == ReceiveMsgOptEnum.V2TIM_NOT_RECEIVE_MESSAGE_EXCEPT_AT.index) {
      return !(await _messageAtCurrentUser(message));
    }

    return true;
  }

  Future<bool> _messageAtCurrentUser(V2TimMessage message) async {
    final loginUser = await _currentLoginUserId();
    if (loginUser == null || loginUser.isEmpty) {
      return false;
    }

    final atList = message.groupAtUserList ?? const <String>[];
    if (atList.isEmpty) {
      return false;
    }

    for (final raw in atList) {
      final at = raw.trim();
      if (at.isEmpty) {
        continue;
      }
      if (at == loginUser ||
          at == V2TimGroupAtInfo.AT_ALL_TAG ||
          at == V2TimGroupAtInfo.c_api_tag) {
        return true;
      }
    }
    return false;
  }

  /// Application-layer entry called by the single ordinary-message ingress.
  Future<void> handleAppRealtimeMessage(V2TimMessage message) {
    return _onRecvNewMessage(message);
  }

  Future<void> _onRecvNewMessage(V2TimMessage message) async {
    await PushMsgKeyDedup.instance.ensureReady();
    if (TypingStatusMessage.isTypingStatus(message)) {
      _traceMsgBanner('skip reason=typing_status');
      return;
    }
    final inflightKey = _messageInflightKey(message);
    if (_inflightMsgKeys.contains(inflightKey)) {
      _traceMsgBanner('skip reason=duplicate_inflight key=$inflightKey');
      return;
    }
    _inflightMsgKeys.add(inflightKey);
    try {
      await _handleRecvNewMessage(message);
    } finally {
      _inflightMsgKeys.remove(inflightKey);
    }
  }

  String _messageInflightKey(V2TimMessage message) {
    final msgKey = PushMsgKeyDedup.instance.msgKeyFromMessage(message);
    if (msgKey != null && msgKey.isNotEmpty) {
      return msgKey;
    }
    final msgID = message.msgID?.trim();
    if (msgID != null && msgID.isNotEmpty) {
      return 'id:$msgID';
    }
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty) {
      return 'local:$id';
    }
    return '${message.timestamp}_${message.random}_${message.sender}';
  }

  Future<void> _handleRecvNewMessage(V2TimMessage message) async {
    // 生活缴费订单 IM 推送：尽早广播，供缴费页提前刷新（文档 §7）。
    LifePaymentOrderUpdateBus.instance.ingestMessage(message);
    final convIdForLatency = _conversationIdFromMessage(message);
    if (convIdForLatency != null && convIdForLatency.isNotEmpty) {
      ConversationPerfGateLog.markRealtimeMsgRecv(
        conversationId: convIdForLatency,
        msgId: message.msgID,
      );
    }
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'new_message',
      conversationId: _conversationIdFromMessage(message),
      debounce: Duration.zero,
    );
    // 横幅门禁之前入库：settings 为空或关系统通知时仍要把对方写进通讯录。
    unawaited(applyInboundFriendBecameFriendsIfNeeded(message));
    // 群改名/换头 tip → 只写对应 Group Entity（非全量）。
    unawaited(
      GroupMembershipSyncService.instance
          .applyInboundGroupDisplayFromMessage(message),
    );
    // 拉人/踢人/退群 tip → 成员首屏（TCP 丢包备份）。
    unawaited(
      GroupMembershipSyncService.instance
          .applyInboundMembershipTipFromMessage(message),
    );
    final msgKey = PushMsgKeyDedup.instance.msgKeyFromMessage(message);
    final settings = _localSetting;
    if (settings == null) {
      _traceMsgBanner('skip reason=settings_null');
      return;
    }
    final loginUser = await _currentLoginUserId();
    if (await _isMessageFromCurrentLoginUser(
      message,
      loginUserId: loginUser,
    )) {
      // 本人操作的原生 tip 偶发仍被 SDK 计入未读。
      if (GroupTipsMessageHelper.shouldSuppressConversationUnread(message)) {
        final tipConvId = _conversationIdFromMessage(message);
        if (tipConvId != null && tipConvId.isNotEmpty) {
          unawaited(
            GroupConversationUnreadHelper.absorbOneUnreadBump(
              tipConvId,
              effectId: msgKey,
            ),
          );
        }
      }
      _traceMsgBanner('skip reason=self_message');
      return;
    }
    if (!settings.notifySystemMessage) {
      _traceMsgBanner('skip reason=system_message_off');
      return;
    }
    // 原生 tip / 静默 tip：不展示、不弹横幅，并扣回 SDK 误增的未读。
    if (GroupTipsMessageHelper.shouldSuppressConversationUnread(message)) {
      final tipConvId = _conversationIdFromMessage(message);
      if (tipConvId != null && tipConvId.isNotEmpty) {
        unawaited(
          GroupConversationUnreadHelper.absorbOneUnreadBump(
            tipConvId,
            effectId: msgKey,
          ),
        );
      }
      _traceMsgBanner('skip reason=suppress_tip_unread');
      return;
    }
    if (isRedPacketClaimNoticeMessage(message)) {
      _traceMsgBanner('skip reason=red_packet_claim_notice');
      return;
    }

    final convId = _conversationIdFromMessage(message);
    final inForeground = _isInForeground();
    final lifecycle = _currentLifecycleState();
    final inCurrentChat = inForeground && _isCurrentConversationId(convId);
    _traceMsgBanner(
      'recv conv=${convId ?? ''} msgID=${message.msgID ?? ''} '
      'foreground=$inForeground inCurrentChat=$inCurrentChat '
      'lifecycle=$lifecycle cachedLifecycle=$_lifecycle',
    );

    if (_isCallSignalMessage(message)) {
      _traceMsgBanner('skip reason=call_signal');
      return;
    }

    if (_isFriendRelationshipChangeMessage(message)) {
      final convId = _conversationIdFromMessage(message);
      if (convId != null && convId.isNotEmpty) {
        GroupConversationUnreadHelper.scheduleClearForSelfOperatedGroupTips(
          convId,
          effectId: msgKey,
        );
      }
      _traceMsgBanner('skip reason=friend_relationship_change');
      return;
    }

    if (await _shouldSuppressForConversationDisturb(
      message: message,
      conversationId: convId,
    )) {
      _traceMsgBanner('skip reason=conversation_disturb conv=${convId ?? ''}');
      return;
    }

    if (_isInActiveCall()) {
      _traceMsgBanner('skip reason=in_active_call');
      return;
    }

    // App 在后台时，即使当前页面停留在这个会话，也必须弹系统通知；
    // 否则用户按 Home 后收到在线 IM 消息但通知栏没有提示。
    // 当前会话内只播放应用内提示音/振动，不弹系统横幅。
    if (inCurrentChat) {
      _traceMsgBanner('skip banner reason=in_current_chat alert_only');
      await _waitForMessageUiCatchUp(conversationId: convId);
      _playInAppMessageAlert(settings);
      return;
    }

    if (inForeground) {
      if (!PushHandler.allowsMessageBanner(settings)) {
        if (!_shouldSuppressForegroundMessageBanner() &&
            PushHandler.wantsInAppMessageAlert(settings)) {
          if (_shouldThrottleConversationNotice(convId)) {
            _traceMsgBanner(
              'skip reason=conversation_throttled conv=${convId ?? ''}',
            );
            return;
          }
          _traceMsgBanner('alert_only reason=message_banner_disabled');
          _playInAppMessageAlert(settings);
        } else {
          _traceMsgBanner('skip reason=message_banner_disabled');
        }
        return;
      }
      if (_shouldSuppressForegroundMessageBanner()) {
        _traceMsgBanner(
          'skip reason=foreground_banner_suppressed '
          'cold=$_suppressColdStartForegroundBanner '
          'allowAfter=$_allowForegroundBannerAfter',
        );
        return;
      }
    }

    if (_shouldThrottleConversationNotice(convId)) {
      _traceMsgBanner(
          'skip reason=conversation_throttled conv=${convId ?? ''}');
      return;
    }

    if (msgKey != null && PushMsgKeyDedup.instance.wasHandled(msgKey)) {
      _traceMsgBanner('skip reason=msgkey_already_handled key=$msgKey');
      return;
    }

    final displayMode = inForeground
        ? settings.notifyBannerDisplayContent
        : settings.notifyDisplayContent;

    // 前台已改走本地系统通知横幅；勿在展示前 cancelByMsgKey，
    // 否则会与即将弹出的本地条抢同一 msgKey。远程残留仍由 willPresent 清理。

    if (GroupTipsMessageHelper.isSuppressedAdministratorTip(message)) {
      _traceMsgBanner('skip reason=suppressed_admin_group_tip');
      return;
    }

    if (GroupTipsMessageHelper.isImAdministratorMemberTip(message)) {
      final groupId = message.groupID?.trim() ??
          message.groupTipsElem?.groupID.trim() ??
          '';
      if (groupId.isNotEmpty) {
        unawaited(
          GroupChangeEventSyncService.instance.syncForGroup(
            groupId,
            reason: 'banner_operator_wait',
          ),
        );
      }
      final preview = await GroupTipsOperatorLiveCache.waitForPreview(message);
      if (preview == null || preview.trim().isEmpty) {
        _traceMsgBanner('skip reason=admin_group_tip_unresolved');
        return;
      }
    }

    final notified = await _showSystemNotificationForMessage(
      message: message,
      conversationId: convId,
      displayMode: displayMode,
    );
    _traceMsgBanner(
      'show_result notified=$notified foreground=$inForeground '
      'displayMode=$displayMode overlay=${AppNavigator.overlay != null}',
    );
    if (inForeground &&
        (notified || displayMode == NotificationDisplayMode.hidden)) {
      _playInAppMessageAlert(settings);
    }
  }

  void _playInAppMessageAlert(LocalSetting settings) {
    if (settings.notifyMessageSound) {
      unawaited(
        InAppNotificationSound.playSound(settings.messageNotificationSoundId),
      );
    }
    if (settings.notifyVibration) {
      unawaited(InAppNotificationVibration.playMessageReceived());
    }
  }

  bool _isSilentGroupTipMessage(V2TimMessage message) {
    return GroupTipsMessageHelper.isSilentGroupTipMessage(message);
  }

  bool _shouldThrottleConversationNotice(String? conversationId) {
    final id = conversationId?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    final now = DateTime.now();
    final last = _lastSystemNotificationAt[id];
    if (last != null && now.difference(last) < _systemNotificationMinInterval) {
      return true;
    }
    _lastSystemNotificationAt[id] = now;
    if (_lastSystemNotificationAt.length > 80) {
      _lastSystemNotificationAt.removeWhere(
        (_, value) => now.difference(value) > const Duration(minutes: 10),
      );
    }
    return false;
  }

  bool _shouldSuppressForegroundMessageBanner() {
    if (_suppressColdStartForegroundBanner) {
      return true;
    }
    final allowAfter = _allowForegroundBannerAfter;
    if (allowAfter == null) {
      return false;
    }
    if (DateTime.now().isBefore(allowAfter)) {
      return true;
    }
    _allowForegroundBannerAfter = null;
    return false;
  }

  Future<bool> _showSystemNotificationForMessage({
    required V2TimMessage message,
    required String? conversationId,
    required NotificationDisplayMode displayMode,
  }) async {
    await PushMsgKeyDedup.instance.ensureReady();
    if (_isSilentGroupTipMessage(message)) {
      return false;
    }
    var conversationLabel = message.nickName;
    var faceUrl = message.faceUrl ?? '';
    V2TimConversation? conversation;
    final inForeground = _isInForeground();
    if (conversationId != null && conversationId.isNotEmpty) {
      // 优先内存会话，避免前台横幅被 SDK getConversation 卡住。
      for (final item in ConversationListNotifier.instance.conversations) {
        if (item.conversationID == conversationId) {
          conversation = item;
          break;
        }
      }
      if (conversation == null) {
        final convRes = await TencentImSDKPlugin.v2TIMManager
            .getConversationManager()
            .getConversation(conversationID: conversationId);
        conversation = convRes.data;
      }
      conversationLabel = conversation?.showName ?? conversationLabel;
      faceUrl = conversation?.faceUrl ?? faceUrl;
      if (await _shouldSuppressForConversationDisturb(
        message: message,
        conversationId: conversationId,
        recvOpt: conversation?.recvOpt,
      )) {
        return false;
      }
    }

    final messageGroupId = (message.groupID ?? '').trim();
    final isGroupMessage = messageGroupId.isNotEmpty;
    if (isGroupMessage) {
      final looked = PushIdentityCache.instance.lookupConversation(
        (conversationId != null && conversationId.isNotEmpty)
            ? conversationId
            : 'group_$messageGroupId',
        groupId: messageGroupId,
      );
      final localName = looked?.showName?.trim() ?? '';
      if (localName.isNotEmpty) {
        conversationLabel = localName;
      }
      final localFace = looked?.faceUrl?.trim() ?? '';
      if (localFace.isNotEmpty) {
        faceUrl = localFace;
      }
    }

    final text = NotificationPushText.fromMessage(
      message,
      mode: displayMode,
      conversationLabel: conversationLabel,
    );

    var title = text.title;
    var body = text.body;

    if (body.trim().isEmpty) {
      return false;
    }

    final isGroup =
        message.groupID != null && message.groupID!.trim().isNotEmpty;
    if (isGroup && displayMode == NotificationDisplayMode.full) {
      final sender = (message.nickName ?? message.sender ?? '').trim();
      if (sender.isNotEmpty && !body.startsWith(sender)) {
        body = '$sender: $body';
      }
    }

    final msgKey = PushMsgKeyDedup.instance.msgKeyFromMessage(message);
    if (msgKey != null) {
      if (PushMsgKeyDedup.instance.wasHandled(msgKey)) {
        PushMsgKeyDedup.instance.trace('claim_skip', msgKey, 'im_online');
        return false;
      }
      // Dart 侧先占坑防并发双弹；成功展示后再 sync 到 iOS handledMsgKeys，
      // 避免 willPresent 因「已 handled」把本地系统通知压掉。
      if (!PushMsgKeyDedup.instance.tryClaim(msgKey)) {
        PushMsgKeyDedup.instance.trace('claim_failed', msgKey, 'im_online');
        return false;
      }
    }
    if (inForeground && displayMode == NotificationDisplayMode.hidden) {
      if (msgKey != null) {
        PushMsgKeyDedup.instance.releaseClaim(msgKey);
      }
      return false;
    }
    final sender = (message.sender ?? message.userID ?? '').trim();
    final groupId = (message.groupID ?? '').trim();
    final showSenderIdentity = displayMode == NotificationDisplayMode.full;
    final resolvedAvatarUrl = showSenderIdentity
        ? PushIdentityCache.resolvePushAvatarUrl(faceUrl)
        : '';
    final threadId = isGroup
        ? ImChatNotificationRegistry.threadIdFor(
            chatType: 'group',
            peerOrGroupId: groupId,
          )
        : ImChatNotificationRegistry.threadIdFor(
            chatType: 'c2c',
            peerOrGroupId: sender,
          );
    final resolvedConversationId = (conversationId?.trim().isNotEmpty ?? false)
        ? conversationId!.trim()
        : (threadId.isNotEmpty
            ? threadId
            : (isGroup && groupId.isNotEmpty
                ? 'group_$groupId'
                : (sender.isNotEmpty ? 'c2c_$sender' : '')));
    final ext = jsonEncode(<String, dynamic>{
      'conversationID': resolvedConversationId,
      'type': 'im_chat',
      'chatType': isGroup ? 'group' : 'c2c',
      if (sender.isNotEmpty) 'fromAccount': sender,
      if (groupId.isNotEmpty) 'groupId': groupId,
      if (msgKey != null) 'msgKey': msgKey,
      if (threadId.isNotEmpty) 'threadId': threadId,
      if (resolvedAvatarUrl.isNotEmpty) 'avatarUrl': resolvedAvatarUrl,
    });

    final shown = await LocalSystemNotificationService.instance.showChatMessage(
      title: title,
      body: body,
      conversationID: resolvedConversationId.isNotEmpty
          ? resolvedConversationId
          : conversationId,
      ext: ext,
      avatarUrl: resolvedAvatarUrl.isNotEmpty ? resolvedAvatarUrl : null,
      notificationId: msgKey != null
          ? ImChatNotificationRegistry.notificationIdFor(msgKey)
          : null,
      msgKey: msgKey,
      threadId: threadId,
    );
    if (shown) {
      if (msgKey != null) {
        await PushMsgKeyDedup.instance.persist();
        await IosApnsPushService.instance.syncHandledMsgKey(msgKey);
        ImChatNotificationRegistry.instance.register(
          threadId: threadId,
          notificationId: ImChatNotificationRegistry.notificationIdFor(msgKey),
          msgKey: msgKey,
        );
      }
    } else if (msgKey != null) {
      PushMsgKeyDedup.instance.releaseClaim(msgKey);
    }
    if (kDebugMode) {
      debugPrint(
        'NotificationSettings: system notification shown=$shown '
        'foreground=$inForeground '
        'conversationId=${resolvedConversationId.isNotEmpty ? resolvedConversationId : (conversationId ?? '')}',
      );
    }
    return shown;
  }

  Future<bool> _openConversationRoute(
    String conversationID,
    dynamic conversation, {
    required String source,
  }) {
    return RouteHandler.openChat(
      conversationID: conversationID,
      conversation: conversation,
      source: source,
    );
  }

  Future<void> resetForLogout() async {
    InAppMessageNotificationBanner.hide();
    InAppMessageNotificationBanner.resetRateLimit();
    if (kIsWeb) {
      _pushListenerAttached = false;
      _pushRegistered = false;
      _pushRegisterTask = null;
      _pushRegisterBlockedUntil = null;
      _cachedLoginUserId = null;
      _pendingConversationTimer?.cancel();
      _pendingConversationTimer = null;
      _pendingConversationOpen = null;
      _consumingPendingConversation = false;
      _consumePendingAgain = false;
      _homeRouteReady = false;
      _lastSystemNotificationAt.clear();
      _inflightMsgKeys.clear();
      ActiveChatRegistry.instance.reset();
      return;
    }
    try {
      await (TencentCloudChatPush() as dynamic).removePushListener(
        listener: _pushListener,
      );
    } catch (_) {}
    try {
      await PushRegistrationService.instance.clearLocalPushStateOnLogout();
      if (_pushRegistered) {
        await TencentCloudChatPush().unRegisterPush();
      }
    } catch (_) {}
    PushMsgKeyDedup.instance.clear();
    ImChatNotificationRegistry.instance.clearAll();
    IncomingCallPushHandler.instance.clear();
    IncomingCallCoordinator.instance.clear();
    _pushListenerAttached = false;
    _pushRegistered = false;
    _pushRegisterTask = null;
    _pushRegisterBlockedUntil = null;
    beginColdStartBannerSuppression();
    _cachedLoginUserId = null;
    _pendingConversationTimer?.cancel();
    _pendingConversationTimer = null;
    _pendingConversationOpen = null;
    _consumingPendingConversation = false;
    _consumePendingAgain = false;
    _homeRouteReady = false;
    _lastSystemNotificationAt.clear();
    _inflightMsgKeys.clear();
    ActiveChatRegistry.instance.reset();
  }

  Future<void> _enqueueExternalConversationOpen({
    required String source,
    String? ext,
    String? conversationID,
    String? groupID,
    String? userID,
    String? sender,
  }) async {
    final resolvedConversationID =
        ExternalChatEntryService.instance.resolveConversationId(
      conversationID: conversationID ??
          ExternalChatEntryService.instance.conversationIdFromExt(ext),
      groupID: groupID,
      userID: userID,
      sender: sender,
    );
    if (resolvedConversationID == null || resolvedConversationID.isEmpty) {
      ExternalChatEntryService.instance.logFlow(
        'resolve_conversation_failed',
        source: source,
        extras: <String, Object?>{
          'groupID': groupID,
          'userID': userID,
          'sender': sender,
          'hasExt': (ext?.trim().isNotEmpty ?? false),
        },
      );
      return;
    }
    _enqueuePendingConversationOpen(
      resolvedConversationID,
      source: source,
    );
  }

  void _enqueuePendingConversationOpen(
    String conversationID, {
    required String source,
  }) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    _pendingConversationOpen = _PendingConversationOpen(
      conversationID: id,
      source: source,
      createdAt: DateTime.now(),
    );
    ExternalChatEntryService.instance.logFlow(
      'enqueue_pending_open',
      source: source,
      conversationID: id,
    );
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'notification_click_pending',
      delay: const Duration(milliseconds: 300),
    );
    _schedulePendingConversationConsume(Duration.zero);
  }

  Future<void> consumePendingConversationOpen() async {
    if (_pendingConversationOpen == null) {
      return;
    }
    await _consumePendingConversationOpenNow();
  }

  void _schedulePendingConversationConsume(Duration delay) {
    _pendingConversationTimer?.cancel();
    _pendingConversationTimer = Timer(delay, () {
      unawaited(_consumePendingConversationOpenNow());
    });
  }

  Future<void> _consumePendingConversationOpenNow() async {
    final pending = _pendingConversationOpen;
    if (pending == null) {
      return;
    }
    if (_consumingPendingConversation) {
      _consumePendingAgain = true;
      return;
    }
    if (DateTime.now().difference(pending.createdAt) >
        _pendingConversationTtl) {
      ExternalChatEntryService.instance.logFlow(
        'drop_pending_open_ttl',
        source: pending.source,
        conversationID: pending.conversationID,
        extras: <String, Object?>{
          'attempts': pending.attempts,
        },
      );
      _pendingConversationOpen = null;
      return;
    }

    if (!_homeRouteReady) {
      ExternalChatEntryService.instance.logFlow(
        'wait_home_route_ready',
        source: pending.source,
        conversationID: pending.conversationID,
      );
      return;
    }

    if (AppNavigator.context == null) {
      _retryPendingConversationOpen(
        pending,
        reason: 'navigator_not_ready',
      );
      return;
    }

    _consumingPendingConversation = true;
    _consumePendingAgain = false;
    try {
      final loginUserId = await _currentLoginUserId();
      if (!identical(_pendingConversationOpen, pending)) {
        _consumePendingAgain = true;
        return;
      }
      if (loginUserId == null || loginUserId.isEmpty) {
        _retryPendingConversationOpen(
          pending,
          reason: 'im_not_logged_in',
        );
        return;
      }

      if (ExternalChatEntryService.instance
          .isVisibleChat(pending.conversationID)) {
        _pendingConversationOpen = null;
        ExternalChatEntryService.instance.logFlow(
          'reuse_current_chat',
          source: pending.source,
          conversationID: pending.conversationID,
          extras: <String, Object?>{
            'ready': ExternalChatEntryService.instance
                .isVisibleChatReady(pending.conversationID),
          },
        );
        ExternalChatEntryService.instance.requestActivation(
          conversationID: pending.conversationID,
          source: pending.source,
          reason: ExternalChatEntryService.instance
                  .isVisibleChatReady(pending.conversationID)
              ? 'pending_visible_ready'
              : 'pending_visible_needs_activation',
          delay: const Duration(milliseconds: 120),
        );
        return;
      }

      final convRes = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getConversation(conversationID: pending.conversationID)
          .timeout(const Duration(seconds: 2));
      if (!identical(_pendingConversationOpen, pending)) {
        _consumePendingAgain = true;
        return;
      }
      final conversation = convRes.data;
      if (conversation != null) {
        ExternalChatEntryService.instance.logFlow(
          'open_pending_conversation',
          source: pending.source,
          conversationID: pending.conversationID,
          extras: <String, Object?>{
            'attempt': pending.attempts + 1,
          },
        );
        final navigationAccepted = await _openConversationRoute(
          pending.conversationID,
          conversation,
          source: pending.source,
        );
        final becameVisible = navigationAccepted &&
            await _waitForConversationVisible(pending.conversationID);
        if (!identical(_pendingConversationOpen, pending)) {
          _consumePendingAgain = true;
          return;
        }
        if (becameVisible) {
          _pendingConversationOpen = null;
          ExternalChatEntryService.instance.logFlow(
            'pending_open_confirmed',
            source: pending.source,
            conversationID: pending.conversationID,
          );
          return;
        }
        _retryPendingConversationOpen(
          pending,
          reason:
              navigationAccepted ? 'chat_not_visible' : 'navigation_rejected',
        );
        return;
      }

      ConversationRefreshBus.instance.requestRefresh(
        reason: 'notification_click_retry',
        delay: const Duration(milliseconds: 250),
      );
      _retryPendingConversationOpen(
        pending,
        reason: 'conversation_not_found',
      );
    } catch (e) {
      if (identical(_pendingConversationOpen, pending)) {
        _retryPendingConversationOpen(
          pending,
          reason: e.toString(),
        );
      } else {
        _consumePendingAgain = true;
      }
    } finally {
      _consumingPendingConversation = false;
      if (_consumePendingAgain && _pendingConversationOpen != null) {
        _consumePendingAgain = false;
        _schedulePendingConversationConsume(Duration.zero);
      }
    }
  }

  Future<bool> _waitForConversationVisible(String conversationID) async {
    final deadline = DateTime.now().add(_pendingVisibilityTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (ExternalChatEntryService.instance.isVisibleChat(conversationID)) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return ExternalChatEntryService.instance.isVisibleChat(conversationID);
  }

  void _retryPendingConversationOpen(
    _PendingConversationOpen pending, {
    required String reason,
  }) {
    if (!identical(_pendingConversationOpen, pending)) {
      _consumePendingAgain = true;
      return;
    }
    pending.attempts += 1;
    ExternalChatEntryService.instance.logFlow(
      'retry_pending_conversation',
      source: pending.source,
      conversationID: pending.conversationID,
      extras: <String, Object?>{
        'attempt': pending.attempts,
        'reason': reason,
      },
    );
    final candidateDelayMs = 250 + (pending.attempts - 1) * 350;
    final delayMs = candidateDelayMs > 5000 ? 5000 : candidateDelayMs;
    _schedulePendingConversationConsume(Duration(milliseconds: delayMs));
  }

  bool _isInForeground() {
    return _currentLifecycleState() == AppLifecycleState.resumed;
  }

  AppLifecycleState _currentLifecycleState() {
    return WidgetsBinding.instance.lifecycleState ?? _lifecycle;
  }

  bool _isInActiveCall() {
    return CallLifecycleService.instance.isInActiveCall;
  }

  bool _isCurrentConversationId(String? conversationId) {
    if (conversationId == null || conversationId.isEmpty) {
      return false;
    }
    return ActiveChatRegistry.instance.isActiveChatInForeground(conversationId);
  }

  String? _conversationIdFromMessage(V2TimMessage message) {
    return MessageConversationId.fromMessage(message);
  }

  Future<void> _waitForMessageUiCatchUp({
    String? conversationId,
    bool refreshConversationPreview = false,
  }) async {
    await Future<void>.delayed(Duration.zero);

    if (refreshConversationPreview) {
      final id = conversationId?.trim() ?? '';
      if (id.isNotEmpty) {
        try {
          await ConversationSyncService.instance.refreshConversationItem(id);
        } catch (_) {}
      }
    }

    for (var frame = 0; frame < 2; frame++) {
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      await completer.future;
    }
  }

  bool _isFriendRelationshipChangeMessage(V2TimMessage message) {
    return isFriendRelationshipCustomMessage(message);
  }

  bool _isCallSignalMessage(V2TimMessage message) {
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
      return false;
    }
    final data = message.customElem?.data ?? '';
    if (data.isEmpty) {
      return false;
    }
    if (data.contains('av_call') ||
        data.contains('rtc_call') ||
        data.contains('lk_call')) {
      return true;
    }
    return _jsonContainsCallBusiness(_decodeJsonLoose(data));
  }

  dynamic _decodeJsonLoose(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  bool _jsonContainsCallBusiness(dynamic decoded) {
    if (decoded is! Map) {
      return false;
    }
    final businessId = decoded['businessID']?.toString();
    if (businessId == 'av_call' ||
        businessId == 'rtc_call' ||
        businessId == 'lk_call') {
      return true;
    }
    final inner = decoded['data'];
    if (inner == null) {
      return false;
    }
    if (inner is String) {
      if (inner.contains('av_call') ||
          inner.contains('rtc_call') ||
          inner.contains('lk_call')) {
        return true;
      }
      return _jsonContainsCallBusiness(_decodeJsonLoose(inner));
    }
    return _jsonContainsCallBusiness(inner);
  }

  Future<void> _handleAndroidJPushNotificationTap(
    AndroidPushTapResult result,
  ) async {
    await handleSelfHostedPushTap(<String, dynamic>{
      ...result.data,
      '_source': result.source,
    });
  }

  Future<void> _handleLocalSystemNotificationTap(
    Map<String, dynamic> payload,
  ) async {
    await handleSelfHostedPushTap(<String, dynamic>{
      ...payload,
      '_source': 'local_system_notification',
    });
  }

  /// 是否允许展示/处理音视频来电（含 VoIP 离线推送与 IM lk_call）。
  bool get allowsCallNotify {
    final settings = _localSetting;
    if (settings == null) {
      return true;
    }
    return PushHandler.allowsCallNotify(settings);
  }

  bool get allowsCallRingtone {
    final settings = _localSetting;
    if (settings == null) {
      return true;
    }
    return settings.notifyVoiceVideoCall && settings.notifyCallRingtone;
  }

  Future<void> syncCallNotificationPreferenceToNative() async {
    if (kIsWeb || !PlatformUtils().isIOS) {
      return;
    }
    await IosApnsPushService.instance.syncCallNotificationEnabled(
      allowsCallNotify,
    );
  }

  Future<bool> resolveAllowsCallNotify() => _resolveAllowsCallNotify();

  /// Early bootstrap hook from [main] before [LocalSetting] is loaded.
  Future<void> handleVoipPushPayloadForBootstrap(
    Map<String, dynamic> data,
  ) {
    return _handleVoipPushPayload(data);
  }

  Future<bool> _resolveAllowsCallNotify() async {
    final settings = _localSetting;
    if (settings != null) {
      return PushHandler.allowsCallNotify(settings);
    }
    if (!kIsWeb && PlatformUtils().isIOS) {
      return IosApnsPushService.instance.readCallNotificationEnabled();
    }
    return true;
  }

  Future<void> _handleVoipPushPayload(Map<String, dynamic> data) async {
    await CallLifecycleService.instance.ensureObserversAttached();
    if (!await _resolveAllowsCallNotify()) {
      final inviteId = VoipPushPayload.readInviteId(data);
      await IosApnsPushService.instance.endVoipCallKit(inviteId: inviteId);
      if (kDebugMode) {
        debugPrint(
          'NotificationSettings: system call notify off — '
          'still present in-app fullscreen',
        );
      }
    }
    await IncomingCallCoordinator.instance.handleVoipPush(data);
  }
}

class _PendingConversationOpen {
  _PendingConversationOpen({
    required this.conversationID,
    required this.source,
    required this.createdAt,
  });

  final String conversationID;
  final String source;
  final DateTime createdAt;
  int attempts = 0;
}
