import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/qr_code_scanner_page.dart';

class QRScannerLauncher {
  const QRScannerLauncher._();

  /// Web / 电脑端不提供扫一扫入口与能力。
  static Future<T?> open<T>(
    BuildContext context, {
    bool walletAddressMode = false,
  }) async {
    if (kIsWeb) {
      return null;
    }
    final granted = await PermissionGuard.cameraForScan(context);
    if (!granted || !context.mounted) {
      return null;
    }

    return Navigator.of(context).push<T>(
      AppMaterialPageRoute(
        builder: (_) => QRCodeScannerPage(walletAddressMode: walletAddressMode),
      ),
    );
  }
}
