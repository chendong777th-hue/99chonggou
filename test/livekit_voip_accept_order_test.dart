import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CallKit accept seeds session with pending VoIP mediaType', () {
    final source = File(
      'lib/src/services/livekit_voip_bridge.dart',
    ).readAsStringSync();
    expect(source, contains('pendingMediaType(inviteId)'));
    expect(
      source,
      contains("mediaType: coordinator.pendingMediaType(inviteId) ?? 'audio'"),
    );
  });

  test('CallKit audio activation does not block UI or LiveKit accept', () {
    final source = File(
      'lib/src/services/livekit_voip_bridge.dart',
    ).readAsStringSync();
    final onAccept = source.indexOf('Future<void> _onAccept(');
    final fulfill = source.indexOf(
      'await _completeAction(uuid, true);',
      onAccept,
    );
    final openPage = source.indexOf(
      'LiveKitCallNavigator.ensureCallPageVisible(reason: \'callKit/beforeAccept\')',
      fulfill,
    );
    final backgroundAudio = source.indexOf(
      'unawaited(_restoreAudioRouteWhenReady(session));',
      openPage,
    );
    final accept = source.indexOf(
      'await session.acceptIncoming();',
      backgroundAudio,
    );

    expect(fulfill, greaterThanOrEqualTo(0));
    expect(openPage, greaterThan(fulfill));
    expect(backgroundAudio, greaterThan(openPage));
    expect(accept, greaterThan(backgroundAudio));

    final acceptPrelude = source.substring(fulfill, accept);
    expect(
      acceptPrelude,
      isNot(contains('await _waitAudioSessionActivated();')),
      reason: 'audio activation must not block page presentation or joining',
    );
  });
}
