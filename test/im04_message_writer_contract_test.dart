import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_delta.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_coverage.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_identity.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_writer.dart';

MessageReconciliationRecord<String> _record(
  String value, {
  required String msgID,
  int? seq,
}) {
  return MessageReconciliationRecord<String>(
    value: value,
    msgID: msgID,
    seq: seq?.toString(),
  );
}

MessageReconciliationWriter<String> _writer() {
  return MessageReconciliationWriter<String>(
    comparator: (left, right) =>
        (left.numericSeq ?? 0).compareTo(right.numericSeq ?? 0),
    scope: const MessageReconciliationWriterScope(
      ownerUserID: 'account-a',
      accountGeneration: 7,
      domainGeneration: 3,
    ),
  );
}

MessageDelta<String> _delta(
  String eventID, {
  required int generation,
  required int clearEpoch,
  String ownerUserID = 'account-a',
  int accountGeneration = 7,
  int domainGeneration = 3,
  MessageDeltaKind kind = MessageDeltaKind.realtimeUpsert,
  Iterable<MessageReconciliationRecord<String>> upserts = const [],
  Iterable<String> tombstones = const [],
}) {
  return MessageDelta<String>(
    conversationKey: 'group-room',
    eventID: eventID,
    kind: kind,
    source: kind == MessageDeltaKind.revoke
        ? MessageDeltaSource.sdkRealtime
        : MessageDeltaSource.userAction,
    generation: generation,
    clearEpoch: clearEpoch,
    ownerUserID: ownerUserID,
    accountGeneration: accountGeneration,
    domainGeneration: domainGeneration,
    upserts: upserts,
    tombstones: tombstones,
  );
}

void main() {
  test('one formal msgID remains one visible row across history and realtime',
      () {
    final writer = _writer();
    writer.seedAuthoritative(
      conversationID: 'group-room',
      clearEpoch: 4,
      trackSeqGaps: true,
      records: <MessageReconciliationRecord<String>>[
        _record('old', msgID: 'm-1', seq: 10),
      ],
    );
    final request = writer.beginInitialHistory(
      conversationID: 'group-room',
      requestedSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
      clearEpoch: 4,
    );

    expect(
      writer.enqueueRealtime(
        conversationID: 'group-room',
        eventID: 'realtime:m-1',
        records: <MessageReconciliationRecord<String>>[
          _record('realtime', msgID: 'm-1', seq: 10),
        ],
      ),
      isNull,
    );

    final commit = writer.completeHistory(
      request: request,
      history: <MessageReconciliationRecord<String>>[
        _record('history', msgID: 'm-1', seq: 10),
      ],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
      proofKind: MessageHistoryProofKind.serverContinuity,
    );

    expect(commit, isNotNull);
    expect(commit!.revision, 1);
    expect(commit.clearEpoch, 4);
    expect(commit.ownerUserID, 'account-a');
    expect(commit.accountGeneration, 7);
    expect(commit.domainGeneration, 3);
    expect(commit.records.map((record) => record.value), ['realtime']);
    expect(commit.records.map((record) => record.serverIdentity), ['m-1']);
  });

  test(
      'old account scope, generation, and clear epoch cannot overwrite newer state',
      () {
    final writer = _writer();
    final first = writer.beginCloudCatchUp(
      conversationID: 'group-room',
      networkState: MessageReconciliationNetworkState.online,
      clearEpoch: 1,
    );
    final second = writer.beginCloudCatchUp(
      conversationID: 'group-room',
      networkState: MessageReconciliationNetworkState.online,
      clearEpoch: 2,
    );

    expect(
      writer.completeHistory(
        request: first,
        history: <MessageReconciliationRecord<String>>[
          _record('old-history', msgID: 'old', seq: 1),
        ],
        actualSource: MessageReconciliationSource.cloud,
        networkState: MessageReconciliationNetworkState.online,
      ),
      isNull,
    );
    expect(
      writer.applyDelta(
        _delta(
          'old-realtime',
          generation: first.generation,
          clearEpoch: first.clearEpoch,
          upserts: <MessageReconciliationRecord<String>>[
            _record('old-realtime', msgID: 'old-realtime', seq: 2),
          ],
        ),
      ),
      isNull,
    );
    expect(
      writer.applyDelta(
        _delta(
          'wrong-account',
          generation: second.generation,
          clearEpoch: second.clearEpoch,
          ownerUserID: 'account-b',
          upserts: <MessageReconciliationRecord<String>>[
            _record('wrong-account', msgID: 'm-wrong', seq: 3),
          ],
        ),
      ),
      isNull,
    );

    expect(
      writer.enqueueRealtime(
        conversationID: 'group-room',
        eventID: 'current-realtime',
        records: <MessageReconciliationRecord<String>>[
          _record('current', msgID: 'm-current', seq: 4),
        ],
      ),
      isNull,
    );
    final commit = writer.completeHistory(
      request: second,
      history: const <MessageReconciliationRecord<String>>[],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );
    expect(commit!.clearEpoch, 2);
    expect(commit.records.map((record) => record.value), ['current']);
  });

  test(
      'realtime received during history is released in one deduplicated commit',
      () {
    final writer = _writer();
    final request = writer.beginInitialHistory(
      conversationID: 'group-room',
      requestedSource: MessageReconciliationSource.local,
      networkState: MessageReconciliationNetworkState.online,
    );
    writer.enqueueRealtime(
      conversationID: 'group-room',
      eventID: 'realtime:released',
      records: <MessageReconciliationRecord<String>>[
        _record('released', msgID: 'm-released', seq: 20),
      ],
    );

    final commit = writer.completeHistory(
      request: request,
      history: <MessageReconciliationRecord<String>>[
        _record('history', msgID: 'm-history', seq: 19),
        _record('history-duplicate', msgID: 'm-released', seq: 20),
      ],
      actualSource: MessageReconciliationSource.local,
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(commit!.revision, 1);
    expect(writer.pendingDeltaCount('group-room'), 0);
    expect(commit.records.map((record) => record.serverIdentity),
        ['m-history', 'm-released']);
  });

  test('revoke tombstone wins over stale history and remains observable', () {
    final writer = _writer();
    writer.seedAuthoritative(
      conversationID: 'group-room',
      records: <MessageReconciliationRecord<String>>[
        _record('original', msgID: 'm-revoked', seq: 30),
      ],
    );
    final request = writer.beginCloudCatchUp(
      conversationID: 'group-room',
      networkState: MessageReconciliationNetworkState.online,
    );
    expect(
      writer.applyDelta(
        _delta(
          'revoke:m-revoked',
          generation: request.generation,
          clearEpoch: request.clearEpoch,
          kind: MessageDeltaKind.revoke,
          upserts: <MessageReconciliationRecord<String>>[
            _record('revoked', msgID: 'm-revoked', seq: 30),
          ],
          tombstones: const <String>{'m-revoked'},
        ),
      ),
      isNull,
    );

    final commit = writer.completeHistory(
      request: request,
      history: <MessageReconciliationRecord<String>>[
        _record('stale-original', msgID: 'm-revoked', seq: 30),
      ],
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(commit!.records.single.value, 'revoked');
    expect(writer.tombstonesFor('group-room'), contains('m-revoked'));
  });
}
