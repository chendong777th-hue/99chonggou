import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

import 'order/wallet_order.dart';
import 'record/wallet_record_models.dart';
import 'red_packet/red_packet_member.dart';

const String kWalletMockPayMode = String.fromEnvironment(
  'WALLET_MOCK_PAY_MODE',
  defaultValue: 'pending',
);

abstract class WalletRepository {
  Future<WalletDto> getWallet();
  Future<List<WalletPayMethodDto>> getPayMethods();
  Future<WalletOrderResult> transfer(WalletTransferReq req);
  Future<WalletOrderResult> withdraw(WalletWithdrawReq req);
  Future<WalletOrderResult> sendRedPacket(WalletRedPacketReq req);
  Future<WalletExchangeOrderDto> exchange(WalletExchangeReq req);
  Future<List<WalletExchangeOrderDto>> getExchangeRecords({
    int page = 0,
    int size = 20,
  });
  Future<WalletOrderResult> queryOrderStatus(WalletOrderDraft draft);
  Future<WalletOrderCardDto> getWalletOrderCard({
    required String type,
    required String orderId,
    required String clientOrderId,
    String? currency,
    int? amount,
    String? status,
    String? greeting,
  });
  Future<List<WalletRecordDto>> getWalletRecords();
  Future<List<WalletRecordDto>> getWalletRecordsByFilter(
    HistoryRecordFilter filter,
  );
  Future<List<WalletRecordDto>> getWalletRecordsByType(WalletRecordType type);
  Future<List<WalletRecordDto>> getDepositRecords();
  Future<List<WalletRecordDto>> getWithdrawRecords();
  Future<WalletOrderResult> claimRedPacket({
    required String orderId,
    String? payPin,
  });
  Future<List<RedPacketMember>> getRedPacketMembers(String conversationId);
}

class MockWalletRepository implements WalletRepository {
  static const List<WalletPayMethodDto> _payMethods = [
    WalletPayMethodDto(
      id: 'usdt_bep20',
      coin: 'USDT',
      net: 'Binance Smart Chain(BEP20)',
      bal: '88.88',
      fiat: '\$88.88',
      balMinor: 88880000,
      scale: 6,
      feeMinor: 0,
      feeCoin: 'BNB',
      feeScale: 18,
      feeBalanceMinor: 0,
      color: Color(0xFF26A17B),
      badgeColor: Color(0xFFF0B90B),
      badge: 'B',
    ),
    WalletPayMethodDto(
      id: 'usdt_erc20',
      coin: 'USDT',
      net: 'Ethereum(ERC20)',
      bal: '88.88',
      fiat: '\$88.88',
      balMinor: 88880000,
      scale: 6,
      feeMinor: 0,
      feeCoin: 'ETH',
      feeScale: 18,
      feeBalanceMinor: 0,
      color: Color(0xFF26A17B),
      badgeColor: Color(0xFF8299E8),
      badge: 'E',
    ),
    WalletPayMethodDto(
      id: 'usdt_trc20',
      coin: 'USDT',
      net: 'Tron(TRC20)',
      bal: '88.88',
      fiat: '\$88.88',
      balMinor: 88880000,
      scale: 6,
      feeMinor: 1000000,
      feeCoin: 'TRX',
      feeScale: 6,
      feeBalanceMinor: 88880000,
      color: Color(0xFF26A17B),
      badgeColor: Color(0xFFFF001F),
      badge: 'T',
    ),
    WalletPayMethodDto(
      id: 'usdt_spl',
      coin: 'USDT',
      net: 'Solana(SPL)',
      bal: '88.88',
      fiat: '\$88.88',
      balMinor: 88880000,
      scale: 6,
      feeMinor: 0,
      feeCoin: 'SOL',
      feeScale: 9,
      feeBalanceMinor: 0,
      color: Color(0xFF26A17B),
      badgeColor: Color(0xFF3C2CEB),
      badge: 'S',
    ),
    WalletPayMethodDto(
      id: 'btc',
      coin: 'BTC',
      net: 'Bitcoin(BTC)',
      bal: '0.0888',
      fiat: '\$8888.00',
      balMinor: 8880000,
      scale: 8,
      feeMinor: 0,
      feeCoin: 'BTC',
      feeScale: 8,
      feeBalanceMinor: 0,
      color: Color(0xFFFF9814),
      badgeColor: Color(0xFFF6A100),
      badge: 'B',
    ),
    WalletPayMethodDto(
      id: 'eth',
      coin: 'ETH',
      net: 'Ethereum(ERC20)',
      bal: '8.88',
      fiat: '\$8888.00',
      balMinor: 888000000,
      scale: 8,
      feeMinor: 0,
      feeCoin: 'ETH',
      feeScale: 18,
      feeBalanceMinor: 0,
      color: Color(0xFFB8C8F5),
      badgeColor: Color(0xFF8299E8),
      badge: 'E',
    ),
  ];

  @override
  Future<WalletDto> getWallet() async {
    await Future.delayed(const Duration(milliseconds: 700));
    return const WalletDto(
      totalBal: '99999.99',
      totalBalUsd: '13793.10',
      trxAddr: 'TP4TT7nd1UEf52K2VXL3678qGbPMYnKaqj',
      coins: [
        CoinDto(
          name: '99币',
          sub: '¥1',
          bal: '1.24',
          fiat: '¥1.24',
          type: CoinType.cny,
          code: '99',
          platformCoin: true,
          depositEnabled: false,
          withdrawEnabled: false,
          balMinor: 124,
          scale: 2,
        ),
        CoinDto(
          name: 'USDT',
          sub: '¥6.7814',
          bal: '0.00',
          fiat: '¥0.00',
          type: CoinType.usdt,
          code: 'USDT',
          balMinor: 0,
          scale: 6,
          priceChangePercent: 0.12,
        ),
      ],
    );
  }

  @override
  Future<List<WalletPayMethodDto>> getPayMethods() async {
    await Future.delayed(const Duration(milliseconds: 280));
    final wallet = await getWallet();
    return wallet.coins
        .map(
          (coin) => coin.toPayMethod(
            net: coin.platformCoin ? '平台币' : 'TRC20',
          ),
        )
        .toList();
  }

  WalletOrderResult _mockResult({
    required String type,
    required String prefix,
    required String clientOrderId,
    required String pendingMsg,
  }) {
    final orderId = '$prefix${DateTime.now().millisecondsSinceEpoch}';
    final mode = kWalletMockPayMode.trim().toLowerCase();

    if (mode == 'success') {
      return WalletOrderResult(
        ok: true,
        state: WalletOrderState.success,
        msg: AppI18n.current.t(
          zhHans: '支付成功',
          zhHant: '支付成功',
          en: 'Payment successful',
          ja: '支払いが完了しました',
          ko: '결제가 완료되었습니다',
        ),
        clientOrderId: clientOrderId,
        orderId: orderId,
        data: {
          'type': type,
          'clientOrderId': clientOrderId,
          'orderId': orderId,
        },
      );
    }

    if (mode == 'failed' || mode == 'fail') {
      return WalletOrderResult(
        ok: false,
        state: WalletOrderState.failed,
        err: WalletOrderErr.networkError,
        msg: AppI18n.current.t(
          zhHans: '模拟支付失败',
          zhHant: '模擬支付失敗',
          en: 'Mock payment failed',
          ja: '模擬支払いに失敗しました',
          ko: '모의 결제에 실패했습니다',
        ),
        clientOrderId: clientOrderId,
        orderId: orderId,
      );
    }

    return WalletOrderResult(
      ok: true,
      state: WalletOrderState.pending,
      msg: pendingMsg,
      clientOrderId: clientOrderId,
      orderId: orderId,
      data: {
        'type': type,
        'clientOrderId': clientOrderId,
        'orderId': orderId,
      },
    );
  }

  @override
  Future<WalletOrderResult> transfer(WalletTransferReq req) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final pay = _findPay(req.payId);

    if (req.clientOrderId.trim().isEmpty) {
      return WalletOrderResult(
        ok: false,
        state: WalletOrderState.failed,
        err: WalletOrderErr.duplicateSubmit,
        msg: AppI18n.current.t(
          zhHans: '订单状态异常，请重试',
          zhHant: '訂單狀態異常，請重試',
          en: 'Order status error. Please try again.',
          ja: '注文状態が異常です。もう一度お試しください。',
          ko: '주문 상태가 올바르지 않습니다. 다시 시도해 주세요.',
        ),
      );
    }
    if (req.pwd.length != 6 || req.pwd == '000000') {
      return WalletOrderResult(ok: false, state: WalletOrderState.failed, err: WalletOrderErr.passwordWrong, msg: WalletOrderErr.passwordWrong.text, clientOrderId: req.clientOrderId);
    }
    final amountMinor = int.tryParse(req.amountMinor) ?? 0;
    if (amountMinor <= 0) {
      return WalletOrderResult(ok: false, state: WalletOrderState.failed, err: WalletOrderErr.invalidAmount, msg: WalletOrderErr.invalidAmount.text, clientOrderId: req.clientOrderId);
    }
    if (!_hasEnough(amountMinor: amountMinor, pay: pay)) {
      final feeCoin = pay.feeCoin.isEmpty ? pay.coin : pay.feeCoin;
      final err = feeCoin == pay.coin ? WalletOrderErr.insufficientBalance : WalletOrderErr.insufficientFee;
      return WalletOrderResult(ok: false, state: WalletOrderState.failed, err: err, msg: err.text, clientOrderId: req.clientOrderId);
    }

    return _mockResult(
      type: 'wallet_transfer',
      prefix: 'TF',
      clientOrderId: req.clientOrderId,
      pendingMsg: AppI18n.current.t(
        zhHans: '交易已提交，可在记录中查看',
        zhHant: '交易已提交，可在記錄中查看',
        en: 'Transaction submitted. Check History for updates.',
        ja: '取引を送信しました。履歴で確認できます。',
        ko: '거래가 제출되었습니다. 기록에서 확인할 수 있습니다.',
      ),
    );
  }

  @override
  Future<WalletOrderResult> withdraw(WalletWithdrawReq req) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final pay = _findPay(req.payId);

    if (req.clientOrderId.trim().isEmpty) {
      return WalletOrderResult(
        ok: false,
        state: WalletOrderState.failed,
        err: WalletOrderErr.duplicateSubmit,
        msg: AppI18n.current.t(
          zhHans: '订单状态异常，请重试',
          zhHant: '訂單狀態異常，請重試',
          en: 'Order status error. Please try again.',
          ja: '注文状態が異常です。もう一度お試しください。',
          ko: '주문 상태가 올바르지 않습니다. 다시 시도해 주세요.',
        ),
      );
    }
    if (req.pwd.length != 6 || req.pwd == '000000') {
      return WalletOrderResult(
        ok: false,
        state: WalletOrderState.failed,
        err: WalletOrderErr.passwordWrong,
        msg: WalletOrderErr.passwordWrong.text,
        clientOrderId: req.clientOrderId,
      );
    }
    if (!RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$').hasMatch(req.toAddress.trim())) {
      return WalletOrderResult(
        ok: false,
        state: WalletOrderState.failed,
        err: WalletOrderErr.invalidReceiver,
        msg: AppI18n.current.t(
          zhHans: 'TRON 地址无效',
          zhHant: 'TRON 地址無效',
          en: 'Invalid TRON address',
          ja: 'TRONアドレスが無効です',
          ko: 'TRON 주소가 올바르지 않습니다',
        ),
        clientOrderId: req.clientOrderId,
      );
    }
    final amountMinor = int.tryParse(req.amountMinor) ?? 0;
    if (amountMinor < 1000000) {
      return WalletOrderResult(
        ok: false,
        state: WalletOrderState.failed,
        err: WalletOrderErr.invalidAmount,
        msg: AppI18n.current.t(
          zhHans: '金额不正确',
          zhHant: '金額不正確',
          en: 'Invalid amount',
          ja: '金額が正しくありません',
          ko: '금액이 올바르지 않습니다',
        ),
        clientOrderId: req.clientOrderId,
      );
    }
    const feeMinor = 1000000;
    if (amountMinor + feeMinor > pay.balMinor) {
      return WalletOrderResult(
        ok: false,
        state: WalletOrderState.failed,
        err: WalletOrderErr.insufficientBalance,
        msg: WalletOrderErr.insufficientBalance.text,
        clientOrderId: req.clientOrderId,
      );
    }

    return WalletOrderResult(
      ok: true,
      state: WalletOrderState.pending,
      msg: AppI18n.current.t(
        zhHans: '提现已提交，可在记录中查看',
        zhHant: '提現已提交，可在記錄中查看',
        en: 'Withdrawal submitted. Check History for updates.',
        ja: '出金を送信しました。履歴で確認できます。',
        ko: '출금이 제출되었습니다. 기록에서 확인할 수 있습니다.',
      ),
      clientOrderId: req.clientOrderId,
      orderId: 'WD${DateTime.now().millisecondsSinceEpoch}',
      data: {
        'type': 'wallet_withdraw',
        'clientOrderId': req.clientOrderId,
      },
    );
  }

  @override
  Future<WalletOrderResult> sendRedPacket(WalletRedPacketReq req) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final pay = _findPay(req.payId);

    if (req.clientOrderId.trim().isEmpty) {
      return WalletOrderResult(
        ok: false,
        state: WalletOrderState.failed,
        err: WalletOrderErr.duplicateSubmit,
        msg: AppI18n.current.t(
          zhHans: '订单状态异常，请重试',
          zhHant: '訂單狀態異常，請重試',
          en: 'Order status error. Please try again.',
          ja: '注文状態が異常です。もう一度お試しください。',
          ko: '주문 상태가 올바르지 않습니다. 다시 시도해 주세요.',
        ),
      );
    }
    if (req.pwd.length != 6 || req.pwd == '000000') {
      return WalletOrderResult(ok: false, state: WalletOrderState.failed, err: WalletOrderErr.passwordWrong, msg: WalletOrderErr.passwordWrong.text, clientOrderId: req.clientOrderId);
    }
    final totalMinor = int.tryParse(req.totalMinor) ?? 0;
    if (totalMinor <= 0) {
      return WalletOrderResult(
        ok: false,
        state: WalletOrderState.failed,
        err: WalletOrderErr.invalidAmount,
        msg: AppI18n.current.t(
          zhHans: '红包金额不正确',
          zhHant: '紅包金額不正確',
          en: 'Invalid red packet amount',
          ja: '紅包の金額が正しくありません',
          ko: '레드패킷 금액이 올바르지 않습니다',
        ),
        clientOrderId: req.clientOrderId,
      );
    }
    if (!_hasEnough(amountMinor: totalMinor, pay: pay)) {
      final feeCoin = pay.feeCoin.isEmpty ? pay.coin : pay.feeCoin;
      final err = feeCoin == pay.coin ? WalletOrderErr.insufficientBalance : WalletOrderErr.insufficientFee;
      return WalletOrderResult(ok: false, state: WalletOrderState.failed, err: err, msg: err.text, clientOrderId: req.clientOrderId);
    }

    return _mockResult(
      type: 'wallet_red_packet',
      prefix: 'RP',
      clientOrderId: req.clientOrderId,
      pendingMsg: AppI18n.current.t(
        zhHans: '红包已提交，可在聊天和记录中查看',
        zhHant: '紅包已提交，可在聊天和記錄中查看',
        en: 'Red packet submitted. Check chat and History.',
        ja: '紅包を送信しました。チャットと履歴で確認できます。',
        ko: '레드패킷이 제출되었습니다. 채팅과 기록에서 확인할 수 있습니다.',
      ),
    );
  }

  @override
  Future<WalletExchangeOrderDto> exchange(WalletExchangeReq req) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final pay = _findPay(req.direction == WalletExchangeDirection.usdtToPlatform
        ? WalletCurrency.usdt
        : WalletCurrency.platform);
    if (req.payPin.length != 6 || req.payPin == '000000') {
      throw WalletSubmitException(
        requestSent: false,
        message: WalletOrderErr.passwordWrong.text,
      );
    }
    if (req.amount <= 0) {
      throw WalletSubmitException(
        requestSent: false,
        message: WalletOrderErr.invalidAmount.text,
      );
    }
    if (req.amount > pay.balMinor) {
      throw WalletSubmitException(
        requestSent: false,
        message: WalletOrderErr.insufficientBalance.text,
      );
    }
    const usdCny = 7.2;
    const markupBps = 0;
    const floatBps = 50;
    const factor = floatBps / 10000.0;
    const base = usdCny * (1 + markupBps / 10000.0);
    final quoted = req.direction == WalletExchangeDirection.usdtToPlatform
        ? base * (1 - factor)
        : base * (1 + factor);
    final output = req.direction == WalletExchangeDirection.usdtToPlatform
        ? (((req.amount / 1000000.0) * quoted) * 100).floor()
        : (((req.amount / 100.0) / quoted) * 1000000).floor();
    if (output <= 0) {
      throw WalletSubmitException(
        requestSent: false,
        message: AppI18n.current.t(
          zhHans: '金额不正确',
          zhHant: '金額不正確',
          en: 'Invalid amount',
          ja: '金額が正しくありません',
          ko: '금액이 올바르지 않습니다',
        ),
      );
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return WalletExchangeOrderDto(
      id: id,
      userId: 'mock_user',
      direction: req.direction,
      inputAmount: req.amount,
      outputAmount: output,
      surplusFen: req.direction == WalletExchangeDirection.usdtToPlatform
          ? ((((req.amount / 1000000.0) * base) * 100).floor() - output).clamp(0, 1 << 30)
          : 0,
      rateSnapshot: '{"usdCny":7.2,"markupBps":0,"floatBps":50}',
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Future<List<WalletExchangeOrderDto>> getExchangeRecords({
    int page = 0,
    int size = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      WalletExchangeOrderDto(
        id: 'ex_001',
        userId: 'mock_user',
        direction: WalletExchangeDirection.usdtToPlatform,
        inputAmount: 1000000,
        outputAmount: 716,
        surplusFen: 0,
        rateSnapshot: '{"usdCny":7.2,"markupBps":0,"floatBps":50}',
        createdAt: '2026-05-23T12:00:00Z',
      ),
      WalletExchangeOrderDto(
        id: 'ex_002',
        userId: 'mock_user',
        direction: WalletExchangeDirection.platformToUsdt,
        inputAmount: 1000,
        outputAmount: 1385046,
        surplusFen: 0,
        rateSnapshot: '{"usdCny":7.2,"markupBps":0,"floatBps":50}',
        createdAt: '2026-05-22T10:00:00Z',
      ),
    ];
  }

  @override
  Future<WalletOrderResult> queryOrderStatus(WalletOrderDraft draft) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final state = draft.retryCount >= 1 ? WalletOrderState.success : WalletOrderState.pending;
    return WalletOrderResult(
      ok: true,
      state: state,
      msg: state == WalletOrderState.success
          ? AppI18n.current.t(
              zhHans: '交易成功',
              zhHant: '交易成功',
              en: 'Transaction successful',
              ja: '取引が成功しました',
              ko: '거래가 성공했습니다',
            )
          : AppI18n.current.t(
              zhHans: '交易处理中，可稍后刷新',
              zhHant: '交易處理中，可稍後刷新',
              en: 'Transaction processing. Refresh later for updates.',
              ja: '取引処理中です。後で更新してください。',
              ko: '거래 처리 중입니다. 나중에 새로고침해 주세요.',
            ),
      clientOrderId: draft.clientOrderId,
      orderId: draft.serverOrderId.isNotEmpty ? draft.serverOrderId : draft.clientOrderId,
      data: {
        'type': draft.type == WalletOrderType.redPacket ? 'wallet_red_packet' : 'wallet_transfer',
        'clientOrderId': draft.clientOrderId,
        'orderId': draft.serverOrderId.isNotEmpty ? draft.serverOrderId : draft.clientOrderId,
      },
    );
  }

  @override
  Future<WalletOrderCardDto> getWalletOrderCard({
    required String type,
    required String orderId,
    required String clientOrderId,
    String? currency,
    int? amount,
    String? status,
    String? greeting,
  }) async {
    await Future.delayed(const Duration(milliseconds: 260));
    if (orderId.trim().isEmpty && clientOrderId.trim().isEmpty) {
      return WalletOrderCardDto(
        ok: false,
        type: '',
        status: 'failed',
        amount: '',
        coin: '',
        title: AppI18n.current.t(
          zhHans: '订单异常',
          zhHant: '訂單異常',
          en: 'Order error',
          ja: '注文エラー',
          ko: '주문 오류',
        ),
        msg: AppI18n.current.t(
          zhHans: '订单信息不完整',
          zhHant: '訂單資訊不完整',
          en: 'Order information is incomplete.',
          ja: '注文情報が不完全です。',
          ko: '주문 정보가 불완전합니다.',
        ),
      );
    }
    if (type == 'wallet_red_packet') {
      return const WalletOrderCardDto(ok: true, type: 'wallet_red_packet', status: 'pending', amount: '88.88', coin: 'USDT', title: '红包', msg: '恭喜发财，大吉大利');
    }
    if (type == 'wallet_transfer') {
      return const WalletOrderCardDto(ok: true, type: 'wallet_transfer', status: 'pending', amount: '88.88', coin: 'USDT', title: '转账', msg: '处理中');
    }
    return WalletOrderCardDto(
      ok: false,
      type: '',
      status: 'failed',
      amount: '',
      coin: '',
      title: AppI18n.current.t(
        zhHans: '订单异常',
        zhHant: '訂單異常',
        en: 'Order error',
        ja: '注文エラー',
        ko: '주문 오류',
      ),
      msg: AppI18n.current.t(
        zhHans: '未知订单类型',
        zhHant: '未知訂單類型',
        en: 'Unknown order type.',
        ja: '不明な注文タイプです。',
        ko: '알 수 없는 주문 유형입니다.',
      ),
    );
  }

  @override
  Future<List<RedPacketMember>> getRedPacketMembers(String conversationId) async {
    await Future.delayed(const Duration(milliseconds: 320));

    return const [
      RedPacketMember(userId: 'u_1001', name: '阿五', qq: '10010001'),
      RedPacketMember(userId: 'u_1002', name: '发发发', qq: '85251244'),
      RedPacketMember(userId: 'u_1003', name: '小明', qq: '10010003'),
      RedPacketMember(userId: 'u_1004', name: '小雨点', qq: '10010004'),
    ];
  }

  @override
  Future<WalletOrderResult> claimRedPacket({
    required String orderId,
    String? payPin,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return WalletOrderResult(
      ok: true,
      state: WalletOrderState.success,
      orderId: orderId,
      msg: AppI18n.current.t(
        zhHans: '领取成功',
        zhHant: '領取成功',
        en: 'Claimed successfully.',
        ja: '受け取りに成功しました。',
        ko: '수령이 완료되었습니다.',
      ),
      data: {'type': 'wallet_red_packet', 'orderId': orderId},
    );
  }

  @override
  Future<List<WalletRecordDto>> getWalletRecords() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return const [
      WalletRecordDto(
        id: 'r_deposit_001', type: WalletRecordType.receive, status: WalletRecordStatus.success,
        title: '链上充值', subTitle: '充值成功', amount: '20.00', coin: 'USDT', income: true,
        network: 'TRC20', fee: '', payer: 'TQ8L2vX31kQ8J4N6Kc9rVYy3sQp1E1eLw9', payee: 'TP4TT7nd1UEf52K2VXL3678qGbPMYnKaqj',
        addr: 'TP4TT7nd1UEf52K2VXL3678qGbPMYnKaqj', hash: '1d7b2c0be5a12d97af86f9712fb14c7658f8a2c180dfb8f4e66b4f3d447e0012', block: '66250888',
        time: '2026-05-22 17:58:12', orderNo: 'DP2026052217580001', serverOrderId: 'DP2026052217580001', clientOrderId: '', memo: '',
      ),
      WalletRecordDto(
        id: 'r_withdraw_001', type: WalletRecordType.transfer, status: WalletRecordStatus.pending,
        title: '提现', subTitle: '广播中', amount: '12.00', coin: 'USDT', income: false,
        network: 'TRC20', fee: '1.000000 USDT', payer: '我的钱包', payee: '外部地址',
        addr: 'TAjR2bhqd9EKbeH78JUDsPSGGv3ev6TBnz', hash: '6fb2e6026c2e4d72d5b7af3dd2ad0e91ba2f43987de4f43e621cf3c55a1029af', block: '--',
        time: '2026-05-22 18:22:48', orderNo: 'WD2026052218220001', serverOrderId: 'WD2026052218220001', clientOrderId: '', memo: '',
      ),
      WalletRecordDto(
        id: 'r_transfer_001', type: WalletRecordType.transfer, status: WalletRecordStatus.success,
        title: '转账给 发发发', subTitle: 'TRC20 转账', amount: '88.88', coin: 'USDT', income: false,
        network: 'TRC20', fee: '1.00 TRX', payer: '我的钱包', payee: '发发发',
        addr: 'TP4TT7nd1UEf52K2VXL3678qGbPMYnKaqj', hash: '0x8a9f27b7c3f4e9d4a62a21d821b9e32c', block: '66251234',
        time: '2026-05-22 18:30:21', orderNo: 'TF2026052218300001', serverOrderId: 'TF2026052218300001', clientOrderId: '', memo: '转账说明',
      ),
      WalletRecordDto(
        id: 'r_receive_001', type: WalletRecordType.receive, status: WalletRecordStatus.success,
        title: '收到 张三 转账', subTitle: 'TRC20 收款', amount: '12.88', coin: 'USDT', income: true,
        network: 'TRC20', fee: '0.00 TRX', payer: '张三', payee: '我的钱包',
        addr: 'TP4TT7nd1UEf52K2VXL3678qGbPMYnKaqj', hash: '0x91f3a6b2159ef002c71f903c0feda621', block: '66251088',
        time: '2026-05-22 18:10:03', orderNo: 'RC2026052218100001', serverOrderId: 'RC2026052218100001', clientOrderId: '', memo: '链上收款',
      ),
      WalletRecordDto(
        id: 'r_red_001', type: WalletRecordType.redPacket, status: WalletRecordStatus.pending,
        title: '发送拼手气红包', subTitle: '领取中 3/5', amount: '88.88', coin: 'USDT', income: false,
        network: '内部红包', fee: '0.00 TRX', payer: '我的钱包', payee: '群红包', addr: '--', hash: '--', block: '--',
        time: '2026-05-22 18:35:10', orderNo: 'RP2026052218350001', serverOrderId: 'RP2026052218350001', clientOrderId: '', memo: '恭喜发财，大吉大利',
        rpType: '拼手气红包', rpCnt: '5 个', rpTotal: '88.88 USDT', rpClaim: '3/5', rpMsg: '恭喜发财，大吉大利',
        rpStatus: '领取中', createdAt: '2026-05-22 18:35:10', expiredAt: '2026-05-23 18:35:10',
      ),
      WalletRecordDto(
        id: 'r_swap_001', type: WalletRecordType.swap, status: WalletRecordStatus.success,
        title: 'USDT 兑换 TRX', subTitle: '闪兑完成', amount: '10.00', coin: 'USDT', income: false,
        network: 'Swap', fee: '0.10 USDT', payer: '我的钱包', payee: '我的钱包', addr: '--', hash: '--', block: '--',
        time: '2026-05-22 18:45:00', orderNo: 'SW2026052218450001', serverOrderId: 'SW2026052218450001', clientOrderId: '', memo: 'USDT → TRX',
      ),
    ];
  }

  @override
  Future<List<WalletRecordDto>> getWalletRecordsByFilter(
    HistoryRecordFilter filter,
  ) async {
    final all = await getWalletRecords();
    switch (filter) {
      case HistoryRecordFilter.all:
        return all;
      case HistoryRecordFilter.chainWithdraw:
        return all.where((item) => item.isChainWithdraw).toList();
      case HistoryRecordFilter.chainDeposit:
        return all.where((item) => item.isChainDeposit).toList();
      case HistoryRecordFilter.internalDeposit:
        return all.where((item) => item.isInternalReceive).toList();
      case HistoryRecordFilter.internalWithdraw:
        return all.where((item) => item.isInternalTransfer).toList();
      case HistoryRecordFilter.redPacket:
        return all
            .where(
              (item) =>
                  item.type == WalletRecordType.redPacket &&
                  !item.isRedPacketRefund,
            )
            .toList();
      case HistoryRecordFilter.redPacketRefund:
        return all.where((item) => item.isRedPacketRefund).toList();
      case HistoryRecordFilter.transfer:
        return all
            .where(
              (item) => item.isInternalReceive || item.isInternalTransfer,
            )
            .toList();
      case HistoryRecordFilter.transferRefund:
        return all
            .where(
              (item) =>
                  item.title.contains('退款') &&
                  item.type == WalletRecordType.transfer,
            )
            .toList();
    }
  }

  @override
  Future<List<WalletRecordDto>> getWalletRecordsByType(
    WalletRecordType type,
  ) async {
    final list = await getWalletRecords();
    if (type == WalletRecordType.all) return list;
    return list.where((e) => e.type == type).toList();
  }

  @override
  Future<List<WalletRecordDto>> getDepositRecords() async {
    final list = await getWalletRecords();
    return list.where((e) => e.title == '链上充值').toList();
  }

  @override
  Future<List<WalletRecordDto>> getWithdrawRecords() async {
    final list = await getWalletRecords();
    return list.where((e) => e.title == '提现').toList();
  }



  WalletPayMethodDto _findPay(String payId) {
    return _payMethods.firstWhere(
      (e) => e.id == payId,
      orElse: () => _payMethods.first,
    );
  }

  bool _hasEnough({
    required int amountMinor,
    required WalletPayMethodDto pay,
  }) {
    final feeCoin = pay.feeCoin.trim().isEmpty ? pay.coin : pay.feeCoin.trim();
    if (pay.feeMinor <= 0 || feeCoin == pay.coin) {
      return amountMinor + pay.feeMinor <= pay.balMinor;
    }
    return amountMinor <= pay.balMinor && pay.feeMinor <= pay.feeBalanceMinor;
  }
}


class WalletOrderCardDto {
  final bool ok;
  final bool invalid;
  final String type;
  final String status;
  final String amount;
  final String coin;
  final String title;
  final String msg;
  final String senderUserId;
  final String groupId;

  const WalletOrderCardDto({
    required this.ok,
    this.invalid = false,
    required this.type,
    required this.status,
    required this.amount,
    required this.coin,
    required this.title,
    required this.msg,
    this.senderUserId = '',
    this.groupId = '',
  });

  factory WalletOrderCardDto.invalidCard() {
    final title = AppI18n.current.t(
      zhHans: '无效卡片',
      zhHant: '無效卡片',
      en: 'Invalid card',
      ja: '無効なカード',
      ko: '유효하지 않은 카드',
    );
    return WalletOrderCardDto(
      ok: false,
      invalid: true,
      type: '',
      status: 'invalid',
      amount: '',
      coin: '',
      title: title,
      msg: title,
    );
  }

  WalletOrderCardDto copyWith({
    bool? ok,
    bool? invalid,
    String? type,
    String? status,
    String? amount,
    String? coin,
    String? title,
    String? msg,
    String? senderUserId,
    String? groupId,
  }) {
    return WalletOrderCardDto(
      ok: ok ?? this.ok,
      invalid: invalid ?? this.invalid,
      type: type ?? this.type,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      coin: coin ?? this.coin,
      title: title ?? this.title,
      msg: msg ?? this.msg,
      senderUserId: senderUserId ?? this.senderUserId,
      groupId: groupId ?? this.groupId,
    );
  }
}

class WalletDto {
  final String totalBal;
  /// 总资产折合 USD（不含 `$` 前缀）；汇率不可用时为空。
  final String totalBalUsd;
  final String trxAddr;
  final List<CoinDto> coins;

  const WalletDto({
    required this.totalBal,
    this.totalBalUsd = '',
    required this.trxAddr,
    required this.coins,
  });
}

class CoinDto {
  final String name;
  final String sub;
  final String bal;
  final String fiat;
  final CoinType type;
  final String code;
  final String? logoUrl;
  final bool platformCoin;
  final bool depositEnabled;
  final bool withdrawEnabled;
  final int balMinor;
  final int scale;
  /// 24h 涨跌幅（百分比数值，如 `0.12` 表示 +0.12%）；未知时为 null。
  final double? priceChangePercent;

  const CoinDto({
    required this.name,
    required this.sub,
    required this.bal,
    required this.fiat,
    required this.type,
    this.code = '',
    this.logoUrl,
    this.platformCoin = false,
    this.depositEnabled = true,
    this.withdrawEnabled = true,
    this.balMinor = 0,
    this.scale = 6,
    this.priceChangePercent,
  });

  /// 小额资产人民币估值阈值（元）。估值低于该值视为小额。
  static const double smallAssetThresholdCny = 1;

  /// 折合人民币估值是否低于 [smallAssetThresholdCny]（用于「隐藏小额资产」）。
  bool get isSmallAsset {
    final raw = fiat.replaceAll(RegExp(r'[¥$,\s≈]'), '');
    final value = double.tryParse(raw);
    if (value != null) return value < smallAssetThresholdCny;
    return balMinor <= 0;
  }

  WalletPayMethodDto toPayMethod({required String net}) {
    final payId = platformCoin
        ? WalletCurrency.platform
        : (code.isNotEmpty ? code.toUpperCase() : name.toUpperCase());
    return WalletPayMethodDto(
      id: payId,
      coin: name,
      net: net,
      bal: bal,
      fiat: fiat,
      balMinor: balMinor,
      scale: scale,
      logoUrl: logoUrl,
      code: code,
      platformCoin: platformCoin,
      color: platformCoin ? const Color(0xFF2B72FF) : const Color(0xFF26A17B),
      badgeColor:
          platformCoin ? const Color(0xFF45C3FF) : const Color(0xFFFF001F),
      badge: platformCoin ? '99' : 'T',
    );
  }
}

enum CoinType { trx, usdt, cny }

/// 发红包 / 转账等场景共用的付款方式 DTO。
class WalletPayMethodDto {
  final String id;
  final String coin;
  final String net;
  final String bal;
  final String fiat;
  final int balMinor;
  final int scale;
  final int feeMinor;
  final String feeCoin;
  final int feeScale;
  final int feeBalanceMinor;
  final Color color;
  final Color badgeColor;
  final String badge;
  final bool enabled;
  final String? logoUrl;
  final String code;
  final bool platformCoin;

  const WalletPayMethodDto({
    required this.id,
    required this.coin,
    required this.net,
    required this.bal,
    required this.fiat,
    required this.balMinor,
    required this.scale,
    this.feeMinor = 0,
    this.feeCoin = '',
    this.feeScale = 0,
    this.feeBalanceMinor = 0,
    required this.color,
    required this.badgeColor,
    required this.badge,
    this.enabled = true,
    this.logoUrl,
    this.code = '',
    this.platformCoin = false,
  });

  static const empty = WalletPayMethodDto(
    id: '',
    coin: 'USDT',
    net: '',
    bal: '0',
    fiat: '\$0.00',
    balMinor: 0,
    scale: 6,
    color: Color(0xFF26A17B),
    badgeColor: Color(0xFF999999),
    badge: '-',
    enabled: false,
  );
}

class WalletTransferReq {
  final String clientOrderId;
  final String toUserId;
  final String toName;
  final String amt;
  final String amountMinor;
  final String coin;
  final String payId;
  final String net;
  final String pwd;
  final String memo;

  const WalletTransferReq({
    required this.clientOrderId,
    required this.toUserId,
    required this.toName,
    required this.amt,
    required this.amountMinor,
    required this.coin,
    required this.payId,
    required this.net,
    required this.pwd,
    required this.memo,
  });
}

class WalletWithdrawReq {
  final String clientOrderId;
  final String toAddress;
  final String amt;
  final String amountMinor;
  final String coin;
  final String payId;
  final String net;
  final String pwd;

  const WalletWithdrawReq({
    required this.clientOrderId,
    required this.toAddress,
    required this.amt,
    required this.amountMinor,
    required this.coin,
    required this.payId,
    required this.net,
    required this.pwd,
  });
}

class WalletRedPacketReq {
  final String clientOrderId;
  final String convId;
  final bool isGroup;
  final String rpType;
  final String cnt;
  final String amt;
  final String amountMinor;
  final String totalAmt;
  final String totalMinor;
  final String coin;
  final String payId;
  final String net;
  final String pwd;
  final String msg;
  final String toUserId;

  const WalletRedPacketReq({
    required this.clientOrderId,
    required this.convId,
    this.isGroup = false,
    required this.rpType,
    required this.cnt,
    required this.amt,
    required this.amountMinor,
    required this.totalAmt,
    required this.totalMinor,
    required this.coin,
    required this.payId,
    required this.net,
    required this.pwd,
    required this.msg,
    required this.toUserId,
  });
}

enum WalletExchangeDirection {
  usdtToPlatform,
  platformToUsdt,
}

extension WalletExchangeDirectionX on WalletExchangeDirection {
  String get code {
    switch (this) {
      case WalletExchangeDirection.usdtToPlatform:
        return 'USDT_TO_PLATFORM';
      case WalletExchangeDirection.platformToUsdt:
        return 'PLATFORM_TO_USDT';
    }
  }

  String get inputCoin {
    switch (this) {
      case WalletExchangeDirection.usdtToPlatform:
        return 'USDT';
      case WalletExchangeDirection.platformToUsdt:
        return '99';
    }
  }

  String get outputCoin {
    switch (this) {
      case WalletExchangeDirection.usdtToPlatform:
        return '99';
      case WalletExchangeDirection.platformToUsdt:
        return 'USDT';
    }
  }

  int get inputScale {
    switch (this) {
      case WalletExchangeDirection.usdtToPlatform:
        return WalletCurrency.usdtScale;
      case WalletExchangeDirection.platformToUsdt:
        return WalletCurrency.platformScale;
    }
  }

  int get outputScale {
    switch (this) {
      case WalletExchangeDirection.usdtToPlatform:
        return WalletCurrency.platformScale;
      case WalletExchangeDirection.platformToUsdt:
        return WalletCurrency.usdtScale;
    }
  }
}

class WalletExchangeReq {
  final WalletExchangeDirection direction;
  final int amount;
  final String payPin;

  const WalletExchangeReq({
    required this.direction,
    required this.amount,
    required this.payPin,
  });
}

class WalletExchangeOrderDto {
  final String id;
  final String userId;
  final WalletExchangeDirection direction;
  final int inputAmount;
  final int outputAmount;
  final int surplusFen;
  final String rateSnapshot;
  final String createdAt;

  const WalletExchangeOrderDto({
    required this.id,
    required this.userId,
    required this.direction,
    required this.inputAmount,
    required this.outputAmount,
    required this.surplusFen,
    required this.rateSnapshot,
    required this.createdAt,
  });
}
