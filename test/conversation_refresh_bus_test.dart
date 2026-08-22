import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';

void main() {
  late ConversationRefreshBus bus;

  setUp(() {
    bus = ConversationRefreshBus.instance;
    bus.resetForTest();
  });

  tearDown(() {
    bus.resetForTest();
  });

  test('省略 conversationId 时保留上一笔会话 ID', () {
    bus.requestRefresh(
      reason: 'friend_became_friends_sent',
      conversationId: 'c2c_peer_a',
      debounce: const Duration(hours: 1),
    );
    expect(bus.lastConversationId, 'c2c_peer_a');
    expect(bus.lastReason, 'friend_became_friends_sent');

    bus.requestRefresh(
      reason: 'friend_list_changed',
      debounce: const Duration(hours: 1),
    );
    expect(bus.lastConversationId, 'c2c_peer_a');
    expect(bus.lastReason, 'friend_list_changed');
  });

  test('显式传入新 conversationId 时覆盖上一笔', () {
    bus.requestRefresh(
      reason: 'friend_became_friends_sent',
      conversationId: 'c2c_peer_a',
      debounce: const Duration(hours: 1),
    );
    bus.requestRefresh(
      reason: 'new_message',
      conversationId: 'c2c_peer_b',
      debounce: const Duration(hours: 1),
    );
    expect(bus.lastConversationId, 'c2c_peer_b');
    expect(bus.lastReason, 'new_message');
  });
}
