import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signaling handles answered_elsewhere with dedupe and ringtone stop', () {
    final source = File('lib/src/services/livekit_call_signaling.dart')
        .readAsStringSync();
    expect(source, contains("'answered_elsewhere'"));
    expect(source, contains('IncomingCallPushHandler.instance.noteInviteHandled'));
    expect(source, contains('LiveKitCallRingtone.instance.stop()'));
  });

  test('session ignores answered_elsewhere during local callee accept', () {
    final source =
        File('lib/src/services/livekit_call_session.dart').readAsStringSync();
    expect(source, contains("case 'answered_elsewhere':"));
    expect(source, contains('_localAcceptInFlight'));
    expect(
      source,
      contains('answered_elsewhere ignored — local accept'),
    );
    expect(source, contains('_acceptStillValid'));
    // Must still finalize when merely ringing (other device answered).
    expect(
      source,
      contains('_phase == LiveKitCallPhase.ringingIn ||'),
    );
    expect(
      source,
      contains('_phase == LiveKitCallPhase.ringingOut)'),
    );
  });

  test('lk_call bubble normalization keeps lk_call businessID', () {
    final source = File(
      'lib/utils/custom_message/calling_message/calling_message_data_provider.dart',
    ).readAsStringSync();
    expect(source, isNot(contains("data['businessID'] = 'av_call';")));
    expect(source, contains("data['businessID'] = 'lk_call';"));
  });
}
