import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_persistence.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im_ingress_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/writer_lease.dart';

void main() {
  group('IM-05 journal and projection checkpoint', () {
    test('declares the complete Journal state machine', () {
      expect(
        isValidImCommitJournalTransition(
          ImCommitJournalState.prepared,
          ImCommitJournalState.metadataCommitted,
        ),
        isTrue,
      );
      expect(
        isValidImCommitJournalTransition(
          ImCommitJournalState.metadataCommitted,
          ImCommitJournalState.projectionPublished,
        ),
        isTrue,
      );
      expect(
        isValidImCommitJournalTransition(
          ImCommitJournalState.projectionPublished,
          ImCommitJournalState.completed,
        ),
        isTrue,
      );
      expect(
        isValidImCommitJournalTransition(
          ImCommitJournalState.prepared,
          ImCommitJournalState.projectionPublished,
        ),
        isFalse,
      );
      expect(
        isValidImCommitJournalTransition(
          ImCommitJournalState.completed,
          ImCommitJournalState.prepared,
        ),
        isFalse,
      );
    });

    test('transitions Outbox through its legal states idempotently', () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquire(store, nowMs: 10);
      final persistence = Im05Persistence(store: store);
      const created = ImOutboxRecord(
        operationId: 'operation-state',
        ownerUserId: 'alice',
        conversationId: 'c2c_bob',
        clientCorrelationId: 'corr-state',
        messageType: 1,
        payloadReference: 'inlineEncryptedText:payload-state',
        payloadHash: 'hash-state',
        state: ImOutboxState.created,
        createdAtMs: 10,
        updatedAtMs: 10,
      );
      await store.transaction((transaction) {
        return transaction.insertOutboxIfAbsent(created);
      });
      final preparing = await persistence.transitionOutbox(
        next: created.copyWith(state: ImOutboxState.preparing),
        expectedState: ImOutboxState.created,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 11,
      );
      final prepared = await persistence.transitionOutbox(
        next: created.copyWith(state: ImOutboxState.prepared),
        expectedState: ImOutboxState.preparing,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 12,
      );
      final replayed = await persistence.transitionOutbox(
        next: created.copyWith(state: ImOutboxState.prepared),
        expectedState: ImOutboxState.preparing,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 13,
      );
      expect(preparing?.state, ImOutboxState.preparing);
      expect(prepared?.state, ImOutboxState.prepared);
      expect(replayed?.state, ImOutboxState.prepared);
      expect(
        () => persistence.transitionOutbox(
          next: created.copyWith(state: ImOutboxState.completed),
          expectedState: ImOutboxState.prepared,
          leaseOwnerId: lease.leaseOwnerId,
          fencingToken: lease.fencingToken,
          nowMs: 14,
        ),
        throwsArgumentError,
      );
    });

    test('lists only owner-scoped recoverable Outboxes in stable order',
        () async {
      final store = InMemoryImIngressStore();
      final persistence = Im05Persistence(store: store);
      const rows = <ImOutboxRecord>[
        ImOutboxRecord(
          operationId: 'prepared-newer',
          ownerUserId: 'alice',
          conversationId: 'c2c_bob',
          clientCorrelationId: 'corr-1',
          messageType: 1,
          payloadReference: '{}',
          payloadHash: 'hash-1',
          state: ImOutboxState.prepared,
          createdAtMs: 10,
          updatedAtMs: 30,
        ),
        ImOutboxRecord(
          operationId: 'intent-older',
          ownerUserId: 'alice',
          conversationId: 'c2c_bob',
          clientCorrelationId: 'corr-2',
          messageType: 1,
          payloadReference: '{}',
          payloadHash: 'hash-2',
          state: ImOutboxState.dispatchIntent,
          createdAtMs: 10,
          updatedAtMs: 20,
        ),
        ImOutboxRecord(
          operationId: 'other-owner',
          ownerUserId: 'mallory',
          conversationId: 'c2c_bob',
          clientCorrelationId: 'corr-3',
          messageType: 1,
          payloadReference: '{}',
          payloadHash: 'hash-3',
          state: ImOutboxState.prepared,
          createdAtMs: 10,
          updatedAtMs: 10,
        ),
      ];
      await store.transaction<void>((transaction) async {
        for (final row in rows) {
          await transaction.insertOutboxIfAbsent(row);
        }
      });

      final recovered = await persistence.listOutboxesForRecovery(
        ownerUserId: 'alice',
        states: const <ImOutboxState>[
          ImOutboxState.prepared,
          ImOutboxState.dispatchIntent,
        ],
        limit: 2,
      );

      expect(
        recovered.map((row) => row.operationId),
        <String>['intent-older', 'prepared-newer'],
      );
    });

    test('replays each commit stage idempotently', () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquire(store, nowMs: 10);
      final persistence = Im05Persistence(store: store);
      const preparedJournal = ImCommitJournalRecord(
        ownerUserId: 'alice',
        journalId: 'journal-1',
        eventNamespace: 'chat',
        eventId: 'event-1',
        scope: 'alice::c2c_bob',
        commitRevision: 7,
        state: ImCommitJournalState.prepared,
        createdAtMs: 10,
        updatedAtMs: 10,
      );
      const metadataJournal = ImCommitJournalRecord(
        ownerUserId: 'alice',
        journalId: 'journal-1',
        eventNamespace: 'chat',
        eventId: 'event-1',
        scope: 'alice::c2c_bob',
        commitRevision: 7,
        state: ImCommitJournalState.metadataCommitted,
        createdAtMs: 10,
        updatedAtMs: 10,
      );

      final firstPrepared = await persistence.prepareJournal(
        record: preparedJournal,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 10,
      );
      final replayedPrepared = await persistence.prepareJournal(
        record: preparedJournal,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 10,
      );
      expect(firstPrepared?.state, ImCommitJournalState.prepared);
      expect(replayedPrepared?.state, ImCommitJournalState.prepared);

      final firstMetadata = await persistence.commitMetadata(
        record: metadataJournal,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 11,
      );
      final replayedMetadata = await persistence.commitMetadata(
        record: metadataJournal,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 12,
      );
      expect(firstMetadata?.state, ImCommitJournalState.metadataCommitted);
      expect(replayedMetadata?.journalId, firstMetadata?.journalId);

      const checkpoint = ImProjectionCheckpointRecord(
        ownerUserId: 'alice',
        scope: 'alice::c2c_bob',
        commitRevision: 7,
        lastJournalId: 'journal-1',
        coverageRevision: 3,
        watermarkRevision: 4,
        barrierRevision: 5,
        projectionVersion: 1,
        updatedAtMs: 12,
      );
      final published = await persistence.publishProjection(
        journal: metadataJournal,
        checkpoint: checkpoint,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 13,
      );
      final replayedPublication = await persistence.publishProjection(
        journal: metadataJournal,
        checkpoint: checkpoint,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 14,
      );
      expect(published?.state, ImCommitJournalState.projectionPublished);
      expect(
        replayedPublication?.state,
        ImCommitJournalState.projectionPublished,
      );

      final completed = await persistence.completeJournal(
        ownerUserId: 'alice',
        journalId: 'journal-1',
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 15,
        sideEffectRevision: 8,
      );
      final replayedCompletion = await persistence.completeJournal(
        ownerUserId: 'alice',
        journalId: 'journal-1',
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 16,
        sideEffectRevision: 8,
      );
      expect(completed?.state, ImCommitJournalState.completed);
      expect(replayedCompletion?.state, ImCommitJournalState.completed);
      expect(replayedCompletion?.sideEffectRevision, 8);
    });

    test('rejects a stale fencing token without changing journal', () async {
      final store = InMemoryImIngressStore();
      final oldLease = await _acquire(store, nowMs: 10, ttlMs: 5);
      final persistence = Im05Persistence(store: store);
      const journal = ImCommitJournalRecord(
        ownerUserId: 'alice',
        journalId: 'journal-stale',
        eventNamespace: 'chat',
        eventId: 'event-stale',
        scope: 'alice::c2c_bob',
        commitRevision: 1,
        state: ImCommitJournalState.metadataCommitted,
        createdAtMs: 10,
        updatedAtMs: 10,
      );
      await persistence.commitMetadata(
        record: journal,
        leaseOwnerId: oldLease.leaseOwnerId,
        fencingToken: oldLease.fencingToken,
        nowMs: 11,
      );

      final newLease = await _acquire(
        store,
        owner: 'alice',
        leaseOwnerId: 'core-new',
        nowMs: 20,
      );
      final rejected = await persistence.publishProjection(
        journal: journal,
        checkpoint: const ImProjectionCheckpointRecord(
          ownerUserId: 'alice',
          scope: 'alice::c2c_bob',
          commitRevision: 1,
          lastJournalId: 'journal-stale',
          coverageRevision: 0,
          watermarkRevision: 0,
          barrierRevision: 0,
          projectionVersion: 1,
          updatedAtMs: 11,
        ),
        leaseOwnerId: oldLease.leaseOwnerId,
        fencingToken: oldLease.fencingToken,
        nowMs: 20,
      );
      expect(rejected, isNull);

      final accepted = await persistence.publishProjection(
        journal: journal,
        checkpoint: const ImProjectionCheckpointRecord(
          ownerUserId: 'alice',
          scope: 'alice::c2c_bob',
          commitRevision: 1,
          lastJournalId: 'journal-stale',
          coverageRevision: 0,
          watermarkRevision: 0,
          barrierRevision: 0,
          projectionVersion: 1,
          updatedAtMs: 11,
        ),
        leaseOwnerId: newLease.leaseOwnerId,
        fencingToken: newLease.fencingToken,
        nowMs: 21,
      );
      expect(accepted?.state, ImCommitJournalState.projectionPublished);
    });

    test('does not dispatch when recovery copy is missing or conflicts',
        () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquire(store, nowMs: 10);
      final persistence = Im05Persistence(store: store);
      final main = _mainOutbox();
      final copy = _recoveryCopy();

      await store.transaction((transaction) async {
        await transaction.insertOutboxIfAbsent(main);
      });
      final missing = await persistence.assessOutboxForDispatch(
        ownerUserId: 'alice',
        operationId: 'operation-1',
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 11,
      );
      expect(missing.decision, ImOutboxDispatchDecision.recoveryCopyMissing);
      expect(missing.canDispatch, isFalse);

      await store.transaction((transaction) async {
        await transaction.insertOutboxRecoveryIfAbsent(
          ImOutboxRecoveryRecord(
            ownerUserId: copy.ownerUserId,
            operationId: copy.operationId,
            clientCorrelationId: copy.clientCorrelationId,
            conversationId: copy.conversationId,
            messageType: copy.messageType,
            recoveryRevision: copy.recoveryRevision,
            state: copy.state,
            payloadReferenceOrCiphertext: copy.payloadReferenceOrCiphertext,
            payloadHash: 'different-payload-hash',
            checksum: copy.checksum,
            updatedAtMs: copy.updatedAtMs,
          ),
        );
      });
      final conflict = await persistence.assessOutboxForDispatch(
        ownerUserId: 'alice',
        operationId: 'operation-1',
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 12,
      );
      expect(conflict.decision, ImOutboxDispatchDecision.identityConflict);
      expect(conflict.canDispatch, isFalse);
    });

    test('DispatchIntent recovery becomes OutcomeUnknown and never resendable',
        () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquire(store, nowMs: 10);
      final persistence = Im05Persistence(store: store);
      final prepared = await persistence.prepareOutbox(
        main: _mainOutbox(),
        recoveryCopy: _recoveryCopy(),
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 11,
      );
      expect(prepared.decision, ImOutboxDispatchDecision.ready);

      final intent = await persistence.recordDispatchIntent(
        ownerUserId: 'alice',
        operationId: 'operation-1',
        dispatchAttemptId: 'attempt-1',
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 12,
      );
      expect(intent.decision, ImOutboxDispatchDecision.ready);

      final recovered = await persistence.recoverOutbox(
        ownerUserId: 'alice',
        operationId: 'operation-1',
      );
      expect(recovered.decision, ImOutboxDispatchDecision.outcomeUnknown);
      expect(recovered.requiresOutcomeQuery, isTrue);
      expect(recovered.canDispatch, isFalse);

      expect(
        await persistence.recordOutcomeUnknown(
          ownerUserId: 'alice',
          operationId: 'operation-1',
          leaseOwnerId: lease.leaseOwnerId,
          fencingToken: lease.fencingToken,
          nowMs: 13,
        ),
        isTrue,
      );
      final stillUnknown = await persistence.recoverOutbox(
        ownerUserId: 'alice',
        operationId: 'operation-1',
      );
      expect(stillUnknown.decision, ImOutboxDispatchDecision.outcomeUnknown);
      expect(stillUnknown.canDispatch, isFalse);
    });

    test('provider evidence resolves OutcomeUnknown and completes projection',
        () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquire(store, nowMs: 10);
      final persistence = Im05Persistence(store: store);
      await persistence.prepareOutbox(
        main: _mainOutbox(),
        recoveryCopy: _recoveryCopy(),
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 11,
      );
      await persistence.recordDispatchIntent(
        ownerUserId: 'alice',
        operationId: 'operation-1',
        dispatchAttemptId: 'attempt-1',
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 12,
      );
      expect(
        await persistence.recordOutcomeUnknown(
          ownerUserId: 'alice',
          operationId: 'operation-1',
          leaseOwnerId: lease.leaseOwnerId,
          fencingToken: lease.fencingToken,
          nowMs: 13,
        ),
        isTrue,
      );

      expect(
        await persistence.adoptOutboxProviderSucceeded(
          ownerUserId: 'alice',
          operationId: 'operation-1',
          clientCorrelationId: 'corr-1',
          conversationId: 'c2c_bob',
          payloadHash: 'payload-hash',
          leaseOwnerId: lease.leaseOwnerId,
          fencingToken: lease.fencingToken,
          nowMs: 14,
          sdkLocalId: 'local-1',
          serverMsgId: 'server-1',
        ),
        isTrue,
      );
      expect(
        await persistence.completeOutboxProjection(
          ownerUserId: 'alice',
          operationId: 'operation-1',
          leaseOwnerId: lease.leaseOwnerId,
          fencingToken: lease.fencingToken,
          nowMs: 15,
        ),
        isTrue,
      );
      final completed = await persistence.recoverOutbox(
        ownerUserId: 'alice',
        operationId: 'operation-1',
      );
      expect(completed.main?.state, ImOutboxState.completed);
      expect(
        completed.recoveryCopy?.state,
        ImOutboxCopyState.reconciled,
      );
      expect(completed.main?.serverMsgId, 'server-1');
    });

    test('provider evidence rejects a correlation or payload mismatch',
        () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquire(store, nowMs: 10);
      final persistence = Im05Persistence(store: store);
      await persistence.prepareOutbox(
        main: _mainOutbox(),
        recoveryCopy: _recoveryCopy(),
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 11,
      );
      final dispatch = await persistence.recordDispatchIntent(
        ownerUserId: 'alice',
        operationId: 'operation-1',
        dispatchAttemptId: 'attempt-1',
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 12,
      );
      await persistence.transitionOutbox(
        next: dispatch.main!.copyWith(state: ImOutboxState.sending),
        expectedState: ImOutboxState.dispatchIntent,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 13,
      );

      expect(
        await persistence.adoptOutboxProviderSucceeded(
          ownerUserId: 'alice',
          operationId: 'operation-1',
          clientCorrelationId: 'wrong-correlation',
          conversationId: 'c2c_bob',
          payloadHash: 'payload-hash',
          leaseOwnerId: lease.leaseOwnerId,
          fencingToken: lease.fencingToken,
          nowMs: 14,
        ),
        isFalse,
      );
      final unchanged = await persistence.recoverOutbox(
        ownerUserId: 'alice',
        operationId: 'operation-1',
      );
      expect(unchanged.main?.state, ImOutboxState.sending);
    });

    test('effect ledger claims and finishes idempotently', () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquire(store, nowMs: 10);
      final persistence = Im05Persistence(store: store);
      final pending = await persistence.ensureEffect(
        record: const ImEffectLedgerRecord(
          ownerUserId: 'alice',
          effectId: 'badge:alice::c2c_bob:7',
          journalId: 'journal-1',
          effectKind: 'badge',
          state: ImEffectLedgerState.pending,
          attemptCount: 0,
          createdAtMs: 10,
          updatedAtMs: 10,
        ),
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 11,
      );
      expect(pending?.state, ImEffectLedgerState.pending);
      final running = await persistence.startEffect(
        ownerUserId: 'alice',
        effectId: 'badge:alice::c2c_bob:7',
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 12,
      );
      expect(running?.state, ImEffectLedgerState.running);
      expect(running?.attemptCount, 1);
      final completed = await persistence.finishEffect(
        ownerUserId: 'alice',
        effectId: 'badge:alice::c2c_bob:7',
        succeeded: true,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 13,
      );
      final replayed = await persistence.finishEffect(
        ownerUserId: 'alice',
        effectId: 'badge:alice::c2c_bob:7',
        succeeded: false,
        error: 'ignored on replay',
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 14,
      );
      expect(completed?.state, ImEffectLedgerState.completed);
      expect(replayed?.state, ImEffectLedgerState.completed);
    });

    test('rejects a same-revision checkpoint with different contents',
        () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquire(store, nowMs: 10);
      const first = ImProjectionCheckpointRecord(
        ownerUserId: 'alice',
        scope: 'alice::c2c_bob',
        commitRevision: 4,
        lastJournalId: 'journal-4',
        coverageRevision: 1,
        watermarkRevision: 1,
        barrierRevision: 1,
        projectionVersion: 1,
        updatedAtMs: 10,
      );
      final inserted = await store.transaction((transaction) {
        return transaction.saveProjectionCheckpointIfCurrent(
          record: first,
          leaseOwnerId: lease.leaseOwnerId,
          fencingToken: lease.fencingToken,
          nowMs: 11,
        );
      });
      final conflict = await store.transaction((transaction) {
        return transaction.saveProjectionCheckpointIfCurrent(
          record: const ImProjectionCheckpointRecord(
            ownerUserId: 'alice',
            scope: 'alice::c2c_bob',
            commitRevision: 4,
            lastJournalId: 'journal-4',
            coverageRevision: 2,
            watermarkRevision: 1,
            barrierRevision: 1,
            projectionVersion: 1,
            updatedAtMs: 12,
          ),
          leaseOwnerId: lease.leaseOwnerId,
          fencingToken: lease.fencingToken,
          nowMs: 12,
        );
      });
      final stored = await store.transaction((transaction) {
        return transaction.findProjectionCheckpoint(
          ownerUserId: 'alice',
          scope: 'alice::c2c_bob',
        );
      });
      expect(inserted, isTrue);
      expect(conflict, isFalse);
      expect(stored?.coverageRevision, 1);
    });

    test('treats mismatched dispatch attempts as a recovery conflict',
        () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquire(store, nowMs: 10);
      final main = _mainOutbox().copyWith(
        state: ImOutboxState.dispatchIntent,
        dispatchAttemptId: 'attempt-main',
      );
      final copy = ImOutboxRecoveryRecord(
        ownerUserId: 'alice',
        operationId: 'operation-1',
        clientCorrelationId: 'corr-1',
        conversationId: 'c2c_bob',
        messageType: 1,
        recoveryRevision: 2,
        state: ImOutboxCopyState.dispatchIntent,
        dispatchAttemptId: 'attempt-copy',
        dispatchIntentAtMs: 12,
        payloadReferenceOrCiphertext: 'encrypted:payload-1',
        payloadHash: 'payload-hash',
        checksum: 'checksum-1',
        updatedAtMs: 12,
      );
      await store.transaction((transaction) async {
        await transaction.insertOutboxIfAbsent(main);
        await transaction.insertOutboxRecoveryIfAbsent(copy);
      });
      final assessment =
          await Im05Persistence(store: store).assessOutboxForDispatch(
        ownerUserId: 'alice',
        operationId: 'operation-1',
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 13,
      );
      expect(assessment.decision, ImOutboxDispatchDecision.recoveryConflict);
      expect(assessment.canDispatch, isFalse);
    });

    test('persists Journal, Checkpoint, Effect and Outbox in SQLite', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final owner = 'im05_sqlite_${DateTime.now().microsecondsSinceEpoch}';
      final localStore = ConversationLocalStore.instance;
      final store = ConversationLocalImIngressStore(owner: localStore);
      final persistence = Im05Persistence(store: store);
      try {
        final lease = await _acquire(store, owner: owner, nowMs: 10);
        const preparedJournal = ImCommitJournalRecord(
          ownerUserId: 'placeholder',
          journalId: 'journal-sqlite',
          eventNamespace: 'chat',
          eventId: 'event-sqlite',
          scope: 'placeholder::c2c_bob',
          commitRevision: 1,
          state: ImCommitJournalState.prepared,
          createdAtMs: 10,
          updatedAtMs: 10,
        );
        final journal = ImCommitJournalRecord(
          ownerUserId: owner,
          journalId: preparedJournal.journalId,
          eventNamespace: preparedJournal.eventNamespace,
          eventId: preparedJournal.eventId,
          scope: '$owner::c2c_bob',
          commitRevision: preparedJournal.commitRevision,
          state: preparedJournal.state,
          createdAtMs: preparedJournal.createdAtMs,
          updatedAtMs: preparedJournal.updatedAtMs,
        );
        final metadata = journal.copyWith(
          state: ImCommitJournalState.metadataCommitted,
        );
        expect(
          (await persistence.prepareJournal(
            record: journal,
            leaseOwnerId: lease.leaseOwnerId,
            fencingToken: lease.fencingToken,
            nowMs: 11,
          ))
              ?.state,
          ImCommitJournalState.prepared,
        );
        expect(
          (await persistence.commitMetadata(
            record: metadata,
            leaseOwnerId: lease.leaseOwnerId,
            fencingToken: lease.fencingToken,
            nowMs: 12,
          ))
              ?.state,
          ImCommitJournalState.metadataCommitted,
        );
        expect(
          (await persistence.publishProjection(
            journal: metadata,
            checkpoint: ImProjectionCheckpointRecord(
              ownerUserId: owner,
              scope: '$owner::c2c_bob',
              commitRevision: 1,
              lastJournalId: 'journal-sqlite',
              coverageRevision: 1,
              watermarkRevision: 1,
              barrierRevision: 1,
              projectionVersion: 1,
              updatedAtMs: 13,
            ),
            leaseOwnerId: lease.leaseOwnerId,
            fencingToken: lease.fencingToken,
            nowMs: 13,
          ))
              ?.state,
          ImCommitJournalState.projectionPublished,
        );

        final sqliteMain = ImOutboxRecord(
          operationId: 'operation-sqlite',
          ownerUserId: owner,
          conversationId: '$owner::c2c_bob',
          clientCorrelationId: 'corr-sqlite',
          messageType: 1,
          payloadReference: 'inlineEncryptedText:payload-sqlite',
          payloadHash: 'payload-hash-sqlite',
          contentChecksum: 'checksum-sqlite',
          state: ImOutboxState.prepared,
          createdAtMs: 13,
          updatedAtMs: 13,
        );
        final sqliteCopy = ImOutboxRecoveryRecord(
          ownerUserId: owner,
          operationId: 'operation-sqlite',
          clientCorrelationId: sqliteMain.clientCorrelationId,
          conversationId: sqliteMain.conversationId,
          messageType: sqliteMain.messageType,
          recoveryRevision: 1,
          state: ImOutboxCopyState.copyPrepared,
          payloadReferenceOrCiphertext: 'encrypted:payload-sqlite',
          payloadHash: sqliteMain.payloadHash,
          checksum: sqliteMain.contentChecksum!,
          updatedAtMs: 13,
        );
        expect(
          (await persistence.prepareOutbox(
            main: sqliteMain,
            recoveryCopy: sqliteCopy,
            leaseOwnerId: lease.leaseOwnerId,
            fencingToken: lease.fencingToken,
            nowMs: 14,
          ))
              .decision,
          ImOutboxDispatchDecision.ready,
        );
      } finally {
        await localStore.closeDatabaseForTest();
        final dbPath = p.join(
          await getDatabasesPath(),
          'conversation_local_v1.db',
        );
        final db = await openDatabase(dbPath, singleInstance: false);
        final batch = db.batch();
        for (final table in <String>[
          'message_commit_journal',
          'message_projection_checkpoint',
          'message_commit_effect',
          'message_outbox',
          'message_outbox_recovery_copy',
          'message_writer_lease',
        ]) {
          batch.delete(table, where: 'owner_user_id = ?', whereArgs: [owner]);
        }
        await batch.commit(noResult: true);
        await db.close();
      }
    });
  });
}

Future<ImWriterLease> _acquire(
  ImIngressStore store, {
  String owner = 'alice',
  String leaseOwnerId = 'core-old',
  required int nowMs,
  int ttlMs = 1000,
}) async {
  final lease = await ImWriterLeaseService(store: store).acquire(
    ownerUserId: owner,
    leaseOwnerId: leaseOwnerId,
    nowMs: nowMs,
    ttlMs: ttlMs,
  );
  return lease!;
}

ImOutboxRecord _mainOutbox() => const ImOutboxRecord(
      operationId: 'operation-1',
      ownerUserId: 'alice',
      conversationId: 'c2c_bob',
      clientCorrelationId: 'corr-1',
      messageType: 1,
      payloadReference: 'inlineEncryptedText:payload-1',
      payloadHash: 'payload-hash',
      contentChecksum: 'checksum-1',
      state: ImOutboxState.prepared,
      createdAtMs: 10,
      updatedAtMs: 10,
    );

ImOutboxRecoveryRecord _recoveryCopy() => const ImOutboxRecoveryRecord(
      ownerUserId: 'alice',
      operationId: 'operation-1',
      clientCorrelationId: 'corr-1',
      conversationId: 'c2c_bob',
      messageType: 1,
      recoveryRevision: 1,
      state: ImOutboxCopyState.copyPrepared,
      payloadReferenceOrCiphertext: 'encrypted:payload-1',
      payloadHash: 'payload-hash',
      checksum: 'checksum-1',
      updatedAtMs: 10,
    );
