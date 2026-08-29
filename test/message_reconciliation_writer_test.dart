import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_delta.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_coverage.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_identity.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_writer.dart';

MessageReconciliationRecord<String> _record(
  String value, {
  String? msgID,
  String? stableID,
  int? seq,
}) {
  return MessageReconciliationRecord<String>(
    value: value,
    msgID: msgID,
    outgoingStableID: stableID,
    seq: seq?.toString(),
  );
}

MessageReconciliationWriter<String> _writer() {
  return MessageReconciliationWriter<String>(
    comparator: (left, right) =>
        (left.numericSeq ?? 0).compareTo(right.numericSeq ?? 0),
  );
}

void main() {
  test('history and queued realtime publish through one revision', () {
    final writer = _writer();
    writer.seedAuthoritative(
      conversationID: 'group_room',
      trackSeqGaps: true,
      records: <MessageReconciliationRecord<String>>[
        _record('existing', msgID: 'm10', seq: 10),
      ],
    );
    final request = writer.beginInitialHistory(
      conversationID: 'group_room',
      requestedSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );
    expect(writer.hasActiveRequest('group_room'), isTrue);

    expect(
      writer.enqueueRealtime(
        conversationID: 'group_room',
        eventID: 'callback-12',
        records: <MessageReconciliationRecord<String>>[
          _record('realtime-12', msgID: 'm12', seq: 12),
        ],
      ),
      isNull,
    );
    expect(writer.revisionFor('group_room'), 0);

    final commit = writer.completeHistory(
      request: request,
      history: <MessageReconciliationRecord<String>>[
        _record('history-11', msgID: 'm11', seq: 11),
      ],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(commit, isNotNull);
    expect(commit!.revision, 1);
    expect(commit.records.map((record) => record.value), <String>[
      'existing',
      'history-11',
      'realtime-12',
    ]);
    expect(commit.missingSeqRanges, isEmpty);
    expect(writer.pendingRealtimeCount('group_room'), 0);
    expect(writer.hasActiveRequest('group_room'), isFalse);
  });

  test('stale completion cannot consume pending realtime for newer request',
      () {
    final writer = _writer();
    final stale = writer.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );
    writer.enqueueRealtime(
      conversationID: 'group_room',
      eventID: 'callback-20',
      records: <MessageReconciliationRecord<String>>[
        _record('realtime-20', msgID: 'm20', seq: 20),
      ],
    );
    final current = writer.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );
    writer.enqueueRealtime(
      conversationID: 'group_room',
      eventID: 'callback-22',
      records: <MessageReconciliationRecord<String>>[
        _record('realtime-22', msgID: 'm22', seq: 22),
      ],
    );

    expect(
      writer.completeHistory(
        request: stale,
        history: <MessageReconciliationRecord<String>>[
          _record('stale-19', msgID: 'm19', seq: 19),
        ],
        actualSource: MessageReconciliationSource.cloud,
        networkState: MessageReconciliationNetworkState.online,
      ),
      isNull,
    );
    expect(writer.pendingRealtimeCount('group_room'), 2);

    final commit = writer.completeHistory(
      request: current,
      history: <MessageReconciliationRecord<String>>[
        _record('history-21', msgID: 'm21', seq: 21),
      ],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );
    expect(commit!.records.map((record) => record.value), <String>[
      'realtime-20',
      'history-21',
      'realtime-22',
    ]);
    expect(commit.revision, 1);
  });

  test('history duplicate is replaced by later realtime callback', () {
    final writer = _writer();
    final request = writer.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );
    writer.enqueueRealtime(
      conversationID: 'group_room',
      eventID: 'callback-30',
      records: <MessageReconciliationRecord<String>>[
        _record('realtime', msgID: 'm30', seq: 30),
      ],
    );

    final commit = writer.completeHistory(
      request: request,
      history: <MessageReconciliationRecord<String>>[
        _record('history', msgID: 'm30', seq: 30),
      ],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(commit!.records, hasLength(1));
    expect(commit.records.single.value, 'realtime');
  });

  test('same Seq with different server IDs survives the writer commit', () {
    final writer = _writer();
    final request = writer.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );
    writer.enqueueRealtime(
      conversationID: 'group_room',
      eventID: 'callback-b',
      records: <MessageReconciliationRecord<String>>[
        _record('server-b', msgID: 'server-b', seq: 40),
      ],
    );

    final commit = writer.completeHistory(
      request: request,
      history: <MessageReconciliationRecord<String>>[
        _record('server-a', msgID: 'server-a', seq: 40),
      ],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(commit!.records, hasLength(2));
    expect(commit.seqIdentityConflicts, hasLength(1));
    expect(commit.seqIdentityConflicts.single.msgIDs,
        <String>{'server-a', 'server-b'});
  });

  test('failed history releases queued realtime in one commit', () {
    final writer = _writer();
    final request = writer.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.unknown,
    );
    writer.enqueueRealtime(
      conversationID: 'group_room',
      eventID: 'callback-50',
      records: <MessageReconciliationRecord<String>>[
        _record('realtime-50', msgID: 'm50', seq: 50),
      ],
    );

    final commit = writer.failHistory(
      request: request,
      reason: 'network unavailable',
      networkState: MessageReconciliationNetworkState.offline,
    );

    expect(commit!.records.single.value, 'realtime-50');
    expect(commit.revision, 1);
    expect(
      writer.coordinator.stateFor('group_room').phase,
      MessageReconciliationPhase.failed,
    );
  });

  test('duplicate realtime event id is idempotent without active history', () {
    final writer = _writer();

    final first = writer.enqueueRealtime(
      conversationID: 'c2c_peer',
      eventID: 'callback-1',
      records: <MessageReconciliationRecord<String>>[
        _record('first', msgID: 'm1', seq: 1),
      ],
    );
    final duplicate = writer.enqueueRealtime(
      conversationID: 'c2c_peer',
      eventID: 'callback-1',
      records: <MessageReconciliationRecord<String>>[
        _record('duplicate', msgID: 'm2', seq: 2),
      ],
    );

    expect(first!.revision, 1);
    expect(duplicate, isNull);
    expect(writer.recordsFor('c2c_peer').single.value, 'first');
  });

  test('C2C per-sender Seq never creates group continuity gaps', () {
    final writer = _writer();
    writer.seedAuthoritative(
      conversationID: 'c2c_peer',
      records: <MessageReconciliationRecord<String>>[
        _record('sender-a', msgID: 'a', seq: 2),
        _record('sender-b', msgID: 'b', seq: 90),
      ],
    );
    final request = writer.beginCloudCatchUp(
      conversationID: 'c2c_peer',
      networkState: MessageReconciliationNetworkState.online,
    );

    final commit = writer.completeHistory(
      request: request,
      history: const <MessageReconciliationRecord<String>>[],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
      cloudHasMoreNewer: true,
    );

    expect(commit!.missingSeqRanges, isEmpty);
    expect(
      writer.coordinator.stateFor('c2c_peer').phase,
      MessageReconciliationPhase.cloudContinuationPending,
    );
  });

  test('bare group IDs track Seq gaps only when explicitly typed', () {
    final writer = _writer();
    writer.seedAuthoritative(
      conversationID: 'm23RIKZN5C2',
      trackSeqGaps: true,
      records: <MessageReconciliationRecord<String>>[
        _record('lower', msgID: 'm100', seq: 100),
        _record('upper', msgID: 'm103', seq: 103),
      ],
    );
    final request = writer.beginCloudCatchUp(
      conversationID: 'm23RIKZN5C2',
      networkState: MessageReconciliationNetworkState.online,
    );

    final commit = writer.completeHistory(
      request: request,
      history: const <MessageReconciliationRecord<String>>[],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(commit!.missingSeqRanges, hasLength(1));
    expect(commit.missingSeqRanges.single.start, 101);
    expect(commit.missingSeqRanges.single.end, 102);
  });

  test('group gap fill shrinks exact Seq ranges without guessing', () {
    final writer = _writer();
    writer.seedAuthoritative(
      conversationID: 'group_room',
      trackSeqGaps: true,
      records: <MessageReconciliationRecord<String>>[
        _record('lower', msgID: 'm100', seq: 100),
        _record('upper', msgID: 'm104', seq: 104),
      ],
    );

    final partialRequest = writer.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );
    final partial = writer.completeHistory(
      request: partialRequest,
      history: <MessageReconciliationRecord<String>>[
        _record('middle', msgID: 'm102', seq: 102),
      ],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
      batchKind: MessageHistoryBatchKind.gapFill,
    );

    expect(
      partial!.missingSeqRanges,
      const <MessageSeqRange>[
        MessageSeqRange(101, 101),
        MessageSeqRange(103, 103),
      ],
    );

    final completeRequest = writer.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );
    final complete = writer.completeHistory(
      request: completeRequest,
      history: <MessageReconciliationRecord<String>>[
        _record('missing-101', msgID: 'm101', seq: 101),
        _record('missing-103', msgID: 'm103', seq: 103),
      ],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
      batchKind: MessageHistoryBatchKind.gapFill,
    );

    expect(complete!.missingSeqRanges, isEmpty);
  });

  test('delete tombstone prevents an older history page resurrecting a row',
      () {
    final writer = _writer();
    writer.seedAuthoritative(
      conversationID: 'c2c_peer',
      records: <MessageReconciliationRecord<String>>[
        _record('visible', msgID: 'm-delete', seq: 10),
      ],
    );

    final deleteCommit = writer.applyDelta(
      MessageDelta<String>(
        conversationKey: 'c2c_peer',
        eventID: 'delete:m-delete',
        kind: MessageDeltaKind.delete,
        source: MessageDeltaSource.userAction,
        generation: 0,
        clearEpoch: 0,
        explicitDeletes: const <String>{'m-delete'},
      ),
    );
    expect(deleteCommit, isNotNull);
    expect(deleteCommit!.records, isEmpty);
    expect(writer.tombstonesFor('c2c_peer'), contains('m-delete'));

    final request = writer.beginCloudCatchUp(
      conversationID: 'c2c_peer',
      networkState: MessageReconciliationNetworkState.online,
    );
    final historyCommit = writer.completeHistory(
      request: request,
      history: <MessageReconciliationRecord<String>>[
        _record('stale-history', msgID: 'm-delete', seq: 10),
      ],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(historyCommit, isNotNull);
    expect(historyCommit!.records, isEmpty);
  });

  test('revoke overlay wins over stale history payload', () {
    final writer = _writer();
    writer.seedAuthoritative(
      conversationID: 'group_room',
      records: <MessageReconciliationRecord<String>>[
        _record('original', msgID: 'm20', seq: 20),
      ],
    );
    writer.applyDelta(
      MessageDelta<String>(
        conversationKey: 'group_room',
        eventID: 'revoke:m20',
        kind: MessageDeltaKind.revoke,
        source: MessageDeltaSource.sdkRealtime,
        generation: 0,
        clearEpoch: 0,
        upserts: <MessageReconciliationRecord<String>>[
          _record('revoked', msgID: 'm20', seq: 20),
        ],
        tombstones: const <String>{'m20'},
      ),
    );

    final request = writer.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );
    final commit = writer.completeHistory(
      request: request,
      history: <MessageReconciliationRecord<String>>[
        _record('stale-original', msgID: 'm20', seq: 20),
      ],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(commit!.records, hasLength(1));
    expect(commit.records.single.value, 'revoked');
  });

  test('delete arriving during history is published in the same revision', () {
    final writer = _writer();
    writer.seedAuthoritative(
      conversationID: 'group_room',
      records: <MessageReconciliationRecord<String>>[
        _record('existing', msgID: 'm30', seq: 30),
      ],
    );
    final request = writer.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );
    expect(
      writer.applyDelta(
        MessageDelta<String>(
          conversationKey: 'group_room',
          eventID: 'delete:m30:inflight',
          kind: MessageDeltaKind.delete,
          source: MessageDeltaSource.userAction,
          generation: request.generation,
          clearEpoch: 0,
          explicitDeletes: const <String>{'m30'},
        ),
      ),
      isNull,
    );

    final commit = writer.completeHistory(
      request: request,
      history: <MessageReconciliationRecord<String>>[
        _record('stale-existing', msgID: 'm30', seq: 30),
        _record('new', msgID: 'm31', seq: 31),
      ],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(commit!.revision, 1);
    expect(commit.records.map((record) => record.value), <String>['new']);
  });

  test('history envelope explicit deletes are consumed before merge', () {
    final writer = _writer();
    final request = writer.beginCloudCatchUp(
      conversationID: 'c2c_peer',
      networkState: MessageReconciliationNetworkState.online,
    );
    final commit = writer.completeHistory(
      request: request,
      history: <MessageReconciliationRecord<String>>[
        _record('stale', msgID: 'm40', seq: 40),
      ],
      explicitDeletes: const <String>{'m40'},
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(commit!.records, isEmpty);
    expect(writer.tombstonesFor('c2c_peer'), contains('m40'));
  });
}
