import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/presence_last_seen_codec.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime_service.dart';

void main() {
  test('ping frame omits empty deviceId and includes non-empty', () {
    expect(PresenceLastSeenCodec.pingFrame(''), {'type': 'ping'});
    expect(
      PresenceLastSeenCodec.pingFrame(' uuid-on-device '),
      {'type': 'ping', 'deviceId': 'uuid-on-device'},
    );
  });

  test('normalizeUserIds dedupes and drops blanks', () {
    expect(
      PresenceLastSeenCodec.normalizeUserIds(
        ['usera', ' usera ', '', 'userb', 'usera'],
      ),
      ['usera', 'userb'],
    );
  });

  test('chunkUserIds respects 200 cap', () {
    final ids = List<String>.generate(401, (i) => 'u$i');
    final chunks = PresenceLastSeenCodec.chunkUserIds(ids);
    expect(chunks.length, 3);
    expect(chunks[0].length, 200);
    expect(chunks[1].length, 200);
    expect(chunks[2].length, 1);
  });

  test('parse presence_last_seen_ok maps', () {
    final batch = PresenceLastSeenCodec.parseBatch(<String, dynamic>{
      'type': 'presence_last_seen_ok',
      'requestId': 'viewport-1',
      'lastSeen': {'usera': 1700000000000, 'userb': 1710000000000},
      'lastActiveVisibility': {'usera': 'everyone', 'userb': 'hidden'},
      'ts': 1700000100000,
    });
    expect(batch.lastSeen['usera'], 1700000000000);
    expect(batch.lastSeen['userb'], 1710000000000);
    expect(batch.lastActiveVisibility['usera'], 'everyone');
    expect(batch.lastActiveVisibility['userb'], 'hidden');
    expect(
      PresenceLastSeenCodec.requestIdOf(<String, dynamic>{
        'requestId': 'viewport-1',
      }),
      'viewport-1',
    );
  });

  test('parse fail code TOO_MANY_INFLIGHT', () {
    expect(
      PresenceLastSeenCodec.failCodeOf(<String, dynamic>{
        'type': 'presence_last_seen_fail',
        'requestId': 'viewport-1',
        'code': 'TOO_MANY_INFLIGHT',
      }),
      PresenceLastSeenFailCode.tooManyInflight,
    );
  });

  test('TCP ready skips periodic HTTP heartbeat', () {
    expect(
      PresenceKeepAlivePolicy.shouldSendHttpHeartbeat(tcpReady: true),
      isFalse,
    );
    expect(
      PresenceKeepAlivePolicy.shouldSendHttpHeartbeat(tcpReady: false),
      isTrue,
    );
  });

  test('INVALID_INPUT does not fallback to HTTP', () {
    expect(
      const PresenceLastSeenTcpException(
        PresenceLastSeenFailCode.invalidInput,
      ).shouldFallbackToHttp,
      isFalse,
    );
    expect(
      const PresenceLastSeenTcpException(
        PresenceLastSeenFailCode.internal,
      ).shouldFallbackToHttp,
      isTrue,
    );
  });

  test('fetchPresenceLastSeen throws when TCP is not ready', () async {
    expect(
      FriendRealtimeService.instance.isRealtimeReady,
      isFalse,
    );
    try {
      await FriendRealtimeService.instance.fetchPresenceLastSeen(['usera']);
      fail('expected PresenceLastSeenTcpException');
    } on PresenceLastSeenTcpException catch (e) {
      expect(e.code, PresenceLastSeenFailCode.notConnected);
      expect(e.shouldFallbackToHttp, isTrue);
    }
  });

  test('empty userIds returns empty batch without TCP', () async {
    final batch =
        await FriendRealtimeService.instance.fetchPresenceLastSeen(const []);
    expect(batch.lastSeen, isEmpty);
    expect(batch.lastActiveVisibility, isEmpty);
  });
}
