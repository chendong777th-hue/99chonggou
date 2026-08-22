import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tencent_cloud_chat_demo/src/models/message_notification_sound.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/sound_record.dart';

/// 应用内消息横幅提示音。
class InAppNotificationSound {
  InAppNotificationSound._();

  static final AudioPlayer _player = AudioPlayer(
    handleAudioSessionActivation: false,
  );
  static bool _sessionConfigured = false;
  static int _lastPlayedAtMs = 0;

  /// 由 main.dart 注入，用于在无 [LocalSetting] 上下文时解析当前提示音。
  static String Function()? soundIdResolver;

  static Future<void> playMessageReceived() async {
    final soundId = soundIdResolver?.call() ?? MessageNotificationSound.defaultId;
    await playSound(soundId);
  }

  static Future<void> playSound(String soundId, {bool force = false}) async {
    // Do not reconfigure AudioSession or play over an active LiveKit call.
    if (LiveKitCallSession.instance.isInCall) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastPlayedAtMs < 800) {
      return;
    }
    _lastPlayedAtMs = now;

    final option = MessageNotificationSound.fromId(soundId);

    try {
      await _ensureSession();
      await _player.stop();
      await _player.setAsset(option.assetPath);
      await _player.setVolume(1);
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('InAppNotificationSound fallback: $error\n$stack');
      }
      await _playSystemFallback();
    } finally {
      // 提示音用了 notification 流后，必须让语音下次强制切回 media/playback。
      SoundPlayer.invalidatePlaybackSession();
    }
  }

  static Future<void> _playSystemFallback() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('InAppNotificationSound system fallback failed: $error\n$stack');
      }
    }
  }

  static Future<void> _ensureSession() async {
    final session = await AudioSession.instance;
    if (!_sessionConfigured) {
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.ambient,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.notification,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );
      _sessionConfigured = true;
      SoundPlayer.invalidatePlaybackSession();
    }
    try {
      await session.setActive(true);
    } catch (_) {}
  }
}
