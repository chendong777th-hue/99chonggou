import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VoIP bridge registers iOS CallKit audio waiter', () {
    final bridge = File(
      'lib/src/services/livekit_voip_bridge.dart',
    ).readAsStringSync();
    expect(bridge, contains('iosCallKitAudioReadyWaiter = _waitForCallKitAudioReadyIfPending'));
    expect(bridge, contains('_waitForCallKitAudioReadyIfPending'));
    expect(bridge, contains('_audioSessionActivatedLatch'));
    expect(bridge, contains('iosCallKitAudioWaitDecision'));
    expect(bridge, contains('ensureLocalMicPublishedAfterCallKitActivate'));
    expect(bridge, isNot(contains('if (existing == null || existing.isCompleted) return')));
  });

  test('callee connect waits for CallKit audio before room.connect', () {
    final session = File(
      'lib/src/services/livekit_call_session.dart',
    ).readAsStringSync();
    final helpers = File(
      'lib/src/services/livekit_call_media_helpers.dart',
    ).readAsStringSync();
    final connectBlock = session.indexOf('Future<void> _connectAndPublish(');
    expect(connectBlock, greaterThanOrEqualTo(0));
    expect(session, contains('await prepareIosCallKitMediaJoin('));
    expect(session, contains('isCallee: _role == AppCallRole.callee'));
    // Audio + video callees must gate on CallKit (not video-only).
    expect(helpers, isNot(contains('if (!video || !isCallee)')));
    expect(helpers, contains('if (!isCallee)'));
    final ringtoneStop = session.indexOf(
      'await LiveKitCallRingtone.instance.stop();',
      connectBlock,
    );
    final prepare = session.indexOf(
      'await prepareIosCallKitMediaJoin(',
      ringtoneStop,
    );
    final connect = session.indexOf(
      'await room.connect(creds.url, creds.token);',
      prepare,
    );
    expect(prepare, greaterThan(ringtoneStop));
    expect(connect, greaterThan(prepare));
  });

  test('mic publish waits for CallKit audio on iOS', () {
    final helpers = File(
      'lib/src/services/livekit_call_media_helpers.dart',
    ).readAsStringSync();
    final publish = helpers.indexOf('Future<bool> publishLocalCallTracks(');
    final micWait = helpers.indexOf(
      'await waitForIosCallKitAudioReady();',
      publish,
    );
    final defer = helpers.indexOf(
      'publishLocalCallTracks defer mic — CallKit audio not ready',
      micWait,
    );
    final micEnable = helpers.indexOf(
      'await local.setMicrophoneEnabled(true);',
      defer,
    );
    expect(micWait, greaterThan(publish));
    expect(defer, greaterThan(micWait));
    expect(micEnable, greaterThan(defer));
    expect(helpers.substring(publish, micEnable), isNot(contains('LiveKitPublishException(\'mic\', \'callKit')));
  });

  test('camera publish waits for CallKit audio on iOS', () {
    final helpers = File(
      'lib/src/services/livekit_call_media_helpers.dart',
    ).readAsStringSync();
    final publish = helpers.indexOf('Future<bool> publishLocalCallTracks(');
    final micEnable = helpers.indexOf(
      'await local.setMicrophoneEnabled(true);',
      publish,
    );
    final cameraWait = helpers.indexOf(
      'await waitForIosCallKitAudioReady();',
      micEnable,
    );
    final cameraEnable = helpers.indexOf(
      'await local.setCameraEnabled(true);',
      cameraWait,
    );
    expect(cameraWait, greaterThan(micEnable));
    expect(cameraEnable, greaterThan(cameraWait));
  });

  test('CXAnswerCallAction fulfills immediately after configureAudioSession', () {
    final ios = File(
      'ios/Runner/SelfHostedVoipCallKit.swift',
    ).readAsStringSync();
    final start = ios.indexOf(
      'func provider(_ provider: CXProvider, perform action: CXAnswerCallAction)',
    );
    final end = ios.indexOf(
      'func provider(_ provider: CXProvider, perform action: CXEndCallAction)',
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final answer = ios.substring(start, end);
    expect(answer, contains('configureAudioSession()'));
    expect(answer, contains('action.fulfill()'));
    expect(answer, isNot(contains('holdCallAction')));
  });

  test('CallKit audio route waits for live tracks before setSpeakerphoneOn', () {
    final bridge = File(
      'lib/src/services/livekit_voip_bridge.dart',
    ).readAsStringSync();
    expect(bridge, contains('hasLiveCallAudioTracks(session.room)'));
    expect(bridge, contains('LiveKitCallPhase.connected'));
  });

  test('ensureCallAudioRoute skips iOS soloAmbient when no audio tracks', () {
    final session = File(
      'lib/src/services/livekit_call_session.dart',
    ).readAsStringSync();
    expect(session, contains('!hasLiveCallAudioTracks(_room)'));
    expect(session, contains('CallKit owns audio session'));
    expect(session, contains('iosCallKitShouldApplyLiveKitSpeakerRoute'));
  });

  test('CallKit _onAccept dismisses system UI with keepAudio after join', () {
    final bridge = File(
      'lib/src/services/livekit_voip_bridge.dart',
    ).readAsStringSync();
    final start = bridge.indexOf('Future<void> _onAccept(');
    final end = bridge.indexOf('Future<void> _onHangup(');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final accept = bridge.substring(start, end);
    expect(accept, contains('keepAudioSession: true'));
    expect(accept, contains('callKit/afterDismissCallKit'));
    expect(accept, contains('_syncLatchFromNative'));
    expect(accept.indexOf('await session.acceptIncoming();'), lessThan(
      accept.indexOf('keepAudioSession: true'),
    ));
  });

  test('native CallKit activate is queryable after dropped channel event', () {
    final api = File(
      'lib/src/services/ios_apns_push_service.dart',
    ).readAsStringSync();
    expect(api, contains('isVoipAudioSessionActivated'));
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(ios, contains('isVoipAudioSessionActivated'));
    final kit = File(
      'ios/Runner/SelfHostedVoipCallKit.swift',
    ).readAsStringSync();
    expect(kit, contains('audioSessionActivated'));
  });

  test('connected session ensures call page is visible', () {
    final session = File(
      'lib/src/services/livekit_call_session.dart',
    ).readAsStringSync();
    expect(
      session,
      contains("LiveKitCallNavigator.ensureCallPageVisible("),
    );
    final connectDone = session.indexOf('_logAudioSnapshot(\'connectPublishDone\');');
    final ensure = session.indexOf(
      "reason: 'connectPublishDone'",
      connectDone,
    );
    expect(ensure, greaterThan(connectDone));
  });

  test('dismissing CallKit after accept keeps AVAudioSession active', () {
    final bridge = File(
      'lib/src/services/livekit_voip_bridge.dart',
    ).readAsStringSync();
    expect(bridge, contains('keepAudioSession'));
    expect(bridge, contains('recoverCallAudio'));
    expect(
      bridge,
      contains('keepAudioSession: true'),
    );
    expect(
      bridge,
      contains("session.recoverCallAudio(tag: 'voipAudioSessionDeactivated')"),
    );

    final ios = File(
      'ios/Runner/SelfHostedVoipCallKit.swift',
    ).readAsStringSync();
    expect(ios, contains('keepAudioSession'));
    expect(ios, contains('if !keepAudioSession'));
    expect(ios, contains('keepAudioAcrossCallKitEnd'));
    expect(ios, contains('didDeactivate ignored'));

    final api = File(
      'lib/src/services/ios_apns_push_service.dart',
    ).readAsStringSync();
    expect(api, contains('keepAudioSession'));
  });

  test('caller audio receive snapshots are always-on', () {
    final session = File(
      'lib/src/services/livekit_call_session.dart',
    ).readAsStringSync();
    expect(session, contains("remoteAccept audioRecv"));
    expect(session, contains("audioRecv[\$tag]"));
    expect(session, contains('TrackPublished identity='));
    expect(session, contains('TrackSubscribed identity='));
    expect(session, contains('describeCallAudioState(_room)'));
    expect(session, isNot(contains('if (!kDebugMode) return;\n    final room = _room;')));
  });

  test('voice calls default to earpiece not speaker', () {
    final session = File(
      'lib/src/services/livekit_call_session.dart',
    ).readAsStringSync();
    expect(session, contains('_speakerOn = creds.isVideo'));
    expect(session, contains('_speakerOn = video'));
    expect(session, contains('_speakerOn = _creds?.isVideo == true'));
  });
}
