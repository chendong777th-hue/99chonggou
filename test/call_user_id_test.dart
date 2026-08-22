import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';

void main() {
  group('CallUserId.normalizeCallUserId', () {
    test('strips c2c_ prefix', () {
      expect(CallUserId.normalizeCallUserId('c2c_user_a'), 'user_a');
    });

    test('strips TRTC composite suffix', () {
      expect(
        CallUserId.normalizeCallUserId('acnj6oxey9#0#0#rqwm8onw3j'),
        'acnj6oxey9',
      );
    });

    test('trims whitespace', () {
      expect(CallUserId.normalizeCallUserId('  user_a  '), 'user_a');
    });
  });

  group('CallUserId.isSameCallUserId', () {
    test('matches plain and composite ids', () {
      expect(
        CallUserId.isSameCallUserId('user_a', 'user_a#0#0#xyz'),
        isTrue,
      );
    });

    test('returns false when either side empty', () {
      expect(CallUserId.isSameCallUserId('', 'user_a'), isFalse);
      expect(CallUserId.isSameCallUserId('user_a', ''), isFalse);
    });
  });

  group('CallUserId role helpers', () {
    test('recognizes caller role', () {
      expect(CallUserId.isCallerRole(TUICallRole.caller), isTrue);
      expect(CallUserId.isCallerRoleName('caller'), isTrue);
    });

    test('recognizes called and legacy callee role names', () {
      expect(CallUserId.isCalleeRole(TUICallRole.called), isTrue);
      expect(CallUserId.isCalleeRoleName('called'), isTrue);
      expect(CallUserId.isCalleeRoleName('callee'), isTrue);
    });
  });
}
