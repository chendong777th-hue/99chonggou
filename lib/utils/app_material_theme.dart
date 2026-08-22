import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

SystemUiOverlayStyle buildAppSystemUiOverlayStyle(
  TUITheme theme, {
  required bool isDark,
}) {
  final statusBarBackground = theme.appbarBgColor ??
      theme.weakBackgroundColor ??
      (isDark ? const Color(0xFF0F0F0F) : Colors.white);
  final navigationBarBackground =
      theme.weakBackgroundColor ?? statusBarBackground;

  return immersiveOverlayForColors(
    statusBarBackground: statusBarBackground,
    navigationBarBackground: navigationBarBackground,
  );
}

ThemeData buildAppMaterialTheme(
  TUITheme theme, {
  required bool isDark,
}) {
  final systemOverlayStyle =
      buildAppSystemUiOverlayStyle(theme, isDark: isDark);
  final cursorColor =
      isDark ? Colors.white : theme.primaryColor ?? const Color(0xFF1E90FF);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: theme.primaryColor ?? const Color(0xFF1E90FF),
    brightness: isDark ? Brightness.dark : Brightness.light,
    surface: theme.conversationItemBgColor ?? theme.weakBackgroundColor,
  ).copyWith(
    primary: theme.primaryColor ?? const Color(0xFF1E90FF),
    surface: theme.conversationItemBgColor ?? theme.weakBackgroundColor,
    onSurface: theme.darkTextColor,
    onPrimary: Colors.white,
    outline: theme.weakDividerColor,
  );

  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    fontFamily: kIsWeb ? AppTokens.fontFamily : null,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: theme.weakBackgroundColor,
    cardColor: theme.conversationItemBgColor ?? theme.weakBackgroundColor,
    dialogTheme: DialogThemeData(
      backgroundColor:
          theme.conversationItemBgColor ?? theme.weakBackgroundColor,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: theme.selectPanelBgColor ??
          theme.conversationItemBgColor ??
          theme.weakBackgroundColor,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: theme.darkTextColor),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: theme.appbarBgColor,
      foregroundColor: theme.appbarTextColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: systemOverlayStyle,
      titleTextStyle: TextStyle(
        color: theme.appbarTextColor,
        fontFamily: kIsWeb ? AppTokens.fontFamily : null,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: cursorColor,
      selectionColor: (theme.primaryColor ?? const Color(0xFF1E90FF))
          .withValues(alpha: 0.22),
      selectionHandleColor: cursorColor,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: theme.inputFillColor,
      hintStyle: TextStyle(color: theme.weakTextColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: AppPageTransitionsBuilder(),
        TargetPlatform.android: AppPageTransitionsBuilder(),
        TargetPlatform.macOS: AppPageTransitionsBuilder(),
        TargetPlatform.linux: AppPageTransitionsBuilder(),
        TargetPlatform.windows: AppPageTransitionsBuilder(),
        TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
      },
    ),
  );
}
