import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_coverage.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class MessageHistoryCoverageStore implements MessageHistoryCoverageRepository {
  MessageHistoryCoverageStore._();

  static final MessageHistoryCoverageStore instance =
      MessageHistoryCoverageStore._();

  static const _dbName = 'message_history_coverage_v1.db';
  static const _coverageTable = 'message_history_coverage';
  static const _holeTable = 'message_history_holes';
  static const _rangeTable = 'message_history_coverage_ranges';
  static const _pageTable = 'message_history_coverage_pages';

  Database? _db;
  Future<Database>? _dbOpenInFlight;
  bool _factoryReady = false;
  final Map<String, Map<String, MessageHistoryCoverage>> _memoryByOwner =
      <String, Map<String, MessageHistoryCoverage>>{};

  @visibleForTesting
  String? debugOwnerUserId;

  @visibleForTesting
  String? debugDatabasePath;

  bool get _useMemoryOnly => kIsWeb;

  String currentOwnerUserId() {
    final cached =
        ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
    if (cached.isNotEmpty) {
      return cached;
    }
    try {
      return ChatIdFormat.rawUserUid(
        TIMUIKitCore.getInstance().loginInfo.userID,
      );
    } catch (_) {
      return '';
    }
  }

  String _resolveOwner([String? ownerUserId]) {
    final explicit = ChatIdFormat.rawUserUid(ownerUserId);
    if (explicit.isNotEmpty) {
      return explicit;
    }
    final debug = debugOwnerUserId?.trim() ?? '';
    if (debug.isNotEmpty) {
      return debug;
    }
    return currentOwnerUserId();
  }

  String _canonicalConversationID(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final lower = value.toLowerCase();
    if (lower.startsWith('c2c_')) {
      final peer = ChatIdFormat.rawUserUid(value.substring(4));
      return peer.isEmpty ? '' : 'c2c_$peer';
    }
    if (lower.startsWith('group_')) {
      final group = ChatIdFormat.canonicalGroupStorageId(value.substring(6));
      return group.isEmpty ? '' : 'group_$group';
    }
    if (value.toUpperCase().contains('TGS#')) {
      final group = ChatIdFormat.canonicalGroupStorageId(value);
      return group.isEmpty ? '' : 'group_$group';
    }
    return value;
  }

  Map<String, MessageHistoryCoverage> _memoryForOwner(String owner) {
    return _memoryByOwner.putIfAbsent(
      owner,
      () => <String, MessageHistoryCoverage>{},
    );
  }

  Future<void> _ensureDatabaseFactory() async {
    if (_factoryReady) return;
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _factoryReady = true;
  }

  Future<Database> _openDb() async {
    final existing = SqfliteLifecycleGuard.beforeOpen(_db);
    if (existing != null) return existing;
    final opening = _dbOpenInFlight;
    if (opening != null) return opening;
    final task = _openDbOnce();
    _dbOpenInFlight = task;
    try {
      return await task;
    } finally {
      if (identical(_dbOpenInFlight, task)) {
        _dbOpenInFlight = null;
      }
    }
  }

  Future<Database> _openDbOnce() async {
    await _ensureDatabaseFactory();
    final debugPath = debugDatabasePath?.trim() ?? '';
    final path = debugPath.isNotEmpty
        ? debugPath
        : p.join(await getDatabasesPath(), _dbName);
    final db = await openDatabase(
      path,
      version: 4,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE $_coverageTable (
            owner_user_id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            is_group INTEGER NOT NULL DEFAULT 0,
            clear_epoch INTEGER NOT NULL DEFAULT 0,
            coverage_revision INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'empty',
            local_oldest_msg_id TEXT,
            local_newest_msg_id TEXT,
            verified_oldest_msg_id TEXT,
            verified_newest_msg_id TEXT,
            verified_oldest_seq INTEGER,
            verified_newest_seq INTEGER,
            older_exhausted INTEGER NOT NULL DEFAULT 0,
            newer_has_more INTEGER NOT NULL DEFAULT 0,
            cloud_verified_at INTEGER NOT NULL DEFAULT 0,
            last_request_generation INTEGER NOT NULL DEFAULT 0,
            last_requested_source TEXT,
            last_actual_source TEXT,
            last_batch_kind TEXT,
            last_cursor_direction TEXT,
            last_cursor_msg_id TEXT,
            last_cursor_seq INTEGER,
            last_returned_oldest_msg_id TEXT,
            last_returned_newest_msg_id TEXT,
            last_returned_oldest_seq INTEGER,
            last_returned_newest_seq INTEGER,
            last_proof_kind TEXT NOT NULL DEFAULT 'none',
            last_cloud_response_proven INTEGER NOT NULL DEFAULT 0,
            continuation_pending INTEGER NOT NULL DEFAULT 0,
            continuation_direction TEXT,
            continuation_cursor_msg_id TEXT,
            continuation_cursor_seq INTEGER,
            updated_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (owner_user_id, conversation_id)
          )
        ''');
        await database.execute('''
          CREATE TABLE $_holeTable (
            owner_user_id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            hole_key TEXT NOT NULL,
            kind TEXT NOT NULL,
            status TEXT NOT NULL,
            start_seq INTEGER,
            end_seq INTEGER,
            older_msg_id TEXT,
            newer_msg_id TEXT,
            generation INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (owner_user_id, conversation_id, hole_key)
          )
        ''');
        await database.execute(
          'CREATE INDEX idx_history_holes_owner_conv '
          'ON $_holeTable(owner_user_id, conversation_id)',
        );
        await database.execute('''
          CREATE TABLE $_rangeTable (
            owner_user_id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            range_key TEXT NOT NULL,
            direction TEXT NOT NULL,
            oldest_msg_id TEXT,
            newest_msg_id TEXT,
            start_seq INTEGER,
            end_seq INTEGER,
            proof_kind TEXT NOT NULL,
            closed INTEGER NOT NULL DEFAULT 0,
            generation INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (owner_user_id, conversation_id, range_key)
          )
        ''');
        await database.execute('''
          CREATE TABLE $_pageTable (
            owner_user_id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            page_key TEXT NOT NULL,
            direction TEXT NOT NULL,
            cursor_msg_id TEXT,
            cursor_seq INTEGER,
            returned_oldest_msg_id TEXT,
            returned_newest_msg_id TEXT,
            returned_oldest_seq INTEGER,
            returned_newest_seq INTEGER,
            is_finished INTEGER NOT NULL DEFAULT 0,
            has_more INTEGER NOT NULL DEFAULT 0,
            proof_kind TEXT NOT NULL,
            generation INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (owner_user_id, conversation_id, page_key)
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          const additions = <String>[
            'ALTER TABLE message_history_coverage ADD COLUMN last_request_generation INTEGER NOT NULL DEFAULT 0',
            'ALTER TABLE message_history_coverage ADD COLUMN last_requested_source TEXT',
            'ALTER TABLE message_history_coverage ADD COLUMN last_actual_source TEXT',
            'ALTER TABLE message_history_coverage ADD COLUMN last_batch_kind TEXT',
            'ALTER TABLE message_history_coverage ADD COLUMN last_cursor_direction TEXT',
            'ALTER TABLE message_history_coverage ADD COLUMN last_cursor_msg_id TEXT',
            'ALTER TABLE message_history_coverage ADD COLUMN last_cursor_seq INTEGER',
            'ALTER TABLE message_history_coverage ADD COLUMN last_returned_oldest_msg_id TEXT',
            'ALTER TABLE message_history_coverage ADD COLUMN last_returned_newest_msg_id TEXT',
            'ALTER TABLE message_history_coverage ADD COLUMN last_returned_oldest_seq INTEGER',
            'ALTER TABLE message_history_coverage ADD COLUMN last_returned_newest_seq INTEGER',
            'ALTER TABLE message_history_coverage ADD COLUMN last_cloud_response_proven INTEGER NOT NULL DEFAULT 0',
          ];
          for (final statement in additions) {
            await database.execute(statement);
          }
        }
        if (oldVersion < 3) {
          const additions = <String>[
            'ALTER TABLE message_history_coverage ADD COLUMN continuation_pending INTEGER NOT NULL DEFAULT 0',
            'ALTER TABLE message_history_coverage ADD COLUMN continuation_direction TEXT',
            'ALTER TABLE message_history_coverage ADD COLUMN continuation_cursor_msg_id TEXT',
            'ALTER TABLE message_history_coverage ADD COLUMN continuation_cursor_seq INTEGER',
          ];
          for (final statement in additions) {
            await database.execute(statement);
          }
          await database.execute('''
            CREATE TABLE IF NOT EXISTS $_rangeTable (
              owner_user_id TEXT NOT NULL, conversation_id TEXT NOT NULL,
              range_key TEXT NOT NULL, direction TEXT NOT NULL,
              oldest_msg_id TEXT, newest_msg_id TEXT, start_seq INTEGER,
              end_seq INTEGER, proof_kind TEXT NOT NULL, closed INTEGER NOT NULL DEFAULT 0,
              generation INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (owner_user_id, conversation_id, range_key)
            )
          ''');
          await database.execute('''
            CREATE TABLE IF NOT EXISTS $_pageTable (
              owner_user_id TEXT NOT NULL, conversation_id TEXT NOT NULL,
              page_key TEXT NOT NULL, direction TEXT NOT NULL,
              cursor_msg_id TEXT, cursor_seq INTEGER,
              returned_oldest_msg_id TEXT, returned_newest_msg_id TEXT,
              returned_oldest_seq INTEGER, returned_newest_seq INTEGER,
              is_finished INTEGER NOT NULL DEFAULT 0, has_more INTEGER NOT NULL DEFAULT 0,
              proof_kind TEXT NOT NULL, generation INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (owner_user_id, conversation_id, page_key)
            )
          ''');
        }
        if (oldVersion < 4) {
          await database.execute(
            "ALTER TABLE message_history_coverage "
            "ADD COLUMN last_proof_kind TEXT NOT NULL DEFAULT 'none'",
          );
        }
      },
    );
    if (!SqfliteLifecycleGuard.instance.canOpenDatabase) {
      await SqfliteLifecycleGuard.closeDatabase(db);
      throw const SqfliteClosedForBackground();
    }
    _db = db;
    return db;
  }

  @override
  Future<MessageHistoryCoverage?> load(String conversationID) async {
    return loadForOwner(_resolveOwner(), conversationID);
  }

  /// Explicit account-scoped read for Coordinator/adapter callers.
  ///
  /// The legacy [load] API remains current-session based for compatibility;
  /// production coordination must use this method so a late response cannot
  /// read another account's coverage.
  Future<MessageHistoryCoverage?> loadForOwner(
    String ownerUserId,
    String conversationID,
  ) async {
    final owner = _resolveOwner(ownerUserId);
    final key = _canonicalConversationID(conversationID);
    if (owner.isEmpty || key.isEmpty) return null;
    final memory = _memoryForOwner(owner);
    final cached = memory[key];
    if (cached != null) return cached;
    if (_useMemoryOnly) return null;
    try {
      final db = await _openDb();
      final rows = await db.query(
        _coverageTable,
        where: 'owner_user_id = ? AND conversation_id = ?',
        whereArgs: <Object?>[owner, key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final holeRows = await db.query(
        _holeTable,
        where: 'owner_user_id = ? AND conversation_id = ?',
        whereArgs: <Object?>[owner, key],
        orderBy: 'updated_at ASC, hole_key ASC',
      );
      final rangeRows = await db.query(
        _rangeTable,
        where: 'owner_user_id = ? AND conversation_id = ?',
        whereArgs: <Object?>[owner, key],
        orderBy: 'updated_at ASC, range_key ASC',
        limit: 64,
      );
      final pageRows = await db.query(
        _pageTable,
        where: 'owner_user_id = ? AND conversation_id = ?',
        whereArgs: <Object?>[owner, key],
        orderBy: 'updated_at ASC, page_key ASC',
        limit: 64,
      );
      final coverage = _coverageFromRows(rows.first, holeRows, rangeRows, pageRows);
      memory[key] = coverage;
      return coverage;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(MessageHistoryCoverage coverage) async {
    await saveForOwner(_resolveOwner(), coverage);
  }

  /// Explicit account-scoped write for Coordinator/adapter callers.
  ///
  /// This preserves the existing monotonic clear-epoch and revision checks;
  /// it only makes the account key an explicit input instead of an ambient
  /// current-session lookup.
  Future<void> saveForOwner(
    String ownerUserId,
    MessageHistoryCoverage coverage,
  ) async {
    final owner = _resolveOwner(ownerUserId);
    final key = _canonicalConversationID(coverage.conversationKey);
    if (owner.isEmpty || key.isEmpty) return;
    final normalized = coverage.copyWith(conversationKey: key);
    final memory = _memoryForOwner(owner);
    final previous = memory[key];
    if (_isStale(previous, normalized)) return;
    memory[key] = normalized;
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) return;
    try {
      final db = await _openDb();
      await db.transaction((txn) async {
        final rows = await txn.query(
          _coverageTable,
          columns: const <String>['clear_epoch', 'coverage_revision'],
          where: 'owner_user_id = ? AND conversation_id = ?',
          whereArgs: <Object?>[owner, key],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final persistedEpoch = _asInt(rows.first['clear_epoch']);
          final persistedRevision = _asInt(rows.first['coverage_revision']);
          if (persistedEpoch > normalized.clearEpoch ||
              (persistedEpoch == normalized.clearEpoch &&
                  persistedRevision > normalized.coverageRevision)) {
            return;
          }
        }
        await txn.insert(
          _coverageTable,
          _coverageRow(owner, normalized),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.delete(
          _holeTable,
          where: 'owner_user_id = ? AND conversation_id = ?',
          whereArgs: <Object?>[owner, key],
        );
        await txn.delete(
          _rangeTable,
          where: 'owner_user_id = ? AND conversation_id = ?',
          whereArgs: <Object?>[owner, key],
        );
        await txn.delete(
          _pageTable,
          where: 'owner_user_id = ? AND conversation_id = ?',
          whereArgs: <Object?>[owner, key],
        );
        for (final hole in normalized.holes) {
          await txn.insert(
            _holeTable,
            _holeRow(owner, key, hole),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final range in normalized.ranges.take(64)) {
          await txn.insert(
            _rangeTable,
            _rangeRow(owner, key, range),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final page in normalized.pages.take(64)) {
          await txn.insert(
            _pageTable,
            _pageRow(owner, key, page),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (_) {}
  }

  @override
  Future<void> clearConversation(
    String conversationID, {
    required bool isGroup,
    required int clearEpoch,
  }) async {
    final key = _canonicalConversationID(conversationID);
    if (key.isEmpty) return;
    await save(
      MessageHistoryCoverage.empty(
        key,
        isGroup: isGroup,
        clearEpoch: clearEpoch,
      ).copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch),
    );
  }

  @override
  Future<void> clearSession() async {
    _memoryByOwner.clear();
    await closeIfOpen();
  }

  Future<void> clearForOwner(String? ownerUserId) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) return;
    _memoryByOwner.remove(owner);
    if (_useMemoryOnly) return;
    try {
      final db = await _openDb();
      await db.transaction((txn) async {
      await txn.delete(
          _holeTable,
          where: 'owner_user_id = ?',
          whereArgs: <Object?>[owner],
      );
      await txn.delete(
        _rangeTable,
        where: 'owner_user_id = ?',
        whereArgs: <Object?>[owner],
      );
      await txn.delete(
        _pageTable,
        where: 'owner_user_id = ?',
        whereArgs: <Object?>[owner],
      );
        await txn.delete(
          _coverageTable,
          where: 'owner_user_id = ?',
          whereArgs: <Object?>[owner],
        );
      });
    } catch (_) {}
  }

  Future<void> closeIfOpen() async {
    final opening = _dbOpenInFlight;
    if (opening != null) {
      try {
        await opening.timeout(const Duration(milliseconds: 400));
      } catch (_) {}
    }
    final db = _db;
    _db = null;
    await SqfliteLifecycleGuard.closeDatabase(db);
  }

  bool _isStale(
    MessageHistoryCoverage? previous,
    MessageHistoryCoverage incoming,
  ) {
    if (previous == null) return false;
    if (previous.clearEpoch != incoming.clearEpoch) {
      return previous.clearEpoch > incoming.clearEpoch;
    }
    return previous.coverageRevision > incoming.coverageRevision;
  }

  Map<String, Object?> _coverageRow(
    String owner,
    MessageHistoryCoverage coverage,
  ) {
    return <String, Object?>{
      'owner_user_id': owner,
      'conversation_id': coverage.conversationKey,
      'is_group': coverage.isGroup ? 1 : 0,
      'clear_epoch': coverage.clearEpoch,
      'coverage_revision': coverage.coverageRevision,
      'status': coverage.status.name,
      'local_oldest_msg_id': coverage.localOldestMsgID,
      'local_newest_msg_id': coverage.localNewestMsgID,
      'verified_oldest_msg_id': coverage.verifiedOldestMsgID,
      'verified_newest_msg_id': coverage.verifiedNewestMsgID,
      'verified_oldest_seq': coverage.verifiedOldestSeq,
      'verified_newest_seq': coverage.verifiedNewestSeq,
      'older_exhausted': coverage.olderExhausted ? 1 : 0,
      'newer_has_more': coverage.newerHasMore ? 1 : 0,
      'cloud_verified_at': coverage.cloudVerifiedAtMs,
      'last_request_generation': coverage.lastRequestGeneration,
      'last_requested_source': coverage.lastRequestedSource,
      'last_actual_source': coverage.lastActualSource,
      'last_batch_kind': coverage.lastBatchKind,
      'last_cursor_direction': coverage.lastCursorDirection,
      'last_cursor_msg_id': coverage.lastCursorMsgID,
      'last_cursor_seq': coverage.lastCursorSeq,
      'last_returned_oldest_msg_id': coverage.lastReturnedOldestMsgID,
      'last_returned_newest_msg_id': coverage.lastReturnedNewestMsgID,
      'last_returned_oldest_seq': coverage.lastReturnedOldestSeq,
      'last_returned_newest_seq': coverage.lastReturnedNewestSeq,
      'last_proof_kind': coverage.lastProofKind.name,
      'last_cloud_response_proven': coverage.lastCloudResponseProven ? 1 : 0,
      'continuation_pending': coverage.continuationPending ? 1 : 0,
      'continuation_direction': coverage.continuationDirection?.name,
      'continuation_cursor_msg_id': coverage.continuationCursorMsgID,
      'continuation_cursor_seq': coverage.continuationCursorSeq,
      'updated_at': coverage.updatedAtMs,
    };
  }

  Map<String, Object?> _holeRow(
    String owner,
    String conversationID,
    MessageHistoryHole hole,
  ) {
    return <String, Object?>{
      'owner_user_id': owner,
      'conversation_id': conversationID,
      'hole_key': hole.key,
      'kind': hole.kind.name,
      'status': hole.status.name,
      'start_seq': hole.startSeq,
      'end_seq': hole.endSeq,
      'older_msg_id': hole.olderMsgID,
      'newer_msg_id': hole.newerMsgID,
      'generation': hole.generation,
      'updated_at': hole.updatedAtMs,
    };
  }

  Map<String, Object?> _rangeRow(
    String owner,
    String conversationID,
    MessageHistoryCoverageRange range,
  ) {
    return <String, Object?>{
      'owner_user_id': owner,
      'conversation_id': conversationID,
      'range_key': range.key,
      'direction': range.direction.name,
      'oldest_msg_id': range.oldestMsgID,
      'newest_msg_id': range.newestMsgID,
      'start_seq': range.startSeq,
      'end_seq': range.endSeq,
      'proof_kind': range.proofKind.name,
      'closed': range.closed ? 1 : 0,
      'generation': range.generation,
      'updated_at': range.updatedAtMs,
    };
  }

  Map<String, Object?> _pageRow(
    String owner,
    String conversationID,
    MessageHistoryPageRecord page,
  ) {
    return <String, Object?>{
      'owner_user_id': owner,
      'conversation_id': conversationID,
      'page_key': page.key,
      'direction': page.direction.name,
      'cursor_msg_id': page.cursorMsgID,
      'cursor_seq': page.cursorSeq,
      'returned_oldest_msg_id': page.returnedOldestMsgID,
      'returned_newest_msg_id': page.returnedNewestMsgID,
      'returned_oldest_seq': page.returnedOldestSeq,
      'returned_newest_seq': page.returnedNewestSeq,
      'is_finished': page.isFinished ? 1 : 0,
      'has_more': page.hasMore ? 1 : 0,
      'proof_kind': page.proofKind.name,
      'generation': page.generation,
      'updated_at': page.updatedAtMs,
    };
  }

  MessageHistoryCoverage _coverageFromRows(
    Map<String, Object?> row,
    List<Map<String, Object?>> holeRows,
    List<Map<String, Object?>> rangeRows,
    List<Map<String, Object?>> pageRows,
  ) {
    final holes = holeRows
        .map(
          (hole) => MessageHistoryHole.fromJson(<String, Object?>{
            'key': hole['hole_key'],
            'kind': hole['kind'],
            'status': hole['status'],
            'startSeq': hole['start_seq'],
            'endSeq': hole['end_seq'],
            'olderMsgID': hole['older_msg_id'],
            'newerMsgID': hole['newer_msg_id'],
            'generation': hole['generation'],
            'updatedAtMs': hole['updated_at'],
          }),
        )
        .toList(growable: false);
    final ranges = rangeRows
        .map(
          (range) => MessageHistoryCoverageRange.fromJson(<String, Object?>{
            'key': range['range_key'],
            'direction': range['direction'],
            'oldestMsgID': range['oldest_msg_id'],
            'newestMsgID': range['newest_msg_id'],
            'startSeq': range['start_seq'],
            'endSeq': range['end_seq'],
            'proofKind': range['proof_kind'],
            'closed': range['closed'],
            'generation': range['generation'],
            'updatedAtMs': range['updated_at'],
          }),
        )
        .toList(growable: false);
    final pages = pageRows
        .map(
          (page) => MessageHistoryPageRecord.fromJson(<String, Object?>{
            'key': page['page_key'],
            'direction': page['direction'],
            'cursorMsgID': page['cursor_msg_id'],
            'cursorSeq': page['cursor_seq'],
            'returnedOldestMsgID': page['returned_oldest_msg_id'],
            'returnedNewestMsgID': page['returned_newest_msg_id'],
            'returnedOldestSeq': page['returned_oldest_seq'],
            'returnedNewestSeq': page['returned_newest_seq'],
            'isFinished': page['is_finished'],
            'hasMore': page['has_more'],
            'proofKind': page['proof_kind'],
            'generation': page['generation'],
            'updatedAtMs': page['updated_at'],
          }),
        )
        .toList(growable: false);
    return MessageHistoryCoverage.fromJson(<String, Object?>{
      'conversationKey': row['conversation_id'],
      'isGroup': _asInt(row['is_group']) == 1,
      'clearEpoch': row['clear_epoch'],
      'coverageRevision': row['coverage_revision'],
      'status': row['status'],
      'localOldestMsgID': row['local_oldest_msg_id'],
      'localNewestMsgID': row['local_newest_msg_id'],
      'verifiedOldestMsgID': row['verified_oldest_msg_id'],
      'verifiedNewestMsgID': row['verified_newest_msg_id'],
      'verifiedOldestSeq': row['verified_oldest_seq'],
      'verifiedNewestSeq': row['verified_newest_seq'],
      'olderExhausted': _asInt(row['older_exhausted']) == 1,
      'newerHasMore': _asInt(row['newer_has_more']) == 1,
      'holes': holes.map((hole) => hole.toJson()).toList(growable: false),
      'ranges': ranges.map((range) => range.toJson()).toList(growable: false),
      'pages': pages.map((page) => page.toJson()).toList(growable: false),
      'continuationPending': _asInt(row['continuation_pending']) == 1,
      'continuationDirection': row['continuation_direction'],
      'continuationCursorMsgID': row['continuation_cursor_msg_id'],
      'continuationCursorSeq': row['continuation_cursor_seq'],
      'cloudVerifiedAtMs': row['cloud_verified_at'],
      'lastRequestGeneration': row['last_request_generation'],
      'lastRequestedSource': row['last_requested_source'],
      'lastActualSource': row['last_actual_source'],
      'lastBatchKind': row['last_batch_kind'],
      'lastCursorDirection': row['last_cursor_direction'],
      'lastCursorMsgID': row['last_cursor_msg_id'],
      'lastCursorSeq': row['last_cursor_seq'],
      'lastReturnedOldestMsgID': row['last_returned_oldest_msg_id'],
      'lastReturnedNewestMsgID': row['last_returned_newest_msg_id'],
      'lastReturnedOldestSeq': row['last_returned_oldest_seq'],
      'lastReturnedNewestSeq': row['last_returned_newest_seq'],
      'lastProofKind': row['last_proof_kind'],
      'lastCloudResponseProven': _asInt(row['last_cloud_response_proven']) == 1,
      'updatedAtMs': row['updated_at'],
    });
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
