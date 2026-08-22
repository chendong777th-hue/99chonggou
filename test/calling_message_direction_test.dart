import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/call_bubble_direction.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';

void main() {
  group('CallBubbleDirection.resolveC2C', () {
    test('caller is self -> outcoming', () {
      expect(
        CallBubbleDirection.resolveC2C(
          callerId: 'user_a',
          loginUserId: 'user_a',
        ),
        CallMessageDirection.outcoming,
      );
    });

    test('caller is peer -> incoming', () {
      expect(
        CallBubbleDirection.resolveC2C(
          callerId: 'user_b',
          loginUserId: 'user_a',
        ),
        CallMessageDirection.incoming,
      );
    });

    test('missing caller uses fallbackIsSelf true', () {
      expect(
        CallBubbleDirection.resolveC2C(
          callerId: '',
          loginUserId: 'user_a',
          fallbackIsSelf: true,
        ),
        CallMessageDirection.outcoming,
      );
    });

    test('missing caller uses fallbackIsSelf false', () {
      expect(
        CallBubbleDirection.resolveC2C(
          callerId: '',
          loginUserId: 'user_a',
          fallbackIsSelf: false,
        ),
        CallMessageDirection.incoming,
      );
    });

    test('missing login and caller defaults incoming', () {
      expect(
        CallBubbleDirection.resolveC2C(
          callerId: '',
          loginUserId: '',
        ),
        CallMessageDirection.incoming,
      );
    });

    test('trims whitespace before comparing caller and login', () {
      expect(
        CallBubbleDirection.resolveC2C(
          callerId: '  user_a  ',
          loginUserId: 'user_a',
        ),
        CallMessageDirection.outcoming,
      );
    });

    test('peer caller with padded ids stays incoming', () {
      expect(
        CallBubbleDirection.resolveC2C(
          callerId: ' user_peer ',
          loginUserId: 'user_self',
        ),
        CallMessageDirection.incoming,
      );
    });

    test('composite caller id matches plain login user as outcoming', () {
      expect(
        CallBubbleDirection.resolveC2C(
          callerId: 'user_self#0#0#abc',
          loginUserId: 'user_self',
        ),
        CallMessageDirection.outcoming,
      );
    });

    test('isOutgoingCall uses normalized comparison', () {
      expect(
        CallBubbleDirection.isOutgoingCall(
          callerId: 'user_self#0#0#abc',
          loginUserId: 'user_self',
        ),
        isTrue,
      );
    });
  });

  group('CallBubbleDirection.resolveC2CTerminalActionBySelf', () {
    const self = 'user_self';
    const peer = 'user_peer';

    test('reject with operator self -> true', () {
      expect(
        CallBubbleDirection.resolveC2CTerminalActionBySelf(
          protocolType: CallProtocolType.reject,
          callerId: peer,
          operatorId: self,
          loginUserId: self,
        ),
        isTrue,
      );
    });

    test('reject with operator peer -> false', () {
      expect(
        CallBubbleDirection.resolveC2CTerminalActionBySelf(
          protocolType: CallProtocolType.reject,
          callerId: self,
          operatorId: peer,
          loginUserId: self,
        ),
        isFalse,
      );
    });

    test('reject without operator uses fallbackIsSelf', () {
      expect(
        CallBubbleDirection.resolveC2CTerminalActionBySelf(
          protocolType: CallProtocolType.reject,
          callerId: peer,
          operatorId: '',
          loginUserId: self,
          fallbackIsSelf: true,
        ),
        isTrue,
      );
      expect(
        CallBubbleDirection.resolveC2CTerminalActionBySelf(
          protocolType: CallProtocolType.reject,
          callerId: peer,
          operatorId: '',
          loginUserId: self,
          fallbackIsSelf: false,
        ),
        isFalse,
      );
    });

    test('cancel with operator self -> true', () {
      expect(
        CallBubbleDirection.resolveC2CTerminalActionBySelf(
          protocolType: CallProtocolType.cancel,
          callerId: self,
          operatorId: self,
          loginUserId: self,
        ),
        isTrue,
      );
    });

    test('cancel without operator falls back to caller', () {
      expect(
        CallBubbleDirection.resolveC2CTerminalActionBySelf(
          protocolType: CallProtocolType.cancel,
          callerId: self,
          operatorId: '',
          loginUserId: self,
        ),
        isTrue,
      );
      expect(
        CallBubbleDirection.resolveC2CTerminalActionBySelf(
          protocolType: CallProtocolType.cancel,
          callerId: peer,
          operatorId: '',
          loginUserId: self,
        ),
        isFalse,
      );
    });

    test('cancel without operator or caller uses fallbackIsSelf', () {
      expect(
        CallBubbleDirection.resolveC2CTerminalActionBySelf(
          protocolType: CallProtocolType.cancel,
          callerId: '',
          operatorId: '',
          loginUserId: self,
          fallbackIsSelf: true,
        ),
        isTrue,
      );
    });
  });

  group('CallBubbleDirection.resolveC2CDisplayDirection', () {
    const self = 'user_self';
    const peer = 'user_peer';

    test('callDirectionHint outgoing wins over callerId peer', () {
      expect(
        CallBubbleDirection.resolveC2CDisplayDirection(
          protocolType: CallProtocolType.reject,
          callerId: peer,
          operatorId: self,
          loginUserId: self,
          callDirectionHint: CallBubbleDirection.callDirectionOutgoing,
        ),
        CallMessageDirection.outcoming,
      );
    });

    test('callDirectionHint incoming wins over callerId self', () {
      expect(
        CallBubbleDirection.resolveC2CDisplayDirection(
          protocolType: CallProtocolType.hangup,
          callerId: self,
          operatorId: peer,
          loginUserId: self,
          callDirectionHint: CallBubbleDirection.callDirectionIncoming,
        ),
        CallMessageDirection.incoming,
      );
    });

    test('without hint, callerId is ignored; fallbackIsSelf drives side', () {
      expect(
        CallBubbleDirection.resolveC2CDisplayDirection(
          protocolType: CallProtocolType.reject,
          callerId: peer,
          operatorId: self,
          loginUserId: self,
          fallbackIsSelf: true,
        ),
        CallMessageDirection.outcoming,
      );
      expect(
        CallBubbleDirection.resolveC2CDisplayDirection(
          protocolType: CallProtocolType.reject,
          callerId: self,
          operatorId: peer,
          loginUserId: self,
          fallbackIsSelf: false,
        ),
        CallMessageDirection.incoming,
      );
    });

    test('without hint or isSelf, defaults to incoming', () {
      expect(
        CallBubbleDirection.resolveC2CDisplayDirection(
          protocolType: CallProtocolType.hangup,
          callerId: self,
          operatorId: '',
          loginUserId: self,
        ),
        CallMessageDirection.incoming,
      );
    });
  });

  group('CallBubbleDirection.isOutgoing', () {
    test('outcoming direction is outgoing', () {
      expect(
        CallBubbleDirection.isOutgoing(CallMessageDirection.outcoming),
        isTrue,
      );
    });

    test('incoming direction is not outgoing', () {
      expect(
        CallBubbleDirection.isOutgoing(CallMessageDirection.incoming),
        isFalse,
      );
    });
  });

  group('CallBubbleDirection.resolveCallerIdFromDirectionHint', () {
    const self = 'user_self';
    const peer = 'user_peer';

    test('incoming hint maps caller to peer', () {
      expect(
        CallBubbleDirection.resolveCallerIdFromDirectionHint(
          callDirection: CallBubbleDirection.callDirectionIncoming,
          loginUserId: self,
          peerUserId: peer,
        ),
        peer,
      );
    });

    test('outgoing hint maps caller to self', () {
      expect(
        CallBubbleDirection.resolveCallerIdFromDirectionHint(
          callDirection: CallBubbleDirection.callDirectionOutgoing,
          loginUserId: self,
          peerUserId: peer,
        ),
        self,
      );
    });
  });

  group('CallBubbleDirection.protocolTypeFromLocalReason', () {
    test('maps reject and lineBusy separately', () {
      expect(
        CallBubbleDirection.protocolTypeFromLocalReason('reject'),
        CallProtocolType.reject,
      );
      expect(
        CallBubbleDirection.protocolTypeFromLocalReason('lineBusy'),
        CallProtocolType.lineBusy,
      );
    });
  });
}
