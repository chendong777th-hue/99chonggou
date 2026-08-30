import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_contracts.dart';

enum ImRecoveryMode {
  sdkBoundaryReplay,
  sdkOverlapReplay,
  historyRequest,
  outboxPayload,
  managedMediaFile,
  commandArguments,
  ephemeralUi,
}

enum ImInboxStatus {
  prepared,
  processing,
  metadataCommitted,
  projectionPublished,
  completed,
}

class ImWriterLeaseRecord {
  const ImWriterLeaseRecord({
    required this.ownerUserId,
    required this.leaseOwnerId,
    required this.fencingToken,
    required this.acquiredAtMs,
    required this.expiresAtMs,
    required this.heartbeatAtMs,
  });

  final String ownerUserId;
  final String leaseOwnerId;
  final int fencingToken;
  final int acquiredAtMs;
  final int expiresAtMs;
  final int heartbeatAtMs;

  bool isExpiredAt(int nowMs) => expiresAtMs <= nowMs;
}

class ImInboxRecord {
  const ImInboxRecord({
    required this.event,
    required this.payloadHash,
    required this.recoveryMode,
    required this.recoveryRef,
    required this.status,
    this.committedAtMs,
    this.processingStartedAtMs,
  });

  final EventEnvelope<void> event;
  final String payloadHash;
  final ImRecoveryMode recoveryMode;
  final String recoveryRef;
  final ImInboxStatus status;
  final int? committedAtMs;
  final int? processingStartedAtMs;

  ImInboxRecord copyWith({
    ImInboxStatus? status,
    int? committedAtMs,
    int? processingStartedAtMs,
  }) {
    return ImInboxRecord(
      event: event,
      payloadHash: payloadHash,
      recoveryMode: recoveryMode,
      recoveryRef: recoveryRef,
      status: status ?? this.status,
      committedAtMs: committedAtMs ?? this.committedAtMs,
      processingStartedAtMs:
          processingStartedAtMs ?? this.processingStartedAtMs,
    );
  }
}

/// Persistence contract for the atomic IM ingress transaction.
///
/// The production implementation uses the existing conversation SQLite
/// database. A small in-memory implementation is included for deterministic
/// contract tests and does not participate in production state.
abstract interface class ImIngressStore {
  Future<T> transaction<T>(
    Future<T> Function(ImIngressTransaction transaction) action,
  );
}

abstract interface class ImIngressTransaction implements Im05Transaction {
  Future<ImInboxRecord?> findInbox({
    required String ownerUserId,
    required String eventNamespace,
    required String eventId,
  });

  Future<int> allocateAccountIngressSequence({
    required String ownerUserId,
    required int nowMs,
  });

  Future<int> allocateScopeIngressSequence({
    required String ownerUserId,
    required String scopeKey,
    required int nowMs,
  });

  Future<void> insertInbox(ImInboxRecord record);

  Future<List<ImInboxRecord>> listInboxForRecovery({
    required String ownerUserId,
    required int accountGeneration,
    int? domainGeneration,
    required int nowMs,
    required int processingTimeoutMs,
    required int limit,
  });

  Future<ImInboxRecord?> claimInboxForWriter({
    required String ownerUserId,
    required String eventNamespace,
    required String eventId,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
    bool allowStaleProcessing = false,
    int processingTimeoutMs = 30000,
  });

  Future<bool> advanceInboxStatusIfCurrent({
    required String ownerUserId,
    required String eventNamespace,
    required String eventId,
    required ImInboxStatus expectedStatus,
    required ImInboxStatus nextStatus,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
    int? committedAtMs,
  });

  Future<bool> insertWriterLeaseIfAbsent(ImWriterLeaseRecord record);

  @override
  Future<ImWriterLeaseRecord?> findWriterLease(String ownerUserId);

  Future<bool> replaceWriterLeaseIfCurrent({
    required String ownerUserId,
    required String expectedLeaseOwnerId,
    required int expectedFencingToken,
    required ImWriterLeaseRecord replacement,
  });

  Future<bool> deleteWriterLeaseIfCurrent({
    required String ownerUserId,
    required String leaseOwnerId,
    required int fencingToken,
  });
}

/// Adapter from the project's existing SQLite owner to the IM persistence
/// contract. It deliberately exposes only IM table operations.
class ConversationLocalImIngressStore implements ImIngressStore {
  ConversationLocalImIngressStore({ConversationLocalStore? owner})
      : _owner = owner ?? ConversationLocalStore.instance;

  final ConversationLocalStore _owner;

  @override
  Future<T> transaction<T>(
    Future<T> Function(ImIngressTransaction transaction) action,
  ) {
    return _owner.runImIngressTransaction<T>(
      (transaction) => action(_SqliteImIngressTransaction(transaction)),
    );
  }
}

class _SqliteImIngressTransaction implements ImIngressTransaction {
  _SqliteImIngressTransaction(this._db);

  final DatabaseExecutor _db;

  static const _inboxTable = 'message_event_inbox';
  static const _leaseTable = 'message_writer_lease';
  static const _counterTable = 'message_ingress_counter';
  static const _journalTable = 'message_commit_journal';
  static const _checkpointTable = 'message_projection_checkpoint';
  static const _effectTable = 'message_commit_effect';
  static const _outboxTable = 'message_outbox';
  static const _outboxRecoveryTable = 'message_outbox_recovery_copy';

  @override
  Future<ImInboxRecord?> findInbox({
    required String ownerUserId,
    required String eventNamespace,
    required String eventId,
  }) async {
    final rows = await _db.query(
      _inboxTable,
      where: 'owner_user_id = ? AND event_namespace = ? AND event_id = ?',
      whereArgs: <Object?>[ownerUserId, eventNamespace, eventId],
      limit: 1,
    );
    return rows.isEmpty ? null : imInboxRecordFromStorageMap(rows.first);
  }

  @override
  Future<int> allocateAccountIngressSequence({
    required String ownerUserId,
    required int nowMs,
  }) {
    return _allocateSequence(
      ownerUserId: ownerUserId,
      scopeKey: '',
      nowMs: nowMs,
    );
  }

  @override
  Future<int> allocateScopeIngressSequence({
    required String ownerUserId,
    required String scopeKey,
    required int nowMs,
  }) {
    return _allocateSequence(
      ownerUserId: ownerUserId,
      scopeKey: scopeKey,
      nowMs: nowMs,
    );
  }

  Future<int> _allocateSequence({
    required String ownerUserId,
    required String scopeKey,
    required int nowMs,
  }) async {
    final rows = await _db.query(
      _counterTable,
      columns: <String>['next_sequence'],
      where: 'owner_user_id = ? AND scope_key = ?',
      whereArgs: <Object?>[ownerUserId, scopeKey],
      limit: 1,
    );
    final current = rows.isEmpty ? 0 : _asInt(rows.first['next_sequence']);
    final next = current + 1;
    if (rows.isEmpty) {
      await _db.insert(_counterTable, <String, Object?>{
        'owner_user_id': ownerUserId,
        'scope_key': scopeKey,
        'next_sequence': next,
        'updated_at': nowMs,
      });
    } else {
      await _db.update(
        _counterTable,
        <String, Object?>{'next_sequence': next, 'updated_at': nowMs},
        where: 'owner_user_id = ? AND scope_key = ?',
        whereArgs: <Object?>[ownerUserId, scopeKey],
      );
    }
    return next;
  }

  @override
  Future<void> insertInbox(ImInboxRecord record) async {
    await _db.insert(_inboxTable, imInboxRecordToStorageMap(record));
  }

  @override
  Future<List<ImInboxRecord>> listInboxForRecovery({
    required String ownerUserId,
    required int accountGeneration,
    int? domainGeneration,
    required int nowMs,
    required int processingTimeoutMs,
    required int limit,
  }) async {
    final staleBefore = nowMs - processingTimeoutMs;
    final rows = await _db.query(
      _inboxTable,
      where: [
        'owner_user_id = ?',
        'account_generation = ?',
        if (domainGeneration != null) 'domain_generation = ?',
        '''(
          status IN (?, ?, ?) OR
          (status = ? AND
            (processing_started_at IS NULL OR processing_started_at <= ?))
        )''',
      ].join(' AND '),
      whereArgs: <Object?>[
        ownerUserId,
        accountGeneration,
        if (domainGeneration != null) domainGeneration,
        ImInboxStatus.prepared.name,
        ImInboxStatus.metadataCommitted.name,
        ImInboxStatus.projectionPublished.name,
        ImInboxStatus.processing.name,
        staleBefore,
      ],
      orderBy: 'account_ingress_sequence ASC',
      limit: limit,
    );
    return rows.map(imInboxRecordFromStorageMap).toList(growable: false);
  }

  @override
  Future<ImInboxRecord?> claimInboxForWriter({
    required String ownerUserId,
    required String eventNamespace,
    required String eventId,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
    bool allowStaleProcessing = false,
    int processingTimeoutMs = 30000,
  }) async {
    if (!await _hasCurrentLease(
        ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
      return null;
    }
    final current = await findInbox(
      ownerUserId: ownerUserId,
      eventNamespace: eventNamespace,
      eventId: eventId,
    );
    if (current == null) {
      return current;
    }
    if (current.status == ImInboxStatus.processing) {
      if (!allowStaleProcessing ||
          (current.processingStartedAtMs != null &&
              current.processingStartedAtMs! > nowMs - processingTimeoutMs)) {
        return null;
      }
      final changed = await _db.update(
        _inboxTable,
        <String, Object?>{'processing_started_at': nowMs},
        where: '''owner_user_id = ? AND event_namespace = ? AND event_id = ?
          AND status = ? AND
          (processing_started_at IS NULL OR processing_started_at <= ?)''',
        whereArgs: <Object?>[
          ownerUserId,
          eventNamespace,
          eventId,
          ImInboxStatus.processing.name,
          nowMs - processingTimeoutMs,
        ],
      );
      return changed == 1
          ? current.copyWith(processingStartedAtMs: nowMs)
          : null;
    }
    if (current.status != ImInboxStatus.prepared) {
      return current;
    }
    final changed = await _db.update(
      _inboxTable,
      <String, Object?>{
        'status': ImInboxStatus.processing.name,
        'processing_started_at': nowMs,
      },
      where:
          'owner_user_id = ? AND event_namespace = ? AND event_id = ? AND status = ?',
      whereArgs: <Object?>[
        ownerUserId,
        eventNamespace,
        eventId,
        ImInboxStatus.prepared.name,
      ],
    );
    if (changed != 1) return null;
    return current.copyWith(
      status: ImInboxStatus.processing,
      processingStartedAtMs: nowMs,
    );
  }

  @override
  Future<bool> advanceInboxStatusIfCurrent({
    required String ownerUserId,
    required String eventNamespace,
    required String eventId,
    required ImInboxStatus expectedStatus,
    required ImInboxStatus nextStatus,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
    int? committedAtMs,
  }) async {
    if (!isValidImInboxTransition(expectedStatus, nextStatus) ||
        !await _hasCurrentLease(
            ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
      return false;
    }
    final changed = await _db.update(
      _inboxTable,
      <String, Object?>{
        'status': nextStatus.name,
        if (committedAtMs != null) 'committed_at': committedAtMs,
      },
      where:
          'owner_user_id = ? AND event_namespace = ? AND event_id = ? AND status = ?',
      whereArgs: <Object?>[
        ownerUserId,
        eventNamespace,
        eventId,
        expectedStatus.name,
      ],
    );
    return changed == 1;
  }

  Future<bool> _hasCurrentLease(
    String ownerUserId,
    String leaseOwnerId,
    int fencingToken,
    int nowMs,
  ) async {
    final rows = await _db.query(
      _leaseTable,
      columns: <String>['lease_owner_id', 'fencing_token', 'expires_at'],
      where: 'owner_user_id = ?',
      whereArgs: <Object?>[ownerUserId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final row = rows.single;
    return row['lease_owner_id'] == leaseOwnerId &&
        _asInt(row['fencing_token']) == fencingToken &&
        _asInt(row['expires_at']) > nowMs;
  }

  @override
  Future<bool> insertWriterLeaseIfAbsent(ImWriterLeaseRecord record) async {
    final inserted = await _db.insert(
      _leaseTable,
      imWriterLeaseToStorageMap(record),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return inserted > 0;
  }

  @override
  Future<ImWriterLeaseRecord?> findWriterLease(String ownerUserId) async {
    final rows = await _db.query(
      _leaseTable,
      where: 'owner_user_id = ?',
      whereArgs: <Object?>[ownerUserId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return imWriterLeaseFromStorageMap(rows.first);
  }

  @override
  Future<bool> replaceWriterLeaseIfCurrent({
    required String ownerUserId,
    required String expectedLeaseOwnerId,
    required int expectedFencingToken,
    required ImWriterLeaseRecord replacement,
  }) async {
    final changed = await _db.update(
      _leaseTable,
      imWriterLeaseToStorageMap(replacement),
      where: 'owner_user_id = ? AND lease_owner_id = ? AND fencing_token = ?',
      whereArgs: <Object?>[
        ownerUserId,
        expectedLeaseOwnerId,
        expectedFencingToken,
      ],
    );
    return changed == 1;
  }

  @override
  Future<bool> deleteWriterLeaseIfCurrent({
    required String ownerUserId,
    required String leaseOwnerId,
    required int fencingToken,
  }) async {
    final changed = await _db.update(
      _leaseTable,
      <String, Object?>{
        'expires_at': 0,
        'heartbeat_at': 0,
      },
      where: 'owner_user_id = ? AND lease_owner_id = ? AND fencing_token = ?',
      whereArgs: <Object?>[ownerUserId, leaseOwnerId, fencingToken],
    );
    return changed == 1;
  }

  @override
  Future<ImCommitJournalRecord?> findCommitJournal({
    required String ownerUserId,
    required String journalId,
  }) async {
    final rows = await _db.query(
      _journalTable,
      where: 'owner_user_id = ? AND journal_id = ?',
      whereArgs: <Object?>[ownerUserId, journalId],
      limit: 1,
    );
    return rows.isEmpty ? null : imCommitJournalFromStorageMap(rows.first);
  }

  @override
  Future<bool> insertCommitJournalIfAbsent(ImCommitJournalRecord record) async {
    final inserted = await _db.insert(
      _journalTable,
      imCommitJournalToStorageMap(record),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return inserted > 0;
  }

  @override
  Future<bool> updateCommitJournalIfCurrent({
    required ImCommitJournalRecord record,
    required ImCommitJournalState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) async {
    if (!isValidImCommitJournalTransition(expectedState, record.state) ||
        !await _hasCurrentLease(
            record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
      return false;
    }
    final changed = await _db.update(
      _journalTable,
      imCommitJournalToStorageMap(record),
      where: 'owner_user_id = ? AND journal_id = ? AND state = ?',
      whereArgs: <Object?>[
        record.ownerUserId,
        record.journalId,
        expectedState.name,
      ],
    );
    return changed == 1;
  }

  @override
  Future<ImProjectionCheckpointRecord?> findProjectionCheckpoint({
    required String ownerUserId,
    required String scope,
  }) async {
    final rows = await _db.query(
      _checkpointTable,
      where: 'owner_user_id = ? AND scope = ?',
      whereArgs: <Object?>[ownerUserId, scope],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : imProjectionCheckpointFromStorageMap(rows.first);
  }

  @override
  Future<bool> saveProjectionCheckpointIfCurrent({
    required ImProjectionCheckpointRecord record,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) async {
    if (!await _hasCurrentLease(
        record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
      return false;
    }
    final current = await findProjectionCheckpoint(
      ownerUserId: record.ownerUserId,
      scope: record.scope,
    );
    if (current != null && record.commitRevision < current.commitRevision) {
      return false;
    }
    if (current == null) {
      final inserted = await _db.insert(
        _checkpointTable,
        imProjectionCheckpointToStorageMap(record),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return inserted > 0;
    }
    if (current.commitRevision == record.commitRevision &&
        _sameCheckpoint(current, record)) {
      return true;
    }
    if (record.commitRevision <= current.commitRevision) {
      return false;
    }
    final changed = await _db.update(
      _checkpointTable,
      imProjectionCheckpointToStorageMap(record),
      where: 'owner_user_id = ? AND scope = ? AND commit_revision = ?',
      whereArgs: <Object?>[
        record.ownerUserId,
        record.scope,
        current.commitRevision,
      ],
    );
    return changed == 1;
  }

  @override
  Future<ImEffectLedgerRecord?> findEffect({
    required String ownerUserId,
    required String effectId,
  }) async {
    final rows = await _db.query(
      _effectTable,
      where: 'owner_user_id = ? AND effect_id = ?',
      whereArgs: <Object?>[ownerUserId, effectId],
      limit: 1,
    );
    return rows.isEmpty ? null : imEffectLedgerFromStorageMap(rows.first);
  }

  @override
  Future<bool> insertEffectIfAbsent(ImEffectLedgerRecord record) async {
    final inserted = await _db.insert(
      _effectTable,
      imEffectLedgerToStorageMap(record),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return inserted > 0;
  }

  @override
  Future<bool> updateEffectIfCurrent({
    required ImEffectLedgerRecord record,
    required ImEffectLedgerState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) async {
    if (!isValidImEffectTransition(expectedState, record.state) ||
        !await _hasCurrentLease(
            record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
      return false;
    }
    final changed = await _db.update(
      _effectTable,
      imEffectLedgerToStorageMap(record),
      where: 'owner_user_id = ? AND effect_id = ? AND state = ?',
      whereArgs: <Object?>[
        record.ownerUserId,
        record.effectId,
        expectedState.name,
      ],
    );
    return changed == 1;
  }

  @override
  Future<ImOutboxRecord?> findOutbox({
    required String ownerUserId,
    required String operationId,
  }) async {
    final rows = await _db.query(
      _outboxTable,
      where: 'owner_user_id = ? AND operation_id = ?',
      whereArgs: <Object?>[ownerUserId, operationId],
      limit: 1,
    );
    return rows.isEmpty ? null : imOutboxFromStorageMap(rows.first);
  }

  @override
  Future<bool> insertOutboxIfAbsent(ImOutboxRecord record) async {
    final inserted = await _db.insert(
      _outboxTable,
      imOutboxToStorageMap(record),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return inserted > 0;
  }

  @override
  Future<bool> updateOutboxIfCurrent({
    required ImOutboxRecord record,
    required ImOutboxState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) async {
    if (!isValidImOutboxTransition(expectedState, record.state) ||
        !await _hasCurrentLease(
            record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
      return false;
    }
    final changed = await _db.update(
      _outboxTable,
      imOutboxToStorageMap(record),
      where: 'owner_user_id = ? AND operation_id = ? AND state = ?',
      whereArgs: <Object?>[
        record.ownerUserId,
        record.operationId,
        expectedState.name,
      ],
    );
    return changed == 1;
  }

  @override
  Future<ImOutboxRecoveryRecord?> findOutboxRecovery({
    required String ownerUserId,
    required String operationId,
  }) async {
    final rows = await _db.query(
      _outboxRecoveryTable,
      where: 'owner_user_id = ? AND operation_id = ?',
      whereArgs: <Object?>[ownerUserId, operationId],
      limit: 1,
    );
    return rows.isEmpty ? null : imOutboxRecoveryFromStorageMap(rows.first);
  }

  @override
  Future<bool> insertOutboxRecoveryIfAbsent(
    ImOutboxRecoveryRecord record,
  ) async {
    final inserted = await _db.insert(
      _outboxRecoveryTable,
      imOutboxRecoveryToStorageMap(record),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return inserted > 0;
  }

  @override
  Future<bool> updateOutboxRecoveryIfCurrent({
    required ImOutboxRecoveryRecord record,
    required ImOutboxCopyState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) async {
    if (!isValidImOutboxRecoveryTransition(expectedState, record.state) ||
        !await _hasCurrentLease(
            record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
      return false;
    }
    final changed = await _db.update(
      _outboxRecoveryTable,
      imOutboxRecoveryToStorageMap(record),
      where: 'owner_user_id = ? AND operation_id = ? AND state = ?',
      whereArgs: <Object?>[
        record.ownerUserId,
        record.operationId,
        expectedState.name,
      ],
    );
    return changed == 1;
  }
}

class InMemoryImIngressStore implements ImIngressStore {
  final Map<String, ImInboxRecord> inbox = <String, ImInboxRecord>{};
  final Map<String, int> counters = <String, int>{};
  final Map<String, ImWriterLeaseRecord> leases =
      <String, ImWriterLeaseRecord>{};
  final Map<String, ImCommitJournalRecord> journals =
      <String, ImCommitJournalRecord>{};
  final Map<String, ImProjectionCheckpointRecord> checkpoints =
      <String, ImProjectionCheckpointRecord>{};
  final Map<String, ImEffectLedgerRecord> effects =
      <String, ImEffectLedgerRecord>{};
  final Map<String, ImOutboxRecord> outboxes = <String, ImOutboxRecord>{};
  final Map<String, ImOutboxRecoveryRecord> outboxRecoveryCopies =
      <String, ImOutboxRecoveryRecord>{};
  Future<void> _tail = Future<void>.value();

  @override
  Future<T> transaction<T>(
    Future<T> Function(ImIngressTransaction transaction) action,
  ) {
    final next = _tail.then<T>(
      (_) => action(_MemoryImIngressTransaction(this)),
    );
    _tail = next.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    return next;
  }
}

class _MemoryImIngressTransaction implements ImIngressTransaction {
  _MemoryImIngressTransaction(this._store);

  final InMemoryImIngressStore _store;

  @override
  Future<ImInboxRecord?> findInbox({
    required String ownerUserId,
    required String eventNamespace,
    required String eventId,
  }) async {
    return _store.inbox['$ownerUserId|$eventNamespace|$eventId'];
  }

  @override
  Future<int> allocateAccountIngressSequence({
    required String ownerUserId,
    required int nowMs,
  }) {
    return _allocate('$ownerUserId|');
  }

  @override
  Future<int> allocateScopeIngressSequence({
    required String ownerUserId,
    required String scopeKey,
    required int nowMs,
  }) {
    return _allocate('$ownerUserId|$scopeKey');
  }

  Future<int> _allocate(String key) async {
    final next = (_store.counters[key] ?? 0) + 1;
    _store.counters[key] = next;
    return next;
  }

  @override
  Future<void> insertInbox(ImInboxRecord record) async {
    _store.inbox[record.event.inboxKey] = record;
  }

  @override
  Future<List<ImInboxRecord>> listInboxForRecovery({
    required String ownerUserId,
    required int accountGeneration,
    int? domainGeneration,
    required int nowMs,
    required int processingTimeoutMs,
    required int limit,
  }) async {
    final staleBefore = nowMs - processingTimeoutMs;
    final records = _store.inbox.values.where((record) {
      final event = record.event;
      if (event.ownerUserId != ownerUserId ||
          event.accountGeneration != accountGeneration ||
          (domainGeneration != null &&
              event.domainGeneration != domainGeneration)) {
        return false;
      }
      if (record.status == ImInboxStatus.prepared ||
          record.status == ImInboxStatus.metadataCommitted ||
          record.status == ImInboxStatus.projectionPublished) {
        return true;
      }
      return record.status == ImInboxStatus.processing &&
          (record.processingStartedAtMs == null ||
              record.processingStartedAtMs! <= staleBefore);
    }).toList()
      ..sort(
        (left, right) => left.event.accountIngressSequence.compareTo(
          right.event.accountIngressSequence,
        ),
      );
    return records.take(limit).toList(growable: false);
  }

  @override
  Future<ImInboxRecord?> claimInboxForWriter({
    required String ownerUserId,
    required String eventNamespace,
    required String eventId,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
    bool allowStaleProcessing = false,
    int processingTimeoutMs = 30000,
  }) async {
    final lease = _store.leases[ownerUserId];
    if (lease == null ||
        lease.leaseOwnerId != leaseOwnerId ||
        lease.fencingToken != fencingToken ||
        lease.isExpiredAt(nowMs)) {
      return null;
    }
    final key = '$ownerUserId|$eventNamespace|$eventId';
    final current = _store.inbox[key];
    if (current == null) {
      return current;
    }
    if (current.status == ImInboxStatus.processing) {
      if (!allowStaleProcessing ||
          (current.processingStartedAtMs != null &&
              current.processingStartedAtMs! > nowMs - processingTimeoutMs)) {
        return null;
      }
      final claimed = current.copyWith(processingStartedAtMs: nowMs);
      _store.inbox[key] = claimed;
      return claimed;
    }
    if (current.status != ImInboxStatus.prepared) {
      return current;
    }
    final claimed = current.copyWith(
      status: ImInboxStatus.processing,
      processingStartedAtMs: nowMs,
    );
    _store.inbox[key] = claimed;
    return claimed;
  }

  @override
  Future<bool> advanceInboxStatusIfCurrent({
    required String ownerUserId,
    required String eventNamespace,
    required String eventId,
    required ImInboxStatus expectedStatus,
    required ImInboxStatus nextStatus,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
    int? committedAtMs,
  }) async {
    final lease = _store.leases[ownerUserId];
    if (!isValidImInboxTransition(expectedStatus, nextStatus) ||
        lease == null ||
        lease.leaseOwnerId != leaseOwnerId ||
        lease.fencingToken != fencingToken ||
        lease.isExpiredAt(nowMs)) {
      return false;
    }
    final key = '$ownerUserId|$eventNamespace|$eventId';
    final current = _store.inbox[key];
    if (current == null || current.status != expectedStatus) return false;
    _store.inbox[key] = current.copyWith(
      status: nextStatus,
      committedAtMs: committedAtMs,
    );
    return true;
  }

  @override
  Future<bool> insertWriterLeaseIfAbsent(ImWriterLeaseRecord record) async {
    if (_store.leases.containsKey(record.ownerUserId)) return false;
    _store.leases[record.ownerUserId] = record;
    return true;
  }

  @override
  Future<ImWriterLeaseRecord?> findWriterLease(String ownerUserId) async {
    return _store.leases[ownerUserId];
  }

  @override
  Future<bool> replaceWriterLeaseIfCurrent({
    required String ownerUserId,
    required String expectedLeaseOwnerId,
    required int expectedFencingToken,
    required ImWriterLeaseRecord replacement,
  }) async {
    final current = _store.leases[ownerUserId];
    if (current == null ||
        current.leaseOwnerId != expectedLeaseOwnerId ||
        current.fencingToken != expectedFencingToken) {
      return false;
    }
    _store.leases[ownerUserId] = replacement;
    return true;
  }

  @override
  Future<bool> deleteWriterLeaseIfCurrent({
    required String ownerUserId,
    required String leaseOwnerId,
    required int fencingToken,
  }) async {
    final current = _store.leases[ownerUserId];
    if (current == null ||
        current.leaseOwnerId != leaseOwnerId ||
        current.fencingToken != fencingToken) {
      return false;
    }
    _store.leases[ownerUserId] = ImWriterLeaseRecord(
      ownerUserId: current.ownerUserId,
      leaseOwnerId: current.leaseOwnerId,
      fencingToken: current.fencingToken,
      acquiredAtMs: current.acquiredAtMs,
      expiresAtMs: 0,
      heartbeatAtMs: 0,
    );
    return true;
  }

  @override
  Future<ImCommitJournalRecord?> findCommitJournal({
    required String ownerUserId,
    required String journalId,
  }) async {
    return _store.journals['$ownerUserId|$journalId'];
  }

  @override
  Future<bool> insertCommitJournalIfAbsent(ImCommitJournalRecord record) async {
    final key = '${record.ownerUserId}|${record.journalId}';
    if (_store.journals.containsKey(key)) return false;
    final duplicate = _store.journals.values.any(
      (current) =>
          current.ownerUserId == record.ownerUserId &&
          current.eventNamespace == record.eventNamespace &&
          current.eventId == record.eventId,
    );
    if (duplicate) return false;
    _store.journals[key] = record;
    return true;
  }

  @override
  Future<bool> updateCommitJournalIfCurrent({
    required ImCommitJournalRecord record,
    required ImCommitJournalState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) async {
    if (!isValidImCommitJournalTransition(expectedState, record.state) ||
        !await _hasCurrentLease(
            record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
      return false;
    }
    final key = '${record.ownerUserId}|${record.journalId}';
    final current = _store.journals[key];
    if (current == null || current.state != expectedState) return false;
    _store.journals[key] = record;
    return true;
  }

  @override
  Future<ImProjectionCheckpointRecord?> findProjectionCheckpoint({
    required String ownerUserId,
    required String scope,
  }) async {
    return _store.checkpoints['$ownerUserId|$scope'];
  }

  @override
  Future<bool> saveProjectionCheckpointIfCurrent({
    required ImProjectionCheckpointRecord record,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) async {
    if (!await _hasCurrentLease(
        record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
      return false;
    }
    final key = '${record.ownerUserId}|${record.scope}';
    final current = _store.checkpoints[key];
    if (current != null && record.commitRevision < current.commitRevision) {
      return false;
    }
    if (current != null &&
        current.commitRevision == record.commitRevision &&
        _sameCheckpoint(current, record)) {
      return true;
    }
    if (current != null && record.commitRevision <= current.commitRevision) {
      return false;
    }
    _store.checkpoints[key] = record;
    return true;
  }

  @override
  Future<ImEffectLedgerRecord?> findEffect({
    required String ownerUserId,
    required String effectId,
  }) async {
    return _store.effects['$ownerUserId|$effectId'];
  }

  @override
  Future<bool> insertEffectIfAbsent(ImEffectLedgerRecord record) async {
    final key = '${record.ownerUserId}|${record.effectId}';
    if (_store.effects.containsKey(key)) return false;
    _store.effects[key] = record;
    return true;
  }

  @override
  Future<bool> updateEffectIfCurrent({
    required ImEffectLedgerRecord record,
    required ImEffectLedgerState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) async {
    if (!isValidImEffectTransition(expectedState, record.state) ||
        !await _hasCurrentLease(
            record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
      return false;
    }
    final key = '${record.ownerUserId}|${record.effectId}';
    final current = _store.effects[key];
    if (current == null || current.state != expectedState) return false;
    _store.effects[key] = record;
    return true;
  }

  @override
  Future<ImOutboxRecord?> findOutbox({
    required String ownerUserId,
    required String operationId,
  }) async {
    final record = _store.outboxes[operationId];
    return record?.ownerUserId == ownerUserId ? record : null;
  }

  @override
  Future<bool> insertOutboxIfAbsent(ImOutboxRecord record) async {
    if (_store.outboxes.containsKey(record.operationId)) return false;
    _store.outboxes[record.operationId] = record;
    return true;
  }

  @override
  Future<bool> updateOutboxIfCurrent({
    required ImOutboxRecord record,
    required ImOutboxState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) async {
    if (!isValidImOutboxTransition(expectedState, record.state) ||
        !await _hasCurrentLease(
            record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
      return false;
    }
    final current = _store.outboxes[record.operationId];
    if (current == null ||
        current.ownerUserId != record.ownerUserId ||
        current.state != expectedState) {
      return false;
    }
    _store.outboxes[record.operationId] = record;
    return true;
  }

  @override
  Future<ImOutboxRecoveryRecord?> findOutboxRecovery({
    required String ownerUserId,
    required String operationId,
  }) async {
    final record = _store.outboxRecoveryCopies[operationId];
    return record?.ownerUserId == ownerUserId ? record : null;
  }

  @override
  Future<bool> insertOutboxRecoveryIfAbsent(
    ImOutboxRecoveryRecord record,
  ) async {
    if (_store.outboxRecoveryCopies.containsKey(record.operationId)) {
      return false;
    }
    _store.outboxRecoveryCopies[record.operationId] = record;
    return true;
  }

  @override
  Future<bool> updateOutboxRecoveryIfCurrent({
    required ImOutboxRecoveryRecord record,
    required ImOutboxCopyState expectedState,
    required String leaseOwnerId,
    required int fencingToken,
    required int nowMs,
  }) async {
    if (!isValidImOutboxRecoveryTransition(expectedState, record.state) ||
        !await _hasCurrentLease(
            record.ownerUserId, leaseOwnerId, fencingToken, nowMs)) {
      return false;
    }
    final current = _store.outboxRecoveryCopies[record.operationId];
    if (current == null || current.state != expectedState) return false;
    _store.outboxRecoveryCopies[record.operationId] = record;
    return true;
  }

  Future<bool> _hasCurrentLease(
    String ownerUserId,
    String leaseOwnerId,
    int fencingToken,
    int nowMs,
  ) async {
    final lease = _store.leases[ownerUserId];
    return lease != null &&
        lease.leaseOwnerId == leaseOwnerId &&
        lease.fencingToken == fencingToken &&
        !lease.isExpiredAt(nowMs);
  }
}

Map<String, Object?> imInboxRecordToStorageMap(ImInboxRecord record) {
  final event = record.event;
  return <String, Object?>{
    'owner_user_id': event.ownerUserId,
    'event_id': event.eventId,
    'event_namespace': event.eventNamespace,
    'conversation_id': event.scope?.canonicalConversationId ?? '',
    'event_kind': event.kind.name,
    'operation_id': event.operationId ?? '',
    'account_generation': event.accountGeneration,
    'domain_generation': event.domainGeneration,
    'source': event.source.name,
    'authority': event.authority.name,
    'view_instance_id': event.viewInstanceId ?? '',
    'surface_id': event.surfaceId ?? '',
    'view_session_generation': event.viewSessionGeneration,
    'history_request_generation': event.historyRequestGeneration,
    'send_operation_generation': event.sendOperationGeneration,
    'clear_epoch': event.clearEpoch,
    'account_ingress_sequence': event.accountIngressSequence,
    'scope_ingress_sequence': event.scopeIngressSequence,
    'provider_sequence': event.providerSequence,
    'source_revision': event.sourceRevision,
    'membership_revision': event.membershipRevision,
    'payload_hash': record.payloadHash,
    'recovery_mode': record.recoveryMode.name,
    'recovery_ref': record.recoveryRef,
    'status': record.status.name,
    'observed_at': event.observedAtMs,
    'committed_at': record.committedAtMs,
    'processing_started_at': record.processingStartedAtMs,
  };
}

ImInboxRecord imInboxRecordFromStorageMap(Map<String, Object?> row) {
  final owner = row['owner_user_id']?.toString() ?? '';
  final rawConversation = row['conversation_id']?.toString() ?? '';
  final scope = rawConversation.isEmpty
      ? null
      : AccountScopedConversationKey(
          ownerUserId: owner,
          conversationType: rawConversation.startsWith('group_')
              ? ImConversationType.group
              : ImConversationType.c2c,
          conversationId: rawConversation,
        );
  final event = EventEnvelope<void>(
    eventId: row['event_id']?.toString() ?? '',
    eventNamespace: row['event_namespace']?.toString() ?? '',
    kind: _enumByName(ImEventKind.values, row['event_kind']?.toString()) ??
        ImEventKind.notification,
    scope: scope,
    ownerUserId: owner,
    accountGeneration: _asInt(row['account_generation']),
    domainGeneration: _asInt(row['domain_generation']),
    viewInstanceId: _optional(row['view_instance_id']),
    surfaceId: _optional(row['surface_id']),
    viewSessionGeneration: _asOptionalInt(row['view_session_generation']),
    historyRequestGeneration: _asOptionalInt(row['history_request_generation']),
    sendOperationGeneration: _asOptionalInt(row['send_operation_generation']),
    clearEpoch: _asInt(row['clear_epoch']),
    accountIngressSequence: _asInt(row['account_ingress_sequence']),
    scopeIngressSequence: _asInt(row['scope_ingress_sequence']),
    providerSequence: _asOptionalInt(row['provider_sequence']),
    sourceRevision: _asOptionalInt(row['source_revision']),
    membershipRevision: _asOptionalInt(row['membership_revision']),
    operationId: _optional(row['operation_id']),
    source: _enumByName(ImEventSource.values, row['source']?.toString()) ??
        ImEventSource.system,
    authority:
        _enumByName(ImEventAuthority.values, row['authority']?.toString()) ??
            ImEventAuthority.unknown,
    observedAtMs: _asInt(row['observed_at']),
  );
  return ImInboxRecord(
    event: event,
    payloadHash: row['payload_hash']?.toString() ?? '',
    recoveryMode:
        _enumByName(ImRecoveryMode.values, row['recovery_mode']?.toString()) ??
            ImRecoveryMode.commandArguments,
    recoveryRef: row['recovery_ref']?.toString() ?? '',
    status: _enumByName(ImInboxStatus.values, row['status']?.toString()) ??
        ImInboxStatus.prepared,
    committedAtMs: _asOptionalInt(row['committed_at']),
    processingStartedAtMs: _asOptionalInt(row['processing_started_at']),
  );
}

Map<String, Object?> imWriterLeaseToStorageMap(ImWriterLeaseRecord record) =>
    <String, Object?>{
      'owner_user_id': record.ownerUserId,
      'lease_owner_id': record.leaseOwnerId,
      'fencing_token': record.fencingToken,
      'acquired_at': record.acquiredAtMs,
      'expires_at': record.expiresAtMs,
      'heartbeat_at': record.heartbeatAtMs,
    };

ImWriterLeaseRecord imWriterLeaseFromStorageMap(Map<String, Object?> row) {
  return ImWriterLeaseRecord(
    ownerUserId: row['owner_user_id']?.toString() ?? '',
    leaseOwnerId: row['lease_owner_id']?.toString() ?? '',
    fencingToken: _asInt(row['fencing_token']),
    acquiredAtMs: _asInt(row['acquired_at']),
    expiresAtMs: _asInt(row['expires_at']),
    heartbeatAtMs: _asInt(row['heartbeat_at']),
  );
}

bool isValidImInboxTransition(ImInboxStatus expected, ImInboxStatus next) {
  return (expected == ImInboxStatus.processing &&
          next == ImInboxStatus.metadataCommitted) ||
      (expected == ImInboxStatus.metadataCommitted &&
          next == ImInboxStatus.projectionPublished) ||
      (expected == ImInboxStatus.projectionPublished &&
          next == ImInboxStatus.completed);
}

bool _sameCheckpoint(
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

int _asInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

int? _asOptionalInt(Object? value) {
  if (value == null) return null;
  return int.tryParse('$value');
}

String? _optional(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

T? _enumByName<T extends Enum>(Iterable<T> values, String? raw) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}
