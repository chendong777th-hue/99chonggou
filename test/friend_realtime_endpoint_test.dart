import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_endpoint.dart';

void main() {
  test('https endpoint uses tls and port 443', () {
    final endpoint = FriendRealtimeEndpoint.parse('https://tcp.99chat.vip');
    expect(endpoint, isNotNull);
    expect(endpoint!.host, 'tcp.99chat.vip');
    expect(endpoint.port, 443);
    expect(endpoint.useTls, isTrue);
  });

  test('https endpoint keeps explicit port', () {
    final endpoint = FriendRealtimeEndpoint.parse(
      'https://tcp.99chat.vip:8082',
    );
    expect(endpoint, isNotNull);
    expect(endpoint!.host, 'tcp.99chat.vip');
    expect(endpoint.port, 8082);
    expect(endpoint.useTls, isTrue);
  });

  test('http endpoint with port stays plaintext', () {
    final endpoint = FriendRealtimeEndpoint.parse(
      'http://tcp.99chat.vip:8082',
    );
    expect(endpoint, isNotNull);
    expect(endpoint!.host, 'tcp.99chat.vip');
    expect(endpoint.port, 8082);
    expect(endpoint.useTls, isFalse);
  });

  test('bare host uses fallback plaintext port', () {
    final endpoint = FriendRealtimeEndpoint.parse(
      'tcp.99chat.vip',
      fallbackPort: 8082,
    );
    expect(endpoint, isNotNull);
    expect(endpoint!.host, 'tcp.99chat.vip');
    expect(endpoint.port, 8082);
    expect(endpoint.useTls, isFalse);
  });
}
