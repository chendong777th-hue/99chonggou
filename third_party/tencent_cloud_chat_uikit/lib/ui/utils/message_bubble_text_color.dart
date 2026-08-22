import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 根据消息气泡背景色解析正文、引用区、时间戳等文字颜色，保证深浅主题下可读性。
class MessageBubbleTextColor {
  MessageBubbleTextColor._();

  /// Web 内置简中字体（与宿主 app pubspec 中 NotoSansSC 一致）。
  static const String webCjkFontFamily = 'NotoSansSC';

  /// 聊天气泡正文（收发双方）默认字重，略重于系统 normal。
  static const FontWeight messageBodyFontWeight = FontWeight.w500;

  /// 消息正文：15.5 / w500 / height 1.20。
  static const double messageBodyFontSize = 15.5;

  /// 与气泡正文默认行高一致。
  static const double messageBodyLineHeight = 1.20;

  /// 气泡左右 padding（约 11~12）。
  static const double messageBubblePaddingHorizontal = 12;

  /// 气泡上下 padding（约 7~8）。
  static const double messageBubblePaddingVertical = 8;

  static const EdgeInsets messageBubblePadding = EdgeInsets.symmetric(
    horizontal: messageBubblePaddingHorizontal,
    vertical: messageBubblePaddingVertical,
  );

  /// 气泡边线（浅色会话，收发双方一致）。
  static const Color bubbleBorderColor = Color(0xFFE6E6E6);
  static const double bubbleBorderWidth = 0.5;

  /// @Deprecated 请用 [bubbleBorderColor]
  static const Color othersBubbleBorderColor = bubbleBorderColor;

  /// @Deprecated 请用 [bubbleBorderWidth]
  static const double othersBubbleBorderWidth = bubbleBorderWidth;

  /// 浅色气泡描边（己方 / 对方相同）；深色气泡不描边。
  static Border? messageBubbleBorder({
    Color? bubbleBackground,
    // 保留参数以兼容旧调用点；收发双方均描边。
    bool? isFromSelf,
  }) {
    if (bubbleBackground != null &&
        ThemeData.estimateBrightnessForColor(bubbleBackground) ==
            Brightness.dark) {
      return null;
    }
    return Border.all(
      color: bubbleBorderColor,
      width: bubbleBorderWidth,
    );
  }

  /// @Deprecated 请用 [messageBubbleBorder]
  static Border? othersBubbleBorder({
    required bool isFromSelf,
    Color? bubbleBackground,
  }) {
    return messageBubbleBorder(
      isFromSelf: isFromSelf,
      bubbleBackground: bubbleBackground,
    );
  }

  /// iOS/Android：不设 [fontFamily]，由系统字体栈自动选择 CJK + Color Emoji。
  /// Web：必须显式 [NotoSansSC]；否则 [inherit: false] 会落到无 CJK 的系统字体，中文不可见。

  /// 气泡正文基础样式（字号、字体、行高），不含颜色与字重。
  static TextStyle messageBodyBaseStyle({
    required double fontSize,
    double? lineHeight,
  }) {
    return TextStyle(
      fontSize: fontSize,
      inherit: false,
      textBaseline: TextBaseline.alphabetic,
      height: lineHeight,
      fontFamily: kIsWeb ? webCjkFontFamily : null,
    );
  }

  /// 聊天输入框文字样式，与气泡正文使用同一字体族、字重与行高。
  static TextStyle messageInputTextStyle({
    required double fontSize,
    required Color color,
    double? lineHeight,
  }) {
    return messageBodyBaseStyle(
      fontSize: fontSize,
      lineHeight: lineHeight ?? messageBodyLineHeight,
    ).copyWith(
      color: color,
      fontWeight: messageBodyFontWeight,
      inherit: false,
    );
  }

  static TextStyle messageInputHintStyle({
    required double fontSize,
    required Color color,
    double? lineHeight,
  }) {
    return messageBodyBaseStyle(
      fontSize: fontSize,
      lineHeight: lineHeight ?? messageBodyLineHeight,
    ).copyWith(
      color: color,
      fontWeight: FontWeight.w400,
      inherit: false,
    );
  }

  /// 低于该亮度时使用浅色字（白/近白）。
  static const double lightTextLuminanceThreshold = 0.58;

  static bool shouldUseLightText(Color backgroundColor) {
    return backgroundColor.computeLuminance() < lightTextLuminanceThreshold;
  }

  static Color primaryText({
    required TUITheme theme,
    required Color backgroundColor,
    Color? overrideColor,
  }) {
    if (overrideColor != null) {
      return overrideColor;
    }
    if (shouldUseLightText(backgroundColor)) {
      return Colors.white;
    }
    return theme.chatMessageItemTextColor ??
        theme.darkTextColor ??
        const Color(0xFF1A1A1A);
  }

  /// 气泡内正文样式（颜色 + 字重），收发消息共用。
  static TextStyle bodyTextStyle({
    required TUITheme theme,
    required Color backgroundColor,
    TextStyle? fontStyle,
    required double fontSize,
    double? lineHeight,
  }) {
    final bodyColor = primaryText(
      theme: theme,
      backgroundColor: backgroundColor,
      overrideColor: fontStyle?.color,
    );
    return messageBodyBaseStyle(
      fontSize: fontStyle?.fontSize ?? fontSize,
      lineHeight: lineHeight ?? fontStyle?.height,
    ).copyWith(
      color: bodyColor,
      fontWeight: _resolveBodyFontWeight(fontStyle?.fontWeight),
    );
  }

  static FontWeight _resolveBodyFontWeight(FontWeight? existing) {
    if (existing == null ||
        existing == FontWeight.w400 ||
        existing == FontWeight.normal) {
      return messageBodyFontWeight;
    }
    if (existing.value < messageBodyFontWeight.value) {
      return messageBodyFontWeight;
    }
    return existing;
  }

  static Color secondaryText({
    required TUITheme theme,
    required Color backgroundColor,
  }) {
    if (shouldUseLightText(backgroundColor)) {
      return Colors.white.withValues(alpha: 0.94);
    }
    final base = theme.chatMessageItemTextColor ??
        theme.darkTextColor ??
        const Color(0xFF2F3236);
    return base.withValues(alpha: 0.92);
  }

  static Color metaText({
    required TUITheme theme,
    required Color backgroundColor,
    Color? overrideColor,
  }) {
    if (overrideColor != null) {
      return overrideColor.withValues(
        alpha: shouldUseLightText(backgroundColor) ? 0.92 : 0.78,
      );
    }
    if (shouldUseLightText(backgroundColor)) {
      return Colors.white.withValues(alpha: 0.92);
    }
    final base = theme.chatMessageItemUnreadStatusTextColor ??
        theme.weakTextColor ??
        const Color(0xFF666666);
    return base.withValues(alpha: 0.88);
  }

  static Color quoteBackground(Color backgroundColor) {
    if (shouldUseLightText(backgroundColor)) {
      return Colors.white.withValues(alpha: 0.22);
    }
    return Colors.black.withValues(alpha: 0.12);
  }

  static Color quoteBorder(Color backgroundColor) {
    if (shouldUseLightText(backgroundColor)) {
      return Colors.white.withValues(alpha: 0.55);
    }
    return Colors.black.withValues(alpha: 0.30);
  }

  static Color quoteSenderText({
    required TUITheme theme,
    required Color backgroundColor,
  }) {
    if (shouldUseLightText(backgroundColor)) {
      return Colors.white;
    }
    return theme.primaryColor ?? const Color(0xFF1E90FF);
  }

  static Color quoteContentText({
    required TUITheme theme,
    required Color backgroundColor,
  }) {
    if (shouldUseLightText(backgroundColor)) {
      return Colors.white.withValues(alpha: 0.82);
    }
    return (theme.weakTextColor ??
            theme.chatMessageItemUnreadStatusTextColor ??
            const Color(0xFF666666))
        .withValues(alpha: 0.88);
  }

  /// 气泡内可点击超链接颜色（与正文区分、保证对比度）。
  static Color hyperlinkText({
    required TUITheme theme,
    required Color backgroundColor,
  }) {
    if (shouldUseLightText(backgroundColor)) {
      return Colors.white;
    }
    return theme.primaryColor ?? const Color(0xFF1E90FF);
  }

  static TextStyle hyperlinkTextStyle({
    required TUITheme theme,
    required Color backgroundColor,
    TextStyle? bodyStyle,
  }) {
    final color = hyperlinkText(theme: theme, backgroundColor: backgroundColor);
    return (bodyStyle ?? const TextStyle()).copyWith(
      color: color,
      decoration: TextDecoration.underline,
      decorationColor: color,
      fontWeight: FontWeight.w600,
    );
  }

  /// 根据正文字色推断气泡深浅（用于未传入 background 时的兜底）。
  static bool bodyStyleOnLightBubble(TextStyle? bodyStyle) {
    final body = bodyStyle?.color;
    if (body == null) {
      return false;
    }
    return body.computeLuminance() > 0.55;
  }

  static Color linkPreviewCardBackground(Color backgroundColor) {
    if (shouldUseLightText(backgroundColor)) {
      return Colors.white.withValues(alpha: 0.22);
    }
    return Colors.black.withValues(alpha: 0.06);
  }

  static Color linkPreviewCardBorder(Color backgroundColor) {
    if (shouldUseLightText(backgroundColor)) {
      return Colors.white.withValues(alpha: 0.35);
    }
    return Colors.black.withValues(alpha: 0.1);
  }

  static Color linkPreviewTitle({
    required TUITheme theme,
    required Color backgroundColor,
  }) {
    if (shouldUseLightText(backgroundColor)) {
      return Colors.white;
    }
    return theme.chatMessageItemTextColor ??
        theme.darkTextColor ??
        const Color(0xFF1A1A1A);
  }

  static Color linkPreviewDescription({
    required TUITheme theme,
    required Color backgroundColor,
  }) {
    if (shouldUseLightText(backgroundColor)) {
      return Colors.white.withValues(alpha: 0.92);
    }
    return theme.weakTextColor ?? const Color(0xFF555555);
  }
}
