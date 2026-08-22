import 'package:flutter/material.dart';

import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_time.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

import 'order/wallet_order.dart';
import 'record/wallet_record_detail_screen.dart';
import 'record/wallet_record_models.dart';
import 'wallet_repository.dart';
import 'widgets/pay_success_main.dart';
import 'progress/wallet_withdraw_progress_service.dart';

/// 提现/转出成功后：清空整条提现流程栈，进入订单详情；返回直达钱包首页。
class WithdrawSuccessNavigation {
  WithdrawSuccessNavigation._();

  static const _externalPayeeLabel = '外部地址';
  static const _myWalletLabel = '我的钱包';

  static WalletRecordStatus recordStatusFromOrderState(WalletOrderState state) {
    switch (state) {
      case WalletOrderState.failed:
      case WalletOrderState.expired:
      case WalletOrderState.cancelled:
      case WalletOrderState.refunded:
        return WalletRecordStatus.failed;
      case WalletOrderState.success:
        return WalletRecordStatus.success;
      case WalletOrderState.accepted:
      case WalletOrderState.pending:
      case WalletOrderState.confirming:
      case WalletOrderState.password:
      case WalletOrderState.submitting:
      case WalletOrderState.created:
      case WalletOrderState.unknown:
        return WalletRecordStatus.pending;
      case WalletOrderState.idle:
        return WalletRecordStatus.pending;
    }
  }

  static String recordSubTitle(WalletOrderResult result) {
    final raw = result.data['status']?.toString().trim() ??
        result.data['state']?.toString().trim() ??
        '';
    if (raw.isNotEmpty) return raw;
    return recordStatusFromOrderState(result.state).txt;
  }

  static WalletRecordDto buildChainWithdrawRecord({
    required WalletOrderResult result,
    required String toAddress,
    required String fromAddress,
    required int amountMinor,
    required int feeMinor,
    required WalletPayMethodDto payMethod,
  }) {
    final i18n = AppI18n.current;
    final orderId = _firstNonEmpty([
      result.orderId,
      result.data['id']?.toString(),
      result.clientOrderId,
    ]);
    final clientOrderId = result.clientOrderId.trim();
    final coin = payMethod.coin.trim().isEmpty ? 'USDT' : payMethod.coin.trim();
    final currency = coin.toUpperCase() == '99' ? WalletCurrency.platform : coin;
    final amountText = WalletAmount.formatMinor(amountMinor, payMethod.scale);
    final feeText = feeMinor > 0
        ? '${WalletAmount.formatFixed(feeMinor, payMethod.scale)} ${walletDisplayCoin(currency)}'
        : '';
    final payer = fromAddress.trim().isEmpty ? _myWalletLabel : fromAddress.trim();

    return WalletRecordDto(
      id: orderId.isEmpty ? clientOrderId : orderId,
      type: WalletRecordType.transfer,
      status: recordStatusFromOrderState(result.state),
      title: i18n.t(
        zhHans: '提现',
        zhHant: '提現',
        en: 'Withdrawal',
        ja: '出金',
        ko: '출금',
      ),
      subTitle: recordSubTitle(result),
      amount: amountText,
      coin: walletDisplayCoin(currency),
      income: false,
      network: payMethod.net.trim().isEmpty ? 'TRC20' : payMethod.net.trim(),
      fee: feeText,
      payer: payer,
      payee: _externalPayeeLabel,
      addr: toAddress.trim(),
      hash: _text(result.data['txId']),
      block: '',
      time: formatWalletApiDateTime(
        DateTime.now(),
        pattern: 'yyyy-MM-dd HH:mm:ss',
      ),
      orderNo: orderId,
      serverOrderId: orderId,
      clientOrderId: clientOrderId,
      memo: _text(result.data['memo'] ?? result.msg),
    );
  }

  static WalletRecordDto buildFriendTransferRecord({
    required WalletOrderResult result,
    required WalletPayMethodDto payMethod,
    required String targetUserId,
    required String targetName,
    required int amountMinor,
  }) {
    final i18n = AppI18n.current;
    final orderId = _firstNonEmpty([
      result.orderId,
      result.data['id']?.toString(),
      result.clientOrderId,
    ]);
    final clientOrderId = result.clientOrderId.trim();
    final coin = payMethod.coin.trim();
    final currency = coin.toUpperCase() == '99' ? WalletCurrency.platform : coin;
    final payee = targetName.trim().isEmpty ? targetUserId.trim() : targetName.trim();

    return WalletRecordDto(
      id: orderId.isEmpty ? clientOrderId : orderId,
      type: WalletRecordType.transfer,
      status: recordStatusFromOrderState(result.state),
      title: i18n.t(
        zhHans: '发起转账',
        zhHant: '發起轉賬',
        en: 'Transfer sent',
        ja: '送金を送信',
        ko: '송금 발송',
      ),
      subTitle: i18n.t(
        zhHans: '平台内转账',
        zhHant: '平台內轉賬',
        en: 'In-app transfer',
        ja: 'アプリ内送金',
        ko: '앱 내 송금',
      ),
      amount: WalletAmount.formatMinor(amountMinor, payMethod.scale),
      coin: walletDisplayCoin(currency),
      income: false,
      network: i18n.t(
        zhHans: '平台',
        zhHant: '平台',
        en: 'Platform',
        ja: 'プラットフォーム',
        ko: '플랫폼',
      ),
      fee: payMethod.feeMinor > 0
          ? '${WalletAmount.formatFixed(payMethod.feeMinor, payMethod.feeScale)} ${walletDisplayCoin(payMethod.feeCoin.isEmpty ? currency : payMethod.feeCoin)}'
          : '',
      payer: _myWalletLabel,
      payee: payee,
      addr: '',
      hash: _text(result.data['txId']),
      block: '',
      time: formatWalletApiDateTime(
        DateTime.now(),
        pattern: 'yyyy-MM-dd HH:mm:ss',
      ),
      orderNo: orderId,
      serverOrderId: orderId,
      clientOrderId: clientOrderId,
      memo: _text(result.data['memo'] ?? result.msg),
    );
  }

  static void openOrderDetail(BuildContext context, WalletRecordDto item) {
    Navigator.of(context).pushAndRemoveUntil(
      AppMaterialPageRoute(
        builder: (_) => WalletRecordDetailScreen(item: item),
      ),
      (route) => route.isFirst,
    );
  }

  static ({String title, String message}) chainWithdrawSuccessCopy(
    WalletOrderResult result,
  ) {
    final i18n = AppI18n.current;
    if (result.state == WalletOrderState.success) {
      return (
        title: i18n.t(
          zhHans: '提现成功',
          zhHant: '提現成功',
          en: 'Withdrawal successful',
          ja: '出金が完了しました',
          ko: '출금이 완료되었습니다',
        ),
        message: i18n.t(
          zhHans: '可在订单页查看详情',
          zhHant: '可在訂單頁查看詳情',
          en: 'View details on the order page.',
          ja: '注文ページで詳細を確認できます。',
          ko: '주문 페이지에서 자세히 확인할 수 있습니다.',
        ),
      );
    }
    return (
      title: i18n.t(
        zhHans: '提交成功',
        zhHant: '提交成功',
        en: 'Submitted',
        ja: '送信完了',
        ko: '제출 완료',
      ),
      message: i18n.t(
        zhHans: '提现已提交，可在订单页查看进度',
        zhHant: '提現已提交，可在訂單頁查看進度',
        en: 'Withdrawal submitted. Track progress on the order page.',
        ja: '出金を送信しました。注文ページで進捗を確認できます。',
        ko: '출금이 제출되었습니다. 주문 페이지에서 진행 상황을 확인할 수 있습니다.',
      ),
    );
  }

  static ({String title, String message}) friendTransferSuccessCopy() {
    final i18n = AppI18n.current;
    return (
      title: i18n.t(
        zhHans: '支付成功',
        zhHant: '支付成功',
        en: 'Payment successful',
        ja: '支払いが完了しました',
        ko: '결제가 완료되었습니다',
      ),
      message: i18n.t(
        zhHans: '转出已完成',
        zhHant: '轉出已完成',
        en: 'Transfer completed',
        ja: '送金が完了しました',
        ko: '송금이 완료되었습니다',
      ),
    );
  }

  static Future<void> celebrateAndOpenChainWithdrawDetail(
    BuildContext context, {
    required WalletOrderResult result,
    required String toAddress,
    required String fromAddress,
    required int amountMinor,
    required int feeMinor,
    required WalletPayMethodDto payMethod,
  }) async {
    final copy = chainWithdrawSuccessCopy(result);
    await PaySuccessOverlay.showFor(
      context,
      title: copy.title,
      message: copy.message,
    );
    if (!context.mounted) return;
    await WalletWithdrawProgressService.instance.startChainWithdraw(
      result: result,
      payMethod: payMethod,
      amountMinor: amountMinor,
    );
    if (!context.mounted) return;
    openChainWithdrawDetail(
      context,
      result: result,
      toAddress: toAddress,
      fromAddress: fromAddress,
      amountMinor: amountMinor,
      feeMinor: feeMinor,
      payMethod: payMethod,
    );
  }

  static Future<void> celebrateAndOpenFriendTransferDetail(
    BuildContext context, {
    required WalletOrderResult result,
    required WalletPayMethodDto payMethod,
    required String targetUserId,
    required String targetName,
    required int amountMinor,
  }) async {
    final copy = friendTransferSuccessCopy();
    await PaySuccessOverlay.showFor(
      context,
      title: copy.title,
      message: copy.message,
    );
    if (!context.mounted) return;
    openFriendTransferDetail(
      context,
      result: result,
      payMethod: payMethod,
      targetUserId: targetUserId,
      targetName: targetName,
      amountMinor: amountMinor,
    );
  }

  static void openChainWithdrawDetail(
    BuildContext context, {
    required WalletOrderResult result,
    required String toAddress,
    required String fromAddress,
    required int amountMinor,
    required int feeMinor,
    required WalletPayMethodDto payMethod,
  }) {
    openOrderDetail(
      context,
      buildChainWithdrawRecord(
        result: result,
        toAddress: toAddress,
        fromAddress: fromAddress,
        amountMinor: amountMinor,
        feeMinor: feeMinor,
        payMethod: payMethod,
      ),
    );
  }

  static void openFriendTransferDetail(
    BuildContext context, {
    required WalletOrderResult result,
    required WalletPayMethodDto payMethod,
    required String targetUserId,
    required String targetName,
    required int amountMinor,
  }) {
    openOrderDetail(
      context,
      buildFriendTransferRecord(
        result: result,
        payMethod: payMethod,
        targetUserId: targetUserId,
        targetName: targetName,
        amountMinor: amountMinor,
      ),
    );
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty && text != '--') return text;
    }
    return '';
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';
}
