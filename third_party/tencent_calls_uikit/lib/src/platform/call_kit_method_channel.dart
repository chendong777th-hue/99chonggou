import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tencent_calls_uikit/src/call_define.dart';
import 'package:tencent_calls_uikit/src/impl/call_manager.dart';
import 'package:tencent_calls_uikit/src/impl/call_state.dart';
import 'package:tencent_calls_uikit/src/data/constants.dart';
import 'package:tencent_calls_uikit/src/extensions/trtc_logger.dart';
import 'package:tencent_calls_uikit/src/platform/call_kit_platform_interface.dart';
import 'package:tencent_calls_uikit/src/utils/key_metrics.dart';
import 'package:tencent_calls_uikit/src/utils/permission.dart';
import 'package:tencent_cloud_uikit_core/tencent_cloud_uikit_core.dart';

class MethodChannelTUICallKit extends TUICallKitPlatform {
  MethodChannelTUICallKit() {
    methodChannel.setMethodCallHandler((call) async {
      await _handleNativeCall(call);
    });
    TUICore.instance.registerEvent(
      setStateEventOnCallSignalingReady,
      (_) {
        _consumePendingSystemPresentation();
        _consumePendingVoipAction();
      },
    );
    TUICore.instance.registerEvent(
      setStateEventOnCallEnd,
      (_) => _clearPendingVoipAction(failAction: true),
    );
  }

  @visibleForTesting
  final methodChannel = const MethodChannel('tuicall_kit');
  _PendingVoipAction? _pendingVoipAction;
  Timer? _pendingVoipActionTimer;
  String _pendingPresentationInviteId = '';
  bool? _pendingPresentationSucceeded;
  static const Duration _pendingVoipActionTimeout = Duration(seconds: 30);

  @override
  Future<void> startForegroundService(bool isVideo) async {
    if (!kIsWeb && Platform.isAndroid) {
      await methodChannel.invokeMethod('startForegroundService', {
        'isVideo': isVideo,
      });
    }
  }

  @override
  Future<void> stopForegroundService() async {
    if (!kIsWeb && Platform.isAndroid) {
      await methodChannel.invokeMethod('stopForegroundService', {});
    }
  }

  @override
  Future<void> startRing(String filePath) async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await methodChannel.invokeMethod('startRing', {"filePath": filePath});
    }
  }

  @override
  Future<void> stopRing() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await methodChannel.invokeMethod('stopRing', {});
    }
  }

  @override
  Future<void> updateCallStateToNative() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      List remoteUserList = [];
      for (var i = 0; i < CallState.instance.remoteUserList.length; ++i) {
        remoteUserList.add(CallState.instance.remoteUserList[i].toJson());
      }

      methodChannel.invokeMethod('updateCallStateToNative', {
        'selfUser': CallState.instance.selfUser.toJson(),
        'remoteUserList': remoteUserList.isNotEmpty ? remoteUserList : [],
        'scene': CallState.instance.scene.index,
        'mediaType': CallState.instance.mediaType.index,
        'startTime': CallState.instance.startTime,
        'camera': CallState.instance.camera.index,
        'isCameraOpen': CallState.instance.isCameraOpen,
        'isMicrophoneMute': CallState.instance.isMicrophoneMute,
      });
    }
  }

  @override
  Future<void> startFloatWindow() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await methodChannel.invokeMethod('startFloatWindow', {});
    }
  }

  @override
  Future<void> stopFloatWindow() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await methodChannel.invokeMethod('stopFloatWindow', {});
    }
  }

  @override
  Future<bool> hasFloatPermission() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      return await methodChannel.invokeMethod('hasFloatPermission', {});
    } else {
      return false;
    }
  }

  @override
  Future<bool> isAndroidPictureInPictureSupported() async {
    if (!kIsWeb && Platform.isAndroid) {
      return await methodChannel
          .invokeMethod('isAndroidPictureInPictureSupported', {});
    }
    return false;
  }

  @override
  Future<void> enterMobilePictureInPicture() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      debugPrint('[CallPip] invoke enterMobilePictureInPicture');
      await methodChannel.invokeMethod('enterMobilePictureInPicture', {});
    }
  }

  @override
  Future<bool> isAppInForeground() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      return await methodChannel.invokeMethod('isAppInForeground', {});
    } else {
      return false;
    }
  }

  @override
  Future<bool> showIncomingBanner() async {
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        await methodChannel.invokeMethod('showIncomingBanner', {});
      } else {
        return false;
      }
    } on PlatformException catch (_) {
      return false;
    } on Exception catch (_) {
      return false;
    }
    return true;
  }

  @override
  Future<bool> initResources(Map resources) async {
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        await methodChannel
            .invokeMethod('initResources', {"resources": resources});
      } else {
        return false;
      }
    } on PlatformException catch (_) {
      return false;
    } on Exception catch (_) {
      return false;
    }
    return true;
  }

  @override
  Future<void> openMicrophone() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await methodChannel.invokeMethod('openMicrophone', {});
    }
  }

  @override
  Future<void> closeMicrophone() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await methodChannel.invokeMethod('closeMicrophone', {});
    }
  }

  @override
  Future<void> apiLog(TRTCLoggerLevel level, String logString) async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await methodChannel.invokeMethod(
          'apiLog', {'level': level.index, 'logString': logString});
    }
  }

  @override
  Future<bool> hasPermissions(
      {required List<PermissionType> permissions}) async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      List<int> permissionsList = [];
      for (var element in permissions) {
        permissionsList.add(element.index);
      }
      return await methodChannel
          .invokeMethod('hasPermissions', {'permission': permissionsList});
    } else {
      return false;
    }
  }

  @override
  Future<PermissionResult> requestPermissions(
      {required List<PermissionType> permissions,
      String title = "",
      String description = "",
      String settingsTip = ""}) async {
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        List<int> permissionsList = [];
        for (var element in permissions) {
          permissionsList.add(element.index);
        }
        int result = await methodChannel.invokeMethod('requestPermissions', {
          'permission': permissionsList,
          'title': title,
          'description': description,
          'settingsTip': settingsTip
        });
        if (result == PermissionResult.granted.index) {
          return PermissionResult.granted;
        } else if (result == PermissionResult.denied.index) {
          return PermissionResult.denied;
        } else {
          return PermissionResult.requesting;
        }
      } else {
        return PermissionResult.denied;
      }
    } on PlatformException catch (_) {
      return PermissionResult.denied;
    } on Exception catch (_) {
      return PermissionResult.denied;
    }
  }

  @override
  Future<bool> isNotificationEnabled() async {
    if (kIsWeb || Platform.isIOS) {
      return false;
    }
    return await methodChannel.invokeMethod('isNotificationEnabled', {});
  }

  @override
  Future<void> pullBackgroundApp() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await methodChannel.invokeMethod('pullBackgroundApp', {});
    }
  }

  @override
  Future<void> openLockScreenApp() async {
    if (!kIsWeb && Platform.isAndroid) {
      await methodChannel.invokeMethod('openLockScreenApp', {});
    }
  }

  @override
  Future<void> enableWakeLock(bool enable) async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await methodChannel.invokeMethod('enableWakeLock', {'enable': enable});
    }
  }

  @override
  Future<void> setScreenPowerPolicy(CallScreenPowerPolicy policy) async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await methodChannel.invokeMethod('setScreenPowerPolicy', {
        'policy': policy.index,
      });
    }
  }

  @override
  Future<bool> isScreenLocked() async {
    if (!kIsWeb && (Platform.isAndroid)) {
      return await methodChannel.invokeMethod('isScreenLocked', {});
    }
    return false;
  }

  @override
  Future<void> imSDKInitSuccessEvent() async {
    if (!kIsWeb && Platform.isAndroid) {
      TRTCLogger.info('imSDKInitSuccessEvent USBCameraService');
      await methodChannel.invokeMethod('imSDKInitSuccessEvent', {});
    }
  }

  @override
  Future<void> loginNativeTUICore(
      int sdkAppId, String userId, String userSig) async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await methodChannel.invokeMethod('loginNativeTUICore',
          {"sdkAppId": sdkAppId, "userId": userId, "userSig": userSig});
    }
  }

  @override
  Future<void> logoutNativeTUICore() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await methodChannel.invokeMethod('logoutNativeTUICore', {});
    }
  }

  @override
  Future<bool> checkUsbCameraService() async {
    if (!kIsWeb && Platform.isAndroid) {
      return await methodChannel.invokeMethod('checkUsbCameraService', {});
    }
    return false;
  }

  @override
  Future<void> openUsbCamera(int viewId) async {
    if (!kIsWeb && Platform.isAndroid) {
      await methodChannel.invokeMethod('openUsbCamera', {'viewId': viewId});
    }
  }

  @override
  Future<void> closeUsbCamera() async {
    if (!kIsWeb && Platform.isAndroid) {
      await methodChannel.invokeMethod('closeUsbCamera', {});
    }
  }

  @override
  Future<bool> isSamsungDevice() async {
    if (!kIsWeb && Platform.isAndroid) {
      return await methodChannel.invokeMethod('isSamsungDevice', {});
    }
    return false;
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case "backCallingPageFromFloatWindow":
        _backCallingPageFromFloatWindow();
        break;
      case "launchCallingPageFromIncomingBanner":
        _launchCallingPageFromIncomingBanner();
        break;
      case "appEnterForeground":
        _appEnterForeground();
        break;
      case "appEnterBackground":
        _appEnterBackground();
        break;
      case "voipChangeMute":
        await _handleVoipChangeMute(call);
        break;
      case "voipChangeAudioPlaybackDevice":
        _handleVoipChangeAudioPlaybackDevice(call);
        break;
      case "voipChangeHangup":
        await _handleVoipHangup(call);
        break;
      case "voipChangeAccept":
        await _handleVoipAccept(call);
        break;
      case "systemCallKitPresentation":
        _handleSystemCallKitPresentation(call);
        break;
      case "androidNotificationCallAction":
        await _handleAndroidNotificationCallAction(call);
        break;
      case "countUV":
        _countUV(call.arguments['isPush'], call.arguments['callId']);
        break;
      default:
        debugPrint("flutter: MethodNotImplemented ${call.method}");
        break;
    }
  }

  void _backCallingPageFromFloatWindow() {
    CallManager.instance.backCallingPageFormFloatWindow();
  }

  void _launchCallingPageFromIncomingBanner() {
    CallState.instance.isInNativeIncomingBanner = false;
    if (CallState.instance.selfUser.callStatus != TUICallStatus.none) {
      CallManager.instance.launchCallingPage();
    }
  }

  void _appEnterForeground() {
    CallManager.instance.handleAppEnterForeground();
  }

  void _appEnterBackground() {
    CallManager.instance.handleAppEnterBackground();
  }

  void _countUV(bool isPush, String callId) {
    if (isPush) {
      KeyMetrics.countUV(EventId.wakeupByPush, callId: callId);
    } else {
      KeyMetrics.countUV(EventId.wakeup, callId: callId);
    }
  }

  Future<void> _handleVoipChangeMute(MethodCall call) async {
    final arguments = call.arguments is Map ? call.arguments as Map : const {};
    final uuid = arguments['uuid']?.toString() ?? '';
    var succeeded = false;
    try {
      if (CallState.instance.selfUser.callStatus != TUICallStatus.none) {
        final mute = arguments['mute'] == true;
        CallState.instance.isMicrophoneMute = mute;
        if (mute) {
          await CallManager.instance.closeMicrophone(false);
        } else {
          final result = await CallManager.instance.openMicrophone(false);
          succeeded = result.code.isEmpty;
        }
        if (mute) {
          succeeded = true;
        }
        TUICore.instance.notifyEvent(setStateEvent);
      }
    } finally {
      await _completeVoipAction(uuid, succeeded);
    }
  }

  void _handleVoipChangeAudioPlaybackDevice(MethodCall call) {
    if (CallState.instance.selfUser.callStatus != TUICallStatus.none) {
      CallState.instance.audioDevice = call.arguments['audioPlaybackDevice'];
      CallManager.instance
          .selectAudioPlaybackDevice(CallState.instance.audioDevice);
      TUICore.instance.notifyEvent(setStateEvent);
    }
  }

  Future<void> _handleVoipHangup(MethodCall call) async {
    final action =
        _PendingVoipAction.fromMethodCall(_PendingVoipActionType.reject, call);
    if (!_actionMatchesCurrentCall(action)) {
      await _completeVoipAction(action.uuid, false);
      return;
    }
    TUIResult? result;
    if (CallState.instance.selfUser.callStatus == TUICallStatus.waiting) {
      _clearPendingVoipAction();
      result = await CallManager.instance.reject();
    } else if (CallState.instance.selfUser.callStatus == TUICallStatus.accept) {
      _clearPendingVoipAction();
      result = await CallManager.instance.hangup();
    } else {
      if (action.inviteId.isNotEmpty) {
        _queuePendingVoipAction(action);
      } else {
        await _completeVoipAction(action.uuid, false);
      }
      return;
    }
    await _completeVoipAction(action.uuid, result.code.isEmpty);
  }

  Future<void> _handleVoipAccept(MethodCall call) async {
    final action =
        _PendingVoipAction.fromMethodCall(_PendingVoipActionType.accept, call);
    if (!_actionMatchesCurrentCall(action)) {
      await _completeVoipAction(action.uuid, false);
      return;
    }
    if (CallState.instance.selfUser.callStatus == TUICallStatus.waiting) {
      _clearPendingVoipAction();
      await _acceptFromSystemCallKit(action);
    } else if (CallState.instance.selfUser.callStatus == TUICallStatus.none) {
      if (action.inviteId.isNotEmpty) {
        _queuePendingVoipAction(action);
      } else {
        await _completeVoipAction(action.uuid, false);
      }
    }
  }

  void _handleSystemCallKitPresentation(MethodCall call) {
    final arguments = call.arguments;
    if (arguments is! Map) {
      return;
    }
    final succeeded = arguments['succeeded'];
    final inviteId = arguments['inviteId']?.toString().trim() ?? '';
    if (succeeded is! bool) {
      return;
    }
    if (CallState.instance.activeCallId.isEmpty && inviteId.isNotEmpty) {
      _pendingPresentationInviteId = inviteId;
      _pendingPresentationSucceeded = succeeded;
      return;
    }
    if (inviteId.isNotEmpty &&
        CallState.instance.activeCallId.isNotEmpty &&
        inviteId != CallState.instance.activeCallId) {
      debugPrint(
          'TUICallKit: ignored stale CallKit presentation inviteId=$inviteId active=${CallState.instance.activeCallId}');
      return;
    }
    CallState.instance.updateSystemCallKitPresentation(succeeded);
    if (succeeded && CallState.instance.isInNativeIncomingBanner) {
      CallState.instance.isInNativeIncomingBanner = false;
      methodChannel.invokeMethod('closeIncomingBanner');
    }
    debugPrint('TUICallKit: system CallKit presentation succeeded=$succeeded');
  }

  void _consumePendingSystemPresentation() {
    final succeeded = _pendingPresentationSucceeded;
    final inviteId = _pendingPresentationInviteId;
    if (succeeded == null ||
        inviteId.isEmpty ||
        inviteId != CallState.instance.activeCallId) {
      return;
    }
    _pendingPresentationSucceeded = null;
    _pendingPresentationInviteId = '';
    CallState.instance.updateSystemCallKitPresentation(succeeded);
  }

  Future<void> _handleAndroidNotificationCallAction(MethodCall call) async {
    if (!Platform.isAndroid || call.arguments is! Map) {
      return;
    }
    final arguments = call.arguments as Map;
    final callId = arguments['callId']?.toString().trim() ?? '';
    if (callId.isEmpty || callId != CallState.instance.activeCallId) {
      debugPrint(
          'TUICallKit: ignored stale Android notification action callId=$callId active=${CallState.instance.activeCallId}');
      return;
    }
    final action = arguments['action']?.toString() ?? '';
    if (action == 'accept') {
      final permission = await Permission.ensure(CallState.instance.mediaType);
      if (permission != PermissionResult.granted ||
          callId != CallState.instance.activeCallId) {
        return;
      }
      await CallManager.instance.accept();
    } else if (action == 'reject') {
      await CallManager.instance.reject();
    }
  }

  void _queuePendingVoipAction(_PendingVoipAction action) {
    _pendingVoipAction = action;
    _pendingVoipActionTimer?.cancel();
    _pendingVoipActionTimer = Timer(
      _pendingVoipActionTimeout,
      () => _clearPendingVoipAction(failAction: true),
    );
    debugPrint('TUICallKit: queued pending CallKit action=$action');
  }

  Future<void> _consumePendingVoipAction() async {
    final action = _pendingVoipAction;
    if (action == null ||
        CallState.instance.selfUser.callStatus != TUICallStatus.waiting) {
      return;
    }
    _clearPendingVoipAction();
    debugPrint('TUICallKit: consuming pending CallKit action=$action');
    if (!_actionMatchesCurrentCall(action)) {
      _clearPendingVoipAction();
      return;
    }
    if (action.type == _PendingVoipActionType.accept) {
      await _acceptFromSystemCallKit(action);
    } else {
      final result = await CallManager.instance.reject();
      await _completeVoipAction(action.uuid, result.code.isEmpty);
    }
  }

  Future<void> _acceptFromSystemCallKit(_PendingVoipAction action) async {
    final result = await CallManager.instance.accept();
    final succeeded = result.code.isEmpty;
    debugPrint(
      'TUICallKit: system CallKit accept result '
      'succeeded=$succeeded code=${result.code} message=${result.message}',
    );
    await _completeVoipAction(action.uuid, succeeded);
    if (!succeeded && Platform.isIOS) {
      try {
        await const MethodChannel('ios_apns_push')
            .invokeMethod<void>('endVoipCallKit');
      } catch (_) {}
    }
  }

  bool _actionMatchesCurrentCall(_PendingVoipAction action) {
    final activeCallId = CallState.instance.activeCallId;
    if (action.inviteId.isEmpty || activeCallId.isEmpty) {
      return true;
    }
    final matches = action.inviteId == activeCallId;
    if (!matches) {
      debugPrint(
          'TUICallKit: ignored stale CallKit action inviteId=${action.inviteId} active=$activeCallId');
    }
    return matches;
  }

  Future<void> _completeVoipAction(String uuid, bool succeeded) async {
    if (!Platform.isIOS || uuid.isEmpty) {
      return;
    }
    try {
      await const MethodChannel('ios_apns_push')
          .invokeMethod<void>('completeVoipCallKitAction', {
        'uuid': uuid,
        'succeeded': succeeded,
      });
    } catch (error) {
      debugPrint('TUICallKit: complete CallKit action failed: $error');
    }
  }

  void _clearPendingVoipAction({bool failAction = false}) {
    final action = _pendingVoipAction;
    _pendingVoipAction = null;
    _pendingVoipActionTimer?.cancel();
    _pendingVoipActionTimer = null;
    if (failAction && action != null) {
      _completeVoipAction(action.uuid, false);
    }
  }
}

enum _PendingVoipActionType { accept, reject }

class _PendingVoipAction {
  const _PendingVoipAction({
    required this.type,
    required this.inviteId,
    required this.uuid,
  });

  factory _PendingVoipAction.fromMethodCall(
      _PendingVoipActionType type, MethodCall call) {
    final arguments = call.arguments;
    final map = arguments is Map ? arguments : const {};
    return _PendingVoipAction(
      type: type,
      inviteId: map['inviteId']?.toString().trim() ?? '',
      uuid: map['uuid']?.toString().trim() ?? '',
    );
  }

  final _PendingVoipActionType type;
  final String inviteId;
  final String uuid;

  @override
  String toString() =>
      '_PendingVoipAction(type:$type, inviteId:$inviteId, uuid:$uuid)';
}
