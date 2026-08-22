import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/services/splash_config_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/launch_system_ui.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

/// Cold-start placeholder shown while [InitStep.checkLogin] runs.
/// Prefers a previously cached remote splash; falls back to the bundled asset
/// so the handoff from the native Launch Screen stays seamless.
class LaunchPage extends StatefulWidget {
  const LaunchPage({Key? key}) : super(key: key);

  static const splashAsset = SplashConfigService.defaultAsset;

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  @override
  void initState() {
    super.initState();
    LaunchSystemUi.apply();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final splash = _buildSplashImage();

    final body = AnnotatedRegion<SystemUiOverlayStyle>(
      value: LaunchSystemUi.overlayStyle,
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(child: splash),
      ),
    );

    if (isWideScreen) {
      return MoveWindow(child: body);
    }
    return body;
  }

  Widget _buildSplashImage() {
    final cachedPath = SplashConfigService.instance.cachedFilePath;
    if (!kIsWeb && cachedPath != null && cachedPath.isNotEmpty) {
      final file = File(cachedPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _assetSplash(),
        );
      }
    }
    return _assetSplash();
  }

  Widget _assetSplash() {
    return Image.asset(
      LaunchPage.splashAsset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      gaplessPlayback: true,
    );
  }
}
