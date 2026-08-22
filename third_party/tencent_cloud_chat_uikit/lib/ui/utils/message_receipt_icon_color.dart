import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// C2C 消息已读勾颜色：浅色主题蓝色，深色主题白色。
class MessageReceiptIconColor {
  MessageReceiptIconColor._();

  static Color resolve({
    required BuildContext context,
    required TUITheme theme,
    required bool isPeerRead,
  }) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    if (isDarkTheme) {
      return Colors.white.withValues(alpha: isPeerRead ? 1.0 : 0.88);
    }
    final blue = theme.primaryColor ?? const Color(0xFF1E90FF);
    return blue.withValues(alpha: isPeerRead ? 1.0 : 0.58);
  }
}
