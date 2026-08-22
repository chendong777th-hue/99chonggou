import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_repository.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';

void main() {
  group('CallResultRepository', () {
    test('save and get by callId', () {
      const callId = 'invite_test_001';
      CallResultRepository.instance.save(
        CallResultRecord.fromCallEnd(
          callId: callId,
          conversationId: 'c2c_peer_a',
          callerUserId: 'self_a',
          operatorUserId: 'self_a',
          peerUserId: 'peer_b',
          reasonName: 'reject',
          durationSec: 0,
          isOutgoing: false,
        ),
      );

      final record = CallResultRepository.instance.get(callId);
      expect(record, isNotNull);
      expect(record!.operatorUserId, 'self_a');
      expect(record.callerUserId, 'self_a');
      expect(record.protocolType, CallProtocolType.reject);
    });

    test('server source overrides device source', () {
      const callId = 'invite_priority_001';
      CallResultRepository.instance.save(
        CallResultRecord.fromCallEnd(
          callId: callId,
          conversationId: 'c2c_peer_x',
          callerUserId: 'self_x',
          operatorUserId: 'self_x',
          peerUserId: 'peer_x',
          reasonName: 'cancel',
          durationSec: 0,
        ),
      );
      CallResultRepository.instance.save(
        CallResultRecord.fromServer(
          callId: callId,
          conversationId: 'c2c_peer_x',
          callerUserId: 'self_x',
          operatorUserId: 'peer_x',
          peerUserId: 'peer_x',
          result: 'rejected',
          durationSec: 0,
          occurredAtMs: 1741231296000,
        ),
      );

      final record = CallResultRepository.instance.get(callId);
      expect(record!.source, CallResultSource.server);
      expect(record.protocolType, CallProtocolType.reject);
      expect(record.operatorUserId, 'peer_x');
    });

    test('device source does not override existing server source', () {
      const callId = 'invite_priority_002';
      CallResultRepository.instance.save(
        CallResultRecord.fromServer(
          callId: callId,
          conversationId: 'c2c_peer_y',
          callerUserId: 'self_y',
          operatorUserId: 'peer_y',
          peerUserId: 'peer_y',
          result: 'rejected',
          durationSec: 0,
          occurredAtMs: 1741231296000,
        ),
      );
      CallResultRepository.instance.save(
        CallResultRecord.fromCallEnd(
          callId: callId,
          conversationId: 'c2c_peer_y',
          callerUserId: 'self_y',
          operatorUserId: 'self_y',
          peerUserId: 'peer_y',
          reasonName: 'cancel',
          durationSec: 0,
        ),
      );

      final record = CallResultRepository.instance.get(callId);
      expect(record!.source, CallResultSource.server);
      expect(record.protocolType, CallProtocolType.reject);
      expect(record.operatorUserId, 'peer_y');
    });
  });

  group('CallResultRecord.protocolTypeFromServerResult', () {
    test('maps server results to protocol types', () {
      expect(CallResultRecord.protocolTypeFromServerResult('answered'),
          CallProtocolType.hangup);
      expect(CallResultRecord.protocolTypeFromServerResult('rejected'),
          CallProtocolType.reject);
      expect(CallResultRecord.protocolTypeFromServerResult('canceled'),
          CallProtocolType.cancel);
      expect(CallResultRecord.protocolTypeFromServerResult('busy'),
          CallProtocolType.lineBusy);
      expect(CallResultRecord.protocolTypeFromServerResult('missed'),
          CallProtocolType.timeout);
      expect(CallResultRecord.protocolTypeFromServerResult('failed'),
          CallProtocolType.timeout);
      expect(CallResultRecord.protocolTypeFromServerResult('weird'),
          CallProtocolType.unknown);
    });
  });
}
