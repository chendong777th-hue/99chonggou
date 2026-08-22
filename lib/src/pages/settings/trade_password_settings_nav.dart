import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/change_trade_password_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/setup_trade_password_page.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';

/// 设置 / 账号安全中打开支付密码相关页面。
class TradePasswordSettingsNav {
  TradePasswordSettingsNav._();

  static Future<void> open(BuildContext context) async {
    bool payPinSet;
    try {
      final me = await WalletApi.instance.getMe();
      payPinSet = me.payPinSet;
    } catch (_) {
      if (!context.mounted) return;
      final i18n = AppI18n.of(context);
      AppDialog.showNotice(
        title: i18n.t(
          zhHans: '暂时无法打开',
          zhHant: '暫時無法開啟',
          en: 'Unable to Open',
          ja: '開けません',
          ko: '열 수 없음',
        ),
        message: i18n.t(
          zhHans: '无法确认交易密码状态，请检查网络后重试。',
          zhHant: '無法確認交易密碼狀態，請檢查網路後再試。',
          en: 'Unable to verify your transaction password status. Please check your connection and try again.',
          ja: '取引パスワードの状態を確認できません。通信状況を確認してからもう一度お試しください。',
          ko: '거래 비밀번호 상태를 확인할 수 없습니다. 네트워크를 확인한 뒤 다시 시도해 주세요.',
        ),
      );
      return;
    }

    if (!context.mounted) return;

    if (payPinSet) {
      await Navigator.push<void>(
        context,
        NavigationRoutes.cupertino(
          builder: (_) => const ChangeTradePasswordPage(),
        ),
      );
      return;
    }

    await openSetup(context);
  }

  static Future<bool?> openSetup(BuildContext context) async {
    return Navigator.push<bool>(
      context,
      NavigationRoutes.cupertino(
        builder: (_) => const SetupTradePasswordPage(),
      ),
    );
  }
}
