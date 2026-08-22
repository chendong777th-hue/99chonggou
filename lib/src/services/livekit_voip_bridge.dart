import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/incoming_call_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/ios_apns_push_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_kit_policy.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_media_helpers.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_navigator.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_ui_log.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';

/// Receives CallKit answer/hangup from iOS `tuicall_kit` channel (AppDelegate).
class LiveKitVoipBridge {
  LiveKitVoipBridge._();

  static final LiveKitVoipBridge instance = LiveKitVoipBridge._();

  static const MethodChannel _channel = MethodChannel('tuicall_kit');
  static const Duration _audioActivateTimeout = Duration(seconds: 8);

  bool _installed = false;
  Completer<void>? _audioActivatedCompleter;
  bool _audioSessionActivatedLatch = false;
  bool _callKitOwnsAudioSession = false;

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  void ensureInstalled() {
    if (_installed) return;
    iosCallKitAudioReadyWaiter = _waitForCallKitAudioReadyIfPending;
    iosCallKitOwnsAudioSession = () => _callKitOwnsAudioSession;
    _channel.setMethodCallHandler(_onMethod);
    _installed = true;
    unawaited(_syncLatchFromNative());
    if (kDebugMode) {
      debugPrint('LiveKitVoipBridge: installed on tuicall_kit');
    }
  }

  Future<dynamic> _onMethod(MethodCall call) async {
    final args = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : <String, dynamic>{};
    final inviteId = args['inviteId']?.toString().trim() ?? '';
    final uuid = args['uuid']?.toString().trim() ?? '';
    switch (call.method) {
      case 'voipChangeAccept':
        await _onAccept(inviteId, uuid);
        break;
      case 'voipChangeHangup':
        await _onHangup(inviteId, uuid);
        break;
      case 'voipChangeMute':
        final mute = args['mute'] == true;
        await LiveKitCallSession.instance.setMicrophoneEnabled(!mute);
        if (uuid.isNotEmpty) {
          await _completeAction(uuid, true);
        }
        break;
      case 'voipAudioSessionActivated':
        _onAudioSessionActivated();
        break;
      case 'voipAudioSessionDeactivated':
        if (kDebugMode) {
          debugPrint('LiveKitVoipBridge: audio session deactivated uuid=$uuid');
        }
        // CallKit end (even with keepAudioSession) often still delivers
        // didDeactivate — re-arm LiveKit playback if the call is still live.
        final session = LiveKitCallSession.instance;
        if (session.isInCall) {
          unawaited(
            session.recoverCallAudio(tag: 'voipAudioSessionDeactivated'),
          );
        }
        break;
      default:
        break;
    }
    return null;
  }

  void _onAudioSessionActivated() {
    _audioSessionActivatedLatch = true;
    liveKitCallUiLog('LiveKitVoipBridge: audio session activated');
    final c = _audioActivatedCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    final session = LiveKitCallSession.instance;
    unawaited(session.ensureCallAudioRoute());
    unawaited(session.ensureLocalMicPublishedAfterCallKitActivate());
  }

  /// Media join gate: wait only for an in-flight CallKit answer.
  /// Timeout is not ready — callers must defer mic publish, not proceed.
  Future<bool> _waitForCallKitAudioReadyIfPending({
    Duration timeout = _audioActivateTimeout,
  }) async {
    if (!_isIos) return true;
    final decision = iosCallKitAudioWaitDecision(
      callKitAnswerInFlight: _audioActivatedCompleter != null,
      activatedLatch: _audioSessionActivatedLatch,
    );
    switch (decision) {
      case IosCallKitAudioWaitDecision.skip:
      case IosCallKitAudioWaitDecision.alreadyReady:
        return true;
      case IosCallKitAudioWaitDecision.waitPending:
        final existing = _audioActivatedCompleter;
        if (existing == null) {
          return iosCallKitAllowMicPublish(
            isIosCalleeCallKitAnswer: true,
            activatedLatch: _audioSessionActivatedLatch,
          );
        }
        if (existing.isCompleted) {
          return iosCallKitAllowMicPublish(
            isIosCalleeCallKitAnswer: true,
            activatedLatch: _audioSessionActivatedLatch,
          );
        }
        try {
          await existing.future.timeout(timeout);
          return iosCallKitAllowMicPublish(
            isIosCalleeCallKitAnswer: true,
            activatedLatch: _audioSessionActivatedLatch,
          );
        } on TimeoutException {
          liveKitCallUiLog(
            'LiveKitVoipBridge: audioActivateTimeout (media gate)',
          );
          await _syncLatchFromNative();
          return iosCallKitAllowMicPublish(
            isIosCalleeCallKitAnswer: true,
            activatedLatch: _audioSessionActivatedLatch,
          );
        }
    }
  }

  Future<void> _syncLatchFromNative() async {
    if (!_isIos) return;
    if (_audioSessionActivatedLatch) return;
    final native =
        await IosApnsPushService.instance.isVoipAudioSessionActivated();
    if (!native) return;
    liveKitCallUiLog(
      'LiveKitVoipBridge: syncLatchFromNative — native already activated',
    );
    _onAudioSessionActivated();
  }

  Future<void> _waitAudioSessionActivated({
    Duration timeout = _audioActivateTimeout,
  }) async {
    if (!_isIos) return;
    if (_audioSessionActivatedLatch) return;
    final existing = _audioActivatedCompleter;
    if (existing == null) return;
    if (existing.isCompleted) return;
    try {
      await existing.future.timeout(timeout);
    } on TimeoutException {
      liveKitCallUiLog('LiveKitVoipBridge: audioActivateTimeout');
    }
  }

  Future<void> _restoreAudioRouteWhenReady(
    LiveKitCallSession session,
  ) async {
    await _waitAudioSessionActivated();
    if (!session.isInCall) {
      return;
    }
    // Wait until local/remote audio tracks exist — applying speaker route
    // earlier forces LiveKit to soloAmbient and callee loses remote playback.
    for (var i = 0; i < 50; i++) {
      if (session.phase == LiveKitCallPhase.connected &&
          hasLiveCallAudioTracks(session.room)) {
        break;
      }
      if (hasLiveCallAudioTracks(session.room)) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!session.isInCall) {
        return;
      }
    }
    if (session.isInCall && hasLiveCallAudioTracks(session.room)) {
      await session.ensureCallAudioRoute();
    }
  }

  void _cancelAudioWait() {
    _resetAudioGate();
  }

  void _resetAudioGate() {
    _audioSessionActivatedLatch = false;
    _callKitOwnsAudioSession = false;
    final c = _audioActivatedCompleter;
    _audioActivatedCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
  }

  Future<void> _completeAction(String uuid, bool succeeded) async {
    if (uuid.isEmpty) return;
    try {
      await IosApnsPushService.instance.completeVoipCallKitAction(
        uuid: uuid,
        succeeded: succeeded,
      );
    } catch (_) {}
  }

  /// VoIP Push 已弹出系统 CallKit 时，App 内接听/挂断需主动收口，避免系统界面残留。
  ///
  /// When [keepAudioSession] is true (LiveKit already joined), CallKit UI is
  /// dismissed without `AVAudioSession.setActive(false)` — otherwise the
  /// callee loses remote playback (caller can still hear).
  Future<void> dismissSystemCallKitForSession({
    String? callId,
    bool markHandled = true,
    bool? keepAudioSession,
  }) async {
    if (!_isIos) {
      return;
    }
    final id = callId?.trim() ?? '';
    final keepAudio = keepAudioSession ?? LiveKitCallSession.instance.isInCall;
    liveKitCallUiLog(
      'dismissSystemCallKit callId=$id keepAudio=$keepAudio '
      'inCall=${LiveKitCallSession.instance.isInCall}',
    );
    await IosApnsPushService.instance.endVoipCallKit(
      inviteId: id.isEmpty ? null : id,
      keepAudioSession: keepAudio,
    );
    if (markHandled && id.isNotEmpty) {
      await IosApnsPushService.instance.syncHandledVoipInviteId(id);
    }
  }

  /// App 内点「接听」：保持在 Flutter LiveKit UI，不创建系统 CallKit 通话。
  Future<void> acceptFromUi() async {
    final session = LiveKitCallSession.instance;
    liveKitCallUiLog(
      'acceptFromUi start role=${session.role} phase=${session.phase} '
      'callId=${session.callId} video=${session.isVideo} '
      'pageOpen=${LiveKitCallNavigator.isCallPageOpen} '
      'pageMounted=${LiveKitCallNavigator.isCallPageMounted} '
      'pageCurrent=${LiveKitCallNavigator.isCallPageCurrent}',
    );
    if (session.role != AppCallRole.callee) {
      liveKitCallUiLog('acceptFromUi abort — not callee');
      return;
    }
    if (session.phase != LiveKitCallPhase.ringingIn &&
        session.phase != LiveKitCallPhase.connecting) {
      liveKitCallUiLog('acceptFromUi abort — phase=${session.phase}');
      return;
    }
    final ctx = AppNavigator.context;
    if (ctx != null && ctx.mounted) {
      final ok = await PermissionGuard.call(ctx, video: session.isVideo);
      liveKitCallUiLog('acceptFromUi permission(ui)=$ok');
      if (!ok) {
        await session.rejectIncoming();
        await dismissSystemCallKitForSession(callId: session.callId);
        return;
      }
    } else {
      final ok = await PermissionGuard.callWithoutUi(video: session.isVideo);
      liveKitCallUiLog('acceptFromUi permission(noUi)=$ok');
      if (!ok) {
        await session.rejectIncoming();
        await dismissSystemCallKitForSession(callId: session.callId);
        return;
      }
    }
    if (!session.isInCall) {
      liveKitCallUiLog('acceptFromUi abort — left call during permission');
      return;
    }

    await LiveKitCallNavigator.ensureCallPageVisible(
      context: ctx,
      reason: 'acceptFromUi/beforeAccept',
    );

    // Keep CallKit audio session active through join; end system UI after media.
    try {
      liveKitCallUiLog('acceptFromUi → acceptIncoming');
      await session.acceptIncoming();
      liveKitCallUiLog(
        'acceptFromUi acceptIncoming done phase=${session.phase}',
      );
    } on LiveKitPublishException catch (e) {
      liveKitCallUiLog('acceptFromUi publish failed kind=${e.kind}');
      await dismissSystemCallKitForSession(callId: session.callId);
      return;
    } catch (e) {
      liveKitCallUiLog('acceptFromUi acceptIncoming error: $e');
      rethrow;
    }
    if (session.isInCall) {
      await LiveKitCallNavigator.ensureCallPageVisible(
        context: ctx,
        reason: 'acceptFromUi/afterAccept',
      );
    }
    liveKitCallUiLog('acceptFromUi → dismissSystemCallKit');
    await dismissSystemCallKitForSession(
      callId: session.callId,
      keepAudioSession: true,
    );
    if (session.isInCall) {
      await session.recoverCallAudio(tag: 'acceptFromUi/afterDismissCallKit');
      await LiveKitCallNavigator.ensureCallPageVisible(
        context: ctx,
        reason: 'acceptFromUi/afterDismissCallKit',
      );
    }
    liveKitCallUiLog(
      'acceptFromUi done phase=${session.phase} '
      'mounted=${LiveKitCallNavigator.isCallPageMounted} '
      'current=${LiveKitCallNavigator.isCallPageCurrent}',
    );
  }

  Future<void> _onAccept(String inviteId, String uuid) async {
    if (kDebugMode) {
      debugPrint('LiveKitVoipBridge: accept inviteId=$inviteId');
    }
    final session = LiveKitCallSession.instance;
    final coordinator = IncomingCallCoordinator.instance;
    if (session.phase == LiveKitCallPhase.idle ||
        session.phase == LiveKitCallPhase.ended) {
      // VoIP may arrive before IM invite; seed a minimal incoming session.
      if (inviteId.isNotEmpty) {
        await session.presentIncoming(
          callId: inviteId,
          callerUserId: coordinator.pendingCallerId(inviteId) ?? '',
          calleeUserId: coordinator.pendingCalleeId(inviteId) ?? '',
          mediaType: coordinator.pendingMediaType(inviteId) ?? 'audio',
        );
      }
    }
    final ctx = AppNavigator.context;
    final video = session.isVideo;
    if (ctx != null && ctx.mounted) {
      final ok = await PermissionGuard.call(ctx, video: video);
      if (!ok) {
        _resetAudioGate();
        await session.rejectIncoming();
        await _completeAction(uuid, false);
        await IosApnsPushService.instance.endVoipCallKit();
        return;
      }
    } else {
      final ok = await PermissionGuard.callWithoutUi(video: video);
      if (!ok) {
        _resetAudioGate();
        await session.rejectIncoming();
        await _completeAction(uuid, false);
        await IosApnsPushService.instance.endVoipCallKit();
        return;
      }
    }
    try {
      // Permission / await 间隙里用户可能已挂断：勿再推僵尸通话页。
      if (!session.isInCall) {
        _resetAudioGate();
        await _completeAction(uuid, false);
        await IosApnsPushService.instance.endVoipCallKit();
        return;
      }

      // Native Answer is already fulfilled. Do not await didActivate here —
      // UI + join stay snappy; prepare/publish gate on the latch.
      _audioActivatedCompleter = Completer<void>();
      _callKitOwnsAudioSession = true;
      if (_audioSessionActivatedLatch) {
        _audioActivatedCompleter!.complete();
      }
      await _syncLatchFromNative();
      await _completeAction(uuid, true);

      if (!session.isInCall) {
        _resetAudioGate();
        await IosApnsPushService.instance.endVoipCallKit();
        return;
      }

      // Present immediately, then join LiveKit while CallKit audio activation
      // continues independently. The callback/background fallback reapplies
      // the preferred speaker/earpiece route once audio is ready.
      liveKitCallUiLog('CallKit _onAccept → ensure+accept inviteId=$inviteId');
      unawaited(
        LiveKitCallNavigator.ensureCallPageVisible(reason: 'callKit/beforeAccept'),
      );
      unawaited(_restoreAudioRouteWhenReady(session));
      await session.acceptIncoming();
      if (LiveKitCallSession.instance.isInCall) {
        await dismissSystemCallKitForSession(
          callId: session.callId,
          keepAudioSession: true,
        );
        _callKitOwnsAudioSession = false;
        await session.recoverCallAudio(tag: 'callKit/afterDismissCallKit');
        await session.ensureLocalMicPublishedAfterCallKitActivate();
        await LiveKitCallNavigator.ensureCallPageVisible(
          reason: 'callKit/afterDismissCallKit',
        );
        liveKitCallUiLog(
          'CallKit _onAccept done phase=${session.phase} '
          'mounted=${LiveKitCallNavigator.isCallPageMounted}',
        );
      } else {
        _resetAudioGate();
        unawaited(LiveKitCallNavigator.closeCallPage());
        await IosApnsPushService.instance.endVoipCallKit();
        return;
      }
      IncomingCallCoordinator.instance.noteImCallReceived(
        inviteId: inviteId.isNotEmpty ? inviteId : session.callId,
        callerId: session.credentials?.callerUserId ?? '',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LiveKitVoipBridge: accept failed $e');
      }
      _resetAudioGate();
      unawaited(LiveKitCallNavigator.closeCallPage());
      // Answer may already be fulfilled — ending CallKit cleans UI.
      await IosApnsPushService.instance.endVoipCallKit();
    }
  }

  Future<void> _onHangup(String inviteId, String uuid) async {
    if (kDebugMode) {
      debugPrint('LiveKitVoipBridge: hangup/decline inviteId=$inviteId');
    }
    _cancelAudioWait();
    final session = LiveKitCallSession.instance;
    if (session.phase == LiveKitCallPhase.ringingIn) {
      await session.rejectIncoming();
    } else if (session.phase == LiveKitCallPhase.ringingOut) {
      await session.cancelOutgoing();
    } else if (session.isInCall) {
      await session.hangup();
    }
    await _completeAction(uuid, true);
    await IosApnsPushService.instance.endVoipCallKit();
  }
}
