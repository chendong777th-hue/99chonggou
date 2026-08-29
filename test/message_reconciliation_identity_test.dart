import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_identity.dart';

MessageReconciliationRecord<String> _record(
  String value, {
  String? msgID,
  String? localID,
  String? stableID,
  String? seq,
}) {
  return MessageReconciliationRecord<String>(
    value: value,
    msgID: msgID,
    localID: localID,
    outgoingStableID: stableID,
    seq: seq,
  );
}

void main() {
  test('realtime then history dedupes by exact server msgID', () {
    final result = MessageReconciliationIdentity
        .merge(<MessageReconciliationRecord<String>>[
      _record('realtime', msgID: 'm1', localID: 'local-a', seq: '10'),
      _record('history', msgID: 'm1', localID: 'local-b', seq: '10'),
    ]);

    expect(result.records, hasLength(1));
    expect(result.records.single.value, 'history');
  });

  test('history then realtime dedupes independently of source order', () {
    final result = MessageReconciliationIdentity
        .merge(<MessageReconciliationRecord<String>>[
      _record('history', msgID: 'm1', seq: '10'),
      _record('realtime', msgID: 'm1', seq: '10'),
    ]);

    expect(result.records, hasLength(1));
    expect(result.records.single.value, 'realtime');
  });

  test('same Seq with different msgID retains both and reports conflict', () {
    final result = MessageReconciliationIdentity
        .merge(<MessageReconciliationRecord<String>>[
      _record('first', msgID: 'm1', seq: '20'),
      _record('second', msgID: 'm2', seq: '20'),
    ]);

    expect(result.records.map((item) => item.value), <String>[
      'first',
      'second',
    ]);
    expect(result.seqIdentityConflicts, hasLength(1));
    expect(result.seqIdentityConflicts.single.seq, 20);
    expect(result.seqIdentityConflicts.single.msgIDs, <String>{'m1', 'm2'});
  });

  test('missing numeric Seq creates bounded continuity ranges', () {
    final result = MessageReconciliationIdentity
        .merge(<MessageReconciliationRecord<String>>[
      _record('10', msgID: 'm10', seq: '10'),
      _record('12', msgID: 'm12', seq: '12'),
      _record('15', msgID: 'm15', seq: '15'),
      _record('invalid', msgID: 'bad', seq: 'not-a-number'),
    ]);

    expect(result.oldestSeq, 10);
    expect(result.newestSeq, 15);
    expect(result.missingSeqRanges, const <MessageSeqRange>[
      MessageSeqRange(11, 11),
      MessageSeqRange(13, 14),
    ]);
  });

  test('optimistic stable identity is replaced by server msgID', () {
    final result = MessageReconciliationIdentity
        .merge(<MessageReconciliationRecord<String>>[
      _record(
        'optimistic',
        localID: 'plugin-local-1',
        stableID: 'outgoing-1',
      ),
      _record(
        'server',
        msgID: 'server-1',
        localID: 'plugin-local-2',
        stableID: 'outgoing-1',
        seq: '30',
      ),
    ]);

    expect(result.records, hasLength(1));
    expect(result.records.single.value, 'server');
    expect(result.records.single.serverIdentity, 'server-1');
  });

  test('optimistic retry cannot replace an already confirmed server row', () {
    final result = MessageReconciliationIdentity
        .merge(<MessageReconciliationRecord<String>>[
      _record('server', msgID: 'server-1', stableID: 'outgoing-1'),
      _record('retry', localID: 'plugin-local-3', stableID: 'outgoing-1'),
    ]);

    expect(result.records, hasLength(1));
    expect(result.records.single.value, 'server');
  });

  test('repeated retries with one stable identity remain one optimistic row',
      () {
    final result = MessageReconciliationIdentity
        .merge(<MessageReconciliationRecord<String>>[
      _record('try-1', localID: 'id-1', stableID: 'outgoing-1'),
      _record('try-2', localID: 'id-2', stableID: 'outgoing-1'),
      _record('try-3', localID: 'id-3', stableID: 'outgoing-1'),
    ]);

    expect(result.records, hasLength(1));
    expect(result.records.single.value, 'try-3');
  });

  test('SDK local id alone never dedupes cloud records', () {
    final result = MessageReconciliationIdentity
        .merge(<MessageReconciliationRecord<String>>[
      _record('anonymous-1', localID: 'same-local-id'),
      _record('anonymous-2', localID: 'same-local-id'),
    ]);

    expect(result.records, hasLength(2));
  });

  test('different server msgIDs sharing stable id are both preserved', () {
    final result = MessageReconciliationIdentity
        .merge(<MessageReconciliationRecord<String>>[
      _record('server-1', msgID: 'm1', stableID: 'outgoing-1', seq: '40'),
      _record('server-2', msgID: 'm2', stableID: 'outgoing-1', seq: '41'),
    ]);

    expect(result.records, hasLength(2));
    expect(result.records.map((item) => item.serverIdentity), <String>[
      'm1',
      'm2',
    ]);
  });
}
