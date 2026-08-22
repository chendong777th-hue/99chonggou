import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_draw_input_format.dart';

void main() {
  group('SangongDrawInputFormat', () {
    test('sanitizeInitial accepts 00-99 and rejects decimals', () {
      expect(SangongDrawInputFormat.sanitizeInitial('37'), '37');
      expect(SangongDrawInputFormat.sanitizeInitial('00'), '00');
      expect(SangongDrawInputFormat.sanitizeInitial('0.88'), '');
      expect(SangongDrawInputFormat.sanitizeInitial('100'), '');
      expect(SangongDrawInputFormat.sanitizeInitial('abc'), '');
    });

    test('appendDigit caps at two digits', () {
      expect(SangongDrawInputFormat.appendDigit('', '3'), '3');
      expect(SangongDrawInputFormat.appendDigit('3', '7'), '37');
      expect(SangongDrawInputFormat.appendDigit('37', '8'), '37');
      expect(SangongDrawInputFormat.appendDigit('9', '9'), '99');
    });

    test('deleteLast removes trailing digit', () {
      expect(SangongDrawInputFormat.deleteLast('37'), '3');
      expect(SangongDrawInputFormat.deleteLast('3'), '');
      expect(SangongDrawInputFormat.deleteLast(''), '');
    });

    test('normalizeForSubmit pads to two digits', () {
      expect(SangongDrawInputFormat.isValidEntry('7'), isTrue);
      expect(SangongDrawInputFormat.normalizeForSubmit('7'), '07');
      expect(SangongDrawInputFormat.normalizeForSubmit('37'), '37');
      expect(SangongDrawInputFormat.normalizeForSubmit('00'), '00');
      expect(SangongDrawInputFormat.normalizeForSubmit(''), '');
      expect(SangongDrawInputFormat.normalizeForSubmit('0.8'), '');
    });

    test('tail sum must end in zero', () {
      expect(
        SangongDrawInputFormat.isTailSumValid(['37', '28', '15', '49', '66', '05']),
        isTrue,
      );
      expect(SangongDrawInputFormat.sumTailDigits(['37', '28', '15', '49', '66', '05']), 40);
      expect(
        SangongDrawInputFormat.isTailSumValid(['37', '37', '37', '37', '37', '37']),
        isFalse,
      );
      expect(SangongDrawInputFormat.tailSumCheckDigit(['00', '10', '20']), 0);
    });
  });
}
