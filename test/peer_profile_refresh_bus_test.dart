import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';

void main() {
  final bus = PeerProfileRefreshBus.instance;

  setUp(bus.clear);

  test('matchesLatest only reports peers from the current notification', () {
    bus.notify('alice');
    expect(bus.matches('alice'), isTrue);
    expect(bus.matchesLatest('alice'), isTrue);

    bus.notify('bob');
    expect(bus.matches('alice'), isTrue);
    expect(bus.matchesLatest('alice'), isFalse);
    expect(bus.matchesLatest('bob'), isTrue);
  });

  test('notifyMany makes every peer in its batch the latest change', () {
    bus.notify('old-peer');
    bus.notifyMany(<String>['alice', 'bob']);

    expect(bus.matchesLatest('old-peer'), isFalse);
    expect(bus.matchesLatest('alice'), isTrue);
    expect(bus.matchesLatest('bob'), isTrue);
  });
}
