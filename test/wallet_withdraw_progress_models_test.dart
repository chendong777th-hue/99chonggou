import 'package:flutter_test/flutter_test.dart';

import 'package:tencent_cloud_chat_demo/src/pages/wallet/progress/wallet_withdraw_progress_models.dart';

void main() {
  group('WalletWithdrawProgressStage', () {
    test('maps backend status to stage', () {
      expect(
        WalletWithdrawProgressStage.fromApi(status: 'BROADCASTING'),
        WalletWithdrawProgressStage.broadcasting,
      );
      expect(
        WalletWithdrawProgressStage.fromApi(status: 'CONFIRMING'),
        WalletWithdrawProgressStage.confirming,
      );
      expect(
        WalletWithdrawProgressStage.fromApi(status: 'COMPLETED'),
        WalletWithdrawProgressStage.completed,
      );
      expect(
        WalletWithdrawProgressStage.fromApi(status: 'FAILED'),
        WalletWithdrawProgressStage.failed,
      );
    });

    test('prefers explicit stage field', () {
      expect(
        WalletWithdrawProgressStage.fromApi(
          stage: 'CONFIRMING',
          status: 'PENDING',
        ),
        WalletWithdrawProgressStage.confirming,
      );
    });
  });

  group('WalletWithdrawProgressSnapshot', () {
    test('builds from order map with short hash', () {
      final snapshot = WalletWithdrawProgressSnapshot.fromOrderMap(
        {
          'id': 'WD123',
          'clientOrderId': 'WD123',
          'status': 'CONFIRMING',
          'confirmations': 8,
          'requiredConfirmations': 19,
          'txId': '6fb2e6026c2e4d72d5b7af3dd2ad0e91ba2f43987de4f43e621cf3c55a1029af',
        },
        amountText: '12.00',
        coin: 'USDT',
        network: 'TRC20',
      );

      expect(snapshot.orderId, 'WD123');
      expect(snapshot.stage, WalletWithdrawProgressStage.confirming);
      expect(snapshot.confirmations, 8);
      expect(snapshot.txHashShort, contains('…'));
    });
  });
}
