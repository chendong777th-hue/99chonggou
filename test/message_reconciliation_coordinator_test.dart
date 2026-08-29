import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_coverage.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_coordinator.dart';

void main() {
  test('cloud provenance requires online socket before and after request', () {
    final proven = MessageReconciliationProvenance.resolve(
      requestedSource: MessageReconciliationSource.cloud,
      beforeRequest: MessageReconciliationNetworkState.online,
      afterResponse: MessageReconciliationNetworkState.online,
    );

    expect(proven.cloudResponseProven, isTrue);
    expect(proven.actualSource, MessageReconciliationSource.cloud);
    expect(proven.networkState, MessageReconciliationNetworkState.online);
  });

  test('unknown cloud response is conservatively treated as local fallback',
      () {
    final provenance = MessageReconciliationProvenance.resolve(
      requestedSource: MessageReconciliationSource.cloud,
      beforeRequest: MessageReconciliationNetworkState.online,
      afterResponse: MessageReconciliationNetworkState.unknown,
    );

    expect(provenance.cloudResponseProven, isFalse);
    expect(provenance.actualSource, MessageReconciliationSource.local);
    expect(provenance.networkState, MessageReconciliationNetworkState.unknown);
  });

  test('offline during cloud request is explicit local-only fallback', () {
    final provenance = MessageReconciliationProvenance.resolve(
      requestedSource: MessageReconciliationSource.cloud,
      beforeRequest: MessageReconciliationNetworkState.online,
      afterResponse: MessageReconciliationNetworkState.offline,
    );

    expect(provenance.cloudResponseProven, isFalse);
    expect(provenance.actualSource, MessageReconciliationSource.local);
    expect(provenance.networkState, MessageReconciliationNetworkState.offline);
  });

  test('explicit local history remains local while online', () {
    final provenance = MessageReconciliationProvenance.resolve(
      requestedSource: MessageReconciliationSource.local,
      beforeRequest: MessageReconciliationNetworkState.online,
      afterResponse: MessageReconciliationNetworkState.online,
    );

    expect(provenance.cloudResponseProven, isFalse);
    expect(provenance.actualSource, MessageReconciliationSource.local);
    expect(provenance.networkState, MessageReconciliationNetworkState.online);
  });

  test('initial and cloud requests expose explicit source and generation', () {
    final coordinator = MessageReconciliationCoordinator();

    final initial = coordinator.beginInitialHistory(
      conversationID: 'group_room',
      requestedSource: MessageReconciliationSource.local,
      networkState: MessageReconciliationNetworkState.online,
    );
    expect(initial.generation, 1);
    expect(
      coordinator.stateFor('group_room').phase,
      MessageReconciliationPhase.initialHistory,
    );

    final cloud = coordinator.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );
    expect(cloud.generation, 2);
    expect(cloud.requestedSource, MessageReconciliationSource.cloud);
    expect(
      coordinator.stateFor('group_room').phase,
      MessageReconciliationPhase.cloudCatchUp,
    );
  });

  test('duplicate realtime events are idempotent', () {
    final coordinator = MessageReconciliationCoordinator();

    final first = coordinator.noteRealtimePending(
      conversationID: 'group_room',
      eventID: 'callback-1',
      msgID: 'msg-1',
      seq: 9,
    );
    final duplicate = coordinator.noteRealtimePending(
      conversationID: 'group_room',
      eventID: 'callback-1',
      msgID: 'msg-duplicate',
      seq: 10,
    );

    expect(first, isTrue);
    expect(duplicate, isFalse);
    final state = coordinator.stateFor('group_room');
    expect(state.lastConfirmedMsgID, 'msg-1');
    expect(state.oldestSeq, 9);
    expect(state.newestSeq, 9);
  });

  test('stale request completion cannot replace a newer generation', () {
    final coordinator = MessageReconciliationCoordinator();
    final stale = coordinator.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );
    final current = coordinator.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(
      coordinator.completeRequest(
        request: stale,
        actualSource: MessageReconciliationSource.cloud,
        networkState: MessageReconciliationNetworkState.online,
        resultCount: 3,
        lastConfirmedMsgID: 'stale',
      ),
      isFalse,
    );
    expect(coordinator.stateFor('group_room').requestGeneration, 2);
    expect(coordinator.stateFor('group_room').lastConfirmedMsgID, isNull);

    expect(
      coordinator.completeRequest(
        request: current,
        actualSource: MessageReconciliationSource.cloud,
        networkState: MessageReconciliationNetworkState.online,
        resultCount: 1,
        lastConfirmedMsgID: 'current',
      ),
      isTrue,
    );
    expect(coordinator.stateFor('group_room').lastConfirmedMsgID, 'current');
  });

  test('empty online cloud response remains a bounded partial result', () {
    final coordinator = MessageReconciliationCoordinator();
    final request = coordinator.beginCloudCatchUp(
      conversationID: 'c2c_peer',
      networkState: MessageReconciliationNetworkState.online,
    );

    coordinator.completeRequest(
      request: request,
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
      resultCount: 0,
    );

    final state = coordinator.stateFor('c2c_peer');
    expect(state.phase, MessageReconciliationPhase.cloudWindowPartial);
    expect(state.isComplete, isFalse);
    expect(state.missingSeqRanges, isEmpty);
  });

  test('only server continuity proof permits complete phase', () {
    final coordinator = MessageReconciliationCoordinator();
    final request = coordinator.beginCloudCatchUp(
      conversationID: 'c2c_continuity',
      networkState: MessageReconciliationNetworkState.online,
    );

    coordinator.completeRequest(
      request: request,
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
      resultCount: 0,
      proofKind: MessageHistoryProofKind.serverContinuity,
    );

    final state = coordinator.stateFor('c2c_continuity');
    expect(state.phase, MessageReconciliationPhase.complete);
    expect(state.isComplete, isTrue);
  });

  test('offline cloud fallback to local remains incomplete', () {
    final coordinator = MessageReconciliationCoordinator();
    final request = coordinator.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.unknown,
    );

    coordinator.completeRequest(
      request: request,
      actualSource: MessageReconciliationSource.local,
      networkState: MessageReconciliationNetworkState.offline,
      resultCount: 5,
      lastConfirmedMsgID: 'local-last',
      oldestSeq: 10,
      newestSeq: 14,
    );

    final state = coordinator.stateFor('group_room');
    expect(state.phase, MessageReconciliationPhase.offlineLocalOnly);
    expect(state.isComplete, isFalse);
    expect(state.needsCloudRetry, isTrue);
    expect(state.source, MessageReconciliationSource.local);
  });

  test('online C2C page with more newer rows remains incomplete', () {
    final coordinator = MessageReconciliationCoordinator();
    final request = coordinator.beginCloudCatchUp(
      conversationID: 'c2c_peer',
      networkState: MessageReconciliationNetworkState.online,
    );

    coordinator.completeRequest(
      request: request,
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
      resultCount: 50,
      lastConfirmedMsgID: 'page-anchor',
      cloudHasMoreNewer: true,
    );

    final state = coordinator.stateFor('c2c_peer');
    expect(
      state.phase,
      MessageReconciliationPhase.cloudContinuationPending,
    );
    expect(state.cloudHasMoreNewer, isTrue);
    expect(state.isComplete, isFalse);
    expect(state.needsCloudRetry, isTrue);
  });

  test('missing Seq ranges keep cloud result in gap-detected state', () {
    final coordinator = MessageReconciliationCoordinator();
    final request = coordinator.beginCloudCatchUp(
      conversationID: 'group_room',
      networkState: MessageReconciliationNetworkState.online,
    );

    coordinator.completeRequest(
      request: request,
      actualSource: MessageReconciliationSource.cloud,
      networkState: MessageReconciliationNetworkState.online,
      resultCount: 4,
      oldestSeq: 20,
      newestSeq: 25,
      missingSeqRanges: const <MessageSeqRange>[
        MessageSeqRange(22, 23),
      ],
    );

    final state = coordinator.stateFor('group_room');
    expect(state.phase, MessageReconciliationPhase.gapDetected);
    expect(state.missingSeqRanges, const <MessageSeqRange>[
      MessageSeqRange(22, 23),
    ]);
    expect(state.needsCloudRetry, isTrue);
  });

  test('diagnostics hash conversation identity and never carry bodies', () {
    final diagnostics = <MessageReconciliationDiagnostic>[];
    final coordinator = MessageReconciliationCoordinator(
      onDiagnostic: diagnostics.add,
    );

    coordinator.beginCloudCatchUp(
      conversationID: 'group_secret-room',
      networkState: MessageReconciliationNetworkState.online,
    );

    expect(diagnostics, hasLength(1));
    expect(diagnostics.single.conversationHash, isNot('group_secret-room'));
    expect(diagnostics.single.conversationHash, hasLength(8));
    expect(
      diagnostics.single.toString(),
      isNot(contains('group_secret-room')),
    );
  });
}
