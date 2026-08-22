import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class DefaultThemeData with ChangeNotifier {
  ThemeType _selectedThemeType = ThemeType.system;
  final CoreServicesImpl _coreInstance = TIMUIKitCore.getInstance();
  VoidCallback? _previousBrightnessCallback;

  DefaultThemeData() {
    _previousBrightnessCallback =
        PlatformDispatcher.instance.onPlatformBrightnessChanged;
    PlatformDispatcher.instance.onPlatformBrightnessChanged =
        _handlePlatformBrightnessChanged;
    _applyTheme();
    _loadFromLocal();
  }

  void _handlePlatformBrightnessChanged() {
    _previousBrightnessCallback?.call();
    if (selectedThemeType != ThemeType.system) {
      return;
    }
    _applyTheme();
    notifyListeners();
  }

  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeType');
    final type = saved == null
        ? ThemeType.system
        : DefTheme.themeTypeFromString(saved);
    _selectedThemeType = type;
    _applyTheme();
    notifyListeners();
  }

  void _applyTheme() {
    _coreInstance.setTheme(theme: DefTheme.getTheme(_selectedThemeType));
  }

  TUITheme get theme {
    return DefTheme.getTheme(_selectedThemeType);
  }

  set theme(TUITheme theme) {
    _selectedThemeType =
        identical(theme, DefTheme.darkTheme) ? ThemeType.dark : ThemeType.blue;
    notifyListeners();
  }

  ThemeType get currentThemeType =>
      DefTheme.resolveThemeType(_selectedThemeType);

  ThemeType get selectedThemeType =>
      DefTheme.normalizeThemeType(_selectedThemeType);

  ThemeMode get materialThemeMode {
    return currentThemeType == ThemeType.dark
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  set currentThemeType(ThemeType type) {
    final normalizedType = DefTheme.normalizeThemeType(type);
    _selectedThemeType = normalizedType;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('themeType', normalizedType.toString());
    });
    _applyTheme();
    notifyListeners();
  }
}
