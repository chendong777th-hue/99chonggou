
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';
import 'package:extended_text/extended_text.dart';

class HttpText extends SpecialText {
  HttpText(TextStyle? textStyle, SpecialTextGestureTapCallback? onTap,
      {this.start})
      : super(flag, flag, textStyle, onTap: onTap);
  static const String flag = '!@TURL#*&\$';
  final int? start;
  @override
  InlineSpan finishText() {
    final String text = getContent();
    final onLightBubble = MessageBubbleTextColor.bodyStyleOnLightBubble(textStyle);
    final linkColor =
        onLightBubble ? Colors.white : const Color(0xFF1E90FF);
    final linkStyle = (textStyle ?? const TextStyle()).copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
      fontWeight: FontWeight.w600,
    );

    return SpecialTextSpan(
        text: text,
        actualText: toString(),
        start: start!,

        ///caret can move into special text
        deleteAll: true,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (onTap != null) {
              onTap!(toString());
            }
          });
  }
}
