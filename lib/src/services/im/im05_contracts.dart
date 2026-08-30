// Durable state contracts for the first IM-05 infrastructure slice.
//
// The records in this file are deliberately storage-shaped. They can be
// encoded by SQLite, IndexedDB, or the deterministic in-memory test store,
// while the protocol decisions remain in [Im05Persistence].

import 'package:tencent_cloud_chat_demo/src/services/im/im_ingress_store.dart';

enum ImCommitJournalState {
  prepared,
  metadataCommitted,
  projectionPublished,
  completed,
}

enum ImEffectLedgerState {
  pending,
  running,
  completed,
  failed,
}

enum ImOutboxState {
  created,
  preparing,
  prepared,
  dispatchIntent,
  sending,
  outcomeUnknown,
  retryable,
  acknowledged,
  completed,
  failedTerminal,
  pausedByLogout,
  abandonedByUser,
}

enum ImOutboxCopyState {
  copyPrepared,
  dispatchIntent,
  resultRecorded,
  outcomeUnknown,
  reconciled,
  gcEligible,
}

enum ImOutboxDispatchDecision {
  ready,
  mainMissing,
  mainNotPrepared,
  recoveryCopyMissing,
  recoveryCopyNotPrepared,
  identityConflict,
  recoveryConflict,
  recoveryLag,
  outcomeUnknown,
  fencingRejected,
}

class ImCommitJournalRecord {
  const ImCommitJournalRecord({
    required this.ownerUserId,
    required this.journalId,
    required this.eventNamespace,
    required this.eventId,
    required this.scope,
    required this.commitRevision,
    required this.state,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.metadataRevision,
    this.projectionRevision,
    this.sideEffectRevision,
    this.leaseOwnerId = '',
    this.fencingToken = 0,
  });

  final String ownerUserId;
  final String journalId;
  final String eventNamespace;
  final String eventId;
  final String scope;
  final int commitRevision;
  final ImCommitJournalState state;
  final int? metadataRevision;
  final int? projectionRevision;
  final int? sideEffectRevision;
  final int createdAtMs;
  final int updatedAtMs;
  final String leaseOwnerId;
  final int fencingToken;

  ImCommitJournalRecord copyWith({
    ImCommitJournalState? state,
    int? metadataRevision,
    int? projectionRevision,
    int? sideEffectRevision,
    int? updatedAtMs,
    String? leaseOwnerId,
    int? fencingToken,
  }) {
    return ImCommitJournalRecord(
      ownerUserId: ownerUserId,
      journalId: journalId,
      eventNamespace: eventNamespace,
      eventId: eventId,
      scope: scope,
      commitRevision: commitRevision,
      state: state ?? this.state,
      metadataRevision: metadataRevision ?? this.metadataRevision,
      projectionRevision: projectionRevision ?? this.projectionRevision,
      sideEffectRevision: sideEffectRevision ?? this.sideEffectRevision,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      leaseOwnerId: leaseOwnerId ?? this.leaseOwnerId,
      fencingToken: fencingToken ?? this.fencingToken,
    );
  }
}

class ImProjectionCheckpointRecord {
  const ImProjectionCheckpointRecord({
    required this.ownerUserId,
    required this.scope,
    required this.commitRevision,
    required this.lastJournalId,
    required this.coverageRevision,
    required this.watermarkRevision,
    required this.barrierRevision,
    required this.projectionVersion,
    required this.updatedAtMs,
    this.leaseOwnerId = '',
    this.fencingToken = 0,
  });

  final String ownerUserId;
  final String scope;
  final int commitRevision;
  final String lastJournalId;
  final int coverageRevision;
  final int watermarkRevision;
  final int barrierRevision;
  final int projectionVersion;
  final int updatedAtMs;
  final String leaseOwnerId;
  final int fencingToken;
}

class ImEffectLedgerRecord {
  const ImEffectLedgerRecord({
    required this.ownerUserId,
    required this.effectId,
    required this.journalId,
    required this.effectKind,
    required this.state,
    required this.attemptCount,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.lastError,
    this.leaseOwnerId = '',
    this.fencingToken = 0,
  });

  final String ownerUserId;
  final String effectId;
  final String journalId;
  final String effectKind;
  final ImEffectLedgerState state;
  final int attemptCount;
  final String? lastError;
  final int createdAtMs;
  final int updatedAtMs;
  final String leaseOwnerId;
  final int fencingToken;
}

class ImOutboxRecord {
  const ImOutboxRecord({
    required this.operationId,
    required this.ownerUserId,
    required this.conversationId,
    required this.clientCorrelationId,
    required this.messageType,
    required this.payloadReference,
    required this.state,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.mediaLocalRef,
    this.encryptionVersion,
    this.keyId,
    this.cipherAlgorithm,
    this.nonce,
    this.contentChecksum,
    this.payloadHash = '',
    this.sdkMessageId,
    this.serverMsgId,
    this.dispatchAttemptId,
    this.dispatchIntentAtMs,
    this.resultCode,
    this.retryCount = 0,
    this.nextRetryAtMs,
    this.leaseOwnerId = '',
    this.fencingToken = 0,
    this.recoveryLag = false,
    this.recoveryConflict = false,
  });

  final String operationId;
  final String ownerUserId;
  final String conversationId;
  final String clientCorrelationId;
  final int messageType;
  final String payloadReference;
  final String? mediaLocalRef;
  final int? encryptionVersion;
  final String? keyId;
  final String? cipherAlgorithm;
  final String? nonce;
  final String? contentChecksum;
  final String payloadHash;
  final ImOutboxState state;
  final String? sdkMessageId;
  final String? serverMsgId;
  final String? dispatchAttemptId;
  final int? dispatchIntentAtMs;
  final String? resultCode;
  final int retryCount;
  final int? nextRetryAtMs;
  final int createdAtMs;
  final int updatedAtMs;
  final String leaseOwnerId;
  final int fencingToken;
  final bool recoveryLag;
  final bool recoveryConflict;

  ImOutboxRecord copyWith({
    ImOutboxState? state,
    String? sdkMessageId,
    String? serverMsgId,
    String? dispatchAttemptId,
    int? dispatchIntentAtMs,
    String? resultCode,
    int? retryCount,
    int? nextRetryAtMs,
    int? updatedAtMs,
    String? leaseOwnerId,
    int? fencingToken,
    bool? recoveryLag,
    bool? recoveryConflict,
  }) {
    return ImOutboxRecord(
      operationId: operationId,
      ownerUserId: ownerUserId,
      conversationId: conversationId,
      clientCorrelationId: clientCorrelationId,
      messageType: messageType,
      payloadReference: payloadReference,
      state: state ?? this.state,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      mediaLocalRef: mediaLocalRef,
      encryptionVersion: encryptionVersion,
      keyId: keyId,
      cipherAlgorithm: cipherAlgorithm,
      nonce: nonce,
      contentChecksum: contentChecksum,
      payloadHash: payloadHash,
      sdkMessageId: sdkMessageId ?? this.sdkMessageId,
      serverMsgId: serverMsgId ?? this.serverMsgId,
      dispatchAttemptId: dispatchAttemptId ?? this.dispatchAttemptId,
      dispatchIntentAtMs: dispatchIntentAtMs ?? this.dispatchIntentAtMs,
      resultCode: resultCode ?? this.resultCode,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAtMs: nextRetryAtMs ?? this.nextRetryAtMs,
      leaseOwnerId: leaseOwnerId ?? this.leaseOwnerId,
      fencingToken: fencingToken ?? this.fencingToken,
      recoveryLag: recoveryLag ?? this.recoveryLag,
      recoveryConflict: recoveryConflict ?? this.recoveryConflict,
    );
  }
}

class ImOutboxRecoveryRecord {
  const ImOutboxRecoveryRecord({
    required this.ownerUserId,
    required this.operationId,
    required this.clientCorrelationId,
    required this.conversationId,
    required this.messageType,
    required this.recoveryRevision,
    required this.state,
    required this.payloadReferenceOrCiphertext,
    required this.payloadHash,
    required this.checksum,
    required this.updatedAtMs,
    this.dispatchAttemptId,
    this.dispatchIntentAtMs,
    this.sdkLocalId,
    this.serverMsgId,
    this.resultCode,
  });

  final String ownerUserId;
  final String operationId;
  final String clientCorrelationId;
  final String conversationId;
  final int messageType;
  final int recoveryRevision;
  final ImOutboxCopyState state;
  final int? dispatchIntentAtMs;
  final String? dispatchAttemptId;
  final String payloadReferenceOrCiphertext;
  final String payloadHash;
  final String checksum;
  final String? sdkLocalId;
  final String? serverMsgId;
  final String? resultCode;
  final int updatedAtMs;
}

abstract interface class Im05Transaction {
  Future<ImWriterLeaseRecord?> findWriterLease(String ownerUserId);

  Future<ImCommitJournalRecord?> findCommitJournal({
    required String ownerUserId,
    required String journalId,
  });

  Future<bool> insertCommitJournalIfAbsent(ImCommitJournalRecord record);

  Future<bool> updateCommitJournalIfCurrent({
    required ImCommitJournalRecord record,
    required ImCommitJournalState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  });

  Future<ImProjectionCheckpointRecord?> findProjectionCheckpoint({
    required String ownerUserId,
    required String scope,
  });

  Future<bool> saveProjectionCheckpointIfCurrent({
    required ImProjectionCheckpointRecord record,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  });

  Future<ImEffectLedgerRecord?> findEffect({
    required String ownerUserId,
    required String effectId,
  });

  Future<bool> insertEffectIfAbsent(ImEffectLedgerRecord record);

  Future<bool> updateEffectIfCurrent({
    required ImEffectLedgerRecord record,
    required ImEffectLedgerState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  });

  Future<ImOutboxRecord?> findOutbox({
    required String ownerUserId,
    required String operationId,
  });

  Future<bool> insertOutboxIfAbsent(ImOutboxRecord record);

  Future<bool> updateOutboxIfCurrent({
    required ImOutboxRecord record,
    required ImOutboxState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  });

  Future<ImOutboxRecoveryRecord?> findOutboxRecovery({
    required String ownerUserId,
    required String operationId,
  });

  Future<bool> insertOutboxRecoveryIfAbsent(ImOutboxRecoveryRecord record);

  Future<bool> updateOutboxRecoveryIfCurrent({
    required ImOutboxRecoveryRecord record,
    required ImOutboxCopyState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  });
}

bool isValidImCommitJournalTransition(
  ImCommitJournalState expected,
  ImCommitJournalState next,
) {
  return (expected == ImCommitJournalState.prepared &&
          next == ImCommitJournalState.metadataCommitted) ||
      (expected == ImCommitJournalState.metadataCommitted &&
          next == ImCommitJournalState.projectionPublished) ||
      (expected == ImCommitJournalState.projectionPublished &&
          next == ImCommitJournalState.completed);
}

bool isValidImOutboxRecoveryTransition(
  ImOutboxCopyState expected,
  ImOutboxCopyState next,
) {
  return (expected == ImOutboxCopyState.copyPrepared &&
          next == ImOutboxCopyState.dispatchIntent) ||
      (expected == ImOutboxCopyState.dispatchIntent &&
          (next == ImOutboxCopyState.resultRecorded ||
              next == ImOutboxCopyState.outcomeUnknown)) ||
      (expected == ImOutboxCopyState.resultRecorded &&
          next == ImOutboxCopyState.reconciled) ||
      (expected == ImOutboxCopyState.outcomeUnknown &&
          next == ImOutboxCopyState.reconciled) ||
      (expected == ImOutboxCopyState.reconciled &&
          next == ImOutboxCopyState.gcEligible);
}

bool isValidImEffectTransition(
  ImEffectLedgerState expected,
  ImEffectLedgerState next,
) {
  return (expected == ImEffectLedgerState.pending &&
          next == ImEffectLedgerState.running) ||
      (expected == ImEffectLedgerState.running &&
          (next == ImEffectLedgerState.completed ||
              next == ImEffectLedgerState.failed));
}

bool isValidImOutboxTransition(ImOutboxState expected, ImOutboxState next) {
  switch (expected) {
    case ImOutboxState.created:
      return next == ImOutboxState.preparing;
    case ImOutboxState.preparing:
      return next == ImOutboxState.prepared;
    case ImOutboxState.prepared:
      return next == ImOutboxState.dispatchIntent ||
          next == ImOutboxState.pausedByLogout;
    case ImOutboxState.dispatchIntent:
      return next == ImOutboxState.sending ||
          next == ImOutboxState.outcomeUnknown;
    case ImOutboxState.sending:
      return next == ImOutboxState.acknowledged ||
          next == ImOutboxState.failedTerminal ||
          next == ImOutboxState.retryable ||
          next == ImOutboxState.outcomeUnknown;
    case ImOutboxState.outcomeUnknown:
      return next == ImOutboxState.acknowledged ||
          next == ImOutboxState.failedTerminal ||
          next == ImOutboxState.retryable;
    case ImOutboxState.retryable:
      return next == ImOutboxState.prepared;
    case ImOutboxState.acknowledged:
      return next == ImOutboxState.completed;
    case ImOutboxState.pausedByLogout:
      return next == ImOutboxState.prepared ||
          next == ImOutboxState.abandonedByUser;
    case ImOutboxState.completed:
    case ImOutboxState.failedTerminal:
    case ImOutboxState.abandonedByUser:
      return false;
  }
}

Map<String, Object?> imCommitJournalToStorageMap(
        ImCommitJournalRecord record) =>
    <String, Object?>{
      'owner_user_id': record.ownerUserId,
      'journal_id': record.journalId,
      'event_namespace': record.eventNamespace,
      'event_id': record.eventId,
      'scope': record.scope,
      'commit_revision': record.commitRevision,
      'state': record.state.name,
      'metadata_revision': record.metadataRevision,
      'projection_revision': record.projectionRevision,
      'side_effect_revision': record.sideEffectRevision,
      'created_at': record.createdAtMs,
      'updated_at': record.updatedAtMs,
      'lease_owner_id': record.leaseOwnerId,
      'fencing_token': record.fencingToken,
    };

ImCommitJournalRecord imCommitJournalFromStorageMap(Map<String, Object?> row) =>
    ImCommitJournalRecord(
      ownerUserId: _string(row['owner_user_id']),
      journalId: _string(row['journal_id']),
      eventNamespace: _string(row['event_namespace']),
      eventId: _string(row['event_id']),
      scope: _string(row['scope']),
      commitRevision: _int(row['commit_revision']),
      state: _enumByName(
        ImCommitJournalState.values,
        row['state']?.toString(),
        ImCommitJournalState.prepared,
      ),
      metadataRevision: _optionalInt(row['metadata_revision']),
      projectionRevision: _optionalInt(row['projection_revision']),
      sideEffectRevision: _optionalInt(row['side_effect_revision']),
      createdAtMs: _int(row['created_at']),
      updatedAtMs: _int(row['updated_at']),
      leaseOwnerId: _string(row['lease_owner_id']),
      fencingToken: _int(row['fencing_token']),
    );

Map<String, Object?> imProjectionCheckpointToStorageMap(
  ImProjectionCheckpointRecord record,
) =>
    <String, Object?>{
      'owner_user_id': record.ownerUserId,
      'scope': record.scope,
      'commit_revision': record.commitRevision,
      'last_journal_id': record.lastJournalId,
      'coverage_revision': record.coverageRevision,
      'watermark_revision': record.watermarkRevision,
      'barrier_revision': record.barrierRevision,
      'projection_version': record.projectionVersion,
      'updated_at': record.updatedAtMs,
      'lease_owner_id': record.leaseOwnerId,
      'fencing_token': record.fencingToken,
    };

ImProjectionCheckpointRecord imProjectionCheckpointFromStorageMap(
  Map<String, Object?> row,
) =>
    ImProjectionCheckpointRecord(
      ownerUserId: _string(row['owner_user_id']),
      scope: _string(row['scope']),
      commitRevision: _int(row['commit_revision']),
      lastJournalId: _string(row['last_journal_id']),
      coverageRevision: _int(row['coverage_revision']),
      watermarkRevision: _int(row['watermark_revision']),
      barrierRevision: _int(row['barrier_revision']),
      projectionVersion: _int(row['projection_version']),
      updatedAtMs: _int(row['updated_at']),
      leaseOwnerId: _string(row['lease_owner_id']),
      fencingToken: _int(row['fencing_token']),
    );

Map<String, Object?> imEffectLedgerToStorageMap(ImEffectLedgerRecord record) =>
    <String, Object?>{
      'owner_user_id': record.ownerUserId,
      'effect_id': record.effectId,
      'journal_id': record.journalId,
      'effect_kind': record.effectKind,
      'state': record.state.name,
      'attempt_count': record.attemptCount,
      'last_error': record.lastError,
      'created_at': record.createdAtMs,
      'updated_at': record.updatedAtMs,
      'lease_owner_id': record.leaseOwnerId,
      'fencing_token': record.fencingToken,
    };

ImEffectLedgerRecord imEffectLedgerFromStorageMap(Map<String, Object?> row) =>
    ImEffectLedgerRecord(
      ownerUserId: _string(row['owner_user_id']),
      effectId: _string(row['effect_id']),
      journalId: _string(row['journal_id']),
      effectKind: _string(row['effect_kind']),
      state: _enumByName(
        ImEffectLedgerState.values,
        row['state']?.toString(),
        ImEffectLedgerState.pending,
      ),
      attemptCount: _int(row['attempt_count']),
      lastError: _optionalString(row['last_error']),
      createdAtMs: _int(row['created_at']),
      updatedAtMs: _int(row['updated_at']),
      leaseOwnerId: _string(row['lease_owner_id']),
      fencingToken: _int(row['fencing_token']),
    );

Map<String, Object?> imOutboxToStorageMap(ImOutboxRecord record) =>
    <String, Object?>{
      'operation_id': record.operationId,
      'owner_user_id': record.ownerUserId,
      'conversation_id': record.conversationId,
      'client_correlation_id': record.clientCorrelationId,
      'message_type': record.messageType,
      'payload_reference': record.payloadReference,
      'media_local_ref': record.mediaLocalRef,
      'encryption_version': record.encryptionVersion,
      'key_id': record.keyId,
      'cipher_algorithm': record.cipherAlgorithm,
      'nonce': record.nonce,
      'content_checksum': record.contentChecksum,
      'payload_hash': record.payloadHash,
      'state': record.state.name,
      'sdk_message_id': record.sdkMessageId,
      'server_msg_id': record.serverMsgId,
      'dispatch_attempt_id': record.dispatchAttemptId,
      'dispatch_intent_at': record.dispatchIntentAtMs,
      'result_code': record.resultCode,
      'retry_count': record.retryCount,
      'next_retry_at': record.nextRetryAtMs,
      'created_at': record.createdAtMs,
      'updated_at': record.updatedAtMs,
      'lease_owner_id': record.leaseOwnerId,
      'fencing_token': record.fencingToken,
      'recovery_lag': record.recoveryLag ? 1 : 0,
      'recovery_conflict': record.recoveryConflict ? 1 : 0,
    };

ImOutboxRecord imOutboxFromStorageMap(Map<String, Object?> row) =>
    ImOutboxRecord(
      operationId: _string(row['operation_id']),
      ownerUserId: _string(row['owner_user_id']),
      conversationId: _string(row['conversation_id']),
      clientCorrelationId: _string(row['client_correlation_id']),
      messageType: _int(row['message_type']),
      payloadReference: _string(row['payload_reference']),
      state: _enumByName(
        ImOutboxState.values,
        row['state']?.toString(),
        ImOutboxState.created,
      ),
      createdAtMs: _int(row['created_at']),
      updatedAtMs: _int(row['updated_at']),
      mediaLocalRef: _optionalString(row['media_local_ref']),
      encryptionVersion: _optionalInt(row['encryption_version']),
      keyId: _optionalString(row['key_id']),
      cipherAlgorithm: _optionalString(row['cipher_algorithm']),
      nonce: _optionalString(row['nonce']),
      contentChecksum: _optionalString(row['content_checksum']),
      payloadHash: _string(row['payload_hash']),
      sdkMessageId: _optionalString(row['sdk_message_id']),
      serverMsgId: _optionalString(row['server_msg_id']),
      dispatchAttemptId: _optionalString(row['dispatch_attempt_id']),
      dispatchIntentAtMs: _optionalInt(row['dispatch_intent_at']),
      resultCode: _optionalString(row['result_code']),
      retryCount: _int(row['retry_count']),
      nextRetryAtMs: _optionalInt(row['next_retry_at']),
      leaseOwnerId: _string(row['lease_owner_id']),
      fencingToken: _int(row['fencing_token']),
      recoveryLag: _int(row['recovery_lag']) != 0,
      recoveryConflict: _int(row['recovery_conflict']) != 0,
    );

Map<String, Object?> imOutboxRecoveryToStorageMap(
  ImOutboxRecoveryRecord record,
) =>
    <String, Object?>{
      'owner_user_id': record.ownerUserId,
      'operation_id': record.operationId,
      'client_correlation_id': record.clientCorrelationId,
      'conversation_id': record.conversationId,
      'message_type': record.messageType,
      'recovery_revision': record.recoveryRevision,
      'state': record.state.name,
      'dispatch_attempt_id': record.dispatchAttemptId,
      'dispatch_intent_at': record.dispatchIntentAtMs,
      'payload_reference_or_ciphertext': record.payloadReferenceOrCiphertext,
      'payload_hash': record.payloadHash,
      'checksum': record.checksum,
      'sdk_local_id': record.sdkLocalId,
      'server_msg_id': record.serverMsgId,
      'result_code': record.resultCode,
      'updated_at': record.updatedAtMs,
    };

ImOutboxRecoveryRecord imOutboxRecoveryFromStorageMap(
  Map<String, Object?> row,
) =>
    ImOutboxRecoveryRecord(
      ownerUserId: _string(row['owner_user_id']),
      operationId: _string(row['operation_id']),
      clientCorrelationId: _string(row['client_correlation_id']),
      conversationId: _string(row['conversation_id']),
      messageType: _int(row['message_type']),
      recoveryRevision: _int(row['recovery_revision']),
      state: _enumByName(
        ImOutboxCopyState.values,
        row['state']?.toString(),
        ImOutboxCopyState.copyPrepared,
      ),
      dispatchAttemptId: _optionalString(row['dispatch_attempt_id']),
      dispatchIntentAtMs: _optionalInt(row['dispatch_intent_at']),
      payloadReferenceOrCiphertext:
          _string(row['payload_reference_or_ciphertext']),
      payloadHash: _string(row['payload_hash']),
      checksum: _string(row['checksum']),
      sdkLocalId: _optionalString(row['sdk_local_id']),
      serverMsgId: _optionalString(row['server_msg_id']),
      resultCode: _optionalString(row['result_code']),
      updatedAtMs: _int(row['updated_at']),
    );

String _string(Object? value) => value?.toString() ?? '';

String? _optionalString(Object? value) {
  final valueText = value?.toString().trim() ?? '';
  return valueText.isEmpty ? null : valueText;
}

int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

int? _optionalInt(Object? value) {
  if (value == null) return null;
  return int.tryParse('$value');
}

T _enumByName<T extends Enum>(Iterable<T> values, String? raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
