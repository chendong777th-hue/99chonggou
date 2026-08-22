import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/at_me_jump.dart';

void main() {
  group('AtMeJump.parseTargetSeq', () {
    test('parses plain and trimmed seq', () {
      expect(AtMeJump.parseTargetSeq('1081'), 1081);
      expect(AtMeJump.parseTargetSeq(' 42 '), 42);
      expect(AtMeJump.canonicalSeqString(' 0042 '), '42');
    });

    test('rejects empty and non-int', () {
      expect(AtMeJump.parseTargetSeq(null), isNull);
      expect(AtMeJump.parseTargetSeq(''), isNull);
      expect(AtMeJump.parseTargetSeq('   '), isNull);
      expect(AtMeJump.parseTargetSeq('abc'), isNull);
      expect(AtMeJump.canonicalSeqString('nope'), isNull);
    });
  });
}
