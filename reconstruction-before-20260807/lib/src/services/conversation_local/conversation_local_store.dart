import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_unread_trace.dart';
import 'package:tencent_cloud_chat_demo/src/services/foreground_chat_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lock_profile_log.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_unread_utils.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';

import 'web_conversation_meta_store.dart';

/// 会话列表本地库（按登录账号隔离）。UI 只读此库，SDK 更新只写此库。
/// 置顶真相为 [ConversationPinSyncService]（自建后端），忽略 SDK `isPinned`。
class ConversationLocalStore {
  ConversationLocalStore._();

  static final ConversationLocalStore instance = ConversationLocalStore._();

  static const _dbName = 'conversation_local_v1.db';
  static const _table = 'conversations';
  static const _metaTable = 'conversation_sync_meta';

  Database? _db;
  final Map<String, List<V2TimConversation>> _memoryByOwner = {};
  final Map<String, ConversationSyncMeta> _memoryMetaByOwner = {};
  bool _factoryReady = false;

  final Set<String> _webMetaHydratedOwners = <String>{};
  Timer? _webMetaPersistTimer;
  String? _webMetaPersistOwner;

  void _applyBackendPinnedFlag(V2TimConversation conversation) {
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

  static const _dbVersion = 6;
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

  final Map<String, int> _readClearedAtMs = {};
  final Map<String, String> _readClearedLastMsgId = {};
  final Map<String, int> _historyClearedAtMs = {};

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

  /// 单测绕过写合并，避免 100ms 延迟拖垮既有用例。
  @visibleForTesting
  static bool bypassUpsertCoalesceForTest = false;

  @visibleForTesting
  Future<void> Function()? beforeUpsertBatchImplForTest;

  Future<Database> _openDb() async {
    final existing = _db;
    if (existing != null) {
      return existing;
    }
    await _ensureDatabaseFactory();
    final basePath = await getDatabasesPath();
    final path = p.join(basePath, _dbName);
    _db = await openDatabase(
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
        await _createMetaTable(db);
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
      },
    );
    return _db!;
  }

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
        updated_at INTEGER NOT NULL DEFAULT 0
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

  /// 同步写入已读锚点内存缓存（不写 DB）。
  void recordReadClearedAnchor(
    String conversationID, {
    String? ownerUserId,
    String? lastMessageId,
  }) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    _recordReadCleared(
      owner,
      id,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    final resolvedLastMessageId =
        lastMessageId?.trim() ?? _lastMessageIdForConversation(owner, id) ?? '';
    if (resolvedLastMessageId.isNotEmpty) {
      _readClearedLastMsgId[_readClearCacheKey(owner, id)] =
          resolvedLastMessageId;
    }
  }

  String? _lastMessageIdForConversation(String owner, String conversationId) {
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
      final msgId = conversation.lastMessage?.msgID?.trim() ?? '';
      return msgId.isEmpty ? null : msgId;
    }
    return null;
  }

  void _clearReadCleared(String owner, String conversationId) {
    final key = _readClearCacheKey(owner, conversationId);
    _readClearedAtMs.remove(key);
    _readClearedLastMsgId.remove(key);
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
    return _readClearedAtMs[_readClearCacheKey(owner, conversationId)] ??
        rowReadClearedAtMs;
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
    if ((conversation.unreadCount ?? 0) > 0) {
      _clearReadCleared(owner, conversationId);
      return 0;
    }
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
    if (_useMemoryOnly) {
      await _ensureWebMetaHydrated(owner);
      for (final candidate in candidates) {
        final cached =
            _historyClearedAtMs[_historyClearCacheKey(owner, candidate)];
        if (cached != null && cached > 0) {
          return cached;
        }
      }
      return 0;
    }
    final db = await _openDb();
    for (final candidate in candidates) {
      final row = await _findPersistedConversationRow(
        db,
        owner: owner,
        conversationId: candidate,
      );
      final at = row?['history_cleared_at'] as int? ?? 0;
      if (at > 0) {
        return at;
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
    final debug = debugOwnerUserId?.trim() ?? '';
    if (debug.isNotEmpty) {
      return debug;
    }
    return currentOwnerUserId();
  }

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
    final token = SqfliteLockProfileLog.beginOp(
      dbTag: _dbName,
      op: 'loadUiWindow',
    );
    try {
      if (ConversationPerfFlags.uiSnapshotEnabled) {
        return await _loadUiSnapshotWindow(owner);
      }
      return await _loadUiFullOwnerWindow(owner);
    } finally {
      SqfliteLockProfileLog.endOp(token);
    }
  }

  /// 单聊/群聊各 LIMIT 后合并，禁止先全表再 trim。
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
      final merged = <V2TimConversation>[...c2c, ...group];
      merged.sort(_sortConversations);
      return _trimUiWindow(merged);
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
    final conversations = <V2TimConversation>[];
    for (final row in [...c2cRows, ...groupRows]) {
      final conversation = _conversationFromRow(row);
      if (conversation == null) {
        continue;
      }
      _applyBackendPinnedFlag(conversation);
      _decorateConversation(conversation);
      conversations.add(conversation);
    }
    conversations.sort(_sortConversations);
    final window = _trimUiWindow(conversations);
    if (kDebugMode) {
      final c2cCount =
          window.where((c) => _resolvedStoredConvType(c) != 2).length;
      final groupCount =
          window.where((c) => _resolvedStoredConvType(c) == 2).length;
      debugPrint(
        'ConversationLocalStore: ui_window snapshot loaded '
        'c2c=$c2cCount/$c2cLimit group=$groupCount/$groupLimit '
        'total=${window.length}',
      );
    }
    return window;
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
    final wanted = conversationIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (owner.isEmpty || wanted.isEmpty || limit <= 0) {
      return const [];
    }
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    final beforeId = beforeConversationId?.trim() ?? '';
    final hasCursor =
        beforeActiveTime != null && beforeId.isNotEmpty;

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
        offset + chunkSize > idList.length
            ? idList.length
            : offset + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final args = <Object?>[owner, ...chunk];
      final typeClause =
          typeFilter == null ? '' : ' AND conv_type = ?';
      if (typeFilter != null) {
        args.add(typeFilter);
      }
      final rows = await db.rawQuery(
        '''
        SELECT * FROM $_table
        WHERE owner_user_id = ?
          AND conversation_id IN ($placeholders)
          $typeClause
        ''',
        args,
      );
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
    final conversations = <V2TimConversation>[];
    for (final row in rows.reversed) {
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

  Future<List<V2TimConversation>> searchConversations({
    required String keyword,
    int limit = ConversationPerfFlags.uiSearchLimit,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final q = keyword.trim();
    if (owner.isEmpty || q.isEmpty || limit <= 0) {
      return const [];
    }
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
        if (out.length >= limit) {
          break;
        }
      }
      out.sort(_sortConversations);
      return out;
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
      ...archivedC2c.map((e) => e.trim()).where((e) => e.isNotEmpty),
      ...archivedGroup.map((e) => e.trim()).where((e) => e.isNotEmpty),
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
        if ((item.lastMessage?.msgID ?? '').trim() == id) {
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
    final token = SqfliteLockProfileLog.beginOp(
      dbTag: _dbName,
      op: 'conversationsByIds',
      extras: <String, Object?>{'count': wanted.length},
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
      final db = await _openDb();
      final ids = wanted.toList(growable: false);
      final placeholders = List.filled(ids.length, '?').join(',');
      final rows = await db.query(
        _table,
        where: 'owner_user_id = ? AND conversation_id IN ($placeholders)',
        whereArgs: [owner, ...ids],
      );
      final out = <V2TimConversation>[];
      final found = <String>{};
      for (final row in rows) {
        final conversation = _conversationFromRow(row);
        if (conversation == null) {
          continue;
        }
        _decorateConversation(conversation);
        out.add(conversation);
        found.add(conversation.conversationID.trim());
      }
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
        final conversation = _conversationFromRow(row);
        if (conversation == null) {
          continue;
        }
        _decorateConversation(conversation);
        out.add(conversation);
      }
      return out;
    } finally {
      SqfliteLockProfileLog.endOp(token);
    }
  }

  static void decorateConversationForUi(V2TimConversation conversation) {
    DisplayNameStore.instance.applyToConversation(conversation);
  }

  static int compareConversationsForUi(
    V2TimConversation a,
    V2TimConversation b,
  ) {
    return _sortConversations(a, b);
  }

  Future<List<V2TimConversation>> upsertBatch({
    required List<V2TimConversation> conversations,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || conversations.isEmpty) {
      return const [];
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

  void _scheduleUpsertCoalesceFlush() {
    if (_upsertCoalesceById.isEmpty && _upsertCoalesceWaiters.isEmpty) {
      return;
    }
    _upsertCoalesceTimer?.cancel();
    final quietDelay = ConversationPerfFlags.upsertWriteCoalesceDelay;
    final maxDelay = ConversationPerfFlags.upsertWriteCoalesceMaxDelay;
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
    final batch = _upsertCoalesceById.values.toList(growable: false);
    _upsertCoalesceById.clear();
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
        _scheduleUpsertCoalesceFlush();
      } else {
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
  }) async {
    final beforeImpl = beforeUpsertBatchImplForTest;
    if (beforeImpl != null) {
      await beforeImpl();
    }
    final owner = ownerUserId;
    if (owner.isEmpty || conversations.isEmpty) {
      return const [];
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
      }
      list.sort(_sortConversations);
      _memoryByOwner[owner] = list;
      return merged;
    }
    final db = await _openDb();
    await profiledTransaction<void>(
      db,
      dbTag: _dbName,
      op: 'upsertBatch',
      extras: <String, Object?>{'count': conversations.length},
      action: (txn) async {
        final ids = <String>[];
        for (final conversation in conversations) {
          final id = conversation.conversationID.trim();
          if (id.isNotEmpty) {
            ids.add(id);
          }
        }
        final rowByExactId = <String, Map<String, Object?>>{};
        if (ids.isNotEmpty) {
          // SQLite 变量上限保守分批 IN 查询，避免逐条 _findPersistedConversationRow。
          const chunkSize = 200;
          for (var offset = 0; offset < ids.length; offset += chunkSize) {
            final chunk = ids.sublist(
              offset,
              offset + chunkSize > ids.length ? ids.length : offset + chunkSize,
            );
            final placeholders = List.filled(chunk.length, '?').join(',');
            final rows = await txn.query(
              _table,
              columns: _persistedComparisonColumns,
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

        List<Map<String, Object?>>? groupRowsCache;
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
          groupRowsCache ??= await txn.query(
            _table,
            columns: _persistedComparisonColumns,
            where: 'owner_user_id = ? AND conv_type = ?',
            whereArgs: [owner, 2],
          );
          for (final row in groupRowsCache!) {
            final storedId = row['conversation_id']?.toString() ?? '';
            if (MessageConversationId.sameConversation(storedId, id)) {
              rowByExactId[id] = row;
              return row;
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
              existingHistoryClearedAtMs:
                  row['history_cleared_at'] as int? ?? 0,
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
            final fullRows = await txn.query(
              _table,
              where: 'owner_user_id = ? AND conversation_id = ?',
              whereArgs: [owner, storedId],
              limit: 1,
            );
            final existing =
                fullRows.isEmpty ? null : _conversationFromRow(fullRows.first);
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
        }
        if (writeCount > 0) {
          await batch.commit(noResult: true);
        } else {
          SqfliteLockProfileLog.event(
            'upsertBatch_skip_unchanged',
            extras: <String, Object?>{'count': conversations.length},
          );
        }
      },
    );
    return merged;
  }

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
    _readClearedAtMs.removeWhere((key, _) => key.startsWith('$owner|'));
    _readClearedLastMsgId.removeWhere((key, _) => key.startsWith('$owner|'));
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

  Future<void> clearSession() async {
    _upsertCoalesceGeneration++;
    _upsertCoalesceTimer?.cancel();
    _upsertCoalesceTimer = null;
    _upsertCoalesceById.clear();
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
    final owner = _resolveOwner(null);
    _memoryByOwner.clear();
    _memoryMetaByOwner.clear();
    _readClearedAtMs.clear();
    _readClearedLastMsgId.clear();
    _historyClearedAtMs.clear();
    if (_useMemoryOnly) {
      _webMetaHydratedOwners.clear();
      _webMetaPersistTimer?.cancel();
      _webMetaPersistTimer = null;
      _webMetaPersistOwner = null;
      if (owner.isNotEmpty) {
        unawaited(
          WebConversationMetaStore.instance.save(
            owner,
            const WebConversationMetaSnapshot(),
          ),
        );
      }
      return;
    }
    final db = _db;
    if (db == null) {
      return;
    }
    await db.delete(_table);
    await db.delete(_metaTable);
  }

  Future<V2TimConversation?> markConversationReadLocally(
    String conversationID,
  ) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final owner = _resolveOwner(null);
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
    final lastId = existing?.lastMessage?.msgID?.trim() ?? '';
    if (existing == null || lastId.isEmpty || !deletedMsgIDs.contains(lastId)) {
      // 被删的不是预览所指那条，预览无需修正。
      return null;
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
    final id = message?.msgID?.trim() ?? '';
    return id.isNotEmpty && _deletedPreviewMsgIds.contains(id);
  }

  void _mergeConversationLastMessage(
    V2TimConversation existing,
    V2TimConversation incoming, {
    required String owner,
    required String conversationId,
    int rowHistoryClearedAtMs = 0,
  }) {
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

    final preferred = GroupTipsMessageHelper.pickPreferredLastMessage(
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
  void _mergeConversationUnread({
    required V2TimConversation existing,
    required V2TimConversation incoming,
    required String owner,
    required String conversationId,
    required int readClearedAtMs,
  }) {
    final existingUnread = existing.unreadCount ?? 0;
    final incomingUnread = incoming.unreadCount ?? 0;

    if (ForegroundChatGuard.isActiveConversation(conversationId)) {
      incoming.unreadCount = 0;
      return;
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
            'incoming': incomingUnread,
            'readClearedAtMs': readClearedAtMs,
            'reason': 'sdk_zero',
          },
        );
      }
      return;
    }

    incoming.unreadCount = incomingUnread;
    _clearReadCleared(owner, conversationId);
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
        },
      );
    }
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
    _readClearedAtMs.clear();
    _readClearedLastMsgId.clear();
    _historyClearedAtMs.clear();
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
    final unread = row['unread_count'] as int?;
    final readClearedAt = row['read_cleared_at'] as int? ?? 0;
    if ((conversation.unreadCount ?? 0) == 0 && (unread ?? 0) > 0) {
      if (ConversationLocalStore.instance.isWithinReadGrace(readClearedAt)) {
        return;
      }
      conversation.unreadCount = unread;
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
    if (rowOrderKey > (conversation.orderkey ?? 0)) {
      conversation.orderkey = rowOrderKey;
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
    DisplayNameStore.instance.applyToConversation(conversation);
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
      DisplayNameStore.instance.setGroup(id, showName, notify: false);
      return;
    }
    final userId = conversation.userID?.trim() ?? '';
    if (userId.isNotEmpty) {
      DisplayNameStore.instance.setC2C(userId, showName, notify: false);
    }
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
    final payload = [
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
      readClearedAtMs,
      historyClearedAtMs,
      localDraftText,
      localDraftText.isEmpty ? 0 : localDraftUpdatedAtMs,
    ].join('\u{1f}');
    return sha256.convert(utf8.encode(payload)).toString();
  }

  static String _rawJsonFingerprint(String rawJson) =>
      sha256.convert(utf8.encode(rawJson)).toString();

  ConversationSyncMeta _syncMetaFromRow(Map<String, Object?> row) {
    return ConversationSyncMeta(
      nextSeq: row['next_seq']?.toString() ?? '0',
      haveMore: (row['have_more'] as int? ?? 1) != 0,
      hasSyncedOnce: (row['has_synced_once'] as int? ?? 0) != 0,
    );
  }

  /// 用自建置顶全量集合覆盖本地 `is_pinned`（先清后写，禁止逐会话 GET）。
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
        conversation.isPinned = matchesPinned(conversation.conversationID);
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
        await txn.rawUpdate(
          'UPDATE $_table SET is_pinned = 0 WHERE owner_user_id = ?',
          [owner],
        );
        if (pinned.isEmpty) {
          return;
        }
        final rows = await txn.query(
          _table,
          columns: <String>['conversation_id'],
          where: 'owner_user_id = ?',
          whereArgs: [owner],
        );
        final toPin = <String>[];
        for (final row in rows) {
          final id = row['conversation_id']?.toString().trim() ?? '';
          if (id.isNotEmpty && matchesPinned(id)) {
            toPin.add(id);
          }
        }
        for (final id in toPin) {
          await txn.update(
            _table,
            <String, Object?>{'is_pinned': 1},
            where: 'owner_user_id = ? AND conversation_id = ?',
            whereArgs: [owner, id],
          );
        }
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
  });

  final String nextSeq;
  final bool haveMore;
  final bool hasSyncedOnce;

  ConversationSyncMeta copyWith({
    String? nextSeq,
    bool? haveMore,
    bool? hasSyncedOnce,
  }) {
    return ConversationSyncMeta(
      nextSeq: nextSeq ?? this.nextSeq,
      haveMore: haveMore ?? this.haveMore,
      hasSyncedOnce: hasSyncedOnce ?? this.hasSyncedOnce,
    );
  }
}
