import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/models/livekit_call_credentials.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  tearDown(() async {
    final session = LiveKitCallSession.instance;
    if (session.isBusy) {
      await session.cancelOutgoing();
    }
  });

  test('prepareOutgoingPending shows ringing before invite credentials',
      () async {
    final session = LiveKitCallSession.instance;
    await session.prepareOutgoingPending(
      calleeUserId: 'peer_1',
      video: false,
    );

    expect(session.phase, LiveKitCallPhase.ringingOut);
    expect(session.role, AppCallRole.caller);
    expect(session.callId, isEmpty);
    expect(session.isVideo, isFalse);
    expect(session.credentials?.calleeUserId, 'peer_1');
  });

  test('bindOutgoingCredentials attaches invite result while ringing', () async {
    final session = LiveKitCallSession.instance;
    await session.prepareOutgoingPending(
      calleeUserId: 'peer_2',
      video: true,
    );

    final ok = session.bindOutgoingCredentials(
      const LiveKitCallCredentials(
        callId: 'call_abc',
        roomName: 'room_abc',
        url: 'wss://example.test',
        token: 'tok',
        mediaType: 'video',
        callerUserId: 'me',
        calleeUserId: 'peer_2',
        timeoutSec: 45,
      ),
    );

    expect(ok, isTrue);
    expect(session.callId, 'call_abc');
    expect(session.isVideo, isTrue);
    expect(session.phase, LiveKitCallPhase.ringingOut);
  });

  test('bindOutgoingCredentials returns false after cancel', () async {
    final session = LiveKitCallSession.instance;
    await session.prepareOutgoingPending(
      calleeUserId: 'peer_3',
      video: false,
    );
    await session.cancelOutgoing();

    final ok = session.bindOutgoingCredentials(
      const LiveKitCallCredentials(
        callId: 'call_late',
        roomName: 'room_late',
        url: 'wss://example.test',
        token: 'tok',
        mediaType: 'audio',
        callerUserId: 'me',
        calleeUserId: 'peer_3',
      ),
    );

    expect(ok, isFalse);
    expect(session.isBusy, isFalse);
  });
}
