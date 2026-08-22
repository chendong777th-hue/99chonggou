import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/friend_request_poll_gate.dart';

void main() {
  group('shouldPollFriendRequests', () {
    test('skips when realtime ready', () {
      expect(shouldPollFriendRequests(realtimeReady: true), isFalse);
    });

    test('polls when realtime not ready', () {
      expect(shouldPollFriendRequests(realtimeReady: false), isTrue);
    });
  });
}
