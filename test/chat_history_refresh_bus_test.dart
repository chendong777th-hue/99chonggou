import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_refresh_bus.dart';

void main() {
  group('ChatHistoryRefreshBus', () {
    test('skips history reload for wallet outbound reasons', () {
      expect(
        ChatHistoryRefreshBus.skipsHistoryReload('wallet_card_sent'),
        isTrue,
      );
      expect(
        ChatHistoryRefreshBus.skipsHistoryReload('wallet_message_sent'),
        isTrue,
      );
      expect(
        ChatHistoryRefreshBus.skipsHistoryReload('external_message_sent'),
        isFalse,
      );
    });

    test('wallet refresh does not bump revision', () {
      final bus = ChatHistoryRefreshBus.instance;
      final before = bus.revision.value;
      bus.requestRefresh(
        conversationId: 'c2c_peer_a',
        reason: 'wallet_message_sent',
      );
      expect(bus.revision.value, before);
      expect(bus.lastReason, 'wallet_message_sent');
      expect(bus.lastConversationId, 'c2c_peer_a');
    });

    test('coalesces duplicate refresh for same conversation', () async {
      final bus = ChatHistoryRefreshBus.instance;
      var fires = 0;
      void listener() => fires++;
      bus.revision.addListener(listener);
      addTearDown(() => bus.revision.removeListener(listener));

      bus.requestRefresh(
        conversationId: 'c2c_peer_b',
        reason: 'im_reconnected',
        delay: const Duration(milliseconds: 40),
      );
      bus.requestRefresh(
        conversationId: 'c2c_peer_b',
        reason: 'im_reconnected',
        delay: const Duration(milliseconds: 40),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fires, 1);
    });
  });
}
