import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/platform_api.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_share_service.dart';
import 'package:tencent_cloud_chat_demo/src/platform/clipboard_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_external_message_sender.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_share_picker_page.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class ShareAppService {
  ShareAppService._();

  static final ShareAppService instance = ShareAppService._();

  final WalletShareService _walletShare = WalletShareService();
  final _sdk = TIMUIKitCore.getSDKInstance();

  /// 与「关于我们 · 官方网站」同源：`/api/v1/platform/contact` 的 `website`。
  Future<String> resolveWebsite() => _resolveShareUrl();

  /// 个人 / 群二维码落地页：优先官网，其次平台 `downloadUrl`。
  Future<String> resolveQrLandingUrl() async {
    try {
      final info = await PlatformApi.instance.fetchContact();
      final website = info.website.trim();
      if (website.isNotEmpty) {
        return website;
      }
      return info.downloadUrl.trim();
    } catch (_) {
      return '';
    }
  }

  Future<String> buildShareText() async {
    final url = await _resolveShareUrl();
    if (url.isEmpty) {
      return '';
    }
    return '我正在使用 ${IMDemoConfig.appName}，快来一起聊天吧！下载链接：$url';
  }

  Future<String> _resolveShareUrl() async {
    try {
      final info = await PlatformApi.instance.fetchContact();
      return info.website.trim();
    } catch (_) {
      return '';
    }
  }

  Future<bool> copyShareText() async {
    final text = await buildShareText();
    if (text.isEmpty) {
      return false;
    }
    try {
      await ClipboardGuard.copy(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<WalletSystemShareResult> systemShare() async {
    final text = await buildShareText();
    if (text.isEmpty) {
      return WalletSystemShareResult.failed;
    }
    return _walletShare.shareSystemText(text);
  }

  Future<bool> sendToTarget(ConversationShareTarget target) async {
    final text = await buildShareText();
    if (text.isEmpty) {
      return false;
    }
    final createRes =
        await _sdk.getMessageManager().createTextMessage(text: text);
    final messageID = createRes.data?.id;
    if (createRes.code != 0 || messageID == null || messageID.isEmpty) {
      return false;
    }
    return ChatExternalMessageSender.sendCreatedMessage(
      messageInfo: createRes.data?.messageInfo,
      receiverUserId: target.userID,
      groupId: target.groupID,
      reason: 'share_app_sent',
    );
  }
}
