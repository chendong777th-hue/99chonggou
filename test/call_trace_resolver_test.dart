import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';

void main() {
  group('CallUserId role direction inference', () {
    test('caller role implies outgoing semantics', () {
      expect(CallUserId.isCallerRole(TUICallRole.caller), isTrue);
      expect(CallUserId.isCalleeRole(TUICallRole.caller), isFalse);
    });

    test('called role implies incoming semantics', () {
      expect(CallUserId.isCalleeRole(TUICallRole.called), isTrue);
      expect(CallUserId.isCallerRole(TUICallRole.called), isFalse);
    });

    test('none role is neither caller nor callee', () {
      expect(CallUserId.isCallerRole(TUICallRole.none), isFalse);
      expect(CallUserId.isCalleeRole(TUICallRole.none), isFalse);
    });
  });

  group('CallUserId composite id parity for trace matching', () {
    const self = 'user_self';
    const peerComposite = 'user_peer#0#0#abc';

    test('self matches composite self id', () {
      expect(
        CallUserId.isSameCallUserId('user_self#0#0#x', self),
        isTrue,
      );
    });

    test('peer composite does not match self', () {
      expect(CallUserId.isSameCallUserId(peerComposite, self), isFalse);
    });

    test('normalized peer matches plain peer', () {
      expect(
        CallUserId.isSameCallUserId(peerComposite, 'user_peer'),
        isTrue,
      );
    });
  });
}
