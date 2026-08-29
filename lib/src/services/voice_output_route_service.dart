import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// 语音消息与 TUICallKit 共用的输出路由。
///
/// 不在录音开始/结束、通话结束时重置用户选择；只有用户主动切换时才更新。
enum VoiceOutputRoute {
  speaker,
  earpiece,
}

class VoiceOutputRouteService {
  VoiceOutputRouteService._();

  static final ValueNotifier<VoiceOutputRoute> routeNotifier =
      ValueNotifier<VoiceOutputRoute>(VoiceOutputRoute.speaker);

  // Native audio-session changes are not safely re-entrant. CallKit, LiveKit
  // track callbacks and the UI can all request a route at the same time, so
  // serialize them and only apply the newest desired route.
  static int _routeGeneration = 0;
  static bool _routeApplyInFlight = false;
  static VoiceOutputRoute? _pendingRoute;
  static bool _pendingConfigureSession = false;
  static bool _pendingForRecording = false;
  static bool _pendingActivate = false;
  // Tracks the category most recently configured through this coordinator.
  // AVAudioSession.overrideOutputAudioPort is only valid for a playAndRecord
  // session; calling it after configuring playback is the common source of
  // OSStatus -50 in this app.
  static bool? _sessionUsesPlayAndRecord;

  static VoiceOutputRoute get currentRoute => routeNotifier.value;

  static bool get isSpeaker => currentRoute == VoiceOutputRoute.speaker;

  static bool get isEarpiece => currentRoute == VoiceOutputRoute.earpiece;

  static bool get supportsNativeRoute {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  static AudioSessionConfiguration playbackConfigFor(VoiceOutputRoute route) {
    if (route == VoiceOutputRoute.earpiece) {
      return voiceChatConfigFor(route);
    }
    // 扬声器走 playback/media：手机静音开关下仍可听语音（对标微信）。
    return const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    );
  }

  static AudioSessionConfiguration voiceChatConfigFor(VoiceOutputRoute route) {
    return AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: route == VoiceOutputRoute.speaker
          ? AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth
          : AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    );
  }

  static Future<bool> applyCurrentRoute({
    bool configureSession = false,
    bool forRecording = false,
    bool activate = false,
  }) {
    return setRoute(
      currentRoute,
      configureSession: configureSession,
      forRecording: forRecording,
      activate: activate,
      forceApply: true,
    );
  }

  static Future<bool> setRoute(
    VoiceOutputRoute route, {
    bool configureSession = false,
    bool forRecording = false,
    bool activate = false,
    bool forceApply = false,
  }) async {
    if (!forceApply && currentRoute == route && !configureSession) {
      return true;
    }

    // 先保存用户意图，再执行异步原生切换。自动播放下一条可能与这里并发，
    // 必须让新播放器立即读到最新选择，不能等平台调用全部结束才更新。
    if (routeNotifier.value != route) {
      routeNotifier.value = route;
    }

    ++_routeGeneration;
    _pendingRoute = route;
    _pendingConfigureSession = _pendingConfigureSession || configureSession;
    _pendingForRecording = _pendingForRecording || forRecording;
    _pendingActivate = _pendingActivate || activate;
    if (_routeApplyInFlight) {
      return true;
    }
    _routeApplyInFlight = true;

    var result = true;
    try {
      while (true) {
        final requestedGeneration = _routeGeneration;
        final requestedRoute = _pendingRoute ?? route;
        final requestedConfigure = _pendingConfigureSession;
        final requestedRecording = _pendingForRecording;
        final requestedActivate = _pendingActivate;
        _pendingRoute = null;
        _pendingConfigureSession = false;
        _pendingForRecording = false;
        _pendingActivate = false;

        if (!kIsWeb) {
          try {
            final session = await AudioSession.instance;
            if (requestedConfigure) {
              final config = requestedRecording
                  ? voiceChatConfigFor(requestedRoute)
                  : playbackConfigFor(requestedRoute);
              await session.configure(config);
              _sessionUsesPlayAndRecord = requestedRecording ||
                  requestedRoute == VoiceOutputRoute.earpiece;
            }
            if (requestedActivate) {
              try {
                await session.setActive(true);
              } catch (e) {
                result = false;
                if (kDebugMode) {
                  debugPrint('VoiceOutputRouteService: setActive failed ($e)');
                }
              }
            }
            // Speaker override is invalid for AVAudioSessionCategoryPlayback.
            // For an inactive session, category/defaultToSpeaker is enough;
            // apply the native port only once the session is active.
            if (_sessionUsesPlayAndRecord == true && requestedActivate) {
              await _applyNativeRoute(requestedRoute);
            }
          } catch (e) {
            result = false;
            if (kDebugMode) {
              debugPrint('VoiceOutputRouteService: switch route failed ($e)');
            }
          }
        }
        // A newer request arrived while native calls were awaiting. Loop once
        // more and apply only the latest route; never let an older request win.
        if (requestedGeneration == _routeGeneration && _pendingRoute == null) {
          break;
        }
      }
    } finally {
      _routeApplyInFlight = false;
    }
    return result;
  }

  static Future<void> _applyNativeRoute(VoiceOutputRoute route) async {
    if (!supportsNativeRoute) {
      return;
    }
    final useSpeaker = route == VoiceOutputRoute.speaker;
    if (Platform.isAndroid) {
      await AndroidAudioManager().setSpeakerphoneOn(useSpeaker);
      return;
    }
    if (Platform.isIOS) {
      await AVAudioSession().overrideOutputAudioPort(
        useSpeaker
            ? AVAudioSessionPortOverride.speaker
            : AVAudioSessionPortOverride.none,
      );
    }
  }
}
