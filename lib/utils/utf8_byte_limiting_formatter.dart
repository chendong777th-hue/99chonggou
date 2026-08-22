import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:flutter/services.dart';

/// 按 UTF-8 字节数限制输入长度，超出时在字符边界截断（避免半个汉字）。
class Utf8ByteLimitingTextInputFormatter extends TextInputFormatter {
  Utf8ByteLimitingTextInputFormatter(this.maxBytes);

  final int maxBytes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (utf8.encode(newValue.text).length <= maxBytes) {
      return newValue;
    }
    final buffer = StringBuffer();
    var bytes = 0;
    for (final ch in newValue.text.characters) {
      final chBytes = utf8.encode(ch).length;
      if (bytes + chBytes > maxBytes) {
        break;
      }
      bytes += chBytes;
      buffer.write(ch);
    }
    final truncated = buffer.toString();
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
      composing: TextRange.empty,
    );
  }
}
