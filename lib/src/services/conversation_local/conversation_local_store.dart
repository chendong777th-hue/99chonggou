import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_unread_trace.dart';
import 'package:tencent_cloud_chat_demo/src/services/foreground_chat_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lock_profile_log.dart';
import 'package:tencent_cloud_chat_demo/src/utils/archive_conversation_lookup.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_unread_utils.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_last_message_prefer.dart';
import 'package:tencent_cloud_chat_demo/utils/group_display_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';

import 'conversation_row_decode_worker.dart';
import 'conversation_mutation_coordinator.dart';
import 'conversation_mutation_event.dart';
import 'web_conversation_meta_store.dart';

/// 「全部已读」/ 批量已读的本地 scope。
enum MarkReadLocalScope { all, c2c, group }

/// [ConversationLocalStore] 批量清未读结果。
class MarkReadBatchResult {
  const MarkReadBatchResult({
    required this.clearedIds,
    required this.conversationCount,
    required this.unreadSumBefore,
  });

  static const empty = MarkReadBatchResult(
    clearedIds: <String>[],
    conversationCount: 0,
    unreadSumBefore: 0,
  );

  final List<String> clearedIds;
  final int conversationCount;
  final int unreadSumBefore;

  bool get isEmpty => conversationCount <= 0;
}

/// [ConversationLocalStore.prepareArchiveIdSet] 结果。
class ArchiveIdPrepareResult {
  const ArchiveIdPrepareResult({
    required this.generation,
    required this.joinTokenCount,
    required this.originalCount,
  });

  final int generation;
  final int joinTokenCount;
  final int originalCount;
}

class _CoordinatorCommitState {
  int generation = 0;
  int? tombstoneGeneration;
  final Set<String> idempotencyKeys = <String>{};
}

class ConversationCoordinatorDurableState {
  const ConversationCoordinatorDurableState({
    required this.generation,
    required this.tombstoned,
  });

  final int generation;
  final bool tombstoned;
}

class ConversationSdkCommittedBatch {
  const ConversationSdkCommittedBatch({
    required this.upserted,
    required this.unreadDeltas,
    required this.unreadProjectionComplete,
    this.changedFieldMasks = const <String, Set<ConversationMutationField>>{},
    this.structureChanged = false,
  });

  final List<V2TimConversation> upserted;
  final List<ConversationUiUnreadDelta> unreadDeltas;
  final bool unreadProjectionComplete;
  final Map<String, Set<ConversationMutationField>> changedFieldMasks;
  final bool structureChanged;
}

class ConversationTypePageCursor {
  const ConversationTypePageCursor({
    required this.pinned,
    required this.activeTime,
    required this.orderKey,
    required this.conversationID,
  });

  final bool pinned;
  final int activeTime;
  final int orderKey;
  final String conversationID;
}

class ConversationReadBarrier {
  const ConversationReadBarrier({
    required this.version,
    required this.recordedAtMs,
    required this.lastMessageId,
    required this.lastMessageTimestamp,
    required this.lastMessageSeq,
    required this.orderKey,
  });

  final int version;
  final int recordedAtMs;
  final String lastMessageId;
  final int lastMessageTimestamp;
  final int lastMessageSeq;
  final int orderKey;
}

@immutable
class ConversationStoreBatchProfileSnapshot {
  const ConversationStoreBatchProfileSnapshot({
    required this.durableStateQueries,
    required this.coordinatorPlanCommits,
    required this.coordinatorStateWrites,
    required this.rawJsonDecodes,
    required this.atomicSdkTransactions,
  });

  final int durableStateQueries;
  final int coordinatorPlanCommits;
  final int coordinatorStateWrites;
  final int rawJsonDecodes;
  final int atomicSdkTransactions;
}

/// 会话列表本地库（按登录账号隔离）。
///
/// Phase3 / sdkPrimary：主列表 UI **不再**以本库 unread/lastMessage/orderKey/isPinned
/// 为权威（见 [ConversationPerfFlags.conversationSqliteListFieldsMirrorOnly]）；
/// 这些列仍可写入，供角标聚合、分组 unread map、离线兜底。权威源 = IM SDK + TabStore。
/// legacy（sdkPrimary=false）：UI 仍可读本库。
///
/// 置顶展示以 [ConversationPinSyncService] 对齐后的集合为准（默认腾讯为主）；
/// 读行时用 `_applyBackendPinnedFlag` 与集合对齐，避免 SDK 与集合短暂不一致。
class ConversationLocalStore {
  ConversationLocalStore._();

  static final ConversationLocalStore instance = ConversationLocalStore._();

  static const _dbName = 'conversation_local_v1.db';
  static const _table = 'conversations';
  static const _metaTable = 'conversation_sync_meta';
  static const _archiveJoinTable = 'archive_join_ids';
  static const _coordinatorStateTable = 'conversation_commit_state';
  static const _pageAnchorTable = 'conversation_page_anchor';
  static const _viewStateTable = 'conversation_view_state';

  Database? _db;
  Future<Database>? _dbOpenInFlight;
  int _databaseOpenCount = 0;
  final Map<String, List<V2TimConversation>> _memoryByOwner = {};
  final Map<String, ConversationSyncMeta> _memoryMetaByOwner = {};
  final Map<String, _CoordinatorCommitState> _coordinatorCommitStates =
      <String, _CoordinatorCommitState>{};
  bool _factoryReady = false;
  int _profileDurableStateQueries = 0;
  int _profileCoordinatorPlanCommits = 0;
  int _profileCoordinatorStateWrites = 0;
  int _profileRawJsonDecodes = 0;
  int _profileAtomicSdkTransactions = 0;

  @visibleForTesting
  ConversationStoreBatchProfileSnapshot get batchProfileForTest =>
      ConversationStoreBatchProfileSnapshot(
        durableStateQueries: _profileDurableStateQueries,
        coordinatorPlanCommits: _profileCoordinatorPlanCommits,
        coordinatorStateWrites: _profileCoordinatorStateWrites,
        rawJsonDecodes: _profileRawJsonDecodes,
        atomicSdkTransactions: _profileAtomicSdkTransactions,
      );

  @visibleForTesting
  void resetBatchProfileForTest() {
    _profileDurableStateQueries = 0;
    _profileCoordinatorPlanCommits = 0;
    _profileCoordinatorStateWrites = 0;
    _profileRawJsonDecodes = 0;
    _profileAtomicSdkTransactions = 0;
  }

  int _archivePrepareGeneration = 0;
  String? _archivePrepareOwner;
  Set<String> _archiveJoinTokenSet = <String>{};
  Set<String> _archiveOriginalIds = <String>{};
  bool _archiveJoinTableReady = false;

  final Set<String> _webMetaHydratedOwners = <String>{};
  Timer? _webMetaPersistTimer;
  String? _webMetaPersistOwner;

  void _applyBackendPinnedFlag(V2TimConversation conversation) {
    // Only overwrite isPinned from the in-memory pin set when it has been
    // hydrated. Before hydration (cold start, guest scope, or hydration
    // failure), the SQLite `is_pinned` column is the sole authority —
    // overwriting with an empty set would reset all pinned conversations
    // to isPinned=false, causing them to sort by time instead of staying
    // at the top.
    if (!ConversationPinSyncService.instance.isHydrated) {
      return;
    }
    conversation.isPinned = ConversationPinSyncService.instance
        .isPinnedConversationId(conversation.conversationID);
  }

  Future<void> _ensureDatabaseFactory() async {
    if (_factoryReady) {
      return;
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _factoryReady = true;
  }

  static const _dbVersion = 14;
  static const _localReadGraceMs = 12000;

  static const _persistedComparisonColumns = <String>[
    'owner_user_id',
    'conversation_id',
    'conv_type',
    'user_id',
    'group_id',
    'show_name',
    'face_url',
    'unread_count',
    'recv_opt',
    'group_type',
    'is_pinned',
    'order_key',
    'active_time',
    'raw_json_fingerprint',
    'read_cleared_at',
    'history_cleared_at',
    'local_draft_text',
    'local_draft_updated_at',
    'last_msg_id',
  ];

  /// upsert 合并还需要旧 raw_json 还原 lastMessage 等字段；和比较列一次取回，
  /// 避免发生变化的每一行再单独 SELECT。
  static const _upsertFetchColumns = <String>[
    ..._persistedComparisonColumns,
    'raw_json',
  ];

  final Map<String, int> _readClearedAtMs = {};
  final Map<String, String> _readClearedLastMsgId = {};
  final Map<String, ConversationReadBarrier> _readBarriers = {};

  /// Monotonic source watermark for SDK unread snapshots. This is separate
  /// from read barriers: it prevents an older callback from reverting a newer
  /// committed SDK value during bootstrap/reconciliation.
  final Map<String, int> _sdkUnreadSourceVersions = <String, int>{};
  final Map<String, int> _historyClearedAtMs = {};
  final Set<String> _historyClearIndexHydratedOwners = <String>{};
  final Map<String, Future<void>> _historyClearIndexInFlightByOwner =
      <String, Future<void>>{};
  int _historyClearIndexGeneration = 0;

  /// 删除消息后被移出预览的 msgID。SDK 删最后一条消息后不刷新会话
  /// lastMessage，后续同步仍可能把这条旧预览带回来；merge 时按此集合丢弃。
  /// 进程内即可：重启后 SDK 侧已收敛。
  final Set<String> _deletedPreviewMsgIds = {};

  final Map<String, V2TimConversation> _upsertCoalesceById =
      <String, V2TimConversation>{};
  final List<_UpsertCoalesceWaiter> _upsertCoalesceWaiters =
      <_UpsertCoalesceWaiter>[];
  final List<_UpsertCoalesceWaiter> _upsertCoalesceInFlightWaiters =
      <_UpsertCoalesceWaiter>[];
  Timer? _upsertCoalesceTimer;
  bool _upsertCoalesceFlushing = false;
  Completer<void>? _upsertCoalesceFlushCompleter;
  DateTime? _upsertCoalesceFirstQueuedAt;
  String? _upsertCoalesceOwner;
  int _upsertCoalesceGeneration = 0;
  bool _resumeForegroundStagedFlushActive = false;

  /// 单测绕过写合并，避免 100ms 延迟拖垮既有用例。
  @visibleForTesting
  static bool bypassUpsertCoalesceForTest = false;

  /// 会话列表滚动等忙碌态：拉长 upsert coalesce，避免与手势抢主线程。
  bool Function()? isUiBusyForWriteCoalesce;

  @visibleForTesting
  Future<void> Function()? beforeUpsertBatchImplForTest;

  @visibleForTesting
  int get databaseOpenCountForTest => _databaseOpenCount;

  Future<Database> _openDb() async {
    final existing = SqfliteLifecycleGuard.beforeOpen(_db);
    if (existing != null) {
      return existing;
    }
    final opening = _dbOpenInFlight;
    if (opening != null) {
      return opening;
    }
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
    final basePath = await getDatabasesPath();
    final path = p.join(basePath, _dbName);
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createConversationTable(db);
        await db.execute(
          'CREATE INDEX idx_conv_owner_sort ON $_table(owner_user_id, is_pinned DESC, active_time DESC, order_key DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_conv_owner_last_msg ON $_table(owner_user_id, last_msg_id)',
        );
        await db.execute(
          'CREATE INDEX idx_conv_owner_type_sort ON $_table(owner_user_id, conv_type, is_pinned DESC, active_time DESC, order_key DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_conv_owner_type_unread ON $_table(owner_user_id, conv_type, unread_count)',
        );
        await _createMetaTable(db);
        await _createCoordinatorStateTable(db);
        await _createPageAnchorTable(db);
        await _createViewStateTable(db);
      },
      onOpen: _ensureRawJsonFingerprintColumn,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToV2(db);
        }
        if (oldVersion < 3) {
          await _upgradeToV3(db);
        }
        if (oldVersion < 4) {
          await _upgradeToV4(db);
        }
        if (oldVersion < 5) {
          await _upgradeToV5(db);
        }
        if (oldVersion < 6) {
          await _upgradeToV6(db);
        }
        if (oldVersion < 7) {
          await _upgradeToV7(db);
        }
        if (oldVersion < 8) {
          await _upgradeToV8(db);
        }
        if (oldVersion < 9) {
          await _upgradeToV9(db);
        }
        if (oldVersion < 10) {
          await _upgradeToV10(db);
        }
        if (oldVersion < 11) {
          await _upgradeToV11(db);
        }
        if (oldVersion < 12) {
          await _upgradeToV12(db);
        }
        if (oldVersion < 13) {
          await _upgradeToV13(db);
        }
        if (oldVersion < 14) {
          await _upgradeToV14(db);
        }
      },
    );
    if (!SqfliteLifecycleGuard.instance.canOpenDatabase) {
      await SqfliteLifecycleGuard.closeDatabase(db);
      throw const SqfliteClosedForBackground();
    }
    _databaseOpenCount++;
    _db = db;
    return db;
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

  @visibleForTesting
  Future<void> closeDatabaseForTest() => closeIfOpen();

  Future<void> _createConversationTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_table (
        owner_user_id TEXT NOT NULL,
        conversation_id TEXT NOT NULL,
        conv_type INTEGER NOT NULL DEFAULT 0,
        user_id TEXT NOT NULL DEFAULT '',
        group_id TEXT NOT NULL DEFAULT '',
        show_name TEXT NOT NULL DEFAULT '',
        face_url TEXT NOT NULL DEFAULT '',
        unread_count INTEGER NOT NULL DEFAULT 0,
        recv_opt INTEGER NOT NULL DEFAULT 0,
        group_type TEXT NOT NULL DEFAULT '',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        order_key INTEGER NOT NULL DEFAULT 0,
        active_time INTEGER NOT NULL DEFAULT 0,
        raw_json TEXT NOT NULL,
        raw_json_fingerprint TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        read_cleared_at INTEGER NOT NULL DEFAULT 0,
        history_cleared_at INTEGER NOT NULL DEFAULT 0,
        local_draft_text TEXT NOT NULL DEFAULT '',
        local_draft_updated_at INTEGER NOT NULL DEFAULT 0,
        last_msg_id TEXT NOT NULL DEFAULT '',
        PRIMARY KEY (owner_user_id, conversation_id)
      )
    ''');
  }

  Future<void> _createMetaTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_metaTable (
        owner_user_id TEXT PRIMARY KEY,
        next_seq TEXT NOT NULL DEFAULT '0',
        have_more INTEGER NOT NULL DEFAULT 1,
        has_synced_once INTEGER NOT NULL DEFAULT 0,
        c2c_next_seq TEXT NOT NULL DEFAULT '0',
        c2c_have_more INTEGER NOT NULL DEFAULT 1,
        group_next_seq TEXT NOT NULL DEFAULT '0',
        group_have_more INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createCoordinatorStateTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_coordinatorStateTable (
        owner_user_id TEXT NOT NULL,
        canonical_conversation_id TEXT NOT NULL,
        generation INTEGER NOT NULL DEFAULT 0,
        tombstone_generation INTEGER,
        idempotency_keys_json TEXT NOT NULL DEFAULT '[]',
        removed_at INTEGER NOT NULL DEFAULT 0,
        reason TEXT NOT NULL DEFAULT '',
        expires_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (owner_user_id, canonical_conversation_id)
      )
    ''');
  }

  Future<void> _upgradeToV2(Database db) async {
    final columns = <String>[
      "show_name TEXT NOT NULL DEFAULT ''",
      "face_url TEXT NOT NULL DEFAULT ''",
      'unread_count INTEGER NOT NULL DEFAULT 0',
      'recv_opt INTEGER NOT NULL DEFAULT 0',
      "group_type TEXT NOT NULL DEFAULT ''",
    ];
    for (final definition in columns) {
      final parts = definition.split(' ');
      final name = parts.first;
      final typeAndDefault = definition.substring(name.length + 1);
      await db.execute('ALTER TABLE $_table ADD COLUMN $name $typeAndDefault');
    }
  }

  Future<void> _upgradeToV3(Database db) async {
    await db.execute(
      'ALTER TABLE $_table ADD COLUMN read_cleared_at INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _upgradeToV4(Database db) async {
    await db.execute(
      "ALTER TABLE $_table ADD COLUMN local_draft_text TEXT NOT NULL DEFAULT ''",
    );
    await db.execute(
      'ALTER TABLE $_table ADD COLUMN local_draft_updated_at INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _upgradeToV5(Database db) async {
    await db.execute(
      'ALTER TABLE $_table ADD COLUMN history_cleared_at INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _upgradeToV6(Database db) async {
    await db.execute(
      "ALTER TABLE $_table ADD COLUMN last_msg_id TEXT NOT NULL DEFAULT ''",
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_conv_owner_last_msg ON $_table(owner_user_id, last_msg_id)',
    );
  }

  Future<void> _upgradeToV7(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_conv_owner_type_sort ON $_table(owner_user_id, conv_type, is_pinned DESC, active_time DESC, order_key DESC)',
    );
  }

  Future<void> _upgradeToV8(Database db) async {
    await db.execute(
      "ALTER TABLE $_metaTable ADD COLUMN c2c_next_seq TEXT NOT NULL DEFAULT '0'",
    );
    await db.execute(
      'ALTER TABLE $_metaTable ADD COLUMN c2c_have_more INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute(
      "ALTER TABLE $_metaTable ADD COLUMN group_next_seq TEXT NOT NULL DEFAULT '0'",
    );
    await db.execute(
      'ALTER TABLE $_metaTable ADD COLUMN group_have_more INTEGER NOT NULL DEFAULT 1',
    );
    // 混流游标不能直接当 ByFilter 游标用；升级后两路从 0 重拉首屏，避免错序。
    await db.execute('''
      UPDATE $_metaTable SET
        c2c_next_seq = '0',
        c2c_have_more = 1,
        group_next_seq = '0',
        group_have_more = 1
    ''');
  }

  Future<void> _upgradeToV9(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_conv_owner_type_unread ON $_table(owner_user_id, conv_type, unread_count)',
    );
  }

  Future<void> _upgradeToV10(Database db) => _createCoordinatorStateTable(db);

  Future<void> _createPageAnchorTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_pageAnchorTable (
        owner_user_id TEXT NOT NULL,
        conv_type INTEGER NOT NULL,
        page_start INTEGER NOT NULL,
        page_end INTEGER NOT NULL DEFAULT 0,
        page_version INTEGER NOT NULL DEFAULT 0,
        pinned INTEGER NOT NULL DEFAULT 0,
        active_time INTEGER NOT NULL DEFAULT 0,
        order_key INTEGER NOT NULL DEFAULT 0,
        conversation_id TEXT NOT NULL DEFAULT '',
        first_pinned INTEGER NOT NULL DEFAULT 0,
        first_active_time INTEGER NOT NULL DEFAULT 0,
        first_order_key INTEGER NOT NULL DEFAULT 0,
        first_conversation_id TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (owner_user_id, conv_type, page_start)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_page_anchor_owner_type_start
      ON $_pageAnchorTable(owner_user_id, conv_type, page_start)
    ''');
  }

  Future<void> _upgradeToV11(Database db) => _createPageAnchorTable(db);
  Future<void> _upgradeToV12(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_pageAnchorTable)');
    if (!columns.any((row) => row['name'] == 'page_end')) {
      await db.execute(
        'ALTER TABLE $_pageAnchorTable ADD COLUMN page_end INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> _upgradeToV13(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_pageAnchorTable)');
    if (!columns.any((row) => row['name'] == 'page_version')) {
      await db.execute(
        'ALTER TABLE $_pageAnchorTable ADD COLUMN page_version INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> _createViewStateTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_viewStateTable (
        owner_user_id TEXT NOT NULL,
        conv_type INTEGER NOT NULL,
        view_version INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (owner_user_id, conv_type)
      )
    ''');
  }

  Future<void> _upgradeToV14(Database db) async {
    await _createViewStateTable(db);
    final columns = await db.rawQuery('PRAGMA table_info($_pageAnchorTable)');
    final names = columns.map((row) => row['name']).toSet();
    for (final definition in const <String>[
      'first_pinned INTEGER NOT NULL DEFAULT 0',
      'first_active_time INTEGER NOT NULL DEFAULT 0',
      'first_order_key INTEGER NOT NULL DEFAULT 0',
      "first_conversation_id TEXT NOT NULL DEFAULT ''",
    ]) {
      final name = definition.split(' ').first;
      if (!names.contains(name)) {
        await db
            .execute('ALTER TABLE $_pageAnchorTable ADD COLUMN $definition');
      }
    }
  }

  Future<void> _ensureRawJsonFingerprintColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_table)');
    if (columns.any((row) => row['name'] == 'raw_json_fingerprint')) {
      return;
    }
    await db.execute(
      "ALTER TABLE $_table ADD COLUMN raw_json_fingerprint TEXT NOT NULL DEFAULT ''",
    );
  }

  static String _normalizeDraftText(String text) {
    return text.replaceAll(RegExp(r'\ufeff'), '').trim();
  }

  static String _localDraftTextFromRow(Map<String, Object?> row) {
    return _normalizeDraftText(row['local_draft_text']?.toString() ?? '');
  }

  static int _localDraftUpdatedAtMsFromRow(Map<String, Object?> row) {
    return _asInt(row['local_draft_updated_at']);
  }

  static void applyLocalDraftToConversation(
    V2TimConversation conversation, {
    required String text,
    required int updatedAtMs,
  }) {
    final normalized = _normalizeDraftText(text);
    if (normalized.isEmpty) {
      conversation.draftText = null;
      conversation.draftTimestamp = null;
      return;
    }
    conversation.draftText = normalized;
    conversation.draftTimestamp = updatedAtMs > 0 ? updatedAtMs ~/ 1000 : null;
  }

  static int _activeTimeForPersistedRow(
    V2TimConversation conversation, {
    required String localDraftText,
    required int localDraftUpdatedAtMs,
  }) {
    if (_normalizeDraftText(localDraftText).isNotEmpty &&
        localDraftUpdatedAtMs > 0) {
      return localDraftUpdatedAtMs >= 1000000000000
          ? localDraftUpdatedAtMs
          : localDraftUpdatedAtMs * 1000;
    }
    return activeTimeMs(conversation);
  }

  void _applyPreservedLocalDraftOnIncoming(
    V2TimConversation incoming, {
    required String preservedLocalDraftText,
    required int preservedLocalDraftUpdatedAtMs,
  }) {
    applyLocalDraftToConversation(
      incoming,
      text: preservedLocalDraftText,
      updatedAtMs: preservedLocalDraftUpdatedAtMs,
    );
  }

  String _conversationEquivalenceKey(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return id;
    }
    final lower = id.toLowerCase();
    if (lower.startsWith('group_')) {
      final token = ChatIdFormat.groupEquivalenceToken(id.substring(6));
      if (token != null && token.isNotEmpty) {
        return 'group:$token';
      }
    }
    if (ChatIdFormat.isIMGroupOrCommunityId(id)) {
      final token = ChatIdFormat.groupEquivalenceToken(id);
      if (token != null && token.isNotEmpty) {
        return 'group:$token';
      }
    }
    if (lower.startsWith('c2c_')) {
      final peer = ChatIdFormat.rawUserUid(id.substring(4));
      if (peer.isNotEmpty) {
        return 'c2c:$peer';
      }
    }
    return id;
  }

  String _readClearCacheKey(String owner, String conversationId) {
    return '$owner|${_conversationEquivalenceKey(conversationId)}';
  }

  String _coordinatorCommitKey({
    required String owner,
    required String canonicalConversationId,
  }) {
    return '$owner|${_conversationEquivalenceKey(canonicalConversationId)}';
  }

  String _coordinatorCanonicalKey(String conversationId) =>
      _conversationEquivalenceKey(conversationId);

  Future<_CoordinatorCommitState> _loadCoordinatorCommitState({
    required String owner,
    required String canonicalConversationId,
  }) async {
    final memoryKey = _coordinatorCommitKey(
      owner: owner,
      canonicalConversationId: canonicalConversationId,
    );
    final cached = _coordinatorCommitStates[memoryKey];
    if (cached != null) {
      return cached;
    }
    final state = _CoordinatorCommitState();
    if (!_useMemoryOnly) {
      final db = await _openDb();
      _profileDurableStateQueries++;
      final rows = await db.query(
        _coordinatorStateTable,
        where: 'owner_user_id = ? AND canonical_conversation_id = ?',
        whereArgs: <Object?>[
          owner,
          _coordinatorCanonicalKey(canonicalConversationId),
        ],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final row = rows.first;
        state.generation = row['generation'] as int? ?? 0;
        state.tombstoneGeneration = row['tombstone_generation'] as int?;
        try {
          final decoded = jsonDecode(
            row['idempotency_keys_json']?.toString() ?? '[]',
          );
          if (decoded is List) {
            state.idempotencyKeys.addAll(
              decoded.map((value) => value.toString()).where(
                    (value) => value.isNotEmpty,
                  ),
            );
          }
        } catch (_) {}
      }
    }
    _coordinatorCommitStates[memoryKey] = state;
    return state;
  }

  Future<ConversationCoordinatorDurableState> coordinatorDurableState({
    required String ownerUserId,
    required String conversationId,
  }) async {
    final owner = ownerUserId.trim();
    final id = conversationId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return const ConversationCoordinatorDurableState(
        generation: 0,
        tombstoned: false,
      );
    }
    final state = await _loadCoordinatorCommitState(
      owner: owner,
      canonicalConversationId: id,
    );
    return ConversationCoordinatorDurableState(
      generation: state.generation,
      tombstoned: state.tombstoneGeneration != null,
    );
  }

  Future<Map<String, ConversationCoordinatorDurableState>>
      coordinatorDurableStates({
    required String ownerUserId,
    required Iterable<String> conversationIds,
  }) async {
    final owner = ownerUserId.trim();
    final ids = conversationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (owner.isEmpty || ids.isEmpty) {
      return const <String, ConversationCoordinatorDurableState>{};
    }
    final stateByCanonical = <String, _CoordinatorCommitState>{};
    final missingCanonical = <String>{};
    for (final id in ids) {
      final canonical = _coordinatorCanonicalKey(id);
      final cached = _coordinatorCommitStates[_coordinatorCommitKey(
        owner: owner,
        canonicalConversationId: canonical,
      )];
      if (cached == null) {
        missingCanonical.add(canonical);
      } else {
        stateByCanonical[canonical] = cached;
      }
    }
    if (!_useMemoryOnly && missingCanonical.isNotEmpty) {
      final db = await _openDb();
      const chunkSize = 400;
      final canonicalIds = missingCanonical.toList(growable: false);
      for (var offset = 0; offset < canonicalIds.length; offset += chunkSize) {
        final chunk = canonicalIds.sublist(
          offset,
          offset + chunkSize > canonicalIds.length
              ? canonicalIds.length
              : offset + chunkSize,
        );
        final placeholders = List.filled(chunk.length, '?').join(',');
        _profileDurableStateQueries++;
        final rows = await db.query(
          _coordinatorStateTable,
          where: 'owner_user_id = ? AND canonical_conversation_id IN '
              '($placeholders)',
          whereArgs: <Object?>[owner, ...chunk],
        );
        for (final row in rows) {
          final canonical = row['canonical_conversation_id']?.toString() ?? '';
          if (canonical.isEmpty) continue;
          final state = _coordinatorStateFromRow(row);
          stateByCanonical[canonical] = state;
          _coordinatorCommitStates[_coordinatorCommitKey(
            owner: owner,
            canonicalConversationId: canonical,
          )] = state;
        }
      }
    }
    for (final canonical in missingCanonical) {
      stateByCanonical.putIfAbsent(canonical, _CoordinatorCommitState.new);
      _coordinatorCommitStates.putIfAbsent(
        _coordinatorCommitKey(
          owner: owner,
          canonicalConversationId: canonical,
        ),
        () => stateByCanonical[canonical]!,
      );
    }
    return <String, ConversationCoordinatorDurableState>{
      for (final id in ids)
        id: ConversationCoordinatorDurableState(
          generation:
              stateByCanonical[_coordinatorCanonicalKey(id)]?.generation ?? 0,
          tombstoned: stateByCanonical[_coordinatorCanonicalKey(id)]
                  ?.tombstoneGeneration !=
              null,
        ),
    };
  }

  _CoordinatorCommitState _coordinatorStateFromRow(
    Map<String, Object?> row,
  ) {
    final state = _CoordinatorCommitState()
      ..generation = row['generation'] as int? ?? 0
      ..tombstoneGeneration = row['tombstone_generation'] as int?;
    try {
      final decoded = jsonDecode(
        row['idempotency_keys_json']?.toString() ?? '[]',
      );
      if (decoded is List) {
        state.idempotencyKeys.addAll(
          decoded
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty),
        );
      }
    } catch (_) {}
    return state;
  }

  Map<String, Object?> _coordinatorStateRow({
    required String owner,
    required String canonicalConversationId,
    required _CoordinatorCommitState state,
  }) {
    const retainedIdempotencyKeyCount = 64;
    final keys = state.idempotencyKeys.toList(growable: false);
    final boundedKeys = keys.length <= retainedIdempotencyKeyCount
        ? keys
        : keys.sublist(keys.length - retainedIdempotencyKeyCount);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final tombstoned = state.tombstoneGeneration != null;
    return <String, Object?>{
      'owner_user_id': owner,
      'canonical_conversation_id':
          _coordinatorCanonicalKey(canonicalConversationId),
      'generation': state.generation,
      'tombstone_generation': state.tombstoneGeneration,
      'idempotency_keys_json': jsonEncode(boundedKeys),
      'removed_at': tombstoned ? now : 0,
      'reason': tombstoned ? 'coordinator_delete' : '',
      // Tombstones are intentionally durable. A later explicit recreate clears
      // them; startup must never expire them by scanning the whole table.
      'expires_at': 0,
      'updated_at': now,
    };
  }

  Future<void> _persistCoordinatorCommitState({
    required String owner,
    required String canonicalConversationId,
    required _CoordinatorCommitState state,
  }) async {
    if (_useMemoryOnly) {
      return;
    }
    _profileCoordinatorStateWrites++;
    final db = await _openDb();
    await db.insert(
      _coordinatorStateTable,
      _coordinatorStateRow(
        owner: owner,
        canonicalConversationId: canonicalConversationId,
        state: state,
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  int? _findConversationIndex(
    List<V2TimConversation> conversations,
    String conversationId,
  ) {
    for (var i = 0; i < conversations.length; i++) {
      if (MessageConversationId.sameConversation(
        conversations[i].conversationID,
        conversationId,
      )) {
        return i;
      }
    }
    return null;
  }

  Future<Map<String, Object?>?> _findPersistedConversationRow(
    DatabaseExecutor executor, {
    required String owner,
    required String conversationId,
  }) async {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return null;
    }
    final exact = await executor.query(
      _table,
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [owner, id],
      limit: 1,
    );
    if (exact.isNotEmpty) {
      return exact.first;
    }
    final lower = id.toLowerCase();
    if (!lower.startsWith('group_') &&
        !ChatIdFormat.isIMGroupOrCommunityId(id)) {
      return null;
    }
    final rows = await executor.query(
      _table,
      where: 'owner_user_id = ? AND conv_type = ?',
      whereArgs: [owner, 2],
    );
    for (final row in rows) {
      final storedId = row['conversation_id']?.toString() ?? '';
      if (MessageConversationId.sameConversation(storedId, id)) {
        return row;
      }
    }
    return null;
  }

  void _recordReadCleared(String owner, String conversationId, int atMs) {
    final key = _readClearCacheKey(owner, conversationId);
    _readClearedAtMs[key] = atMs;
    _scheduleWebMetaPersist(owner);
  }

  /// 同步写入已读锚点和版本缓存（不写 DB）。SDK 延迟快照与本地清零
  /// 必须在同一个版本域比较，不能只依赖一个短时间宽限窗。
  ConversationReadBarrier? recordReadClearedAnchor(
    String conversationID, {
    String? ownerUserId,
    String? lastMessageId,
    int? lastMessageTimestamp,
    int? lastMessageSeq,
    int? orderKey,
  }) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _recordReadCleared(owner, id, now);
    final current = _conversationFor(owner, id);
    final resolvedLastMessageId =
        lastMessageId?.trim() ?? current?.lastMessage?.msgID?.trim() ?? '';
    if (resolvedLastMessageId.isNotEmpty) {
      _readClearedLastMsgId[_readClearCacheKey(owner, id)] =
          resolvedLastMessageId;
    }
    final timestamp =
        lastMessageTimestamp ?? current?.lastMessage?.timestamp ?? 0;
    final seq = lastMessageSeq ??
        int.tryParse(current?.lastMessage?.seq?.trim() ?? '') ??
        0;
    final order = orderKey ?? current?.orderkey ?? 0;
    final key = _readClearCacheKey(owner, id);
    final previous = _readBarriers[key];
    // `orderkey` is a sorting token, not evidence of a newer message. Keep it
    // out of the read-watermark clock so an old SDK page cannot consume this
    // barrier merely by carrying a larger sort key.
    final baseVersion = timestamp;
    final version = <int>[
      baseVersion + 1,
      (previous?.version ?? 0) + 1,
      1,
    ].reduce((left, right) => left > right ? left : right);
    final barrier = ConversationReadBarrier(
      version: version,
      recordedAtMs: now,
      lastMessageId: resolvedLastMessageId,
      lastMessageTimestamp: timestamp,
      lastMessageSeq: seq,
      orderKey: order,
    );
    _readBarriers[key] = barrier;
    return barrier;
  }

  V2TimConversation? _conversationFor(String owner, String conversationId) {
    final list = _memoryByOwner[owner];
    if (list == null) {
      return null;
    }
    for (final conversation in list) {
      if (!MessageConversationId.sameConversation(
        conversation.conversationID,
        conversationId,
      )) {
        continue;
      }
      return conversation;
    }
    return null;
  }

  ConversationReadBarrier? readBarrierFor(
    String conversationID, {
    String? ownerUserId,
  }) {
    final id = conversationID.trim();
    final owner = _resolveOwner(ownerUserId);
    if (id.isEmpty || owner.isEmpty) {
      return null;
    }
    final direct = _readBarriers[_readClearCacheKey(owner, id)];
    if (direct != null) {
      return direct;
    }
    for (final entry in _readBarriers.entries) {
      final separator = entry.key.indexOf('|');
      if (separator < 0 || entry.key.substring(0, separator) != owner) {
        continue;
      }
      if (MessageConversationId.sameConversation(
        entry.key.substring(separator + 1),
        id,
      )) {
        return entry.value;
      }
    }
    return null;
  }

  /// Applies the read barrier before an SDK row enters the mutation
  /// coordinator and returns the minimum source version for that SDK event.
  /// A replay keeps unread at zero; a provably newer message consumes the
  /// barrier and receives a version above it.
  int resolveSdkUnreadAgainstReadBarrier(
    V2TimConversation incoming, {
    String? ownerUserId,
  }) {
    final id = incoming.conversationID.trim();
    final owner = _resolveOwner(ownerUserId);
    if (id.isEmpty || owner.isEmpty) {
      return 0;
    }
    final barrier = readBarrierFor(id, ownerUserId: owner);
    if (barrier == null) {
      return 0;
    }
    final incomingMessage = incoming.lastMessage;
    final incomingId = incomingMessage?.msgID?.trim() ?? '';
    final incomingTimestamp = incomingMessage?.timestamp ?? 0;
    final incomingSeq = int.tryParse(incomingMessage?.seq?.trim() ?? '') ?? 0;
    final exactReplay = barrier.lastMessageId.isNotEmpty &&
        incomingId.isNotEmpty &&
        barrier.lastMessageId == incomingId;
    final advanced = !exactReplay &&
        (incomingSeq > barrier.lastMessageSeq && incomingSeq > 0 ||
            incomingTimestamp > barrier.lastMessageTimestamp);
    if (advanced) {
      _clearReadCleared(owner, id);
      return barrier.version + 1;
    }
    if ((incoming.unreadCount ?? 0) > 0 || exactReplay) {
      incoming.unreadCount = 0;
      ConversationUnreadTrace.log(
        'sdk_unread_rejected_by_version_anchor',
        conversationID: id,
        unreadAfter: 0,
        extras: <String, Object?>{
          'barrierVersion': barrier.version,
          'anchorMessageId': barrier.lastMessageId,
          'incomingMessageId': incomingId,
        },
      );
    }
    return barrier.version;
  }

  void _clearReadCleared(String owner, String conversationId) {
    final key = _readClearCacheKey(owner, conversationId);
    _readClearedAtMs.remove(key);
    _readClearedLastMsgId.remove(key);
    _readBarriers.remove(key);
    _readBarriers.removeWhere((candidate, _) {
      final separator = candidate.indexOf('|');
      return separator >= 0 &&
          candidate.substring(0, separator) == owner &&
          MessageConversationId.sameConversation(
            candidate.substring(separator + 1),
            conversationId,
          );
    });
    _scheduleWebMetaPersist(owner);
  }

  String _historyClearCacheKey(String owner, String conversationId) =>
      '$owner|$conversationId';

  /// 清空水位按裸 ID / c2c_ / group_ 多别名写入，避免 SDK 回调 ID 形态
  /// 与本地写入不一致时保壳失效（归档会话清空后从列表消失）。
  Set<String> _historyClearIdCandidates(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return const <String>{};
    }
    final candidates = <String>{id};
    if (id.startsWith('c2c_') || id.startsWith('group_')) {
      candidates.add(id.startsWith('c2c_') ? id.substring(4) : id.substring(6));
    } else {
      candidates.add('c2c_$id');
      candidates.add('group_$id');
    }
    final normalized = MessageConversationId.normalizeComparableKey(id);
    if (normalized.isNotEmpty) {
      candidates.add(normalized);
    }
    return candidates;
  }

  void _recordHistoryCleared(String owner, String conversationId, int atMs) {
    for (final candidate in _historyClearIdCandidates(conversationId)) {
      _historyClearedAtMs[_historyClearCacheKey(owner, candidate)] = atMs;
    }
    _scheduleWebMetaPersist(owner);
  }

  void _clearHistoryCleared(String owner, String conversationId) {
    for (final candidate in _historyClearIdCandidates(conversationId)) {
      _historyClearedAtMs.remove(_historyClearCacheKey(owner, candidate));
    }
    _scheduleWebMetaPersist(owner);
  }

  Future<void> _ensureWebMetaHydrated(String owner) async {
    if (!_useMemoryOnly || owner.isEmpty) {
      return;
    }
    if (_webMetaHydratedOwners.contains(owner)) {
      return;
    }
    _webMetaHydratedOwners.add(owner);
    final snapshot = await WebConversationMetaStore.instance.load(owner);
    if (snapshot == null) {
      return;
    }
    snapshot.historyClearedAtMs.forEach((conversationId, atMs) {
      if (atMs > 0) {
        _recordHistoryClearedWithoutPersist(owner, conversationId, atMs);
      }
    });
    snapshot.readClearedAtMs.forEach((conversationId, atMs) {
      if (atMs > 0) {
        _recordReadClearedWithoutPersist(owner, conversationId, atMs);
      }
    });
    snapshot.readClearedLastMsgId.forEach((conversationId, msgId) {
      if (msgId.isNotEmpty) {
        _readClearedLastMsgId[_readClearCacheKey(owner, conversationId)] =
            msgId;
      }
    });
  }

  void _recordHistoryClearedWithoutPersist(
    String owner,
    String conversationId,
    int atMs,
  ) {
    for (final candidate in _historyClearIdCandidates(conversationId)) {
      _historyClearedAtMs[_historyClearCacheKey(owner, candidate)] = atMs;
    }
  }

  void _recordReadClearedWithoutPersist(
    String owner,
    String conversationId,
    int atMs,
  ) {
    _readClearedAtMs[_readClearCacheKey(owner, conversationId)] = atMs;
  }

  void _scheduleWebMetaPersist(String owner) {
    if (!_useMemoryOnly || owner.isEmpty) {
      return;
    }
    _webMetaPersistOwner = owner;
    _webMetaPersistTimer?.cancel();
    _webMetaPersistTimer = Timer(const Duration(milliseconds: 200), () {
      final target = _webMetaPersistOwner;
      if (target == null || target.isEmpty) {
        return;
      }
      unawaited(_persistWebMeta(target));
    });
  }

  Future<void> _persistWebMeta(String owner) async {
    if (!_useMemoryOnly || owner.isEmpty) {
      return;
    }
    final prefix = '$owner|';
    final historyClearedAtMs = <String, int>{};
    _historyClearedAtMs.forEach((key, value) {
      if (key.startsWith(prefix) && value > 0) {
        historyClearedAtMs[key.substring(prefix.length)] = value;
      }
    });
    final readClearedAtMs = <String, int>{};
    _readClearedAtMs.forEach((key, value) {
      if (key.startsWith(prefix) && value > 0) {
        readClearedAtMs[key.substring(prefix.length)] = value;
      }
    });
    final readClearedLastMsgId = <String, String>{};
    _readClearedLastMsgId.forEach((key, value) {
      if (key.startsWith(prefix) && value.isNotEmpty) {
        readClearedLastMsgId[key.substring(prefix.length)] = value;
      }
    });
    await WebConversationMetaStore.instance.save(
      owner,
      WebConversationMetaSnapshot(
        historyClearedAtMs: historyClearedAtMs,
        readClearedAtMs: readClearedAtMs,
        readClearedLastMsgId: readClearedLastMsgId,
      ),
    );
  }

  int _resolvedHistoryClearedAtMs({
    required String owner,
    required String conversationId,
    required int rowHistoryClearedAtMs,
  }) {
    for (final candidate in _historyClearIdCandidates(conversationId)) {
      final cached =
          _historyClearedAtMs[_historyClearCacheKey(owner, candidate)];
      if (cached != null && cached > 0) {
        return cached;
      }
    }
    return rowHistoryClearedAtMs;
  }

  bool _shouldPreferNullLastMessage({
    required V2TimMessage? existing,
    required int historyClearedAtMs,
  }) {
    if (historyClearedAtMs <= 0) {
      return false;
    }
    if (existing == null) {
      return true;
    }
    final ts = existing.timestamp ?? 0;
    if (ts <= 0) {
      return true;
    }
    final existingMs = ts < 1000000000000 ? ts * 1000 : ts;
    return historyClearedAtMs >= existingMs;
  }

  int _historyClearedAtForPersistedRow({
    required String owner,
    required String conversationId,
    required V2TimConversation incoming,
    required int existingHistoryClearedAtMs,
  }) {
    final resolved = _resolvedHistoryClearedAtMs(
      owner: owner,
      conversationId: conversationId,
      rowHistoryClearedAtMs: existingHistoryClearedAtMs,
    );
    final incomingLast = incoming.lastMessage;
    if (incomingLast == null) {
      return resolved;
    }
    final incomingMs = lastMessageTimestampMs(incoming);
    if (resolved > 0 && incomingMs > resolved) {
      _clearHistoryCleared(owner, conversationId);
      return 0;
    }
    return resolved;
  }

  int _resolvedReadClearedAtMs({
    required String owner,
    required String conversationId,
    required int rowReadClearedAtMs,
  }) {
    final direct = _readClearedAtMs[_readClearCacheKey(owner, conversationId)];
    if (direct != null && direct > 0) {
      return direct;
    }
    // Canonical writes already share one key. This fallback accepts pre-102
    // Web/meta aliases until the next local read clears them canonically.
    for (final entry in _readClearedAtMs.entries) {
      final separator = entry.key.indexOf('|');
      if (separator < 0 || entry.key.substring(0, separator) != owner) {
        continue;
      }
      if (entry.value > 0 &&
          MessageConversationId.sameConversation(
            entry.key.substring(separator + 1),
            conversationId,
          )) {
        return entry.value;
      }
    }
    return rowReadClearedAtMs;
  }

  String? _resolvedReadClearedLastMessageId({
    required String owner,
    required String conversationId,
  }) {
    final direct =
        _readClearedLastMsgId[_readClearCacheKey(owner, conversationId)];
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final id = conversationId.trim();
    if (id.startsWith('group_') || id.startsWith('c2c_')) {
      final bare = id.startsWith('group_') ? id.substring(6) : id.substring(4);
      final alias = _readClearedLastMsgId[_readClearCacheKey(owner, bare)];
      if (alias != null && alias.isNotEmpty) {
        return alias;
      }
    }
    return null;
  }

  /// Read anchor used by the conversation-list merge gate. This is kept
  /// synchronous because SDK conversation callbacks are applied on the UI
  /// isolate before the persistence transaction completes.
  String? readClearedLastMessageIdFor(
    String conversationID, {
    String? ownerUserId,
  }) {
    final id = conversationID.trim();
    final owner = _resolveOwner(ownerUserId);
    if (id.isEmpty || owner.isEmpty) {
      return null;
    }
    return _resolvedReadClearedLastMessageId(
      owner: owner,
      conversationId: id,
    );
  }

  /// 公开读取 read cleared 时间戳（供 ConversationUnreadGuard 宽限判定）。
  int readClearedAtFor(
    String conversationID, {
    String? ownerUserId,
  }) {
    final id = conversationID.trim();
    final owner = _resolveOwner(ownerUserId);
    if (id.isEmpty || owner.isEmpty) {
      return 0;
    }
    return _resolvedReadClearedAtMs(
      owner: owner,
      conversationId: id,
      rowReadClearedAtMs: 0,
    );
  }

  int _readClearedAtForPersistedRow({
    required String owner,
    required String conversationId,
    required V2TimConversation conversation,
    required int existingReadClearedAtMs,
  }) {
    final resolved = _resolvedReadClearedAtMs(
      owner: owner,
      conversationId: conversationId,
      rowReadClearedAtMs: existingReadClearedAtMs,
    );
    if (ForegroundChatGuard.isActiveConversation(conversationId)) {
      conversation.unreadCount = 0;
      return resolved > 0 ? resolved : existingReadClearedAtMs;
    }
    // `unreadCount > 0` has no message identity and must never consume the
    // barrier before the shared snapshot adjudicator compares its anchor.
    return resolved;
  }

  bool _withinLocalReadGrace(int readClearedAtMs) {
    if (readClearedAtMs <= 0) {
      return false;
    }
    return DateTime.now().toUtc().millisecondsSinceEpoch - readClearedAtMs <
        _localReadGraceMs;
  }

  bool isWithinReadGrace(int readClearedAtMs) {
    return _withinLocalReadGrace(readClearedAtMs);
  }

  static int lastMessageTimestampMs(V2TimConversation conversation) {
    final ts = conversation.lastMessage?.timestamp ?? 0;
    if (ts <= 0) {
      return 0;
    }
    return ts < 1000000000000 ? ts * 1000 : ts;
  }

  static int messageTimestampMs(V2TimMessage? message) {
    final ts = message?.timestamp ?? 0;
    if (ts <= 0) {
      return 0;
    }
    return ts < 1000000000000 ? ts * 1000 : ts;
  }

  /// 会话清空水位（毫秒）。无则返回 0。供进页 peek 过滤旧消息。
  Future<void> preloadHistoryClearIndex({String? ownerUserId}) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    await _ensureHistoryClearIndexHydrated(owner);
  }

  Future<void> _ensureHistoryClearIndexHydrated(String owner) async {
    if (_historyClearIndexHydratedOwners.contains(owner)) {
      return;
    }
    final existing = _historyClearIndexInFlightByOwner[owner];
    if (existing != null) {
      await existing;
      return;
    }
    final generation = _historyClearIndexGeneration;
    final task = () async {
      if (_useMemoryOnly) {
        await _ensureWebMetaHydrated(owner);
      } else {
        final db = await _openDb();
        final rows = await db.query(
          _table,
          columns: const <String>['conversation_id', 'history_cleared_at'],
          where: 'owner_user_id = ? AND history_cleared_at > 0',
          whereArgs: <Object?>[owner],
        );
        if (generation != _historyClearIndexGeneration) {
          return;
        }
        for (final row in rows) {
          final conversationId = row['conversation_id']?.toString() ?? '';
          final atMs = row['history_cleared_at'] as int? ?? 0;
          if (conversationId.isNotEmpty && atMs > 0) {
            _recordHistoryClearedWithoutPersist(owner, conversationId, atMs);
          }
        }
      }
      if (generation == _historyClearIndexGeneration) {
        _historyClearIndexHydratedOwners.add(owner);
      }
    }();
    _historyClearIndexInFlightByOwner[owner] = task;
    try {
      await task;
    } finally {
      if (identical(_historyClearIndexInFlightByOwner[owner], task)) {
        _historyClearIndexInFlightByOwner.remove(owner);
      }
    }
  }

  Future<int> historyClearedAtMs(
    String conversationID, {
    String? ownerUserId,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return 0;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return 0;
    }
    final candidates = <String>{id};
    if (id.startsWith('c2c_') || id.startsWith('group_')) {
      candidates.add(id.startsWith('c2c_') ? id.substring(4) : id.substring(6));
    } else {
      candidates.add('c2c_$id');
      candidates.add('group_$id');
    }
    for (final candidate in candidates) {
      final cached =
          _historyClearedAtMs[_historyClearCacheKey(owner, candidate)];
      if (cached != null && cached > 0) {
        return cached;
      }
    }
    await _ensureHistoryClearIndexHydrated(owner);
    for (final candidate in candidates) {
      final cached =
          _historyClearedAtMs[_historyClearCacheKey(owner, candidate)];
      if (cached != null && cached > 0) {
        return cached;
      }
    }
    return 0;
  }

  bool shouldSuppressConversationDeletionAfterHistoryClear(
    String conversationID,
  ) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return false;
    }
    if (ArchiveHistoryProvider.isHistoryClearPending(id)) {
      return true;
    }
    final owner = _resolveOwner(null);
    if (owner.isEmpty) {
      return false;
    }
    final historyClearedAtMs = _resolvedHistoryClearedAtMs(
      owner: owner,
      conversationId: id,
      rowHistoryClearedAtMs: 0,
    );
    return historyClearedAtMs > 0;
  }

  Future<bool> shouldSuppressConversationDeletionAfterHistoryClearAsync(
    String conversationID,
  ) async {
    if (shouldSuppressConversationDeletionAfterHistoryClear(conversationID)) {
      return true;
    }
    final id = conversationID.trim();
    if (id.isEmpty) {
      return false;
    }
    final owner = _resolveOwner(null);
    if (owner.isEmpty || _useMemoryOnly) {
      return false;
    }
    final db = await _openDb();
    final row = await _findPersistedConversationRow(
      db,
      owner: owner,
      conversationId: id,
    );
    if (row == null) {
      return false;
    }
    final storedId = row['conversation_id']?.toString() ?? id;
    final historyClearedAtMs = _resolvedHistoryClearedAtMs(
      owner: owner,
      conversationId: storedId,
      rowHistoryClearedAtMs: row['history_cleared_at'] as int? ?? 0,
    );
    return historyClearedAtMs > 0;
  }

  String currentOwnerUserId() {
    return ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
  }

  @visibleForTesting
  String? debugOwnerUserId;

  String _resolveOwner(String? ownerUserId) {
    final explicit = ChatIdFormat.rawUserUid(ownerUserId);
    if (explicit.isNotEmpty) {
      return explicit;
    }
    // Non-null debug override wins even when empty (tests: force no-owner
    // without touching login / SharedPreferences).
    if (debugOwnerUserId != null) {
      return debugOwnerUserId!.trim();
    }
    return currentOwnerUserId();
  }

  /// Public owner resolution used by unread aggregate refresh gates.
  /// Same order as [_resolveOwner]: explicit → debug override → login id.
  String resolvedOwnerUserId({String? ownerUserId}) =>
      _resolveOwner(ownerUserId);

  bool get _useMemoryOnly => kIsWeb;

  static int activeTimeMs(V2TimConversation conversation) {
    final draft = conversation.draftTimestamp ?? 0;
    final last = conversation.lastMessage?.timestamp ?? 0;
    final raw = draft != 0 ? draft : last;
    if (raw <= 0) {
      return conversation.orderkey ?? 0;
    }
    return raw >= 1000000000000 ? raw : raw * 1000;
  }

  /// 触底/触顶分页游标：优先用「会话 ID → 库列 active_time」缓存，
  /// 与 `loadOlderPage` / `ORDER BY active_time` 同口径。
  ///
  /// 必须用 ID Map 而非 Expando：列表合并/解码会换新对象，Expando 一丢就
  /// 退回 lastMessage，游标卡死在错误边上（日志里反复同一 cursor + 全靠 OFFSET）。
  static int pagingAnchorMs(V2TimConversation conversation) {
    final id = conversation.conversationID.trim();
    if (id.isNotEmpty) {
      final remembered =
          ConversationLocalStore.instance._pagingActiveTimeById[id];
      if (remembered != null && remembered > 0) {
        return remembered;
      }
    }
    return activeTimeMs(conversation);
  }

  final Map<String, int> _pagingActiveTimeById = <String, int>{};

  void rememberPagingActiveTime(
    V2TimConversation conversation,
    int activeTimeMsValue,
  ) {
    final id = conversation.conversationID.trim();
    if (id.isEmpty || activeTimeMsValue <= 0) {
      return;
    }
    _pagingActiveTimeById[id] = activeTimeMsValue;
  }

  /// 在候选集中取「库序最旧」边：active_time 最小；同刻取 conversation_id 最大
  ///（与 `loadOlderPage` 的 `id > cursor` 一致）。
  static V2TimConversation? oldestPagingCursor(
    Iterable<V2TimConversation> conversations,
  ) {
    V2TimConversation? best;
    var bestTime = 0;
    for (final conversation in conversations) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      final time = pagingAnchorMs(conversation);
      if (best == null) {
        best = conversation;
        bestTime = time;
        continue;
      }
      if (time < bestTime ||
          (time == bestTime && id.compareTo(best.conversationID.trim()) > 0)) {
        best = conversation;
        bestTime = time;
      }
    }
    return best;
  }

  /// 在候选集中取「库序最新」边：active_time 最大；同刻取 conversation_id 最小
  ///（与 `loadNewerPage` 的 `id < cursor` 一致）。
  static V2TimConversation? newestPagingCursor(
    Iterable<V2TimConversation> conversations,
  ) {
    V2TimConversation? best;
    var bestTime = 0;
    for (final conversation in conversations) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      final time = pagingAnchorMs(conversation);
      if (best == null) {
        best = conversation;
        bestTime = time;
        continue;
      }
      if (time > bestTime ||
          (time == bestTime && id.compareTo(best.conversationID.trim()) < 0)) {
        best = conversation;
        bestTime = time;
      }
    }
    return best;
  }

  /// 列表排序/时间展示用的锚点：清空预览后仍保留原活跃时间。
  static int displayTimestampMs(V2TimConversation conversation) {
    final draft = conversation.draftTimestamp ?? 0;
    if (draft != 0) {
      return draft >= 1000000000000 ? draft : draft * 1000;
    }
    final last = messageTimestampMs(conversation.lastMessage);
    if (last > 0) {
      return last;
    }
    return activeTimeMs(conversation);
  }

  static int? displayTimestampSec(V2TimConversation conversation) {
    final ms = displayTimestampMs(conversation);
    if (ms <= 0) {
      return null;
    }
    return ms ~/ 1000;
  }

  static int _maxNonNegative(int a, int b) => a > b ? a : b;

  int _resolveSortAnchorMs({
    required V2TimConversation conversation,
    int rowOrderKey = 0,
    int rowActiveTimeMs = 0,
  }) {
    final fromConversation = activeTimeMs(conversation);
    final fromLastMessage = messageTimestampMs(conversation.lastMessage);
    final fromOrderKey = conversation.orderkey ?? 0;
    var anchor = 0;
    anchor = _maxNonNegative(anchor, rowOrderKey);
    anchor = _maxNonNegative(anchor, rowActiveTimeMs);
    anchor = _maxNonNegative(anchor, fromOrderKey);
    anchor = _maxNonNegative(anchor, fromConversation);
    anchor = _maxNonNegative(anchor, fromLastMessage);
    return anchor;
  }

  void _preserveConversationSortAnchor(
    V2TimConversation existing,
    V2TimConversation incoming,
  ) {
    final anchor = _resolveSortAnchorMs(conversation: existing);
    if (anchor <= 0) {
      return;
    }
    incoming.orderkey = _maxNonNegative(incoming.orderkey ?? 0, anchor);
  }

  /// 非 UI / 兼容全表读取（不做 hardCap trim）。
  /// UI 热路径请用 [loadUiWindow]（scope 限量快照 + 可选 hardCap trim）/ [loadOlderPage]。
  @Deprecated('Use loadUiWindow / loadOlderPage for UI hot paths')
  Future<List<V2TimConversation>> loadAsV2TimConversations({
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return const [];
    }
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      for (final conversation in list) {
        _applyBackendPinnedFlag(conversation);
        _decorateConversation(conversation);
      }
      list.sort(_sortConversations);
      return list;
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ?',
      whereArgs: [owner],
      orderBy: 'is_pinned DESC, active_time DESC, order_key DESC',
    );
    final conversations = <V2TimConversation>[];
    for (final row in rows) {
      final conversation = _conversationFromRow(row);
      if (conversation == null) {
        continue;
      }
      _applyBackendPinnedFlag(conversation);
      _decorateConversation(conversation);
      conversations.add(conversation);
    }
    conversations.sort(_sortConversations);
    return conversations;
  }

  Future<int> countRows({String? ownerUserId}) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return 0;
    }
    if (_useMemoryOnly) {
      return _memoryByOwner[owner]?.length ?? 0;
    }
    final db = await _openDb();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE owner_user_id = ?',
      [owner],
    );
    return _asInt(rows.first['c']);
  }

  Future<List<V2TimConversation>> loadUiWindow({String? ownerUserId}) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return const [];
    }
    if (!ConversationPerfFlags.loadUiWindowSingleFlight) {
      return _loadUiWindowOnce(owner);
    }
    // 脏合并：飞行中再来请求只记 dirty，leader 结束后最多再跑一轮，
    // 所有等待方拿到最终快照（压冷启连环 begin）。
    if (ConversationPerfFlags.loadUiWindowCoalesceWhileBusy) {
      _loadUiWindowDirty = true;
      final existingLeader = _loadUiWindowLeader;
      if (existingLeader != null) {
        ConversationPerfGateLog.log(
          'load_ui_window_single_flight_join',
          extras: <String, Object?>{
            'gen': _loadUiWindowGeneration,
            'dirty': 1,
          },
        );
        return existingLeader.future;
      }
      final leader = Completer<List<V2TimConversation>>();
      _loadUiWindowLeader = leader;
      unawaited(() async {
        List<V2TimConversation> last = const [];
        try {
          while (_loadUiWindowDirty) {
            _loadUiWindowDirty = false;
            final gen = ++_loadUiWindowGeneration;
            final task = _loadUiWindowOnce(owner, gen: gen);
            _loadUiWindowInFlight = task;
            try {
              last = await task;
            } finally {
              if (identical(_loadUiWindowInFlight, task)) {
                _loadUiWindowInFlight = null;
              }
            }
          }
          if (!leader.isCompleted) {
            leader.complete(last);
          }
        } catch (e, st) {
          if (!leader.isCompleted) {
            leader.completeError(e, st);
          }
        } finally {
          if (identical(_loadUiWindowLeader, leader)) {
            _loadUiWindowLeader = null;
          }
          // 收尾瞬间又脏：再开一轮，避免丢请求。
          if (_loadUiWindowDirty) {
            unawaited(loadUiWindow(ownerUserId: owner));
          }
        }
      }());
      return leader.future;
    }
    final inFlight = _loadUiWindowInFlight;
    if (inFlight != null) {
      ConversationPerfGateLog.log(
        'load_ui_window_single_flight_join',
        extras: <String, Object?>{'gen': _loadUiWindowGeneration},
      );
      return inFlight;
    }
    final gen = ++_loadUiWindowGeneration;
    final task = _loadUiWindowOnce(owner, gen: gen);
    _loadUiWindowInFlight = task;
    try {
      return await task;
    } finally {
      if (identical(_loadUiWindowInFlight, task)) {
        _loadUiWindowInFlight = null;
      }
    }
  }

  Future<List<V2TimConversation>>? _loadUiWindowInFlight;
  Completer<List<V2TimConversation>>? _loadUiWindowLeader;
  bool _loadUiWindowDirty = false;
  int _loadUiWindowGeneration = 0;

  Future<List<V2TimConversation>> _loadUiWindowOnce(
    String owner, {
    int gen = 0,
  }) async {
    ConversationPerfGateLog.log(
      'load_ui_window_begin',
      extras: <String, Object?>{'gen': gen, 'joined': 0},
    );
    final token = SqfliteLockProfileLog.beginOp(
      dbTag: _dbName,
      op: 'loadUiWindow',
    );
    final started = DateTime.now().millisecondsSinceEpoch;
    try {
      if (ConversationPerfFlags.uiSnapshotEnabled) {
        return await _loadUiSnapshotWindow(owner);
      }
      return await _loadUiFullOwnerWindow(owner);
    } finally {
      SqfliteLockProfileLog.endOp(token);
      ConversationPerfGateLog.log(
        'load_ui_window_end',
        extras: <String, Object?>{
          'gen': gen,
          'costMs': DateTime.now().millisecondsSinceEpoch - started,
        },
      );
    }
  }

  /// 单聊/群聊各 LIMIT 后合并，禁止先全表再 trim。
  /// 置顶会话即使不在「最近 LIMIT」内也必须并入（登录后会话很多时常见）。
  Future<List<V2TimConversation>> _loadUiSnapshotWindow(String owner) async {
    final c2cLimit = ConversationPerfFlags.uiSnapshotC2cLimit;
    final groupLimit = ConversationPerfFlags.uiSnapshotGroupLimit;
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      for (final conversation in list) {
        _applyBackendPinnedFlag(conversation);
        _decorateConversation(conversation);
      }
      list.sort(_sortConversations);
      final c2c = <V2TimConversation>[];
      final group = <V2TimConversation>[];
      for (final conversation in list) {
        if (_resolvedStoredConvType(conversation) == 2) {
          if (group.length < groupLimit) {
            group.add(conversation);
          }
        } else if (c2c.length < c2cLimit) {
          c2c.add(conversation);
        }
        if (c2c.length >= c2cLimit && group.length >= groupLimit) {
          break;
        }
      }
      final merged = ConversationLocalStore.mergeConversationsForUi(
        c2c,
        group,
      );
      final withPins = await _ensurePinnedPresentInWindow(owner, merged);
      withPins.sort(_sortConversations);
      return _trimUiWindow(withPins);
    }

    final db = await _openDb();
    const orderBy = 'is_pinned DESC, active_time DESC, order_key DESC';
    final c2cRows = await db.query(
      _table,
      where: 'owner_user_id = ? AND conv_type = ?',
      whereArgs: [owner, 1],
      orderBy: orderBy,
      limit: c2cLimit,
    );
    final groupRows = await db.query(
      _table,
      where: 'owner_user_id = ? AND conv_type = ?',
      whereArgs: [owner, 2],
      orderBy: orderBy,
      limit: groupLimit,
    );
    final conversations = await _conversationsFromDbRows([
      ...c2cRows,
      ...groupRows,
    ]);
    final withPins = await _ensurePinnedPresentInWindow(owner, conversations);
    withPins.sort(_sortConversations);
    final window = _trimUiWindow(withPins);
    if (kDebugMode) {
      final c2cCount =
          window.where((c) => _resolvedStoredConvType(c) != 2).length;
      final groupCount =
          window.where((c) => _resolvedStoredConvType(c) == 2).length;
      final pinnedCount = window.where((c) => c.isPinned == true).length;
      debugPrint(
        'ConversationLocalStore: ui_window snapshot loaded '
        'c2c=$c2cCount/$c2cLimit group=$groupCount/$groupLimit '
        'pinned=$pinnedCount total=${window.length}',
      );
    }
    return window;
  }

  /// 自建置顶集合中、却落在 window 之外的会话，按 id 补进列表。
  Future<List<V2TimConversation>> ensurePinnedPresentInWindow(
    List<V2TimConversation> window, {
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return List<V2TimConversation>.from(window);
    }
    return _ensurePinnedPresentInWindow(owner, window);
  }

  /// 自建置顶集合中、却落在 snapshot LIMIT 之外的会话，按 id 补进首屏窗。
  ///
  /// 典型：会话很多 + `is_pinned` 列尚未对齐 / 置顶水合晚于首屏装载时，
  /// 仅靠 `ORDER BY is_pinned` 的 LIMIT 会漏掉冷置顶。
  Future<List<V2TimConversation>> _ensurePinnedPresentInWindow(
    String owner,
    List<V2TimConversation> window,
  ) async {
    final pinnedIds = ConversationPinSyncService.instance.pinnedConversationIds;
    final present = List<V2TimConversation>.from(window);
    for (final conversation in present) {
      _applyBackendPinnedFlag(conversation);
    }
    if (pinnedIds.isEmpty) {
      return present;
    }

    bool alreadyHave(String id) {
      for (final conversation in present) {
        if (MessageConversationId.sameConversation(
          conversation.conversationID,
          id,
        )) {
          return true;
        }
      }
      return false;
    }

    final missing = <String>[];
    for (final raw in pinnedIds) {
      final id = raw.trim();
      if (id.isEmpty || alreadyHave(id)) {
        continue;
      }
      missing.add(id);
    }
    if (missing.isEmpty) {
      return present;
    }

    final totalSw = Stopwatch()..start();
    var waitMs = 0;
    if (ConversationPerfFlags.ensurePinnedWaitsUpsertIdle) {
      final waitSw = Stopwatch()..start();
      await waitUntilUpsertWriteIdle(
        maxWait: ConversationPerfFlags.ensurePinnedUpsertIdleMaxWait,
      );
      waitMs = waitSw.elapsedMilliseconds;
    }

    final extras = await conversationsByIds(
      missing,
      ownerUserId: owner,
      phaseWaitMs: waitMs,
      phaseTotalSw: totalSw,
      caller: 'ensure_pinned',
    );
    for (final conversation in extras) {
      _applyBackendPinnedFlag(conversation);
      final id = conversation.conversationID.trim();
      if (id.isEmpty || alreadyHave(id)) {
        continue;
      }
      present.add(conversation);
    }
    return present;
  }

  Future<List<V2TimConversation>> _loadUiFullOwnerWindow(String owner) async {
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      for (final conversation in list) {
        _applyBackendPinnedFlag(conversation);
        _decorateConversation(conversation);
      }
      list.sort(_sortConversations);
      return _trimUiWindow(list);
    }

    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ?',
      whereArgs: [owner],
      orderBy: 'is_pinned DESC, active_time DESC, order_key DESC',
    );
    final conversations = await _conversationsFromDbRows(rows);
    conversations.sort(_sortConversations);
    return _trimUiWindow(conversations);
  }

  List<V2TimConversation> _trimUiWindow(List<V2TimConversation> sorted) {
    return trimUiWindowWithTypeFloors(sorted);
  }

  /// 总硬顶 + 单聊/群聊地板：先保两侧热门地板，余量按 UI 序填充。
  static List<V2TimConversation> trimUiWindowWithTypeFloors(
    List<V2TimConversation> sorted, {
    int? hardCap,
    int? c2cFloor,
    int? groupFloor,
  }) {
    if (!ConversationPerfFlags.uiWindowHardCapEnabled && hardCap == null) {
      return List<V2TimConversation>.from(sorted);
    }
    final cap = hardCap ?? ConversationPerfFlags.uiWindowHardCap;
    if (cap <= 0 || sorted.length <= cap) {
      return List<V2TimConversation>.from(sorted);
    }
    final c2cKeep = c2cFloor ?? ConversationPerfFlags.uiSnapshotC2cLimit;
    final groupKeep = groupFloor ?? ConversationPerfFlags.uiSnapshotGroupLimit;
    final c2c = <V2TimConversation>[];
    final group = <V2TimConversation>[];
    for (final conversation in sorted) {
      if (_isGroupConv(conversation)) {
        group.add(conversation);
      } else {
        c2c.add(conversation);
      }
    }
    final out = <V2TimConversation>[];
    final taken = <String>{};
    void takeFrom(List<V2TimConversation> src, int n) {
      var added = 0;
      for (final conversation in src) {
        if (added >= n || out.length >= cap) {
          break;
        }
        final id = conversation.conversationID.trim();
        if (id.isEmpty || taken.contains(id)) {
          continue;
        }
        out.add(conversation);
        taken.add(id);
        added++;
      }
    }

    takeFrom(c2c, c2cKeep);
    takeFrom(group, groupKeep);
    for (final conversation in sorted) {
      if (out.length >= cap) {
        break;
      }
      final id = conversation.conversationID.trim();
      if (id.isEmpty || taken.contains(id)) {
        continue;
      }
      out.add(conversation);
      taken.add(id);
    }
    out.sort(compareConversationsForUi);
    if (out.length <= cap) {
      return out;
    }
    return out.sublist(0, cap);
  }

  static bool _isGroupConv(V2TimConversation conversation) {
    final type = conversation.type ?? 0;
    if (type == 2) {
      return true;
    }
    if (type == 1) {
      return false;
    }
    final id = conversation.conversationID.trim();
    return id.startsWith('group_');
  }

  Future<List<V2TimConversation>> loadOlderPage({
    required int beforeActiveTime,
    required String beforeConversationId,
    int limit = ConversationPerfFlags.uiScrollPageSize,
    String? ownerUserId,

    /// `1` 单聊 / `2` 群聊；`null` 混排（兼容旧调用）。
    int? convType,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final beforeId = beforeConversationId.trim();
    if (owner.isEmpty || limit <= 0) {
      return const [];
    }
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      for (final conversation in list) {
        _applyBackendPinnedFlag(conversation);
        _decorateConversation(conversation);
      }
      list.sort(_sortConversations);
      final filtered = typeFilter == null
          ? list
          : list
              .where(
                (c) => typeFilter == 2 ? _isGroupConv(c) : !_isGroupConv(c),
              )
              .toList(growable: false);
      final idx = filtered.indexWhere((c) => c.conversationID == beforeId);
      if (idx < 0) {
        return filtered.take(limit).toList(growable: false);
      }
      final start = idx + 1;
      if (start >= filtered.length) {
        return const [];
      }
      final end =
          start + limit > filtered.length ? filtered.length : start + limit;
      return filtered.sublist(start, end);
    }

    final db = await _openDb();
    final rows = typeFilter == null
        ? await db.rawQuery(
            '''
      SELECT * FROM $_table
      WHERE owner_user_id = ?
        AND (
          active_time < ?
          OR (active_time = ? AND conversation_id > ?)
        )
      ORDER BY is_pinned DESC, active_time DESC, order_key DESC, conversation_id ASC
      LIMIT ?
      ''',
            [owner, beforeActiveTime, beforeActiveTime, beforeId, limit],
          )
        : await db.rawQuery(
            '''
      SELECT * FROM $_table
      WHERE owner_user_id = ?
        AND conv_type = ?
        AND (
          active_time < ?
          OR (active_time = ? AND conversation_id > ?)
        )
      ORDER BY is_pinned DESC, active_time DESC, order_key DESC, conversation_id ASC
      LIMIT ?
      ''',
            [
              owner,
              typeFilter,
              beforeActiveTime,
              beforeActiveTime,
              beforeId,
              limit,
            ],
          );
    return _conversationsFromDbRows(rows);
  }

  /// 按类型统计本地行数（触底空游标时判断库里是否还有未进窗的会话）。
  ///
  /// [excludeConversationIds]：原始归档 ID 集；会展开为 lookup token 后排除。
  Future<int> countByConvType({
    required int convType,
    String? ownerUserId,
    Set<String>? excludeConversationIds,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    if (owner.isEmpty || typeFilter == null) {
      return 0;
    }
    final excludeTokens = _archiveExcludeTokens(excludeConversationIds);
    if (_useMemoryOnly) {
      final list = _memoryByOwner[owner] ?? const <V2TimConversation>[];
      return list.where((c) {
        if (typeFilter == 2 ? !_isGroupConv(c) : _isGroupConv(c)) {
          return false;
        }
        if (excludeTokens.isEmpty) {
          return true;
        }
        return !conversationIdInArchivedLookup(
          excludeTokens,
          c.conversationID,
        );
      }).length;
    }
    final db = await _openDb();
    if (excludeTokens.isEmpty) {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $_table WHERE owner_user_id = ? AND conv_type = ?',
        [owner, typeFilter],
      );
      return _asInt(rows.first['c']);
    }
    return _countByConvTypeExcluding(db, owner, typeFilter, excludeTokens);
  }

  /// 置顶会话数（与虚拟列表库序一致；可排除归档）。
  Future<int> countPinnedByConvType({
    required int convType,
    String? ownerUserId,
    Set<String>? excludeConversationIds,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    if (owner.isEmpty || typeFilter == null) {
      return 0;
    }
    final excludeTokens = _archiveExcludeTokens(excludeConversationIds);
    if (_useMemoryOnly) {
      final list = _memoryByOwner[owner] ?? const <V2TimConversation>[];
      return list.where((c) {
        if (typeFilter == 2 ? !_isGroupConv(c) : _isGroupConv(c)) {
          return false;
        }
        if (c.isPinned != true) {
          return false;
        }
        if (excludeTokens.isEmpty) {
          return true;
        }
        return !conversationIdInArchivedLookup(
          excludeTokens,
          c.conversationID,
        );
      }).length;
    }
    final db = await _openDb();
    if (excludeTokens.isEmpty) {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $_table '
        'WHERE owner_user_id = ? AND conv_type = ? AND is_pinned = 1',
        [owner, typeFilter],
      );
      return _asInt(rows.first['c']);
    }
    return _withExcludeQueryLock(() async {
      await _fillExcludeArchivedTemp(db, excludeTokens);
      try {
        final rows = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM $_table c '
          'WHERE c.owner_user_id = ? AND c.conv_type = ? AND c.is_pinned = 1 '
          'AND NOT EXISTS (SELECT 1 FROM $_excludeArchivedTemp e WHERE e.id = c.conversation_id)',
          [owner, typeFilter],
        );
        return _asInt(rows.first['c']);
      } finally {
        await db.delete(_excludeArchivedTemp);
      }
    });
  }

  /// 非置顶且 active_time 严格大于 [thresholdActiveTimeMs] 的会话数。
  Future<int> countNonPinnedNewerThanByConvType({
    required int convType,
    required int thresholdActiveTimeMs,
    String? ownerUserId,
    Set<String>? excludeConversationIds,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    if (owner.isEmpty || typeFilter == null) {
      return 0;
    }
    final excludeTokens = _archiveExcludeTokens(excludeConversationIds);
    if (_useMemoryOnly) {
      final list = _memoryByOwner[owner] ?? const <V2TimConversation>[];
      return list.where((c) {
        if (typeFilter == 2 ? !_isGroupConv(c) : _isGroupConv(c)) {
          return false;
        }
        if (c.isPinned == true) {
          return false;
        }
        if (activeTimeMs(c) <= thresholdActiveTimeMs) {
          return false;
        }
        if (excludeTokens.isEmpty) {
          return true;
        }
        return !conversationIdInArchivedLookup(
          excludeTokens,
          c.conversationID,
        );
      }).length;
    }
    final db = await _openDb();
    if (excludeTokens.isEmpty) {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $_table '
        'WHERE owner_user_id = ? AND conv_type = ? AND is_pinned = 0 '
        'AND active_time > ?',
        [owner, typeFilter, thresholdActiveTimeMs],
      );
      return _asInt(rows.first['c']);
    }
    return _withExcludeQueryLock(() async {
      await _fillExcludeArchivedTemp(db, excludeTokens);
      try {
        final rows = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM $_table c '
          'WHERE c.owner_user_id = ? AND c.conv_type = ? AND c.is_pinned = 0 '
          'AND c.active_time > ? '
          'AND NOT EXISTS (SELECT 1 FROM $_excludeArchivedTemp e WHERE e.id = c.conversation_id)',
          [owner, typeFilter, thresholdActiveTimeMs],
        );
        return _asInt(rows.first['c']);
      } finally {
        await db.delete(_excludeArchivedTemp);
      }
    });
  }

  Set<String> _archiveExcludeTokens(Set<String>? excludeConversationIds) {
    if (excludeConversationIds == null || excludeConversationIds.isEmpty) {
      return const <String>{};
    }
    return buildArchiveLookupTokenSet(excludeConversationIds);
  }

  static const _excludeArchivedTemp = '_excl_archived_ids';
  Future<void>? _excludeQueryChain;

  /// 串行化 TEMP 排除查询，避免双 Tab purge 并发把 COUNT 打回全量。
  Future<T> _withExcludeQueryLock<T>(Future<T> Function() action) {
    if (!ConversationPerfFlags.archiveExcludeQuerySerialized) {
      return action();
    }
    final previous = _excludeQueryChain;
    final gate = Completer<void>();
    _excludeQueryChain = gate.future;
    return () async {
      try {
        if (previous != null) {
          await previous;
        }
        return await action();
      } finally {
        if (!gate.isCompleted) {
          gate.complete();
        }
      }
    }();
  }

  Future<int> _countByConvTypeExcluding(
    Database db,
    String owner,
    int typeFilter,
    Set<String> excludeTokens,
  ) {
    return _withExcludeQueryLock(() async {
      await _fillExcludeArchivedTemp(db, excludeTokens);
      try {
        final rows = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM $_table c '
          'WHERE c.owner_user_id = ? AND c.conv_type = ? '
          'AND NOT EXISTS (SELECT 1 FROM $_excludeArchivedTemp e WHERE e.id = c.conversation_id)',
          [owner, typeFilter],
        );
        return _asInt(rows.first['c']);
      } finally {
        await db.delete(_excludeArchivedTemp);
      }
    });
  }

  Future<void> _ensureExcludeArchivedTemp(Database db) async {
    await db.execute(
      'CREATE TEMP TABLE IF NOT EXISTS $_excludeArchivedTemp ('
      'id TEXT PRIMARY KEY NOT NULL)',
    );
  }

  Future<void> _fillExcludeArchivedTemp(
    Database db,
    Set<String> tokens,
  ) async {
    await _ensureExcludeArchivedTemp(db);
    await db.delete(_excludeArchivedTemp);
    final list = tokens.toList(growable: false);
    const chunk = 400;
    for (var i = 0; i < list.length; i += chunk) {
      final end = i + chunk > list.length ? list.length : i + chunk;
      final batch = db.batch();
      for (final id in list.sublist(i, end)) {
        batch.insert(
          _excludeArchivedTemp,
          <String, Object?>{'id': id},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  /// 按库序（置顶 + active_time）取类型页，供游标漂移时 OFFSET 兜底翻页。
  ///
  /// [excludeConversationIds]：原始归档 ID 集；展开 token 后排除。
  Future<List<V2TimConversation>> loadConvTypePage({
    required int convType,
    required int offset,
    int limit = ConversationPerfFlags.uiScrollPageSize,
    String? ownerUserId,
    Set<String>? excludeConversationIds,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    if (owner.isEmpty || typeFilter == null || limit <= 0) {
      return const [];
    }
    final start = offset < 0 ? 0 : offset;
    final excludeTokens = _archiveExcludeTokens(excludeConversationIds);
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      for (final conversation in list) {
        _applyBackendPinnedFlag(conversation);
        _decorateConversation(conversation);
      }
      list.sort(_sortConversations);
      final filtered = list.where((c) {
        if (typeFilter == 2 ? !_isGroupConv(c) : _isGroupConv(c)) {
          return false;
        }
        if (excludeTokens.isEmpty) {
          return true;
        }
        return !conversationIdInArchivedLookup(
          excludeTokens,
          c.conversationID,
        );
      }).toList(growable: false);
      if (start >= filtered.length) {
        return const [];
      }
      final end =
          start + limit > filtered.length ? filtered.length : start + limit;
      return filtered.sublist(start, end);
    }
    final db = await _openDb();
    // 虚拟列表按 typeIndex 直接消费本查询的顺序。登录置顶集合已水合后，
    // 它比 SQLite 镜像列更新得更早：若仍只按 is_pinned 排序，行对象在
    // decode 时虽然会显示图钉，却仍停留在旧的时间序位置。
    //
    // 在 SQL 层使用同一份置顶真值，保证 LIMIT/OFFSET 之前就完成正确排序；
    // 不能只在当前 page decode 后排序，否则落在 page 外的冷置顶进不了头窗。
    final pinService = ConversationPinSyncService.instance;
    final useHydratedPinTruth = pinService.isHydrated;
    final effectivePinnedIds = useHydratedPinTruth
        ? pinService.pinnedConversationIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .where((id) => typeFilter == 2
                ? !MessageConversationId.looksLikeC2cConversationId(id)
                : !MessageConversationId.looksLikeGroupConversationId(id))
            .toList(growable: false)
        : const <String>[];
    // Never emit a bare numeric ORDER BY term here: SQLite treats `ORDER BY
    // 0` as a column ordinal and rejects it ("term out of range").
    const noPinnedRankSql =
        'CASE WHEN c.conversation_id IS NULL THEN 0 ELSE 0 END';
    final pinRankSql = !useHydratedPinTruth
        ? 'c.is_pinned'
        : effectivePinnedIds.isEmpty
            ? noPinnedRankSql
            : 'CASE WHEN c.conversation_id IN '
                '(${List.filled(effectivePinnedIds.length, '?').join(',')}) '
                'THEN 1 ELSE 0 END';
    final orderSql = '$pinRankSql DESC, c.active_time DESC, '
        'c.order_key DESC, c.conversation_id ASC';

    Future<List<V2TimConversation>> decodeOrdered(
      List<Map<String, Object?>> rows,
    ) async {
      final page = await _conversationsFromDbRows(rows);
      // 防御等价 ID / 查询期间置顶集合变化；正常情况下 SQL 已给出此顺序。
      page.sort(_sortConversations);
      return page;
    }

    if (excludeTokens.isEmpty) {
      final rows = await db.rawQuery(
        'SELECT c.* FROM $_table c '
        'WHERE c.owner_user_id = ? AND c.conv_type = ? '
        'ORDER BY $orderSql LIMIT ? OFFSET ?',
        <Object?>[
          owner,
          typeFilter,
          ...effectivePinnedIds,
          limit,
          start,
        ],
      );
      return decodeOrdered(rows);
    }
    return _withExcludeQueryLock(() async {
      await _fillExcludeArchivedTemp(db, excludeTokens);
      try {
        final rows = await db.rawQuery(
          'SELECT c.* FROM $_table c '
          'WHERE c.owner_user_id = ? AND c.conv_type = ? '
          'AND NOT EXISTS (SELECT 1 FROM $_excludeArchivedTemp e WHERE e.id = c.conversation_id) '
          'ORDER BY $orderSql '
          'LIMIT ? OFFSET ?',
          <Object?>[
            owner,
            typeFilter,
            ...effectivePinnedIds,
            limit,
            start,
          ],
        );
        return decodeOrdered(rows);
      } finally {
        await db.delete(_excludeArchivedTemp);
      }
    });
  }

  /// Keyset page for the type hydrate window. The cursor is the last emitted
  /// row in the same ordering used by [loadConvTypePage].
  Future<List<V2TimConversation>> loadConvTypePageAfterCursor({
    required int convType,
    required ConversationTypePageCursor cursor,
    int limit = ConversationPerfFlags.uiScrollPageSize,
    String? ownerUserId,
    Set<String>? excludeConversationIds,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    if (owner.isEmpty || typeFilter == null || limit <= 0) {
      return const [];
    }
    if (_useMemoryOnly) {
      final all = await loadConvTypePage(
        convType: convType,
        offset: 0,
        limit: 1 << 30,
        ownerUserId: owner,
        excludeConversationIds: excludeConversationIds,
      );
      final out = all
          .where((row) {
            final pinned = row.isPinned == true;
            final key = <int>[
              pinned ? 1 : 0,
              activeTimeMs(row),
              row.orderkey ?? 0
            ];
            final cur = <int>[
              cursor.pinned ? 1 : 0,
              cursor.activeTime,
              cursor.orderKey
            ];
            final cmp = key[0] != cur[0]
                ? cur[0].compareTo(key[0])
                : key[1] != cur[1]
                    ? cur[1].compareTo(key[1])
                    : key[2] != cur[2]
                        ? cur[2].compareTo(key[2])
                        : row.conversationID.compareTo(cursor.conversationID);
            // The final tie-breaker is ASC, so rows after the cursor have a
            // lexicographically greater conversation ID.
            return cmp > 0;
          })
          .take(limit)
          .toList(growable: false);
      return out;
    }
    final excludeTokens = _archiveExcludeTokens(excludeConversationIds);
    final db = await _openDb();
    final pinService = ConversationPinSyncService.instance;
    final useHydratedPinTruth = pinService.isHydrated;
    final effectivePinnedIds = useHydratedPinTruth
        ? pinService.pinnedConversationIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .where((id) => typeFilter == 2
                ? !MessageConversationId.looksLikeC2cConversationId(id)
                : !MessageConversationId.looksLikeGroupConversationId(id))
            .toList(growable: false)
        : const <String>[];
    const noPinnedRankSql =
        'CASE WHEN c.conversation_id IS NULL THEN 0 ELSE 0 END';
    final pinRankSql = !useHydratedPinTruth
        ? 'c.is_pinned'
        : effectivePinnedIds.isEmpty
            ? noPinnedRankSql
            : 'CASE WHEN c.conversation_id IN '
                '(${List.filled(effectivePinnedIds.length, '?').join(',')}) '
                'THEN 1 ELSE 0 END';
    final orderSql = '$pinRankSql DESC, c.active_time DESC, '
        'c.order_key DESC, c.conversation_id ASC';
    final cursorWhere = '($pinRankSql < ? OR '
        '($pinRankSql = ? AND (c.active_time < ? OR '
        '(c.active_time = ? AND (c.order_key < ? OR '
        '(c.order_key = ? AND c.conversation_id > ?))))))';
    final args = <Object?>[
      owner,
      typeFilter,
      ...effectivePinnedIds,
      cursor.pinned ? 1 : 0,
      ...effectivePinnedIds,
      cursor.pinned ? 1 : 0,
      cursor.activeTime,
      cursor.activeTime,
      cursor.orderKey,
      cursor.orderKey,
      cursor.conversationID,
      ...effectivePinnedIds,
      limit,
    ];
    Future<List<V2TimConversation>> queryPage() async {
      final excludeClause = excludeTokens.isEmpty
          ? ''
          : ' AND NOT EXISTS (SELECT 1 FROM $_excludeArchivedTemp e WHERE e.id = c.conversation_id)';
      final rows = await db.rawQuery(
        'SELECT c.* FROM $_table c WHERE c.owner_user_id = ? AND '
        'c.conv_type = ? AND $cursorWhere$excludeClause '
        'ORDER BY $orderSql LIMIT ?',
        args,
      );
      final page = await _conversationsFromDbRows(rows);
      page.sort(_sortConversations);
      return page;
    }

    if (excludeTokens.isEmpty) {
      return queryPage();
    }
    return _withExcludeQueryLock(() async {
      await _fillExcludeArchivedTemp(db, excludeTokens);
      try {
        return await queryPage();
      } finally {
        await db.delete(_excludeArchivedTemp);
      }
    });
  }

  /// 在给定会话 ID 集合内按 UI 序取「更旧」的一页（归档列表触底分页）。
  ///
  /// [beforeActiveTime]/[beforeConversationId] 同时为空时取第一页；
  /// 否则取严格排在游标之后（更旧）的会话。
  Future<List<V2TimConversation>> loadOlderAmongIds({
    required Set<String> conversationIds,
    int? beforeActiveTime,
    String? beforeConversationId,
    int limit = ConversationPerfFlags.uiScrollPageSize,
    String? ownerUserId,
    int? convType,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final wanted =
        conversationIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (owner.isEmpty || wanted.isEmpty || limit <= 0) {
      return const [];
    }
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    final beforeId = beforeConversationId?.trim() ?? '';
    final hasCursor = beforeActiveTime != null && beforeId.isNotEmpty;

    if (_useMemoryOnly) {
      final list = <V2TimConversation>[];
      for (final conversation
          in _memoryByOwner[owner] ?? const <V2TimConversation>[]) {
        final id = conversation.conversationID.trim();
        if (id.isEmpty) {
          continue;
        }
        final hit = wanted.any(
          (w) => MessageConversationId.sameConversation(id, w),
        );
        if (!hit) {
          continue;
        }
        if (typeFilter != null) {
          final isGroup = _isGroupConv(conversation);
          if (typeFilter == 2 ? !isGroup : isGroup) {
            continue;
          }
        }
        _applyBackendPinnedFlag(conversation);
        _decorateConversation(conversation);
        list.add(conversation);
      }
      list.sort(_sortConversations);
      return _sliceOlderAmongSorted(
        list,
        hasCursor: hasCursor,
        beforeActiveTime: beforeActiveTime ?? 0,
        beforeConversationId: beforeId,
        limit: limit,
      );
    }

    final db = await _openDb();
    final matched = <V2TimConversation>[];
    final foundKeys = <String>{};
    const chunkSize = 200;
    final idList = wanted.toList(growable: false);
    for (var offset = 0; offset < idList.length; offset += chunkSize) {
      final chunk = idList.sublist(
        offset,
        offset + chunkSize > idList.length ? idList.length : offset + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final args = <Object?>[owner, ...chunk];
      final typeClause = typeFilter == null ? '' : ' AND conv_type = ?';
      if (typeFilter != null) {
        args.add(typeFilter);
      }
      final rows = await db.rawQuery('''
        SELECT * FROM $_table
        WHERE owner_user_id = ?
          AND conversation_id IN ($placeholders)
          $typeClause
        ''', args);
      for (final row in rows) {
        final conversation = _conversationFromRow(row);
        if (conversation == null) {
          continue;
        }
        final id = conversation.conversationID.trim();
        if (id.isEmpty || foundKeys.contains(id)) {
          continue;
        }
        foundKeys.add(id);
        _applyBackendPinnedFlag(conversation);
        _decorateConversation(conversation);
        matched.add(conversation);
      }
    }
    // IN 未命中时再走模糊查找（id 形态兼容）。
    for (final id in idList) {
      if (foundKeys.any((f) => MessageConversationId.sameConversation(f, id))) {
        continue;
      }
      final row = await _findPersistedConversationRow(
        db,
        owner: owner,
        conversationId: id,
      );
      if (row == null) {
        continue;
      }
      final conversation = _conversationFromRow(row);
      if (conversation == null) {
        continue;
      }
      if (typeFilter != null) {
        final isGroup = _isGroupConv(conversation);
        if (typeFilter == 2 ? !isGroup : isGroup) {
          continue;
        }
      }
      final cid = conversation.conversationID.trim();
      if (cid.isEmpty || foundKeys.contains(cid)) {
        continue;
      }
      foundKeys.add(cid);
      _applyBackendPinnedFlag(conversation);
      _decorateConversation(conversation);
      matched.add(conversation);
    }
    matched.sort(_sortConversations);
    return _sliceOlderAmongSorted(
      matched,
      hasCursor: hasCursor,
      beforeActiveTime: beforeActiveTime ?? 0,
      beforeConversationId: beforeId,
      limit: limit,
    );
  }

  List<V2TimConversation> _sliceOlderAmongSorted(
    List<V2TimConversation> sortedNewestFirst, {
    required bool hasCursor,
    required int beforeActiveTime,
    required String beforeConversationId,
    required int limit,
  }) {
    if (sortedNewestFirst.isEmpty || limit <= 0) {
      return const [];
    }
    var start = 0;
    if (hasCursor) {
      final idx = sortedNewestFirst.indexWhere(
        (c) => MessageConversationId.sameConversation(
          c.conversationID,
          beforeConversationId,
        ),
      );
      if (idx >= 0) {
        start = idx + 1;
      } else {
        start = sortedNewestFirst.indexWhere((c) {
          final active = activeTimeMs(c);
          if (active < beforeActiveTime) {
            return true;
          }
          if (active > beforeActiveTime) {
            return false;
          }
          return c.conversationID.compareTo(beforeConversationId) > 0;
        });
        if (start < 0) {
          return const [];
        }
      }
    }
    if (start >= sortedNewestFirst.length) {
      return const [];
    }
    final end = start + limit > sortedNewestFirst.length
        ? sortedNewestFirst.length
        : start + limit;
    return sortedNewestFirst.sublist(start, end);
  }

  Future<void> _ensureArchiveJoinTable(Database db) async {
    if (_archiveJoinTableReady) {
      return;
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_archiveJoinTable (
        conversation_id TEXT PRIMARY KEY NOT NULL
      )
    ''');
    _archiveJoinTableReady = true;
  }

  Future<void> _clearArchiveJoinState({Database? db}) async {
    _archiveJoinTokenSet = <String>{};
    _archiveOriginalIds = <String>{};
    _archivePrepareOwner = null;
    if (_useMemoryOnly) {
      return;
    }
    final database = db ?? _db;
    if (database == null) {
      return;
    }
    try {
      await _ensureArchiveJoinTable(database);
      await database.delete(_archiveJoinTable);
    } catch (_) {}
  }

  /// 将会话归档 ID 展开为 JOIN 候选并写入会话级表（供真分页）。
  Future<ArchiveIdPrepareResult> prepareArchiveIdSet({
    required Set<String> conversationIds,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final originals =
        conversationIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final generation = ++_archivePrepareGeneration;
    final sw = Stopwatch()..start();
    if (owner.isEmpty || originals.isEmpty) {
      await _clearArchiveJoinState();
      return ArchiveIdPrepareResult(
        generation: generation,
        joinTokenCount: 0,
        originalCount: 0,
      );
    }

    final tokens = buildArchiveJoinCandidateSet(originals);
    _archivePrepareOwner = owner;
    _archiveOriginalIds = originals;
    _archiveJoinTokenSet = tokens;

    if (_useMemoryOnly) {
      if (ConversationPerfFlags.archivePagePhaseLogEnabled) {
        ConversationPerfGateLog.log(
          'archive_page_prepare',
          extras: <String, Object?>{
            'gen': generation,
            'originals': originals.length,
            'tokens': tokens.length,
            'prepareMs': sw.elapsedMilliseconds,
            'memory': 1,
          },
        );
      }
      return ArchiveIdPrepareResult(
        generation: generation,
        joinTokenCount: tokens.length,
        originalCount: originals.length,
      );
    }

    final db = await _openDb();
    await _ensureArchiveJoinTable(db);
    await db.delete(_archiveJoinTable);
    final tokenList = tokens.toList(growable: false);
    final chunkSize = ConversationPerfFlags.archivePrepareChunkSize > 0
        ? ConversationPerfFlags.archivePrepareChunkSize
        : 400;
    for (var offset = 0; offset < tokenList.length; offset += chunkSize) {
      if (generation != _archivePrepareGeneration) {
        break;
      }
      final end = offset + chunkSize > tokenList.length
          ? tokenList.length
          : offset + chunkSize;
      final chunk = tokenList.sublist(offset, end);
      final batch = db.batch();
      for (final id in chunk) {
        batch.insert(
          _archiveJoinTable,
          <String, Object?>{'conversation_id': id},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
      if (ConversationPerfFlags.archivePrepareYield && end < tokenList.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (ConversationPerfFlags.archivePagePhaseLogEnabled) {
      ConversationPerfGateLog.log(
        'archive_page_prepare',
        extras: <String, Object?>{
          'gen': generation,
          'originals': originals.length,
          'tokens': tokens.length,
          'prepareMs': sw.elapsedMilliseconds,
          'memory': 0,
        },
      );
    }
    return ArchiveIdPrepareResult(
      generation: generation,
      joinTokenCount: tokens.length,
      originalCount: originals.length,
    );
  }

  /// 冷 hydrate 成功后把新会话 ID 补进 JOIN 候选，便于后续真分页命中。
  Future<void> addArchiveJoinConversationIds(
    Iterable<String> conversationIds,
  ) async {
    final extras = <String>{};
    for (final raw in conversationIds) {
      extras.addAll(archiveJoinCandidatesForConversationId(raw));
    }
    if (extras.isEmpty) {
      return;
    }
    _archiveJoinTokenSet = {..._archiveJoinTokenSet, ...extras};
    if (_useMemoryOnly) {
      return;
    }
    final db = await _openDb();
    await _ensureArchiveJoinTable(db);
    final batch = db.batch();
    for (final id in extras) {
      batch.insert(
        _archiveJoinTable,
        <String, Object?>{'conversation_id': id},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 在已 prepare 的归档候选内按 UI 序取一页（SQL JOIN + LIMIT；内存模式 token Set）。
  Future<List<V2TimConversation>> loadOlderAmongPreparedArchiveIds({
    int? beforeActiveTime,
    String? beforeConversationId,
    int limit = ConversationPerfFlags.uiScrollPageSize,
    String? ownerUserId,
    int? convType,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || limit <= 0 || _archiveJoinTokenSet.isEmpty) {
      return const [];
    }
    if (_archivePrepareOwner != null && _archivePrepareOwner != owner) {
      return const [];
    }
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    final beforeId = beforeConversationId?.trim() ?? '';
    final hasCursor = beforeActiveTime != null && beforeId.isNotEmpty;
    final sw = Stopwatch()..start();

    if (_useMemoryOnly) {
      final lookup = _archiveJoinTokenSet;
      final list = <V2TimConversation>[];
      for (final conversation
          in _memoryByOwner[owner] ?? const <V2TimConversation>[]) {
        final id = conversation.conversationID.trim();
        if (id.isEmpty) {
          continue;
        }
        if (!conversationIdInArchivedLookup(lookup, id)) {
          continue;
        }
        if (typeFilter != null) {
          final isGroup = _isGroupConv(conversation);
          if (typeFilter == 2 ? !isGroup : isGroup) {
            continue;
          }
        }
        _applyBackendPinnedFlag(conversation);
        _decorateConversation(conversation);
        list.add(conversation);
      }
      list.sort(_sortConversations);
      final page = _sliceOlderAmongSorted(
        list,
        hasCursor: hasCursor,
        beforeActiveTime: beforeActiveTime ?? 0,
        beforeConversationId: beforeId,
        limit: limit,
      );
      if (ConversationPerfFlags.archivePagePhaseLogEnabled) {
        ConversationPerfGateLog.log(
          'archive_page_query',
          extras: <String, Object?>{
            'pageCount': page.length,
            'idSetSize': lookup.length,
            'queryMs': sw.elapsedMilliseconds,
            'hasCursor': hasCursor ? 1 : 0,
            'memory': 1,
          },
        );
      }
      return page;
    }

    final db = await _openDb();
    await _ensureArchiveJoinTable(db);
    final args = <Object?>[owner];
    final typeClause = typeFilter == null ? '' : ' AND c.conv_type = ?';
    if (typeFilter != null) {
      args.add(typeFilter);
    }
    var cursorClause = '';
    if (hasCursor) {
      cursorClause = '''
        AND (
          c.active_time < ?
          OR (c.active_time = ? AND c.conversation_id > ?)
        )
      ''';
      args.add(beforeActiveTime);
      args.add(beforeActiveTime);
      args.add(beforeId);
    }
    args.add(limit);
    final rows = await db.rawQuery(
      '''
      SELECT c.* FROM $_table c
      INNER JOIN $_archiveJoinTable a
        ON c.conversation_id = a.conversation_id
      WHERE c.owner_user_id = ?
        $typeClause
        $cursorClause
      ORDER BY c.is_pinned DESC, c.active_time DESC, c.order_key DESC,
               c.conversation_id ASC
      LIMIT ?
      ''',
      args,
    );
    final page = await _conversationsFromDbRows(rows);
    if (ConversationPerfFlags.archivePagePhaseLogEnabled) {
      ConversationPerfGateLog.log(
        'archive_page_query',
        extras: <String, Object?>{
          'pageCount': page.length,
          'idSetSize': _archiveJoinTokenSet.length,
          'queryMs': sw.elapsedMilliseconds,
          'hasCursor': hasCursor ? 1 : 0,
          'memory': 0,
        },
      );
    }
    return page;
  }

  /// 在已 prepare 的前提下，找出本地尚无会话壳的原始归档 ID（只扫 id，不全量 hydrate）。
  Future<List<String>> listColdArchivedIds({
    Set<String>? originalArchivedIds,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final originals = (originalArchivedIds ?? _archiveOriginalIds)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (owner.isEmpty || originals.isEmpty) {
      return const [];
    }

    final matchedStored = <String>{};
    if (_useMemoryOnly) {
      final lookup = _archiveJoinTokenSet.isNotEmpty
          ? _archiveJoinTokenSet
          : buildArchiveJoinCandidateSet(originals);
      for (final conversation
          in _memoryByOwner[owner] ?? const <V2TimConversation>[]) {
        final id = conversation.conversationID.trim();
        if (id.isEmpty) {
          continue;
        }
        if (conversationIdInArchivedLookup(lookup, id)) {
          matchedStored.add(id);
        }
      }
    } else {
      final db = await _openDb();
      if (_archiveJoinTokenSet.isNotEmpty) {
        await _ensureArchiveJoinTable(db);
        final rows = await db.rawQuery(
          '''
          SELECT c.conversation_id AS conversation_id
          FROM $_table c
          INNER JOIN $_archiveJoinTable a
            ON c.conversation_id = a.conversation_id
          WHERE c.owner_user_id = ?
          ''',
          [owner],
        );
        for (final row in rows) {
          final id = row['conversation_id']?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            matchedStored.add(id);
          }
        }
      } else {
        final tokens = buildArchiveJoinCandidateSet(originals).toList();
        const chunkSize = 200;
        for (var offset = 0; offset < tokens.length; offset += chunkSize) {
          final chunk = tokens.sublist(
            offset,
            offset + chunkSize > tokens.length
                ? tokens.length
                : offset + chunkSize,
          );
          final placeholders = List.filled(chunk.length, '?').join(',');
          final rows = await db.rawQuery(
            '''
            SELECT conversation_id FROM $_table
            WHERE owner_user_id = ?
              AND conversation_id IN ($placeholders)
            ''',
            <Object?>[owner, ...chunk],
          );
          for (final row in rows) {
            final id = row['conversation_id']?.toString().trim() ?? '';
            if (id.isNotEmpty) {
              matchedStored.add(id);
            }
          }
          if (ConversationPerfFlags.archivePrepareYield) {
            await Future<void>.delayed(Duration.zero);
          }
        }
      }
    }

    final cold = <String>[];
    for (final id in originals) {
      if (!archivedIdMatchedInStoredIds(id, matchedStored)) {
        cold.add(id);
      }
    }
    if (ConversationPerfFlags.archivePagePhaseLogEnabled) {
      ConversationPerfGateLog.log(
        'archive_page_cold_scan',
        extras: <String, Object?>{
          'originals': originals.length,
          'matched': matchedStored.length,
          'cold': cold.length,
        },
      );
    }
    return cold;
  }

  /// 比游标「更新」的一页（用于近顶 prepend）。结果已按 UI 序（新→旧）。
  Future<List<V2TimConversation>> loadNewerPage({
    required int afterActiveTime,
    required String afterConversationId,
    int limit = ConversationPerfFlags.uiScrollPageSize,
    String? ownerUserId,
    int? convType,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final afterId = afterConversationId.trim();
    if (owner.isEmpty || limit <= 0) {
      return const [];
    }
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      for (final conversation in list) {
        _applyBackendPinnedFlag(conversation);
        _decorateConversation(conversation);
      }
      list.sort(_sortConversations);
      final filtered = typeFilter == null
          ? list
          : list
              .where(
                (c) => typeFilter == 2 ? _isGroupConv(c) : !_isGroupConv(c),
              )
              .toList(growable: false);
      final idx = filtered.indexWhere((c) => c.conversationID == afterId);
      if (idx <= 0) {
        return const [];
      }
      final start = idx - limit < 0 ? 0 : idx - limit;
      return filtered.sublist(start, idx);
    }

    final db = await _openDb();
    // 先取「最接近游标」的更新项（升序靠近），再反转为 UI 降序。
    final rows = typeFilter == null
        ? await db.rawQuery(
            '''
      SELECT * FROM $_table
      WHERE owner_user_id = ?
        AND (
          active_time > ?
          OR (active_time = ? AND conversation_id < ?)
        )
      ORDER BY is_pinned ASC, active_time ASC, order_key ASC, conversation_id DESC
      LIMIT ?
      ''',
            [owner, afterActiveTime, afterActiveTime, afterId, limit],
          )
        : await db.rawQuery(
            '''
      SELECT * FROM $_table
      WHERE owner_user_id = ?
        AND conv_type = ?
        AND (
          active_time > ?
          OR (active_time = ? AND conversation_id < ?)
        )
      ORDER BY is_pinned ASC, active_time ASC, order_key ASC, conversation_id DESC
      LIMIT ?
      ''',
            [
              owner,
              typeFilter,
              afterActiveTime,
              afterActiveTime,
              afterId,
              limit,
            ],
          );
    return _conversationsFromDbRows(rows.reversed.toList(growable: false));
  }

  Future<List<V2TimConversation>> searchConversations({
    required String keyword,
    int limit = ConversationPerfFlags.uiSearchLimit,
    int offset = 0,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final q = keyword.trim();
    if (owner.isEmpty || q.isEmpty || limit <= 0) {
      return const [];
    }
    final safeOffset = offset < 0 ? 0 : offset;
    final like = '%$q%';
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final out = <V2TimConversation>[];
      for (final conversation in list) {
        _applyBackendPinnedFlag(conversation);
        _decorateConversation(conversation);
        final hay = [
          conversation.showName ?? '',
          conversation.conversationID,
          conversation.userID ?? '',
          conversation.groupID ?? '',
        ].join(' ').toLowerCase();
        if (!hay.contains(q.toLowerCase())) {
          continue;
        }
        out.add(conversation);
      }
      out.sort(_sortConversations);
      if (safeOffset >= out.length) {
        return const [];
      }
      final end = safeOffset + limit;
      return out.sublist(
        safeOffset,
        end > out.length ? out.length : end,
      );
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: '''
        owner_user_id = ? AND (
          show_name LIKE ? OR conversation_id LIKE ?
          OR user_id LIKE ? OR group_id LIKE ?
        )
      ''',
      whereArgs: [owner, like, like, like, like],
      orderBy: 'is_pinned DESC, active_time DESC, order_key DESC',
      limit: limit,
      offset: safeOffset,
    );
    final conversations = <V2TimConversation>[];
    for (final row in rows) {
      final conversation = _conversationFromRow(row);
      if (conversation == null) {
        continue;
      }
      _applyBackendPinnedFlag(conversation);
      _decorateConversation(conversation);
      conversations.add(conversation);
    }
    return conversations;
  }

  /// 分页拉全量命中会话：空页 / 短页 / 达上限 / [shouldCancel] / 无新 id 时终止。
  Future<List<V2TimConversation>> searchConversationsAllPages({
    required String keyword,
    int pageSize = ConversationPerfFlags.uiSearchPageSize,
    int maxResults = ConversationPerfFlags.uiSearchMaxResults,
    int maxPages = ConversationPerfFlags.uiSearchMaxPages,
    bool Function()? shouldCancel,
    void Function(
      List<V2TimConversation> batch,
      List<V2TimConversation> accumulated,
    )? onBatch,
    String? ownerUserId,
  }) async {
    final q = keyword.trim();
    if (q.isEmpty || pageSize <= 0 || maxResults <= 0 || maxPages <= 0) {
      return const [];
    }

    final accumulated = <V2TimConversation>[];
    final seenIds = <String>{};
    var offset = 0;
    var pages = 0;

    while (pages < maxPages && accumulated.length < maxResults) {
      if (shouldCancel?.call() ?? false) {
        break;
      }

      final remaining = maxResults - accumulated.length;
      final fetchLimit = pageSize < remaining ? pageSize : remaining;
      if (fetchLimit <= 0) {
        break;
      }

      final batch = await searchConversations(
        keyword: q,
        limit: fetchLimit,
        offset: offset,
        ownerUserId: ownerUserId,
      );
      pages++;

      if (batch.isEmpty) {
        break;
      }

      final uniqueBatch = <V2TimConversation>[];
      for (final conversation in batch) {
        final id = conversation.conversationID.trim();
        if (id.isEmpty || seenIds.contains(id)) {
          continue;
        }
        seenIds.add(id);
        uniqueBatch.add(conversation);
        accumulated.add(conversation);
        if (accumulated.length >= maxResults) {
          break;
        }
      }

      if (uniqueBatch.isNotEmpty) {
        onBatch?.call(
          List<V2TimConversation>.unmodifiable(uniqueBatch),
          List<V2TimConversation>.unmodifiable(accumulated),
        );
      }

      if (batch.length < fetchLimit || accumulated.length >= maxResults) {
        break;
      }
      if (uniqueBatch.isEmpty) {
        break;
      }

      offset += batch.length;
      await Future<void>.delayed(Duration.zero);
    }

    return accumulated;
  }

  Future<List<V2TimConversation>> loadConversationsWithUnread({
    int limit = 100,
    int offset = 0,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || limit <= 0) {
      return const [];
    }
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final unread = <V2TimConversation>[];
      for (final conversation in list) {
        if ((conversation.unreadCount ?? 0) <= 0) {
          continue;
        }
        _applyBackendPinnedFlag(conversation);
        _decorateConversation(conversation);
        unread.add(conversation);
      }
      unread.sort(_sortConversations);
      if (offset >= unread.length) {
        return const [];
      }
      final end =
          offset + limit > unread.length ? unread.length : offset + limit;
      return unread.sublist(offset, end);
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND unread_count > 0',
      whereArgs: [owner],
      orderBy: 'active_time DESC, order_key DESC',
      limit: limit,
      offset: offset < 0 ? 0 : offset,
    );
    final conversations = <V2TimConversation>[];
    for (final row in rows) {
      final conversation = _conversationFromRow(row);
      if (conversation == null) {
        continue;
      }
      _applyBackendPinnedFlag(conversation);
      _decorateConversation(conversation);
      conversations.add(conversation);
    }
    return conversations;
  }

  /// Tab 角标用：按 notifiable 规则分 c2c/group 求和（轻量列，不做 lastMessage decorate）。
  ///
  /// 规则对齐 [ConversationUnreadUtils.notifiableUnreadForAggregate]：
  /// `unread>0` 且 (`recv_opt=0` 或 Meeting)，排除 `user_id=10000` / [excludedUserIds]，
  /// 再减去归档集合中仍带未读的贡献。
  Future<NotifiableUnreadSums> sumNotifiableUnreadByScope({
    required Set<String> archivedC2c,
    required Set<String> archivedGroup,
    Set<String> excludedUserIds = const <String>{},
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return const NotifiableUnreadSums(c2c: 0, group: 0);
    }
    if (_useMemoryOnly) {
      var c2c = 0;
      var group = 0;
      for (final conversation
          in _memoryByOwner[owner] ?? const <V2TimConversation>[]) {
        final n = ConversationUnreadUtils.notifiableUnreadForAggregate(
          conversation,
          archivedC2c: archivedC2c,
          archivedGroup: archivedGroup,
        );
        if (n <= 0) {
          continue;
        }
        if (ConversationUnreadUtils.isGroupConversation(conversation)) {
          group += n;
        } else {
          c2c += n;
        }
      }
      return NotifiableUnreadSums(c2c: c2c, group: group);
    }

    final db = await _openDb();
    final excluded = excludedUserIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '10000')
        .toSet()
        .toList(growable: false);
    final args = <Object?>[owner];
    final excludedClause = excluded.isEmpty
        ? ''
        : ' AND IFNULL(user_id, \'\') NOT IN (${List.filled(excluded.length, '?').join(',')})';
    if (excluded.isNotEmpty) {
      args.addAll(excluded);
    }
    final rows = await db.rawQuery('''
      SELECT conv_type AS t, SUM(unread_count) AS s FROM $_table
      WHERE owner_user_id = ?
        AND unread_count > 0
        AND (recv_opt = 0 OR group_type = 'Meeting')
        AND IFNULL(user_id, '') != '10000'
        $excludedClause
      GROUP BY conv_type
      ''', args);
    var c2c = 0;
    var group = 0;
    for (final row in rows) {
      final type = _asInt(row['t']);
      final sum = _asInt(row['s']);
      if (type == 2) {
        group += sum;
      } else {
        c2c += sum;
      }
    }

    final archivedIds = <String>{
      ...cachedArchiveLookupTokenSet(archivedC2c),
      ...cachedArchiveLookupTokenSet(archivedGroup),
    };
    if (archivedIds.isNotEmpty) {
      final deduction = await _sumNotifiableUnreadForIds(
        db: db,
        owner: owner,
        conversationIds: archivedIds.toList(growable: false),
        excludedUserIds: excluded,
      );
      c2c = c2c - deduction.c2c;
      group = group - deduction.group;
      if (c2c < 0) {
        c2c = 0;
      }
      if (group < 0) {
        group = 0;
      }
    }
    return NotifiableUnreadSums(c2c: c2c, group: group);
  }

  Future<NotifiableUnreadSums> _sumNotifiableUnreadForIds({
    required DatabaseExecutor db,
    required String owner,
    required List<String> conversationIds,
    required List<String> excludedUserIds,
  }) async {
    var c2c = 0;
    var group = 0;
    const chunkSize = 200;
    for (var offset = 0; offset < conversationIds.length; offset += chunkSize) {
      final chunk = conversationIds.sublist(
        offset,
        offset + chunkSize > conversationIds.length
            ? conversationIds.length
            : offset + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final args = <Object?>[owner, ...chunk];
      final excludedClause = excludedUserIds.isEmpty
          ? ''
          : ' AND IFNULL(user_id, \'\') NOT IN (${List.filled(excludedUserIds.length, '?').join(',')})';
      if (excludedUserIds.isNotEmpty) {
        args.addAll(excludedUserIds);
      }
      final rows = await db.rawQuery('''
        SELECT conv_type AS t, SUM(unread_count) AS s FROM $_table
        WHERE owner_user_id = ?
          AND conversation_id IN ($placeholders)
          AND unread_count > 0
          AND (recv_opt = 0 OR group_type = 'Meeting')
          AND IFNULL(user_id, '') != '10000'
          $excludedClause
        GROUP BY conv_type
        ''', args);
      for (final row in rows) {
        final type = _asInt(row['t']);
        final sum = _asInt(row['s']);
        if (type == 2) {
          group += sum;
        } else {
          c2c += sum;
        }
      }
    }
    return NotifiableUnreadSums(c2c: c2c, group: group);
  }

  /// 批量返回 conversation_id → unread_count（folder 未读一次扫库）。
  Future<Map<String, int>> unreadCountMapForConversationIds(
    Iterable<String> conversationIds, {
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final ids = conversationIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (owner.isEmpty || ids.isEmpty) {
      return const <String, int>{};
    }
    if (_useMemoryOnly) {
      final out = <String, int>{};
      for (final conversation
          in _memoryByOwner[owner] ?? const <V2TimConversation>[]) {
        final cid = conversation.conversationID.trim();
        if (cid.isEmpty) {
          continue;
        }
        for (final id in ids) {
          if (MessageConversationId.sameConversation(cid, id)) {
            out[id] = conversation.unreadCount ?? 0;
            break;
          }
        }
      }
      return out;
    }
    final db = await _openDb();
    final out = <String, int>{};
    const chunkSize = 200;
    for (var offset = 0; offset < ids.length; offset += chunkSize) {
      final chunk = ids.sublist(
        offset,
        offset + chunkSize > ids.length ? ids.length : offset + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.rawQuery(
        '''
        SELECT conversation_id AS id, unread_count AS u FROM $_table
        WHERE owner_user_id = ? AND conversation_id IN ($placeholders)
        ''',
        <Object?>[owner, ...chunk],
      );
      for (final row in rows) {
        final id = (row['id'] as String?)?.trim() ?? '';
        if (id.isEmpty) {
          continue;
        }
        out[id] = _asInt(row['u']);
      }
    }
    return out;
  }

  Future<int> sumUnreadForConversationIds(
    Iterable<String> conversationIds, {
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final ids = conversationIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (owner.isEmpty || ids.isEmpty) {
      return 0;
    }
    if (_useMemoryOnly) {
      var sum = 0;
      for (final conversation
          in _memoryByOwner[owner] ?? const <V2TimConversation>[]) {
        for (final id in ids) {
          if (MessageConversationId.sameConversation(
            conversation.conversationID,
            id,
          )) {
            sum += conversation.unreadCount ?? 0;
            break;
          }
        }
      }
      return sum;
    }
    final db = await _openDb();
    var sum = 0;
    const chunkSize = 200;
    for (var offset = 0; offset < ids.length; offset += chunkSize) {
      final chunk = ids.sublist(
        offset,
        offset + chunkSize > ids.length ? ids.length : offset + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.rawQuery(
        '''
        SELECT SUM(unread_count) AS s FROM $_table
        WHERE owner_user_id = ? AND conversation_id IN ($placeholders)
        ''',
        <Object?>[owner, ...chunk],
      );
      sum += _asInt(rows.first['s']);
    }
    return sum;
  }

  Future<int> sumUnreadCount({String? ownerUserId}) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return 0;
    }
    if (_useMemoryOnly) {
      var sum = 0;
      for (final c in _memoryByOwner[owner] ?? const <V2TimConversation>[]) {
        sum += c.unreadCount ?? 0;
      }
      return sum;
    }
    final db = await _openDb();
    final rows = await db.rawQuery(
      'SELECT SUM(unread_count) AS s FROM $_table WHERE owner_user_id = ?',
      [owner],
    );
    return _asInt(rows.first['s']);
  }

  Future<List<String>> listGroupConversationIds({String? ownerUserId}) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return const [];
    }
    if (_useMemoryOnly) {
      return (_memoryByOwner[owner] ?? const <V2TimConversation>[])
          .map((c) => c.conversationID.trim())
          .where((id) => id.startsWith('group_'))
          .toList(growable: false);
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      columns: ['conversation_id', 'group_id'],
      where:
          "owner_user_id = ? AND (conversation_id LIKE 'group_%' OR group_id != '')",
      whereArgs: [owner],
    );
    final ids = <String>[];
    for (final row in rows) {
      final id = row['conversation_id']?.toString().trim() ?? '';
      if (id.startsWith('group_')) {
        ids.add(id);
      } else {
        final gid = row['group_id']?.toString().trim() ?? '';
        if (gid.isNotEmpty) {
          ids.add('group_$gid');
        }
      }
    }
    return ids;
  }

  Future<V2TimConversation?> findByLastMsgId(
    String msgId, {
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final id = msgId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return null;
    }
    if (_useMemoryOnly) {
      for (final item in _memoryByOwner[owner] ?? const <V2TimConversation>[]) {
        final last = item.lastMessage;
        if (last == null) {
          continue;
        }
        if (lastMessageMatchesRevokeTarget(last, id)) {
          _decorateConversation(item);
          return item;
        }
      }
      return null;
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND last_msg_id = ?',
      whereArgs: [owner, id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final conversation = _conversationFromRow(rows.first);
    if (conversation == null) {
      return null;
    }
    _decorateConversation(conversation);
    return conversation;
  }

  Future<V2TimConversation?> conversationById(
    String conversationID, {
    String? ownerUserId,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    if (_useMemoryOnly) {
      for (final item in _memoryByOwner[owner] ?? const <V2TimConversation>[]) {
        if (MessageConversationId.sameConversation(item.conversationID, id)) {
          _decorateConversation(item);
          return item;
        }
      }
      return null;
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [owner, id],
      limit: 1,
    );
    Map<String, Object?>? row = rows.isNotEmpty ? rows.first : null;
    row ??= await _findPersistedConversationRow(
      db,
      owner: owner,
      conversationId: id,
    );
    if (row == null) {
      return null;
    }
    final conversation = _conversationFromRow(row);
    if (conversation == null) {
      return null;
    }
    _decorateConversation(conversation);
    return conversation;
  }

  /// 批量按 id 取库内行（UI soft/merge-preserve 热路径）。
  Future<List<V2TimConversation>> conversationsByIds(
    List<String> conversationIds, {
    String? ownerUserId,
    int phaseWaitMs = 0,
    Stopwatch? phaseTotalSw,
    String caller = 'unspecified',
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || conversationIds.isEmpty) {
      return const [];
    }
    final wanted = <String>{};
    for (final raw in conversationIds) {
      final id = raw.trim();
      if (id.isNotEmpty) {
        wanted.add(id);
      }
    }
    if (wanted.isEmpty) {
      return const [];
    }
    final totalSw = phaseTotalSw ?? (Stopwatch()..start());
    final token = SqfliteLockProfileLog.beginOp(
      dbTag: _dbName,
      op: 'conversationsByIds',
      extras: <String, Object?>{
        'count': wanted.length,
        if (ConversationPerfFlags.conversationsByIdsCallerLogEnabled)
          'caller': caller,
      },
    );
    try {
      if (_useMemoryOnly) {
        final out = <V2TimConversation>[];
        for (final item
            in _memoryByOwner[owner] ?? const <V2TimConversation>[]) {
          final id = item.conversationID.trim();
          if (id.isEmpty) {
            continue;
          }
          final hit = wanted.any(
            (w) => MessageConversationId.sameConversation(id, w),
          );
          if (!hit) {
            continue;
          }
          _decorateConversation(item);
          out.add(item);
        }
        return out;
      }
      final querySw = Stopwatch()..start();
      final db = await _openDb();
      final ids = wanted.toList(growable: false);
      final placeholders = List.filled(ids.length, '?').join(',');
      final rows = await db.query(
        _table,
        where: 'owner_user_id = ? AND conversation_id IN ($placeholders)',
        whereArgs: [owner, ...ids],
      );
      final out = await _conversationsFromDbRows(rows);
      final found = <String>{
        for (final conversation in out) conversation.conversationID.trim(),
      };
      // 兼容 id 形态差异：IN 未命中的再走模糊查找。
      for (final id in ids) {
        if (found.any((f) => MessageConversationId.sameConversation(f, id))) {
          continue;
        }
        final row = await _findPersistedConversationRow(
          db,
          owner: owner,
          conversationId: id,
        );
        if (row == null) {
          continue;
        }
        final patched = await _conversationsFromDbRows([row]);
        if (patched.isEmpty) {
          continue;
        }
        out.add(patched.first);
      }
      final queryMs = querySw.elapsedMilliseconds;
      if (ConversationPerfFlags.conversationsByIdsPhaseLogEnabled) {
        ConversationPerfGateLog.log(
          'conversationsByIds_phases',
          extras: <String, Object?>{
            'count': wanted.length,
            'waitMs': phaseWaitMs,
            'queryMs': queryMs,
            'totalMs': totalSw.elapsedMilliseconds,
            if (ConversationPerfFlags.conversationsByIdsCallerLogEnabled)
              'caller': caller,
          },
        );
      }
      return out;
    } finally {
      SqfliteLockProfileLog.endOp(token);
    }
  }

  static void decorateConversationForUi(V2TimConversation conversation) {
    if (!MessageConversationId.messageBelongsToConversation(
      conversation.lastMessage,
      conversation.conversationID,
    )) {
      conversation.lastMessage = null;
    }
    DisplayNameStore.instance.applyToConversation(conversation);
  }

  static int compareConversationsForUi(
    V2TimConversation a,
    V2TimConversation b,
  ) {
    return _sortConversations(a, b);
  }

  /// 两段已经各自排好序的会话列表，按 UI 顺序线性合并。
  static List<V2TimConversation> mergeConversationsForUi(
    List<V2TimConversation> first,
    List<V2TimConversation> second,
  ) {
    if (first.isEmpty) return List<V2TimConversation>.from(second);
    if (second.isEmpty) return List<V2TimConversation>.from(first);

    // Pages and realtime patches can overlap. A plain two-way merge assumes
    // disjoint inputs and duplicates rows when a patch is also present in the
    // loaded page. Canonicalize IDs first, then sort one committed view.
    final byId = <String, V2TimConversation>{};
    for (final row in <V2TimConversation>[...first, ...second]) {
      final id = row.conversationID.trim();
      if (id.isEmpty) continue;
      final key = MessageConversationId.normalizeComparableKey(id);
      final existing = byId[key];
      if (existing == null) {
        byId[key] = row;
      } else {
        byId[key] = preferConversationForUi(existing, row);
      }
    }
    final out = byId.values.toList(growable: false);
    out.sort(compareConversationsForUi);
    return out;
  }

  static V2TimConversation preferConversationForUi(
    V2TimConversation existing,
    V2TimConversation incoming,
  ) {
    final preferredLast = ConversationLastMessagePrefer.preferLastMessage(
      existing: existing.lastMessage,
      incoming: incoming.lastMessage,
    );
    final preferred =
        incoming.lastMessage == preferredLast ? incoming : existing;
    preferred.unreadCount =
        math.max(existing.unreadCount ?? 0, incoming.unreadCount ?? 0);
    preferred.lastMessage = preferredLast;
    preferred.isPinned = incoming.isPinned ?? existing.isPinned;
    preferred.orderkey =
        math.max(existing.orderkey ?? 0, incoming.orderkey ?? 0);
    return preferred;
  }

  /// Plan 094: 公开通用写入口，仅限 072 rollback allowlist（kill-switch
  /// 回滚路径）与测试钩子使用。生产权威模式必须走 [commitCoordinatorPlan]；
  /// 新调用者不得直接调用本方法（见 `conversation_sync_service.dart` 的
  /// `_commitSdkConversationBatch` 注释）。等价 ID 合并语义由 Coordinator
  /// 字段权威接管，本方法只做数据库整行 upsert。
  Future<List<V2TimConversation>> upsertBatch({
    required List<V2TimConversation> conversations,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || conversations.isEmpty) {
      return const [];
    }
    if (!SqfliteLifecycleGuard.instance.writesAllowed) {
      _queueCoalesceWithoutFlush(
        owner: owner,
        conversations: conversations,
      );
      return conversations;
    }
    if (_useMemoryOnly ||
        !ConversationPerfFlags.upsertWriteCoalesceEnabled ||
        bypassUpsertCoalesceForTest) {
      return _upsertBatchImpl(conversations: conversations, ownerUserId: owner);
    }
    while (_upsertCoalesceOwner != null &&
        _upsertCoalesceOwner != owner &&
        (_upsertCoalesceFlushing ||
            _upsertCoalesceById.isNotEmpty ||
            _upsertCoalesceWaiters.isNotEmpty)) {
      await _flushUpsertCoalesceNow();
    }
    _upsertCoalesceOwner = owner;
    final requestedKeys = <String>{};
    for (final conversation in conversations) {
      final id = conversation.conversationID.trim();
      if (id.isNotEmpty) {
        final key = _conversationEquivalenceKey(id);
        _upsertCoalesceById[key] = conversation;
        requestedKeys.add(key);
      }
    }
    if (requestedKeys.isEmpty) {
      return const <V2TimConversation>[];
    }
    _upsertCoalesceFirstQueuedAt ??= DateTime.now();
    final waiter = _UpsertCoalesceWaiter(requestedKeys);
    _upsertCoalesceWaiters.add(waiter);
    _scheduleUpsertCoalesceFlush();
    return waiter.completer.future;
  }

  @visibleForTesting
  Future<void> flushUpsertWriteCoalesceForTest() => _flushUpsertCoalesceNow();

  /// 等 upsert coalesce 刷完（或超时），供读路径错峰。
  Future<void> waitUntilUpsertWriteIdle({
    Duration maxWait = const Duration(milliseconds: 800),
  }) async {
    if (!SqfliteLifecycleGuard.instance.writesAllowed) {
      final active = _upsertCoalesceFlushCompleter;
      if (active != null) {
        try {
          await active.future.timeout(maxWait);
        } catch (_) {}
      }
      return;
    }
    if (_useMemoryOnly ||
        !ConversationPerfFlags.upsertWriteCoalesceEnabled ||
        bypassUpsertCoalesceForTest) {
      return;
    }
    final deadline = DateTime.now().add(maxWait);
    while (_upsertCoalesceFlushing ||
        _upsertCoalesceById.isNotEmpty ||
        _upsertCoalesceWaiters.isNotEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        ConversationPerfGateLog.log(
          'upsert_idle_wait_timeout',
          extras: <String, Object?>{
            'flushing': _upsertCoalesceFlushing,
            'queued': _upsertCoalesceById.length,
            'waiters': _upsertCoalesceWaiters.length,
          },
        );
        return;
      }
      final active = _upsertCoalesceFlushCompleter;
      if (active != null) {
        await active.future;
        continue;
      }
      // 已排队未 flush：触发一次并等待。
      if (_upsertCoalesceById.isNotEmpty || _upsertCoalesceWaiters.isNotEmpty) {
        unawaited(_flushUpsertCoalesceNow());
        final started = _upsertCoalesceFlushCompleter;
        if (started != null) {
          await started.future;
          continue;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  void pauseCoalesceForBackground() {
    _upsertCoalesceTimer?.cancel();
    _upsertCoalesceTimer = null;
    _completeCoalesceWaitersFromQueued();
  }

  void resumeCoalesceAfterForeground() {
    if (!SqfliteLifecycleGuard.instance.writesAllowed) {
      return;
    }
    if (_upsertCoalesceById.isEmpty && _upsertCoalesceWaiters.isEmpty) {
      return;
    }
    final cap = ConversationPerfFlags.resumeForegroundCoalesceBatchCap;
    if (cap > 0 && _upsertCoalesceById.length > cap) {
      _resumeForegroundStagedFlushActive = true;
    }
    _scheduleUpsertCoalesceFlush();
  }

  void _queueCoalesceWithoutFlush({
    required String owner,
    required List<V2TimConversation> conversations,
  }) {
    _upsertCoalesceOwner = owner;
    for (final conversation in conversations) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      _upsertCoalesceById[_conversationEquivalenceKey(id)] = conversation;
    }
    _upsertCoalesceTimer?.cancel();
    _upsertCoalesceTimer = null;
  }

  void _completeCoalesceWaitersFromQueued() {
    if (_upsertCoalesceWaiters.isEmpty) {
      return;
    }
    final waiters = List<_UpsertCoalesceWaiter>.from(_upsertCoalesceWaiters);
    _upsertCoalesceWaiters.clear();
    for (final waiter in waiters) {
      if (waiter.completer.isCompleted) {
        continue;
      }
      final scoped = <V2TimConversation>[];
      for (final key in waiter.requestedKeys) {
        final conversation = _upsertCoalesceById[key];
        if (conversation != null) {
          scoped.add(conversation);
        }
      }
      waiter.completer.complete(scoped);
    }
  }

  void _scheduleUpsertCoalesceFlush() {
    if (!SqfliteLifecycleGuard.instance.writesAllowed) {
      return;
    }
    if (_upsertCoalesceById.isEmpty && _upsertCoalesceWaiters.isEmpty) {
      return;
    }
    _upsertCoalesceTimer?.cancel();
    final busy = isUiBusyForWriteCoalesce?.call() ?? false;
    final quietDelay = busy
        ? ConversationPerfFlags.upsertWriteCoalesceDelayBusy
        : ConversationPerfFlags.upsertWriteCoalesceDelay;
    final maxDelay = busy
        ? ConversationPerfFlags.upsertWriteCoalesceMaxDelayBusy
        : ConversationPerfFlags.upsertWriteCoalesceMaxDelay;
    var delay = quietDelay;
    final firstQueuedAt = _upsertCoalesceFirstQueuedAt;
    if (firstQueuedAt != null && maxDelay > Duration.zero) {
      final remaining = maxDelay - DateTime.now().difference(firstQueuedAt);
      if (remaining <= Duration.zero) {
        delay = Duration.zero;
      } else if (delay <= Duration.zero || remaining < delay) {
        delay = remaining;
      }
    }
    if (delay <= Duration.zero) {
      unawaited(_flushUpsertCoalesceNow());
      return;
    }
    _upsertCoalesceTimer = Timer(delay, () {
      unawaited(_flushUpsertCoalesceNow());
    });
  }

  Future<void> _flushUpsertCoalesceNow() async {
    _upsertCoalesceTimer?.cancel();
    _upsertCoalesceTimer = null;
    if (!SqfliteLifecycleGuard.instance.writesAllowed) {
      _completeCoalesceWaitersFromQueued();
      return;
    }
    if (_upsertCoalesceFlushing) {
      final active = _upsertCoalesceFlushCompleter;
      if (active != null) {
        await active.future;
      }
      return;
    }
    if (_upsertCoalesceById.isEmpty && _upsertCoalesceWaiters.isEmpty) {
      _upsertCoalesceOwner = null;
      _upsertCoalesceFirstQueuedAt = null;
      return;
    }
    _upsertCoalesceFlushing = true;
    final flushCompleter = Completer<void>();
    _upsertCoalesceFlushCompleter = flushCompleter;
    final generation = _upsertCoalesceGeneration;
    final owner = _upsertCoalesceOwner ?? '';
    var batch = _upsertCoalesceById.values.toList(growable: false);
    final cap = ConversationPerfFlags.resumeForegroundCoalesceBatchCap;
    if (_resumeForegroundStagedFlushActive && cap > 0 && batch.length > cap) {
      final remainder = batch.sublist(cap);
      batch = batch.sublist(0, cap);
      _upsertCoalesceById.clear();
      for (final conversation in remainder) {
        final id = conversation.conversationID.trim();
        if (id.isEmpty) {
          continue;
        }
        _upsertCoalesceById[_conversationEquivalenceKey(id)] = conversation;
      }
    } else {
      _upsertCoalesceById.clear();
      _resumeForegroundStagedFlushActive = false;
    }
    final waiters = List<_UpsertCoalesceWaiter>.from(_upsertCoalesceWaiters);
    _upsertCoalesceWaiters.clear();
    _upsertCoalesceInFlightWaiters
      ..clear()
      ..addAll(waiters);
    _upsertCoalesceFirstQueuedAt = null;
    try {
      if (batch.isEmpty || owner.isEmpty) {
        for (final waiter in waiters) {
          if (!waiter.completer.isCompleted) {
            waiter.completer.complete(const <V2TimConversation>[]);
          }
        }
        return;
      }
      SqfliteLockProfileLog.event(
        'upsertBatch_coalesced',
        extras: <String, Object?>{
          'count': batch.length,
          'waiters': waiters.length,
        },
      );
      try {
        final result = await _upsertBatchImpl(
          conversations: batch,
          ownerUserId: owner,
        );
        final resultByKey = <String, V2TimConversation>{
          for (final conversation in result)
            _conversationEquivalenceKey(conversation.conversationID):
                conversation,
        };
        for (final waiter in waiters) {
          if (waiter.completer.isCompleted) {
            continue;
          }
          if (generation != _upsertCoalesceGeneration) {
            waiter.completer.complete(const <V2TimConversation>[]);
            continue;
          }
          final scoped = <V2TimConversation>[];
          for (final key in waiter.requestedKeys) {
            final conversation = resultByKey[key];
            if (conversation != null) {
              scoped.add(conversation);
            }
          }
          waiter.completer.complete(scoped);
        }
      } catch (e, st) {
        for (final waiter in waiters) {
          if (!waiter.completer.isCompleted) {
            waiter.completer.completeError(e, st);
          }
        }
      }
    } finally {
      _upsertCoalesceInFlightWaiters.clear();
      _upsertCoalesceFlushing = false;
      if (_upsertCoalesceById.isNotEmpty || _upsertCoalesceWaiters.isNotEmpty) {
        _upsertCoalesceFirstQueuedAt ??= DateTime.now();
        if (_resumeForegroundStagedFlushActive &&
            _upsertCoalesceById.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scheduleUpsertCoalesceFlush();
          });
        } else {
          _scheduleUpsertCoalesceFlush();
        }
      } else {
        _resumeForegroundStagedFlushActive = false;
        _upsertCoalesceOwner = null;
        _upsertCoalesceFirstQueuedAt = null;
      }
      if (!flushCompleter.isCompleted) {
        flushCompleter.complete();
      }
      _upsertCoalesceFlushCompleter = null;
    }
  }

  Future<List<V2TimConversation>> _upsertBatchImpl({
    required List<V2TimConversation> conversations,
    required String ownerUserId,
    bool invokeBeforeHook = true,
    DatabaseExecutor? executor,
    List<ConversationUiUnreadDelta>? unreadDeltas,
  }) async {
    final beforeImpl = invokeBeforeHook ? beforeUpsertBatchImplForTest : null;
    if (beforeImpl != null) {
      await beforeImpl();
    }
    final owner = ownerUserId;
    if (owner.isEmpty || conversations.isEmpty) {
      return const [];
    }
    final chunkSize = ConversationPerfFlags.upsertTransactionChunkSize;
    if (executor == null &&
        !_useMemoryOnly &&
        chunkSize > 0 &&
        conversations.length > chunkSize) {
      final merged = <V2TimConversation>[];
      for (var offset = 0; offset < conversations.length; offset += chunkSize) {
        final end = offset + chunkSize > conversations.length
            ? conversations.length
            : offset + chunkSize;
        merged.addAll(
          await _upsertBatchImpl(
            conversations: conversations.sublist(offset, end),
            ownerUserId: owner,
            invokeBeforeHook: false,
            unreadDeltas: unreadDeltas,
          ),
        );
        if (end < conversations.length) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      return merged;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final merged = <V2TimConversation>[];
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const <V2TimConversation>[],
      );
      for (final conversation in conversations) {
        final id = conversation.conversationID.trim();
        if (id.isEmpty) {
          continue;
        }
        final existingIdx = _findConversationIndex(list, id);
        final existing = existingIdx == null ? null : list[existingIdx];
        final oldUnread = existing == null
            ? 0
            : ConversationUnreadUtils.notifiableUnreadForAggregate(
                existing,
                archivedC2c: const <String>{},
                archivedGroup: const <String>{},
              );
        final mergeId = existing?.conversationID ?? id;
        if (existing != null) {
          conversation.conversationID = mergeId;
          _mergeConversationLastMessage(
            existing,
            conversation,
            owner: owner,
            conversationId: mergeId,
            rowHistoryClearedAtMs: _resolvedHistoryClearedAtMs(
              owner: owner,
              conversationId: mergeId,
              rowHistoryClearedAtMs: 0,
            ),
          );
          _mergeConversationUnread(
            existing: existing,
            incoming: conversation,
            owner: owner,
            conversationId: mergeId,
            readClearedAtMs: _resolvedReadClearedAtMs(
              owner: owner,
              conversationId: mergeId,
              rowReadClearedAtMs: 0,
            ),
          );
          conversation.draftText = existing.draftText;
          conversation.draftTimestamp = existing.draftTimestamp;
          _applyBackendPinnedFlag(conversation);
          list[existingIdx!] = conversation;
        } else {
          _applyBackendPinnedFlag(conversation);
          list.add(conversation);
        }
        _captureDisplayName(conversation);
        merged.add(conversation);
        unreadDeltas?.add(
          ConversationUiUnreadDelta(
            isGroup: conversation.type == 2,
            oldNotifiable: oldUnread,
            newNotifiable: ConversationUnreadUtils.notifiableUnreadForAggregate(
              conversation,
              archivedC2c: const <String>{},
              archivedGroup: const <String>{},
            ),
          ),
        );
      }
      list.sort(_sortConversations);
      _memoryByOwner[owner] = list;
      return merged;
    }
    Future<void> applyRows(DatabaseExecutor txn) async {
      final ids = <String>{};
      for (final conversation in conversations) {
        final id = conversation.conversationID.trim();
        if (id.isEmpty) {
          continue;
        }
        ids.add(id);
        final lower = id.toLowerCase();
        if (lower.startsWith('group_')) {
          final bare = id.substring(6);
          if (bare.isNotEmpty) {
            ids.add(bare);
            final normalized = ChatIdFormat.normalizeGroupId(bare);
            if (normalized.isNotEmpty) {
              ids.add(normalized);
              ids.add('group_$normalized');
            }
          }
        } else if (ChatIdFormat.isIMGroupOrCommunityId(id)) {
          final normalized = ChatIdFormat.normalizeGroupId(id);
          if (normalized.isNotEmpty) {
            ids.add(normalized);
            ids.add('group_$normalized');
          }
        }
      }
      final rowByExactId = <String, Map<String, Object?>>{};
      if (ids.isNotEmpty) {
        // SQLite 变量上限保守分批 IN 查询，避免逐条 _findPersistedConversationRow。
        const chunkSize = 200;
        final idList = ids.toList(growable: false);
        for (var offset = 0; offset < idList.length; offset += chunkSize) {
          final chunk = idList.sublist(
            offset,
            offset + chunkSize > idList.length
                ? idList.length
                : offset + chunkSize,
          );
          final placeholders = List.filled(chunk.length, '?').join(',');
          final rows = await txn.query(
            _table,
            columns: _upsertFetchColumns,
            where: 'owner_user_id = ? AND conversation_id IN ($placeholders)',
            whereArgs: <Object?>[owner, ...chunk],
          );
          for (final row in rows) {
            final storedId = row['conversation_id']?.toString() ?? '';
            if (storedId.isNotEmpty) {
              rowByExactId[storedId] = row;
            }
          }
        }
      }

      Future<Map<String, Object?>?> resolveRow(String id) async {
        final exact = rowByExactId[id];
        if (exact != null) {
          return exact;
        }
        final lower = id.toLowerCase();
        if (!lower.startsWith('group_') &&
            !ChatIdFormat.isIMGroupOrCommunityId(id)) {
          return null;
        }
        // 歧义 id：只按候选 conversation_id IN (...) 查，禁止全表 conv_type=2。
        final candidates = <String>{id};
        if (lower.startsWith('group_')) {
          final bare = id.substring(6);
          if (bare.isNotEmpty) {
            candidates.add(bare);
            final normalized = ChatIdFormat.normalizeGroupId(bare);
            if (normalized.isNotEmpty) {
              candidates.add(normalized);
              candidates.add('group_$normalized');
            }
          }
        } else {
          final normalized = ChatIdFormat.normalizeGroupId(id);
          if (normalized.isNotEmpty) {
            candidates.add(normalized);
            candidates.add('group_$normalized');
          }
        }
        final missing = candidates
            .where((c) => !rowByExactId.containsKey(c))
            .toList(growable: false);
        if (missing.isNotEmpty) {
          final placeholders = List.filled(missing.length, '?').join(',');
          final rows = await txn.query(
            _table,
            columns: _upsertFetchColumns,
            where: 'owner_user_id = ? AND conversation_id IN ($placeholders)',
            whereArgs: <Object?>[owner, ...missing],
          );
          for (final row in rows) {
            final storedId = row['conversation_id']?.toString() ?? '';
            if (storedId.isNotEmpty) {
              rowByExactId[storedId] = row;
            }
          }
        }
        for (final candidate in candidates) {
          final hit = rowByExactId[candidate];
          if (hit != null) {
            rowByExactId[id] = hit;
            return hit;
          }
        }
        // 受限 fallback：仅当候选皆未命中，按 sameConversation 扫已缓存 exact 行。
        for (final entry in rowByExactId.entries) {
          if (MessageConversationId.sameConversation(entry.key, id)) {
            ConversationPerfGateLog.log(
              'upsert_group_resolve_fallback',
              extras: <String, Object?>{
                'id': id,
                'storedId': entry.key,
              },
            );
            rowByExactId[id] = entry.value;
            return entry.value;
          }
        }
        return null;
      }

      final batch = txn.batch();
      var writeCount = 0;
      for (final conversation in conversations) {
        final id = conversation.conversationID.trim();
        if (id.isEmpty) {
          continue;
        }
        final row = await resolveRow(id);
        final existingUnread = row == null
            ? 0
            : ConversationUnreadUtils.notifiableUnreadFromColumns(
                unreadCount: row['unread_count'] as int? ?? 0,
                recvOpt: row['recv_opt'] as int? ?? 0,
                groupType: row['group_type']?.toString() ?? '',
              );
        var preservedLocalDraftText = '';
        var preservedLocalDraftUpdatedAtMs = 0;
        if (row != null) {
          final storedId = row['conversation_id']?.toString() ?? id;
          conversation.conversationID = storedId;
          preservedLocalDraftText = _localDraftTextFromRow(row);
          preservedLocalDraftUpdatedAtMs = _localDraftUpdatedAtMsFromRow(row);
          _applyBackendPinnedFlag(conversation);
          _applyPreservedLocalDraftOnIncoming(
            conversation,
            preservedLocalDraftText: preservedLocalDraftText,
            preservedLocalDraftUpdatedAtMs: preservedLocalDraftUpdatedAtMs,
          );
          _captureDisplayName(conversation);
          final rowReadClearedAtMs = row['read_cleared_at'] as int? ?? 0;
          final fastReadClearedAt = _readClearedAtForPersistedRow(
            owner: owner,
            conversationId: storedId,
            conversation: conversation,
            existingReadClearedAtMs: rowReadClearedAtMs,
          );
          final fastHistoryClearedAt = _historyClearedAtForPersistedRow(
            owner: owner,
            conversationId: storedId,
            incoming: conversation,
            existingHistoryClearedAtMs: row['history_cleared_at'] as int? ?? 0,
          );
          // 轻量指纹：先比列字段，unchanged 时跳过 jsonEncode（省 UTF-8/SHA/Channel）。
          if (ConversationPerfFlags.useLightweightFingerprint) {
            final probe = _comparisonProbeFromConversation(
              owner,
              conversation,
              readClearedAtMs: fastReadClearedAt,
              historyClearedAtMs: fastHistoryClearedAt,
              localDraftText: preservedLocalDraftText,
              localDraftUpdatedAtMs: preservedLocalDraftUpdatedAtMs,
            );
            if (_samePersistedConversationRow(row, probe)) {
              continue;
            }
          } else {
            final fastRawJson = jsonEncode(conversation.toJson());
            final fastRow = _rowFromConversation(
              owner,
              conversation,
              now,
              readClearedAtMs: fastReadClearedAt,
              historyClearedAtMs: fastHistoryClearedAt,
              localDraftText: preservedLocalDraftText,
              localDraftUpdatedAtMs: preservedLocalDraftUpdatedAtMs,
              rawJson: fastRawJson,
            );
            if (_samePersistedConversationRow(row, fastRow)) {
              continue;
            }
          }
          final existing = _conversationFromRow(row);
          if (existing != null) {
            _mergeConversationLastMessage(
              existing,
              conversation,
              owner: owner,
              conversationId: storedId,
              rowHistoryClearedAtMs: row['history_cleared_at'] as int? ?? 0,
            );
            _mergeConversationUnread(
              existing: existing,
              incoming: conversation,
              owner: owner,
              conversationId: storedId,
              readClearedAtMs: _resolvedReadClearedAtMs(
                owner: owner,
                conversationId: storedId,
                rowReadClearedAtMs: rowReadClearedAtMs,
              ),
            );
          }
          _applyBackendPinnedFlag(conversation);
        } else {
          _applyBackendPinnedFlag(conversation);
        }
        _captureDisplayName(conversation);
        _applyPreservedLocalDraftOnIncoming(
          conversation,
          preservedLocalDraftText: preservedLocalDraftText,
          preservedLocalDraftUpdatedAtMs: preservedLocalDraftUpdatedAtMs,
        );
        final persistedReadClearedAt = row != null
            ? _readClearedAtForPersistedRow(
                owner: owner,
                conversationId: conversation.conversationID.trim(),
                conversation: conversation,
                existingReadClearedAtMs: row['read_cleared_at'] as int? ?? 0,
              )
            : _readClearedAtForPersistedRow(
                owner: owner,
                conversationId: conversation.conversationID.trim(),
                conversation: conversation,
                existingReadClearedAtMs: 0,
              );
        final persistedHistoryClearedAt = row != null
            ? _historyClearedAtForPersistedRow(
                owner: owner,
                conversationId: conversation.conversationID.trim(),
                incoming: conversation,
                existingHistoryClearedAtMs:
                    row['history_cleared_at'] as int? ?? 0,
              )
            : _resolvedHistoryClearedAtMs(
                owner: owner,
                conversationId: conversation.conversationID.trim(),
                rowHistoryClearedAtMs: 0,
              );
        final rawJson = jsonEncode(conversation.toJson());
        final nextRow = _rowFromConversation(
          owner,
          conversation,
          now,
          readClearedAtMs: persistedReadClearedAt,
          historyClearedAtMs: persistedHistoryClearedAt,
          localDraftText: preservedLocalDraftText,
          localDraftUpdatedAtMs: preservedLocalDraftUpdatedAtMs,
          rawJson: rawJson,
        );
        if (row != null && _samePersistedConversationRow(row, nextRow)) {
          continue;
        }
        batch.insert(
          _table,
          nextRow,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        writeCount++;
        merged.add(conversation);
        unreadDeltas?.add(
          ConversationUiUnreadDelta(
            isGroup: conversation.type == 2,
            oldNotifiable: existingUnread,
            newNotifiable: ConversationUnreadUtils.notifiableUnreadForAggregate(
              conversation,
              archivedC2c: const <String>{},
              archivedGroup: const <String>{},
            ),
          ),
        );
      }
      if (writeCount > 0) {
        await batch.commit(noResult: true);
      } else {
        SqfliteLockProfileLog.event(
          'upsertBatch_skip_unchanged',
          extras: <String, Object?>{'count': conversations.length},
        );
      }
    }

    if (executor != null) {
      await applyRows(executor);
    } else {
      final db = await _openDb();
      await profiledTransaction<void>(
        db,
        dbTag: _dbName,
        op: 'upsertBatch',
        extras: <String, Object?>{'count': conversations.length},
        action: applyRows,
      );
    }
    return merged;
  }

  Future<ConversationDatabaseCommitResult<V2TimConversation>>
      commitCoordinatorPlan({
    required ConversationDatabaseCommitPlan<V2TimConversation> plan,
  }) async {
    _profileCoordinatorPlanCommits++;
    final owner = plan.ownerUserId.trim();
    final canonicalId = plan.canonicalConversationId.trim();
    if (owner.isEmpty || canonicalId.isEmpty) {
      return ConversationDatabaseCommitResult<V2TimConversation>(
        disposition:
            ConversationDatabaseCommitDisposition.rejectedEmptyIdentity,
        plan: plan,
      );
    }
    final state = await _loadCoordinatorCommitState(
      owner: owner,
      canonicalConversationId: canonicalId,
    );
    Future<void> acceptState({required int? tombstoneGeneration}) async {
      state
        ..generation = plan.generation
        ..tombstoneGeneration = tombstoneGeneration;
      state.idempotencyKeys.add(plan.idempotencyKey);
      await _persistCoordinatorCommitState(
        owner: owner,
        canonicalConversationId: canonicalId,
        state: state,
      );
    }

    if (state.idempotencyKeys.contains(plan.idempotencyKey)) {
      return ConversationDatabaseCommitResult<V2TimConversation>(
        disposition: ConversationDatabaseCommitDisposition.ignoredDuplicate,
        plan: plan,
      );
    }
    if (plan.generation < state.generation) {
      return ConversationDatabaseCommitResult<V2TimConversation>(
        disposition:
            ConversationDatabaseCommitDisposition.rejectedStaleGeneration,
        plan: plan,
      );
    }
    final tombstoneGeneration = state.tombstoneGeneration;
    if (tombstoneGeneration != null &&
        plan.changeType == ConversationDatabaseChangeType.upsert) {
      final canRecreate = plan.recreatesDeletedConversation &&
          plan.generation > tombstoneGeneration;
      if (!canRecreate) {
        return ConversationDatabaseCommitResult<V2TimConversation>(
          disposition:
              ConversationDatabaseCommitDisposition.rejectedByTombstone,
          plan: plan,
        );
      }
    }
    if (plan.changeType == ConversationDatabaseChangeType.upsert) {
      if (_isDraftOnlyCoordinatorPatch(plan.fieldPatch)) {
        final draft =
            plan.fieldPatch[ConversationMutationField.draft]?.toString() ?? '';
        final updated = draft.trim().isEmpty
            ? await clearLocalDraft(
                conversationID: canonicalId,
                ownerUserId: owner,
              )
            : await updateLocalDraft(
                conversationID: canonicalId,
                draftText: draft,
                ownerUserId: owner,
              );
        await acceptState(tombstoneGeneration: null);
        return ConversationDatabaseCommitResult<V2TimConversation>(
          disposition: updated == null
              ? ConversationDatabaseCommitDisposition.noop
              : ConversationDatabaseCommitDisposition.applied,
          plan: plan,
          upsertedSnapshots: updated == null
              ? const <V2TimConversation>[]
              : <V2TimConversation>[updated],
          shouldNotifyUi: updated != null,
        );
      }
      if (_isMarkReadCoordinatorPatch(plan.fieldPatch)) {
        final updated = await markConversationReadLocally(
          canonicalId,
          ownerUserId: owner,
        );
        await acceptState(tombstoneGeneration: null);
        return ConversationDatabaseCommitResult<V2TimConversation>(
          disposition: updated == null
              ? ConversationDatabaseCommitDisposition.noop
              : ConversationDatabaseCommitDisposition.applied,
          plan: plan,
          upsertedSnapshots: updated == null
              ? const <V2TimConversation>[]
              : <V2TimConversation>[updated],
          shouldNotifyUi: updated != null,
        );
      }
      if (_isUnreadCountCoordinatorPatch(plan.fieldPatch)) {
        final updated = await updateConversationUnreadCountLocally(
          conversationID: canonicalId,
          unreadCount: plan.fieldPatch[ConversationMutationField.unread] as int,
          ownerUserId: owner,
          snapshot: plan.fullSnapshot,
        );
        await acceptState(tombstoneGeneration: null);
        return ConversationDatabaseCommitResult<V2TimConversation>(
          disposition: updated == null
              ? ConversationDatabaseCommitDisposition.noop
              : ConversationDatabaseCommitDisposition.applied,
          plan: plan,
          upsertedSnapshots: updated == null
              ? const <V2TimConversation>[]
              : <V2TimConversation>[updated],
          shouldNotifyUi: updated != null,
        );
      }
      if (_isPinOnlyCoordinatorPatch(plan.fieldPatch)) {
        final updated = await updateConversationPinnedLocally(
          conversationID: canonicalId,
          isPinned: plan.fieldPatch[ConversationMutationField.pin] == true,
          ownerUserId: owner,
          snapshot: plan.fullSnapshot,
        );
        await acceptState(tombstoneGeneration: null);
        return ConversationDatabaseCommitResult<V2TimConversation>(
          disposition: updated == null
              ? ConversationDatabaseCommitDisposition.noop
              : ConversationDatabaseCommitDisposition.applied,
          plan: plan,
          upsertedSnapshots: updated == null
              ? const <V2TimConversation>[]
              : <V2TimConversation>[updated],
          shouldNotifyUi: updated != null,
        );
      }
      if (_isMuteOnlyCoordinatorPatch(plan.fieldPatch)) {
        final updated = await updateConversationRecvOptLocally(
          conversationID: canonicalId,
          recvOpt: plan.fieldPatch[ConversationMutationField.mute] as int,
          ownerUserId: owner,
          snapshot: plan.fullSnapshot,
        );
        await acceptState(tombstoneGeneration: null);
        return ConversationDatabaseCommitResult<V2TimConversation>(
          disposition: updated == null
              ? ConversationDatabaseCommitDisposition.noop
              : ConversationDatabaseCommitDisposition.applied,
          plan: plan,
          upsertedSnapshots: updated == null
              ? const <V2TimConversation>[]
              : <V2TimConversation>[updated],
          shouldNotifyUi: updated != null,
        );
      }
      if (_isMetadataCoordinatorPatch(plan.fieldPatch)) {
        final updated = await updateConversationMetadataLocally(
          conversationID: canonicalId,
          showName: plan.fieldPatch[ConversationMutationField.name] as String?,
          faceUrl: plan.fieldPatch[ConversationMutationField.avatar] as String?,
          ownerUserId: owner,
          snapshot: plan.fullSnapshot,
        );
        await acceptState(tombstoneGeneration: null);
        return ConversationDatabaseCommitResult<V2TimConversation>(
          disposition: updated == null
              ? ConversationDatabaseCommitDisposition.noop
              : ConversationDatabaseCommitDisposition.applied,
          plan: plan,
          upsertedSnapshots: updated == null
              ? const <V2TimConversation>[]
              : <V2TimConversation>[updated],
          shouldNotifyUi: updated != null,
        );
      }
      final snapshot = plan.fullSnapshot;
      if (snapshot == null) {
        return ConversationDatabaseCommitResult<V2TimConversation>(
          disposition:
              ConversationDatabaseCommitDisposition.rejectedMissingSnapshot,
          plan: plan,
        );
      }
      final upserted = await _upsertBatchImpl(
        conversations: <V2TimConversation>[snapshot],
        ownerUserId: owner,
      );
      await acceptState(tombstoneGeneration: null);
      return ConversationDatabaseCommitResult<V2TimConversation>(
        disposition: upserted.isEmpty
            ? ConversationDatabaseCommitDisposition.noop
            : ConversationDatabaseCommitDisposition.applied,
        plan: plan,
        upsertedSnapshots: upserted,
        shouldNotifyUi: upserted.isNotEmpty,
      );
    }

    final previousGeneration = state.generation;
    final previousTombstoneGeneration = state.tombstoneGeneration;
    state
      ..generation = plan.generation
      ..tombstoneGeneration = plan.generation;
    state.idempotencyKeys.add(plan.idempotencyKey);
    late final List<String> deleted;
    try {
      deleted = await _deleteWithCoordinatorState(
        owner: owner,
        canonicalConversationId: canonicalId,
        state: state,
      );
    } catch (_) {
      state
        ..generation = previousGeneration
        ..tombstoneGeneration = previousTombstoneGeneration;
      state.idempotencyKeys.remove(plan.idempotencyKey);
      rethrow;
    }
    return ConversationDatabaseCommitResult<V2TimConversation>(
      disposition: deleted.isEmpty
          ? ConversationDatabaseCommitDisposition.noop
          : ConversationDatabaseCommitDisposition.applied,
      plan: plan,
      deletedConversationIds: deleted,
      shouldNotifyUi: deleted.isNotEmpty,
    );
  }

  Future<ConversationSdkCommittedBatch>
      commitCoordinatorSdkUpsertPlansBatchResult({
    required List<ConversationDatabaseCommitPlan<V2TimConversation>> plans,
  }) async {
    if (plans.isEmpty) {
      return const ConversationSdkCommittedBatch(
        upserted: <V2TimConversation>[],
        unreadDeltas: <ConversationUiUnreadDelta>[],
        unreadProjectionComplete: true,
      );
    }
    final owner = plans.first.ownerUserId.trim();
    if (owner.isEmpty ||
        plans.any((plan) => plan.ownerUserId.trim() != owner)) {
      return const ConversationSdkCommittedBatch(
        upserted: <V2TimConversation>[],
        unreadDeltas: <ConversationUiUnreadDelta>[],
        unreadProjectionComplete: false,
      );
    }
    _profileCoordinatorPlanCommits += plans.length;
    await coordinatorDurableStates(
      ownerUserId: owner,
      conversationIds: plans.map((plan) => plan.canonicalConversationId),
    );
    final accepted = <(
      ConversationDatabaseCommitPlan<V2TimConversation>,
      _CoordinatorCommitState
    )>[];
    for (final plan in plans) {
      if (plan.changeType != ConversationDatabaseChangeType.upsert ||
          plan.fullSnapshot == null) {
        continue;
      }
      final state = await _loadCoordinatorCommitState(
        owner: owner,
        canonicalConversationId: plan.canonicalConversationId,
      );
      if (state.idempotencyKeys.contains(plan.idempotencyKey) ||
          plan.generation < state.generation) {
        continue;
      }
      final tombstoneGeneration = state.tombstoneGeneration;
      if (tombstoneGeneration != null &&
          !(plan.recreatesDeletedConversation &&
              plan.generation > tombstoneGeneration)) {
        continue;
      }
      accepted.add((plan, state));
    }
    if (accepted.isEmpty) {
      return const ConversationSdkCommittedBatch(
        upserted: <V2TimConversation>[],
        unreadDeltas: <ConversationUiUnreadDelta>[],
        unreadProjectionComplete: true,
      );
    }
    final previousStates = <_CoordinatorCommitState,
        ({
      int generation,
      int? tombstoneGeneration,
      Set<String> idempotencyKeys,
    })>{
      for (final entry in accepted)
        entry.$2: (
          generation: entry.$2.generation,
          tombstoneGeneration: entry.$2.tombstoneGeneration,
          idempotencyKeys: Set<String>.from(entry.$2.idempotencyKeys),
        ),
    };
    final snapshots =
        accepted.map((entry) => entry.$1.fullSnapshot!).toList(growable: false);
    final changedFieldMasks = <String, Set<ConversationMutationField>>{
      for (final entry in accepted)
        if (entry.$1.fieldPatch.isNotEmpty)
          entry.$1.canonicalConversationId:
              Set<ConversationMutationField>.unmodifiable(
            entry.$1.fieldPatch.keys,
          ),
    };
    final structureChanged = accepted.any(
      (entry) =>
          entry.$1.recreatesDeletedConversation ||
          entry.$1.fieldPatch.containsKey(ConversationMutationField.pin) ||
          entry.$1.fieldPatch.containsKey(ConversationMutationField.order),
    );
    final beforeImpl = beforeUpsertBatchImplForTest;
    if (beforeImpl != null) {
      await beforeImpl();
    }
    for (final entry in accepted) {
      entry.$2
        ..generation = entry.$1.generation
        ..tombstoneGeneration = null;
      entry.$2.idempotencyKeys.add(entry.$1.idempotencyKey);
    }
    late final List<V2TimConversation> merged;
    final unreadDeltas = <ConversationUiUnreadDelta>[];
    if (_useMemoryOnly) {
      merged = await _upsertBatchImpl(
        conversations: snapshots,
        ownerUserId: owner,
        invokeBeforeHook: false,
        unreadDeltas: unreadDeltas,
      );
    } else {
      final db = await _openDb();
      try {
        _profileAtomicSdkTransactions++;
        merged = await profiledTransaction<List<V2TimConversation>>(
          db,
          dbTag: _dbName,
          op: 'coordinatorSdkUpsertAtomicBatch',
          extras: <String, Object?>{'count': accepted.length},
          action: (txn) async {
            final committedRows = await _upsertBatchImpl(
              conversations: snapshots,
              ownerUserId: owner,
              invokeBeforeHook: false,
              executor: txn,
              unreadDeltas: unreadDeltas,
            );
            final batch = txn.batch();
            for (final entry in accepted) {
              _profileCoordinatorStateWrites++;
              batch.insert(
                _coordinatorStateTable,
                _coordinatorStateRow(
                  owner: owner,
                  canonicalConversationId: entry.$1.canonicalConversationId,
                  state: entry.$2,
                ),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            await batch.commit(noResult: true);
            return committedRows;
          },
        );
      } catch (_) {
        for (final entry in previousStates.entries) {
          entry.key.generation = entry.value.generation;
          entry.key.tombstoneGeneration = entry.value.tombstoneGeneration;
          entry.key.idempotencyKeys
            ..clear()
            ..addAll(entry.value.idempotencyKeys);
        }
        rethrow;
      }
    }
    return ConversationSdkCommittedBatch(
      upserted: List<V2TimConversation>.unmodifiable(merged),
      unreadDeltas: List<ConversationUiUnreadDelta>.unmodifiable(unreadDeltas),
      unreadProjectionComplete: true,
      changedFieldMasks: changedFieldMasks,
      structureChanged: structureChanged,
    );
  }

  Future<List<V2TimConversation>> commitCoordinatorSdkUpsertPlansBatch({
    required List<ConversationDatabaseCommitPlan<V2TimConversation>> plans,
  }) async {
    final result = await commitCoordinatorSdkUpsertPlansBatchResult(
      plans: plans,
    );
    return result.upserted;
  }

  Future<MarkReadBatchResult> commitCoordinatorMarkReadPlans({
    required List<ConversationDatabaseCommitPlan<V2TimConversation>> plans,
  }) async {
    if (plans.isEmpty) {
      return MarkReadBatchResult.empty;
    }
    final owner = plans.first.ownerUserId.trim();
    if (owner.isEmpty ||
        plans.any((plan) => plan.ownerUserId.trim() != owner)) {
      return MarkReadBatchResult.empty;
    }
    final accepted = <(
      ConversationDatabaseCommitPlan<V2TimConversation>,
      _CoordinatorCommitState
    )>[];
    for (final plan in plans) {
      if (plan.changeType != ConversationDatabaseChangeType.upsert ||
          !_isMarkReadCoordinatorPatch(plan.fieldPatch)) {
        continue;
      }
      final state = await _loadCoordinatorCommitState(
        owner: owner,
        canonicalConversationId: plan.canonicalConversationId,
      );
      if (state.idempotencyKeys.contains(plan.idempotencyKey) ||
          plan.generation < state.generation ||
          state.tombstoneGeneration != null) {
        continue;
      }
      accepted.add((plan, state));
    }
    if (accepted.isEmpty) {
      return MarkReadBatchResult.empty;
    }
    final result = await markConversationsReadLocallyBatch(
      accepted.map((entry) => entry.$1.canonicalConversationId),
      ownerUserId: owner,
    );
    for (final entry in accepted) {
      final plan = entry.$1;
      final state = entry.$2
        ..generation = plan.generation
        ..tombstoneGeneration = null;
      state.idempotencyKeys.add(plan.idempotencyKey);
    }
    if (!_useMemoryOnly) {
      final db = await _openDb();
      await profiledTransaction<void>(
        db,
        dbTag: _dbName,
        op: 'coordinatorMarkReadStateBatch',
        extras: <String, Object?>{'count': accepted.length},
        action: (txn) async {
          final batch = txn.batch();
          for (final entry in accepted) {
            batch.insert(
              _coordinatorStateTable,
              _coordinatorStateRow(
                owner: owner,
                canonicalConversationId: entry.$1.canonicalConversationId,
                state: entry.$2,
              ),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        },
      );
    }
    return result;
  }

  Future<void> commitCoordinatorPinSetPlans({
    required List<ConversationDatabaseCommitPlan<V2TimConversation>> plans,
    required Set<String> pinnedConversationIds,
  }) async {
    if (plans.isEmpty) {
      return;
    }
    final owner = plans.first.ownerUserId.trim();
    if (owner.isEmpty ||
        plans.any((plan) => plan.ownerUserId.trim() != owner)) {
      return;
    }
    final accepted = <(
      ConversationDatabaseCommitPlan<V2TimConversation>,
      _CoordinatorCommitState
    )>[];
    for (final plan in plans) {
      if (plan.changeType != ConversationDatabaseChangeType.upsert ||
          !_isPinOnlyCoordinatorPatch(plan.fieldPatch)) {
        continue;
      }
      final state = await _loadCoordinatorCommitState(
        owner: owner,
        canonicalConversationId: plan.canonicalConversationId,
      );
      if (state.idempotencyKeys.contains(plan.idempotencyKey) ||
          plan.generation < state.generation ||
          state.tombstoneGeneration != null) {
        continue;
      }
      accepted.add((plan, state));
    }
    if (accepted.isEmpty) {
      return;
    }
    await replaceAllPinnedFlags(
      pinnedConversationIds: pinnedConversationIds,
      ownerUserId: owner,
    );
    for (final entry in accepted) {
      final plan = entry.$1;
      final state = entry.$2
        ..generation = plan.generation
        ..tombstoneGeneration = null;
      state.idempotencyKeys.add(plan.idempotencyKey);
    }
    if (!_useMemoryOnly) {
      final db = await _openDb();
      await profiledTransaction<void>(
        db,
        dbTag: _dbName,
        op: 'coordinatorPinStateBatch',
        extras: <String, Object?>{'count': accepted.length},
        action: (txn) async {
          final batch = txn.batch();
          for (final entry in accepted) {
            batch.insert(
              _coordinatorStateTable,
              _coordinatorStateRow(
                owner: owner,
                canonicalConversationId: entry.$1.canonicalConversationId,
                state: entry.$2,
              ),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        },
      );
    }
  }

  static bool _isDraftOnlyCoordinatorPatch(
    Map<ConversationMutationField, Object?> patch,
  ) =>
      patch.length == 1 && patch.containsKey(ConversationMutationField.draft);

  @visibleForTesting
  static bool isDraftOnlyCoordinatorPatchForTest(
    Map<ConversationMutationField, Object?> patch,
  ) =>
      _isDraftOnlyCoordinatorPatch(patch);

  static bool _isMarkReadCoordinatorPatch(
    Map<ConversationMutationField, Object?> patch,
  ) =>
      patch.length == 1 &&
      patch[ConversationMutationField.unread] is int &&
      patch[ConversationMutationField.unread] == 0;

  @visibleForTesting
  static bool isMarkReadCoordinatorPatchForTest(
    Map<ConversationMutationField, Object?> patch,
  ) =>
      _isMarkReadCoordinatorPatch(patch);

  static bool _isUnreadCountCoordinatorPatch(
    Map<ConversationMutationField, Object?> patch,
  ) {
    final value = patch[ConversationMutationField.unread];
    return patch.length == 1 && value is int && value > 0;
  }

  @visibleForTesting
  static bool isUnreadCountCoordinatorPatchForTest(
    Map<ConversationMutationField, Object?> patch,
  ) =>
      _isUnreadCountCoordinatorPatch(patch);

  static bool _isPinOnlyCoordinatorPatch(
    Map<ConversationMutationField, Object?> patch,
  ) =>
      patch.length == 1 && patch[ConversationMutationField.pin] is bool;

  @visibleForTesting
  static bool isPinOnlyCoordinatorPatchForTest(
    Map<ConversationMutationField, Object?> patch,
  ) =>
      _isPinOnlyCoordinatorPatch(patch);

  static bool _isMuteOnlyCoordinatorPatch(
    Map<ConversationMutationField, Object?> patch,
  ) =>
      patch.length == 1 && patch[ConversationMutationField.mute] is int;

  @visibleForTesting
  static bool isMuteOnlyCoordinatorPatchForTest(
    Map<ConversationMutationField, Object?> patch,
  ) =>
      _isMuteOnlyCoordinatorPatch(patch);

  static bool _isMetadataCoordinatorPatch(
    Map<ConversationMutationField, Object?> patch,
  ) {
    if (patch.isEmpty) {
      return false;
    }
    for (final entry in patch.entries) {
      if (entry.key != ConversationMutationField.name &&
          entry.key != ConversationMutationField.avatar) {
        return false;
      }
      if (entry.value is! String) {
        return false;
      }
    }
    return true;
  }

  @visibleForTesting
  static bool isMetadataCoordinatorPatchForTest(
    Map<ConversationMutationField, Object?> patch,
  ) =>
      _isMetadataCoordinatorPatch(patch);

  Future<List<String>> _resolveStoredConversationIdsForDelete(
    DatabaseExecutor executor, {
    required String owner,
    required List<String> requestedIds,
  }) async {
    final requestedKeys = requestedIds
        .map(_conversationEquivalenceKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    if (requestedKeys.isEmpty) {
      return const <String>[];
    }
    final resolved = <String>{};
    const chunkSize = 200;
    for (var offset = 0; offset < requestedIds.length; offset += chunkSize) {
      final chunk = requestedIds.sublist(
        offset,
        offset + chunkSize > requestedIds.length
            ? requestedIds.length
            : offset + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final exactRows = await executor.query(
        _table,
        columns: const <String>['conversation_id'],
        where: 'owner_user_id = ? AND conversation_id IN ($placeholders)',
        whereArgs: <Object?>[owner, ...chunk],
      );
      for (final row in exactRows) {
        final storedId = row['conversation_id']?.toString().trim() ?? '';
        if (storedId.isNotEmpty) {
          resolved.add(storedId);
        }
      }
    }
    final resolvedKeys = resolved.map(_conversationEquivalenceKey).toSet();
    if (resolvedKeys.containsAll(requestedKeys)) {
      return resolved.toList(growable: false);
    }
    final fallbackRows = await executor.query(
      _table,
      columns: const <String>['conversation_id'],
      where: 'owner_user_id = ?',
      whereArgs: <Object?>[owner],
    );
    for (final row in fallbackRows) {
      final storedId = row['conversation_id']?.toString().trim() ?? '';
      if (storedId.isEmpty ||
          !requestedKeys.contains(_conversationEquivalenceKey(storedId))) {
        continue;
      }
      resolved.add(storedId);
    }
    return resolved.toList(growable: false);
  }

  Future<List<String>> _deleteWithCoordinatorState({
    required String owner,
    required String canonicalConversationId,
    required _CoordinatorCommitState state,
  }) async {
    _cancelPendingUpserts(
      owner: owner,
      conversationIds: <String>[canonicalConversationId],
    );
    if (_useMemoryOnly) {
      final deleted = await deleteBatch(
        conversationIds: <String>[canonicalConversationId],
        ownerUserId: owner,
      );
      return deleted;
    }
    final db = await _openDb();
    final deleted = <String>[];
    await profiledTransaction<void>(
      db,
      dbTag: _dbName,
      op: 'coordinatorDelete',
      extras: const <String, Object?>{'count': 1},
      action: (txn) async {
        final storedIds = await _resolveStoredConversationIdsForDelete(
          txn,
          owner: owner,
          requestedIds: <String>[canonicalConversationId],
        );
        for (final id in storedIds) {
          final removed = await txn.delete(
            _table,
            where: 'owner_user_id = ? AND conversation_id = ?',
            whereArgs: <Object?>[owner, id],
          );
          if (removed > 0) {
            deleted.add(id);
          }
        }
        await txn.insert(
          _coordinatorStateTable,
          _coordinatorStateRow(
            owner: owner,
            canonicalConversationId: canonicalConversationId,
            state: state,
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      },
    );
    for (final id in deleted) {
      clearHistoryClearedMarkers(id, ownerUserId: owner);
    }
    return deleted;
  }

  Future<List<String>> deleteBatch({
    required List<String> conversationIds,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || conversationIds.isEmpty) {
      return const [];
    }
    final ids = conversationIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      return const [];
    }
    _cancelPendingUpserts(owner: owner, conversationIds: ids);
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final idSet = ids.map(_conversationEquivalenceKey).toSet();
      final deleted = <String>[];
      list.removeWhere((e) {
        if (idSet.contains(_conversationEquivalenceKey(e.conversationID))) {
          deleted.add(e.conversationID);
          return true;
        }
        return false;
      });
      _memoryByOwner[owner] = list;
      for (final id in deleted) {
        clearHistoryClearedMarkers(id, ownerUserId: owner);
      }
      return deleted;
    }
    final db = await _openDb();
    final storedIds = await _resolveStoredConversationIdsForDelete(
      db,
      owner: owner,
      requestedIds: ids,
    );
    if (storedIds.isEmpty) {
      return const <String>[];
    }
    final deleted = <String>[];
    await profiledTransaction<void>(
      db,
      dbTag: _dbName,
      op: 'deleteBatch',
      extras: <String, Object?>{'count': storedIds.length},
      action: (txn) async {
        for (final id in storedIds) {
          final removed = await txn.delete(
            _table,
            where: 'owner_user_id = ? AND conversation_id = ?',
            whereArgs: [owner, id],
          );
          if (removed > 0) {
            deleted.add(id);
          }
        }
      },
    );
    for (final id in deleted) {
      clearHistoryClearedMarkers(id, ownerUserId: owner);
    }
    return deleted;
  }

  /// 会话已从列表移除时，清掉「清空历史」水位，避免后续误保壳。
  void clearHistoryClearedMarkers(
    String conversationID, {
    String? ownerUserId,
  }) {
    final owner = _resolveOwner(ownerUserId);
    final id = conversationID.trim();
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    _clearHistoryCleared(owner, id);
  }

  Future<ConversationSyncMeta> readSyncMeta({String? ownerUserId}) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return const ConversationSyncMeta();
    }
    if (_useMemoryOnly) {
      return _memoryMetaByOwner[owner] ?? const ConversationSyncMeta();
    }
    final db = await _openDb();
    final rows = await db.query(
      _metaTable,
      where: 'owner_user_id = ?',
      whereArgs: [owner],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const ConversationSyncMeta();
    }
    return _syncMetaFromRow(rows.first);
  }

  Future<void> writeSyncMeta({
    required ConversationSyncMeta meta,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    if (_useMemoryOnly) {
      _memoryMetaByOwner[owner] = meta;
      return;
    }
    final db = await _openDb();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.insert(
        _metaTable,
        {
          'owner_user_id': owner,
          'next_seq': meta.nextSeq,
          'have_more': meta.haveMore ? 1 : 0,
          'has_synced_once': meta.hasSyncedOnce ? 1 : 0,
          'c2c_next_seq': meta.c2cNextSeq,
          'c2c_have_more': meta.c2cHaveMore ? 1 : 0,
          'group_next_seq': meta.groupNextSeq,
          'group_have_more': meta.groupHaveMore ? 1 : 0,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearForOwner(String? ownerUserId) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    _memoryByOwner.remove(owner);
    _memoryMetaByOwner.remove(owner);
    _coordinatorCommitStates.removeWhere((key, _) => key.startsWith('$owner|'));
    _readClearedAtMs.removeWhere((key, _) => key.startsWith('$owner|'));
    _readClearedLastMsgId.removeWhere((key, _) => key.startsWith('$owner|'));
    _readBarriers.removeWhere((key, _) => key.startsWith('$owner|'));
    _sdkUnreadSourceVersions.removeWhere((key, _) => key.startsWith('$owner|'));
    if (_useMemoryOnly) {
      _webMetaHydratedOwners.remove(owner);
      unawaited(
        WebConversationMetaStore.instance.save(
          owner,
          const WebConversationMetaSnapshot(),
        ),
      );
      return;
    }
    final db = await _openDb();
    await db.delete(_table, where: 'owner_user_id = ?', whereArgs: [owner]);
    await db.delete(_metaTable, where: 'owner_user_id = ?', whereArgs: [owner]);
    await db.delete(_pageAnchorTable,
        where: 'owner_user_id = ?', whereArgs: [owner]);
    await db.delete(_viewStateTable,
        where: 'owner_user_id = ?', whereArgs: [owner]);
    await db.delete(
      _coordinatorStateTable,
      where: 'owner_user_id = ?',
      whereArgs: <Object?>[owner],
    );
  }

  Future<void> upsertConversationPageAnchor({
    required String ownerUserId,
    required int convType,
    required int pageStart,
    required ConversationTypePageCursor cursor,
    int? pageEnd,
    int pageVersion = 0,
    ConversationTypePageCursor? firstCursor,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || (convType != 1 && convType != 2) || pageStart < 0)
      return;
    if (_useMemoryOnly) return;
    final db = await _openDb();
    await db.insert(
      _pageAnchorTable,
      <String, Object?>{
        'owner_user_id': owner,
        'conv_type': convType,
        'page_start': pageStart,
        'page_end': pageEnd ?? pageStart,
        'page_version': pageVersion,
        'first_pinned': firstCursor?.pinned == true ? 1 : 0,
        'first_active_time': firstCursor?.activeTime ?? 0,
        'first_order_key': firstCursor?.orderKey ?? 0,
        'first_conversation_id': firstCursor?.conversationID ?? '',
        'pinned': cursor.pinned ? 1 : 0,
        'active_time': cursor.activeTime,
        'order_key': cursor.orderKey,
        'conversation_id': cursor.conversationID,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> nextConversationViewVersion({
    required String ownerUserId,
    required int convType,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || (convType != 1 && convType != 2) || _useMemoryOnly)
      return 0;
    final db = await _openDb();
    return db.transaction<int>((txn) async {
      final rows = await txn.query(
        _viewStateTable,
        columns: const ['view_version'],
        where: 'owner_user_id = ? AND conv_type = ?',
        whereArgs: <Object?>[owner, convType],
        limit: 1,
      );
      final next = (rows.isEmpty ? 0 : _asInt(rows.first['view_version'])) + 1;
      await txn.insert(
        _viewStateTable,
        <String, Object?>{
          'owner_user_id': owner,
          'conv_type': convType,
          'view_version': next,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return next;
    });
  }

  Future<Map<int, ConversationTypePageCursor>> loadConversationPageAnchors({
    required String ownerUserId,
    required int convType,
    int? maxPageStart,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || (convType != 1 && convType != 2))
      return <int, ConversationTypePageCursor>{};
    if (_useMemoryOnly) return <int, ConversationTypePageCursor>{};
    final db = await _openDb();
    final rows = await db.query(
      _pageAnchorTable,
      where: maxPageStart == null
          ? 'owner_user_id = ? AND conv_type = ?'
          : 'owner_user_id = ? AND conv_type = ? AND page_start <= ?',
      whereArgs: maxPageStart == null
          ? <Object?>[owner, convType]
          : <Object?>[owner, convType, maxPageStart],
      orderBy: 'page_start ASC',
    );
    return <int, ConversationTypePageCursor>{
      for (final row in rows)
        _asInt(row['page_end'] ?? row['page_start']):
            ConversationTypePageCursor(
          pinned: _asInt(row['pinned']) != 0,
          activeTime: _asInt(row['active_time']),
          orderKey: _asInt(row['order_key']),
          conversationID: row['conversation_id']?.toString() ?? '',
        ),
    };
  }

  Future<void> deleteConversationPageAnchors({
    required String ownerUserId,
    int? convType,
    int? pageStart,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || _useMemoryOnly) return;
    final clauses = <String>['owner_user_id = ?'];
    final args = <Object?>[owner];
    if (convType != null) {
      clauses.add('conv_type = ?');
      args.add(convType);
    }
    if (pageStart != null) {
      clauses.add('page_start = ?');
      args.add(pageStart);
    }
    final db = await _openDb();
    await db.delete(_pageAnchorTable,
        where: clauses.join(' AND '), whereArgs: args);
  }

  Future<void> deleteConversationPageAnchorsFrom({
    required String ownerUserId,
    required int convType,
    required int pageStart,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || _useMemoryOnly || pageStart < 0) return;
    final db = await _openDb();
    await db.delete(
      _pageAnchorTable,
      where: 'owner_user_id = ? AND conv_type = ? AND page_start >= ?',
      whereArgs: <Object?>[owner, convType, pageStart],
    );
  }

  void _cancelPendingUpserts({
    required String owner,
    required Iterable<String> conversationIds,
  }) {
    if (_upsertCoalesceOwner != owner) {
      return;
    }
    final keys = conversationIds
        .map(_conversationEquivalenceKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    if (keys.isEmpty) {
      return;
    }
    for (final key in keys) {
      _upsertCoalesceById.remove(key);
    }
    for (final waiter in <_UpsertCoalesceWaiter>[
      ..._upsertCoalesceWaiters,
      ..._upsertCoalesceInFlightWaiters,
    ]) {
      waiter.requestedKeys.removeAll(keys);
      if (waiter.requestedKeys.isEmpty && !waiter.completer.isCompleted) {
        waiter.completer.complete(const <V2TimConversation>[]);
      }
    }
    _upsertCoalesceWaiters.removeWhere(
      (waiter) => waiter.completer.isCompleted,
    );
    if (_upsertCoalesceById.isEmpty && _upsertCoalesceWaiters.isEmpty) {
      _upsertCoalesceTimer?.cancel();
      _upsertCoalesceTimer = null;
      _upsertCoalesceFirstQueuedAt = null;
      if (!_upsertCoalesceFlushing) {
        _upsertCoalesceOwner = null;
      }
    }
  }

  Future<void> clearSession({String? ownerUserId}) async {
    _upsertCoalesceGeneration++;
    _historyClearIndexGeneration++;
    _upsertCoalesceTimer?.cancel();
    _upsertCoalesceTimer = null;
    _upsertCoalesceById.clear();
    _loadUiWindowDirty = false;
    _loadUiWindowInFlight = null;
    final loadLeader = _loadUiWindowLeader;
    _loadUiWindowLeader = null;
    if (loadLeader != null && !loadLeader.isCompleted) {
      loadLeader.complete(const <V2TimConversation>[]);
    }
    for (final waiter in _upsertCoalesceWaiters) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.complete(const <V2TimConversation>[]);
      }
    }
    for (final waiter in _upsertCoalesceInFlightWaiters) {
      waiter.requestedKeys.clear();
      if (!waiter.completer.isCompleted) {
        waiter.completer.complete(const <V2TimConversation>[]);
      }
    }
    _upsertCoalesceWaiters.clear();
    _upsertCoalesceFirstQueuedAt = null;
    _upsertCoalesceOwner = null;
    beforeUpsertBatchImplForTest = null;
    // 退出时只卸载已经固定的当前账号；其他账号的 Web 内存桶继续保留。
    // owner 为空表示调用方没有可确认的身份，此时不能误清其他账号。
    final owner = _resolveOwner(ownerUserId);
    final webOwners =
        _useMemoryOnly && owner.isNotEmpty ? <String>[owner] : const <String>[];
    if (owner.isNotEmpty) {
      _memoryByOwner.remove(owner);
      _memoryMetaByOwner.remove(owner);
      final ownerPrefix = '$owner|';
      _coordinatorCommitStates.removeWhere(
        (key, _) => key.startsWith(ownerPrefix),
      );
      _readClearedAtMs.removeWhere((key, _) => key.startsWith(ownerPrefix));
      _readClearedLastMsgId.removeWhere(
        (key, _) => key.startsWith(ownerPrefix),
      );
      _readBarriers.removeWhere((key, _) => key.startsWith(ownerPrefix));
      _sdkUnreadSourceVersions.removeWhere(
        (key, _) => key.startsWith(ownerPrefix),
      );
      _historyClearedAtMs.removeWhere(
        (key, _) => key.startsWith(ownerPrefix),
      );
      _historyClearIndexHydratedOwners.remove(owner);
      _historyClearIndexInFlightByOwner.remove(owner);
    }
    _archivePrepareGeneration++;
    await _clearArchiveJoinState();
    // 登出只卸内存：磁盘按 owner_user_id 多账号长期共存，注销走 clearForOwner。
    if (_useMemoryOnly) {
      for (final webOwner in webOwners) {
        _webMetaHydratedOwners.remove(webOwner);
      }
      _webMetaPersistTimer?.cancel();
      _webMetaPersistTimer = null;
      _webMetaPersistOwner = null;
      for (final owner in webOwners) {
        if (owner.isEmpty) {
          continue;
        }
        unawaited(
          WebConversationMetaStore.instance.save(
            owner,
            const WebConversationMetaSnapshot(),
          ),
        );
      }
    }
  }

  /// 测试专用：整表清空（生产登出禁止调用）。
  @visibleForTesting
  Future<void> wipeAllDiskForTest() async {
    _memoryByOwner.clear();
    _memoryMetaByOwner.clear();
    _coordinatorCommitStates.clear();
    _readClearedAtMs.clear();
    _readClearedLastMsgId.clear();
    _readBarriers.clear();
    _historyClearedAtMs.clear();
    _historyClearIndexHydratedOwners.clear();
    _historyClearIndexInFlightByOwner.clear();
    if (_useMemoryOnly) {
      _webMetaHydratedOwners.clear();
      return;
    }
    final db = await _openDb();
    await db.delete(_table);
    await db.delete(_metaTable);
    await db.delete(_coordinatorStateTable);
  }

  Future<V2TimConversation?> markConversationReadLocally(
    String conversationID, {
    String? ownerUserId,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _recordReadCleared(owner, id, now);
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final index = list.indexWhere((e) => e.conversationID == id);
      if (index < 0) {
        return null;
      }
      if ((list[index].unreadCount ?? 0) == 0) {
        _recordReadCleared(owner, id, now);
        return null;
      }
      list[index].unreadCount = 0;
      final lastMessageId = list[index].lastMessage?.msgID?.trim() ?? '';
      if (lastMessageId.isNotEmpty) {
        _readClearedLastMsgId[_readClearCacheKey(owner, id)] = lastMessageId;
      }
      _memoryByOwner[owner] = list;
      return list[index];
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [owner, id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final conversation = _conversationFromRow(rows.first);
    if (conversation == null) {
      return null;
    }
    if ((conversation.unreadCount ?? 0) == 0) {
      _recordReadCleared(owner, id, now);
      return null;
    }
    conversation.unreadCount = 0;
    final localDraftText = _localDraftTextFromRow(rows.first);
    final localDraftUpdatedAtMs = _localDraftUpdatedAtMsFromRow(rows.first);
    final readClearedAtMs = now;
    _recordReadCleared(owner, id, readClearedAtMs);
    final lastMessageId = conversation.lastMessage?.msgID?.trim() ?? '';
    if (lastMessageId.isNotEmpty) {
      _readClearedLastMsgId[_readClearCacheKey(owner, id)] = lastMessageId;
    }
    await db.insert(
      _table,
      _rowFromConversation(
        owner,
        conversation,
        now,
        readClearedAtMs: readClearedAtMs,
        localDraftText: localDraftText,
        localDraftUpdatedAtMs: localDraftUpdatedAtMs,
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return conversation;
  }

  /// 按会话 id 批量清未读（勾选 / 归档集合）。单事务 UPDATE，避免 N 次写库。
  Future<MarkReadBatchResult> markConversationsReadLocallyBatch(
    Iterable<String> conversationIds, {
    MarkReadLocalScope? scope,
    String? ownerUserId,
  }) async {
    final ids =
        conversationIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return MarkReadBatchResult.empty;
    }
    final includeTokens = buildArchiveLookupTokenSet(ids);
    return _markUnreadReadBatch(
      ownerUserId: ownerUserId,
      includeTokens: includeTokens,
      scope: scope,
      excludeTokens: const <String>{},
    );
  }

  /// 按 scope 批量清未读；[excludeConversationIds] 为归档原集（会展开 token）。
  Future<MarkReadBatchResult> markAllUnreadReadLocally({
    required MarkReadLocalScope scope,
    Set<String> excludeConversationIds = const <String>{},
    String? ownerUserId,
  }) async {
    return _markUnreadReadBatch(
      ownerUserId: ownerUserId,
      includeTokens: null,
      scope: scope,
      excludeTokens: _archiveExcludeTokens(excludeConversationIds),
    );
  }

  /// 预估将清除的会话数 / 未读合计（确认框用）。
  Future<MarkReadBatchResult> previewUnreadForMarkRead({
    MarkReadLocalScope? scope,
    Iterable<String>? conversationIds,
    Set<String> excludeConversationIds = const <String>{},
    String? ownerUserId,
  }) async {
    final ids = conversationIds
        ?.map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final includeTokens =
        ids == null || ids.isEmpty ? null : buildArchiveLookupTokenSet(ids);
    return _collectUnreadForMarkRead(
      ownerUserId: ownerUserId,
      includeTokens: includeTokens,
      scope: scope,
      excludeTokens: _archiveExcludeTokens(excludeConversationIds),
      applyClear: false,
    );
  }

  Future<MarkReadBatchResult> _markUnreadReadBatch({
    required String? ownerUserId,
    required Set<String>? includeTokens,
    required MarkReadLocalScope? scope,
    required Set<String> excludeTokens,
  }) {
    return _collectUnreadForMarkRead(
      ownerUserId: ownerUserId,
      includeTokens: includeTokens,
      scope: scope,
      excludeTokens: excludeTokens,
      applyClear: true,
    );
  }

  Future<MarkReadBatchResult> _collectUnreadForMarkRead({
    required String? ownerUserId,
    required Set<String>? includeTokens,
    required MarkReadLocalScope? scope,
    required Set<String> excludeTokens,
    required bool applyClear,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return MarkReadBatchResult.empty;
    }
    if (includeTokens != null && includeTokens.isEmpty) {
      return MarkReadBatchResult.empty;
    }

    if (_useMemoryOnly) {
      return _collectUnreadForMarkReadMemory(
        owner: owner,
        includeTokens: includeTokens,
        scope: scope,
        excludeTokens: excludeTokens,
        applyClear: applyClear,
      );
    }

    final db = await _openDb();
    final typeClause = _markReadScopeSql(scope);
    if (includeTokens != null) {
      return _collectUnreadForMarkReadByIncludeTokens(
        db: db,
        owner: owner,
        includeTokens: includeTokens,
        typeClause: typeClause,
        applyClear: applyClear,
      );
    }
    if (excludeTokens.isEmpty) {
      return _collectUnreadForMarkReadSql(
        db: db,
        owner: owner,
        whereSql: 'owner_user_id = ? AND unread_count > 0$typeClause',
        whereArgs: <Object?>[owner],
        applyClear: applyClear,
      );
    }
    return _withExcludeQueryLock(() async {
      await _fillExcludeArchivedTemp(db, excludeTokens);
      try {
        return _collectUnreadForMarkReadSql(
          db: db,
          owner: owner,
          whereSql: 'owner_user_id = ? AND unread_count > 0$typeClause '
              'AND NOT EXISTS (SELECT 1 FROM $_excludeArchivedTemp e '
              'WHERE e.id = conversation_id)',
          whereArgs: <Object?>[owner],
          applyClear: applyClear,
        );
      } finally {
        await db.delete(_excludeArchivedTemp);
      }
    });
  }

  String _markReadScopeSql(MarkReadLocalScope? scope) {
    switch (scope) {
      case MarkReadLocalScope.c2c:
        return ' AND conv_type != 2';
      case MarkReadLocalScope.group:
        return ' AND conv_type = 2';
      case MarkReadLocalScope.all:
      case null:
        return '';
    }
  }

  bool _markReadScopeMatches(
    V2TimConversation conversation,
    MarkReadLocalScope? scope,
  ) {
    switch (scope) {
      case MarkReadLocalScope.c2c:
        return !_isGroupConv(conversation);
      case MarkReadLocalScope.group:
        return _isGroupConv(conversation);
      case MarkReadLocalScope.all:
      case null:
        return true;
    }
  }

  MarkReadBatchResult _collectUnreadForMarkReadMemory({
    required String owner,
    required Set<String>? includeTokens,
    required MarkReadLocalScope? scope,
    required Set<String> excludeTokens,
    required bool applyClear,
  }) {
    final list = List<V2TimConversation>.from(
      _memoryByOwner[owner] ?? const <V2TimConversation>[],
    );
    final clearedIds = <String>[];
    var unreadSum = 0;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final conversation in list) {
      if (!_markReadScopeMatches(conversation, scope)) {
        continue;
      }
      final id = conversation.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      if (includeTokens != null &&
          !conversationIdInArchivedLookup(includeTokens, id)) {
        continue;
      }
      if (excludeTokens.isNotEmpty &&
          conversationIdInArchivedLookup(excludeTokens, id)) {
        continue;
      }
      final unread = conversation.unreadCount ?? 0;
      if (unread <= 0) {
        continue;
      }
      clearedIds.add(id);
      unreadSum += unread;
      if (applyClear) {
        conversation.unreadCount = 0;
        recordReadClearedAnchor(
          id,
          ownerUserId: owner,
          lastMessageId: conversation.lastMessage?.msgID,
          lastMessageTimestamp: conversation.lastMessage?.timestamp,
          lastMessageSeq:
              int.tryParse(conversation.lastMessage?.seq?.trim() ?? ''),
          orderKey: conversation.orderkey,
        );
      }
    }
    if (applyClear && clearedIds.isNotEmpty) {
      _memoryByOwner[owner] = list;
    }
    return MarkReadBatchResult(
      clearedIds: clearedIds,
      conversationCount: clearedIds.length,
      unreadSumBefore: unreadSum,
    );
  }

  Future<MarkReadBatchResult> _collectUnreadForMarkReadByIncludeTokens({
    required Database db,
    required String owner,
    required Set<String> includeTokens,
    required String typeClause,
    required bool applyClear,
  }) async {
    final tokenList = includeTokens.toList(growable: false);
    final clearedIds = <String>[];
    var unreadSum = 0;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    const chunk = 400;
    for (var i = 0; i < tokenList.length; i += chunk) {
      final end = i + chunk > tokenList.length ? tokenList.length : i + chunk;
      final batch = tokenList.sublist(i, end);
      final placeholders = List.filled(batch.length, '?').join(',');
      final rows = await db.query(
        _table,
        columns: const [
          'conversation_id',
          'unread_count',
          'last_msg_id',
          'raw_json',
          'order_key',
        ],
        where: 'owner_user_id = ? AND unread_count > 0$typeClause '
            'AND conversation_id IN ($placeholders)',
        whereArgs: <Object?>[owner, ...batch],
      );
      for (final row in rows) {
        final id = row['conversation_id']?.toString().trim() ?? '';
        if (id.isEmpty) {
          continue;
        }
        final unread = _asInt(row['unread_count']);
        if (unread <= 0) {
          continue;
        }
        clearedIds.add(id);
        unreadSum += unread;
        if (applyClear) {
          _recordReadBarrierForPersistedRow(owner, row, now);
        }
      }
    }
    if (applyClear && clearedIds.isNotEmpty) {
      const chunkSize = 400;
      for (var i = 0; i < clearedIds.length; i += chunkSize) {
        final end = i + chunkSize > clearedIds.length
            ? clearedIds.length
            : i + chunkSize;
        final batch = clearedIds.sublist(i, end);
        final placeholders = List.filled(batch.length, '?').join(',');
        await db.rawUpdate(
          'UPDATE $_table SET unread_count = 0, read_cleared_at = ? '
          'WHERE owner_user_id = ? AND conversation_id IN ($placeholders)',
          <Object?>[now, owner, ...batch],
        );
      }
      _zeroMemoryUnreadForIds(owner, clearedIds.toSet());
    }
    return MarkReadBatchResult(
      clearedIds: clearedIds,
      conversationCount: clearedIds.length,
      unreadSumBefore: unreadSum,
    );
  }

  Future<MarkReadBatchResult> _collectUnreadForMarkReadSql({
    required Database db,
    required String owner,
    required String whereSql,
    required List<Object?> whereArgs,
    required bool applyClear,
  }) async {
    final rows = await db.query(
      _table,
      columns: const [
        'conversation_id',
        'unread_count',
        'last_msg_id',
        'raw_json',
        'order_key',
      ],
      where: whereSql,
      whereArgs: whereArgs,
    );
    final clearedIds = <String>[];
    var unreadSum = 0;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final row in rows) {
      final id = row['conversation_id']?.toString().trim() ?? '';
      if (id.isEmpty) {
        continue;
      }
      final unread = _asInt(row['unread_count']);
      if (unread <= 0) {
        continue;
      }
      clearedIds.add(id);
      unreadSum += unread;
      if (applyClear) {
        _recordReadBarrierForPersistedRow(owner, row, now);
      }
    }
    if (applyClear && clearedIds.isNotEmpty) {
      // 只更新已收集的 id，避免 TEMP 排除表在 SELECT/UPDATE 之间被并发清空后误伤。
      const chunk = 400;
      for (var i = 0; i < clearedIds.length; i += chunk) {
        final end =
            i + chunk > clearedIds.length ? clearedIds.length : i + chunk;
        final batch = clearedIds.sublist(i, end);
        final placeholders = List.filled(batch.length, '?').join(',');
        await db.rawUpdate(
          'UPDATE $_table SET unread_count = 0, read_cleared_at = ? '
          'WHERE owner_user_id = ? AND conversation_id IN ($placeholders)',
          <Object?>[now, owner, ...batch],
        );
      }
      _zeroMemoryUnreadForIds(owner, clearedIds.toSet());
    }
    return MarkReadBatchResult(
      clearedIds: clearedIds,
      conversationCount: clearedIds.length,
      unreadSumBefore: unreadSum,
    );
  }

  void _recordReadBarrierForPersistedRow(
    String owner,
    Map<String, Object?> row,
    int now,
  ) {
    final id = row['conversation_id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      return;
    }
    final conversation = _conversationFromRow(row);
    final message = conversation?.lastMessage;
    recordReadClearedAnchor(
      id,
      ownerUserId: owner,
      lastMessageId: message?.msgID ?? row['last_msg_id']?.toString(),
      lastMessageTimestamp: message?.timestamp,
      lastMessageSeq: int.tryParse(message?.seq?.trim() ?? ''),
      orderKey: _asInt(row['order_key']),
    );
  }

  void _zeroMemoryUnreadForIds(String owner, Set<String> ids) {
    if (ids.isEmpty) {
      return;
    }
    final list = _memoryByOwner[owner];
    if (list == null || list.isEmpty) {
      return;
    }
    for (final conversation in list) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty || !ids.contains(id)) {
        // 归档 token 形态可能与内存 id 不一致：宽松匹配。
        if (!ids.any(
          (token) => MessageConversationId.sameConversation(token, id),
        )) {
          continue;
        }
      }
      if ((conversation.unreadCount ?? 0) > 0) {
        conversation.unreadCount = 0;
      }
    }
  }

  /// 清空聊天记录后去掉本地会话预览，并记录 history_cleared_at 供 merge 使用。
  Future<V2TimConversation?> clearConversationLastMessage(
    String conversationID, {
    String? ownerUserId,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _recordHistoryCleared(owner, id, now);

    // 水位优先取「被清的最后一条消息」的服务器时间：设备与 IM 服务器时钟
    // 可能相差分钟级。若用本机 now 作水位，清空后立刻发送的新消息（其服务器
    // 时间戳早于本机 now）会被 merge 误判为清空前的旧预览而抹掉，表现为
    // 清空→发送→回列表看不到预览。
    int refineWatermark(V2TimConversation conversation) {
      final lastMs = lastMessageTimestampMs(conversation);
      if (lastMs > 0) {
        _recordHistoryCleared(owner, id, lastMs);
        return lastMs;
      }
      return now;
    }

    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final index = _findConversationIndex(list, id);
      if (index == null) {
        return null;
      }
      final conversation = list[index];
      refineWatermark(conversation);
      final sortAnchorMs = _resolveSortAnchorMs(conversation: conversation);
      conversation.lastMessage = null;
      if (sortAnchorMs > 0) {
        conversation.orderkey = sortAnchorMs;
      }
      list[index] = conversation;
      _memoryByOwner[owner] = list;
      _decorateConversation(conversation);
      return conversation;
    }

    final db = await _openDb();
    final row = await _findPersistedConversationRow(
      db,
      owner: owner,
      conversationId: id,
    );
    if (row == null) {
      return null;
    }
    final storedId = row['conversation_id']?.toString() ?? id;
    final conversation = _conversationFromRow(row);
    if (conversation == null) {
      return null;
    }
    conversation.conversationID = storedId;
    final watermarkMs = refineWatermark(conversation);
    final sortAnchorMs = _resolveSortAnchorMs(
      conversation: conversation,
      rowOrderKey: row['order_key'] as int? ?? 0,
      rowActiveTimeMs: row['active_time'] as int? ?? 0,
    );
    conversation.lastMessage = null;
    if (sortAnchorMs > 0) {
      conversation.orderkey = sortAnchorMs;
    }
    final localDraftText = _localDraftTextFromRow(row);
    final localDraftUpdatedAtMs = _localDraftUpdatedAtMsFromRow(row);
    final readClearedAtMs = row['read_cleared_at'] as int? ?? 0;
    await db.insert(
      _table,
      _rowFromConversation(
        owner,
        conversation,
        now,
        readClearedAtMs: readClearedAtMs,
        historyClearedAtMs: watermarkMs,
        localDraftText: localDraftText,
        localDraftUpdatedAtMs: localDraftUpdatedAtMs,
        pinnedActiveTimeMs: sortAnchorMs > 0 ? sortAnchorMs : null,
        pinnedOrderKey: sortAnchorMs > 0 ? sortAnchorMs : null,
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _decorateConversation(conversation);
    return conversation;
  }

  /// 聊天页删除消息后强制回退本地会话预览。
  /// 不能走 upsertBatch：merge 按时间取新，会把更「新」的被删消息保留住。
  /// 仅当当前预览正是被删消息之一时生效；[replacement] 为 null
  ///（会话已无剩余消息）时按清空历史处理。
  Future<V2TimConversation?> replaceConversationLastMessageAfterDelete(
    String conversationID, {
    required Set<String> deletedMsgIDs,
    V2TimMessage? replacement,
    String? ownerUserId,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty || deletedMsgIDs.isEmpty) {
      return null;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    _deletedPreviewMsgIds.addAll(
      deletedMsgIDs.map((m) => m.trim()).where((m) => m.isNotEmpty),
    );
    final existing = await conversationById(id, ownerUserId: owner);
    if (existing == null) {
      return null;
    }
    final lastIds = <String>{
      if ((existing.lastMessage?.msgID?.trim() ?? '').isNotEmpty)
        existing.lastMessage!.msgID!.trim(),
      if ((existing.lastMessage?.id?.toString().trim() ?? '').isNotEmpty)
        existing.lastMessage!.id.toString().trim(),
    };
    if (lastIds.intersection(deletedMsgIDs).isEmpty) {
      // 数据库可能已经先回退到前一条，但 UI 仍持有被删预览。返回当前
      // committed snapshot 继续校准 UI，不能用 null 让上层直接放弃刷新。
      _decorateConversation(existing);
      return existing;
    }
    if (replacement == null) {
      return clearConversationLastMessage(
        existing.conversationID,
        ownerUserId: owner,
      );
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final index = _findConversationIndex(list, id);
      if (index == null) {
        return null;
      }
      final conversation = list[index];
      // 保留原排序锚点：删最后一条不应让会话在列表里跳位。
      final sortAnchorMs = _resolveSortAnchorMs(conversation: conversation);
      conversation.lastMessage = replacement;
      if (sortAnchorMs > 0) {
        conversation.orderkey = sortAnchorMs;
      }
      list[index] = conversation;
      _memoryByOwner[owner] = list;
      _decorateConversation(conversation);
      return conversation;
    }
    final db = await _openDb();
    final row = await _findPersistedConversationRow(
      db,
      owner: owner,
      conversationId: id,
    );
    if (row == null) {
      return null;
    }
    final storedId = row['conversation_id']?.toString() ?? id;
    final conversation = _conversationFromRow(row);
    if (conversation == null) {
      return null;
    }
    conversation.conversationID = storedId;
    final sortAnchorMs = _resolveSortAnchorMs(
      conversation: conversation,
      rowOrderKey: row['order_key'] as int? ?? 0,
      rowActiveTimeMs: row['active_time'] as int? ?? 0,
    );
    conversation.lastMessage = replacement;
    if (sortAnchorMs > 0) {
      conversation.orderkey = sortAnchorMs;
    }
    await db.insert(
      _table,
      _rowFromConversation(
        owner,
        conversation,
        now,
        readClearedAtMs: row['read_cleared_at'] as int? ?? 0,
        historyClearedAtMs: row['history_cleared_at'] as int? ?? 0,
        localDraftText: _localDraftTextFromRow(row),
        localDraftUpdatedAtMs: _localDraftUpdatedAtMsFromRow(row),
        pinnedActiveTimeMs: sortAnchorMs > 0 ? sortAnchorMs : null,
        pinnedOrderKey: sortAnchorMs > 0 ? sortAnchorMs : null,
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _decorateConversation(conversation);
    return conversation;
  }

  /// SDK 清空后可能触发 onConversationDeleted；补建空预览会话壳。
  Future<V2TimConversation?> ensureConversationShellAfterHistoryClear(
    String conversationID, {
    String? ownerUserId,
    V2TimConversation? snapshot,
  }) async {
    final existing = await conversationById(
      conversationID,
      ownerUserId: ownerUserId,
    );
    if (existing != null) {
      return clearConversationLastMessage(
        existing.conversationID,
        ownerUserId: ownerUserId,
      );
    }
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _recordHistoryCleared(owner, id, now);
    final shell = snapshot ?? _minimalConversationForId(id);
    final sortAnchorMs = _resolveSortAnchorMs(conversation: shell);
    shell.lastMessage = null;
    if (sortAnchorMs > 0) {
      shell.orderkey = sortAnchorMs;
    }
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final index = _findConversationIndex(list, shell.conversationID);
      if (index == null) {
        list.add(shell);
      } else {
        list[index] = shell;
      }
      list.sort(_sortConversations);
      _memoryByOwner[owner] = list;
      _decorateConversation(shell);
      return shell;
    }
    final db = await _openDb();
    await db.insert(
      _table,
      _rowFromConversation(
        owner,
        shell,
        now,
        historyClearedAtMs: now,
        pinnedActiveTimeMs: sortAnchorMs > 0 ? sortAnchorMs : null,
        pinnedOrderKey: sortAnchorMs > 0 ? sortAnchorMs : null,
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _decorateConversation(shell);
    return shell;
  }

  Future<V2TimConversation?> updateConversationPinnedLocally({
    required String conversationID,
    required bool isPinned,
    String? ownerUserId,
    V2TimConversation? snapshot,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final index = list.indexWhere((e) => e.conversationID == id);
      if (index < 0) {
        if (snapshot == null) {
          return null;
        }
        final created = _cloneConversationForPin(snapshot, id, isPinned);
        list.add(created);
        list.sort(_sortConversations);
        _memoryByOwner[owner] = list;
        return created;
      }
      list[index].isPinned = isPinned;
      if (!isPinned) {
        final active = activeTimeMs(list[index]);
        if (active > 0) {
          list[index].orderkey = active;
        }
      }
      list.sort(_sortConversations);
      _memoryByOwner[owner] = list;
      return list.firstWhere((e) => e.conversationID == id);
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [owner, id],
      limit: 1,
    );
    if (rows.isEmpty) {
      if (snapshot == null) {
        return null;
      }
      final created = _cloneConversationForPin(snapshot, id, isPinned);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db.insert(
        _table,
        _rowFromConversation(owner, created, now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return created;
    }
    final conversation = _conversationFromRow(rows.first);
    if (conversation == null) {
      return null;
    }
    conversation.isPinned = isPinned;
    if (!isPinned) {
      final active = activeTimeMs(conversation);
      if (active > 0) {
        conversation.orderkey = active;
      }
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final localDraftText = _localDraftTextFromRow(rows.first);
    final localDraftUpdatedAtMs = _localDraftUpdatedAtMsFromRow(rows.first);
    await db.insert(
      _table,
      _rowFromConversation(
        owner,
        conversation,
        now,
        readClearedAtMs: rows.first['read_cleared_at'] as int? ?? 0,
        localDraftText: localDraftText,
        localDraftUpdatedAtMs: localDraftUpdatedAtMs,
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return conversation;
  }

  Future<V2TimConversation?> updateConversationRecvOptLocally({
    required String conversationID,
    required int recvOpt,
    String? ownerUserId,
    V2TimConversation? snapshot,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final index = list.indexWhere((e) => e.conversationID == id);
      if (index < 0) {
        if (snapshot == null) {
          return null;
        }
        final created = _cloneConversationForRecvOpt(snapshot, id, recvOpt);
        list.add(created);
        list.sort(_sortConversations);
        _memoryByOwner[owner] = list;
        return created;
      }
      list[index].recvOpt = recvOpt;
      _memoryByOwner[owner] = list;
      return list[index];
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [owner, id],
      limit: 1,
    );
    if (rows.isEmpty) {
      if (snapshot == null) {
        return null;
      }
      final created = _cloneConversationForRecvOpt(snapshot, id, recvOpt);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db.insert(
        _table,
        _rowFromConversation(owner, created, now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return created;
    }
    final conversation = _conversationFromRow(rows.first);
    if (conversation == null) {
      return null;
    }
    conversation.recvOpt = recvOpt;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final localDraftText = _localDraftTextFromRow(rows.first);
    final localDraftUpdatedAtMs = _localDraftUpdatedAtMsFromRow(rows.first);
    await db.insert(
      _table,
      _rowFromConversation(
        owner,
        conversation,
        now,
        readClearedAtMs: rows.first['read_cleared_at'] as int? ?? 0,
        localDraftText: localDraftText,
        localDraftUpdatedAtMs: localDraftUpdatedAtMs,
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return conversation;
  }

  V2TimConversation _cloneConversationForRecvOpt(
    V2TimConversation snapshot,
    String conversationID,
    int recvOpt,
  ) {
    return V2TimConversation(
      conversationID: conversationID,
      type: snapshot.type,
      userID: snapshot.userID,
      groupID: snapshot.groupID,
      showName: snapshot.showName,
      faceUrl: snapshot.faceUrl,
      recvOpt: recvOpt,
      unreadCount: snapshot.unreadCount ?? 0,
      lastMessage: snapshot.lastMessage,
      draftText: snapshot.draftText,
      draftTimestamp: snapshot.draftTimestamp,
      isPinned: snapshot.isPinned,
      orderkey: snapshot.orderkey,
      groupType: snapshot.groupType,
      groupAtInfoList: snapshot.groupAtInfoList,
    );
  }

  Future<V2TimConversation?> updateConversationUnreadCountLocally({
    required String conversationID,
    required int unreadCount,
    String? ownerUserId,
    V2TimConversation? snapshot,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty || unreadCount < 0) {
      return null;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final index = list.indexWhere((e) => e.conversationID == id);
      if (index < 0) {
        if (snapshot == null) {
          return null;
        }
        snapshot
          ..conversationID = id
          ..unreadCount = unreadCount;
        list.add(snapshot);
        list.sort(_sortConversations);
        _memoryByOwner[owner] = list;
        return snapshot;
      }
      list[index].unreadCount = unreadCount;
      _memoryByOwner[owner] = list;
      return list[index];
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [owner, id],
      limit: 1,
    );
    final conversation =
        rows.isEmpty ? snapshot : _conversationFromRow(rows.first);
    if (conversation == null) {
      return null;
    }
    conversation
      ..conversationID = id
      ..unreadCount = unreadCount;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.insert(
      _table,
      _rowFromConversation(
        owner,
        conversation,
        now,
        readClearedAtMs:
            rows.isEmpty ? 0 : rows.first['read_cleared_at'] as int? ?? 0,
        localDraftText: rows.isEmpty ? '' : _localDraftTextFromRow(rows.first),
        localDraftUpdatedAtMs:
            rows.isEmpty ? 0 : _localDraftUpdatedAtMsFromRow(rows.first),
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return conversation;
  }

  Future<V2TimConversation?> updateConversationMetadataLocally({
    required String conversationID,
    String? showName,
    String? faceUrl,
    String? ownerUserId,
    V2TimConversation? snapshot,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty || (showName == null && faceUrl == null)) {
      return null;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final index = list.indexWhere((e) => e.conversationID == id);
      if (index < 0) {
        if (snapshot == null) {
          return null;
        }
        snapshot.conversationID = id;
        if (showName != null) snapshot.showName = showName;
        if (faceUrl != null) snapshot.faceUrl = faceUrl;
        list.add(snapshot);
        list.sort(_sortConversations);
        _memoryByOwner[owner] = list;
        return snapshot;
      }
      if (showName != null) list[index].showName = showName;
      if (faceUrl != null) list[index].faceUrl = faceUrl;
      _memoryByOwner[owner] = list;
      return list[index];
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [owner, id],
      limit: 1,
    );
    final conversation =
        rows.isEmpty ? snapshot : _conversationFromRow(rows.first);
    if (conversation == null) {
      return null;
    }
    conversation.conversationID = id;
    if (showName != null) conversation.showName = showName;
    if (faceUrl != null) conversation.faceUrl = faceUrl;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.insert(
      _table,
      _rowFromConversation(
        owner,
        conversation,
        now,
        readClearedAtMs:
            rows.isEmpty ? 0 : rows.first['read_cleared_at'] as int? ?? 0,
        localDraftText: rows.isEmpty ? '' : _localDraftTextFromRow(rows.first),
        localDraftUpdatedAtMs:
            rows.isEmpty ? 0 : _localDraftUpdatedAtMsFromRow(rows.first),
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return conversation;
  }

  V2TimConversation _cloneConversationForPin(
    V2TimConversation snapshot,
    String conversationID,
    bool isPinned,
  ) {
    return V2TimConversation(
      conversationID: conversationID,
      type: snapshot.type,
      userID: snapshot.userID,
      groupID: snapshot.groupID,
      showName: snapshot.showName,
      faceUrl: snapshot.faceUrl,
      recvOpt: snapshot.recvOpt,
      unreadCount: snapshot.unreadCount ?? 0,
      lastMessage: snapshot.lastMessage,
      draftText: snapshot.draftText,
      draftTimestamp: snapshot.draftTimestamp,
      isPinned: isPinned,
      orderkey: snapshot.orderkey,
      groupType: snapshot.groupType,
      groupAtInfoList: snapshot.groupAtInfoList,
    );
  }

  Future<V2TimConversation?> updateLocalDraft({
    required String conversationID,
    required String draftText,
    String? ownerUserId,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final normalized = _normalizeDraftText(draftText);
    if (normalized.isEmpty) {
      return clearLocalDraft(conversationID: id, ownerUserId: ownerUserId);
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final index = list.indexWhere((e) => e.conversationID == id);
      final conversation =
          index >= 0 ? list[index] : _minimalConversationForId(id);
      applyLocalDraftToConversation(
        conversation,
        text: normalized,
        updatedAtMs: nowMs,
      );
      if (index >= 0) {
        list[index] = conversation;
      } else {
        list.add(conversation);
      }
      list.sort(_sortConversations);
      _memoryByOwner[owner] = list;
      _decorateConversation(conversation);
      return conversation;
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [owner, id],
      limit: 1,
    );
    final conversation = rows.isNotEmpty
        ? _conversationFromRow(rows.first)
        : _minimalConversationForId(id);
    if (conversation == null) {
      return null;
    }
    applyLocalDraftToConversation(
      conversation,
      text: normalized,
      updatedAtMs: nowMs,
    );
    await db.insert(
      _table,
      _rowFromConversation(
        owner,
        conversation,
        nowMs,
        readClearedAtMs:
            rows.isNotEmpty ? rows.first['read_cleared_at'] as int? ?? 0 : 0,
        localDraftText: normalized,
        localDraftUpdatedAtMs: nowMs,
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _decorateConversation(conversation);
    return conversation;
  }

  Future<V2TimConversation?> clearLocalDraft({
    required String conversationID,
    String? ownerUserId,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      final index = list.indexWhere((e) => e.conversationID == id);
      if (index < 0) {
        return null;
      }
      applyLocalDraftToConversation(list[index], text: '', updatedAtMs: 0);
      _memoryByOwner[owner] = list;
      _decorateConversation(list[index]);
      return list[index];
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [owner, id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final conversation = _conversationFromRow(rows.first);
    if (conversation == null) {
      return null;
    }
    applyLocalDraftToConversation(conversation, text: '', updatedAtMs: 0);
    await db.insert(
      _table,
      _rowFromConversation(
        owner,
        conversation,
        nowMs,
        readClearedAtMs: rows.first['read_cleared_at'] as int? ?? 0,
        localDraftText: '',
        localDraftUpdatedAtMs: 0,
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _decorateConversation(conversation);
    return conversation;
  }

  Future<String> localDraftTextFor({
    required String conversationID,
    String? ownerUserId,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return '';
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return '';
    }
    if (_useMemoryOnly) {
      for (final item in _memoryByOwner[owner] ?? const <V2TimConversation>[]) {
        if (item.conversationID == id) {
          return _normalizeDraftText(item.draftText ?? '');
        }
      }
      return '';
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      columns: ['local_draft_text'],
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [owner, id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return '';
    }
    return _localDraftTextFromRow(rows.first);
  }

  V2TimConversation _minimalConversationForId(String conversationId) {
    if (conversationId.startsWith('group_')) {
      return V2TimConversation(
        conversationID: conversationId,
        type: 2,
        groupID: conversationId.substring(6),
      );
    }
    if (conversationId.startsWith('c2c_')) {
      return V2TimConversation(
        conversationID: conversationId,
        type: 1,
        userID: conversationId.substring(4),
      );
    }
    return V2TimConversation(conversationID: conversationId);
  }

  bool _isDeletedPreviewMessage(V2TimMessage? message) {
    final ids = <String>{
      if ((message?.msgID?.trim() ?? '').isNotEmpty) message!.msgID!.trim(),
      if ((message?.id?.toString().trim() ?? '').isNotEmpty)
        message!.id.toString().trim(),
    };
    return ids.any(_deletedPreviewMsgIds.contains);
  }

  void _mergeConversationLastMessage(
    V2TimConversation existing,
    V2TimConversation incoming, {
    required String owner,
    required String conversationId,
    int rowHistoryClearedAtMs = 0,
  }) {
    if (!MessageConversationId.messageBelongsToConversation(
      incoming.lastMessage,
      conversationId,
      loginUserId: owner,
    )) {
      incoming.lastMessage = null;
    }
    if (!MessageConversationId.messageBelongsToConversation(
      existing.lastMessage,
      conversationId,
      loginUserId: owner,
    )) {
      existing.lastMessage = null;
    }
    // 已删消息不允许再成为预览：SDK 同步回写的陈旧 lastMessage 直接丢弃，
    // 让 merge 回落到本地已修正的预览。
    if (_isDeletedPreviewMessage(incoming.lastMessage)) {
      incoming.lastMessage = null;
      _preserveConversationSortAnchor(existing, incoming);
    }
    if (_isDeletedPreviewMessage(existing.lastMessage)) {
      existing.lastMessage = null;
    }
    final historyClearedAtMs = _resolvedHistoryClearedAtMs(
      owner: owner,
      conversationId: conversationId,
      rowHistoryClearedAtMs: rowHistoryClearedAtMs,
    );
    if (historyClearedAtMs > 0 && incoming.lastMessage != null) {
      final incomingMsgMs = messageTimestampMs(incoming.lastMessage);
      if (incomingMsgMs <= historyClearedAtMs) {
        // 清空后 SDK 可能仍回写旧 lastMessage；必须置空，不能回落到 existing。
        incoming.lastMessage = null;
        _preserveConversationSortAnchor(existing, incoming);
        return;
      }
      _clearHistoryCleared(owner, conversationId);
    }
    if (incoming.lastMessage == null &&
        _shouldPreferNullLastMessage(
          existing: existing.lastMessage,
          historyClearedAtMs: historyClearedAtMs,
        )) {
      incoming.lastMessage = null;
      _preserveConversationSortAnchor(existing, incoming);
      return;
    }

    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: existing.lastMessage,
      incoming: incoming.lastMessage,
    );
    if (preferred != null) {
      preserveRevokedLastMessageState(
        existing: existing.lastMessage,
        incoming: incoming.lastMessage,
        preferred: preferred,
      );
      preservePeerReadLastMessageState(
        existing: existing.lastMessage,
        incoming: incoming.lastMessage,
        preferred: preferred,
      );
    }
    incoming.lastMessage = preferred;
    if (preferred != null &&
        historyClearedAtMs > 0 &&
        lastMessageTimestampMs(incoming) > historyClearedAtMs) {
      _clearHistoryCleared(owner, conversationId);
    }
    final preferredTs = preferred?.timestamp ?? 0;
    final incomingOrder = incoming.orderkey ?? 0;
    final existingOrder = existing.orderkey ?? 0;
    if (preferredTs > 0) {
      incoming.orderkey = [
        incomingOrder,
        existingOrder,
        preferredTs,
      ].reduce((left, right) => left > right ? left : right);
    } else if (existingOrder > incomingOrder) {
      incoming.orderkey = existingOrder;
    }
  }

  /// 未读以 IM SDK 为准：活跃会话强制 0；其余透传 SDK unreadCount。
  /// 若 lastMessage 为已隐藏/静默群 tip，扣回 SDK 多计的 1 条未读。
  void _mergeConversationUnread({
    required V2TimConversation existing,
    required V2TimConversation incoming,
    required String owner,
    required String conversationId,
    required int readClearedAtMs,
  }) {
    final existingUnread = existing.unreadCount ?? 0;
    var incomingUnread = incoming.unreadCount ?? 0;
    final sourceKey = _readClearCacheKey(owner, conversationId);
    final incomingGeneration = _sdkUnreadSourceVersion(incoming);
    final committedGeneration = _sdkUnreadSourceVersions[sourceKey] ?? 0;
    final barrier = readBarrierFor(conversationId, ownerUserId: owner);
    final readBarrierVersion = barrier?.version ?? 0;

    final staleSameGeneration = incomingGeneration == committedGeneration &&
        incomingUnread < existingUnread &&
        readBarrierVersion == 0;
    if (incomingGeneration < committedGeneration || staleSameGeneration) {
      incoming.unreadCount = existingUnread;
      ConversationUnreadTrace.log(
        'sdk_unread_rejected_stale_generation',
        conversationID: conversationId,
        unreadBefore: existingUnread,
        unreadAfter: existingUnread,
        extras: <String, Object?>{
          'incomingGeneration': incomingGeneration,
          'committedGeneration': committedGeneration,
          'readBarrierVersion': readBarrierVersion,
          'decision': 'rejected',
          'staleSameGeneration': staleSameGeneration,
        },
      );
      return;
    }
    if (incomingGeneration > committedGeneration) {
      _sdkUnreadSourceVersions[sourceKey] = incomingGeneration;
    }

    if (ForegroundChatGuard.isActiveConversation(conversationId)) {
      incoming.unreadCount = 0;
      return;
    }

    // Some compatibility/store paths bypass SyncService. They still must use
    // the exact same watermark adjudication before merging unread.
    resolveSdkUnreadAgainstReadBarrier(incoming, ownerUserId: owner);
    incomingUnread = incoming.unreadCount ?? 0;

    // A conversation opened moments ago may receive an older SDK snapshot
    // after the local read commit. Do not resurrect the badge when that
    // snapshot still points at the exact message used as the read anchor.
    final readAnchorMessageId = _resolvedReadClearedLastMessageId(
      owner: owner,
      conversationId: conversationId,
    );
    final incomingLastMessageId = incoming.lastMessage?.msgID?.trim() ?? '';
    final incomingLastMessageAtMs = lastMessageTimestampMs(incoming);
    final readGraceReplay = incomingUnread > 0 &&
        readClearedAtMs > 0 &&
        incomingLastMessageAtMs > 0 &&
        incomingLastMessageAtMs <= readClearedAtMs &&
        isWithinReadGrace(readClearedAtMs);
    final exactAnchorReplay = readAnchorMessageId != null &&
        incomingLastMessageId.isNotEmpty &&
        incomingLastMessageId == readAnchorMessageId;
    if (incomingUnread > 0 &&
        readClearedAtMs > 0 &&
        (exactAnchorReplay || readGraceReplay)) {
      incoming.unreadCount = 0;
      ConversationUnreadTrace.log(
        'merge_unread_suppress_read_anchor_replay',
        conversationID: conversationId,
        unreadBefore: existingUnread,
        unreadAfter: 0,
        extras: <String, Object?>{
          'incoming': incomingUnread,
          'readClearedAtMs': readClearedAtMs,
          'anchorMessageId': readAnchorMessageId,
          'timestampReplay': readGraceReplay,
        },
      );
      return;
    }

    final last = incoming.lastMessage;
    if (last != null &&
        GroupTipsMessageHelper.shouldSuppressConversationUnread(last) &&
        incomingUnread > existingUnread) {
      final adjusted = incomingUnread - 1;
      ConversationUnreadTrace.log(
        'merge_unread_suppress_tip',
        conversationID: conversationId,
        unreadBefore: existingUnread,
        unreadAfter: adjusted,
        extras: <String, Object?>{
          'incoming': incomingUnread,
          'readClearedAtMs': readClearedAtMs,
          'elemType': last.elemType,
        },
      );
      incomingUnread = adjusted;
      incoming.unreadCount = adjusted;
    }

    if (incomingUnread == 0) {
      incoming.unreadCount = 0;
      if (existingUnread != 0) {
        ConversationUnreadTrace.log(
          'merge_unread_result',
          conversationID: conversationId,
          unreadBefore: existingUnread,
          unreadAfter: 0,
          extras: <String, Object?>{
            'incoming': incoming.unreadCount ?? 0,
            'readClearedAtMs': readClearedAtMs,
            'reason': 'sdk_zero',
          },
        );
      }
      return;
    }

    incoming.unreadCount = incomingUnread;
    if (incomingUnread != existingUnread) {
      ConversationUnreadTrace.log(
        'merge_unread_result',
        conversationID: conversationId,
        unreadBefore: existingUnread,
        unreadAfter: incomingUnread,
        extras: <String, Object?>{
          'incoming': incomingUnread,
          'readClearedAtMs': readClearedAtMs,
          'reason': 'sdk_unread',
          'incomingGeneration': incomingGeneration,
          'committedGeneration':
              _sdkUnreadSourceVersions[sourceKey] ?? committedGeneration,
          'readBarrierVersion': readBarrierVersion,
          'decision': 'accepted',
        },
      );
    }
  }

  int _sdkUnreadSourceVersion(V2TimConversation conversation) {
    final message = conversation.lastMessage;
    final seq = int.tryParse(message?.seq?.trim() ?? '') ?? 0;
    final timestamp = message?.timestamp ?? 0;
    return seq > timestamp ? seq : timestamp;
  }

  static int _sortConversations(V2TimConversation a, V2TimConversation b) {
    final pinA = a.isPinned == true ? 1 : 0;
    final pinB = b.isPinned == true ? 1 : 0;
    if (pinA != pinB) {
      return pinB.compareTo(pinA);
    }
    final activeA = activeTimeMs(a);
    final activeB = activeTimeMs(b);
    if (activeA != activeB) {
      return activeB.compareTo(activeA);
    }
    final orderA = a.orderkey ?? 0;
    final orderB = b.orderkey ?? 0;
    if (orderA != orderB) {
      return orderB.compareTo(orderA);
    }
    return a.conversationID.compareTo(b.conversationID);
  }

  @visibleForTesting
  static int compareConversationsForTest(
    V2TimConversation a,
    V2TimConversation b,
  ) {
    return compareConversationsForUi(a, b);
  }

  @visibleForTesting
  static String normalizeDraftTextForTest(String text) =>
      _normalizeDraftText(text);

  @visibleForTesting
  void applyPreservedLocalDraftForTest(
    V2TimConversation incoming, {
    required String preservedLocalDraftText,
    required int preservedLocalDraftUpdatedAtMs,
  }) {
    _applyPreservedLocalDraftOnIncoming(
      incoming,
      preservedLocalDraftText: preservedLocalDraftText,
      preservedLocalDraftUpdatedAtMs: preservedLocalDraftUpdatedAtMs,
    );
  }

  @visibleForTesting
  static int activeTimeForPersistedRowForTest(
    V2TimConversation conversation, {
    required String localDraftText,
    required int localDraftUpdatedAtMs,
  }) {
    return _activeTimeForPersistedRow(
      conversation,
      localDraftText: localDraftText,
      localDraftUpdatedAtMs: localDraftUpdatedAtMs,
    );
  }

  @visibleForTesting
  void resetAnchorStateForTest() {
    _historyClearIndexGeneration++;
    _readClearedAtMs.clear();
    _readClearedLastMsgId.clear();
    _readBarriers.clear();
    _historyClearedAtMs.clear();
    _historyClearIndexHydratedOwners.clear();
    _historyClearIndexInFlightByOwner.clear();
    debugOwnerUserId = null;
  }

  @visibleForTesting
  void mergeConversationUnreadForTest({
    required V2TimConversation existing,
    required V2TimConversation incoming,
    required String owner,
    required String conversationId,
    required int readClearedAtMs,
  }) {
    _mergeConversationUnread(
      existing: existing,
      incoming: incoming,
      owner: owner,
      conversationId: conversationId,
      readClearedAtMs: readClearedAtMs,
    );
  }

  /// SQLite 行 → UI 会话对象。大批量时可走 Isolate 解码 `raw_json`。
  Future<List<V2TimConversation>> _conversationsFromDbRows(
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) {
      return <V2TimConversation>[];
    }
    final useIsolate = !kIsWeb &&
        ConversationPerfFlags.isolateRowDecodeEnabled &&
        rows.length >= ConversationPerfFlags.isolateRowDecodeMinRows;
    if (useIsolate) {
      try {
        final cloned = rows
            .map((row) => Map<String, Object?>.from(row))
            .toList(growable: false);
        final payloads =
            await compute(decodeConversationRowsForIsolate, cloned);
        final out = <V2TimConversation>[];
        for (final payload in payloads) {
          final conversation = _conversationFromIsolatePayload(payload);
          if (conversation == null) {
            continue;
          }
          _applyBackendPinnedFlag(conversation);
          _decorateConversation(conversation);
          out.add(conversation);
        }
        return out;
      } catch (e, st) {
        debugPrint(
          'ConversationLocalStore: isolate row decode failed, fallback sync: $e\n$st',
        );
      }
    }
    final out = <V2TimConversation>[];
    for (final row in rows) {
      final conversation = _conversationFromRow(row);
      if (conversation == null) {
        continue;
      }
      _applyBackendPinnedFlag(conversation);
      _decorateConversation(conversation);
      out.add(conversation);
    }
    return out;
  }

  V2TimConversation? _conversationFromIsolatePayload(
    Map<String, dynamic> payload,
  ) {
    final conversationId = payload['conversation_id']?.toString() ?? '';
    var userId = payload['user_id']?.toString() ?? '';
    var groupId = payload['group_id']?.toString() ?? '';
    if (groupId.isEmpty && conversationId.startsWith('group_')) {
      groupId = conversationId.substring(6);
    }
    if (userId.isEmpty && conversationId.startsWith('c2c_')) {
      userId = conversationId.substring(4);
    }
    final convType = _resolvedConvType(
      conversationId,
      payload['conv_type'] as int? ?? 0,
      groupId,
      userId,
    );

    V2TimConversation? conversation;
    final decoded = payload['decoded'];
    if (decoded is Map) {
      conversation = _conversationFromLooseMap(
        Map<String, dynamic>.from(decoded),
        conversationId: conversationId,
        convType: convType,
        userId: userId,
        groupId: groupId,
      );
    }
    conversation ??= conversationId.isEmpty
        ? null
        : V2TimConversation(
            conversationID: conversationId,
            type: convType > 0 ? convType : (groupId.isNotEmpty ? 2 : 1),
            userID: userId.isEmpty ? null : userId,
            groupID: groupId.isEmpty ? null : groupId,
            isPinned: (payload['is_pinned'] as int? ?? 0) != 0,
            orderkey: payload['order_key'] as int? ?? 0,
          );
    if (conversation == null) {
      return null;
    }
    final rowFallback = <String, Object?>{
      'show_name': payload['show_name'],
      'face_url': payload['face_url'],
      'unread_count': payload['unread_count'],
      'read_cleared_at': payload['read_cleared_at'],
      'recv_opt': payload['recv_opt'],
      'group_type': payload['group_type'],
      'order_key': payload['order_key'],
      'active_time': payload['active_time'],
      'is_pinned': payload['is_pinned'],
    };
    _applyRowDisplayFallback(conversation, rowFallback);
    applyLocalDraftToConversation(
      conversation,
      text: _normalizeDraftText(payload['local_draft_text']?.toString() ?? ''),
      updatedAtMs: payload['local_draft_updated_at'] as int? ?? 0,
    );
    return conversation;
  }

  V2TimConversation? _conversationFromRow(Map<String, Object?> row) {
    final conversationId = row['conversation_id']?.toString() ?? '';
    var userId = row['user_id']?.toString() ?? '';
    var groupId = row['group_id']?.toString() ?? '';
    if (groupId.isEmpty && conversationId.startsWith('group_')) {
      groupId = conversationId.substring(6);
    }
    if (userId.isEmpty && conversationId.startsWith('c2c_')) {
      userId = conversationId.substring(4);
    }
    final convType = _resolvedConvType(
      conversationId,
      row['conv_type'] as int? ?? 0,
      groupId,
      userId,
    );

    V2TimConversation? conversation;
    final raw = row['raw_json']?.toString() ?? '';
    if (raw.isNotEmpty) {
      try {
        _profileRawJsonDecodes++;
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          conversation = _conversationFromLooseMap(
            Map<String, dynamic>.from(decoded),
            conversationId: conversationId,
            convType: convType,
            userId: userId,
            groupId: groupId,
          );
        }
      } catch (_) {}
    }

    conversation ??= conversationId.isEmpty
        ? null
        : V2TimConversation(
            conversationID: conversationId,
            type: convType > 0 ? convType : (groupId.isNotEmpty ? 2 : 1),
            userID: userId.isEmpty ? null : userId,
            groupID: groupId.isEmpty ? null : groupId,
            isPinned: (row['is_pinned'] as int? ?? 0) != 0,
            orderkey: row['order_key'] as int? ?? 0,
          );

    if (conversation == null) {
      return null;
    }
    _applyRowDisplayFallback(conversation, row);
    applyLocalDraftToConversation(
      conversation,
      text: _localDraftTextFromRow(row),
      updatedAtMs: _localDraftUpdatedAtMsFromRow(row),
    );
    return conversation;
  }

  static V2TimConversation _conversationFromLooseMap(
    Map<String, dynamic> json, {
    required String conversationId,
    required int convType,
    required String userId,
    required String groupId,
  }) {
    final resolvedType = _resolvedConvType(
      conversationId,
      json['conv_type'] as int? ?? convType,
      groupId,
      userId,
    );
    final conversation = V2TimConversation(
      conversationID: conversationId,
      type: resolvedType > 0 ? resolvedType : (groupId.isNotEmpty ? 2 : 1),
      userID: userId.isEmpty ? null : userId,
      groupID: groupId.isEmpty ? null : groupId,
    );
    conversation.showName = json['conv_show_name']?.toString();
    conversation.faceUrl = json['conv_face_url']?.toString();
    conversation.groupType = json['conv_group_type']?.toString();
    conversation.unreadCount = _asInt(json['conv_unread_num']);
    conversation.isPinned = json['conv_is_pinned'] == true;
    conversation.recvOpt = json['conv_recv_opt'] as int?;
    conversation.orderkey = _asInt(json['conv_active_time']);
    conversation.customData = json['conv_custom_data']?.toString();
    conversation.c2cReadTimestamp = _asInt(json['conv_c2c_read_timestamp']);
    conversation.groupReadSequence = _asInt(json['conv_group_read_sequence']);

    if (json['conv_is_has_draft'] == true) {
      final draft = json['conv_draft'];
      if (draft is Map) {
        conversation.draftTimestamp = _asInt(
          draft['edit_time'] ?? draft['editTime'],
        );
        final message = draft['message'];
        if (message is Map) {
          final textElem = message['text_elem'] ?? message['textElem'];
          if (textElem is Map) {
            conversation.draftText = textElem['text']?.toString();
          }
        }
      }
    }

    final lastMessage = json['conv_last_msg'];
    if (lastMessage is Map) {
      try {
        conversation.lastMessage = V2TimMessage.fromJson(
          Map<String, dynamic>.from(lastMessage),
        );
      } catch (_) {}
    }

    if (json['conv_group_at_info_array'] is List) {
      conversation.groupAtInfoList = [];
    }

    _applyConversationIdentityFallback(
      conversation,
      conversationId: conversationId,
      convType: resolvedType,
      userId: userId,
      groupId: groupId,
    );
    return conversation;
  }

  static void _applyRowDisplayFallback(
    V2TimConversation conversation,
    Map<String, Object?> row,
  ) {
    final showName = row['show_name']?.toString().trim() ?? '';
    if ((conversation.showName?.trim().isEmpty ?? true) &&
        showName.isNotEmpty) {
      conversation.showName = showName;
    }
    final faceUrl = row['face_url']?.toString().trim() ?? '';
    if ((conversation.faceUrl?.trim().isEmpty ?? true) && faceUrl.isNotEmpty) {
      conversation.faceUrl = faceUrl;
    }
    final unreadCol = _asInt(row['unread_count']);
    final readClearedAt = row['read_cleared_at'] as int? ?? 0;
    // 批量已读只更新列：当列已清零且写过已读锚点时，以列为准，避免 raw_json 旧未读盖回。
    if (unreadCol <= 0 && readClearedAt > 0) {
      conversation.unreadCount = 0;
    } else if ((conversation.unreadCount ?? 0) == 0 && unreadCol > 0) {
      if (!ConversationLocalStore.instance.isWithinReadGrace(readClearedAt)) {
        conversation.unreadCount = unreadCol;
      }
    }
    final recvOpt = row['recv_opt'] as int?;
    if ((conversation.recvOpt ?? 0) == 0 && recvOpt != null && recvOpt != 0) {
      conversation.recvOpt = recvOpt;
    }
    final groupType = row['group_type']?.toString().trim() ?? '';
    if ((conversation.groupType?.trim().isEmpty ?? true) &&
        groupType.isNotEmpty) {
      conversation.groupType = groupType;
    }
    ConversationLocalStore.instance._applyBackendPinnedFlag(conversation);
    final rowOrderKey = row['order_key'] as int? ?? 0;
    final rowActiveTime = row['active_time'] as int? ?? 0;
    final bestKey = rowOrderKey > rowActiveTime ? rowOrderKey : rowActiveTime;
    if (bestKey > (conversation.orderkey ?? 0)) {
      conversation.orderkey = bestKey;
    }
    if (rowActiveTime > 0) {
      ConversationLocalStore.instance.rememberPagingActiveTime(
        conversation,
        rowActiveTime,
      );
    }
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _decorateConversation(V2TimConversation conversation) {
    _hydrateGroupShowNameFromLocal(conversation);
    final beforeApply = conversation.showName?.trim() ?? '';
    DisplayNameStore.instance.applyToConversation(conversation);
    final groupId = conversation.groupID?.trim() ?? '';
    if (groupId.isEmpty) {
      return;
    }
    // 历史缓存可能误存了完整 IM ID，避免盖掉已恢复的真实群名。
    if (GroupDisplayResolver.looksLikeGroupIdLabel(
      conversation.showName,
      groupId: groupId,
    )) {
      if (beforeApply.isNotEmpty &&
          !GroupDisplayResolver.looksLikeGroupIdLabel(
            beforeApply,
            groupId: groupId,
          )) {
        conversation.showName = beforeApply;
      } else {
        _hydrateGroupShowNameFromLocal(conversation);
      }
    }
  }

  void _hydrateGroupShowNameFromLocal(V2TimConversation conversation) {
    final groupId = conversation.groupID?.trim() ?? '';
    if (groupId.isEmpty && !conversation.conversationID.startsWith('group_')) {
      return;
    }
    final id = groupId.isNotEmpty
        ? groupId
        : conversation.conversationID.substring('group_'.length);
    final current = conversation.showName?.trim() ?? '';
    final needsName = current.isEmpty ||
        GroupDisplayResolver.looksLikeGroupIdLabel(current, groupId: id);
    if (!needsName) {
      return;
    }
    final localName =
        GroupLocalStore.instance.readCached(groupId: id)?.groupName.trim() ??
            '';
    if (localName.isEmpty ||
        GroupDisplayResolver.looksLikeGroupIdLabel(localName, groupId: id)) {
      return;
    }
    conversation.showName = localName;
    DisplayNameStore.instance.setGroup(id, localName, notify: false);
    final canonical = ChatIdFormat.canonicalGroupStorageId(id);
    if (canonical.isNotEmpty && canonical != id) {
      DisplayNameStore.instance.setGroup(canonical, localName, notify: false);
    }
  }

  void _captureDisplayName(V2TimConversation conversation) {
    final showName = conversation.showName?.trim() ?? '';
    if (showName.isEmpty) {
      return;
    }
    final groupId = conversation.groupID?.trim() ?? '';
    if (groupId.isNotEmpty ||
        conversation.conversationID.startsWith('group_')) {
      final id = groupId.isNotEmpty
          ? groupId
          : conversation.conversationID.substring(6);
      // 禁止把完整 IM ID / 短码别名写入展示名缓存。
      if (GroupDisplayResolver.looksLikeGroupIdLabel(showName, groupId: id)) {
        return;
      }
      // A conversation snapshot may lag behind the authoritative group
      // record after login/reconnect. Keep an existing local/self-hosted name
      // from being overwritten by that stale showName. Explicit group-info
      // change events still write through directly.
      final existing = DisplayNameStore.instance.groupWhere(
        id,
        (storedId, queryId) =>
            ChatIdFormat.groupEquivalenceToken(storedId) ==
            ChatIdFormat.groupEquivalenceToken(queryId),
      );
      if (existing == null || existing.trim().isEmpty) {
        DisplayNameStore.instance.setGroup(id, showName, notify: false);
        final canonical = ChatIdFormat.canonicalGroupStorageId(id);
        if (canonical.isNotEmpty && canonical != id) {
          DisplayNameStore.instance
              .setGroup(canonical, showName, notify: false);
        }
      }
      return;
    }
    final userId = conversation.userID?.trim() ?? '';
    if (userId.isEmpty) {
      return;
    }
    // C2C：Store 已非空时禁止会话 showName（常为昵称）覆盖备注。
    final existingStore = DisplayNameStore.instance
            .c2c(ChatIdFormat.rawUserUid(userId))
            ?.trim() ??
        '';
    if (existingStore.isNotEmpty) {
      return;
    }
    if (DisplayNameStore.isRawUserIdDisplayName(userId, showName)) {
      return;
    }
    DisplayNameStore.instance.setC2C(userId, showName, notify: false);
  }

  static int _resolvedConvType(
    String conversationId,
    int convType,
    String groupId,
    String userId,
  ) {
    if (convType > 0) {
      return convType;
    }
    if (groupId.isNotEmpty || conversationId.startsWith('group_')) {
      return 2;
    }
    if (userId.isNotEmpty || conversationId.startsWith('c2c_')) {
      return 1;
    }
    return convType;
  }

  static void _applyConversationIdentityFallback(
    V2TimConversation conversation, {
    required String conversationId,
    required int convType,
    required String userId,
    required String groupId,
  }) {
    if (conversation.conversationID.trim().isEmpty &&
        conversationId.isNotEmpty) {
      conversation.conversationID = conversationId;
    }
    final resolvedType = _resolvedConvType(
      conversation.conversationID,
      conversation.type ?? convType,
      conversation.groupID ?? groupId,
      conversation.userID ?? userId,
    );
    if ((conversation.type ?? 0) == 0 && resolvedType > 0) {
      conversation.type = resolvedType;
    }
    if ((conversation.groupID ?? '').isEmpty) {
      if (groupId.isNotEmpty) {
        conversation.groupID = groupId;
      } else if (conversation.conversationID.startsWith('group_')) {
        conversation.groupID = conversation.conversationID.substring(6);
      }
    }
    if ((conversation.userID ?? '').isEmpty) {
      if (userId.isNotEmpty) {
        conversation.userID = userId;
      } else if (conversation.conversationID.startsWith('c2c_')) {
        conversation.userID = conversation.conversationID.substring(4);
      }
    }
  }

  static String _resolvedGroupId(V2TimConversation conversation) {
    final groupId = conversation.groupID?.trim() ?? '';
    if (groupId.isNotEmpty) {
      return groupId;
    }
    final conversationId = conversation.conversationID;
    if (conversationId.startsWith('group_')) {
      return conversationId.substring(6);
    }
    return '';
  }

  static String _resolvedUserId(V2TimConversation conversation) {
    final userId = conversation.userID?.trim() ?? '';
    if (userId.isNotEmpty) {
      return userId;
    }
    final conversationId = conversation.conversationID;
    if (conversationId.startsWith('c2c_')) {
      return conversationId.substring(4);
    }
    return '';
  }

  static int _resolvedStoredConvType(V2TimConversation conversation) {
    final type = conversation.type ?? 0;
    if (type > 0) {
      return type;
    }
    if (_resolvedGroupId(conversation).isNotEmpty) {
      return 2;
    }
    return 1;
  }

  Map<String, Object?> _rowFromConversation(
    String owner,
    V2TimConversation conversation,
    int updatedAt, {
    int readClearedAtMs = 0,
    int historyClearedAtMs = 0,
    String localDraftText = '',
    int localDraftUpdatedAtMs = 0,
    int? pinnedActiveTimeMs,
    int? pinnedOrderKey,
    String? rawJson,
  }) {
    final groupId = _resolvedGroupId(conversation);
    final userId = _resolvedUserId(conversation);
    final normalizedLocalDraft = _normalizeDraftText(localDraftText);
    final orderKey = pinnedOrderKey ?? conversation.orderkey ?? 0;
    final encodedRawJson = rawJson ?? jsonEncode(conversation.toJson());
    final activeTime = pinnedActiveTimeMs ??
        _activeTimeForPersistedRow(
          conversation,
          localDraftText: normalizedLocalDraft,
          localDraftUpdatedAtMs: localDraftUpdatedAtMs,
        );
    return <String, Object?>{
      'owner_user_id': owner,
      'conversation_id': conversation.conversationID,
      'conv_type': _resolvedStoredConvType(conversation),
      'user_id': userId,
      'group_id': groupId,
      'show_name': conversation.showName ?? '',
      'face_url': conversation.faceUrl ?? '',
      'unread_count': conversation.unreadCount ?? 0,
      'recv_opt': conversation.recvOpt ?? 0,
      'group_type': conversation.groupType ?? '',
      'is_pinned': (conversation.isPinned ?? false) ? 1 : 0,
      'order_key': orderKey,
      'active_time': activeTime,
      'raw_json': encodedRawJson,
      'raw_json_fingerprint': _fingerprintForPersist(
        conversation: conversation,
        rawJson: encodedRawJson,
        readClearedAtMs: readClearedAtMs,
        historyClearedAtMs: historyClearedAtMs,
        localDraftText: normalizedLocalDraft,
        localDraftUpdatedAtMs: localDraftUpdatedAtMs,
        activeTime: activeTime,
        orderKey: orderKey,
      ),
      'updated_at': updatedAt,
      'read_cleared_at': readClearedAtMs,
      'history_cleared_at': historyClearedAtMs,
      'local_draft_text': normalizedLocalDraft,
      'local_draft_updated_at':
          normalizedLocalDraft.isEmpty ? 0 : localDraftUpdatedAtMs,
      'last_msg_id': conversation.lastMessage?.msgID?.trim() ?? '',
    };
  }

  /// 不 encode 整包 JSON，仅投影比较列，供 upsert 快路径跳过。
  Map<String, Object?> _comparisonProbeFromConversation(
    String owner,
    V2TimConversation conversation, {
    required int readClearedAtMs,
    required int historyClearedAtMs,
    String localDraftText = '',
    int localDraftUpdatedAtMs = 0,
  }) {
    final normalizedLocalDraft = _normalizeDraftText(localDraftText);
    final orderKey = conversation.orderkey ?? 0;
    final activeTime = _activeTimeForPersistedRow(
      conversation,
      localDraftText: normalizedLocalDraft,
      localDraftUpdatedAtMs: localDraftUpdatedAtMs,
    );
    return <String, Object?>{
      'owner_user_id': owner,
      'conversation_id': conversation.conversationID,
      'conv_type': _resolvedStoredConvType(conversation),
      'user_id': _resolvedUserId(conversation),
      'group_id': _resolvedGroupId(conversation),
      'show_name': conversation.showName ?? '',
      'face_url': conversation.faceUrl ?? '',
      'unread_count': conversation.unreadCount ?? 0,
      'recv_opt': conversation.recvOpt ?? 0,
      'group_type': conversation.groupType ?? '',
      'is_pinned': (conversation.isPinned ?? false) ? 1 : 0,
      'order_key': orderKey,
      'active_time': activeTime,
      'raw_json_fingerprint': _lightweightContentFingerprint(
        conversation: conversation,
        readClearedAtMs: readClearedAtMs,
        historyClearedAtMs: historyClearedAtMs,
        localDraftText: normalizedLocalDraft,
        localDraftUpdatedAtMs: localDraftUpdatedAtMs,
        activeTime: activeTime,
        orderKey: orderKey,
      ),
      'read_cleared_at': readClearedAtMs,
      'history_cleared_at': historyClearedAtMs,
      'local_draft_text': normalizedLocalDraft,
      'local_draft_updated_at':
          normalizedLocalDraft.isEmpty ? 0 : localDraftUpdatedAtMs,
      'last_msg_id': conversation.lastMessage?.msgID?.trim() ?? '',
    };
  }

  static bool _samePersistedConversationRow(
    Map<String, Object?> existing,
    Map<String, Object?> incoming,
  ) {
    for (final column in _persistedComparisonColumns) {
      if (existing[column] != incoming[column]) {
        return false;
      }
    }
    return true;
  }

  static String _fingerprintForPersist({
    required V2TimConversation conversation,
    required String rawJson,
    required int readClearedAtMs,
    required int historyClearedAtMs,
    required String localDraftText,
    required int localDraftUpdatedAtMs,
    required int activeTime,
    required int orderKey,
  }) {
    if (ConversationPerfFlags.useLightweightFingerprint) {
      return _lightweightContentFingerprint(
        conversation: conversation,
        readClearedAtMs: readClearedAtMs,
        historyClearedAtMs: historyClearedAtMs,
        localDraftText: localDraftText,
        localDraftUpdatedAtMs: localDraftUpdatedAtMs,
        activeTime: activeTime,
        orderKey: orderKey,
      );
    }
    return _rawJsonFingerprint(rawJson);
  }

  /// 列表热路径关心的字段指纹（避免整包 JSON UTF-8）。
  @visibleForTesting
  static String lightweightContentFingerprintForTest(
    V2TimConversation conversation, {
    int readClearedAtMs = 0,
    int historyClearedAtMs = 0,
    String localDraftText = '',
    int localDraftUpdatedAtMs = 0,
    int activeTime = 0,
    int orderKey = 0,
  }) {
    return _lightweightContentFingerprint(
      conversation: conversation,
      readClearedAtMs: readClearedAtMs,
      historyClearedAtMs: historyClearedAtMs,
      localDraftText: localDraftText,
      localDraftUpdatedAtMs: localDraftUpdatedAtMs,
      activeTime: activeTime,
      orderKey: orderKey,
    );
  }

  static String _lightweightContentFingerprint({
    required V2TimConversation conversation,
    required int readClearedAtMs,
    required int historyClearedAtMs,
    required String localDraftText,
    required int localDraftUpdatedAtMs,
    required int activeTime,
    required int orderKey,
  }) {
    final last = conversation.lastMessage;
    final parts = <Object?>[
      conversation.conversationID,
      conversation.type ?? 0,
      conversation.userID ?? '',
      conversation.groupID ?? '',
      conversation.showName ?? '',
      conversation.faceUrl ?? '',
      conversation.unreadCount ?? 0,
      conversation.recvOpt ?? 0,
      conversation.groupType ?? '',
      (conversation.isPinned ?? false) ? 1 : 0,
      orderKey,
      activeTime,
      last?.msgID?.trim() ?? '',
      last?.timestamp ?? 0,
      last?.elemType ?? 0,
      last?.status ?? 0,
      last?.isPeerRead == true ? 1 : 0,
      last?.textElem?.text ?? '',
      last?.customElem?.data ?? '',
      last?.customElem?.desc ?? '',
      last?.customElem?.extension ?? '',
      last?.faceElem?.data ?? '',
      last?.sender ?? '',
      last?.nickName ?? '',
      last?.nameCard ?? '',
      last?.groupTipsElem == null
          ? ''
          : jsonEncode(last!.groupTipsElem!.toJson()),
      readClearedAtMs,
      historyClearedAtMs,
      localDraftText,
      localDraftText.isEmpty ? 0 : localDraftUpdatedAtMs,
    ];
    final customData = conversation.customData?.trim() ?? '';
    if (customData.isNotEmpty) {
      parts.add('custom:$customData');
    }
    final payload = parts.join('\u{1f}');
    return sha256.convert(utf8.encode(payload)).toString();
  }

  static String _rawJsonFingerprint(String rawJson) =>
      sha256.convert(utf8.encode(rawJson)).toString();

  @visibleForTesting
  static List<(String, bool)> pinnedFlagChangesForRows({
    required Iterable<Map<String, Object?>> rows,
    required bool Function(String conversationId) matchesPinned,
  }) {
    final changes = <(String, bool)>[];
    for (final row in rows) {
      final id = row['conversation_id']?.toString().trim() ?? '';
      if (id.isEmpty) {
        continue;
      }
      final nextPinned = matchesPinned(id);
      final currentPinned = (row['is_pinned'] as int? ?? 0) != 0;
      if (nextPinned != currentPinned) {
        changes.add((id, nextPinned));
      }
    }
    return changes;
  }

  ConversationSyncMeta _syncMetaFromRow(Map<String, Object?> row) {
    final c2cHaveMore = row.containsKey('c2c_have_more')
        ? (row['c2c_have_more'] as int? ?? 1) != 0
        : (row['have_more'] as int? ?? 1) != 0;
    final groupHaveMore = row.containsKey('group_have_more')
        ? (row['group_have_more'] as int? ?? 1) != 0
        : (row['have_more'] as int? ?? 1) != 0;
    final c2cNextSeq = row['c2c_next_seq']?.toString() ?? '0';
    final groupNextSeq = row['group_next_seq']?.toString() ?? '0';
    return ConversationSyncMeta(
      nextSeq: row['next_seq']?.toString() ?? '0',
      haveMore: c2cHaveMore || groupHaveMore,
      hasSyncedOnce: (row['has_synced_once'] as int? ?? 0) != 0,
      c2cNextSeq: c2cNextSeq.isEmpty ? '0' : c2cNextSeq,
      c2cHaveMore: c2cHaveMore,
      groupNextSeq: groupNextSeq.isEmpty ? '0' : groupNextSeq,
      groupHaveMore: groupHaveMore,
    );
  }

  /// 用置顶全量集合覆盖本地 `is_pinned`，仅提交实际变化的行。
  /// 集合应由 [ConversationPinSyncService] 按腾讯（或回退自建）对齐后传入。
  Future<void> replaceAllPinnedFlags({
    required Set<String> pinnedConversationIds,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    final pinned = pinnedConversationIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    bool matchesPinned(String conversationId) {
      if (pinned.contains(conversationId)) {
        return true;
      }
      for (final id in pinned) {
        if (MessageConversationId.sameConversation(id, conversationId)) {
          return true;
        }
      }
      return false;
    }

    if (_useMemoryOnly) {
      final list = List<V2TimConversation>.from(
        _memoryByOwner[owner] ?? const [],
      );
      for (final conversation in list) {
        if (ConversationPinSyncService.instance.isHydrated) {
          conversation.isPinned = matchesPinned(conversation.conversationID);
        }
      }
      list.sort(_sortConversations);
      _memoryByOwner[owner] = list;
      return;
    }

    final db = await _openDb();
    await profiledTransaction<void>(
      db,
      dbTag: _dbName,
      op: 'replaceAllPinnedFlags',
      extras: <String, Object?>{'pinnedCount': pinned.length},
      action: (txn) async {
        final rows = await txn.query(
          _table,
          columns: <String>['conversation_id', 'is_pinned'],
          where: 'owner_user_id = ?',
          whereArgs: [owner],
        );
        final changes = pinnedFlagChangesForRows(
          rows: rows,
          matchesPinned: matchesPinned,
        );
        if (changes.isEmpty) {
          return;
        }
        final batch = txn.batch();
        for (final change in changes) {
          batch.update(
            _table,
            <String, Object?>{'is_pinned': change.$2 ? 1 : 0},
            where: 'owner_user_id = ? AND conversation_id = ?',
            whereArgs: [owner, change.$1],
          );
        }
        await batch.commit(noResult: true);
      },
    );
  }
}

class _UpsertCoalesceWaiter {
  _UpsertCoalesceWaiter(Set<String> requestedKeys)
      : requestedKeys = Set<String>.from(requestedKeys);

  final Set<String> requestedKeys;
  final Completer<List<V2TimConversation>> completer =
      Completer<List<V2TimConversation>>();
}

class ConversationSyncMeta {
  const ConversationSyncMeta({
    this.nextSeq = '0',
    this.haveMore = true,
    this.hasSyncedOnce = false,
    this.c2cNextSeq = '0',
    this.c2cHaveMore = true,
    this.groupNextSeq = '0',
    this.groupHaveMore = true,
  });

  /// 旧混流游标（typed 模式下仅兼容落库，不以它分页）。
  final String nextSeq;

  /// 任一路仍有更多时为 true（兼容旧调用方）。
  final bool haveMore;
  final bool hasSyncedOnce;

  final String c2cNextSeq;
  final bool c2cHaveMore;
  final String groupNextSeq;
  final bool groupHaveMore;

  bool haveMoreForType(int convType) {
    return convType == 2 ? groupHaveMore : c2cHaveMore;
  }

  String nextSeqForType(int convType) {
    return convType == 2 ? groupNextSeq : c2cNextSeq;
  }

  ConversationSyncMeta copyWith({
    String? nextSeq,
    bool? haveMore,
    bool? hasSyncedOnce,
    String? c2cNextSeq,
    bool? c2cHaveMore,
    String? groupNextSeq,
    bool? groupHaveMore,
  }) {
    final nextC2cHaveMore = c2cHaveMore ?? this.c2cHaveMore;
    final nextGroupHaveMore = groupHaveMore ?? this.groupHaveMore;
    return ConversationSyncMeta(
      nextSeq: nextSeq ?? this.nextSeq,
      haveMore: haveMore ?? (nextC2cHaveMore || nextGroupHaveMore),
      hasSyncedOnce: hasSyncedOnce ?? this.hasSyncedOnce,
      c2cNextSeq: c2cNextSeq ?? this.c2cNextSeq,
      c2cHaveMore: nextC2cHaveMore,
      groupNextSeq: groupNextSeq ?? this.groupNextSeq,
      groupHaveMore: nextGroupHaveMore,
    );
  }

  ConversationSyncMeta withTypedCursor({
    required int convType,
    required String nextSeq,
    required bool haveMore,
    bool? hasSyncedOnce,
  }) {
    final normalized = nextSeq.trim().isEmpty ? '0' : nextSeq.trim();
    if (convType == 2) {
      return copyWith(
        groupNextSeq: normalized,
        groupHaveMore: haveMore,
        hasSyncedOnce: hasSyncedOnce,
      );
    }
    return copyWith(
      c2cNextSeq: normalized,
      c2cHaveMore: haveMore,
      hasSyncedOnce: hasSyncedOnce,
    );
  }
}
