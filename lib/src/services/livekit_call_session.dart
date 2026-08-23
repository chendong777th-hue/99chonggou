import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/livekit_call_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/livekit_call_credentials.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_kit_policy.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_media_helpers.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_navigator.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_ringtone.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_telemetry_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_ui_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_output_route_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

typedef LiveKitCallEndedCallback = void Function({
  required String callId,
  required AppCallMediaType mediaType,
  required AppCallEndReason reason,
  required AppCallRole role,
  required String callerUserId,
  required String calleeUserId,
  required String peerUserId,
  required String operatorUserId,
  required double totalTimeSec,
  required bool isOutgoing,
});

/// Single active LiveKit C2C call session.
class LiveKitCallSession extends ChangeNotifier {
  LiveKitCallSession._();

  static final LiveKitCallSession instance = LiveKitCallSession._();

  final LiveKitCallApi _api = LiveKitCallApi.instance;

  LiveKitCallPhase _phase = LiveKitCallPhase.idle;
  LiveKitCallCredentials? _creds;
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  AppCallRole _role = AppCallRole.none;
  AppCallEndReason? _pendingEndReason;
  DateTime? _connectedAt;
  Timer? _ringTimeout;
  bool _finalizing = false;
  /// True while this device is accepting as callee (ignore answered_elsewhere echo).
  bool _localAcceptInFlight = false;
  /// Bumped on every finalize so in-flight connect/publish can abort.
  int _sessionGen = 0;
  bool _micEnabled = true;
  bool _camEnabled = false;
  bool _speakerOn = true;
  bool _voiceAudioSessionConfigured = false;
  int _lastVoiceRouteApplyMs = 0;
  CameraPosition _cameraPosition = CameraPosition.front;
  bool _switchingCamera = false;
  List<String>? _cachedCameraIds;
  Timer? _tokenRefreshTimer;
  int _tokenRecoverAttempts = 0;
  LiveKitCallTelemetryRecorder? _telemetry;

  static const int _maxTokenRecoverAttempts = 1;
  static const Duration _tokenRefreshLeadTime = Duration(seconds: 90);

  LiveKitCallEndedCallback? onCallEnded;

  LiveKitCallPhase get phase => _phase;
  LiveKitCallCredentials? get credentials => _creds;
  Room? get room => _room;
  AppCallRole get role => _role;
  bool get isBusy => _phase != LiveKitCallPhase.idle && _phase != LiveKitCallPhase.ended;
  bool get isInCall =>
      _phase == LiveKitCallPhase.ringingOut ||
      _phase == LiveKitCallPhase.ringingIn ||
      _phase == LiveKitCallPhase.connecting ||
      _phase == LiveKitCallPhase.connected;
  bool get micEnabled => _micEnabled;
  bool get camEnabled => _camEnabled;
  bool get speakerOn => _speakerOn;
  bool get isVideo => _creds?.isVideo == true;
  DateTime? get connectedAt => _connectedAt;

  String get callId => _creds?.callId ?? '';
  String get peerUserId {
    final self = _selfUserId();
    final caller = CallUserId.normalizeCallUserId(_creds?.callerUserId ?? '');
    final callee = CallUserId.normalizeCallUserId(_creds?.calleeUserId ?? '');
    if (_role == AppCallRole.caller) return callee;
    if (_role == AppCallRole.callee) return caller;
    if (self.isNotEmpty && caller == self) return callee;
    return caller;
  }

  VideoTrack? get localVideoTrack {
    final pubs = _room?.localParticipant?.videoTrackPublications;
    if (pubs == null || pubs.isEmpty) return null;
    final track = pubs.first.track;
    return track is VideoTrack ? track : null;
  }

  VideoTrack? get remoteVideoTrack {
    final remotes = _room?.remoteParticipants.values;
    if (remotes == null) return null;
    for (final participant in remotes) {
      for (final pub in participant.videoTrackPublications) {
        final track = pub.track;
        if (track is VideoTrack) return track;
      }
    }
    return null;
  }

  /// Prepare outgoing ringing UI state without waiting for LiveKit connect.
  Future<void> prepareOutgoing(LiveKitCallCredentials creds) async {
    if (isBusy) {
      throw LiveKitCallApiException('BUSY', '当前已有通话');
    }
    _resetState();
    _creds = creds;
    _role = AppCallRole.caller;
    _phase = LiveKitCallPhase.ringingOut;
    _speakerOn = creds.isVideo;
    notifyListeners();
    _armRingTimeout(creds.timeoutSec);
  }

  /// Local outgoing ringing UI before [LiveKitCallApi.invite] returns.
  ///
  /// Mirrors [presentIncoming]: show the call page immediately; bind real
  /// credentials later. Empty callId/url/token until [bindOutgoingCredentials].
  Future<void> prepareOutgoingPending({
    required String calleeUserId,
    required bool video,
  }) async {
    if (isBusy) {
      throw LiveKitCallApiException('BUSY', '当前已有通话');
    }
    _resetState();
    _creds = LiveKitCallCredentials(
      callId: '',
      roomName: '',
      url: '',
      token: '',
      mediaType: video ? 'video' : 'audio',
      // caller filled by invite response in [bindOutgoingCredentials]
      callerUserId: '',
      calleeUserId: CallUserId.normalizeCallUserId(calleeUserId),
      timeoutSec: 60,
    );
    _role = AppCallRole.caller;
    _phase = LiveKitCallPhase.ringingOut;
    _speakerOn = video;
    notifyListeners();
    _armRingTimeout(60);
  }

  /// Apply invite credentials onto a pending outgoing session.
  ///
  /// Returns `false` if the user already canceled / session ended while
  /// invite was in flight — caller should cancel the remote call.
  bool bindOutgoingCredentials(LiveKitCallCredentials creds) {
    if (_role != AppCallRole.caller) return false;
    if (_phase != LiveKitCallPhase.ringingOut &&
        _phase != LiveKitCallPhase.connecting) {
      return false;
    }
    _creds = creds;
    _armRingTimeout(creds.timeoutSec);
    _ensureTelemetryRecorder(creds);
    notifyListeners();
    return true;
  }

  /// Connect media for the prepared session. On failure, ends the session.
  Future<void> connectMedia() async {
    final creds = _creds;
    if (creds == null) {
      throw LiveKitCallApiException('INVALID_STATE', '通话未准备');
    }
    if (_phase != LiveKitCallPhase.ringingOut &&
        _phase != LiveKitCallPhase.ringingIn &&
        _phase != LiveKitCallPhase.connecting) {
      throw LiveKitCallApiException('INVALID_STATE', '通话状态无效');
    }
    try {
      await _telemetry?.capturePermissions(video: isVideo);
      await _connectAndPublish(creds);
    } on LiveKitPublishException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'LiveKitCallSession: connectMedia publish failed kind=${e.kind}',
        );
      }
      ToastUtils.toast(liveKitPublishFailureMessage(e.kind));
      if (_phase != LiveKitCallPhase.idle && _phase != LiveKitCallPhase.ended) {
        await _finalizePublishFailure();
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LiveKitCallSession: connectMedia failed: $e');
      }
      if (_phase != LiveKitCallPhase.idle && _phase != LiveKitCallPhase.ended) {
        await _finalize(
          reason: AppCallEndReason.unknown,
          operatorIsSelf: true,
        );
      }
      rethrow;
    }
  }

  Future<void> startOutgoing(LiveKitCallCredentials creds) async {
    await prepareOutgoing(creds);
    await connectMedia();
  }

  Future<void> presentIncoming({
    required String callId,
    required String callerUserId,
    required String calleeUserId,
    required String mediaType,
    String roomName = '',
    int timeoutSec = 60,
  }) async {
    if (isBusy && callId.trim() != this.callId) {
      return;
    }
    if (_phase == LiveKitCallPhase.ringingIn && this.callId == callId.trim()) {
      _mergeIncomingPresentation(
        callerUserId: callerUserId,
        calleeUserId: calleeUserId,
        mediaType: mediaType,
        roomName: roomName,
        timeoutSec: timeoutSec,
      );
      return;
    }
    _resetState();
    _creds = LiveKitCallCredentials(
      callId: callId.trim(),
      roomName: roomName,
      url: '',
      token: '',
      mediaType: mediaType,
      callerUserId: callerUserId,
      calleeUserId: calleeUserId,
      timeoutSec: timeoutSec,
    );
    _role = AppCallRole.callee;
    _phase = LiveKitCallPhase.ringingIn;
    _speakerOn = _creds?.isVideo == true;
    notifyListeners();
    _armRingTimeout(timeoutSec);
    _ensureTelemetryRecorder(_creds!);
  }

  void _mergeIncomingPresentation({
    required String callerUserId,
    required String calleeUserId,
    required String mediaType,
    required String roomName,
    required int timeoutSec,
  }) {
    final existing = _creds;
    if (existing == null) {
      return;
    }
    final nextMedia = mediaType.trim().isNotEmpty
        ? mediaType.trim().toLowerCase()
        : existing.mediaType;
    final nextCaller = callerUserId.trim().isNotEmpty
        ? callerUserId.trim()
        : existing.callerUserId;
    final nextCallee = calleeUserId.trim().isNotEmpty
        ? calleeUserId.trim()
        : existing.calleeUserId;
    final nextRoom = roomName.trim().isNotEmpty ? roomName.trim() : existing.roomName;
    if (nextMedia == existing.mediaType &&
        nextCaller == existing.callerUserId &&
        nextCallee == existing.calleeUserId &&
        nextRoom == existing.roomName &&
        timeoutSec == existing.timeoutSec) {
      return;
    }
    _creds = LiveKitCallCredentials(
      callId: existing.callId,
      roomName: nextRoom,
      url: existing.url,
      token: existing.token,
      mediaType: nextMedia,
      callerUserId: nextCaller,
      calleeUserId: nextCallee,
      expiresAt: existing.expiresAt,
      timeoutSec: timeoutSec,
    );
    _ensureTelemetryRecorder(_creds!);
    notifyListeners();
  }

  Future<void> acceptIncoming() async {
    final id = callId;
    liveKitCallUiLog(
      'acceptIncoming start callId=$id role=$_role phase=$_phase gen=$_sessionGen',
    );
    if (id.isEmpty || _role != AppCallRole.callee) {
      liveKitCallUiLog('acceptIncoming abort — empty id or not callee');
      return;
    }
    if (_phase == LiveKitCallPhase.connecting ||
        _phase == LiveKitCallPhase.connected) {
      liveKitCallUiLog('acceptIncoming noop — already $_phase');
      return;
    }
    final gen = _sessionGen;
    _localAcceptInFlight = true;
    _phase = LiveKitCallPhase.connecting;
    notifyListeners();
    try {
      await _telemetry?.capturePermissions(video: isVideo);
      if (!_acceptStillValid(gen: gen, callId: id)) {
        liveKitCallUiLog(
          'acceptIncoming aborted before credentials — session changed '
          'gen=$gen→$_sessionGen role=$_role phase=$_phase',
        );
        return;
      }
      final creds = await resolveAcceptCredentials(callId: id);
      if (!_acceptStillValid(gen: gen, callId: id)) {
        liveKitCallUiLog(
          'acceptIncoming aborted after credentials — session changed '
          'gen=$gen→$_sessionGen role=$_role phase=$_phase',
        );
        return;
      }
      _creds = creds;
      liveKitCallUiLog(
        'acceptIncoming credentials ok room=${creds.roomName} '
        'video=${creds.isVideo}',
      );
      await _connectAndPublish(creds);
      liveKitCallUiLog('acceptIncoming connectPublish done phase=$_phase');
    } on LiveKitPublishException catch (e) {
      liveKitCallUiLog('acceptIncoming publish failed kind=${e.kind}');
      if (kDebugMode) {
        debugPrint(
          'LiveKitCallSession: acceptIncoming publish failed kind=${e.kind}',
        );
      }
      ToastUtils.toast(liveKitPublishFailureMessage(e.kind));
      if (_phase != LiveKitCallPhase.idle && _phase != LiveKitCallPhase.ended) {
        await _finalizePublishFailure();
      }
      rethrow;
    } catch (e) {
      liveKitCallUiLog('acceptIncoming failed: $e');
      if (kDebugMode) {
        debugPrint('LiveKitCallSession: acceptIncoming failed: $e');
      }
      if (_phase != LiveKitCallPhase.idle && _phase != LiveKitCallPhase.ended) {
        await _finalize(
          reason: AppCallEndReason.unknown,
          operatorIsSelf: true,
        );
      }
      rethrow;
    } finally {
      _localAcceptInFlight = false;
    }
  }

  bool _acceptStillValid({required int gen, required String callId}) {
    return !_finalizing &&
        _sessionGen == gen &&
        _role == AppCallRole.callee &&
        this.callId == callId &&
        (_phase == LiveKitCallPhase.connecting ||
            _phase == LiveKitCallPhase.connected);
  }

  Future<void> rejectIncoming() async {
    final id = callId;
    _pendingEndReason = AppCallEndReason.reject;
    // End local UI/media immediately; REST is best-effort and must not block.
    if (id.isNotEmpty) {
      unawaited(_api.reject(callId: id).catchError((_) {}));
    }
    await _finalize(reason: AppCallEndReason.reject, operatorIsSelf: true);
  }

  Future<void> cancelOutgoing() async {
    final id = callId;
    _pendingEndReason = AppCallEndReason.canceled;
    if (id.isNotEmpty) {
      unawaited(_api.cancel(callId: id).catchError((_) {}));
    }
    await _finalize(reason: AppCallEndReason.canceled, operatorIsSelf: true);
  }

  Future<void> hangup() async {
    final id = callId;
    _pendingEndReason = AppCallEndReason.hangup;
    if (id.isNotEmpty) {
      try {
        await _api
            .hangup(callId: id)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    await _finalize(reason: AppCallEndReason.hangup, operatorIsSelf: true);
  }

  Future<void> handleRemoteAction(String action) async {
    final normalized = action.trim().toLowerCase();
    liveKitCallUiLog(
      'handleRemoteAction action=$normalized phase=$_phase role=$_role '
      'localAccept=$_localAcceptInFlight callId=$callId',
    );
    switch (normalized) {
      case 'accept':
        // Caller waiting for peer: mark connected. Callee already drives
        // connecting→connected via acceptIncoming / connectPublish.
        if (_role == AppCallRole.callee) {
          liveKitCallUiLog('handleRemoteAction accept ignored — local callee');
          break;
        }
        if (_phase == LiveKitCallPhase.ringingOut ||
            _phase == LiveKitCallPhase.connecting) {
          _phase = LiveKitCallPhase.connected;
          _connectedAt ??= DateTime.now();
          _ringTimeout?.cancel();
          notifyListeners();
          liveKitCallUiLog(
            'remoteAccept audioRecv role=$_role speakerOn=$_speakerOn '
            '${describeCallAudioState(_room)}',
          );
          unawaited(_ensureCallAudioRoute());
          unawaited(ensureRemoteAudioSubscribed(_room, tag: 'remoteAccept'));
          _scheduleRemoteAudioRecovery('remoteAccept');
          final creds = _creds;
          if (creds != null) {
            _armTokenRefresh(creds);
          }
          unawaited(
            LiveKitCallNavigator.ensureCallPageVisible(reason: 'remoteAccept'),
          );
        }
        break;
      case 'reject':
        await _finalize(
          reason: AppCallEndReason.reject,
          operatorIsSelf: false,
        );
        break;
      case 'cancel':
        await _finalize(
          reason: AppCallEndReason.canceled,
          operatorIsSelf: false,
        );
        break;
      case 'hangup':
        await _finalize(
          reason: AppCallEndReason.hangup,
          operatorIsSelf: false,
        );
        break;
      case 'answered_elsewhere':
        // Server often echoes this to the device that just accepted. Ignore
        // while we are the accepting callee, otherwise the page is torn down
        // while acceptIncoming continues and creates a zombie connected call.
        if (_localAcceptInFlight ||
            (_role == AppCallRole.callee &&
                _phase == LiveKitCallPhase.connecting)) {
          liveKitCallUiLog(
            'handleRemoteAction answered_elsewhere ignored — local accept',
          );
          break;
        }
        // 已接通：忽略。振铃中：其它设备已接，立即收口。
        if (_phase == LiveKitCallPhase.connected) {
          break;
        }
        if (_phase == LiveKitCallPhase.ringingIn ||
            _phase == LiveKitCallPhase.ringingOut) {
          unawaited(LiveKitCallRingtone.instance.stop());
          await _finalize(
            reason: AppCallEndReason.otherDeviceAccepted,
            operatorIsSelf: false,
          );
        }
        break;
    }
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (enabled) {
      final pub = await _room?.localParticipant?.setMicrophoneEnabled(true);
      if (pub == null || pub.track == null) {
        _micEnabled = false;
        notifyListeners();
        ToastUtils.toast(liveKitPublishFailureMessage('mic'));
        if (_phase != LiveKitCallPhase.idle && _phase != LiveKitCallPhase.ended) {
          await _finalizePublishFailure();
        }
        return;
      }
      _micEnabled = true;
    } else {
      _micEnabled = false;
      await _room?.localParticipant?.setMicrophoneEnabled(false);
    }
    notifyListeners();
  }

  Future<void> setCameraEnabled(bool enabled) async {
    _camEnabled = enabled;
    await _room?.localParticipant?.setCameraEnabled(enabled);
    notifyListeners();
  }

  Future<void> setSpeakerphoneOn(bool enabled) async {
    _speakerOn = enabled;
    liveKitCallUiLog(
      'setSpeakerphoneOn enabled=$enabled role=$_role phase=$_phase '
      '${describeCallAudioState(_room)}',
    );
    try {
      await Hardware.instance.setSpeakerphoneOn(
        enabled,
        forceSpeakerOutput: enabled,
      );
    } catch (e, st) {
      liveKitCallUiLog('setSpeakerphoneOn failed enabled=$enabled error=$e');
      if (kDebugMode) {
        debugPrint('LiveKitCallSession: setSpeakerphoneOn($enabled) failed: $e\n$st');
      }
    }
    notifyListeners();
  }

  /// Stop ringtone and re-apply LiveKit speaker route after media is live.
  Future<void> ensureCallAudioRoute() => _ensureCallAudioRoute();

  /// Publish (or republish) local mic after CallKit `didActivate`.
  ///
  /// Must not treat a transient miss as [LiveKitPublishException] / hangup.
  Future<void> ensureLocalMicPublishedAfterCallKitActivate() async {
    if (_finalizing || _room == null || !isInCall) {
      liveKitCallUiLog(
        'ensureLocalMicPublishedAfterCallKitActivate skip phase=$_phase',
      );
      return;
    }
    final local = _room!.localParticipant;
    if (local == null) {
      liveKitCallUiLog(
        'ensureLocalMicPublishedAfterCallKitActivate skip — no localParticipant',
      );
      return;
    }
    if (_localMicPublishedUnmuted()) {
      await recoverCallAudio(tag: 'callKitDidActivate');
      return;
    }
    liveKitCallUiLog(
      'ensureLocalMicPublishedAfterCallKitActivate retry '
      '${describeCallAudioState(_room)}',
    );
    try {
      var micPub = await local.setMicrophoneEnabled(true);
      if (micPub == null || micPub.track == null) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (_finalizing || _room == null || !isInCall) {
          return;
        }
        micPub = await local.setMicrophoneEnabled(true);
      }
      if (micPub == null || micPub.track == null) {
        liveKitCallUiLog(
          'ensureLocalMicPublishedAfterCallKitActivate mic still missing',
        );
      } else {
        _micEnabled = true;
        if (_creds?.isVideo == true && !_camEnabled) {
          try {
            final camPub = await local.setCameraEnabled(true);
            if (camPub != null && camPub.track != null) {
              _camEnabled = true;
              _cameraPosition = CameraPosition.front;
            }
          } catch (e) {
            liveKitCallUiLog(
              'ensureLocalMicPublishedAfterCallKitActivate camera retry failed '
              'error=$e',
            );
          }
        }
        notifyListeners();
      }
    } catch (e) {
      liveKitCallUiLog(
        'ensureLocalMicPublishedAfterCallKitActivate mic retry failed error=$e',
      );
    }
    await recoverCallAudio(tag: 'callKitDidActivate');
  }

  bool _localMicPublishedUnmuted() {
    for (final pub in _room?.localParticipant?.audioTrackPublications ?? const []) {
      if (pub.track != null && !pub.muted) {
        return true;
      }
    }
    return false;
  }

  /// Re-subscribe remote audio + re-apply iOS route after CallKit handoff.
  Future<void> recoverCallAudio({String tag = 'recover'}) async {
    if (_finalizing || _room == null || !isInCall) {
      liveKitCallUiLog('recoverCallAudio skip tag=$tag phase=$_phase');
      return;
    }
    liveKitCallUiLog(
      'recoverCallAudio begin tag=$tag role=$_role speakerOn=$_speakerOn '
      '${describeCallAudioState(_room)}',
    );
    await ensureRemoteAudioSubscribed(_room, tag: tag);
    await ensureRemoteAudioPlayback(_room, tag: tag);
    await _ensureCallAudioRoute();
    _scheduleRemoteAudioRecovery('$tag-sched');
    liveKitCallUiLog(
      'recoverCallAudio done tag=$tag role=$_role '
      '${describeCallAudioState(_room)}',
    );
  }

  Future<void> _ensureCallAudioRoute() async {
    if (_room == null || _finalizing) return;
    await LiveKitCallRingtone.instance.stop();
    // CallKit still owns playAndRecord — LiveKit speaker reconfig kills capture.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        !iosCallKitShouldApplyLiveKitSpeakerRoute(
          callKitOwnsAudioSession: iosCallKitOwnsAudioSession?.call() ?? false,
        )) {
      liveKitCallUiLog(
        '_ensureCallAudioRoute skip — CallKit owns audio session '
        'role=$_role ${describeCallAudioState(_room)}',
      );
      return;
    }
    // On iOS, setSpeakerphoneOn reconfigures AVAudioSession from LiveKit's
    // track counters. Before any track is live that becomes soloAmbient and
    // breaks CallKit playback (callee cannot hear remote audio).
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        !hasLiveCallAudioTracks(_room)) {
      liveKitCallUiLog(
        '_ensureCallAudioRoute skip — no live audio tracks yet '
        'role=$_role ${describeCallAudioState(_room)}',
      );
      return;
    }
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Track/recovery events can arrive in bursts. Reapplying the native
      // route for every event tears down and recreates iOS's audio graph,
      // which causes intermittent two-way silence even when both tracks are
      // already subscribed. Keep the first apply and suppress only the
      // duplicate burst; a later CallKit handoff can still reapply it.
      if (now - _lastVoiceRouteApplyMs < 800) {
        liveKitCallUiLog(
          '_ensureCallAudioRoute coalesced speakerOn=$_speakerOn '
          'role=$_role ${describeCallAudioState(_room)}',
        );
        return;
      }
      _lastVoiceRouteApplyMs = now;
      liveKitCallUiLog(
        '_ensureCallAudioRoute apply speakerOn=$_speakerOn '
        'video=$isVideo role=$_role ${describeCallAudioState(_room)}',
      );
      // 回铃音使用 media/playback 会话，CallKit 接听又可能暂时持有
      // playAndRecord。音轨已经就绪后必须在这里完成一次确定性的交接，
      // 否则会出现「TrackSubscribed/started=1 但双方都无声」的偶发状态。
      if (!_voiceAudioSessionConfigured) {
        await VoiceOutputRouteService.applyCurrentRoute(
          configureSession: true,
          forRecording: true,
          activate: true,
        );
        _voiceAudioSessionConfigured = true;
      } else {
        await VoiceOutputRouteService.applyCurrentRoute(activate: true);
      }
      await Hardware.instance.setSpeakerphoneOn(
        _speakerOn,
        forceSpeakerOutput: _speakerOn,
      );
    } catch (e, st) {
      liveKitCallUiLog('_ensureCallAudioRoute failed: $e');
      if (kDebugMode) {
        debugPrint('LiveKitCallSession: _ensureCallAudioRoute failed: $e\n$st');
      }
    }
  }

  void _logAudioSnapshot(String tag) {
    liveKitCallUiLog(
      'audioRecv[$tag] callId=$callId role=$_role phase=$_phase '
      'speakerOn=$_speakerOn ${describeCallAudioState(_room)}',
    );
    if (!kDebugMode) {
      return;
    }
    logLocalTrackPublications(_room, tag: tag);
    final remotes = _room?.remoteParticipants.values;
    if (remotes == null) {
      return;
    }
    for (final remote in remotes) {
      logRemoteAudioPublications(remote, tag: tag);
    }
  }

  void _scheduleRemoteAudioRecovery(String tag) {
    if (_finalizing) return;
    unawaited(
      scheduleRemoteAudioRecovery(
        _room,
        tag: tag,
        onAudioReady: _ensureCallAudioRoute,
      ),
    );
  }

  Future<void> switchCamera() async {
    if (_switchingCamera || !_camEnabled) return;
    final track = localVideoTrack;
    if (track is! LocalVideoTrack) return;
    _switchingCamera = true;
    final nextPos = _cameraPosition.switched();
    try {
      // iOS/Android often report empty/mismatched deviceId — don't rely on it
      // alone or the first tap keeps selecting the already-active camera.
      final cameras = await _videoInputIds();
      if (cameras.length >= 2) {
        final options = track.currentOptions;
        final currentId =
            options is CameraCaptureOptions ? (options.deviceId ?? '') : '';
        var index = currentId.isEmpty ? -1 : cameras.indexOf(currentId);
        if (index < 0) {
          index = _cameraPosition == CameraPosition.front ? 0 : 1;
          if (index >= cameras.length) index = 0;
        }
        final nextId = cameras[(index + 1) % cameras.length];
        // fastSwitch uses native Helper.switchCamera — no track restart.
        await track.switchCamera(nextId, fastSwitch: true);
        _cameraPosition = nextPos;
        return;
      }
      await track.setCameraPosition(nextPos);
      _cameraPosition = nextPos;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('LiveKitCallSession: switchCamera failed: $e\n$st');
      }
      try {
        await track.setCameraPosition(nextPos);
        _cameraPosition = nextPos;
      } catch (_) {}
    } finally {
      _switchingCamera = false;
      notifyListeners();
    }
  }

  Future<List<String>> _videoInputIds() async {
    final cached = _cachedCameraIds;
    if (cached != null && cached.length >= 2) return cached;
    final devices = await Hardware.instance.enumerateDevices();
    final ids = devices
        .where((d) => d.kind == 'videoinput')
        .map((d) => d.deviceId)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    _cachedCameraIds = ids;
    return ids;
  }

  Future<void> _connectAndPublish(LiveKitCallCredentials creds) async {
    final gen = _sessionGen;
    _phase = LiveKitCallPhase.connecting;
    notifyListeners();
    _ensureTelemetryRecorder(creds);
    _telemetry?.markConnectStarted();
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    _room = room;
    final listener = room.createListener();
    _roomListener = listener;
    listener
      ..on<RoomReconnectingEvent>((_) {
        if (_finalizing || _sessionGen != gen) return;
        liveKitCallUiLog('room reconnecting callId=$callId role=$_role');
      })
      ..on<RoomReconnectedEvent>((_) {
        if (_finalizing || _sessionGen != gen) return;
        liveKitCallUiLog(
          'room reconnected callId=$callId role=$_role '
          '${describeCallAudioState(_room)}',
        );
        unawaited(ensureRemoteAudioSubscribed(_room, tag: 'RoomReconnected'));
        _scheduleRemoteAudioRecovery('RoomReconnected');
        notifyListeners();
      })
      ..on<ParticipantConnectedEvent>((event) {
        if (_finalizing || _sessionGen != gen) return;
        liveKitCallUiLog(
          'ParticipantConnected identity=${event.participant.identity} '
          'role=$_role ${describeCallAudioState(_room)}',
        );
        _scheduleRemoteAudioRecovery('ParticipantConnected');
        _logAudioSnapshot('ParticipantConnected');
        notifyListeners();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        if (_finalizing || _sessionGen != gen) return;
        unawaited(
          _finalize(
            reason: AppCallEndReason.hangup,
            operatorIsSelf: false,
          ),
        );
      })
      ..on<RoomDisconnectedEvent>((event) {
        if (_finalizing || _sessionGen != gen) return;
        if (event.reason == DisconnectReason.duplicateIdentity) {
          _telemetry?.markDuplicateIdentity();
        }
        if (_maybeRecoverFromDisconnect(event.reason)) {
          return;
        }
        final mapped = disconnectReasonToEndReason(event.reason);
        unawaited(
          _finalize(
            reason: mapped ??
                _pendingEndReason ??
                AppCallEndReason.hangup,
            operatorIsSelf: false,
          ),
        );
      })
      ..on<TrackPublishedEvent>((event) {
        if (_finalizing || _sessionGen != gen) return;
        liveKitCallUiLog(
          'TrackPublished identity=${event.participant.identity} '
          'kind=${event.publication.kind} source=${event.publication.source} '
          'sub=${event.publication.subscribed} muted=${event.publication.muted} '
          'role=$_role ${describeCallAudioState(_room)}',
        );
        if (event.publication.kind == TrackType.AUDIO ||
            event.publication.kind == TrackType.VIDEO) {
          _scheduleRemoteAudioRecovery('TrackPublished');
        }
        _logAudioSnapshot('TrackPublished');
        notifyListeners();
      })
      ..on<TrackSubscribedEvent>((event) {
        if (_finalizing || _sessionGen != gen) return;
        liveKitCallUiLog(
          'TrackSubscribed identity=${event.participant.identity} '
          'kind=${event.track.kind} source=${event.publication.source} '
          'muted=${event.publication.muted} role=$_role '
          '${describeCallAudioState(_room)}',
        );
        if (event.track.kind == TrackType.AUDIO) {
          unawaited(_ensureCallAudioRoute());
          _scheduleRemoteAudioRecovery('TrackSubscribedAudio');
        }
        if (event.track.kind == TrackType.VIDEO) {
          notifyListeners();
        }
        _logAudioSnapshot('TrackSubscribed');
        notifyListeners();
      })
      ..on<LocalTrackPublishedEvent>((_) {
        if (_sessionGen == gen) notifyListeners();
      });

    await LiveKitCallRingtone.instance.stop();
    await prepareIosCallKitMediaJoin(
      video: creds.isVideo,
      isCallee: _role == AppCallRole.callee,
    );
    try {
      await room.connect(creds.url, creds.token);
    } catch (e) {
      if (_sessionGen != gen || _finalizing) return;
      _telemetry?.setError(e.toString());
      rethrow;
    }
    if (_sessionGen != gen || _finalizing) {
      // Hangup raced connect — drop this room; finalize already owns UI.
      unawaited(_teardownMedia(room, listener));
      return;
    }
    _telemetry?.markConnectFinished();

    try {
      final published = await publishLocalCallTracks(
        room: room,
        video: creds.isVideo,
      );
      _telemetry?.markPublishFinished(ok: published);
      if (!published) {
        liveKitCallUiLog(
          'connectPublish deferred local tracks '
          '${describeCallAudioState(room)}',
        );
      }
      logLocalTrackPublications(room, tag: 'publishLocalCallTracks');
    } on LiveKitPublishException catch (e) {
      _telemetry
        ?..markPublishFinished(ok: false)
        ..setError(e.toString());
      if (_sessionGen != gen || _finalizing) {
        unawaited(_teardownMedia(room, listener));
      }
      rethrow;
    }
    if (_sessionGen != gen || _finalizing) {
      unawaited(_teardownMedia(room, listener));
      return;
    }
    _micEnabled = countLocalAudioTracks(room) > 0;
    if (creds.isVideo && _micEnabled) {
      _camEnabled = true;
      _cameraPosition = CameraPosition.front;
      // Warm device list so the first flip doesn't wait on enumerateDevices.
      unawaited(_videoInputIds());
    }
    await ensureRemoteAudioSubscribed(room, tag: 'connectPublishDone');
    await ensureRemoteVideoSubscribed(room, tag: 'connectPublishDone');
    await ensureRemoteAudioPlayback(room, tag: 'connectPublishDone');
    await _ensureCallAudioRoute();

    if (_sessionGen != gen || _finalizing) {
      unawaited(_teardownMedia(room, listener));
      return;
    }

    if (_role == AppCallRole.caller) {
      // Wait for remote accept signal / participant join.
      if (_phase == LiveKitCallPhase.connecting) {
        _phase = LiveKitCallPhase.ringingOut;
      }
    } else if (_role == AppCallRole.callee) {
      _phase = LiveKitCallPhase.connected;
      _connectedAt = DateTime.now();
      _ringTimeout?.cancel();
      await _ensureCallAudioRoute();
      // Caller may already be publishing; retry subscribe/start after join.
      unawaited(recoverCallAudio(tag: 'connectPublishDone/callee'));
    } else {
      liveKitCallUiLog(
        'connectPublishDone abort — unexpected role=$_role gen=$gen',
      );
      unawaited(_teardownMedia(room, listener));
      return;
    }
    _armTokenRefresh(creds);
    _logAudioSnapshot('connectPublishDone');
    notifyListeners();
    if (_phase == LiveKitCallPhase.connected) {
      unawaited(
        LiveKitCallNavigator.ensureCallPageVisible(
          reason: 'connectPublishDone',
        ),
      );
    }
  }

  Future<void> _finalizePublishFailure() async {
    _pendingEndReason = AppCallEndReason.unknown;
    final id = callId;
    if (id.isNotEmpty) {
      unawaited(_api.hangup(callId: id).catchError((_) {}));
    }
    await _finalize(reason: AppCallEndReason.unknown, operatorIsSelf: true);
  }

  void _ensureTelemetryRecorder(LiveKitCallCredentials creds) {
    final id = creds.callId.trim();
    if (id.isEmpty) {
      return;
    }
    final existing = _telemetry;
    if (existing != null && existing.callId == id) {
      return;
    }
    _telemetry = LiveKitCallTelemetryService.instance.start(
      callId: id,
      role: _role,
      mediaType: appCallMediaTypeFromString(creds.mediaType),
    );
  }

  void _armTokenRefresh(LiveKitCallCredentials creds) {
    _tokenRefreshTimer?.cancel();
    if (creds.expiresAt <= 0) {
      return;
    }
    final refreshAt = DateTime.fromMillisecondsSinceEpoch(
      creds.expiresAt * 1000,
    ).subtract(_tokenRefreshLeadTime);
    final delay = refreshAt.difference(DateTime.now());
    if (!delay.isNegative && delay > Duration.zero) {
      _tokenRefreshTimer = Timer(delay, () {
        unawaited(_refreshRoomTokenIfConnected());
      });
      return;
    }
    unawaited(_refreshRoomTokenIfConnected());
  }

  bool _maybeRecoverFromDisconnect(DisconnectReason? reason) {
    if (_phase != LiveKitCallPhase.connected || callId.isEmpty) {
      return false;
    }
    if (_tokenRecoverAttempts >= _maxTokenRecoverAttempts) {
      return false;
    }
    if (!_isRecoverableDisconnect(reason)) {
      return false;
    }
    _tokenRecoverAttempts++;
    unawaited(_recoverRoomConnection());
    return true;
  }

  bool _isRecoverableDisconnect(DisconnectReason? reason) {
    return reason == DisconnectReason.reconnectAttemptsExceeded ||
        reason == DisconnectReason.joinFailure ||
        reason == DisconnectReason.signalingConnectionFailure ||
        reason == DisconnectReason.disconnected;
  }

  Future<void> _refreshRoomTokenIfConnected() async {
    if (_finalizing || _phase != LiveKitCallPhase.connected) {
      return;
    }
    final id = callId;
    if (id.isEmpty) {
      return;
    }
    try {
      final creds = await _api.fetchToken(callId: id);
      _creds = creds;
      _armTokenRefresh(creds);
      await _reconnectRoomWithCredentials(creds);
    } catch (e, st) {
      _telemetry?.setError('tokenRefresh: $e');
      if (kDebugMode) {
        debugPrint('LiveKitCallSession: token refresh failed $e\n$st');
      }
    }
  }

  Future<void> _recoverRoomConnection() async {
    final creds = _creds;
    if (creds == null || creds.callId.isEmpty) {
      return;
    }
    try {
      final fresh = await _api.fetchToken(callId: creds.callId);
      _creds = fresh;
      _armTokenRefresh(fresh);
      await _reconnectRoomWithCredentials(fresh);
    } catch (e, st) {
      _telemetry?.setError('recover: $e');
      if (kDebugMode) {
        debugPrint('LiveKitCallSession: recover connection failed $e\n$st');
      }
      if (!_finalizing && _phase == LiveKitCallPhase.connected) {
        await _finalize(
          reason: AppCallEndReason.unknown,
          operatorIsSelf: false,
        );
      }
    }
  }

  Future<void> _reconnectRoomWithCredentials(
    LiveKitCallCredentials creds,
  ) async {
    final room = _room;
    if (room == null || _finalizing) {
      return;
    }
    final gen = _sessionGen;
    final mic = _micEnabled;
    final cam = _camEnabled;
    final video = creds.isVideo;
    try {
      await room.disconnect();
    } catch (_) {}
    if (_sessionGen != gen || _finalizing) {
      return;
    }
    _telemetry?.markConnectStarted();
    await room.connect(creds.url, creds.token);
    if (_sessionGen != gen || _finalizing) {
      return;
    }
    _telemetry?.markConnectFinished();
    if (mic) {
      await publishLocalCallTracks(room: room, video: video && cam);
      _telemetry?.markPublishFinished(ok: true);
    }
    await ensureRemoteAudioSubscribed(room, tag: 'reconnect');
    await ensureRemoteVideoSubscribed(room, tag: 'reconnect');
    await _ensureCallAudioRoute();
    if (_sessionGen == gen && !_finalizing) {
      notifyListeners();
    }
  }

  void _reportTelemetry({
    required Room? room,
    required AppCallEndReason reason,
    required double durationSec,
  }) {
    final recorder = _telemetry;
    if (recorder == null) {
      return;
    }
    final payload = recorder.build(
      room: room,
      endReason: reason,
      durationSec: durationSec,
    );
    LiveKitCallTelemetryService.instance.clearActive(recorder);
    _telemetry = null;
    unawaited(LiveKitCallTelemetryService.instance.report(payload));
  }

  Future<void> _teardownMedia(
    Room? room,
    EventsListener<RoomEvent>? listener,
  ) async {
    try {
      await listener?.dispose().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await room?.disconnect().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await room?.dispose().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  void _armRingTimeout(int timeoutSec) {
    _ringTimeout?.cancel();
    final sec = timeoutSec > 0 ? timeoutSec : 60;
    _ringTimeout = Timer(Duration(seconds: sec), () {
      if (_phase == LiveKitCallPhase.ringingOut) {
        unawaited(cancelOutgoing());
      } else if (_phase == LiveKitCallPhase.ringingIn) {
        unawaited(
          _finalize(
            reason: AppCallEndReason.noResponse,
            operatorIsSelf: false,
          ),
        );
      }
    });
  }

  Future<void> _finalize({
    required AppCallEndReason reason,
    required bool operatorIsSelf,
  }) async {
    if (_finalizing) return;
    if (_phase == LiveKitCallPhase.idle || _phase == LiveKitCallPhase.ended) {
      return;
    }
    _finalizing = true;
    // Invalidate any in-flight connect/publish before tearing media down.
    _sessionGen++;
    liveKitCallUiLog(
      '_finalize reason=$reason self=$operatorIsSelf '
      'phaseWas=$_phase role=$_role callId=$callId gen=$_sessionGen '
      'localAccept=$_localAcceptInFlight',
    );
    _ringTimeout?.cancel();
    _tokenRefreshTimer?.cancel();

    final room = _room;
    final listener = _roomListener;
    _room = null;
    _roomListener = null;

    final creds = _creds;
    final role = _role;
    final connectedAt = _connectedAt;
    final effectiveReason = _pendingEndReason ?? reason;

    try {
      final total = connectedAt == null
          ? 0.0
          : DateTime.now().difference(connectedAt).inMilliseconds / 1000.0;
      final caller = CallUserId.normalizeCallUserId(creds?.callerUserId ?? '');
      final callee = CallUserId.normalizeCallUserId(creds?.calleeUserId ?? '');
      final self = _selfUserId();
      final peer = role == AppCallRole.caller ? callee : caller;
      final operatorId = operatorIsSelf
          ? self
          : (peer.isNotEmpty
              ? peer
              : (role == AppCallRole.caller ? callee : caller));
      final isOutgoing = role == AppCallRole.caller;
      final media = appCallMediaTypeFromString(creds?.mediaType);

      _reportTelemetry(
        room: room,
        reason: effectiveReason,
        durationSec: total,
      );

      // Close UI immediately — never block hangup on LiveKit disconnect /
      // bubble persistence / VoIP cleanup (those caused exit stutter).
      _phase = LiveKitCallPhase.ended;
      notifyListeners();

      // Idle right away so the page can pop; keep room teardown / chat bubble
      // off the pop animation frame (disconnect + chat rebuild caused jank).
      _resetState();
      notifyListeners();

      // Do not rely solely on LiveKitCallPage's listener: CallKit accept may
      // push the route after hangup notify already fired.
      unawaited(LiveKitCallNavigator.closeCallPage());

      final callback = onCallEnded;
      final endedCallId = creds?.callId ?? '';
      unawaited(() async {
        // Exit is Duration.zero; only yield a frame so pop + blank paint settle
        // before chat-bubble rebuild / room.dispose.
        await Future<void>.delayed(const Duration(milliseconds: 48));
        if (callback != null && endedCallId.isNotEmpty) {
          callback(
            callId: endedCallId,
            mediaType: media,
            reason: effectiveReason,
            role: role,
            callerUserId: caller,
            calleeUserId: callee,
            peerUserId: peer,
            operatorUserId: operatorId,
            totalTimeSec: total,
            isOutgoing: isOutgoing,
          );
        }
        await _teardownMedia(room, listener);
      }());
    } finally {
      _finalizing = false;
    }
  }

  void _resetState() {
    _tokenRefreshTimer?.cancel();
    _tokenRecoverAttempts = 0;
    _phase = LiveKitCallPhase.idle;
    _creds = null;
    _role = AppCallRole.none;
    _pendingEndReason = null;
    _connectedAt = null;
    _micEnabled = true;
    _camEnabled = false;
    _speakerOn = false;
    _voiceAudioSessionConfigured = false;
    _lastVoiceRouteApplyMs = 0;
    _cameraPosition = CameraPosition.front;
    _switchingCamera = false;
    _cachedCameraIds = null;
  }

  String _selfUserId() {
    try {
      return CallUserId.normalizeCallUserId(
        TIMUIKitCore.getInstance().loginInfo.userID,
      );
    } catch (_) {
      return '';
    }
  }
}
