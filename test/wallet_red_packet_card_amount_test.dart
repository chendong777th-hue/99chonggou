import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_store.dart';

void main() {
  test('local red packet card uses the same amount format as the API card', () {
    const fen = 8800;
    final local = WalletStore.buildLocalOrderCard(
      type: 'wallet_red_packet',
      currency: WalletCurrency.platform,
      amount: fen,
      status: 'success',
      greeting: '恭喜发财，大吉大利',
    );

    expect(local, isNotNull);
    expect(local!.amount, formatWalletAmount(WalletCurrency.platform, fen));
    expect(local.amount, '88.00');
    expect(local.coin, walletDisplayCoin(WalletCurrency.platform));
  });

  test('local USDT card matches formatUsdtMicro', () {
    const micro = 1234000;
    final local = WalletStore.buildLocalOrderCard(
      type: 'wallet_red_packet',
      currency: WalletCurrency.usdt,
      amount: micro,
      status: 'pending',
    );

    expect(local, isNotNull);
    expect(local!.amount, formatWalletAmount(WalletCurrency.usdt, micro));
    expect(local.amount, '1.234');
  });

  test('retainWalletCardDisplayAmount keeps previous amount over empty refresh', () {
    const previous = WalletOrderCardDto(
      ok: true,
      type: 'wallet_red_packet',
      status: 'success',
      amount: '88.00',
      coin: '元',
      title: '红包',
      msg: '恭喜发财，大吉大利',
    );
    const next = WalletOrderCardDto(
      ok: true,
      type: 'wallet_red_packet',
      status: 'pending',
      amount: '',
      coin: '',
      title: '红包',
      msg: '恭喜发财，大吉大利',
    );

    final retained = retainWalletCardDisplayAmount(
      next: next,
      previous: previous,
    );
    expect(retained.amount, '88.00');
    expect(retained.coin, '元');
    expect(retained.status, 'pending');
  });

  test('retainWalletCardDisplayAmount does not block a real amount update', () {
    const previous = WalletOrderCardDto(
      ok: true,
      type: 'wallet_red_packet',
      status: 'success',
      amount: '88.00',
      coin: '元',
      title: '红包',
      msg: '恭喜发财，大吉大利',
    );
    const next = WalletOrderCardDto(
      ok: true,
      type: 'wallet_red_packet',
      status: 'success',
      amount: '10.00',
      coin: '元',
      title: '红包',
      msg: '恭喜发财，大吉大利',
    );

    final retained = retainWalletCardDisplayAmount(
      next: next,
      previous: previous,
    );
    expect(retained.amount, '10.00');
  });

  test('local transfer card builds without amount to avoid loading flash', () {
    final local = WalletStore.buildLocalOrderCard(
      type: 'wallet_transfer',
      currency: WalletCurrency.platform,
      amount: null,
      status: 'pending',
    );

    expect(local, isNotNull);
    expect(local!.ok, isTrue);
    expect(local.type, 'wallet_transfer');
    expect(local.amount, isEmpty);
    expect(local.coin, isNotEmpty);
  });

  test('local group transfer card builds without amount', () {
    final local = WalletStore.buildLocalOrderCard(
      type: 'wallet_group_transfer',
      amount: null,
      status: 'SUCCESS',
    );

    expect(local, isNotNull);
    expect(local!.type, 'wallet_group_transfer');
    expect(local.status, 'success');
  });

  test('quiet merge ignores title/msg churn within same visual family', () {
    const previous = WalletOrderCardDto(
      ok: true,
      type: 'wallet_transfer',
      status: 'pending',
      amount: '10.00',
      coin: '元',
      title: '转账',
      msg: '',
    );
    const next = WalletOrderCardDto(
      ok: true,
      type: 'wallet_transfer',
      status: 'pending',
      amount: '10.00',
      coin: '元',
      title: '转账详情',
      msg: '处理中',
    );

    expect(
      walletCardQuietMergeNeedsRebuild(previous: previous, next: next),
      isFalse,
    );
  });

  test('quiet merge rebuilds when visual family changes', () {
    const previous = WalletOrderCardDto(
      ok: true,
      type: 'wallet_red_packet',
      status: 'pending',
      amount: '8.00',
      coin: '元',
      title: '红包',
      msg: '恭喜发财，大吉大利',
    );
    const next = WalletOrderCardDto(
      ok: true,
      type: 'wallet_red_packet',
      status: 'claimed',
      amount: '8.00',
      coin: '元',
      title: '红包',
      msg: '恭喜发财，大吉大利',
    );

    expect(
      walletCardQuietMergeNeedsRebuild(previous: previous, next: next),
      isTrue,
    );
    expect(walletCardVisualFamily('pending'), 'available');
    expect(walletCardVisualFamily('claimed'), 'inactive');
  });

  test('quiet merge rebuilds when amount fills in', () {
    const previous = WalletOrderCardDto(
      ok: true,
      type: 'wallet_transfer',
      status: 'pending',
      amount: '',
      coin: '元',
      title: '转账',
      msg: '',
    );
    const next = WalletOrderCardDto(
      ok: true,
      type: 'wallet_transfer',
      status: 'pending',
      amount: '12.00',
      coin: '元',
      title: '转账',
      msg: '',
    );

    expect(
      walletCardQuietMergeNeedsRebuild(previous: previous, next: next),
      isTrue,
    );
  });
}
