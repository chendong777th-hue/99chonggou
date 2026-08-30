import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im_ingress_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/writer_lease.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// Event input before the durable coordinator assigns ingress sequences.
///
/// Callers may carry a transient SDK object in [payload] for the current
/// process, but the Inbox stores only metadata plus [recoveryRef]. Formal
/// messages are recovered from the SDK boundary/overlap window after a crash.
class ImIngressDraft<T> {
  const ImIngressDraft({
    required this.eventId,
    required this.eventNamespace,
    required this.kind,
    required this.ownerUserId,
    required this.accountGeneration,
    required this.domainGeneration,
    required this.clearEpoch,
    required this.source,
    required this.authority,
    required this.observedAtMs,
    required this.payloadHash,
    required this.recoveryMode,
    required this.recoveryRef,
    this.scope,
    this.viewInstanceId,
    this.surfaceId,
    this.viewSessionGeneration,
    this.historyRequestGeneration,
    this.sendOperationGeneration,
    this.providerSequence,
    this.sourceRevision,
    this.membershipRevision,
    this.operationId,
    this.proof,
    this.cursor,
    this.payload,
  });

  final String eventId;
  final String eventNamespace;
  final ImEventKind kind;
  final AccountScopedConversationKey? scope;
  final String ownerUserId;
  final int accountGeneration;
  final int domainGeneration;
  final String? viewInstanceId;
  final String? surfaceId;
  final int? viewSessionGeneration;
  final int? historyRequestGeneration;
  final int? sendOperationGeneration;
  final int clearEpoch;
  final int? providerSequence;
  final int? sourceRevision;
  final int? membershipRevision;
  final String? operationId;
  final ImEventSource source;
  final ImEventAuthority authority;
  final ImHistoryProofReference? proof;
  final ImCursorReference? cursor;
  final int observedAtMs;
  final String payloadHash;
  final ImRecoveryMode recoveryMode;
  final String recoveryRef;
  final T? payload;

  EventEnvelope<T> materialize({
    required int accountIngressSequence,
    required int scopeIngressSequence,
  }) {
    return EventEnvelope<T>(
      eventId: eventId,
      eventNamespace: eventNamespace,
      kind: kind,
      scope: scope,
      ownerUserId: ownerUserId,
      accountGeneration: accountGeneration,
      domainGeneration: domainGeneration,
      viewInstanceId: viewInstanceId,
      surfaceId: surfaceId,
      viewSessionGeneration: viewSessionGeneration,
      historyRequestGeneration: historyRequestGeneration,
      sendOperationGeneration: sendOperationGeneration,
      clearEpoch: clearEpoch,
      accountIngressSequence: accountIngressSequence,
      scopeIngressSequence: scopeIngressSequence,
      providerSequence: providerSequence,
      sourceRevision: sourceRevision,
      membershipRevision: membershipRevision,
      operationId: operationId,
      source: source,
      authority: authority,
      proof: proof,
      cursor: cursor,
      observedAtMs: observedAtMs,
      payload: payload,
    );
  }
}

class ImIngressAppendResult<T> {
  const ImIngressAppendResult({
    required this.event,
    required this.record,
    required this.wasDuplicate,
  });

  final EventEnvelope<T> event;
  final ImInboxRecord record;
  final bool wasDuplicate;

  bool get wasPrepared => !wasDuplicate;
}

/// Appends one event atomically with both account and scope ingress numbers.
///
/// The transaction order is intentional: idempotency lookup, both counters,
/// and Inbox insert happen under one SQLite transaction. No in-memory counter
/// is used as a source of truth.
class DurableIngressGateway {
  DurableIngressGateway({required ImIngressStore store}) : _store = store;

  final ImIngressStore _store;

  Future<ImInboxRecord?> claimForWriter({
    required EventEnvelope<dynamic> event,
    required ImWriterLease lease,
    required int nowMs,
    bool allowStaleProcessing = false,
    int processingTimeoutMs = 30000,
  }) {
    return _store.transaction<ImInboxRecord?>((transaction) {
      return transaction.claimInboxForWriter(
        ownerUserId: event.ownerUserId,
        eventNamespace: event.eventNamespace,
        eventId: event.eventId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: nowMs,
        allowStaleProcessing: allowStaleProcessing,
        processingTimeoutMs: processingTimeoutMs,
      );
    });
  }

  Future<List<ImInboxRecord>> listForRecovery({
    required String ownerUserId,
    required int accountGeneration,
    int? domainGeneration,
    required int nowMs,
    int processingTimeoutMs = 30000,
    int limit = 100,
  }) {
    if (limit <= 0) return Future<List<ImInboxRecord>>.value(const []);
    return _store.transaction<List<ImInboxRecord>>((transaction) {
      return transaction.listInboxForRecovery(
        ownerUserId: ownerUserId,
        accountGeneration: accountGeneration,
        domainGeneration: domainGeneration,
        nowMs: nowMs,
        processingTimeoutMs: processingTimeoutMs,
        limit: limit,
      );
    });
  }

  Future<bool> advanceForWriter({
    required EventEnvelope<dynamic> event,
    required ImInboxStatus expectedStatus,
    required ImInboxStatus nextStatus,
    required ImWriterLease lease,
    required int nowMs,
    int? committedAtMs,
  }) {
    return _store.transaction<bool>((transaction) {
      return transaction.advanceInboxStatusIfCurrent(
        ownerUserId: event.ownerUserId,
        eventNamespace: event.eventNamespace,
        eventId: event.eventId,
        expectedStatus: expectedStatus,
        nextStatus: nextStatus,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: nowMs,
        committedAtMs: committedAtMs,
      );
    });
  }

  Future<ImIngressAppendResult<T>> append<T>(ImIngressDraft<T> draft) async {
    final owner = ChatIdFormat.rawUserUid(draft.ownerUserId);
    if (owner.isEmpty) {
      throw ArgumentError.value(
        draft.ownerUserId,
        'ownerUserId',
        'must not be empty',
      );
    }
    final namespace = draft.eventNamespace.trim();
    final eventId = draft.eventId.trim();
    final recoveryRef = draft.recoveryRef.trim();
    final inputHash = draft.payloadHash.trim();
    if (namespace.isEmpty || eventId.isEmpty) {
      throw ArgumentError('eventNamespace and eventId are required');
    }
    if (inputHash.isEmpty || recoveryRef.isEmpty) {
      throw ArgumentError('payloadHash and recoveryRef are required');
    }
    final storedHash = _storedPayloadHash(
      ownerUserId: owner,
      eventNamespace: namespace,
      eventId: eventId,
      kind: draft.kind,
      scopeKey: draft.scope?.canonicalConversationId ?? '',
      accountGeneration: draft.accountGeneration,
      domainGeneration: draft.domainGeneration,
      payloadHash: inputHash,
      recoveryRef: recoveryRef,
      operationId: draft.operationId ?? '',
    );
    final nowMs = draft.observedAtMs;

    return _store.transaction<ImIngressAppendResult<T>>((transaction) async {
      final existing = await transaction.findInbox(
        ownerUserId: owner,
        eventNamespace: namespace,
        eventId: eventId,
      );
      if (existing != null) {
        if (existing.payloadHash != storedHash ||
            existing.recoveryRef != recoveryRef ||
            existing.recoveryMode != draft.recoveryMode) {
          throw ImIngressConflictException(
            ownerUserId: owner,
            eventNamespace: namespace,
            eventId: eventId,
          );
        }
        return ImIngressAppendResult<T>(
          event: draft.materialize(
            accountIngressSequence: existing.event.accountIngressSequence,
            scopeIngressSequence: existing.event.scopeIngressSequence,
          ),
          record: existing,
          wasDuplicate: true,
        );
      }

      final accountSequence = await transaction.allocateAccountIngressSequence(
        ownerUserId: owner,
        nowMs: nowMs,
      );
      final scopeSequence = draft.scope == null
          ? 0
          : await transaction.allocateScopeIngressSequence(
              ownerUserId: owner,
              scopeKey: draft.scope!.canonicalConversationId,
              nowMs: nowMs,
            );
      final event = draft.materialize(
        accountIngressSequence: accountSequence,
        scopeIngressSequence: scopeSequence,
      );
      final metadataEvent = _withoutPayload(event);
      final record = ImInboxRecord(
        event: metadataEvent,
        payloadHash: storedHash,
        recoveryMode: draft.recoveryMode,
        recoveryRef: recoveryRef,
        status: ImInboxStatus.prepared,
      );
      await transaction.insertInbox(record);
      return ImIngressAppendResult<T>(
        event: event,
        record: record,
        wasDuplicate: false,
      );
    });
  }
}

class ImIngressConflictException implements Exception {
  const ImIngressConflictException({
    required this.ownerUserId,
    required this.eventNamespace,
    required this.eventId,
  });

  final String ownerUserId;
  final String eventNamespace;
  final String eventId;

  @override
  String toString() =>
      'IM Inbox identity conflict for $ownerUserId|$eventNamespace|$eventId';
}

EventEnvelope<void> _withoutPayload<T>(EventEnvelope<T> event) {
  return EventEnvelope<void>(
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
  );
}

String _storedPayloadHash({
  required String ownerUserId,
  required String eventNamespace,
  required String eventId,
  required ImEventKind kind,
  required String scopeKey,
  required int accountGeneration,
  required int domainGeneration,
  required String payloadHash,
  required String recoveryRef,
  required String operationId,
}) {
  final canonical = jsonEncode(<String, String>{
    'ownerUserId': ownerUserId,
    'eventNamespace': eventNamespace,
    'eventId': eventId,
    'kind': kind.name,
    'scopeKey': scopeKey,
    'accountGeneration': '$accountGeneration',
    'domainGeneration': '$domainGeneration',
    'payloadHash': payloadHash,
    'recoveryRef': recoveryRef,
    'operationId': operationId,
  });
  return sha256.convert(utf8.encode(canonical)).toString();
}
