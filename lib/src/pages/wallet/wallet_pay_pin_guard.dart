import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_api.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/trade_password_settings_nav.dart';

/// 资金操作前校验是否已设置支付密码；未设置则跳转设置页。
class WalletPayPinGuard {
  WalletPayPinGuard._();

  /// 已设置或设置成功返回 `true`；用户取消或接口失败返回 `false`。
  static Future<bool> ensureSet(BuildContext context) async {
    if (!context.mounted) return false;

    bool payPinSet = false;
    try {
      final me = await WalletApi.instance.getMe();
      payPinSet = me.payPinSet;
    } catch (_) {
      return false;
    }

    if (payPinSet) return true;
    if (!context.mounted) return false;

    final ok = await TradePasswordSettingsNav.openSetup(context);
    return ok == true;
  }
}
