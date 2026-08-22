import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/livekit_call_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/livekit_call_credentials.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_media_helpers.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';

const _sampleCreds = LiveKitCallCredentials(
  callId: 'call-1',
  roomName: 'room-1',
  url: 'wss://example.com',
  token: 'token-1',
  mediaType: 'audio',
  callerUserId: 'u1',
  calleeUserId: 'u2',
);

void main() {
  group('liveKitPublishFailureMessage', () {
    test('maps mic failure', () {
      expect(liveKitPublishFailureMessage('mic'), contains('麦克风'));
    });

    test('maps camera failure', () {
      expect(liveKitPublishFailureMessage('camera'), contains('摄像头'));
    });
  });

  group('resolveAcceptCredentials', () {
    test('falls back to fetchToken on CALL_ALREADY_ANSWERED', () async {
      var fetchCalled = false;
      final api = LiveKitCallApiOverride(
        acceptFn: ({required String callId}) async {
          throw LiveKitCallApiException('CALL_ALREADY_ANSWERED', 'already');
        },
        fetchTokenFn: ({required String callId}) async {
          fetchCalled = true;
          expect(callId, 'call-1');
          return _sampleCreds;
        },
      );

      final creds = await resolveAcceptCredentials(callId: 'call-1', api: api);
      expect(fetchCalled, isTrue);
      expect(creds.token, 'token-1');
    });

    test('falls back to fetchToken on REQUEST_TIMEOUT', () async {
      var fetchCalled = false;
      final api = LiveKitCallApiOverride(
        acceptFn: ({required String callId}) async {
          throw LiveKitCallApiException('REQUEST_TIMEOUT', 'timeout');
        },
        fetchTokenFn: ({required String callId}) async {
          fetchCalled = true;
          return _sampleCreds;
        },
      );

      final creds = await resolveAcceptCredentials(callId: 'call-1', api: api);
      expect(fetchCalled, isTrue);
      expect(creds.callId, 'call-1');
    });

    test('rethrows other API errors', () async {
      final api = LiveKitCallApiOverride(
        acceptFn: ({required String callId}) async {
          throw LiveKitCallApiException('CALLEE_BUSY', 'busy');
        },
        fetchTokenFn: ({required String callId}) async => _sampleCreds,
      );

      await expectLater(
        resolveAcceptCredentials(callId: 'call-1', api: api),
        throwsA(isA<LiveKitCallApiException>()),
      );
    });
  });

  group('disconnectReasonToEndReason', () {
    test('maps duplicate identity to otherDeviceAccepted', () {
      expect(
        disconnectReasonToEndReason(DisconnectReason.duplicateIdentity),
        AppCallEndReason.otherDeviceAccepted,
      );
    });

    test('maps server-side removal to endByServer', () {
      expect(
        disconnectReasonToEndReason(DisconnectReason.participantRemoved),
        AppCallEndReason.endByServer,
      );
    });

    test('returns null for null disconnect reason', () {
      expect(disconnectReasonToEndReason(null), isNull);
    });

    test('returns null for client initiated disconnect', () {
      expect(
        disconnectReasonToEndReason(DisconnectReason.clientInitiated),
        isNull,
      );
    });
  });

  group('countRemoteAudioTracks', () {
    test('returns zero when room is null', () {
      expect(countRemoteAudioTracks(null), 0);
    });
  });

  group('countLocalAudioTracks', () {
    test('returns zero when room is null', () {
      expect(countLocalAudioTracks(null), 0);
    });
  });

  group('describeCallAudioState', () {
    test('describes a null room', () {
      expect(describeCallAudioState(null), 'room=null');
    });
  });

  group('always-on audio receive logs', () {
    test('subscribe and playback log via liveKitCallUiLog', () {
      final helpers = File(
        'lib/src/services/livekit_call_media_helpers.dart',
      ).readAsStringSync();
      expect(helpers, contains('describeCallAudioState'));
      expect(helpers, contains('ensureRemoteAudioSubscribed tag='));
      expect(helpers, contains('ensureRemoteAudioPlayback tag='));
      expect(helpers, contains('emptyTrack tag='));
      expect(helpers, contains('scheduleRemoteAudioRecovery begin tag='));
      expect(helpers, contains('scheduleRemoteAudioRecovery end tag='));
    });
  });

  group('logLocalTrackPublications', () {
    test('is safe when room is null', () {
      expect(() => logLocalTrackPublications(null, tag: 'test'), returnsNormally);
    });
  });

  group('scheduleRemoteAudioRecovery', () {
    test('is safe when room is null', () async {
      await expectLater(
        scheduleRemoteAudioRecovery(null, tag: 'test'),
        completes,
      );
    });
  });
}
