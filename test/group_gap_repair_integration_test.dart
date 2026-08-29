import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_identity.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_writer.dart';

MessageReconciliationRecord<String> _record(int seq, String source) {
  return MessageReconciliationRecord<String>(
    value: '$source-$seq',
    msgID: 'm$seq',
    seq: '$seq',
  );
}

void main() {
  test('gap history and concurrent realtime publish every msgID exactly once',
      () {
    final writer = MessageReconciliationWriter<String>(
      comparator: (left, right) =>
          right.numericSeq!.compareTo(left.numericSeq!),
    );
    writer.seedAuthoritative(
      conversationID: 'group_room',
      trackSeqGaps: true,
      records: <MessageReconciliationRecord<String>>[
        _record(103, 'existing'),
        _record(100, 'existing'),
      ],
    );
    final request = writer.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(
      writer.enqueueRealtime(
        conversationID: 'group_room',
        eventID: 'realtime-104',
        records: <MessageReconciliationRecord<String>>[
          _record(104, 'realtime'),
        ],
      ),
      isNull,
    );

    final commit = writer.completeHistory(
      request: request,
      history: <MessageReconciliationRecord<String>>[
        _record(101, 'cloud'),
        _record(102, 'cloud'),
        _record(102, 'cloud-duplicate'),
      ],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(commit, isNotNull);
    expect(
      commit!.records.map((record) => record.numericSeq),
      <int?>[104, 103, 102, 101, 100],
    );
    expect(
      commit.records.map((record) => record.serverIdentity).toSet(),
      <String?>{'m100', 'm101', 'm102', 'm103', 'm104'},
    );
    expect(commit.missingSeqRanges, isEmpty);
    expect(writer.pendingRealtimeCount('group_room'), 0);
    expect(
      writer.coordinator.stateFor('group_room').phase,
      MessageReconciliationPhase.cloudWindowPartial,
    );
  });

  test('a continuation page commits while state remains incomplete', () {
    final writer = MessageReconciliationWriter<String>(
      comparator: (left, right) =>
          right.numericSeq!.compareTo(left.numericSeq!),
    );
    writer.seedAuthoritative(
      conversationID: 'c2c_peer',
      records: <MessageReconciliationRecord<String>>[_record(1, 'existing')],
    );
    final request = writer.beginCloudCatchUp(
      conversationID: 'c2c_peer',
      networkState: MessageReconciliationNetworkState.online,
    );

    final commit = writer.completeHistory(
      request: request,
      history: <MessageReconciliationRecord<String>>[_record(2, 'cloud')],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
      cloudHasMoreNewer: true,
    );

    expect(commit!.records.map((record) => record.numericSeq), <int?>[2, 1]);
    final state = writer.coordinator.stateFor('c2c_peer');
    expect(state.cloudHasMoreNewer, isTrue);
    expect(
      state.phase,
      MessageReconciliationPhase.cloudContinuationPending,
    );
  });
}
