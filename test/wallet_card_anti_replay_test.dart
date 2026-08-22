import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_integrity.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_replay_guard.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_send_failure.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_sent_store.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_pending_recovery_service.dart';

void main() {
  group('WalletCardReplayGuard', () {
    late WalletCardReplayGuard guard;

    setUp(() {
      guard = WalletCardReplayGuard(
        store: WalletCardSentStore(storage: MemoryWalletCardSentStorage()),
      );
    });

    test('payment can send once then never again', () async {
      expect(
        await guard.allowSend(orderId: '368', source: WalletCardSendSource.payment),
        isTrue,
      );
      await guard.rememberImSent(orderId: '368', clientOrderId: 'red_packet_a');
      expect(
        await guard.allowSend(orderId: '368', source: WalletCardSendSource.payment),
        isFalse,
      );
      expect(
        await guard.allowSend(
          clientOrderId: 'red_packet_a',
          source: WalletCardSendSource.manual,
        ),
        isFalse,
      );
    });

    test('open conversation auto retry never sends even if IM mark missing', () async {
      await guard.rememberRestSuccess(orderId: '368');
      expect(
        await guard.allowSend(
          orderId: '368',
          source: WalletCardSendSource.autoRetry,
        ),
        isFalse,
      );
      expect(
        await guard.allowSend(
          orderId: '999',
          source: WalletCardSendSource.autoRetry,
        ),
        isFalse,
      );
    });

    test('recovery can send until IM success; autoRetry still blocked', () async {
      await guard.rememberRestSuccess(orderId: '368');
      expect(
        await guard.allowSend(
          orderId: '368',
          source: WalletCardSendSource.recovery,
        ),
        isTrue,
      );
      expect(
        await guard.allowSend(
          orderId: '368',
          source: WalletCardSendSource.autoRetry,
        ),
        isFalse,
      );
      await guard.rememberImSent(orderId: '368');
      expect(
        await guard.allowSend(
          orderId: '368',
          source: WalletCardSendSource.recovery,
        ),
        isFalse,
      );
    });

    test('manual retry allowed until IM success', () async {
      await guard.rememberRestSuccess(orderId: '368');
      expect(
        await guard.allowSend(orderId: '368', source: WalletCardSendSource.manual),
        isTrue,
      );
      await guard.rememberImSent(orderId: '368');
      expect(
        await guard.allowSend(orderId: '368', source: WalletCardSendSource.manual),
        isFalse,
      );
    });
  });

  group('WalletCardSendFailure', () {
    test('classifies duplicate and invalid rejects', () {
      expect(
        WalletCardSendFailure.classify(desc: 'WALLET_CARD_DUP'),
        WalletCardImReject.duplicate,
      );
      expect(
        WalletCardSendFailure.classify(code: 10004, desc: 'wallet_card_invalid'),
        WalletCardImReject.invalid,
      );
      expect(
        WalletCardSendFailure.classify(code: 80001, desc: 'timeout'),
        WalletCardImReject.none,
      );
    });

    test('duplicate outcome is delivered and not retried', () {
      final outcome = WalletCardSendFailure.outcomeOf(desc: 'WALLET_CARD_DUP');
      expect(outcome.delivered, isTrue);
      expect(outcome.shouldRetry, isFalse);
      expect(outcome.reject, WalletCardImReject.duplicate);
    });

    test('invalid outcome is terminal and not retried', () {
      final outcome = WalletCardSendFailure.outcomeOf(desc: 'WALLET_CARD_INVALID');
      expect(outcome.delivered, isFalse);
      expect(outcome.shouldRetry, isFalse);
      expect(outcome.reject, WalletCardImReject.invalid);
    });
  });

  group('WalletCardIntegrity', () {
    test('404 is invalid', () {
      expect(
        WalletCardIntegrity.evaluate(httpStatus: 404),
        WalletCardInvalidReason.notFound,
      );
    });

    test('sender mismatch is invalid', () {
      expect(
        WalletCardIntegrity.evaluate(
          restSenderUserId: 'alice',
          messageSender: 'bob',
        ),
        WalletCardInvalidReason.senderMismatch,
      );
    });

    test('matching sender is valid', () {
      expect(
        WalletCardIntegrity.evaluate(
          restSenderUserId: 'alice',
          messageSender: 'alice',
        ),
        WalletCardInvalidReason.none,
      );
    });

    test('group conversation mismatch is invalid', () {
      expect(
        WalletCardIntegrity.evaluate(
          restGroupId: 'm25KMR3N5CY',
          messageGroupId: 'otherGroup',
          isGroupMessage: true,
        ),
        WalletCardInvalidReason.conversationMismatch,
      );
    });

    test('c2c card with rest groupId is invalid', () {
      expect(
        WalletCardIntegrity.evaluate(
          restGroupId: 'm25KMR3N5CY',
          isGroupMessage: false,
        ),
        WalletCardInvalidReason.conversationMismatch,
      );
    });
  });

  group('WalletPendingRecoveryService.sendRetryableCards', () {
    test('offline or empty payloads send nothing', () async {
      var calls = 0;
      expect(
        await WalletPendingRecoveryService.sendRetryableCards(
          online: false,
          payloads: [
            {'orderId': '1'},
          ],
          send: (_) async {
            calls++;
            return true;
          },
        ),
        0,
      );
      expect(calls, 0);
      expect(
        await WalletPendingRecoveryService.sendRetryableCards(
          online: true,
          payloads: const [],
          send: (_) async {
            calls++;
            return true;
          },
        ),
        0,
      );
    });

    test('online sends retryable payloads and counts successes', () async {
      final sent = <String>[];
      final queued = await WalletPendingRecoveryService.sendRetryableCards(
        online: true,
        payloads: [
          {'orderId': 'ok'},
          {'orderId': 'fail'},
        ],
        send: (payload) async {
          final id = payload['orderId']?.toString() ?? '';
          sent.add(id);
          return id == 'ok';
        },
      );
      expect(queued, 1);
      expect(sent, ['ok', 'fail']);
    });
  });
}
