import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_dispatch_service.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_im_payload.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_replay_guard.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_sent_store.dart';

void main() {
  group('WalletCardImPayload', () {
    test('group transfer and community id resolve as group', () {
      expect(
        WalletCardImPayload.resolveIsGroup({
          'type': 'wallet_group_transfer',
          'conversationId': 'u123',
        }),
        isTrue,
      );
      expect(
        WalletCardImPayload.resolveIsGroup({
          'type': 'wallet_red_packet',
          'isGroup': true,
          'conversationId': 'm25KMR3N5CY',
        }),
        isTrue,
      );
      expect(
        WalletCardImPayload.resolveIsGroup({
          'type': 'wallet_red_packet',
          'conversationId': 'm25KMR3N5CY',
        }),
        isTrue,
      );
    });

    test('c2c transfer resolves peer without group', () {
      final target = WalletCardImPayload.resolveTarget({
        'type': 'wallet_transfer',
        'isGroup': false,
        'conversationId': 'c2c_user99',
      });
      expect(target.isGroup, isFalse);
      expect(target.receiverUserId, 'user99');
      expect(target.groupId, isEmpty);
    });

    test('group payload strips group_ prefix', () {
      final target = WalletCardImPayload.resolveTarget({
        'type': 'wallet_red_packet',
        'isGroup': true,
        'conversationId': 'group_m25KMR3N5CY',
      });
      expect(target.isGroup, isTrue);
      expect(target.receiverUserId, isEmpty);
      expect(target.groupId, isNotEmpty);
    });

    test('custom data keeps order keys and greeting', () {
      final data = WalletCardImPayload.buildCustomData(
        {
          'type': 'wallet_red_packet',
          'orderId': '368',
          'clientOrderId': 'red_packet_a',
          'currency': '99',
          'amount': 8800,
          'status': 'success',
          'greeting': '恭喜发财',
          'packetType': 'LUCKY',
        },
        conversationId: 'm25KMR3N5CY',
      );
      expect(data['businessID'], 'wallet_order');
      expect(data['customType'], 'wallet_red_packet');
      expect(data['orderId'], '368');
      expect(data['clientOrderId'], 'red_packet_a');
      expect(data['amount'], 8800);
      expect(data['greeting'], '恭喜发财');
      expect(data['memo'], '恭喜发财');
      expect(data['packetType'], 'LUCKY');
    });
  });

  group('WalletCardDispatchService conversation match', () {
    tearDown(WalletCardDispatchService.instance.debugClear);

    test('takeForConversation matches group_ prefix with bare id', () {
      final svc = WalletCardDispatchService.instance;
      svc.enqueue({
        'clientOrderId': 'rp_1',
        'conversationId': 'group_m25KMR3N5CY',
        'sendSource': 'payment',
      });
      final taken = svc.takeForConversation('m25KMR3N5CY');
      expect(taken, hasLength(1));
      expect(taken.first['clientOrderId'], 'rp_1');
      expect(svc.pendingCount, 0);
    });

    test('takeForConversation does not mix c2c and group', () {
      final svc = WalletCardDispatchService.instance;
      svc.enqueue({
        'clientOrderId': 'tf_1',
        'conversationId': 'c2c_user99',
        'sendSource': 'payment',
      });
      expect(svc.takeForConversation('group_user99'), isEmpty);
      expect(svc.pendingCount, 1);
    });
  });

  group('WalletCardReplayGuard inflight', () {
    test('second begin is blocked until end', () {
      final guard = WalletCardReplayGuard(
        store: WalletCardSentStore(storage: MemoryWalletCardSentStorage()),
      );
      expect(
        guard.tryBeginSend(orderId: '368', clientOrderId: 'rp_1'),
        isTrue,
      );
      expect(
        guard.tryBeginSend(orderId: '368', clientOrderId: 'rp_1'),
        isFalse,
      );
      guard.endSend(orderId: '368', clientOrderId: 'rp_1');
      expect(
        guard.tryBeginSend(orderId: '368', clientOrderId: 'rp_1'),
        isTrue,
      );
    });
  });
}
