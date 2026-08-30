import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/push_token_api.dart';
import 'package:tencent_cloud_chat_demo/src/platform/push_handler.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_msgkey_dedup.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_token_local/push_token_upload_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/voip_push_payload.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

typedef IosPushTapHandler = FutureOr<void> Function(Map<String, dynamic> data);
typedef IosRemoteNotificationHandler = FutureOr<void> Function(
  Map<String, dynamic> data,
);

class IosApnsPushService {
  IosApnsPushService._();

  static final IosApnsPushService instance = IosApnsPushService._();
  static const MethodChannel _channel = MethodChannel('ios_apns_push');
  static const String _tracePrefix = 'IOS_PUSH_TRACE';

  static const String _lastSubmittedKey = 'ios_apns_last_submit_key';
  static const String _lastSubmittedAtKey = 'ios_apns_last_submit_at';
  static const Duration _submitRefreshInterval = Duration(hours: 6);

  bool _installed = false;
  Future<void>? _syncTask;
  IosPushTapHandler? _onNotificationTap;
  IosPushTapHandler? _onVoipPush;
  IosRemoteNotificationHandler? _onRemoteNotificationReceived;

  String? _cachedApnsToken;
  String? _cachedVoipToken;

  Future<void> install({
    IosPushTapHandler? onNotificationTap,
    IosPushTapHandler? onVoipPush,
    IosRemoteNotificationHandler? onRemoteNotificationReceived,
  }) async {
    if (!Platform.isIOS) {
      return;
    }
    if (onNotificationTap != null) {
      _onNotificationTap = onNotificationTap;
    }
    if (onVoipPush != null) {
      _onVoipPush = onVoipPush;
    }
    if (onRemoteNotificationReceived != null) {
      _onRemoteNotificationReceived = onRemoteNotificationReceived;
    }
    if (_installed) {
      if (onNotificationTap != null) {
        await _markNotificationTapHandlerReady();
      }
      return;
    }
    _installed = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onApnsToken':
          _cachedApnsToken = _readToken(call.arguments);
          unawaited(syncTokens(reason: 'apns_token'));
          return;
        case 'onVoipToken':
          _cachedVoipToken = _readToken(call.arguments);
          unawaited(syncTokens(reason: 'voip_token'));
          return;
        case 'onNotificationTap':
          await _dispatchTap(
            call.arguments,
            source: 'ios_apns_notification_tap',
            handler: _onNotificationTap,
          );
          return;
        case 'onRemoteNotificationReceived':
          await _handleRemoteNotificationReceived(call.arguments);
          return;
        case 'onVoipPush':
          await _handleVoipPush(call.arguments);
          return;
        default:
          return;
      }
    });

    try {
      await _channel.invokeMethod<void>('install');
      if (onNotificationTap != null) {
        await _markNotificationTapHandlerReady();
      }
      await _consumePendingVoipPush();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IosApnsPush: install failed ($e)');
      }
    }
  }

  Future<void> _markNotificationTapHandlerReady() async {
    try {
      await _channel.invokeMethod<void>('setNotificationTapHandlerReady');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IosApnsPush: tap handler ready failed ($e)');
      }
    }
  }

  Future<void> applyFromSettings(
    LocalSetting settings, {
    IosPushTapHandler? onNotificationTap,
    IosPushTapHandler? onVoipPush,
    IosRemoteNotificationHandler? onRemoteNotificationReceived,
  }) async {
    if (!Platform.isIOS) {
      return;
    }
    if (onNotificationTap != null) {
      _onNotificationTap = onNotificationTap;
    }
    if (onVoipPush != null) {
      _onVoipPush = onVoipPush;
    }
    if (onRemoteNotificationReceived != null) {
      _onRemoteNotificationReceived = onRemoteNotificationReceived;
    }
    await install(
      onNotificationTap: onNotificationTap,
      onVoipPush: onVoipPush,
      onRemoteNotificationReceived: onRemoteNotificationReceived,
    );

    if (!PushHandler.needsTimPush(settings)) {
      _trace('skip registration: notification settings disabled');
      return;
    }

    try {
      await _channel.invokeMethod<void>('registerForRemoteNotifications');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IosApnsPush: register failed ($e)');
      }
    }
    await syncTokens(reason: 'apply_settings');
    await _consumePendingTap();
  }

  Future<void> syncTokens({String reason = 'manual'}) {
    if (!Platform.isIOS) {
      return Future<void>.value();
    }
    final running = _syncTask;
    if (running != null) {
      return running;
    }
    final task = _syncTokensOnce(reason: reason);
    _syncTask = task.whenComplete(() {
      if (identical(_syncTask, task)) {
        _syncTask = null;
      }
    });
    return _syncTask!;
  }

  Future<void> unregisterForLogout() async {
    if (!Platform.isIOS) {
      return;
    }
    await _deleteServerTokenIfPossible(reason: 'logout');
    await clearLocalStateOnLogout();
  }

  Future<void> clearLocalStateOnLogout() async {
    if (!Platform.isIOS) {
      return;
    }
    _cachedApnsToken = null;
    _cachedVoipToken = null;
    await syncLoginUserId(null);
    await endVoipCallKit();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSubmittedKey);
    await prefs.remove(_lastSubmittedAtKey);
    try {
      await _channel.invokeMethod<void>('clearHandledMsgKeys');
    } catch (_) {}
  }

  Future<void> cancelNotificationForMsgKey(String? msgKey) async {
    final key = PushMsgKeyDedup.instance.normalizeKey(msgKey);
    if (!Platform.isIOS || key == null) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('cancelNotificationForMsgKey', {
        'msgKey': key,
      });
    } catch (_) {}
  }

  Future<void> syncHandledMsgKey(String msgKey) async {
    final key = msgKey.trim();
    if (!Platform.isIOS || key.isEmpty) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('syncHandledMsgKey', {
        'msgKey': key,
      });
    } catch (_) {}
  }

  Future<int> clearAllImChatNotifications() async {
    if (!Platform.isIOS) {
      return 0;
    }
    try {
      final count = await _channel.invokeMethod<int>(
        'clearAllImChatNotifications',
      );
      return count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> clearDeliveredImChatNotifications({String? threadId}) async {
    if (!Platform.isIOS) {
      return 0;
    }
    try {
      final count = await _channel.invokeMethod<int>(
        'clearDeliveredImChatNotifications',
        <String, dynamic>{
          if (threadId != null && threadId.trim().isNotEmpty)
            'threadId': threadId.trim(),
        },
      );
      return count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 同步 C2C 展示名到 iOS 原生，供 VoIP 离线 CallKit 读取。
  Future<void> syncDisplayNameCache(Map<String, String> names) async {
    if (!Platform.isIOS || names.isEmpty) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('cacheDisplayNames', names);
    } catch (_) {}
  }

  Future<bool> readCallNotificationEnabled() async {
    if (!Platform.isIOS) {
      return true;
    }
    try {
      final enabled = await _channel.invokeMethod<bool>(
        'getCallNotificationEnabled',
      );
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> syncCallNotificationEnabled(bool enabled) async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(
        'cacheCallNotificationEnabled',
        <String, dynamic>{'enabled': enabled},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IosApnsPush: sync call notify failed ($e)');
      }
    }
  }

  Future<void> syncLoginUserId(String? userId) async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('cacheLoginUserId', <String, dynamic>{
        'userId': userId?.trim() ?? '',
      });
    } catch (_) {}
  }

  /// Native CallKit `didActivate` latch — survives a dropped MethodChannel event.
  Future<bool> isVoipAudioSessionActivated() async {
    if (!Platform.isIOS) {
      return false;
    }
    try {
      final v =
          await _channel.invokeMethod<bool>('isVoipAudioSessionActivated');
      return v == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> endVoipCallKit({
    String? inviteId,
    bool keepAudioSession = false,
  }) async {
    if (!Platform.isIOS) {
      return;
    }
    final id = inviteId?.trim() ?? '';
    try {
      await _channel.invokeMethod<void>(
        'endVoipCallKit',
        <String, dynamic>{
          if (id.isNotEmpty) 'inviteId': id,
          'keepAudioSession': keepAudioSession,
        },
      );
    } catch (_) {}
  }

  /// Mark CallKit incoming call as connected (Dynamic Island / status bar).
  Future<void> connectVoipCallKit({String? inviteId}) async {
    if (!Platform.isIOS) {
      return;
    }
    final id = inviteId?.trim() ?? '';
    try {
      await _channel.invokeMethod<void>(
        'connectVoipCallKit',
        id.isEmpty ? null : <String, dynamic>{'inviteId': id},
      );
    } catch (_) {}
  }

  Future<void> completeVoipCallKitAction({
    required String uuid,
    required bool succeeded,
  }) async {
    if (!Platform.isIOS || uuid.trim().isEmpty) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(
        'completeVoipCallKitAction',
        <String, dynamic>{
          'uuid': uuid.trim(),
          'succeeded': succeeded,
        },
      );
    } catch (_) {}
  }

  Future<void> syncHandledVoipInviteId(String? inviteId) async {
    final id = inviteId?.trim() ?? '';
    if (!Platform.isIOS || id.isEmpty) {
      return;
    }
    try {
      await _channel
          .invokeMethod<void>('syncHandledVoipInviteId', <String, dynamic>{
        'inviteId': id,
      });
    } catch (_) {}
  }

  Future<void> _syncTokensOnce({required String reason}) async {
    await ApiClient.instance.ensureDeviceIdReady();
    final authToken = ApiClient.instance.token;
    if (!ApiClient.isValidJwt(authToken)) {
      _trace('skip token sync: invalid JWT reason=$reason');
      return;
    }

    var apnsToken = _cachedApnsToken?.trim() ?? '';
    var voipToken = _cachedVoipToken?.trim() ?? '';
    var bundleId = '';
    var apsEnvironment = '';
    if (apnsToken.isEmpty || voipToken.isEmpty || bundleId.isEmpty) {
      try {
        final native = await _channel.invokeMapMethod<String, dynamic>(
          'getCachedTokens',
        );
        apnsToken = apnsToken.isNotEmpty
            ? apnsToken
            : (native?['apnsToken']?.toString().trim() ?? '');
        voipToken = voipToken.isNotEmpty
            ? voipToken
            : (native?['voipToken']?.toString().trim() ?? '');
        bundleId = native?['bundleId']?.toString().trim() ?? '';
        apsEnvironment = native?['apsEnvironment']?.toString().trim() ?? '';
        if (apnsToken.isNotEmpty) {
          _cachedApnsToken = apnsToken;
        }
        if (voipToken.isNotEmpty) {
          _cachedVoipToken = voipToken;
        }
      } catch (_) {}
    }

    if (apnsToken.isEmpty) {
      _trace('skip token sync: apns token empty reason=$reason');
      return;
    }

    final deviceId = ApiClient.instance.deviceId.trim();
    final tokenKeyHash = _buildTokenKeyHash(
      deviceId: deviceId,
      apnsToken: apnsToken,
      voipToken: voipToken,
      bundleId: bundleId,
      apsEnvironment: apsEnvironment,
    );
    final uploadedInDb = await PushTokenUploadLocalStore.instance.hasSuccess(
      deviceId: deviceId,
      platform: 'IOS',
      tokenKeyHash: tokenKeyHash,
    );
    if (uploadedInDb) {
      _trace(
        'skip POST /me/push-token: already recorded in local db '
        'reason=$reason hasVoip=${voipToken.isNotEmpty} '
        'bundleId=$bundleId aps=$apsEnvironment',
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final submitKey = _buildSubmitKey(
      apnsToken,
      voipToken,
      authToken!,
      bundleId: bundleId,
      apsEnvironment: apsEnvironment,
    );
    final lastKey = prefs.getString(_lastSubmittedKey);
    final lastAtMs = prefs.getInt(_lastSubmittedAtKey) ?? 0;
    final lastAt = DateTime.fromMillisecondsSinceEpoch(lastAtMs);
    if (lastKey == submitKey &&
        DateTime.now().difference(lastAt) < _submitRefreshInterval) {
      _trace('skip POST /me/push-token: already submitted within 6h');
      return;
    }

    try {
      _trace(
        'POST /me/push-token start reason=$reason '
        'hasVoip=${voipToken.isNotEmpty} bundleId=$bundleId aps=$apsEnvironment',
      );
      final result = await PushTokenApi.instance.registerIosToken(
        token: apnsToken,
        voipToken: voipToken.isNotEmpty ? voipToken : null,
        bundleId: bundleId.isNotEmpty ? bundleId : null,
        apsEnvironment: apsEnvironment.isNotEmpty ? apsEnvironment : null,
      );
      _trace(
        'POST /me/push-token response ok=${result.ok} '
        'provider=${result.provider} hasVoipToken=${result.hasVoipToken}',
      );
      await prefs.setString(_lastSubmittedKey, submitKey);
      await prefs.setInt(
        _lastSubmittedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      if (voipToken.isNotEmpty && !result.hasVoipToken) {
        await PushTokenApi.instance.registerVoipToken(
          token: voipToken,
          bundleId: bundleId.isNotEmpty ? bundleId : null,
          apsEnvironment: apsEnvironment.isNotEmpty ? apsEnvironment : null,
        );
      }
      await PushTokenUploadLocalStore.instance.markSuccess(
        deviceId: deviceId,
        platform: 'IOS',
        tokenKeyHash: tokenKeyHash,
      );
    } catch (e) {
      _trace('POST /me/push-token failed reason=$reason error=$e');
      if (kDebugMode) {
        debugPrint('IosApnsPush: upload token failed ($e)');
      }
    }
  }

  Future<void> _deleteServerTokenIfPossible({required String reason}) async {
    final authToken = ApiClient.instance.token;
    if (!ApiClient.isValidJwt(authToken)) {
      return;
    }
    try {
      await PushTokenApi.instance.deleteCurrentDeviceToken();
      if (kDebugMode) {
        debugPrint('IosApnsPush: server token deleted reason=$reason');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IosApnsPush: delete server token failed ($e)');
      }
    }
  }

  Future<void> _consumePendingVoipPush() async {
    try {
      final payload = await _channel.invokeMapMethod<String, dynamic>(
        'consumePendingVoipPush',
      );
      if (payload == null || payload.isEmpty) {
        return;
      }
      await _handleVoipPush(payload);
    } catch (_) {}
  }

  Future<void> consumePendingNotificationTap() async {
    await _consumePendingTap();
  }

  Future<void> _consumePendingTap() async {
    try {
      final payload = await _channel.invokeMapMethod<String, dynamic>(
        'consumePendingNotificationTap',
      );
      if (payload == null || payload.isEmpty) {
        return;
      }
      await _dispatchTap(
        payload,
        source: 'ios_apns_cold_start_tap',
        handler: _onNotificationTap,
      );
    } catch (_) {}
  }

  Future<void> _handleRemoteNotificationReceived(dynamic raw) async {
    final data = _normalizePayload(raw);
    if (data.isEmpty) {
      return;
    }
    final handler = _onRemoteNotificationReceived;
    if (handler != null) {
      await handler(data);
    }
  }

  Future<void> _handleVoipPush(dynamic raw) async {
    final data = _normalizePayload(raw);
    if (data.isEmpty) {
      return;
    }
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    if (VoipPushPayload.shouldEndCall(data)) {
      await endVoipCallKit();
      return;
    }
    if (!VoipPushPayload.isCallPushType(type)) {
      return;
    }
    final inviteId = VoipPushPayload.readInviteId(data);
    final handler = _onVoipPush;
    if (handler != null) {
      await handler(data);
    }
    if (inviteId != null) {
      unawaited(syncHandledVoipInviteId(inviteId));
    }
    try {
      final loginRes = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
      if (loginRes.data == null || loginRes.data!.isEmpty) {
        _trace('voip push received before IM login inviteId=$inviteId');
      }
    } catch (_) {}
  }

  Future<void> _dispatchTap(
    dynamic raw, {
    required String source,
    IosPushTapHandler? handler,
  }) async {
    final data = _normalizePayload(raw);
    _trace(
      'tap dispatch source=$source empty=${data.isEmpty} '
      'conv=${data['conversationID'] ?? ''} '
      'handler=${(handler ?? _onNotificationTap) != null}',
    );
    if (data.isEmpty) {
      return;
    }
    final callback = handler ?? _onNotificationTap;
    if (callback != null) {
      await callback(<String, dynamic>{...data, '_source': source});
    }
  }

  Map<String, dynamic> _normalizePayload(dynamic raw) {
    if (raw is Map) {
      final output = <String, dynamic>{};
      raw.forEach((key, value) {
        if (key == null || value == null) {
          return;
        }
        output[key.toString()] = value;
      });
      return output;
    }
    if (raw is String && raw.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return _normalizePayload(decoded);
        }
      } catch (_) {}
    }
    return const <String, dynamic>{};
  }

  String? _readToken(dynamic raw) {
    if (raw is Map) {
      return raw['token']?.toString().trim();
    }
    return raw?.toString().trim();
  }

  String _buildSubmitKey(
    String apnsToken,
    String voipToken,
    String authToken, {
    String bundleId = '',
    String apsEnvironment = '',
  }) {
    final raw =
        '${ApiClient.instance.deviceId}|$apnsToken|$voipToken|$authToken|$bundleId|$apsEnvironment';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  String _buildTokenKeyHash({
    required String deviceId,
    required String apnsToken,
    required String voipToken,
    String bundleId = '',
    String apsEnvironment = '',
  }) {
    final raw =
        '$deviceId|${apnsToken.trim()}|${voipToken.trim()}|$bundleId|$apsEnvironment';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  // 推送链路打点（print）。默认关闭，避免前台反复 skip 刷屏；排查时再开。
  static const bool _traceEnabled = false;

  void _trace(String message) {
    if (!_traceEnabled) return;
    print('$_tracePrefix $message');
  }
}
