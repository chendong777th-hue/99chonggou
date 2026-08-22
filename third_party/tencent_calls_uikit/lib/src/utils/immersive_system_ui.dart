import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 通话页沉浸式系统栏（语音/视频全屏）。
class CallImmersiveSystemUi {
  CallImmersiveSystemUi._();

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

  static void restoreAfterCall() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
}
