import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';

void main() {
  group('walletDetailCoinCode', () {
    test('uses platform code 99 instead of display name 元', () {
      expect(
        walletDetailCoinCode(currency: '99', coin: '元'),
        WalletCurrency.platform,
      );
      expect(
        walletDetailCoinCode(currency: '元', coin: '元'),
        WalletCurrency.platform,
      );
      expect(
        walletDetailCoinCode(currency: null, coin: '元'),
        WalletCurrency.platform,
      );
      expect(
        walletDetailCoinCode(currency: '', coin: 'CNY'),
        WalletCurrency.platform,
      );
    });

    test('keeps USDT code stable', () {
      expect(
        walletDetailCoinCode(currency: 'USDT', coin: 'USDT'),
        'USDT',
      );
      expect(
        walletDetailCoinCode(currency: 'usdt', coin: ''),
        'USDT',
      );
    });
  });
}
