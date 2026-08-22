import 'package:extended_text/extended_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/common/utils.dart';

class ChatIdMentionText extends SpecialText {
  ChatIdMentionText(
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap, {
    this.start,
  }) : super(flag, flag, textStyle, onTap: onTap);

  static const String flag = '!@99CHATID#*&\$';

  final int? start;

  static String parseRawId(String mentionText) {
    final trimmed = mentionText.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    // 完整/公开群 ID（含中间 `@`）保留原样，供加群解析。
    if (trimmed.toUpperCase().contains('TGS#')) {
      return trimmed.startsWith('@') ? trimmed : '@$trimmed';
    }
    if (trimmed.startsWith('@')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  @override
  InlineSpan finishText() {
    final String text = getContent();
    final linkColor = LinkUtils.hexToColor('015fff');

    return SpecialTextSpan(
      text: text,
      actualText: toString(),
      start: start!,
      deleteAll: true,
      style: TextStyle(color: linkColor),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          if (onTap != null) {
            onTap!(parseRawId(text));
          }
        },
    );
  }
}
