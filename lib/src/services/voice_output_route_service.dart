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

    if (kIsWeb) {
      return true;
    }

    try {
      final session = await AudioSession.instance;
      if (configureSession) {
        final config =
            forRecording ? voiceChatConfigFor(route) : playbackConfigFor(route);
        await session.configure(config);
      }

      if (activate) {
        try {
          await session.setActive(true);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('VoiceOutputRouteService: setActive failed ($e)');
          }
        }
      }

      // configure / setActive 都可能让系统重新选择默认输出端口。
      // 原生路由必须最后应用，才能保证连续播放下一条时沿用用户选择。
      await _applyNativeRoute(route);

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VoiceOutputRouteService: switch route failed ($e)');
      }
      return false;
    }
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
