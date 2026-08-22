import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_live_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/pay_auth_helper.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_pay_pin_guard.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/adaptive_modal.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_live_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

class GroupLiveTipSheet {
  GroupLiveTipSheet._();

  static Future<void> show(
    BuildContext context, {
    required String liveSessionId,
    required String anchorUserId,
  }) async {
    final allowed = await WalletPayPinGuard.ensureSet(context);
    if (!allowed || !context.mounted) return;

    final amountController = TextEditingController();
    final memoController = TextEditingController();
    var currency = WalletCurrency.usdt;

    await showAdaptiveModalSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final i18n = AppI18n.of(context);
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    i18n.t(
                      zhHans: '打赏主播',
                      zhHant: '打賞主播',
                      en: 'Tip anchor',
                      ja: '投げ銭',
                      ko: '후원하기',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: WalletCurrency.usdt,
                        label: Text(WalletCurrency.usdt),
                      ),
                      ButtonSegment(
                        value: WalletCurrency.platform,
                        label: Text(i18n.t(
                          zhHans: '99',
                          zhHant: '99',
                          en: '99',
                          ja: '99',
                          ko: '99',
                        )),
                      ),
                    ],
                    selected: {currency},
                    onSelectionChanged: (value) {
                      setState(() => currency = value.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: i18n.t(
                        zhHans: '金额',
                        zhHant: '金額',
                        en: 'Amount',
                        ja: '金額',
                        ko: '금액',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: memoController,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText: i18n.t(
                        zhHans: '备注（选填）',
                        zhHant: '備註（選填）',
                        en: 'Memo (optional)',
                        ja: 'メモ（任意）',
                        ko: '메모 (선택)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _submit(
                      context,
                      liveSessionId: liveSessionId,
                      currency: currency,
                      amountText: amountController.text,
                      memo: memoController.text,
                    ),
                    child: Text(i18n.t(
                      zhHans: '确认打赏',
                      zhHant: '確認打賞',
                      en: 'Confirm tip',
                      ja: '投げ銭する',
                      ko: '후원 확인',
                    )),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _submit(
    BuildContext context, {
    required String liveSessionId,
    required String currency,
    required String amountText,
    required String memo,
  }) async {
    final amount = _parseAmount(currency, amountText);
    if (amount <= 0) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '请输入有效金额',
        zhHant: '請輸入有效金額',
        en: 'Enter a valid amount.',
        ja: '有効な金額を入力してください。',
        ko: '유효한 금액을 입력해 주세요.',
      ));
      return;
    }
    final displayAmount = currency == WalletCurrency.usdt
        ? formatUsdtMicro(amount)
        : formatPlatformFen(amount);
    final displayCoin = currency == WalletCurrency.usdt
        ? WalletCurrency.usdt
        : walletDisplayCoin(WalletCurrency.platform);

    final clientOrderId = 'tip_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}';
    final auth = await PayAuthHelper.collectAndSubmit(
      context: context,
      title: AppI18n.of(context).t(
        zhHans: '确认打赏',
        zhHant: '確認打賞',
        en: 'Confirm tip',
        ja: '投げ銭確認',
        ko: '후원 확인',
      ),
      amountText: displayAmount,
      amountCoin: displayCoin,
      payText: displayCoin,
      payCoinCode: currency,
      onSubmit: (pin) async {
        try {
          await GroupLiveApi.instance.tip(
            liveSessionId: liveSessionId,
            currency: currency,
            amount: amount,
            payPin: pin,
            clientOrderId: clientOrderId,
            memo: memo.trim().isEmpty ? null : memo.trim(),
          );
          return null;
        } catch (e) {
          return GroupLiveErrorMessage.from(e);
        }
      },
    );
    if (!context.mounted) return;
    if (auth.success) {
      Navigator.of(context).pop();
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '打赏成功',
        zhHant: '打賞成功',
        en: 'Tip sent',
        ja: '投げ銭しました',
        ko: '후원 완료',
      ));
    }
  }

  static int _parseAmount(String currency, String text) {
    final normalized = text.trim().replaceAll(',', '');
    final value = double.tryParse(normalized);
    if (value == null || value <= 0) return 0;
    if (currency == WalletCurrency.usdt) {
      return (value * math.pow(10, WalletCurrency.usdtScale)).round();
    }
    return (value * math.pow(10, WalletCurrency.platformScale)).round();
  }
}
