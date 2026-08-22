import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_share_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/share_app_service.dart';

/// 分享能力收口（应用分享 + 钱包文本/系统分享）。
class SharePlatform {
  SharePlatform._();

  static ShareAppService get appShare => ShareAppService.instance;

  static WalletShareService walletShare() => WalletShareService();

  static Future<WalletSystemShareResult> systemShareApp() =>
      appShare.systemShare();

  static Future<WalletShareTextResult> shareWalletText(String text) =>
      walletShare().shareText(text);
}
