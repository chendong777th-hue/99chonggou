import 'dart:async';
import 'dart:io';

import 'package:tencent_calls_uikit/src/call_engine.dart';
import 'package:tencent_calls_uikit/src/call_define.dart';
import 'package:tencent_calls_uikit/src/call_observer.dart';
import 'package:tencent_calls_uikit/src/impl/call_manager.dart';
import 'package:tencent_calls_uikit/src/data/constants.dart';
import 'package:tencent_calls_uikit/src/data/user.dart';
import 'package:tencent_calls_uikit/src/extensions/calling_bell_feature.dart';
import 'package:tencent_calls_uikit/src/extensions/trtc_logger.dart';
import 'package:tencent_calls_uikit/src/i18n/i18n_utils.dart';
import 'package:tencent_calls_uikit/src/platform/call_engine_platform_interface.dart';
import 'package:tencent_calls_uikit/src/platform/call_kit_platform_interface.dart';
import 'package:tencent_calls_uikit/src/utils/key_metrics.dart';
import 'package:tencent_calls_uikit/src/utils/preference.dart';
import 'package:tencent_calls_uikit/src/utils/string_stream.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_uikit_core/tencent_cloud_uikit_core.dart';

class CallState {
  static final CallState instance = CallState._internal();

  factory CallState() {
    return instance;
  }

  CallState._internal() {
    init();
  }

  User selfUser = User();
  User caller = User();
  List<User> calleeList = [];
  List<String> calleeIdList = [];
  List<User> remoteUserList = [];
  TUICallScene scene = TUICallScene.singleCall;
  TUICallMediaType mediaType = TUICallMediaType.none;
  int timeCount = 0;
  int startTime = 0;
  Timer? _timer;
  Future<void>? _terminationFuture;
  bool _terminationCompleted = false;
  TUIRoomId roomId = TUIRoomId.intRoomId(intRoomId: 0);
  String groupId = '';
  bool isCameraOpen = false;
  TUICamera camera = TUICamera.front;
  bool isMicrophoneMute = false;
  TUIAudioPlaybackDevice audioDevice = TUIAudioPlaybackDevice.earpiece;
  bool enableMuteMode = false;
  bool enableFloatWindow = false;
  bool showVirtualBackgroundButton = false;
  bool enableBlurBackground = false;
  NetworkQualityHint networkQualityReminder = NetworkQualityHint.none;

  bool isChangedBigSmallVideo = false;
  bool isOpenFloatWindow = false;
  bool enableIncomingBanner = false;
  bool isInNativeIncomingBanner = false;

  bool isStartForegroundService = false;
  bool forceUseV2API = false;
  static String? Function(String userId)? displayNameResolver;
  bool? systemCallKitPresentationSucceeded;
  Completer<bool?>? _systemCallKitPresentationCompleter;
  String activeCallId = '';
  int _callEpoch = 0;
  int get callEpoch => _callEpoch;

  int beginCallSession(String callId) {
    final normalizedCallId = callId.trim();
    if (normalizedCallId.isNotEmpty &&
        normalizedCallId == activeCallId &&
        selfUser.callStatus != TUICallStatus.none) {
      return _callEpoch;
    }
    _callEpoch++;
    activeCallId = normalizedCallId;
    _terminationFuture = null;
    _terminationCompleted = false;
    resetSystemCallKitPresentation();
    TRTCLogger.info(
        'CallState beginCallSession(callId:$activeCallId, epoch:$_callEpoch)');
    return _callEpoch;
  }

  bool bindCallId(String callId) {
    final normalizedCallId = callId.trim();
    if (normalizedCallId.isEmpty) {
      return true;
    }
    if (activeCallId.isEmpty) {
      activeCallId = normalizedCallId;
      return true;
    }
    return activeCallId == normalizedCallId;
  }

  bool isCurrentSession({String? callId, int? epoch}) {
    if (epoch != null && epoch != _callEpoch) {
      return false;
    }
    final normalizedCallId = callId?.trim() ?? '';
    return normalizedCallId.isEmpty ||
        activeCallId.isEmpty ||
        normalizedCallId == activeCallId;
  }

  void updateSystemCallKitPresentation(bool succeeded) {
    systemCallKitPresentationSucceeded = succeeded;
    final completer = _systemCallKitPresentationCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(succeeded);
    }
  }

  Future<bool?> waitForSystemCallKitPresentation({
    Duration timeout = const Duration(milliseconds: 1200),
  }) async {
    final resolved = systemCallKitPresentationSucceeded;
    if (resolved != null) {
      return resolved;
    }
    final completer =
        _systemCallKitPresentationCompleter ??= Completer<bool?>();
    return completer.future.timeout(timeout, onTimeout: () => null);
  }

  void resetSystemCallKitPresentation() {
    systemCallKitPresentationSucceeded = null;
    final completer = _systemCallKitPresentationCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    _systemCallKitPresentationCompleter = null;
  }

  final TUICallObserver observer = TUICallObserver(onError:
      (int code, String message) {
    TRTCLogger.info('TUICallObserver onError(code:$code, message:$message)');
  }, onCallReceived: (String callId, String callerId, List<String> calleeIdList,
      TUICallMediaType mediaType, CallObserverExtraInfo info) async {
    TRTCLogger.info(
        'TUICallObserver onCallReceived(callId:$callId callerId:$callerId, calleeIdList:$calleeIdList, callMediaType:$mediaType, info:${info.toString()}), version:${Constants.pluginVersion}');
    KeyMetrics.countUV(EventId.received, callId: callId);
    final epoch = CallState.instance.beginCallSession(callId);
    final initialized = await CallState.instance.handleCallReceivedData(
        callerId, calleeIdList, info.chatGroupId, mediaType, epoch);
    if (!initialized || !CallState.instance.isCurrentSession(epoch: epoch)) {
      TRTCLogger.info(
          'TUICallObserver onCallReceived ignored stale continuation(callId:$callId, epoch:$epoch)');
      return;
    }
    // 系统 CallKit 的接听可能早于 IM 来电信令。状态进入 waiting 后
    // 单独通知 pending action，不借用会打开自定义通话页的事件。
    TUICore.instance.notifyEvent(setStateEventOnCallSignalingReady);
    await TUICallKitPlatform.instance.updateCallStateToNative();
    await CallManager.instance.syncScreenPowerPolicy();
    if (!CallState.instance.isCurrentSession(epoch: epoch)) {
      return;
    }

    if (Platform.isIOS) {
      final systemPresentation =
          await CallState.instance.waitForSystemCallKitPresentation();
      if (!CallState.instance.isCurrentSession(epoch: epoch)) {
        return;
      }
      if (systemPresentation != true) {
        await CallingBellFeature.startRing(callEpoch: epoch);
      }
      if (systemPresentation == true) {
        CallState.instance.isInNativeIncomingBanner = false;
        TRTCLogger.info(
            'TUICallKit suppress custom incoming UI, CallKit decision:$systemPresentation');
      } else if (CallState.instance.enableIncomingBanner) {
        CallState.instance.isInNativeIncomingBanner = true;
        await TUICallKitPlatform.instance.showIncomingBanner();
      } else {
        CallState.instance.isInNativeIncomingBanner = false;
        CallManager.instance.launchCallingPage();
      }
    } else if (Platform.isAndroid) {
      await CallingBellFeature.startRing(callEpoch: epoch);
      if (!CallState.instance.isCurrentSession(epoch: epoch)) {
        return;
      }
      if (await CallManager.instance.isScreenLocked()) {
        CallManager.instance.openLockScreenApp();
        return;
      }

      if (CallState.instance.enableIncomingBanner &&
          !(await CallManager.instance.isSamsungDevice())) {
        CallState.instance.isInNativeIncomingBanner = true;
        CallManager.instance.showIncomingBanner();
      } else {
        if (await TUICallKitPlatform.instance.isAppInForeground()) {
          CallState.instance.isInNativeIncomingBanner = false;
          CallManager.instance.launchCallingPage();
        } else {
          CallManager.instance.pullBackgroundApp();
        }
      }
    }
  }, onCallCancelled: (String callerId) {
    final normalizedCallerId = normalizeCallUserId(callerId);
    if (CallState.instance.selfUser.callStatus != TUICallStatus.waiting ||
        normalizedCallerId.isEmpty ||
        normalizedCallerId != CallState.instance.caller.id) {
      TRTCLogger.info(
          'TUICallObserver onCallCancelled ignored callerId:$callerId activeCaller:${CallState.instance.caller.id}');
      return;
    }
    CallState.instance.terminateCall(
        source: 'onCallCancelled:$callerId',
        epoch: CallState.instance.callEpoch);
  }, onCallNotConnected: (String callId, TUICallMediaType mediaType,
      CallEndReason reason, String userId, CallObserverExtraInfo info) {
    TRTCLogger.info(
        'TUICallObserver onCallNotConnected(callId:$callId, mediaType:$mediaType, reason:$reason, userId:$userId, info:${info.toString()})');
    CallState.instance
        .terminateCall(source: 'onCallNotConnected:$callId', callId: callId);
  }, onCallBegin:
      (String callId, TUICallMediaType mediaType, CallObserverExtraInfo info) {
    TRTCLogger.info(
        'TUICallObserver onCallBegin(callId:$callId, mediaType:$mediaType, info:${info.toString()})');
    if (!CallState.instance.bindCallId(callId)) {
      TRTCLogger.info(
          'TUICallObserver onCallBegin ignored stale callId:$callId active:${CallState.instance.activeCallId}');
      return;
    }
    CallState.instance.startTime =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    CallingBellFeature.stopRing();
    CallState.instance.roomId = info.roomId;
    CallState.instance.mediaType = mediaType;
    CallState.instance.selfUser.callRole = info.role;
    CallState.instance.selfUser.callStatus = TUICallStatus.accept;
    CallState.instance.groupId = info.chatGroupId;
    if (Platform.isIOS &&
        CallState.instance.systemCallKitPresentationSucceeded == true) {
      TUICallKitPlatform.instance.isAppInForeground().then((isForeground) {
        if (isForeground) {
          CallManager.instance.launchCallingPage();
        }
      });
    }
    if (CallState.instance.isMicrophoneMute) {
      CallManager.instance.closeMicrophone();
    } else {
      CallManager.instance.openMicrophone();
    }
    CallManager.instance.initAudioPlayDeviceAndCamera();
    CallState.instance.startTimer();
    CallState.instance.isChangedBigSmallVideo = true;
    CallState.instance.isInNativeIncomingBanner = false;
    TUICore.instance.notifyEvent(setStateEvent);
    TUICore.instance.notifyEvent(setStateEventOnCallBegin);
    TUICallKitPlatform.instance.updateCallStateToNative();
  }, onCallEnd: (String callId,
      TUICallMediaType mediaType,
      CallEndReason reason,
      String userId,
      double totalTime,
      CallObserverExtraInfo info) {
    TRTCLogger.info(
        'TUICallObserver onCallEnd(callId:$callId, mediaType:$mediaType, reason:$reason, userId:$userId totalTime:$totalTime, info:${info.toString()})');
    CallState.instance
        .terminateCall(source: 'onCallEnd:$callId', callId: callId);
  }, onCallMediaTypeChanged:
      (TUICallMediaType oldCallMediaType, TUICallMediaType newCallMediaType) {
    CallState.instance.mediaType = newCallMediaType;
    TUICore.instance.notifyEvent(setStateEvent);
    TUICallKitPlatform.instance.updateCallStateToNative();
  }, onUserReject: (String userId) {
    TRTCLogger.info('TUICallObserver onUserReject(userId:$userId)');
    for (var remoteUser in CallState.instance.remoteUserList) {
      if (remoteUser.id == userId) {
        CallState.instance.remoteUserList.remove(remoteUser);
        TUICore.instance.notifyEvent(setStateEvent);
        break;
      }
    }

    TUICallKitPlatform.instance.updateCallStateToNative();
    if (TUICallScene.singleCall == CallState.instance.scene) {
      CallManager.instance
          .showToast(CallKit_t('otherPartyDeclinedCallRequest'));
    }
  }, onUserNoResponse: (String userId) {
    TRTCLogger.info('TUICallObserver onUserNoResponse(userId:$userId)');
    for (var remoteUser in CallState.instance.remoteUserList) {
      if (remoteUser.id == userId) {
        CallState.instance.remoteUserList.remove(remoteUser);
        TUICore.instance.notifyEvent(setStateEvent);
        break;
      }
    }

    TUICallKitPlatform.instance.updateCallStateToNative();
    if (TUICallScene.singleCall == CallState.instance.scene) {
      CallManager.instance.showToast(CallKit_t('otherPartyNoResponse'));
    }
  }, onUserLineBusy: (String userId) {
    TRTCLogger.info('TUICallObserver onUserLineBusy(userId:$userId)');
    CallState.instance.remoteUserList
        .removeWhere((remoteUser) => remoteUser.id == userId);
    TUICore.instance.notifyEvent(setStateEvent);
    TUICallKitPlatform.instance.updateCallStateToNative();
    if (TUICallScene.singleCall == CallState.instance.scene) {
      CallManager.instance.showToast(CallKit_t('otherPartyBusy'));
    } else {
      CallManager.instance.showToast('$userId ${CallKit_t('busy')}');
    }
  }, onUserJoin: (String userId) async {
    if (Constants.aiTranslationRobotPrefixList
        .any((robot) => userId.contains(robot))) {
      return;
    }

    TRTCLogger.info('TUICallObserver onUserJoin(userId:$userId)');
    for (var remoteUser in CallState.instance.remoteUserList) {
      if (remoteUser.id == userId) {
        remoteUser.callStatus = TUICallStatus.accept;
        TUICore.instance.notifyEvent(setStateEvent);

        TUICallKitPlatform.instance.updateCallStateToNative();
        return;
      }
    }

    final user = User();
    user.id = userId;
    user.callStatus = TUICallStatus.accept;
    CallState.instance.remoteUserList.add(user);
    final imInfo = await TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .getFriendsInfo(userIDList: [userId]);
    user.nickname = StringStream.makeNull(
        imInfo.data?[0].friendInfo?.userProfile?.nickName, '');
    user.remark =
        StringStream.makeNull(imInfo.data?[0].friendInfo?.friendRemark, '');
    user.avatar = StringStream.makeNull(
        imInfo.data?[0].friendInfo?.userProfile?.faceUrl,
        Constants.defaultAvatar);
    TUICore.instance.notifyEvent(setStateEvent);

    TUICallKitPlatform.instance.updateCallStateToNative();
  }, onUserLeave: (String userId) {
    TRTCLogger.info('TUICallObserver onUserLeave(userId:$userId)');
    for (var remoteUser in CallState.instance.remoteUserList) {
      if (remoteUser.id == userId) {
        CallState.instance.remoteUserList.remove(remoteUser);
        TUICore.instance.notifyEvent(setStateEvent);
        break;
      }
    }

    TUICallKitPlatform.instance.updateCallStateToNative();

    if (TUICallScene.singleCall == CallState.instance.scene) {
      CallManager.instance.showToast(CallKit_t('otherPartyHungUp'));
    }
  }, onUserVideoAvailable: (String userId, bool isVideoAvailable) {
    TRTCLogger.info(
        'TUICallObserver onUserVideoAvailable(userId:$userId, isVideoAvailable:$isVideoAvailable)');
    for (var remoteUser in CallState.instance.remoteUserList) {
      if (remoteUser.id == userId) {
        remoteUser.videoAvailable = isVideoAvailable;
        TUICore.instance.notifyEvent(setStateEvent);

        TUICallKitPlatform.instance.updateCallStateToNative();
        return;
      }
    }
  }, onUserAudioAvailable: (String userId, bool isAudioAvailable) {
    TRTCLogger.info(
        'TUICallObserver onUserAudioAvailable(userId:$userId, isVideoAvailable:$isAudioAvailable)');
    for (var remoteUser in CallState.instance.remoteUserList) {
      if (remoteUser.id == userId) {
        remoteUser.audioAvailable = isAudioAvailable;
        TUICore.instance.notifyEvent(setStateEvent);
        return;
      }
    }
  }, onUserNetworkQualityChanged:
      (List<TUINetworkQualityInfo> networkQualityList) {
    if (networkQualityList.isEmpty) {
      return;
    }
    if (TUICallScene.groupCall == CallState.instance.scene) {
      for (var networkQualityInfo in networkQualityList) {
        if (networkQualityInfo.userId == CallState.instance.selfUser.id) {
          CallState.instance.selfUser.networkQualityReminder =
              CallState.instance.isBadNetwork(networkQualityInfo.quality);
          continue;
        }
        for (var remoteUser in CallState.instance.remoteUserList) {
          if (remoteUser.id == networkQualityInfo.userId) {
            remoteUser.networkQualityReminder =
                CallState.instance.isBadNetwork(networkQualityInfo.quality);
          }
        }
      }
    } else if (TUICallScene.singleCall == CallState.instance.scene) {
      TUINetworkQuality localQuality = TUINetworkQuality.unknown;
      TUINetworkQuality remoteQuality = TUINetworkQuality.unknown;

      for (var networkQualityInfo in networkQualityList) {
        if (CallState.instance.selfUser.id == networkQualityInfo.userId) {
          localQuality = networkQualityInfo.quality;
        } else {
          remoteQuality = networkQualityInfo.quality;
        }
      }

      if (CallState.instance.isBadNetwork(localQuality)) {
        CallState.instance.networkQualityReminder = NetworkQualityHint.local;
      } else if (CallState.instance.isBadNetwork(remoteQuality)) {
        CallState.instance.networkQualityReminder = NetworkQualityHint.remote;
      } else {
        CallState.instance.networkQualityReminder = NetworkQualityHint.none;
      }
    }
    TUICore.instance.notifyEvent(setStateEvent);
  }, onUserVoiceVolumeChanged: (Map<String, int> volumeMap) {
    bool needUpdate2Native = false;
    for (var remoteUser in CallState.instance.remoteUserList) {
      var volume = volumeMap[remoteUser.id] ?? 0;
      remoteUser.playOutVolume = volume;
      if (volume > 10) {
        needUpdate2Native = true;
      }
    }

    var selfVolume = volumeMap[CallState.instance.selfUser.id] ?? 0;
    CallState.instance.selfUser.playOutVolume = selfVolume;
    if (selfVolume > 10) {
      needUpdate2Native = true;
    }

    if (needUpdate2Native) {
      TUICallKitPlatform.instance.updateCallStateToNative();
      TUICore.instance.notifyEvent(setStateEvent);
    }
  }, onKickedOffline: () {
    TRTCLogger.info('TUICallObserver onKickedOffline()');
    CallManager.instance.hangup();
    CallState.instance.terminateCall(source: 'onKickedOffline');
  }, onUserSigExpired: () {
    TRTCLogger.info('TUICallObserver onUserSigExpired()');
    CallManager.instance.hangup();
    CallState.instance.terminateCall(source: 'onUserSigExpired');
  });

  void init() {
    PreferenceUtils.getInstance()
        .getBool(Constants.spKeyEnableMuteMode, false)
        .then((value) => {enableMuteMode = value});
  }

  Future<void> registerEngineObserver() async {
    TRTCLogger.info('CallState registerEngineObserver');
    await TUICallEngine.instance.addObserver(observer);
  }

  void unRegisterEngineObserver() {
    TUICallEnginePlatform.instance.removeAllObserver();
  }

  static String normalizeCallUserId(String raw) {
    var text = raw.trim();
    if (text.startsWith('c2c_')) {
      text = text.substring(4).trim();
    }
    final hashIndex = text.indexOf('#');
    if (hashIndex > 0) {
      text = text.substring(0, hashIndex).trim();
    }
    return text;
  }

  void _applyResolvedProfile({
    required String userId,
    required String nickname,
    required String avatar,
    required String remark,
  }) {
    if (userId.isEmpty) {
      return;
    }
    if (CallState.instance.caller.id == userId) {
      if (nickname.isNotEmpty) {
        CallState.instance.caller.nickname = nickname;
      }
      if (remark.isNotEmpty) {
        CallState.instance.caller.remark = remark;
      }
      if (avatar.isNotEmpty) {
        CallState.instance.caller.avatar = avatar;
      }
      return;
    }
    for (final callee in CallState.instance.calleeList) {
      if (callee.id != userId) {
        continue;
      }
      if (nickname.isNotEmpty) {
        callee.nickname = nickname;
      }
      if (remark.isNotEmpty) {
        callee.remark = remark;
      }
      if (avatar.isNotEmpty) {
        callee.avatar = avatar;
      }
      return;
    }
  }

  Future<bool> _hydrateUsersWithoutProfile(
      List<String> userIds, int epoch) async {
    if (!isCurrentSession(epoch: epoch)) {
      return false;
    }
    final pending = <String>{};
    for (final userId in userIds) {
      final normalized = normalizeCallUserId(userId);
      if (normalized.isEmpty || normalized == CallState.instance.selfUser.id) {
        continue;
      }
      if (CallState.instance.caller.id == normalized) {
        if (CallState.instance.caller.nickname.isEmpty &&
            CallState.instance.caller.remark.isEmpty) {
          pending.add(normalized);
        }
        continue;
      }
      for (final callee in CallState.instance.calleeList) {
        if (callee.id == normalized &&
            callee.nickname.isEmpty &&
            callee.remark.isEmpty) {
          pending.add(normalized);
          break;
        }
      }
    }
    if (pending.isEmpty) {
      return true;
    }

    final unresolved = <String>{};
    for (final userId in pending) {
      final resolved = displayNameResolver?.call(userId)?.trim() ?? '';
      if (resolved.isNotEmpty) {
        _applyResolvedProfile(
          userId: userId,
          nickname: resolved,
          avatar: '',
          remark: '',
        );
        continue;
      }
      unresolved.add(userId);
    }
    if (unresolved.isEmpty) {
      return true;
    }

    final res = await TencentImSDKPlugin.v2TIMManager
        .getUsersInfo(userIDList: unresolved.toList());
    if (!isCurrentSession(epoch: epoch)) {
      return false;
    }
    for (final profile in res.data ?? const []) {
      final userId = profile.userID?.trim() ?? '';
      if (userId.isEmpty) {
        continue;
      }
      _applyResolvedProfile(
        userId: userId,
        nickname: StringStream.makeNull(profile.nickName, ''),
        avatar: StringStream.makeNull(profile.faceUrl, Constants.defaultAvatar),
        remark: '',
      );
    }
    return true;
  }

  Future<bool> handleCallReceivedData(
      String callerId,
      List<String> calleeIdList,
      String groupId,
      TUICallMediaType callMediaType,
      int epoch) async {
    if (!isCurrentSession(epoch: epoch)) {
      return false;
    }
    callerId = normalizeCallUserId(callerId);
    calleeIdList = calleeIdList
        .map(normalizeCallUserId)
        .where((userId) => userId.isNotEmpty)
        .toList();
    CallState.instance.caller = User();
    CallState.instance.calleeList.clear();
    CallState.instance.remoteUserList.clear();
    CallState.instance.caller.id = callerId;
    CallState.instance.calleeIdList.clear();
    CallState.instance.calleeIdList.addAll(calleeIdList);
    CallState.instance.groupId = groupId;
    CallState.instance.mediaType = callMediaType;
    CallState.instance.selfUser.callStatus = TUICallStatus.waiting;

    if (callMediaType == TUICallMediaType.none || calleeIdList.isEmpty) {
      return false;
    }

    if (calleeIdList.length >= Constants.groupCallMaxUserCount) {
      CallManager.instance.showToast(CallKit_t('exceededMaximumNumber'));
      return false;
    }

    CallState.instance.groupId = groupId;
    if (CallState.instance.groupId.isNotEmpty || calleeIdList.length > 1) {
      CallState.instance.scene = TUICallScene.groupCall;
    } else {
      CallState.instance.scene = TUICallScene.singleCall;
    }
    CallState.instance.mediaType = callMediaType;

    CallState.instance.selfUser.callRole = TUICallRole.called;

    final allUserId = [callerId] + calleeIdList;

    for (var userId in allUserId) {
      if (CallState.instance.selfUser.id == userId) {
        if (userId == callerId) {
          CallState.instance.caller = CallState.instance.selfUser;
        } else {
          CallState.instance.calleeList.add(CallState.instance.selfUser);
        }
        continue;
      }

      final user = User();
      user.id = userId;

      if (userId == callerId) {
        CallState.instance.caller = user;
      } else {
        CallState.instance.calleeList.add(user);
      }
    }

    final imFriendsUserInfos = await TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .getFriendsInfo(userIDList: allUserId);
    if (!isCurrentSession(epoch: epoch)) {
      return false;
    }
    for (var imFriendUserInfo in imFriendsUserInfos.data ?? const []) {
      final friendUserId = imFriendUserInfo.friendInfo?.userID?.trim() ?? '';
      if (friendUserId.isEmpty ||
          friendUserId == CallState.instance.selfUser.id) {
        continue;
      }

      _applyResolvedProfile(
        userId: friendUserId,
        nickname: StringStream.makeNull(
            imFriendUserInfo.friendInfo?.userProfile?.nickName, ''),
        avatar: StringStream.makeNull(
            imFriendUserInfo.friendInfo?.userProfile?.faceUrl,
            Constants.defaultAvatar),
        remark: StringStream.makeNull(
            imFriendUserInfo.friendInfo?.friendRemark, ''),
      );

      if (friendUserId == callerId) {
        CallState.instance.caller.callStatus = TUICallStatus.waiting;
        CallState.instance.caller.callRole = TUICallRole.caller;
      } else {
        for (var calleeUser in CallState.instance.calleeList) {
          if (calleeUser.id == friendUserId) {
            calleeUser.callStatus = TUICallStatus.waiting;
            calleeUser.callRole = TUICallRole.called;
          }
        }
      }
    }

    if (!await _hydrateUsersWithoutProfile(allUserId, epoch) ||
        !isCurrentSession(epoch: epoch)) {
      return false;
    }

    CallState.instance.remoteUserList.clear();
    if (CallState.instance.caller.id.isNotEmpty &&
        CallState.instance.selfUser.id != CallState.instance.caller.id) {
      CallState.instance.remoteUserList.add(CallState.instance.caller);
    }
    for (var callee in CallState.instance.calleeList) {
      if (CallState.instance.selfUser.id == callee.id) {
        continue;
      }
      CallState.instance.remoteUserList.add(callee);
    }
    return true;
  }

  void startTimer() {
    CallState.instance.timeCount = 0;
    CallState.instance._timer?.cancel();
    CallState.instance._timer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (TUICallStatus.accept != CallState.instance.selfUser.callStatus) {
        stopTimer();
        return;
      }
      CallState.instance.timeCount++;
      TUICore.instance.notifyEvent(setStateEventRefreshTiming);
    });
  }

  void stopTimer() {
    CallState.instance._timer?.cancel();
    CallState.instance._timer = null;
  }

  Future<void> terminateCall({
    required String source,
    String? callId,
    int? epoch,
  }) {
    if (!isCurrentSession(callId: callId, epoch: epoch)) {
      TRTCLogger.info(
          'CallState terminateCall ignored stale session(source:$source, callId:$callId, epoch:$epoch, activeCallId:$activeCallId, activeEpoch:$_callEpoch)');
      return Future<void>.value();
    }
    final targetEpoch = epoch ?? _callEpoch;
    if (selfUser.callStatus != TUICallStatus.none) {
      _terminationCompleted = false;
    }

    final inProgress = _terminationFuture;
    if (inProgress != null) {
      TRTCLogger.info(
          'CallState terminateCall ignored while in progress(source:$source)');
      return inProgress;
    }

    if (_terminationCompleted) {
      TRTCLogger.info(
          'CallState terminateCall already completed(source:$source)');
      return CallingBellFeature.stopRing();
    }

    late final Future<void> termination;
    termination = _performTermination(source, targetEpoch).whenComplete(() {
      if (identical(_terminationFuture, termination)) {
        _terminationFuture = null;
      }
    });
    _terminationFuture = termination;
    return termination;
  }

  Future<void> _performTermination(String source, int epoch) async {
    TRTCLogger.info(
        'CallState terminateCall start(source:$source, epoch:$epoch)');
    final remoteUserIds = remoteUserList
        .map((user) => user.id)
        .where((id) => id.isNotEmpty)
        .toList();

    await _runTerminationStep(
        'stopRing', () => CallingBellFeature.stopRing(callEpoch: epoch));
    if (!isCurrentSession(epoch: epoch)) {
      return;
    }
    stopTimer();
    await _runTerminationStep('closeCamera', CallManager.instance.closeCamera);
    if (!isCurrentSession(epoch: epoch)) {
      return;
    }
    await _runTerminationStep(
        'closeMicrophone', CallManager.instance.closeMicrophone);
    if (!isCurrentSession(epoch: epoch)) {
      return;
    }
    for (final userId in remoteUserIds) {
      await _runTerminationStep('stopRemoteView:$userId',
          () => CallManager.instance.stopRemoteView(userId));
      if (!isCurrentSession(epoch: epoch)) {
        return;
      }
    }
    await _runTerminationStep(
        'stopForegroundService', CallManager.instance.stopForegroundService);

    if (!isCurrentSession(epoch: epoch)) {
      return;
    }
    cleanState();
    activeCallId = '';
    _terminationCompleted = true;
    TUICore.instance.notifyEvent(setStateEventOnCallEnd);
    await _runTerminationStep('updateCallStateToNative',
        TUICallKitPlatform.instance.updateCallStateToNative);
    await _runTerminationStep(
        'syncScreenPowerPolicy', CallManager.instance.syncScreenPowerPolicy);
    TRTCLogger.info(
        'CallState terminateCall complete(source:$source, epoch:$epoch)');
  }

  Future<void> _runTerminationStep(
      String name, Future<void> Function() step) async {
    try {
      await step();
    } catch (error) {
      TRTCLogger.info(
          'CallState terminateCall step failed(name:$name, error:$error)');
    }
  }

  void cleanState() {
    KeyMetrics.reset();
    CallState.instance.resetSystemCallKitPresentation();
    CallState.instance.activeCallId = '';

    CallState.instance.selfUser.callRole = TUICallRole.none;
    CallState.instance.selfUser.callStatus = TUICallStatus.none;

    CallState.instance.remoteUserList.clear();
    CallState.instance.caller = User();
    CallState.instance.calleeList.clear();
    CallState.instance.calleeIdList.clear();

    CallState.instance.mediaType = TUICallMediaType.none;
    CallState.instance.scene = TUICallScene.singleCall;
    CallState.instance.timeCount = 0;
    CallState.instance.startTime = 0;
    CallState.instance.roomId = TUIRoomId.intRoomId(intRoomId: 0);
    CallState.instance.groupId = '';

    CallState.instance.isMicrophoneMute = false;
    CallState.instance.camera = TUICamera.front;
    CallState.instance.isCameraOpen = false;
    CallState.instance.audioDevice = TUIAudioPlaybackDevice.earpiece;

    CallState.instance.isChangedBigSmallVideo = false;
    CallState.instance.isOpenFloatWindow = false;
    CallState.instance.isInNativeIncomingBanner = false;
    CallState.instance.enableBlurBackground = false;
    CallState.instance.networkQualityReminder = NetworkQualityHint.none;
  }

  bool isBadNetwork(TUINetworkQuality quality) {
    return quality == TUINetworkQuality.bad ||
        quality == TUINetworkQuality.vBad ||
        quality == TUINetworkQuality.down;
  }
}
