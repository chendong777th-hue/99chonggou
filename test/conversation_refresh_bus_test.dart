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

  test('同一防抖窗口保留每个事件自己的会话 ID', () {
    bus.requestRefresh(
      reason: 'friend_became_friends_sent',
      conversationId: 'c2c_peer_a',
      debounce: const Duration(hours: 1),
    );
    bus.requestRefresh(
      reason: 'new_message',
      debounce: Duration.zero,
    );
    expect(bus.lastEvents, hasLength(2));
    expect(bus.lastEvents.first.conversationId, 'c2c_peer_a');
    expect(bus.lastEvents.last.conversationId, isNull);
    expect(bus.lastReason, 'new_message');
    expect(bus.lastConversationId, isNull);
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
      debounce: Duration.zero,
    );
    expect(bus.lastConversationId, 'c2c_peer_b');
    expect(bus.lastReason, 'new_message');
  });

  test('退群与新消息在同一批次不会互相覆盖', () {
    bus.requestRefresh(
      reason: 'group_self_removed',
      conversationId: 'group_a',
      debounce: const Duration(hours: 1),
    );
    bus.requestRefresh(
      reason: 'new_message',
      conversationId: 'group_b',
      debounce: Duration.zero,
    );

    expect(bus.lastEvents, hasLength(2));
    expect(bus.lastEvents[0].reason, 'group_self_removed');
    expect(bus.lastEvents[0].conversationId, 'group_a');
    expect(bus.lastEvents[1].reason, 'new_message');
    expect(bus.lastEvents[1].conversationId, 'group_b');
  });

  test('刷新批次只允许最新调度提交一次', () {
    bus.requestRefresh(
      reason: 'group_metadata',
      conversationId: 'group_a',
      debounce: const Duration(hours: 1),
    );
    bus.requestRefresh(
      reason: 'new_message',
      conversationId: 'group_a',
      debounce: Duration.zero,
    );
    expect(bus.lastEvents, hasLength(2));
    expect(bus.lastEvents.last.reason, 'new_message');
  });
}
