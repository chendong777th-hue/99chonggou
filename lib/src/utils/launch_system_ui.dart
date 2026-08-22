import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/app_material_theme.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';

/// 冷启动阶段的全局沉浸式系统栏（LaunchPage / 登录页 / 进首页前）。
class LaunchSystemUi {
  LaunchSystemUi._();

  static bool _inStartupPhase = true;

  static final ValueNotifier<bool> startupPhaseListenable = ValueNotifier(true);

  static bool get isInStartupPhase => _inStartupPhase;

  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static Future<void> apply() {
    _inStartupPhase = true;
    startupPhaseListenable.value = true;
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge).then((_) {
      SystemChrome.setSystemUIOverlayStyle(overlayStyle);
    });
  }

  static SystemUiOverlayStyle overlayForApp(BuildContext context) {
    if (_inStartupPhase) {
      return overlayStyle;
    }
    try {
      final themeModel = Provider.of<DefaultThemeData>(context, listen: false);
      final isDark = themeModel.currentThemeType == ThemeType.dark;
      return buildAppSystemUiOverlayStyle(themeModel.theme, isDark: isDark);
    } catch (_) {
      return overlayStyle;
    }
  }

  static void completeStartup(BuildContext context) {
    if (!_inStartupPhase) {
      return;
    }
    _inStartupPhase = false;
    startupPhaseListenable.value = false;
    restoreFromContext(context);
  }

  static void restoreFromContext(BuildContext context) {
    if (!context.mounted) {
      return;
    }
    try {
      final themeModel = Provider.of<DefaultThemeData>(context, listen: false);
      final isDark = themeModel.currentThemeType == ThemeType.dark;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        buildAppSystemUiOverlayStyle(themeModel.theme, isDark: isDark),
      );
    } catch (_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }
}
