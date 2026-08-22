import 'package:flutter/foundation.dart';
import 'package:live_flutter_plugin/v2_tx_live_premier.dart';
import 'package:tencent_cloud_chat_demo/config.dart';

/// Configures Tencent Cloud live playback licence once per process.
class GroupLiveTencentLicence {
  GroupLiveTencentLicence._();

  static bool _configured = false;

  /// Whether dart-define licence credentials were provided at build time.
  static bool get hasCredentials {
    final url = IMDemoConfig.tencentLiveLicenceUrl.trim();
    final key = IMDemoConfig.tencentLiveLicenceKey.trim();
    return url.isNotEmpty && key.isNotEmpty;
  }

  static Future<void> ensureConfigured() async {
    if (_configured) {
      return;
    }
    _configured = true;
    final url = IMDemoConfig.tencentLiveLicenceUrl.trim();
    final key = IMDemoConfig.tencentLiveLicenceKey.trim();
    if (url.isEmpty || key.isEmpty) {
      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[GroupLive] Tencent live licence missing; set '
          'TENCENT_LIVE_LICENCE_URL / TENCENT_LIVE_LICENCE_KEY',
        );
      }
      return;
    }
    await V2TXLivePremier.setLicence(url, key);
  }
}
