import 'package:tencent_cloud_chat_demo/src/services/im/im05_contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im_ingress_store.dart';

/// First-round persistence coordinator for Commit Journal, Projection
/// Checkpoint, Effect Ledger, and the two-sided Outbox prepare boundary.
///
/// This class owns protocol decisions only. The actual database owner remains
/// [ConversationLocalStore] through [ImIngressStore.transaction].
class Im05Persistence {
  Im05Persistence({required ImIngressStore store}) : _store = store;

  final ImIngressStore _store;

  /// Persists the Journal's explicit PREPARED marker. The Inbox remains the
  /// event recovery anchor, but this marker makes the Journal state machine
  /// observable to recovery and contract tests.
  Future<ImCommitJournalRecord?> prepareJournal({
    required ImCommitJournalRecord record,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) {
    if (record.state != ImCommitJournalState.prepared) {
      throw ArgumentError('prepareJournal requires prepared state');
    }
    return _store.transaction<ImCommitJournalRecord?>((transaction) async {
      if (!await _hasCurrentLease(
          transaction, record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
        return null;
      }
      final current = await transaction.findCommitJournal(
        ownerUserId: record.ownerUserId,
        journalId: record.journalId,
      );
      if (current != null) {
        _checkJournalIdentity(current, record);
        return current;
      }
      final prepared = record.copyWith(
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      final inserted = await transaction.insertCommitJournalIfAbsent(prepared);
      if (inserted) return prepared;
      final duplicate = await transaction.findCommitJournal(
        ownerUserId: record.ownerUserId,
        journalId: record.journalId,
      );
      if (duplicate != null) _checkJournalIdentity(duplicate, record);
      return duplicate;
    });
  }

  Future<ImCommitJournalRecord?> commitMetadata({
    required ImCommitJournalRecord record,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) {
    if (record.state != ImCommitJournalState.metadataCommitted) {
      throw ArgumentError('commitMetadata requires metadataCommitted state');
    }
    return _store.transaction<ImCommitJournalRecord?>((transaction) async {
      if (!await _hasCurrentLease(
          transaction, record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
        return null;
      }
      final current = await transaction.findCommitJournal(
        ownerUserId: record.ownerUserId,
        journalId: record.journalId,
      );
      var prepared = current;
      if (prepared == null) {
        final preparedRecord = record.copyWith(
          state: ImCommitJournalState.prepared,
          updatedAtMs: nowMs,
          leaseOwnerId: leaseOwnerId,
          fencingToken: fencingToken,
        );
        final inserted = await transaction.insertCommitJournalIfAbsent(
          preparedRecord,
        );
        prepared = inserted
            ? preparedRecord
            : await transaction.findCommitJournal(
                ownerUserId: record.ownerUserId,
                journalId: record.journalId,
              );
      }
      if (prepared == null) return null;
      _checkJournalIdentity(prepared, record);
      if (prepared.state == ImCommitJournalState.metadataCommitted ||
          prepared.state == ImCommitJournalState.projectionPublished ||
          prepared.state == ImCommitJournalState.completed) {
        return prepared;
      }
      if (prepared.state != ImCommitJournalState.prepared) return null;
      final metadata = record.copyWith(
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      final advanced = await transaction.updateCommitJournalIfCurrent(
        record: metadata,
        expectedState: ImCommitJournalState.prepared,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
      return advanced ? metadata : null;
    });
  }

  /// Saves the checkpoint and publishes the Journal stage in one transaction.
  /// A stale checkpoint or fencing token is rejected without changing either
  /// record.
  Future<ImCommitJournalRecord?> publishProjection({
    required ImCommitJournalRecord journal,
    required ImProjectionCheckpointRecord checkpoint,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) {
    return _store.transaction<ImCommitJournalRecord?>((transaction) async {
      if (!await _hasCurrentLease(transaction, journal.ownerUserId,
          leaseOwnerId, fencingToken, nowMs)) {
        return null;
      }
      final current = await transaction.findCommitJournal(
        ownerUserId: journal.ownerUserId,
        journalId: journal.journalId,
      );
      if (current == null) return null;
      _checkJournalIdentity(current, journal);
      if (current.state == ImCommitJournalState.projectionPublished ||
          current.state == ImCommitJournalState.completed) {
        _checkCheckpointIdentity(checkpoint, journal);
        final persistedCheckpoint = await transaction.findProjectionCheckpoint(
          ownerUserId: checkpoint.ownerUserId,
          scope: checkpoint.scope,
        );
        if (persistedCheckpoint == null) return null;
        if (!_sameCheckpointValue(persistedCheckpoint, checkpoint)) {
          throw const Im05IdentityConflictException(
            'projection checkpoint conflict',
          );
        }
        return current;
      }
      if (current.state != ImCommitJournalState.metadataCommitted) {
        return null;
      }
      _checkCheckpointIdentity(checkpoint, journal);
      final checkpointToSave = ImProjectionCheckpointRecord(
        ownerUserId: checkpoint.ownerUserId,
        scope: checkpoint.scope,
        commitRevision: checkpoint.commitRevision,
        lastJournalId: checkpoint.lastJournalId,
        coverageRevision: checkpoint.coverageRevision,
        watermarkRevision: checkpoint.watermarkRevision,
        barrierRevision: checkpoint.barrierRevision,
        projectionVersion: checkpoint.projectionVersion,
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      final saved = await transaction.saveProjectionCheckpointIfCurrent(
        record: checkpointToSave,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
      if (!saved) return null;
      final projected = current.copyWith(
        state: ImCommitJournalState.projectionPublished,
        projectionRevision: checkpoint.commitRevision,
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      final advanced = await transaction.updateCommitJournalIfCurrent(
        record: projected,
        expectedState: ImCommitJournalState.metadataCommitted,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
      return advanced ? projected : null;
    });
  }

  Future<ImCommitJournalRecord?> completeJournal({
    required String ownerUserId,
    required String journalId,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
    int? sideEffectRevision,
  }) {
    return _store.transaction<ImCommitJournalRecord?>((transaction) async {
      if (!await _hasCurrentLease(
          transaction, ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
        return null;
      }
      final current = await transaction.findCommitJournal(
        ownerUserId: ownerUserId,
        journalId: journalId,
      );
      if (current == null) return null;
      if (current.state == ImCommitJournalState.completed) return current;
      if (current.state != ImCommitJournalState.projectionPublished) {
        return null;
      }
      final completed = current.copyWith(
        state: ImCommitJournalState.completed,
        sideEffectRevision: sideEffectRevision ?? current.sideEffectRevision,
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      final advanced = await transaction.updateCommitJournalIfCurrent(
        record: completed,
        expectedState: ImCommitJournalState.projectionPublished,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
      return advanced ? completed : null;
    });
  }

  Future<ImOutboxRecord?> transitionOutbox({
    required ImOutboxRecord next,
    required ImOutboxState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) {
    if (!isValidImOutboxTransition(expectedState, next.state)) {
      throw ArgumentError.value(
        next.state,
        'next.state',
        'is not valid after $expectedState',
      );
    }
    return _store.transaction<ImOutboxRecord?>((transaction) async {
      if (!await _hasCurrentLease(
          transaction, next.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
        return null;
      }
      final current = await transaction.findOutbox(
        ownerUserId: next.ownerUserId,
        operationId: next.operationId,
      );
      if (current == null) return null;
      _checkOutboxRecordIdentity(current, next);
      if (current.state == next.state) return current;
      if (current.state != expectedState) return null;
      final persisted = next.copyWith(
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      final changed = await transaction.updateOutboxIfCurrent(
        record: persisted,
        expectedState: expectedState,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
      return changed ? persisted : null;
    });
  }

  Future<ImOutboxRecoveryRecord?> transitionOutboxRecoveryCopy({
    required ImOutboxRecoveryRecord next,
    required ImOutboxCopyState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) {
    if (!isValidImOutboxRecoveryTransition(expectedState, next.state)) {
      throw ArgumentError.value(
        next.state,
        'next.state',
        'is not valid after $expectedState',
      );
    }
    return _store.transaction<ImOutboxRecoveryRecord?>((transaction) async {
      if (!await _hasCurrentLease(
          transaction, next.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
        return null;
      }
      final current = await transaction.findOutboxRecovery(
        ownerUserId: next.ownerUserId,
        operationId: next.operationId,
      );
      if (current == null) return null;
      _checkRecoveryIdentity(current, next);
      if (current.state == next.state) return current;
      if (current.state != expectedState) return null;
      final persisted = ImOutboxRecoveryRecord(
        ownerUserId: next.ownerUserId,
        operationId: next.operationId,
        clientCorrelationId: next.clientCorrelationId,
        conversationId: next.conversationId,
        messageType: next.messageType,
        recoveryRevision: next.recoveryRevision,
        state: next.state,
        dispatchAttemptId: next.dispatchAttemptId,
        dispatchIntentAtMs: next.dispatchIntentAtMs,
        payloadReferenceOrCiphertext: next.payloadReferenceOrCiphertext,
        payloadHash: next.payloadHash,
        checksum: next.checksum,
        sdkLocalId: next.sdkLocalId,
        serverMsgId: next.serverMsgId,
        resultCode: next.resultCode,
        updatedAtMs: nowMs,
      );
      final changed = await transaction.updateOutboxRecoveryIfCurrent(
        record: persisted,
        expectedState: expectedState,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
      return changed ? persisted : null;
    });
  }

  Future<ImEffectLedgerRecord?> ensureEffect({
    required ImEffectLedgerRecord record,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) {
    return _store.transaction<ImEffectLedgerRecord?>((transaction) async {
      if (!await _hasCurrentLease(
          transaction, record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
        return null;
      }
      final current = await transaction.findEffect(
        ownerUserId: record.ownerUserId,
        effectId: record.effectId,
      );
      if (current != null) {
        if (current.journalId != record.journalId ||
            current.effectKind != record.effectKind) {
          throw const Im05IdentityConflictException('effect identity conflict');
        }
        return current;
      }
      final persisted = ImEffectLedgerRecord(
        ownerUserId: record.ownerUserId,
        effectId: record.effectId,
        journalId: record.journalId,
        effectKind: record.effectKind,
        state: ImEffectLedgerState.pending,
        attemptCount: record.attemptCount,
        lastError: record.lastError,
        createdAtMs: record.createdAtMs,
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      final inserted = await transaction.insertEffectIfAbsent(persisted);
      if (inserted) return persisted;
      return transaction.findEffect(
        ownerUserId: record.ownerUserId,
        effectId: record.effectId,
      );
    });
  }

  Future<ImEffectLedgerRecord?> startEffect({
    required String ownerUserId,
    required String effectId,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) {
    return _store.transaction<ImEffectLedgerRecord?>((transaction) async {
      if (!await _hasCurrentLease(
          transaction, ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
        return null;
      }
      final current = await transaction.findEffect(
        ownerUserId: ownerUserId,
        effectId: effectId,
      );
      if (current == null) return null;
      if (current.state == ImEffectLedgerState.running ||
          current.state == ImEffectLedgerState.completed ||
          current.state == ImEffectLedgerState.failed) {
        return current;
      }
      final running = ImEffectLedgerRecord(
        ownerUserId: current.ownerUserId,
        effectId: current.effectId,
        journalId: current.journalId,
        effectKind: current.effectKind,
        state: ImEffectLedgerState.running,
        attemptCount: current.attemptCount + 1,
        lastError: null,
        createdAtMs: current.createdAtMs,
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      final changed = await transaction.updateEffectIfCurrent(
        record: running,
        expectedState: ImEffectLedgerState.pending,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
      return changed ? running : null;
    });
  }

  Future<ImEffectLedgerRecord?> finishEffect({
    required String ownerUserId,
    required String effectId,
    required bool succeeded,
    String? error,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) {
    return _store.transaction<ImEffectLedgerRecord?>((transaction) async {
      if (!await _hasCurrentLease(
          transaction, ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
        return null;
      }
      final current = await transaction.findEffect(
        ownerUserId: ownerUserId,
        effectId: effectId,
      );
      if (current == null) return null;
      if (current.state == ImEffectLedgerState.completed ||
          current.state == ImEffectLedgerState.failed) {
        return current;
      }
      if (current.state != ImEffectLedgerState.running) return null;
      final finished = ImEffectLedgerRecord(
        ownerUserId: current.ownerUserId,
        effectId: current.effectId,
        journalId: current.journalId,
        effectKind: current.effectKind,
        state: succeeded
            ? ImEffectLedgerState.completed
            : ImEffectLedgerState.failed,
        attemptCount: current.attemptCount,
        lastError: succeeded ? null : error,
        createdAtMs: current.createdAtMs,
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      final changed = await transaction.updateEffectIfCurrent(
        record: finished,
        expectedState: ImEffectLedgerState.running,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
      return changed ? finished : null;
    });
  }

  /// Persists both sides of the Prepared boundary before any SDK call.
  Future<ImOutboxDispatchAssessment> prepareOutbox({
    required ImOutboxRecord main,
    required ImOutboxRecoveryRecord recoveryCopy,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) {
    if (main.state != ImOutboxState.prepared ||
        recoveryCopy.state != ImOutboxCopyState.copyPrepared) {
      throw ArgumentError('prepareOutbox requires both Prepared states');
    }
    return _store.transaction<ImOutboxDispatchAssessment>((transaction) async {
      if (!await _hasCurrentLease(
          transaction, main.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
        return const ImOutboxDispatchAssessment(
          decision: ImOutboxDispatchDecision.fencingRejected,
        );
      }
      if (!_sameOutboxIdentity(main, recoveryCopy)) {
        throw const Im05IdentityConflictException('outbox identity conflict');
      }
      final currentMain = await transaction.findOutbox(
        ownerUserId: main.ownerUserId,
        operationId: main.operationId,
      );
      final currentCopy = await transaction.findOutboxRecovery(
        ownerUserId: recoveryCopy.ownerUserId,
        operationId: recoveryCopy.operationId,
      );
      if (currentMain == null) {
        await transaction.insertOutboxIfAbsent(main.copyWith(
          updatedAtMs: nowMs,
          leaseOwnerId: leaseOwnerId,
          fencingToken: fencingToken,
        ));
      } else if (!_sameOutboxIdentity(currentMain, recoveryCopy)) {
        throw const Im05IdentityConflictException('main outbox conflict');
      }
      if (currentCopy == null) {
        await transaction.insertOutboxRecoveryIfAbsent(recoveryCopy);
      } else if (!_sameRecoveryIdentity(currentCopy, recoveryCopy)) {
        throw const Im05IdentityConflictException(
            'outbox recovery copy conflict');
      }
      return _assess(
        main: await transaction.findOutbox(
          ownerUserId: main.ownerUserId,
          operationId: main.operationId,
        ),
        recoveryCopy: await transaction.findOutboxRecovery(
          ownerUserId: main.ownerUserId,
          operationId: main.operationId,
        ),
        leaseValid: true,
      );
    });
  }

  /// Returns whether a fresh SDK dispatch is permitted. A recorded Intent is
  /// deliberately classified as OutcomeUnknown and never becomes dispatchable
  /// through recovery.
  Future<ImOutboxDispatchAssessment> assessOutboxForDispatch({
    required String ownerUserId,
    required String operationId,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) {
    return _store.transaction<ImOutboxDispatchAssessment>((transaction) async {
      final leaseValid = await _hasCurrentLease(
        transaction,
        ownerUserId,
        leaseOwnerId,
        fencingToken,
        nowMs,
      );
      return _assess(
        main: await transaction.findOutbox(
          ownerUserId: ownerUserId,
          operationId: operationId,
        ),
        recoveryCopy: await transaction.findOutboxRecovery(
          ownerUserId: ownerUserId,
          operationId: operationId,
        ),
        leaseValid: leaseValid,
      );
    });
  }

  /// Records the single dispatch decision after both Prepared records agree.
  /// The returned `ready` assessment means the caller may make the one SDK
  /// call for this dispatch attempt. After a crash, re-assessment is
  /// `outcomeUnknown` and cannot be used to send again.
  Future<ImOutboxDispatchAssessment> recordDispatchIntent({
    required String ownerUserId,
    required String operationId,
    required String dispatchAttemptId,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) {
    if (dispatchAttemptId.trim().isEmpty) {
      throw ArgumentError.value(
        dispatchAttemptId,
        'dispatchAttemptId',
        'must not be empty',
      );
    }
    return _store.transaction<ImOutboxDispatchAssessment>((transaction) async {
      final assessment = _assess(
        main: await transaction.findOutbox(
          ownerUserId: ownerUserId,
          operationId: operationId,
        ),
        recoveryCopy: await transaction.findOutboxRecovery(
          ownerUserId: ownerUserId,
          operationId: operationId,
        ),
        leaseValid: await _hasCurrentLease(
          transaction,
          ownerUserId,
          leaseOwnerId,
          fencingToken,
          nowMs,
        ),
      );
      if (!assessment.canDispatch) return assessment;
      final main = assessment.main!;
      final copy = assessment.recoveryCopy!;
      final intentMain = main.copyWith(
        state: ImOutboxState.dispatchIntent,
        dispatchAttemptId: dispatchAttemptId,
        dispatchIntentAtMs: nowMs,
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      final intentCopy = ImOutboxRecoveryRecord(
        ownerUserId: copy.ownerUserId,
        operationId: copy.operationId,
        clientCorrelationId: copy.clientCorrelationId,
        conversationId: copy.conversationId,
        messageType: copy.messageType,
        recoveryRevision: copy.recoveryRevision + 1,
        state: ImOutboxCopyState.dispatchIntent,
        dispatchAttemptId: dispatchAttemptId,
        dispatchIntentAtMs: nowMs,
        payloadReferenceOrCiphertext: copy.payloadReferenceOrCiphertext,
        payloadHash: copy.payloadHash,
        checksum: copy.checksum,
        sdkLocalId: copy.sdkLocalId,
        serverMsgId: copy.serverMsgId,
        resultCode: copy.resultCode,
        updatedAtMs: nowMs,
      );
      final mainChanged = await transaction.updateOutboxIfCurrent(
        record: intentMain,
        expectedState: ImOutboxState.prepared,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
      final copyChanged = await transaction.updateOutboxRecoveryIfCurrent(
        record: intentCopy,
        expectedState: ImOutboxCopyState.copyPrepared,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
      if (!mainChanged || !copyChanged) {
        return const ImOutboxDispatchAssessment(
          decision: ImOutboxDispatchDecision.recoveryConflict,
        );
      }
      return ImOutboxDispatchAssessment(
        decision: ImOutboxDispatchDecision.ready,
        main: intentMain,
        recoveryCopy: intentCopy,
      );
    });
  }

  /// Marks a recorded Intent as unknown on both ledgers. This is the only
  /// recovery transition exposed here; it never invokes the SDK.
  Future<bool> recordOutcomeUnknown({
    required String ownerUserId,
    required String operationId,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
    String? resultCode,
  }) {
    return _store.transaction<bool>((transaction) async {
      if (!await _hasCurrentLease(
          transaction, ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
        return false;
      }
      final main = await transaction.findOutbox(
        ownerUserId: ownerUserId,
        operationId: operationId,
      );
      final copy = await transaction.findOutboxRecovery(
        ownerUserId: ownerUserId,
        operationId: operationId,
      );
      if (main == null ||
          copy == null ||
          main.dispatchAttemptId != copy.dispatchAttemptId) {
        return false;
      }
      if (main.state == ImOutboxState.outcomeUnknown &&
          copy.state == ImOutboxCopyState.outcomeUnknown) {
        return true;
      }
      if ((main.state != ImOutboxState.dispatchIntent &&
              main.state != ImOutboxState.sending) ||
          (copy.state != ImOutboxCopyState.dispatchIntent &&
              copy.state != ImOutboxCopyState.outcomeUnknown)) {
        return false;
      }
      final unknownMain = main.copyWith(
        state: ImOutboxState.outcomeUnknown,
        resultCode: resultCode ?? main.resultCode,
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      final unknownCopy = ImOutboxRecoveryRecord(
        ownerUserId: copy.ownerUserId,
        operationId: copy.operationId,
        clientCorrelationId: copy.clientCorrelationId,
        conversationId: copy.conversationId,
        messageType: copy.messageType,
        recoveryRevision: copy.recoveryRevision + 1,
        state: ImOutboxCopyState.outcomeUnknown,
        dispatchAttemptId: copy.dispatchAttemptId,
        dispatchIntentAtMs: copy.dispatchIntentAtMs,
        payloadReferenceOrCiphertext: copy.payloadReferenceOrCiphertext,
        payloadHash: copy.payloadHash,
        checksum: copy.checksum,
        sdkLocalId: copy.sdkLocalId,
        serverMsgId: copy.serverMsgId,
        resultCode: resultCode ?? copy.resultCode,
        updatedAtMs: nowMs,
      );
      final mainChanged = await transaction.updateOutboxIfCurrent(
        record: unknownMain,
        expectedState: main.state,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
      final copyChanged = copy.state == ImOutboxCopyState.outcomeUnknown
          ? true
          : await transaction.updateOutboxRecoveryIfCurrent(
              record: unknownCopy,
              expectedState: ImOutboxCopyState.dispatchIntent,
              leaseOwnerId: leaseOwnerId,
              fencingToken: fencingToken,
              nowMs: nowMs,
            );
      return mainChanged && copyChanged;
    });
  }

  Future<bool> recordOutboxSdkSucceeded({
    required String ownerUserId,
    required String operationId,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
    String? sdkLocalId,
    String? serverMsgId,
    String? resultCode,
  }) {
    return _recordOutboxSdkResult(
      ownerUserId: ownerUserId,
      operationId: operationId,
      leaseOwnerId: leaseOwnerId,
      fencingToken: fencingToken,
      nowMs: nowMs,
      nextMainState: ImOutboxState.acknowledged,
      sdkLocalId: sdkLocalId,
      serverMsgId: serverMsgId,
      resultCode: resultCode,
    );
  }

  Future<bool> recordOutboxSdkFailed({
    required String ownerUserId,
    required String operationId,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
    String? sdkLocalId,
    String? serverMsgId,
    String? resultCode,
  }) {
    return _recordOutboxSdkResult(
      ownerUserId: ownerUserId,
      operationId: operationId,
      leaseOwnerId: leaseOwnerId,
      fencingToken: fencingToken,
      nowMs: nowMs,
      nextMainState: ImOutboxState.failedTerminal,
      sdkLocalId: sdkLocalId,
      serverMsgId: serverMsgId,
      resultCode: resultCode,
    );
  }

  Future<bool> completeOutboxProjection({
    required String ownerUserId,
    required String operationId,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) {
    return _store.transaction<bool>((transaction) async {
      if (!await _hasCurrentLease(
          transaction, ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
        return false;
      }
      final main = await transaction.findOutbox(
        ownerUserId: ownerUserId,
        operationId: operationId,
      );
      final copy = await transaction.findOutboxRecovery(
        ownerUserId: ownerUserId,
        operationId: operationId,
      );
      if (main == null || copy == null || !_sameOutboxIdentity(main, copy)) {
        return false;
      }
      if (main.dispatchAttemptId != null &&
          copy.dispatchAttemptId != null &&
          main.dispatchAttemptId != copy.dispatchAttemptId) {
        return false;
      }
      if (main.state == ImOutboxState.completed &&
          copy.state == ImOutboxCopyState.reconciled) {
        return true;
      }
      if (main.state != ImOutboxState.acknowledged) {
        return false;
      }
      if (copy.state != ImOutboxCopyState.resultRecorded &&
          copy.state != ImOutboxCopyState.reconciled) {
        return false;
      }
      if (copy.state == ImOutboxCopyState.resultRecorded) {
        final reconciled = ImOutboxRecoveryRecord(
          ownerUserId: copy.ownerUserId,
          operationId: copy.operationId,
          clientCorrelationId: copy.clientCorrelationId,
          conversationId: copy.conversationId,
          messageType: copy.messageType,
          recoveryRevision: copy.recoveryRevision + 1,
          state: ImOutboxCopyState.reconciled,
          dispatchAttemptId: copy.dispatchAttemptId,
          dispatchIntentAtMs: copy.dispatchIntentAtMs,
          payloadReferenceOrCiphertext: copy.payloadReferenceOrCiphertext,
          payloadHash: copy.payloadHash,
          checksum: copy.checksum,
          sdkLocalId: copy.sdkLocalId,
          serverMsgId: copy.serverMsgId,
          resultCode: copy.resultCode,
          updatedAtMs: nowMs,
        );
        final copyChanged = await transaction.updateOutboxRecoveryIfCurrent(
          record: reconciled,
          expectedState: ImOutboxCopyState.resultRecorded,
          leaseOwnerId: leaseOwnerId,
          fencingToken: fencingToken,
          nowMs: nowMs,
        );
        if (!copyChanged) return false;
      }
      final completed = main.copyWith(
        state: ImOutboxState.completed,
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      return transaction.updateOutboxIfCurrent(
        record: completed,
        expectedState: ImOutboxState.acknowledged,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
    });
  }

  Future<bool> _recordOutboxSdkResult({
    required String ownerUserId,
    required String operationId,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
    required ImOutboxState nextMainState,
    String? sdkLocalId,
    String? serverMsgId,
    String? resultCode,
  }) {
    if (nextMainState != ImOutboxState.acknowledged &&
        nextMainState != ImOutboxState.failedTerminal) {
      throw ArgumentError.value(nextMainState, 'nextMainState');
    }
    return _store.transaction<bool>((transaction) async {
      if (!await _hasCurrentLease(
          transaction, ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
        return false;
      }
      final main = await transaction.findOutbox(
        ownerUserId: ownerUserId,
        operationId: operationId,
      );
      final copy = await transaction.findOutboxRecovery(
        ownerUserId: ownerUserId,
        operationId: operationId,
      );
      if (main == null || copy == null || !_sameOutboxIdentity(main, copy)) {
        return false;
      }
      if (main.dispatchAttemptId != null &&
          copy.dispatchAttemptId != null &&
          main.dispatchAttemptId != copy.dispatchAttemptId) {
        return false;
      }
      if (main.state == ImOutboxState.completed &&
          copy.state == ImOutboxCopyState.reconciled) {
        return true;
      }
      if (main.state == nextMainState &&
          (copy.state == ImOutboxCopyState.resultRecorded ||
              copy.state == ImOutboxCopyState.reconciled)) {
        return true;
      }
      // IM-08: a late SDK success/failure callback must never silently
      // overwrite an already-resolved OutcomeUnknown. The single Writer
      // keeps OutcomeUnknown open until history, realtime or an explicit
      // recovery query adopts the operation; transitioning it from the
      // dispatch path would resurrect or fail UI bubbles that the user
      // is still waiting on.
      if (main.state != ImOutboxState.sending) {
        return false;
      }

      if (copy.state == ImOutboxCopyState.dispatchIntent ||
          copy.state == ImOutboxCopyState.outcomeUnknown) {
        final nextCopyState = copy.state == ImOutboxCopyState.dispatchIntent
            ? ImOutboxCopyState.resultRecorded
            : ImOutboxCopyState.reconciled;
        final resultCopy = ImOutboxRecoveryRecord(
          ownerUserId: copy.ownerUserId,
          operationId: copy.operationId,
          clientCorrelationId: copy.clientCorrelationId,
          conversationId: copy.conversationId,
          messageType: copy.messageType,
          recoveryRevision: copy.recoveryRevision + 1,
          state: nextCopyState,
          dispatchAttemptId: copy.dispatchAttemptId,
          dispatchIntentAtMs: copy.dispatchIntentAtMs,
          payloadReferenceOrCiphertext: copy.payloadReferenceOrCiphertext,
          payloadHash: copy.payloadHash,
          checksum: copy.checksum,
          sdkLocalId: sdkLocalId ?? copy.sdkLocalId,
          serverMsgId: serverMsgId ?? copy.serverMsgId,
          resultCode: resultCode ?? copy.resultCode,
          updatedAtMs: nowMs,
        );
        final copyChanged = await transaction.updateOutboxRecoveryIfCurrent(
          record: resultCopy,
          expectedState: copy.state,
          leaseOwnerId: leaseOwnerId,
          fencingToken: fencingToken,
          nowMs: nowMs,
        );
        if (!copyChanged) return false;
      } else if (copy.state != ImOutboxCopyState.resultRecorded &&
          copy.state != ImOutboxCopyState.reconciled) {
        return false;
      }

      final resultMain = main.copyWith(
        state: nextMainState,
        sdkMessageId: sdkLocalId,
        serverMsgId: serverMsgId,
        resultCode: resultCode,
        updatedAtMs: nowMs,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
      );
      return transaction.updateOutboxIfCurrent(
        record: resultMain,
        expectedState: main.state,
        leaseOwnerId: leaseOwnerId,
        fencingToken: fencingToken,
        nowMs: nowMs,
      );
    });
  }

  Future<ImOutboxDispatchAssessment> recoverOutbox({
    required String ownerUserId,
    required String operationId,
  }) {
    return _store.transaction<ImOutboxDispatchAssessment>((transaction) async {
      final main = await transaction.findOutbox(
        ownerUserId: ownerUserId,
        operationId: operationId,
      );
      final copy = await transaction.findOutboxRecovery(
        ownerUserId: ownerUserId,
        operationId: operationId,
      );
      return _assess(main: main, recoveryCopy: copy, leaseValid: true);
    });
  }
}

class ImOutboxDispatchAssessment {
  const ImOutboxDispatchAssessment({
    required this.decision,
    this.main,
    this.recoveryCopy,
  });

  final ImOutboxDispatchDecision decision;
  final ImOutboxRecord? main;
  final ImOutboxRecoveryRecord? recoveryCopy;

  bool get canDispatch => decision == ImOutboxDispatchDecision.ready;

  bool get requiresOutcomeQuery =>
      decision == ImOutboxDispatchDecision.outcomeUnknown;
}

class Im05IdentityConflictException implements Exception {
  const Im05IdentityConflictException(this.message);

  final String message;

  @override
  String toString() => 'IM-05 identity conflict: $message';
}

Future<bool> _hasCurrentLease(
  Im05Transaction transaction,
  String ownerUserId,
  String leaseOwnerId,
  int fencingToken,
  int nowMs,
) async {
  final lease = await transaction.findWriterLease(ownerUserId);
  return lease != null &&
      lease.leaseOwnerId == leaseOwnerId &&
      lease.fencingToken == fencingToken &&
      !lease.isExpiredAt(nowMs);
}

void _checkJournalIdentity(
  ImCommitJournalRecord current,
  ImCommitJournalRecord expected,
) {
  if (current.eventNamespace != expected.eventNamespace ||
      current.eventId != expected.eventId ||
      current.scope != expected.scope ||
      current.commitRevision != expected.commitRevision) {
    throw const Im05IdentityConflictException('journal identity conflict');
  }
}

void _checkCheckpointIdentity(
  ImProjectionCheckpointRecord checkpoint,
  ImCommitJournalRecord journal,
) {
  if (checkpoint.ownerUserId != journal.ownerUserId ||
      checkpoint.scope != journal.scope ||
      checkpoint.commitRevision != journal.commitRevision ||
      checkpoint.lastJournalId != journal.journalId) {
    throw const Im05IdentityConflictException('checkpoint does not match');
  }
}

void _checkOutboxRecordIdentity(
  ImOutboxRecord current,
  ImOutboxRecord expected,
) {
  if (current.ownerUserId != expected.ownerUserId ||
      current.operationId != expected.operationId ||
      current.conversationId != expected.conversationId ||
      current.clientCorrelationId != expected.clientCorrelationId ||
      current.messageType != expected.messageType ||
      current.payloadReference != expected.payloadReference ||
      current.payloadHash != expected.payloadHash) {
    throw const Im05IdentityConflictException('outbox identity conflict');
  }
}

void _checkRecoveryIdentity(
  ImOutboxRecoveryRecord current,
  ImOutboxRecoveryRecord expected,
) {
  if (!_sameRecoveryIdentity(current, expected)) {
    throw const Im05IdentityConflictException(
      'outbox recovery identity conflict',
    );
  }
}

bool _sameOutboxIdentity(
  ImOutboxRecord main,
  ImOutboxRecoveryRecord copy,
) {
  return main.ownerUserId == copy.ownerUserId &&
      main.operationId == copy.operationId &&
      main.conversationId == copy.conversationId &&
      main.clientCorrelationId == copy.clientCorrelationId &&
      main.messageType == copy.messageType &&
      main.payloadHash == copy.payloadHash &&
      (main.contentChecksum == null ||
          main.contentChecksum!.isEmpty ||
          copy.checksum.isEmpty ||
          main.contentChecksum == copy.checksum);
}

bool _sameRecoveryIdentity(
  ImOutboxRecoveryRecord current,
  ImOutboxRecoveryRecord expected,
) {
  return current.ownerUserId == expected.ownerUserId &&
      current.operationId == expected.operationId &&
      current.clientCorrelationId == expected.clientCorrelationId &&
      current.conversationId == expected.conversationId &&
      current.messageType == expected.messageType &&
      current.payloadHash == expected.payloadHash &&
      current.checksum == expected.checksum &&
      current.payloadReferenceOrCiphertext ==
          expected.payloadReferenceOrCiphertext;
}

bool _sameCheckpointValue(
  ImProjectionCheckpointRecord left,
  ImProjectionCheckpointRecord right,
) {
  return left.ownerUserId == right.ownerUserId &&
      left.scope == right.scope &&
      left.commitRevision == right.commitRevision &&
      left.lastJournalId == right.lastJournalId &&
      left.coverageRevision == right.coverageRevision &&
      left.watermarkRevision == right.watermarkRevision &&
      left.barrierRevision == right.barrierRevision &&
      left.projectionVersion == right.projectionVersion;
}

ImOutboxDispatchAssessment _assess({
  required ImOutboxRecord? main,
  required ImOutboxRecoveryRecord? recoveryCopy,
  required bool leaseValid,
}) {
  if (!leaseValid) {
    return ImOutboxDispatchAssessment(
      decision: ImOutboxDispatchDecision.fencingRejected,
      main: main,
      recoveryCopy: recoveryCopy,
    );
  }
  if (main == null) {
    return ImOutboxDispatchAssessment(
      decision: ImOutboxDispatchDecision.mainMissing,
      recoveryCopy: recoveryCopy,
    );
  }
  if (recoveryCopy == null) {
    return ImOutboxDispatchAssessment(
      decision: ImOutboxDispatchDecision.recoveryCopyMissing,
      main: main,
    );
  }
  if (!_sameOutboxIdentity(main, recoveryCopy)) {
    return ImOutboxDispatchAssessment(
      decision: ImOutboxDispatchDecision.identityConflict,
      main: main,
      recoveryCopy: recoveryCopy,
    );
  }
  if (main.dispatchAttemptId != null &&
      recoveryCopy.dispatchAttemptId != null &&
      main.dispatchAttemptId != recoveryCopy.dispatchAttemptId) {
    return ImOutboxDispatchAssessment(
      decision: ImOutboxDispatchDecision.recoveryConflict,
      main: main,
      recoveryCopy: recoveryCopy,
    );
  }
  if (main.recoveryConflict) {
    return ImOutboxDispatchAssessment(
      decision: ImOutboxDispatchDecision.recoveryConflict,
      main: main,
      recoveryCopy: recoveryCopy,
    );
  }
  if (main.recoveryLag) {
    return ImOutboxDispatchAssessment(
      decision: ImOutboxDispatchDecision.recoveryLag,
      main: main,
      recoveryCopy: recoveryCopy,
    );
  }
  if (main.state == ImOutboxState.dispatchIntent ||
      main.state == ImOutboxState.sending ||
      main.state == ImOutboxState.outcomeUnknown ||
      recoveryCopy.state == ImOutboxCopyState.dispatchIntent ||
      recoveryCopy.state == ImOutboxCopyState.outcomeUnknown) {
    return ImOutboxDispatchAssessment(
      decision: ImOutboxDispatchDecision.outcomeUnknown,
      main: main,
      recoveryCopy: recoveryCopy,
    );
  }
  if (main.state != ImOutboxState.prepared) {
    return ImOutboxDispatchAssessment(
      decision: ImOutboxDispatchDecision.mainNotPrepared,
      main: main,
      recoveryCopy: recoveryCopy,
    );
  }
  if (recoveryCopy.state != ImOutboxCopyState.copyPrepared) {
    return ImOutboxDispatchAssessment(
      decision: ImOutboxDispatchDecision.recoveryCopyNotPrepared,
      main: main,
      recoveryCopy: recoveryCopy,
    );
  }
  return ImOutboxDispatchAssessment(
    decision: ImOutboxDispatchDecision.ready,
    main: main,
    recoveryCopy: recoveryCopy,
  );
}
