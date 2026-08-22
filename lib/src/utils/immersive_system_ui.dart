import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/utils/launch_system_ui.dart';

/// 深色全屏场景（扫一扫、媒体预览等）共用的沉浸式系统栏。
class ImmersiveSystemUi {
  ImmersiveSystemUi._();

  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
  );

  static Future<void> apply() {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge).then((_) {
      SystemChrome.setSystemUIOverlayStyle(overlayStyle);
    });
  }

  static void restore(BuildContext context) {
    if (!context.mounted) {
      return;
    }
    if (LaunchSystemUi.isInStartupPhase) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(LaunchSystemUi.overlayStyle);
      return;
    }
    LaunchSystemUi.restoreFromContext(context);
  }
}
