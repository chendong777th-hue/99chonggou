import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';

class CallMessageBubbleStyle {
  const CallMessageBubbleStyle({
    required this.background,
    required this.textColor,
    this.border,
  });

  final Color background;
  final Color textColor;
  final Border? border;

  static BorderRadius bubbleBorderRadius({required bool isFromSelf}) {
    return isFromSelf
        ? const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(2),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          );
  }

  static CallMessageBubbleStyle resolve(
    TUITheme theme, {
    required bool isFromSelf,
  }) {
    final background = isFromSelf
        ? (theme.chatMessageItemFromSelfBgColor ??
            theme.lightPrimaryMaterialColor.shade50)
        : (theme.chatMessageItemFromOthersBgColor ??
            theme.weakBackgroundColor ??
            Colors.white);
    final isDarkBubble =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    final textColor = isDarkBubble
        ? (isFromSelf
            ? Colors.white
            : (theme.chatMessageItemTextColor ??
                theme.darkTextColor ??
                Colors.white))
        : (theme.darkTextColor ?? Colors.black);
    final Border? border = isDarkBubble
        ? (!isFromSelf
            ? Border.all(
                color: theme.weakDividerColor ?? const Color(0xFF252525),
                width: MessageBubbleTextColor.bubbleBorderWidth,
              )
            : null)
        : MessageBubbleTextColor.messageBubbleBorder(
            isFromSelf: isFromSelf,
            bubbleBackground: background,
          );
    return CallMessageBubbleStyle(
      background: background,
      textColor: textColor,
      border: border,
    );
  }
}
