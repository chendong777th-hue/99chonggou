import 'dart:async';

import 'package:tencent_cloud_chat_demo/src/services/im/contracts/contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/durable_ingress_gateway.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im_ingress_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im_mailbox.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/writer_lease.dart';

class ImRecoveryPayload {
  const ImRecoveryPayload._({required this.canRecover, this.payload});

  const ImRecoveryPayload.recovered(Object? payload)
      : this._(canRecover: true, payload: payload);

  const ImRecoveryPayload.unavailable() : this._(canRecover: false);

  final bool canRecover;
  final Object? payload;
}

/// Marker used when an ephemeral UI event has no durable payload to recover.
/// It is intentionally distinct from null so command payload loss cannot be
/// mistaken for a successfully recovered event.
class ImRecoveredEphemeralUiEvent {
  const ImRecoveredEphemeralUiEvent();
}

typedef ImRecoveryPayloadLoader = Future<ImRecoveryPayload> Function(
  ImInboxRecord record,
);

class ImRecoveryRunResult {
  const ImRecoveryRunResult({
    required this.scanned,
    required this.dispatched,
    required this.deferred,
  });

  final int scanned;
  final int dispatched;
  final int deferred;
}

/// Replays durable ingress rows after the unique MessageCore owner is ready.
///
/// The worker never invents a message body. For formal SDK messages the
/// payload loader must read the SDK local store or a bounded overlap window.
/// Only ephemeral UI rows may be dispatched without a payload. Other rows must
/// still provide a recoverable command or formal SDK message, even when their
/// metadata/projection transition was already committed.
class ImRecoveryWorker {
  ImRecoveryWorker({
    required this.gateway,
    required this.router,
    required this.lease,
    required this.ownerUserId,
    required this.accountGeneration,
    required this.domainGeneration,
    required this.loadPayload,
    this.processingTimeoutMs = 30000,
  });

  final DurableIngressGateway gateway;
  final ImMailboxRouter router;
  final ImWriterLease lease;
  final String ownerUserId;
  final int accountGeneration;
  final int domainGeneration;
  final ImRecoveryPayloadLoader loadPayload;
  final int processingTimeoutMs;

  Future<ImRecoveryRunResult> run({
    int nowMs = 0,
    int limit = 100,
  }) async {
    final effectiveNow =
        nowMs > 0 ? nowMs : DateTime.now().millisecondsSinceEpoch;
    final records = await gateway.listForRecovery(
      ownerUserId: ownerUserId,
      accountGeneration: accountGeneration,
      domainGeneration: domainGeneration,
      nowMs: effectiveNow,
      processingTimeoutMs: processingTimeoutMs,
      limit: limit,
    );
    var dispatched = 0;
    var deferred = 0;
    for (final record in records) {
      ImRecoveryPayload recovery;
      if (record.status == ImInboxStatus.projectionPublished) {
        recovery = const ImRecoveryPayload.recovered(null);
      } else if (record.recoveryMode == ImRecoveryMode.ephemeralUi) {
        recovery = const ImRecoveryPayload.recovered(
          ImRecoveredEphemeralUiEvent(),
        );
      } else {
        try {
          recovery = await loadPayload(record);
        } catch (_) {
          recovery = const ImRecoveryPayload.unavailable();
        }
      }
      if (!recovery.canRecover) {
        deferred++;
        continue;
      }
      final event = _withPayload(record.event, recovery.payload);
      try {
        await router.dispatch(event, lane: _laneFor(event));
        dispatched++;
      } catch (_) {
        deferred++;
      }
    }
    return ImRecoveryRunResult(
      scanned: records.length,
      dispatched: dispatched,
      deferred: deferred,
    );
  }
}

EventEnvelope<dynamic> _withPayload(
  EventEnvelope<void> event,
  Object? payload,
) {
  return EventEnvelope<dynamic>(
    eventId: event.eventId,
    eventNamespace: event.eventNamespace,
    kind: event.kind,
    scope: event.scope,
    ownerUserId: event.ownerUserId,
    accountGeneration: event.accountGeneration,
    domainGeneration: event.domainGeneration,
    viewInstanceId: event.viewInstanceId,
    surfaceId: event.surfaceId,
    viewSessionGeneration: event.viewSessionGeneration,
    historyRequestGeneration: event.historyRequestGeneration,
    sendOperationGeneration: event.sendOperationGeneration,
    clearEpoch: event.clearEpoch,
    accountIngressSequence: event.accountIngressSequence,
    scopeIngressSequence: event.scopeIngressSequence,
    providerSequence: event.providerSequence,
    sourceRevision: event.sourceRevision,
    membershipRevision: event.membershipRevision,
    operationId: event.operationId,
    source: event.source,
    authority: event.authority,
    proof: event.proof,
    cursor: event.cursor,
    observedAtMs: event.observedAtMs,
    payload: payload,
  );
}

ImIngressLane _laneFor(EventEnvelope<dynamic> event) {
  if (event.kind == ImEventKind.messageMutation) {
    return ImIngressLane.urgent;
  }
  if (event.kind == ImEventKind.historyPage) {
    return ImIngressLane.history;
  }
  return ImIngressLane.realtime;
}
