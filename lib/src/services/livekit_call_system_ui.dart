import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/src/services/desktop_call_float_service.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_demo/src/services/desktop_call_float_service_web.dart';
import 'package:tencent_cloud_chat_demo/src/services/ios_apns_push_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_navigator.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';

/// Bridges LiveKit call session to platform picture-in-picture.
///
/// Calls started or answered inside the app intentionally stay in the Flutter
/// LiveKit UI. This class must not create or connect an iOS CallKit call for
/// those flows. Native CallKit cleanup remains here because an offline VoIP
/// push may have presented system UI before Flutter was running.
class LiveKitCallSystemUi {
  LiveKitCallSystemUi._();

  static final LiveKitCallSystemUi instance = LiveKitCallSystemUi._();

  static const MethodChannel _iosChannel = MethodChannel('ios_apns_push');
  static const MethodChannel _androidChannel =
      MethodChannel('livekit_call_platform');

  bool _attached = false;
  LiveKitCallPhase? _lastPhase;
  String _lastCallId = '';
  String _lastPipTrackId = '';

  /// True while Android system PiP (or iOS system PiP) is showing.
  final ValueNotifier<bool> systemPipActive = ValueNotifier<bool>(false);

  Future<void> ensureAttached() async {
    if (_attached || kIsWeb) return;
    LiveKitCallSession.instance.addListener(_onSession);
    if (Platform.isAndroid) {
      _androidChannel.setMethodCallHandler(_onAndroidMethodCall);
    }
    _attached = true;
    // Seed last-known state without side effects. Calling `_onSession()` while
    // still idle would `endVoipCallKit()` and tear down a CallKit UI that
    // native PushKit already reported (cold-start / killed-app offline ring).
    final session = LiveKitCallSession.instance;
    _lastPhase = session.phase;
    _lastCallId = session.callId;
    _lastPipTrackId = _pipTrackId(session);
    if (session.phase != LiveKitCallPhase.idle &&
        session.phase != LiveKitCallPhase.ended) {
      _onSession();
    }
  }

  Future<dynamic> _onAndroidMethodCall(MethodCall call) async {
    if (call.method == 'onPipModeChanged') {
      final args = call.arguments;
      final active = args is Map && args['isInPictureInPictureMode'] == true;
      systemPipActive.value = active;
      if (kDebugMode) {
        debugPrint('LiveKitCallSystemUi: Android PiP active=$active');
      }
    }
  }

  void _onSession() {
    final session = LiveKitCallSession.instance;
    final phase = session.phase;
    final callId = session.callId;
    final trackId = _pipTrackId(session);
    if (phase == _lastPhase &&
        callId == _lastCallId &&
        trackId == _lastPipTrackId) {
      return;
    }
    final previousPhase = _lastPhase;
    _lastPhase = phase;
    _lastCallId = callId;
    _lastPipTrackId = trackId;

    switch (phase) {
      case LiveKitCallPhase.ringingOut:
        unawaited(_setPipEligible(false));
        break;
      case LiveKitCallPhase.ringingIn:
        // Incoming CallKit already reported by VoIP push when applicable.
        unawaited(_setPipEligible(false));
        break;
      case LiveKitCallPhase.connecting:
        break;
      case LiveKitCallPhase.connected:
        unawaited(_setPipEligible(session.isVideo));
        break;
      case LiveKitCallPhase.ended:
      case LiveKitCallPhase.idle:
        // Only end CallKit after a real Flutter call session. Idle attach /
        // VoIP-before-session must not kill the native ringing UI.
        final hadActiveSession = previousPhase != null &&
            previousPhase != LiveKitCallPhase.idle &&
            previousPhase != LiveKitCallPhase.ended;
        if (hadActiveSession) {
          unawaited(_endSystemUi());
        }
        break;
    }
  }

  /// WebRTC [MediaStreamTrack.id] for native PiP renderer (not LiveKit sid).
  String _pipTrackId(LiveKitCallSession session) {
    if (!session.isVideo) return '';
    final remote = session.remoteVideoTrack?.mediaStreamTrack.id?.trim() ?? '';
    if (remote.isNotEmpty) return remote;
    return session.localVideoTrack?.mediaStreamTrack.id?.trim() ?? '';
  }

  Future<void> onLifecycleChanged(AppLifecycleState state) async {
    if (kIsWeb) return;
    final session = LiveKitCallSession.instance;
    if (!session.isInCall) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (session.isVideo &&
          session.phase == LiveKitCallPhase.connected) {
        // Android system PiP snapshots the Activity — prefer fullscreen call
        // page so the PiP window shows video, not the chat list.
        if (Platform.isAndroid) {
          await _ensureCallPageForAndroidPip();
          await _setPipContentReady(true);
          // Let the call page paint at least one video frame.
          await WidgetsBinding.instance.endOfFrame;
          await WidgetsBinding.instance.endOfFrame;
          await Future<void>.delayed(const Duration(milliseconds: 48));
        } else if (!LiveKitCallNavigator.isCallPageOpen &&
            !DesktopCallFloatService.instance.visible) {
          unawaited(LiveKitCallNavigator.openCallPage(
            peerDisplayName: DesktopCallFloatService.instance.peerDisplayName,
            peerFaceUrl: DesktopCallFloatService.instance.peerFaceUrl,
          ));
        }
        await _enterPip();
      } else if (!session.isVideo && Platform.isIOS) {
        // Audio: CallKit Dynamic Island only (no float / PiP) — same as TUICallKit.
        if (DesktopCallFloatService.instance.visible) {
          DesktopCallFloatService.instance.hide();
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      systemPipActive.value = false;
      if (Platform.isAndroid) {
        await _setPipContentReady(LiveKitCallNavigator.isCallPageOpen);
      }
      final session = LiveKitCallSession.instance;
      if (session.isInCall && !LiveKitCallNavigator.isCallPageOpen) {
        unawaited(LiveKitCallNavigator.ensureCallPageVisible());
      }
    }
  }

  /// Restore fullscreen call UI without awaiting route pop (openCallPage
  /// completes only when the page is closed).
  Future<void> _ensureCallPageForAndroidPip() async {
    if (LiveKitCallNavigator.isCallPageOpen) {
      if (DesktopCallFloatService.instance.visible) {
        DesktopCallFloatService.instance.hide();
      }
      return;
    }
    if (DesktopCallFloatService.instance.visible) {
      await DesktopCallFloatService.instance.restoreCallPage();
    } else {
      unawaited(LiveKitCallNavigator.openCallPage(
        peerDisplayName: DesktopCallFloatService.instance.peerDisplayName,
        peerFaceUrl: DesktopCallFloatService.instance.peerFaceUrl,
      ));
    }
    for (var i = 0; i < 30 && !LiveKitCallNavigator.isCallPageOpen; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _endSystemUi() async {
    systemPipActive.value = false;
    await _setPipEligible(false);
    await _setPipContentReady(false);
    if (Platform.isIOS) {
      final endedCallId = _lastCallId.trim();
      await IosApnsPushService.instance.endVoipCallKit(
        inviteId: endedCallId.isEmpty ? null : endedCallId,
      );
      try {
        await _iosChannel.invokeMethod<void>('stopLiveKitPip');
      } catch (_) {}
    }
  }

  Future<void> _setPipEligible(bool eligible) async {
    if (Platform.isAndroid) {
      try {
        await _androidChannel.invokeMethod<void>(
          'setPipEligible',
          <String, dynamic>{'eligible': eligible},
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('LiveKitCallSystemUi: setPipEligible failed $e');
        }
      }
    } else if (Platform.isIOS) {
      final session = LiveKitCallSession.instance;
      final peer = session.peerUserId;
      final name = DisplayNameStore.instance.c2c(peer)?.trim() ?? peer;
      final trackId = _pipTrackId(session);
      try {
        await _iosChannel.invokeMethod<void>('setLiveKitPip', <String, dynamic>{
          'enabled': eligible,
          'hasVideo': session.isVideo,
          'peerName': name,
          'trackId': trackId,
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint('LiveKitCallSystemUi: setLiveKitPip failed $e');
        }
      }
    }
  }

  Future<void> setPipContentReady(bool ready) => _setPipContentReady(ready);

  Future<void> _setPipContentReady(bool ready) async {
    if (!Platform.isAndroid) return;
    try {
      await _androidChannel.invokeMethod<void>(
        'setPipContentReady',
        <String, dynamic>{'ready': ready},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LiveKitCallSystemUi: setPipContentReady failed $e');
      }
    }
  }

  Future<void> _enterPip() async {
    if (Platform.isAndroid) {
      try {
        await _androidChannel.invokeMethod<void>('enterPictureInPicture');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('LiveKitCallSystemUi: enterPictureInPicture failed $e');
        }
      }
    } else if (Platform.isIOS) {
      try {
        await _iosChannel.invokeMethod<void>('enterLiveKitPip');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('LiveKitCallSystemUi: enterLiveKitPip failed $e');
        }
      }
    }
  }
}
