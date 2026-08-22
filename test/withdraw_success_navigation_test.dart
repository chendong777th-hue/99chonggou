import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_order.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/record/wallet_record_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/withdraw_success_navigation.dart';

void main() {
  group('WithdrawSuccessNavigation', () {
    test('chainWithdrawSuccessCopy uses submitted copy for pending orders', () {
      final copy = WithdrawSuccessNavigation.chainWithdrawSuccessCopy(
        WalletOrderResult(
          ok: true,
          state: WalletOrderState.pending,
          orderId: 'WD123',
        ),
      );
      expect(copy.title, isNotEmpty);
      expect(copy.message, isNotEmpty);
    });

    test('buildChainWithdrawRecord marks chain withdraw detail fields', () {
      final record = WithdrawSuccessNavigation.buildChainWithdrawRecord(
        result: WalletOrderResult(
          ok: true,
          state: WalletOrderState.pending,
          orderId: 'WD123',
          clientOrderId: 'WD123',
          data: const {'status': 'PENDING'},
        ),
        toAddress: 'TAjR2bhqd9EKbeH78JUDsPSGGv3ev6TBnz',
        fromAddress: 'TP4TT7nd1UEf52K2VXL3678qGbPMYnKaqj',
        amountMinor: 12000000,
        feeMinor: 1000000,
        payMethod: const WalletPayMethodDto(
          id: 'usdt',
          coin: 'USDT',
          net: 'TRC20',
          bal: '10',
          fiat: '\$10',
          balMinor: 10000000,
          scale: 6,
          feeMinor: 1000000,
          feeCoin: 'USDT',
          feeScale: 6,
          feeBalanceMinor: 10000000,
          color: Color(0xFF26A17B),
          badgeColor: Color(0xFF26A17B),
          badge: 'T',
        ),
      );

      expect(record.isChainWithdraw, isTrue);
      expect(record.payee, '外部地址');
      expect(record.addr, 'TAjR2bhqd9EKbeH78JUDsPSGGv3ev6TBnz');
      expect(record.status, WalletRecordStatus.pending);
      expect(record.orderNo, 'WD123');
    });

    test('buildFriendTransferRecord marks internal transfer detail fields', () {
      final record = WithdrawSuccessNavigation.buildFriendTransferRecord(
        result: WalletOrderResult(
          ok: true,
          state: WalletOrderState.success,
          orderId: 'TF456',
          clientOrderId: 'TF456',
        ),
        payMethod: const WalletPayMethodDto(
          id: 'usdt',
          coin: 'USDT',
          net: 'TRC20',
          bal: '10',
          fiat: '\$10',
          balMinor: 10000000,
          scale: 6,
          feeMinor: 0,
          feeCoin: 'USDT',
          feeScale: 6,
          feeBalanceMinor: 0,
          color: Color(0xFF26A17B),
          badgeColor: Color(0xFF26A17B),
          badge: 'T',
        ),
        targetUserId: 'user001',
        targetName: '张三',
        amountMinor: 8800000,
      );

      expect(record.isInternalTransfer, isTrue);
      expect(record.isChainWithdraw, isFalse);
      expect(record.payee, '张三');
      expect(record.status, WalletRecordStatus.success);
    });
  });
}
