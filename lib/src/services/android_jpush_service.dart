import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:jpush_flutter/jpush_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/push_token_api.dart';
import 'package:tencent_cloud_chat_demo/src/platform/push_handler.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_chat_notification_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_msgkey_dedup.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_token_local/push_token_upload_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_payload_normalizer.dart';
import 'package:tencent_cloud_chat_demo/src/services/local_system_notification_service.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

final class AndroidPushTapResult {
  const AndroidPushTapResult({
    required this.data,
    required this.source,
  });

  final Map<String, dynamic> data;
  final String source;
}

typedef AndroidPushTapHandler = FutureOr<void> Function(
  AndroidPushTapResult result,
);

class _NativeJPushConfig {
  const _NativeJPushConfig({
    this.packageName = '',
    this.appKey = '',
    this.channel = '',
  });

  final String packageName;
  final String appKey;
  final String channel;
}

class AndroidJPushService {
  AndroidJPushService._();

  static final AndroidJPushService instance = AndroidJPushService._();
  static const String _tracePrefix = 'JPUSH_TRACE';

  static const String _lastSubmittedKey = 'android_jpush_last_submit_key';
  static const String _lastSubmittedAtKey = 'android_jpush_last_submit_at';
  static const Duration _submitRefreshInterval = Duration(hours: 6);
  static const String _cachedRegistrationIdKey =
      'android_jpush_cached_registration_id';
  static const MethodChannel _nativeConfigChannel =
      MethodChannel('android_jpush_config');

  final JPushFlutterInterface _jpush = JPush.newJPush();

  bool _installed = false;
  bool _setupDone = false;
  bool _policyDisabled = false;
  Future<void>? _syncTask;
  AndroidPushTapHandler? _onNotificationTap;
  bool Function()? _isInForegroundResolver;

  void setInForegroundResolver(bool Function() resolver) {
    _isInForegroundResolver = resolver;
  }

  bool get _isInForeground => _isInForegroundResolver?.call() ?? false;

  Future<void> install({AndroidPushTapHandler? onNotificationTap}) async {
    if (!Platform.isAndroid) {
      return;
    }
    if (onNotificationTap != null) {
      _onNotificationTap = onNotificationTap;
    }
    if (_installed) {
      return;
    }
    _installed = true;

    _jpush.addEventHandler(
      onOpenNotification: (event) async {
        await _dispatchTap(event, source: 'jpush_open_notification');
      },
      onReceiveNotification: (event) async {
        if (kDebugMode) {
          debugPrint('AndroidJPush: receive notification ${_safeEvent(event)}');
        }
        await _handleIncomingPushNotification(event);
      },
      onReceiveMessage: (event) async {
        if (kDebugMode) {
          debugPrint(
              'AndroidJPush: receive custom message ${_safeEvent(event)}');
        }
      },
      onConnected: (event) async {
        if (kDebugMode) {
          debugPrint('AndroidJPush: connected ${_safeEvent(event)}');
        }
        unawaited(syncRegistrationId(reason: 'connected'));
      },
      onCommandResult: (event) async {
        if (kDebugMode) {
          debugPrint('AndroidJPush: command ${_safeEvent(event)}');
        }
      },
    );

    await _setupOnce();
  }

  Future<void> applyFromSettings(
    LocalSetting settings, {
    AndroidPushTapHandler? onNotificationTap,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    _trace(
      'apply settings '
      'message=${settings.notifySystemMessage} '
      'call=${settings.notifyVoiceVideoCall}',
    );
    if (onNotificationTap != null) {
      _onNotificationTap = onNotificationTap;
    }
    await install(onNotificationTap: onNotificationTap);

    if (!PushHandler.needsTimPush(settings)) {
      _trace('skip registration: notification settings disabled');
      await disableForUserSetting();
      return;
    }

    if (!_setupDone) {
      _trace('skip registration: JPush setup not ready');
      return;
    }

    try {
      _jpush.requestRequiredPermission();
      _jpush.setBackgroundEnable(enable: true);
      _jpush.resumePush();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AndroidJPush: resume failed ($e)');
      }
    }
    await syncRegistrationId(reason: 'apply_settings');
  }

  Future<void> syncRegistrationId({String reason = 'manual'}) {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }
    if (!_setupDone) {
      _trace('skip token sync: setup not ready reason=$reason');
      return Future<void>.value();
    }
    final running = _syncTask;
    if (running != null) {
      _trace('reuse running token sync reason=$reason');
      return running;
    }

    _trace('start token sync reason=$reason');
    final task = _syncRegistrationIdWithRetry(reason: reason);
    _syncTask = task;
    unawaited(task.whenComplete(() {
      if (identical(_syncTask, task)) {
        _syncTask = null;
      }
    }));
    return task;
  }

  Future<void> disableForUserSetting() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _deleteServerTokenIfPossible(reason: 'notification_setting_off');
    try {
      await _jpush.stopPush();
    } catch (_) {}
  }

  Future<void> disableForAppPolicy() async {
    if (!Platform.isAndroid || _policyDisabled) {
      return;
    }
    _policyDisabled = true;
    _trace('disabled by app policy');
    await _deleteServerTokenIfPossible(reason: 'app_policy_disabled');
    try {
      await _jpush.stopPush();
    } catch (e) {
      _trace('stopPush for app policy failed error=$e');
    }
  }

  Future<void> unregisterForLogout() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _deleteServerTokenIfPossible(reason: 'logout');
    await clearLocalStateOnLogout();
  }

  Future<void> clearImChatNotifications({String? threadId}) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      const channel = MethodChannel('app_system_notification');
      await channel.invokeMethod<int>(
        'clearImChatNotifications',
        <String, dynamic>{
          if (threadId != null && threadId.trim().isNotEmpty)
            'threadId': threadId.trim(),
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AndroidJPush: clearImChatNotifications failed ($e)');
      }
    }
  }

  Future<void> cancelNotificationForMsgKey(String msgKey) async {
    if (!Platform.isAndroid) {
      return;
    }
    final key = msgKey.trim();
    if (key.isEmpty) {
      return;
    }
    try {
      const channel = MethodChannel('app_system_notification');
      await channel.invokeMethod<int>(
        'cancelNotificationByMsgKey',
        <String, dynamic>{'msgKey': key},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AndroidJPush: cancelNotificationForMsgKey failed ($e)');
      }
    }
  }

  Future<void> clearLocalStateOnLogout() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _jpush.deleteAlias();
    } catch (_) {}
    try {
      await _jpush.stopPush();
    } catch (_) {}
    try {
      await _jpush.clearAllNotifications();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSubmittedKey);
    await prefs.remove(_lastSubmittedAtKey);
  }

  Future<_NativeJPushConfig> _readNativeConfig() async {
    try {
      final raw = await _nativeConfigChannel.invokeMethod<dynamic>('getConfig');
      if (raw is Map) {
        final map = <String, dynamic>{};
        raw.forEach((key, value) => map[key.toString()] = value);
        return _NativeJPushConfig(
          packageName: map['packageName']?.toString() ?? '',
          appKey: map['appKey']?.toString() ?? '',
          channel: map['channel']?.toString() ?? '',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AndroidJPush: read native config failed ($e)');
      }
    }
    return const _NativeJPushConfig();
  }

  Future<void> _setupOnce() async {
    if (_setupDone) {
      return;
    }
    final nativeConfig = await _readNativeConfig();
    final dartAppKey = IMDemoConfig.jpushAppKey.trim();
    final manifestAppKey = nativeConfig.appKey.trim();
    final appKey = manifestAppKey.isNotEmpty ? manifestAppKey : dartAppKey;
    final channel = nativeConfig.channel.trim().isNotEmpty
        ? nativeConfig.channel.trim()
        : IMDemoConfig.jpushChannel;
    _trace(
      'setup config '
      'package=${nativeConfig.packageName} '
      'manifestAppKey=${manifestAppKey.isNotEmpty} '
      'dartAppKey=${dartAppKey.isNotEmpty} '
      'channel=$channel',
    );

    if (manifestAppKey.isEmpty) {
      _trace('setup aborted: AndroidManifest JPUSH_APPKEY is empty');
      if (kDebugMode) {
        debugPrint(
          'AndroidJPush: AndroidManifest JPUSH_APPKEY is empty; skip setup. '
          'Set JPUSH_APPKEY in android/local.properties. '
          'Flutter --dart-define alone is not enough for native JPush metadata.',
        );
      }
      return;
    }
    if (dartAppKey.isNotEmpty && dartAppKey != manifestAppKey && kDebugMode) {
      debugPrint(
        'AndroidJPush: dart JPUSH_APPKEY and manifest JPUSH_APPKEY are different; '
        'use manifest JPUSH_APPKEY to avoid package/AppKey mismatch. '
        'package=${nativeConfig.packageName}',
      );
    }

    try {
      // 合规默认：不采集定位 / Wi-Fi / IMEI 等额外信息，不开营销分析。
      _jpush.setCollectControl(
        imsi: false,
        mac: false,
        wifi: false,
        bssid: false,
        ssid: false,
        imei: false,
        cell: false,
        gps: false,
      );
      _jpush.setAuth(enable: true);
      _jpush.setDataInsightsEnable(enable: false);
      _jpush.setGeofenceEnable(enable: false);
      _jpush.setSmartPushEnable(enable: false);
      _jpush.setLinkMergeEnable(enable: true);
      _jpush.enableAutoWakeup(
          enable: IMDemoConfig.androidJPushAutoWakeupEnabled);
      _jpush.setWakeEnable(enable: IMDemoConfig.androidJPushWakeEnabled);
      _jpush.setBackgroundEnable(enable: true);
      _jpush.setUnShowAtTheForeground(unShow: true);
      await _jpush.setLatestNotificationNumber(6);
      _jpush.setup(
        appKey: appKey,
        channel: channel,
        production: kReleaseMode,
        debug: kDebugMode,
      );
      _jpush.resumePush();
      _setupDone = true;
      _trace('setup completed');
      unawaited(syncRegistrationId(reason: 'setup'));
    } catch (e) {
      _trace('setup failed error=$e');
      if (kDebugMode) {
        debugPrint('AndroidJPush: setup failed ($e)');
      }
    }
  }

  Future<void> _syncRegistrationIdWithRetry({required String reason}) async {
    await ApiClient.instance.ensureDeviceIdReady();
    final token = ApiClient.instance.token;
    if (!ApiClient.isValidJwt(token)) {
      _trace('skip token sync: invalid JWT reason=$reason');
      return;
    }
    _trace(
      'token sync ready '
      'reason=$reason device=${_masked(ApiClient.instance.deviceId)}',
    );

    const delays = <Duration>[
      Duration(milliseconds: 0),
      Duration(milliseconds: 800),
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 20),
      Duration(seconds: 40),
    ];

    for (var attempt = 0; attempt < delays.length; attempt += 1) {
      final delay = delays[attempt];
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      final registrationId = await _readRegistrationId();
      if (registrationId.isEmpty) {
        _trace(
          'registrationId empty '
          'reason=$reason attempt=${attempt + 1}/${delays.length}',
        );
        continue;
      }
      _trace(
        'registrationId ready '
        'reason=$reason attempt=${attempt + 1}/${delays.length} '
        'registrationId=${_masked(registrationId)}',
      );
      await _submitRegistrationId(
        registrationId,
        authToken: token!,
        reason: reason,
      );
      return;
    }

    _trace('registrationId still empty after retry reason=$reason');
  }

  Future<String> _readRegistrationId() async {
    try {
      final id = (await _jpush.getRegistrationID().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          _trace('getRegistrationID timeout');
          return '';
        },
      ))
          .trim();
      if (id.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cachedRegistrationIdKey, id);
      }
      return id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AndroidJPush: getRegistrationID failed ($e)');
      }
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cachedRegistrationIdKey)?.trim() ?? '';
    }
  }

  Future<void> _submitRegistrationId(
    String registrationId, {
    required String authToken,
    required String reason,
  }) async {
    final deviceId = ApiClient.instance.deviceId.trim();
    final tokenKeyHash = _buildTokenKeyHash(deviceId, registrationId);
    final uploadedInDb = await PushTokenUploadLocalStore.instance.hasSuccess(
      deviceId: deviceId,
      platform: 'ANDROID',
      tokenKeyHash: tokenKeyHash,
    );
    if (uploadedInDb) {
      _trace(
        'local db has previous upload record; refresh server token anyway '
        'reason=$reason registrationId=${_masked(registrationId)}',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final submitKey = _buildSubmitKey(registrationId, authToken);
    final lastKey = prefs.getString(_lastSubmittedKey);
    final lastAtMs = prefs.getInt(_lastSubmittedAtKey) ?? 0;
    final lastAt = DateTime.fromMillisecondsSinceEpoch(lastAtMs);
    if (lastKey == submitKey &&
        DateTime.now().difference(lastAt) < _submitRefreshInterval) {
      _trace(
        'recent submit record exists; refresh server token anyway '
        'reason=$reason registrationId=${_masked(registrationId)}',
      );
    }

    try {
      _trace(
        'POST /me/push-token start '
        'reason=$reason device=${_masked(deviceId)} '
        'registrationId=${_masked(registrationId)}',
      );
      final result = await PushTokenApi.instance.registerAndroidToken(
        token: registrationId,
      );
      _trace(
        'POST /me/push-token response '
        'reason=$reason ok=${result.ok} '
        'platform=${result.platform} provider=${result.provider}',
      );
      if (!result.ok && result.provider.toUpperCase() != 'JPUSH') {
        if (kDebugMode) {
          debugPrint(
            'AndroidJPush: server returned unexpected result '
            'ok=${result.ok} provider=${result.provider}',
          );
        }
      }
      if (result.ok) {
        await PushTokenUploadLocalStore.instance.markSuccess(
          deviceId: deviceId,
          platform: 'ANDROID',
          tokenKeyHash: tokenKeyHash,
        );
        await prefs.setString(_lastSubmittedKey, submitKey);
        await prefs.setInt(
          _lastSubmittedAtKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      await _bindAliasIfPossible();
      if (kDebugMode) {
        debugPrint(
          'AndroidJPush: registrationId uploaded reason=$reason '
          'provider=${result.provider}',
        );
      }
    } catch (e) {
      _trace('POST /me/push-token failed reason=$reason error=$e');
      if (kDebugMode) {
        debugPrint('AndroidJPush: upload registrationId failed ($e)');
      }
    }
  }

  static const bool _traceEnabled = false;

  void _trace(String message) {
    if (!_traceEnabled) return;
    print('$_tracePrefix $message');
  }

  String _masked(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return '<empty>';
    }
    if (text.length <= 8) {
      return '<len:${text.length}>';
    }
    return '${text.substring(0, 4)}...${text.substring(text.length - 4)}';
  }

  String _buildSubmitKey(String registrationId, String authToken) {
    final raw = '${ApiClient.instance.deviceId}|$registrationId|$authToken';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  String _buildTokenKeyHash(String deviceId, String registrationId) {
    final raw = '$deviceId|${registrationId.trim()}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<void> _bindAliasIfPossible() async {
    try {
      final user = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
      final userId = user.data?.trim() ?? '';
      if (userId.isNotEmpty) {
        await _jpush.setAlias(userId);
      }
    } catch (_) {}
  }

  Future<void> _deleteServerTokenIfPossible({required String reason}) async {
    final token = ApiClient.instance.token;
    if (!ApiClient.isValidJwt(token)) {
      return;
    }
    try {
      await PushTokenApi.instance.deleteCurrentDeviceToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastSubmittedKey);
      await prefs.remove(_lastSubmittedAtKey);
      if (kDebugMode) {
        debugPrint('AndroidJPush: server token deleted reason=$reason');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AndroidJPush: delete server token failed ($e)');
      }
    }
  }

  Future<void> _handleIncomingPushNotification(dynamic event) async {
    final data = AndroidPushPayloadNormalizer.normalize(event);
    if (data.isEmpty) {
      return;
    }
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    if (type == 'im_chat' || type == 'chat_message') {
      await _handleIncomingImChatPush(data);
      return;
    }
    if (type == 'friend_list') {
      await FriendRequestNoticeService.instance.handlePushFriendList(data);
      return;
    }
    if (type == 'group_changed') {
      await FriendRequestNoticeService.instance.handlePushGroupChanged(data);
      return;
    }
    if (type != 'friend_request') {
      return;
    }
    final fromUserId = data['fromUserId']?.toString() ??
        data['from_user_id']?.toString() ??
        data['userID']?.toString() ??
        data['userId']?.toString();
    final requestId = int.tryParse(
      data['requestId']?.toString() ?? data['request_id']?.toString() ?? '',
    );
    await FriendRequestNoticeService.instance.handlePushFriendRequest(
      fromUserId: fromUserId,
      displayName: data['nickname']?.toString() ?? data['title']?.toString(),
      requestId: requestId,
    );
  }

  Future<void> _handleIncomingImChatPush(Map<String, dynamic> data) async {
    await PushMsgKeyDedup.instance.ensureReady();
    final msgKey = PushMsgKeyDedup.instance.normalizeKey(data['msgKey']);
    final threadId = _threadIdFromPushData(data);

    // 前台横幅已改走本地系统通知；极光前台清条会把刚弹出的本地横幅掐掉。
    if (_isInForeground) {
      PushMsgKeyDedup.instance
          .trace('foreground_skip_clear', msgKey ?? '', 'jpush');
      return;
    }

    if (msgKey != null && PushMsgKeyDedup.instance.wasHandled(msgKey)) {
      PushMsgKeyDedup.instance.trace('clear_push', msgKey, 'jpush');
      await _clearImChatForMsgKey(msgKey, threadId);
      return;
    }

    if (msgKey != null && !PushMsgKeyDedup.instance.tryClaim(msgKey)) {
      PushMsgKeyDedup.instance.trace('claim_failed', msgKey, 'jpush');
      await _clearImChatForMsgKey(msgKey, threadId);
      return;
    }
    if (msgKey != null) {
      await PushMsgKeyDedup.instance.persist();
    }
  }

  Future<void> _clearImChatForMsgKey(String msgKey, String? threadId) async {
    await cancelNotificationForMsgKey(msgKey);
    await LocalSystemNotificationService.instance.cancelNotification(
      ImChatNotificationRegistry.notificationIdFor(msgKey),
    );
    await clearImChatNotifications(
      threadId: threadId?.isNotEmpty == true ? threadId : null,
    );
  }

  String? _threadIdFromPushData(Map<String, dynamic> data) {
    final direct = data['threadId']?.toString().trim() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }
    final chatType = data['chatType']?.toString().trim().toLowerCase() ?? '';
    final groupId = data['groupId']?.toString().trim() ??
        data['groupID']?.toString().trim() ??
        '';
    if (chatType == 'group' && groupId.isNotEmpty) {
      return ImChatNotificationRegistry.threadIdFor(
        chatType: 'group',
        peerOrGroupId: groupId,
      );
    }
    final sender = data['fromAccount']?.toString().trim() ??
        data['sender']?.toString().trim() ??
        '';
    if (sender.isNotEmpty) {
      return ImChatNotificationRegistry.threadIdFor(
        chatType: 'c2c',
        peerOrGroupId: sender,
      );
    }
    return null;
  }

  Future<void> _dispatchTap(dynamic event, {required String source}) async {
    final data = AndroidPushPayloadNormalizer.normalize(event);
    if (data.isEmpty) {
      return;
    }
    final handler = _onNotificationTap;
    if (handler != null) {
      await handler(AndroidPushTapResult(data: data, source: source));
    }
  }

  String _safeEvent(dynamic event) {
    try {
      return jsonEncode(event);
    } catch (_) {
      return event.toString();
    }
  }
}

class AndroidPushPayloadNormalizer {
  AndroidPushPayloadNormalizer._();

  static Map<String, dynamic> normalize(dynamic raw) =>
      PushPayloadNormalizer.normalize(raw);

  static String? resolveConversationId(Map<String, dynamic> data) =>
      PushPayloadNormalizer.resolveConversationId(data);
}
