import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';

/// Whether ringtone may play for [phase] given media room presence.
///
/// AudioSession ownership belongs to LiveKit / CallKit — ringtone must not
/// reconfigure the session, and must not play after [hasRoom] is true.
@visibleForTesting
bool shouldPlayRingtone({
  required LiveKitCallPhase phase,
  required bool hasRoom,
}) {
  switch (phase) {
    case LiveKitCallPhase.ringingOut:
    case LiveKitCallPhase.ringingIn:
      return !hasRoom;
    case LiveKitCallPhase.connecting:
    case LiveKitCallPhase.connected:
    case LiveKitCallPhase.ended:
    case LiveKitCallPhase.idle:
      return false;
  }
}

/// Plays legacy TUICallKit dial/ring tones for LiveKit call phases.
///
/// - Outgoing waiting: `phone_dialing.mp3`
/// - Incoming waiting: `phone_ringing.mp3`
/// Stops on connect / end / reject / cancel.
///
/// Ringtone only plays assets; AudioSession is owned by LiveKit / CallKit.
class LiveKitCallRingtone {
  LiveKitCallRingtone._();

  static final LiveKitCallRingtone instance = LiveKitCallRingtone._();

  static const String dialingAsset = 'assets/call_sounds/phone_dialing.mp3';
  static const String ringingAsset = 'assets/call_sounds/phone_ringing.mp3';

  final AudioPlayer _player = AudioPlayer(
    handleAudioSessionActivation: false,
  );
  bool _attached = false;
  LiveKitCallPhase? _playingForPhase;
  String? _playingAsset;
  int _playGen = 0;

  Future<void> ensureAttached() async {
    if (_attached) return;
    LiveKitCallSession.instance.addListener(_onSession);
    _attached = true;
    _onSession();
  }

  Future<void> stop() async {
    _playGen++;
    _playingForPhase = null;
    _playingAsset = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  void _onSession() {
    final session = LiveKitCallSession.instance;
    final phase = session.phase;
    final hasRoom = session.room != null;
    if (!shouldPlayRingtone(phase: phase, hasRoom: hasRoom)) {
      unawaited(stop());
      return;
    }
    if (!NotificationSettingsService.instance.allowsCallRingtone) {
      unawaited(stop());
      return;
    }
    switch (phase) {
      case LiveKitCallPhase.ringingOut:
        unawaited(_playLoop(dialingAsset, phase));
        break;
      case LiveKitCallPhase.ringingIn:
        unawaited(_playLoop(ringingAsset, phase));
        break;
      case LiveKitCallPhase.connecting:
      case LiveKitCallPhase.connected:
      case LiveKitCallPhase.ended:
      case LiveKitCallPhase.idle:
        unawaited(stop());
        break;
    }
  }

  Future<void> _playLoop(String asset, LiveKitCallPhase phase) async {
    if (_playingForPhase == phase && _playingAsset == asset) {
      // Already looping the right tone (e.g. reconnect notify).
      if (_player.playing) return;
    }
    final gen = ++_playGen;
    _playingForPhase = phase;
    _playingAsset = asset;
    try {
      await _player.stop();
      if (gen != _playGen) return;
      await _player.setLoopMode(LoopMode.one);
      await _player.setAsset(asset);
      await _player.setVolume(1);
      await _player.seek(Duration.zero);
      if (gen != _playGen) return;
      await _player.play();
      if (kDebugMode) {
        debugPrint('LiveKitCallRingtone: playing $asset phase=$phase');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('LiveKitCallRingtone: play failed: $e\n$st');
      }
    }
  }
}
