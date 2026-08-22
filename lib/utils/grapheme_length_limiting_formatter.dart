import 'package:characters/characters.dart';
import 'package:flutter/services.dart';

/// 按 Unicode 字素簇（与 [Characters.length] 一致）限制输入长度。
class GraphemeLengthLimitingTextInputFormatter extends TextInputFormatter {
  GraphemeLengthLimitingTextInputFormatter(this.maxLength);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newGraphemes = newValue.text.characters;
    final newLength = newGraphemes.length;
    if (newLength <= maxLength) {
      return newValue;
    }

    final oldLength = oldValue.text.characters.length;
    // 已超长时仅允许删减，禁止继续输入。
    if (newLength < oldLength) {
      return newValue;
    }
    if (oldLength >= maxLength) {
      return oldValue;
    }

    // 从未超长状态粘贴/输入导致超出时，截断到上限。
    final truncated = newGraphemes.take(maxLength).toString();
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
      composing: TextRange.empty,
    );
  }
}
