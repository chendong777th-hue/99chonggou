import 'package:tencent_cloud_chat_demo/src/services/share_app_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactInviteLauncher {
  ContactInviteLauncher._();

  static Future<bool> openSmsInvite({
    required String phone,
  }) async {
    final normalized = phone.replaceAll(RegExp(r'[\s\-()]'), '').trim();
    if (normalized.isEmpty) {
      return false;
    }

    final body = await ShareAppService.instance.buildShareText();
    if (body.isEmpty) {
      return false;
    }

    final uri = Uri.parse(
      'sms:$normalized?body=${Uri.encodeComponent(body)}',
    );
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
