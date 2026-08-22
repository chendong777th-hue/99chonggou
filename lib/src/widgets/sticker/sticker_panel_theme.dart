import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 表情面板配色（随应用蓝/暗色主题切换）。
class StickerPanelTheme {
  const StickerPanelTheme({
    required this.panelBackground,
    required this.bottomBarBackground,
    required this.selectedTabColor,
    required this.addCellBackground,
    required this.addCellBorder,
    required this.mutedIconColor,
    required this.unselectedTabForeground,
    required this.onSelectedTabIconColor,
    required this.emptyHintTextColor,
    required this.deleteButtonBackground,
    required this.deleteButtonShadow,
  });

  final Color panelBackground;
  final Color bottomBarBackground;
  final Color selectedTabColor;
  final Color addCellBackground;
  final Color addCellBorder;
  final Color mutedIconColor;
  final Color unselectedTabForeground;
  final Color onSelectedTabIconColor;
  final Color emptyHintTextColor;
  final Color deleteButtonBackground;
  final Color deleteButtonShadow;

  static const Color wechatGreen = Color(0xFF07C160);
  static const Color heartPink = Color(0xFFFF6B9D);

  static StickerPanelTheme of(BuildContext context) {
    final appTheme = Provider.of<DefaultThemeData>(context, listen: true);
    final isDark = appTheme.currentThemeType == ThemeType.dark;
    final tui = appTheme.theme;
    return isDark ? _dark(tui) : _light(tui);
  }

  static StickerPanelTheme _light(TUITheme tui) {
    return StickerPanelTheme(
      panelBackground: const Color(0xFFEDEDED),
      bottomBarBackground: const Color(0xFFF7F7F7),
      selectedTabColor: wechatGreen,
      addCellBackground: Colors.white,
      addCellBorder: const Color(0xFFD8D8D8),
      mutedIconColor: tui.weakTextColor ?? const Color(0xFF8A8A8A),
      unselectedTabForeground: tui.darkTextColor ?? Colors.black87,
      onSelectedTabIconColor: Colors.white,
      emptyHintTextColor: tui.weakTextColor ?? const Color(0xFF8A8A8A),
      deleteButtonBackground: Colors.white,
      deleteButtonShadow: const Color(0x66BEBEBE),
    );
  }

  static StickerPanelTheme _dark(TUITheme tui) {
    final surface = tui.inputFillColor ?? const Color(0xFF171717);
    final bar = tui.weakBackgroundColor ?? const Color(0xFF0F0F0F);
    return StickerPanelTheme(
      panelBackground: surface,
      bottomBarBackground: bar,
      selectedTabColor: wechatGreen,
      addCellBackground:
          tui.conversationItemBgColor ?? const Color(0xFF1D1D1D),
      addCellBorder: tui.weakDividerColor ?? const Color(0xFF252525),
      mutedIconColor: tui.weakTextColor ?? const Color(0xFF8A8A8A),
      unselectedTabForeground: tui.darkTextColor ?? const Color(0xFFD6D6D6),
      onSelectedTabIconColor: Colors.white,
      emptyHintTextColor: tui.weakTextColor ?? const Color(0xFF8A8A8A),
      deleteButtonBackground:
          tui.conversationItemBgColor ?? const Color(0xFF2A2A2A),
      deleteButtonShadow: const Color(0x66000000),
    );
  }
}
