import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// UIKit 内部的语音输出路由桥接接口。
/// app 层通过 [SoundPlayerVoiceRouteBridge.install] 注入实现，
/// 避免 UIKit 跨 package 引用 app 的 VoiceOutputRouteService。
enum SoundPlayerVoiceRoute { speaker, earpiece }

abstract class SoundPlayerVoiceRouteBridge {
  static SoundPlayerVoiceRouteBridge? _instance;

  static SoundPlayerVoiceRouteBridge? get instance => _instance;

  static void install(SoundPlayerVoiceRouteBridge bridge) {
    _instance = bridge;
  }

  SoundPlayerVoiceRoute get currentRoute;
  bool get isSpeaker => currentRoute == SoundPlayerVoiceRoute.speaker;
  ValueListenable<SoundPlayerVoiceRoute> get routeNotifier;

  AudioSessionConfiguration playbackConfigFor(SoundPlayerVoiceRoute route);
  AudioSessionConfiguration voiceChatConfigFor(SoundPlayerVoiceRoute route);

  Future<bool> applyCurrentRoute({
    bool configureSession = false,
    bool forRecording = false,
    bool activate = false,
  });

  Future<bool> setRoute(
    SoundPlayerVoiceRoute target, {
    bool configureSession = true,
    bool forRecording = false,
    bool activate = true,
    bool forceApply = false,
  });
}

/// 默认实现：扬声器播放，无原生路由切换——仅在不注入 bridge 时兜底。
class _DefaultVoiceRouteBridge implements SoundPlayerVoiceRouteBridge {
  static final ValueNotifier<SoundPlayerVoiceRoute> _notifier =
      ValueNotifier<SoundPlayerVoiceRoute>(SoundPlayerVoiceRoute.speaker);

  @override
  SoundPlayerVoiceRoute get currentRoute => _notifier.value;

  @override
  bool get isSpeaker => currentRoute == SoundPlayerVoiceRoute.speaker;

  @override
  ValueListenable<SoundPlayerVoiceRoute> get routeNotifier => _notifier;

  @override
  AudioSessionConfiguration playbackConfigFor(SoundPlayerVoiceRoute route) {
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

  @override
  AudioSessionConfiguration voiceChatConfigFor(SoundPlayerVoiceRoute route) {
    return AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: route == SoundPlayerVoiceRoute.speaker
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

  @override
  Future<bool> applyCurrentRoute({
    bool configureSession = false,
    bool forRecording = false,
    bool activate = false,
  }) async {
    return true;
  }

  @override
  Future<bool> setRoute(
    SoundPlayerVoiceRoute target, {
    bool configureSession = true,
    bool forRecording = false,
    bool activate = true,
    bool forceApply = false,
  }) async {
    _notifier.value = target;
    return true;
  }
}

/// 获取当前 bridge（已安装用 app 实现，否则用默认兜底）。
SoundPlayerVoiceRouteBridge get soundPlayerVoiceRouteBridge =>
    SoundPlayerVoiceRouteBridge.instance ?? _DefaultVoiceRouteBridge();
