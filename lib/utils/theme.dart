import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

enum ThemeType { system, blue, dark }

class DefTheme {
  static const TUITheme blueTheme = TUITheme(
    primaryColor: AppTokens.accent,
    lightPrimaryColor: AppTokens.accent,
    weakBackgroundColor: AppTokens.surfaceLight,
    wideBackgroundColor: AppTokens.surfaceLight,
    weakDividerColor: AppTokens.chatChromeDivider,
    darkTextColor: AppTokens.chatBubbleTextLight,
    weakTextColor: AppTokens.textSecondaryLight,
    inputFillColor: AppTokens.surfaceAltLight,
    appbarBgColor: AppTokens.surfaceLight,
    appbarTextColor: AppTokens.textPrimaryLight,
    conversationItemBgColor: AppTokens.surfaceLight,
    conversationItemPinedBgColor: AppTokens.surfaceAltLight,
    conversationItemChooseBgColor: AppTokens.accentSoft,
    conversationItemBorderColor: AppTokens.borderLight,
    conversationItemTitleTextColor: AppTokens.textPrimaryLight,
    conversationItemLastMessageTextColor: AppTokens.textSecondaryLight,
    conversationItemTitmeTextColor: AppTokens.textSecondaryLight,
    chatBgColor: AppTokens.chatBgLight,
    chatHeaderBgColor: AppTokens.surfaceLight,
    chatHeaderTitleTextColor: AppTokens.textPrimaryLight,
    chatHeaderBackTextColor: AppTokens.accent,
    chatHeaderActionTextColor: AppTokens.textPrimaryLight,
    chatMessageItemTextColor: AppTokens.chatBubbleTextLight,
    chatMessageItemFromSelfBgColor: AppTokens.chatBubbleSelfLight,
    chatMessageItemFromOthersBgColor: AppTokens.chatBubbleOtherLight,
  );

  static const TUITheme darkTheme = TUITheme(
    primaryColor: AppTokens.accent,
    lightPrimaryColor: AppTokens.brand400,
    weakBackgroundColor: AppTokens.backgroundDark,
    wideBackgroundColor: AppTokens.backgroundDark,
    weakDividerColor: AppTokens.borderDark,
    darkTextColor: AppTokens.textPrimaryDark,
    weakTextColor: AppTokens.textSecondaryDark,
    inputFillColor: AppTokens.surfaceDark,
    selectPanelBgColor: AppTokens.surfaceDark,
    selectPanelTextIconColor: AppTokens.textPrimaryDark,
    appbarBgColor: AppTokens.backgroundDark,
    appbarTextColor: AppTokens.textPrimaryDark,
    conversationItemBgColor: AppTokens.surfaceDark,
    conversationItemActiveBgColor: AppTokens.surfaceAltDark,
    conversationItemPinedBgColor: AppTokens.surfaceAltDark,
    conversationItemChooseBgColor: AppTokens.surfaceAltDark,
    conversationItemBorderColor: AppTokens.borderDark,
    conversationItemTitleTextColor: AppTokens.textPrimaryDark,
    conversationItemLastMessageTextColor: AppTokens.textSecondaryDark,
    conversationItemTitmeTextColor: AppTokens.textSecondaryDark,
    chatBgColor: AppTokens.backgroundDark,
    desktopChatMessageInputBgColor: AppTokens.surfaceDark,
    chatHeaderBgColor: AppTokens.backgroundDark,
    chatHeaderTitleTextColor: AppTokens.textPrimaryDark,
    chatHeaderBackTextColor: AppTokens.accent,
    chatHeaderActionTextColor: AppTokens.textPrimaryDark,
    chatMessageItemTextColor: AppTokens.textPrimaryDark,
    chatMessageItemFromSelfBgColor: AppTokens.accent,
    chatMessageItemFromOthersBgColor: AppTokens.surfaceDark,
    chatMessageItemUnreadStatusTextColor: AppTokens.textSecondaryDark,
  );

  static ThemeType normalizeThemeType(Object? value) {
    return themeTypeFromString(value?.toString() ?? '');
  }

  static ThemeType themeTypeFromString(String str) {
    switch (str) {
      case 'ThemeType.system':
      case 'ThemeType.followSystem':
      case 'ThemeType.systemMode':
        return ThemeType.system;
      case 'ThemeType.dark':
      case 'ThemeType.solemn':
        return ThemeType.dark;
      case 'ThemeType.blue':
      case 'ThemeType.brisk':
      case 'ThemeType.bright':
      case 'ThemeType.fantasy':
        return ThemeType.blue;
      default:
        if (str.isEmpty) {
          return ThemeType.system;
        }
        return ThemeType.blue;
    }
  }

  static ThemeType resolveThemeType(Object? value) {
    final type = normalizeThemeType(value);
    if (type == ThemeType.system) {
      return PlatformDispatcher.instance.platformBrightness == Brightness.dark
          ? ThemeType.dark
          : ThemeType.blue;
    }
    return type;
  }

  static TUITheme getTheme(Object? value) {
    final type = resolveThemeType(value);
    switch (type) {
      case ThemeType.dark:
        return darkTheme;
      case ThemeType.system:
      case ThemeType.blue:
        return blueTheme;
    }
  }

  static String getThemeName(Object? value) {
    final type = normalizeThemeType(value);
    switch (type) {
      case ThemeType.system:
        return TIM_t("跟随系统");
      case ThemeType.dark:
        return TIM_t("深色主题");
      case ThemeType.blue:
        return TIM_t("日间主题");
    }
  }
}
