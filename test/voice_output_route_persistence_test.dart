import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_output_route_service.dart';

void main() {
  test('speaker and earpiece keep distinct playback session modes', () {
    final speaker = VoiceOutputRouteService.playbackConfigFor(
      VoiceOutputRoute.speaker,
    );
    final earpiece = VoiceOutputRouteService.playbackConfigFor(
      VoiceOutputRoute.earpiece,
    );

    expect(speaker.avAudioSessionCategory, AVAudioSessionCategory.playback);
    expect(
      earpiece.avAudioSessionCategory,
      AVAudioSessionCategory.playAndRecord,
    );
  });

  test('native route is restored after session activation', () {
    final source = File(
      'lib/src/services/voice_output_route_service.dart',
    ).readAsStringSync();
    final activate = source.indexOf('await session.setActive(true)');
    final nativeRoute = source.indexOf(
      'await _applyNativeRoute(requestedRoute)',
    );

    expect(activate, greaterThan(-1));
    expect(nativeRoute, greaterThan(activate));
  });

  test('user route intent is stored before asynchronous native work', () {
    final source = File(
      'lib/src/services/voice_output_route_service.dart',
    ).readAsStringSync();
    final setterStart = source.indexOf('static Future<bool> setRoute(');
    final setterEnd = source.indexOf(
      'static Future<void> _applyNativeRoute(',
      setterStart,
    );
    final setter = source.substring(setterStart, setterEnd);
    final persist = setter.indexOf('routeNotifier.value = route');
    final session =
        setter.indexOf('final session = await AudioSession.instance');

    expect(persist, greaterThan(-1));
    expect(session, greaterThan(persist));
  });

  test('every new voice source reapplies current route before play', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/sound_record.dart',
    ).readAsStringSync();
    final playStart = source.indexOf('static Future<void> _playInternal({');
    final playEnd = source.indexOf(
      'static Future<void> pause()',
      playStart,
    );
    final playSource = source.substring(playStart, playEnd);
    final setSource = playSource.indexOf('await _audioPlayer.setAudioSource(');
    final applyRoute =
        playSource.indexOf('await _applyOutputRoute(configureSession: true)');
    final play = playSource.indexOf('unawaited(_audioPlayer.play()');

    expect(setSource, greaterThan(-1));
    expect(applyRoute, greaterThan(setSource));
    expect(play, greaterThan(applyRoute));
  });

  test('actual playing state reasserts route after player takes control', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/sound_record.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
          'if (state.playing) {\n      _reassertRouteAfterPlaybackStarted();'),
    );
    expect(source, contains('Duration(milliseconds: 160)'));
    expect(source, contains('await _applyOutputRoute();'));
    expect(
      source,
      contains(
        'if (_playbackPhase == VoicePlaybackPhase.loading ||',
      ),
    );
  });

  test('live speaker toggle reconfigures session and resumes current playback',
      () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/sound_record.dart',
    ).readAsStringSync();
    final start = source.indexOf('static Future<bool> _setSpeakerOnInternal(');
    final end = source.indexOf('static Future<bool> toggleSpeaker(');
    expect(start, greaterThan(-1));
    expect(end, greaterThan(start));
    final body = source.substring(start, end);
    expect(body, contains('configureSession: true'));
    expect(body, contains('forceApply: true'));
    expect(body, contains('await _audioPlayer.pause()'));
    expect(body, contains('unawaited(_audioPlayer.play()'));
    expect(body, contains('_applyingRouteChange = true'));
  });

  test('session reconfigure during route switch does not user-pause playback',
      () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/sound_record.dart',
    ).readAsStringSync();
    expect(source, contains('if (_applyingRouteChange) {\n        return;'));
  });

  test('legacy iOS recorder/player do not mutate the shared audio session', () {
    for (final path in <String>[
      'third_party/flutter_plugin_record_plus/ios/Classes/DPAudioRecorder.m',
      'third_party/flutter_plugin_record_plus/ios/Classes/DPAudioPlayer.m',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('setCategory:')));
      expect(source, isNot(contains('setActive:')));
      expect(source, isNot(contains('overrideOutputAudioPort(')));
    }
  });

  test('CallKit playAndRecord configuration does not request A2DP', () {
    final source = File(
      'ios/Runner/SelfHostedVoipCallKit.swift',
    ).readAsStringSync();
    final start = source.indexOf('private func configureAudioSession()');
    final end = source.indexOf('private func deactivateAudioSession()', start);
    expect(start, greaterThan(-1));
    expect(end, greaterThan(start));
    expect(source.substring(start, end), isNot(contains('allowBluetoothA2DP')));
  });

  test('tooltip rebuilds speaker/earpiece labels from route notifier', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_message_tooltip.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('SoundPlayer.outputRouteListenable.addListener'),
    );
    expect(
      source,
      contains("SoundPlayer.speakerOn ? '听筒' : '扬声器'"),
    );
  });
}
