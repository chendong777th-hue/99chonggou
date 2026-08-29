import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/my_group_az_skeleton.dart';
import 'package:tencent_cloud_chat_demo/src/services/search_local/pinyin_index.dart';
import 'package:tencent_cloud_chat_demo/src/services/search_local/search_id_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lock_profile_log.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_conversation_visibility.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';

enum GroupStoreMutationKind { incremental, replaceAll, reset }

/// The only publication boundary for committed group metadata.
///
/// Database/cache mutation happens first. Consumers then receive one immutable
/// delta carrying the exact Store version that owns those snapshots.
class GroupStoreCommit {
  GroupStoreCommit({
    required this.ownerUserId,
    required this.version,
    required this.kind,
    Iterable<MeGroupRecord> upserted = const <MeGroupRecord>[],
    Iterable<String> deletedGroupIds = const <String>[],
  })  : upserted = List<MeGroupRecord>.unmodifiable(upserted),
        deletedGroupIds = List<String>.unmodifiable(deletedGroupIds);

  final String ownerUserId;
  final int version;
  final GroupStoreMutationKind kind;
  final List<MeGroupRecord> upserted;
  final List<String> deletedGroupIds;

  bool get isEmpty =>
      upserted.isEmpty &&
      deletedGroupIds.isEmpty &&
      kind != GroupStoreMutationKind.reset;
}

/// 自托管群列表本地库（按登录账号隔离）。
class GroupLocalStore {
  GroupLocalStore._();

  static final GroupLocalStore instance = GroupLocalStore._();

  static const _dbName = 'group_local_v1.db';
  static const _table = 'my_groups';
  static const _syncMetaTable = 'sync_meta';
  static const _searchTable = 'group_search_index';
  static const _deleteInChunkSize = 100;
  static const int defaultSearchPageSize = 80;

  Database? _db;
  final Map<String, List<MeGroupRecord>> _memoryByOwner = {};
  final Map<String, Map<String, MeGroupRecord>> _cacheByOwner = {};
  final Map<String, int> _metadataWriteGenerations = <String, int>{};
  int _metadataWriteSequence = 0;
  final Set<String> _fullyCachedOwners = <String>{};
  final Set<String> _indexTagBackfillDoneOwners = <String>{};
  bool _factoryReady = false;
  int _listDataRevision = 0;
  late final ValueNotifier<GroupStoreCommit> commitListenable =
      ValueNotifier<GroupStoreCommit>(
    GroupStoreCommit(
      ownerUserId: '',
      version: 0,
      kind: GroupStoreMutationKind.reset,
    ),
  );

  bool get _useMemoryOnly => kIsWeb;

  /// 「我的群聊」骨架缓存失效依据：写库/清会话后递增。
  int get listDataRevision => _listDataRevision;

  void _bumpListDataRevision() {
    _listDataRevision++;
  }

  void _publishCommit({
    required String ownerUserId,
    required GroupStoreMutationKind kind,
    Iterable<MeGroupRecord> upserted = const <MeGroupRecord>[],
    Iterable<String> deletedGroupIds = const <String>[],
  }) {
    final upsertedList = upserted.toList(growable: false);
    final deletedList = deletedGroupIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (kind != GroupStoreMutationKind.reset &&
        upsertedList.isEmpty &&
        deletedList.isEmpty) {
      return;
    }
    _bumpListDataRevision();
    commitListenable.value = GroupStoreCommit(
      ownerUserId: ownerUserId,
      version: _listDataRevision,
      kind: kind,
      upserted: upsertedList,
      deletedGroupIds: deletedList,
    );
  }

  String _metadataWriteKey(String owner, String groupId) {
    return '$owner|${groupEquivalenceKey(groupId)}';
  }

  /// Returns a monotonic token for an async metadata write. A caller may
  /// obtain it before starting a network request and pass it back to [upsert]
  /// so an older response cannot commit after a newer request.
  int beginMetadataWrite({
    required String ownerUserId,
    required String groupId,
  }) {
    final owner = _resolveOwner(ownerUserId);
    final id = groupId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return 0;
    }
    final generation = ++_metadataWriteSequence;
    _metadataWriteGenerations[_metadataWriteKey(owner, id)] = generation;
    return generation;
  }

  bool _isCurrentMetadataWrite({
    required String owner,
    required String groupId,
    required int generation,
  }) {
    return generation > 0 &&
        _metadataWriteGenerations[_metadataWriteKey(owner, groupId)] ==
            generation;
  }

  @visibleForTesting
  static bool acceptsMetadataRecord({
    required MeGroupRecord? existing,
    required MeGroupRecord incoming,
  }) {
    if (existing == null) {
      return true;
    }
    // A server timestamp is authoritative when both sides have one. A
    // missing timestamp remains compatible with the existing fallback path;
    // async request ordering is protected by the generation gate above.
    return existing.updatedAt <= 0 ||
        incoming.updatedAt <= 0 ||
        incoming.updatedAt >= existing.updatedAt;
  }

  /// 会话列表滚动等忙碌态：replaceAll 块间拉长 yield。
  bool Function()? isUiBusyForWrite;

  /// 等价键合并：同一群只保留最后一条；空 id 丢弃。
  static List<MeGroupRecord> dedupeGroupRecords(List<MeGroupRecord> records) {
    final byKey = <String, MeGroupRecord>{};
    final order = <String>[];
    for (final raw in records) {
      final id = raw.groupId.trim();
      if (id.isEmpty) {
        continue;
      }
      final key = groupEquivalenceKey(id);
      if (!byKey.containsKey(key)) {
        order.add(key);
      }
      byKey[key] = raw.copyWith(groupId: id);
    }
    return [for (final key in order) byKey[key]!];
  }

  /// existing 中应删除的库内 `group_id`：
  /// - 不在 normalized 等价集合内；或
  /// - 与 normalized 某条等价但字符串不同（清旧别名，避免双行）。
  @visibleForTesting
  static List<String> groupIdsToDelete({
    required List<MeGroupRecord> existing,
    required List<MeGroupRecord> normalized,
  }) {
    final newByKey = <String, String>{};
    for (final item in normalized) {
      final id = item.groupId.trim();
      if (id.isEmpty) {
        continue;
      }
      newByKey[groupEquivalenceKey(id)] = id;
    }
    final out = <String>[];
    final seen = <String>{};
    for (final item in existing) {
      final id = item.groupId.trim();
      if (id.isEmpty) {
        continue;
      }
      final key = groupEquivalenceKey(id);
      final keepId = newByKey[key];
      if (keepId == null || keepId != id) {
        if (seen.add(id)) {
          out.add(id);
        }
      }
    }
    return out;
  }

  static String groupEquivalenceKey(String groupId) {
    final token = ChatIdFormat.groupEquivalenceToken(groupId);
    if (token != null && token.isNotEmpty) {
      return token;
    }
    final canonical = ChatIdFormat.canonicalGroupStorageId(groupId);
    return canonical.isNotEmpty ? canonical : groupId.trim();
  }

  @visibleForTesting
  static bool samePersistedGroupRecord(
    MeGroupRecord existing,
    MeGroupRecord incoming,
  ) {
    return existing.groupId == incoming.groupId &&
        existing.groupType == incoming.groupType &&
        existing.groupName == incoming.groupName &&
        existing.displayAlias == incoming.displayAlias &&
        existing.avatarUrl == incoming.avatarUrl &&
        existing.avatarPreviewUrl == incoming.avatarPreviewUrl &&
        existing.avatarVersion == incoming.avatarVersion &&
        existing.notice == incoming.notice &&
        existing.memberCount == incoming.memberCount &&
        existing.myRole == incoming.myRole &&
        existing.myNameCard == incoming.myNameCard &&
        existing.joinedAt == incoming.joinedAt &&
        (incoming.updatedAt <= 0 || existing.updatedAt == incoming.updatedAt) &&
        existing.ownerUserId == incoming.ownerUserId &&
        existing.noticeUpdatedAt == incoming.noticeUpdatedAt &&
        existing.noticeUpdatedBy == incoming.noticeUpdatedBy &&
        existing.isAllMuted == incoming.isAllMuted &&
        existing.gameEnabled == incoming.gameEnabled;
  }

  @visibleForTesting
  static List<MeGroupRecord> groupRecordsToUpsert({
    required List<MeGroupRecord> existing,
    required List<MeGroupRecord> normalized,
  }) {
    final existingByKey = <String, MeGroupRecord>{
      for (final item in existing) groupEquivalenceKey(item.groupId): item,
    };
    return normalized.where((item) {
      final old = existingByKey[groupEquivalenceKey(item.groupId)];
      if (!acceptsMetadataRecord(existing: old, incoming: item)) {
        return false;
      }
      return old == null || !samePersistedGroupRecord(old, item);
    }).toList(growable: false);
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

  Future<Database> _openDb() async {
    final existing = SqfliteLifecycleGuard.beforeOpen(_db);
    if (existing != null) {
      return existing;
    }
    await _ensureDatabaseFactory();
    final basePath = await getDatabasesPath();
    final path = p.join(basePath, _dbName);
    _db = await openDatabase(
      path,
      version: 8,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            owner_user_id TEXT NOT NULL,
            group_id TEXT NOT NULL,
            group_type TEXT NOT NULL DEFAULT '',
            group_name TEXT NOT NULL DEFAULT '',
            display_alias TEXT NOT NULL DEFAULT '',
            avatar_url TEXT NOT NULL DEFAULT '',
            avatar_preview_url TEXT NOT NULL DEFAULT '',
            avatar_version INTEGER NOT NULL DEFAULT 0,
            notice TEXT NOT NULL DEFAULT '',
            member_count INTEGER NOT NULL DEFAULT 0,
            my_role INTEGER NOT NULL DEFAULT 200,
            my_name_card TEXT NOT NULL DEFAULT '',
            joined_at INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            owner_group_user_id TEXT NOT NULL DEFAULT '',
            notice_updated_at INTEGER NOT NULL DEFAULT 0,
            notice_updated_by TEXT NOT NULL DEFAULT '',
            is_all_muted INTEGER NOT NULL DEFAULT 0,
            game_enabled INTEGER NOT NULL DEFAULT 0,
            index_tag TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (owner_user_id, group_id)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_my_groups_owner ON $_table(owner_user_id)',
        );
        await db.execute(
          'CREATE INDEX idx_my_groups_owner_az ON $_table('
          'owner_user_id, index_tag, group_name, group_id)',
        );
        await db.execute('''
          CREATE TABLE $_syncMetaTable (
            owner_user_id TEXT PRIMARY KEY,
            last_full_sync_at_ms INTEGER NOT NULL DEFAULT 0,
            last_full_sync_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await _createGroupSearchIndexTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN is_all_muted INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN notice_updated_by TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN game_enabled INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN index_tag TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_my_groups_owner_az ON $_table('
            'owner_user_id, index_tag, group_name, group_id)',
          );
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_syncMetaTable (
              owner_user_id TEXT PRIMARY KEY,
              last_full_sync_at_ms INTEGER NOT NULL DEFAULT 0,
              last_full_sync_count INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 7) {
          await _createGroupSearchIndexTable(db);
          await _rebuildAllGroupSearchIndexes(db);
        }
        if (oldVersion < 8) {
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN avatar_preview_url TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN avatar_version INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
    return _db!;
  }

  Future<void> closeIfOpen() async {
    final db = _db;
    _db = null;
    await SqfliteLifecycleGuard.closeDatabase(db);
  }

  static Future<void> _createGroupSearchIndexTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_searchTable (
        owner_user_id TEXT NOT NULL,
        group_id TEXT NOT NULL,
        haystack TEXT NOT NULL DEFAULT '',
        PRIMARY KEY (owner_user_id, group_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_group_search_owner_id '
      'ON $_searchTable(owner_user_id, group_id)',
    );
  }

  static Future<void> _rebuildAllGroupSearchIndexes(DatabaseExecutor db) async {
    final owners = await db.rawQuery(
      'SELECT DISTINCT owner_user_id FROM $_table',
    );
    for (final row in owners) {
      final owner = row['owner_user_id']?.toString() ?? '';
      if (owner.isEmpty) {
        continue;
      }
      await _rebuildGroupSearchIndexForOwnerStatic(db, owner);
    }
  }

  static Future<void> _rebuildGroupSearchIndexForOwnerStatic(
    DatabaseExecutor db,
    String owner,
  ) async {
    await db.delete(
      _searchTable,
      where: 'owner_user_id = ?',
      whereArgs: [owner],
    );
    final rows = await db.query(
      _table,
      columns: const ['group_id', 'group_name', 'display_alias'],
      where: 'owner_user_id = ?',
      whereArgs: [owner],
    );
    final batch = db.batch();
    for (final row in rows) {
      final groupId = row['group_id']?.toString() ?? '';
      if (groupId.isEmpty) {
        continue;
      }
      batch.insert(
        _searchTable,
        <String, Object?>{
          'owner_user_id': owner,
          'group_id': groupId,
          'haystack': PinyinIndex.groupHaystack(
            groupId: groupId,
            groupName: row['group_name']?.toString() ?? '',
            displayAlias: row['display_alias']?.toString() ?? '',
          ),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  String currentOwnerUserId() {
    final override = debugOwnerUserIdOverride?.trim() ?? '';
    if (override.isNotEmpty) {
      return ChatIdFormat.rawUserUid(override);
    }
    try {
      return ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
    } catch (_) {
      return '';
    }
  }

  String _resolveOwner(String? ownerUserId) {
    final override = debugOwnerUserIdOverride?.trim() ?? '';
    if (override.isNotEmpty) {
      return ChatIdFormat.rawUserUid(override);
    }
    final explicit = ChatIdFormat.rawUserUid(ownerUserId);
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return currentOwnerUserId();
  }

  /// 同步读取内存中的群资料（供离线推送 ext 组装使用）。
  MeGroupRecord? readCached({required String groupId, String? ownerUserId}) {
    final owner = _resolveOwner(ownerUserId);
    final raw = groupId.trim();
    if (owner.isEmpty || raw.isEmpty) {
      return null;
    }
    final bucket = _cacheByOwner[owner];
    if (bucket == null || bucket.isEmpty) {
      return null;
    }
    final normalized = ChatIdFormat.normalizeGroupId(raw);
    final apiId = ChatIdFormat.apiGroupId(raw);
    for (final key in <String>{raw, apiId, normalized}) {
      if (key.isEmpty) {
        continue;
      }
      final hit = bucket[key];
      if (hit != null) {
        return hit;
      }
    }
    for (final entry in bucket.entries) {
      final record = entry.value;
      if (ChatIdFormat.groupIdsEquivalent(entry.key, raw) ||
          (normalized.isNotEmpty &&
              ChatIdFormat.groupIdsEquivalent(entry.key, normalized))) {
        return record;
      }
      // displayAlias（如 @m2…）与错误加成的 @TGS#_@TGS#m2… 对齐到真实 groupId。
      final aliasApi = ChatIdFormat.apiGroupId(record.displayAlias);
      if (apiId.isNotEmpty && aliasApi.isNotEmpty && aliasApi == apiId) {
        return record;
      }
    }
    return null;
  }

  /// 解析 IM SDK 可用的群 ID：优先本地 [MeGroupRecord.groupId]（含 `@TGS#_mc…`）。
  ///
  /// 会话里常见把 `displayAlias` 短码加成成 `@TGS#_@TGS#m2…`，IM 侧 10010/6017。
  Future<String> resolveImGroupId(
    String? input, {
    String? ownerUserId,
  }) async {
    final raw = input?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }
    final cached = readCached(groupId: raw, ownerUserId: ownerUserId);
    if (cached != null) {
      final fromCache = ChatIdFormat.imGroupIdFromRecord(
        groupId: cached.groupId,
        displayAlias: cached.displayAlias,
      );
      if (fromCache.isNotEmpty) {
        return fromCache;
      }
    }
    final record = await read(groupId: raw, ownerUserId: ownerUserId);
    if (record != null) {
      final fromRead = ChatIdFormat.imGroupIdFromRecord(
        groupId: record.groupId,
        displayAlias: record.displayAlias,
      );
      if (fromRead.isNotEmpty) {
        return fromRead;
      }
    }
    // 全表按 displayAlias 再扫一遍（read 只按 group_id 候选，别名错位时会漏）。
    final apiId = ChatIdFormat.apiGroupId(raw);
    if (apiId.isNotEmpty) {
      final all = await readAll(ownerUserId: ownerUserId, caller: 'resolveIm');
      for (final item in all) {
        final aliasApi = ChatIdFormat.apiGroupId(item.displayAlias);
        if (aliasApi.isNotEmpty && aliasApi == apiId) {
          final resolved = ChatIdFormat.imGroupIdFromRecord(
            groupId: item.groupId,
            displayAlias: item.displayAlias,
          );
          if (resolved.isNotEmpty) {
            return resolved;
          }
        }
      }
    }
    return ChatIdFormat.normalizeGroupId(raw);
  }

  Future<List<MeGroupRecord>> readAll({
    String? ownerUserId,
    String caller = 'unspecified',
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return const <MeGroupRecord>[];
    }
    if (_fullyCachedOwners.contains(owner)) {
      return List<MeGroupRecord>.from(
        _cacheByOwner[owner]?.values ?? const <MeGroupRecord>[],
        growable: false,
      );
    }
    if (_useMemoryOnly) {
      final records = List<MeGroupRecord>.from(
        _memoryByOwner[owner] ?? const [],
      );
      _cacheRecords(owner, records);
      _fullyCachedOwners.add(owner);
      return records;
    }
    final started = DateTime.now().millisecondsSinceEpoch;
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ?',
      whereArgs: [owner],
      orderBy: 'joined_at DESC, group_id ASC',
    );
    final records = rows.map(_recordFromRow).toList(growable: false);
    _cacheRecords(owner, records);
    _fullyCachedOwners.add(owner);
    SqfliteLockProfileLog.event(
      'readAll',
      extras: <String, Object?>{
        'db': _dbName,
        'caller': caller,
        'rows': records.length,
        'costMs': DateTime.now().millisecondsSinceEpoch - started,
      },
    );
    return records;
  }

  Future<MeGroupRecord?> read({
    required String groupId,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final id = groupId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return null;
    }
    final cached = readCached(groupId: id, ownerUserId: owner);
    if (cached != null) {
      return cached;
    }
    if (_fullyCachedOwners.contains(owner) || _useMemoryOnly) {
      return null;
    }

    final candidates = <String>{
      id,
      ChatIdFormat.apiGroupId(id),
      ChatIdFormat.normalizeGroupId(id),
      ChatIdFormat.canonicalGroupStorageId(id),
      ...ChatIdFormat.groupIdLookupCandidates(id),
    }..removeWhere((candidate) => candidate.trim().isEmpty);
    if (candidates.isEmpty) {
      return null;
    }
    final db = await _openDb();
    final placeholders = List.filled(candidates.length, '?').join(',');
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND group_id IN ($placeholders)',
      whereArgs: <Object?>[owner, ...candidates],
    );
    for (final row in rows) {
      final record = _recordFromRow(row);
      if (!ChatIdFormat.groupIdsEquivalent(record.groupId, id)) {
        continue;
      }
      final bucket = _cacheByOwner.putIfAbsent(
        owner,
        () => <String, MeGroupRecord>{},
      );
      bucket[record.groupId] = record;
      return record;
    }
    // group_id 对不上时，用 display_alias 短码对齐（会话误用 @TGS#_@TGS#m2…）。
    final apiId = ChatIdFormat.apiGroupId(id);
    if (apiId.isNotEmpty) {
      final aliasRows = await db.query(
        _table,
        where: 'owner_user_id = ? AND display_alias IN (?, ?)',
        whereArgs: <Object?>[owner, apiId, '@$apiId'],
      );
      for (final row in aliasRows) {
        final record = _recordFromRow(row);
        final aliasApi = ChatIdFormat.apiGroupId(record.displayAlias);
        if (aliasApi.isNotEmpty && aliasApi == apiId) {
          final bucket = _cacheByOwner.putIfAbsent(
            owner,
            () => <String, MeGroupRecord>{},
          );
          bucket[record.groupId] = record;
          return record;
        }
      }
    }
    return null;
  }

  Future<List<V2TimGroupInfo>> loadAsV2TimGroupInfos({
    String? ownerUserId,
  }) async {
    final records = await readAll(ownerUserId: ownerUserId);
    return records.map((e) => e.toV2TimGroupInfo()).toList(growable: false);
  }

  Future<List<MeGroupRecord>> readByIds({
    required List<String> groupIds,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final ids = groupIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (owner.isEmpty || ids.isEmpty) {
      return const [];
    }
    if (_useMemoryOnly) {
      final map = <String, MeGroupRecord>{
        for (final item in _memoryByOwner[owner] ?? const <MeGroupRecord>[])
          item.groupId: item,
      };
      return [
        for (final id in ids)
          if (map[id] != null) map[id]!,
      ];
    }
    final db = await _openDb();
    final out = <MeGroupRecord>[];
    const chunk = 200;
    for (var i = 0; i < ids.length; i += chunk) {
      final end = i + chunk > ids.length ? ids.length : i + chunk;
      final slice = ids.sublist(i, end);
      final placeholders = List.filled(slice.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT * FROM $_table WHERE owner_user_id = ? '
        'AND group_id IN ($placeholders)',
        <Object?>[owner, ...slice],
      );
      final byId = <String, MeGroupRecord>{};
      for (final row in rows) {
        final record = _recordFromRow(row);
        byId[record.groupId] = record;
      }
      for (final id in slice) {
        final hit = byId[id];
        if (hit != null) {
          out.add(hit);
        }
      }
    }
    return out;
  }

  Future<List<V2TimGroupInfo>> loadAsV2TimGroupInfosByIds({
    required List<String> groupIds,
    String? ownerUserId,
  }) async {
    final records = await readByIds(
      groupIds: groupIds,
      ownerUserId: ownerUserId,
    );
    return records.map((e) => e.toV2TimGroupInfo()).toList(growable: false);
  }

  /// 本地群关键字搜索：返回 ID 页（cursor = 上一页最后 group_id）。
  Future<SearchIdPage> searchGroupIds({
    required String keyword,
    String? ownerUserId,
    int limit = defaultSearchPageSize,
    String? cursor,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final needle = keyword.trim().toLowerCase();
    final pageSize = limit <= 0 ? defaultSearchPageSize : limit;
    if (owner.isEmpty || needle.isEmpty) {
      return SearchIdPage.empty;
    }
    if (_useMemoryOnly) {
      final all = _memoryByOwner[owner] ?? const <MeGroupRecord>[];
      final matched = <String>[];
      for (final item in all) {
        final id = item.groupId.trim();
        if (id.isEmpty) {
          continue;
        }
        if (cursor != null &&
            cursor.trim().isNotEmpty &&
            id.compareTo(cursor.trim()) <= 0) {
          continue;
        }
        final haystack = PinyinIndex.groupHaystack(
          groupId: id,
          groupName: item.groupName,
          displayAlias: item.displayAlias,
        );
        if (!haystack.contains(needle)) {
          continue;
        }
        matched.add(id);
      }
      matched.sort();
      final hasMore = matched.length > pageSize;
      final pageIds =
          hasMore ? matched.sublist(0, pageSize) : List<String>.from(matched);
      return SearchIdPage(
        ids: pageIds,
        nextCursor: pageIds.isEmpty ? null : pageIds.last,
        hasMore: hasMore,
      );
    }

    final db = await _openDb();
    await _createGroupSearchIndexTable(db);
    final args = <Object?>[owner, '%$needle%'];
    final cursorClause =
        (cursor != null && cursor.trim().isNotEmpty) ? ' AND group_id > ?' : '';
    if (cursorClause.isNotEmpty) {
      args.add(cursor!.trim());
    }
    args.add(pageSize + 1);
    final rows = await db.rawQuery(
      'SELECT group_id FROM $_searchTable '
      'WHERE owner_user_id = ? AND haystack LIKE ?$cursorClause '
      'ORDER BY group_id ASC LIMIT ?',
      args,
    );
    final ids = <String>[
      for (final row in rows)
        if ((row['group_id']?.toString() ?? '').isNotEmpty)
          row['group_id']!.toString(),
    ];
    final hasMore = ids.length > pageSize;
    final pageIds = hasMore ? ids.sublist(0, pageSize) : List<String>.from(ids);
    return SearchIdPage(
      ids: pageIds,
      nextCursor: pageIds.isEmpty ? null : pageIds.last,
      hasMore: hasMore,
    );
  }

  Future<void> _upsertGroupSearchRow(
    DatabaseExecutor db,
    String owner,
    MeGroupRecord record,
  ) async {
    final id = record.groupId.trim();
    if (id.isEmpty) {
      return;
    }
    await db.insert(
      _searchTable,
      <String, Object?>{
        'owner_user_id': owner,
        'group_id': id,
        'haystack': PinyinIndex.groupHaystack(
          groupId: id,
          groupName: record.groupName,
          displayAlias: record.displayAlias,
        ),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _deleteGroupSearchRows(
    DatabaseExecutor db,
    String owner,
    Iterable<String> groupIds,
  ) async {
    final ids = groupIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      _searchTable,
      where: 'owner_user_id = ? AND group_id IN ($placeholders)',
      whereArgs: <Object?>[owner, ...ids],
    );
  }

  Future<int> countGroups({String? ownerUserId}) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return 0;
    }
    if (_useMemoryOnly) {
      return (_memoryByOwner[owner] ?? const <MeGroupRecord>[]).length;
    }
    if (_fullyCachedOwners.contains(owner)) {
      return _cacheByOwner[owner]?.length ?? 0;
    }
    final db = await _openDb();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE owner_user_id = ?',
      <Object?>[owner],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// 当前 owner 是否已有全表内存缓存（syncFull 刚 readAll / replaceAll 后为 true）。
  bool isOwnerFullyCached({String? ownerUserId}) {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return false;
    }
    if (_useMemoryOnly) {
      return _memoryByOwner.containsKey(owner);
    }
    return _fullyCachedOwners.contains(owner);
  }

  /// 最近一次成功全量 sync 的 meta；无记录时 at/count 为 0。
  Future<({int atMs, int count})> readFullSyncMeta({
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return (atMs: 0, count: 0);
    }
    if (_useMemoryOnly) {
      final cached = _memoryFullSyncMeta[owner];
      return cached ?? (atMs: 0, count: 0);
    }
    final db = await _openDb();
    final rows = await db.query(
      _syncMetaTable,
      columns: const <String>['last_full_sync_at_ms', 'last_full_sync_count'],
      where: 'owner_user_id = ?',
      whereArgs: <Object?>[owner],
      limit: 1,
    );
    if (rows.isEmpty) {
      return (atMs: 0, count: 0);
    }
    final row = rows.first;
    return (
      atMs: (row['last_full_sync_at_ms'] as int?) ?? 0,
      count: (row['last_full_sync_count'] as int?) ?? 0,
    );
  }

  Future<void> writeFullSyncMeta({
    required int count,
    String? ownerUserId,
    int? atMs,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    final stamp = atMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      _memoryFullSyncMeta[owner] = (atMs: stamp, count: count);
      return;
    }
    final db = await _openDb();
    await db.insert(
      _syncMetaTable,
      <String, Object?>{
        'owner_user_id': owner,
        'last_full_sync_at_ms': stamp,
        'last_full_sync_count': count,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  final Map<String, ({int atMs, int count})> _memoryFullSyncMeta =
      <String, ({int atMs, int count})>{};

  /// AZ 轻量骨架：按 index_tag + 群名排序；不转全量业务对象、不现场算拼音。
  Future<List<MyGroupAzSkeleton>> readAzSkeleton({
    String? ownerUserId,
    String keyword = '',
    int? limit,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return const [];
    }
    final needle = keyword.trim().toLowerCase();
    final cap = limit == null ? null : (limit <= 0 ? 0 : limit);

    if (_useMemoryOnly || _fullyCachedOwners.contains(owner)) {
      final source = _useMemoryOnly
          ? List<MeGroupRecord>.from(_memoryByOwner[owner] ?? const [])
          : List<MeGroupRecord>.from(
              _cacheByOwner[owner]?.values ?? const <MeGroupRecord>[],
            );
      final out = <MyGroupAzSkeleton>[];
      for (final record in source) {
        final skeleton = _skeletonFromRecord(record);
        if (needle.isNotEmpty && !_skeletonMatchesKeyword(skeleton, needle)) {
          continue;
        }
        out.add(skeleton);
      }
      out.sort(_compareAzSkeleton);
      if (cap != null) {
        if (cap == 0) {
          return const [];
        }
        if (out.length > cap) {
          return out.sublist(0, cap);
        }
      }
      return out;
    }

    final db = await _openDb();
    final where = StringBuffer('owner_user_id = ?');
    final args = <Object?>[owner];
    if (needle.isNotEmpty) {
      where.write(
        ' AND (LOWER(group_name) LIKE ? OR LOWER(group_id) LIKE ? '
        'OR LOWER(display_alias) LIKE ?)',
      );
      final like = '%$needle%';
      args.addAll(<Object?>[like, like, like]);
    }
    final rows = await db.query(
      _table,
      columns: const <String>[
        'group_id',
        'group_type',
        'group_name',
        'avatar_url',
        'member_count',
        'my_role',
        'index_tag',
      ],
      where: where.toString(),
      whereArgs: args,
      orderBy: 'index_tag ASC, group_name ASC, group_id ASC',
      limit: cap,
    );
    final out = <MyGroupAzSkeleton>[];
    for (final row in rows) {
      final skeleton = _skeletonFromRow(row);
      if (skeleton.groupId.isEmpty) {
        continue;
      }
      // 缺 tag 的老行：临时补算，避免 AZ 全进 #；backfill 会写回。
      if (skeleton.indexTag.isEmpty) {
        out.add(
          MyGroupAzSkeleton(
            groupId: skeleton.groupId,
            groupType: skeleton.groupType,
            groupName: skeleton.groupName,
            avatarUrl: skeleton.avatarUrl,
            memberCount: skeleton.memberCount,
            myRole: skeleton.myRole,
            indexTag: MyGroupAzSkeleton.computeIndexTag(
              groupName: skeleton.groupName,
              groupId: skeleton.groupId,
            ),
          ),
        );
      } else {
        out.add(skeleton);
      }
    }
    return out;
  }

  /// 为缺 index_tag 的行分块补齐（不阻塞首帧时可 await）。
  Future<void> ensureIndexTagsBackfilled({String? ownerUserId}) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || _useMemoryOnly) {
      return;
    }
    if (_indexTagBackfillDoneOwners.contains(owner)) {
      return;
    }
    final db = await _openDb();
    final chunk = GroupLocalPerfFlags.myGroupListBackfillChunkSize <= 0
        ? 200
        : GroupLocalPerfFlags.myGroupListBackfillChunkSize;
    while (true) {
      final rows = await db.query(
        _table,
        columns: const <String>['group_id', 'group_name'],
        where: "owner_user_id = ? AND (index_tag IS NULL OR index_tag = '')",
        whereArgs: <Object?>[owner],
        limit: chunk,
      );
      if (rows.isEmpty) {
        break;
      }
      final batch = db.batch();
      for (final row in rows) {
        final groupId = row['group_id']?.toString() ?? '';
        if (groupId.isEmpty) {
          continue;
        }
        final groupName = row['group_name']?.toString() ?? '';
        final tag = MyGroupAzSkeleton.computeIndexTag(
          groupName: groupName,
          groupId: groupId,
        );
        batch.update(
          _table,
          <String, Object?>{'index_tag': tag},
          where: 'owner_user_id = ? AND group_id = ?',
          whereArgs: <Object?>[owner, groupId],
        );
      }
      await batch.commit(noResult: true);
      if (rows.length < chunk) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    _indexTagBackfillDoneOwners.add(owner);
  }

  /// 测试专用：清空某账号 index_tag，并允许再次 backfill。
  @visibleForTesting
  Future<void> debugClearIndexTagsForOwner(String ownerUserId) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || _useMemoryOnly) {
      return;
    }
    final db = await _openDb();
    await db.update(
      _table,
      <String, Object?>{'index_tag': ''},
      where: 'owner_user_id = ?',
      whereArgs: <Object?>[owner],
    );
    _indexTagBackfillDoneOwners.remove(owner);
  }

  /// 测试专用：直接读 SQL 中的 index_tag。
  @visibleForTesting
  Future<List<Map<String, Object?>>> debugReadIndexTagRows(
    String ownerUserId,
  ) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty || _useMemoryOnly) {
      return const [];
    }
    final db = await _openDb();
    return db.query(
      _table,
      columns: const <String>['group_id', 'group_name', 'index_tag'],
      where: 'owner_user_id = ?',
      whereArgs: <Object?>[owner],
    );
  }

  static int _compareAzSkeleton(MyGroupAzSkeleton a, MyGroupAzSkeleton b) {
    final tag = a.indexTag.compareTo(b.indexTag);
    if (tag != 0) {
      return tag;
    }
    final name = a.groupName.compareTo(b.groupName);
    if (name != 0) {
      return name;
    }
    return a.groupId.compareTo(b.groupId);
  }

  static bool _skeletonMatchesKeyword(
    MyGroupAzSkeleton skeleton,
    String needleLower,
  ) {
    return skeleton.groupName.toLowerCase().contains(needleLower) ||
        skeleton.groupId.toLowerCase().contains(needleLower) ||
        skeleton.showName.toLowerCase().contains(needleLower);
  }

  MyGroupAzSkeleton _skeletonFromRecord(MeGroupRecord record) {
    return MyGroupAzSkeleton(
      groupId: record.groupId,
      groupType: record.groupType,
      groupName: record.groupName,
      avatarUrl: record.avatarUrl,
      memberCount: record.memberCount,
      myRole: record.myRole,
      indexTag: MyGroupAzSkeleton.computeIndexTag(
        groupName: record.groupName,
        groupId: record.groupId,
      ),
    );
  }

  MyGroupAzSkeleton _skeletonFromRow(Map<String, Object?> row) {
    return MyGroupAzSkeleton(
      groupId: row['group_id']?.toString() ?? '',
      groupType: row['group_type']?.toString() ?? '',
      groupName: row['group_name']?.toString() ?? '',
      avatarUrl: row['avatar_url']?.toString() ?? '',
      memberCount: (row['member_count'] as int?) ?? 0,
      myRole: (row['my_role'] as int?) ?? 200,
      indexTag: row['index_tag']?.toString() ?? '',
    );
  }

  /// [existingSnapshot]：调用方（如 syncFull）刚读过的快照，避免二次 `readAll`
  /// 全表过 Channel。仅允许同一次同步调用内传入，禁止跨 await 复用过期列表。
  Future<void> replaceAll({
    required String ownerUserId,
    required List<MeGroupRecord> records,
    List<MeGroupRecord>? existingSnapshot,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final admissible = records
        .where((item) => !isForbiddenGroupStorageId(item.groupId))
        .toList(growable: false);
    final rejected = records.length - admissible.length;
    if (rejected > 0) {
      debugPrint(
        '[GroupIdGate] replaceAll_filter_forbidden count=$rejected',
      );
      SqfliteLockProfileLog.event(
        'group_replaceAll_filter_forbidden',
        extras: <String, Object?>{
          'db': _dbName,
          'rejected': rejected,
        },
      );
    }
    final normalized = dedupeGroupRecords(admissible);
    if (owner.isEmpty) {
      return;
    }
    final writeGenerations = <String, int>{
      for (final item in normalized)
        groupEquivalenceKey(item.groupId): beginMetadataWrite(
          ownerUserId: owner,
          groupId: item.groupId,
        ),
    };
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      final existing = List<MeGroupRecord>.from(
        _memoryByOwner[owner] ?? const <MeGroupRecord>[],
      );
      final existingByKey = <String, MeGroupRecord>{
        for (final item in existing) groupEquivalenceKey(item.groupId): item,
      };
      final guarded = normalized.map((item) {
        final old = existingByKey[groupEquivalenceKey(item.groupId)];
        return acceptsMetadataRecord(existing: old, incoming: item) ||
                old == null
            ? item
            : old;
      }).toList(growable: false);
      _memoryByOwner[owner] = guarded;
      _cacheRecords(owner, guarded);
      _fullyCachedOwners.add(owner);
      _publishCommit(
        ownerUserId: owner,
        kind: GroupStoreMutationKind.replaceAll,
        upserted: groupRecordsToUpsert(
          existing: existing,
          normalized: guarded,
        ),
        deletedGroupIds: groupIdsToDelete(
          existing: existing,
          normalized: guarded,
        ),
      );
      return;
    }

    final readAllSkipped = existingSnapshot != null;
    SqfliteLockProfileLog.event(
      'replaceAll_begin',
      extras: <String, Object?>{
        'db': _dbName,
        'owner': owner,
        'count': normalized.length,
        'readAll_skipped': readAllSkipped ? 1 : 0,
      },
    );

    final existing = existingSnapshot ?? await readAll(ownerUserId: owner);
    final rawToDelete = groupIdsToDelete(
      existing: existing,
      normalized: normalized,
    );
    for (final id in rawToDelete) {
      writeGenerations.putIfAbsent(
        groupEquivalenceKey(id),
        () => beginMetadataWrite(ownerUserId: owner, groupId: id),
      );
    }
    final toDelete = rawToDelete.where((id) {
      final generation = writeGenerations[groupEquivalenceKey(id)] ?? 0;
      return _isCurrentMetadataWrite(
        owner: owner,
        groupId: id,
        generation: generation,
      );
    }).toList(growable: false);
    final rawToUpsert = groupRecordsToUpsert(
      existing: existing,
      normalized: normalized,
    );
    final toUpsert = rawToUpsert.where((item) {
      final generation =
          writeGenerations[groupEquivalenceKey(item.groupId)] ?? 0;
      return _isCurrentMetadataWrite(
        owner: owner,
        groupId: item.groupId,
        generation: generation,
      );
    }).toList(growable: false);
    final db = await _openDb();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final toUpsertIds = toUpsert.map((item) => item.groupId).toSet();
    final existingByKey = <String, MeGroupRecord>{
      for (final item in existing) groupEquivalenceKey(item.groupId): item,
    };
    final cachedBase = <String, MeGroupRecord>{
      for (final item in (_cacheByOwner[owner]?.values ?? existing))
        groupEquivalenceKey(item.groupId): item,
    };
    final cachedRecords = normalized.map((item) {
      final generation =
          writeGenerations[groupEquivalenceKey(item.groupId)] ?? 0;
      if (!_isCurrentMetadataWrite(
        owner: owner,
        groupId: item.groupId,
        generation: generation,
      )) {
        return cachedBase[groupEquivalenceKey(item.groupId)] ??
            existingByKey[groupEquivalenceKey(item.groupId)] ??
            item;
      }
      final old = existingByKey[groupEquivalenceKey(item.groupId)];
      if (!acceptsMetadataRecord(existing: old, incoming: item) &&
          old != null) {
        // Keep the database and the in-memory UI cache on the same
        // authoritative record when an old response is rejected.
        return old;
      }
      if (item.updatedAt > 0) {
        return item;
      }
      final updatedAt =
          toUpsertIds.contains(item.groupId) ? now : (old?.updatedAt ?? now);
      return item.copyWith(updatedAt: updatedAt);
    }).toList(growable: false);
    final resolvedToUpsert = cachedRecords
        .where((item) => toUpsertIds.contains(item.groupId))
        .toList(growable: false);
    final coldStart = isColdStartReplaceAll(
      existingCount: existing.length,
      upsertCount: resolvedToUpsert.length,
      normalizedCount: normalized.length,
    );
    final writeChunkSize = coldStart
        ? GroupLocalPerfFlags.coldStartWriteChunkSize
        : GroupLocalPerfFlags.syncFullWriteChunkSize;
    final baseYield = coldStart
        ? GroupLocalPerfFlags.coldStartWriteChunkYield
        : GroupLocalPerfFlags.syncFullWriteChunkYield;
    final writeYield = (isUiBusyForWrite?.call() ?? false)
        ? GroupLocalPerfFlags.syncFullWriteChunkYieldWhileScrolling
        : baseYield;
    final chunkSize =
        writeChunkSize <= 0 ? resolvedToUpsert.length : writeChunkSize;

    for (var offset = 0;
        offset < toDelete.length;
        offset += _deleteInChunkSize) {
      final end = offset + _deleteInChunkSize > toDelete.length
          ? toDelete.length
          : offset + _deleteInChunkSize;
      final chunk = toDelete.sublist(offset, end);
      await profiledTransaction<void>(
        db,
        dbTag: _dbName,
        op: 'replaceAll_del_chunk',
        extras: <String, Object?>{'chunk': chunk.length},
        action: (txn) async {
          final batch = txn.batch();
          for (final id in chunk) {
            batch.delete(
              _table,
              where: 'owner_user_id = ? AND group_id = ?',
              whereArgs: [owner, id],
            );
          }
          await batch.commit(noResult: true);
        },
      );
      if (end < toDelete.length && writeYield > Duration.zero) {
        await Future<void>.delayed(writeYield);
      }
    }

    if (resolvedToUpsert.isEmpty) {
      _cacheRecords(owner, cachedRecords);
      _fullyCachedOwners.add(owner);
      _publishCommit(
        ownerUserId: owner,
        kind: GroupStoreMutationKind.replaceAll,
        deletedGroupIds: toDelete,
      );
      SqfliteLockProfileLog.event(
        'replaceAll_end',
        extras: <String, Object?>{
          'db': _dbName,
          'owner': owner,
          'deleted': toDelete.length,
          'upserted': 0,
          'unchanged': normalized.length,
          'readAll_skipped': readAllSkipped ? 1 : 0,
          'cold_start': coldStart ? 1 : 0,
        },
      );
      return;
    }

    final effectiveChunk = chunkSize <= 0 ? resolvedToUpsert.length : chunkSize;
    for (var offset = 0;
        offset < resolvedToUpsert.length;
        offset += effectiveChunk) {
      final end = offset + effectiveChunk > resolvedToUpsert.length
          ? resolvedToUpsert.length
          : offset + effectiveChunk;
      final chunk = resolvedToUpsert.sublist(offset, end);
      await profiledTransaction<void>(
        db,
        dbTag: _dbName,
        op: 'replaceAll_upsert_chunk',
        extras: <String, Object?>{
          'chunk': chunk.length,
          'cold_start': coldStart ? 1 : 0,
        },
        action: (txn) async {
          final batch = txn.batch();
          for (final item in chunk) {
            batch.insert(
              _table,
              _rowFromRecord(owner, item, now),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        },
      );
      if (end < resolvedToUpsert.length && writeYield > Duration.zero) {
        await Future<void>.delayed(writeYield);
      }
    }

    _cacheRecords(owner, cachedRecords);
    _fullyCachedOwners.add(owner);
    _publishCommit(
      ownerUserId: owner,
      kind: GroupStoreMutationKind.replaceAll,
      upserted: resolvedToUpsert,
      deletedGroupIds: toDelete,
    );
    try {
      await _rebuildGroupSearchIndexForOwnerStatic(db, owner);
    } catch (e) {
      debugPrint('[GroupLocalStore] rebuild search index failed: $e');
    }
    SqfliteLockProfileLog.event(
      'replaceAll_end',
      extras: <String, Object?>{
        'db': _dbName,
        'owner': owner,
        'deleted': toDelete.length,
        'upserted': resolvedToUpsert.length,
        'unchanged': normalized.length - resolvedToUpsert.length,
        'readAll_skipped': readAllSkipped ? 1 : 0,
        'cold_start': coldStart ? 1 : 0,
        'chunk': effectiveChunk,
      },
    );
  }

  /// 本地无数据，或本轮几乎整表 upsert 时走冷启动写节奏。
  @visibleForTesting
  static bool isColdStartReplaceAll({
    required int existingCount,
    required int upsertCount,
    required int normalizedCount,
  }) {
    if (upsertCount <= 0) {
      return false;
    }
    if (existingCount <= 0) {
      return true;
    }
    if (normalizedCount <= 0) {
      return false;
    }
    return upsertCount / normalizedCount >=
        GroupLocalPerfFlags.coldStartUpsertRatio;
  }

  Future<bool> upsert({
    required String ownerUserId,
    required MeGroupRecord record,
    int? writeGeneration,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final id = record.groupId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return false;
    }
    if (isForbiddenGroupStorageId(id)) {
      debugPrint(
        '[GroupIdGate] group_upsert_reject_forbidden_id groupId=$id',
      );
      SqfliteLockProfileLog.event(
        'group_upsert_reject_forbidden_id',
        extras: <String, Object?>{
          'db': _dbName,
          'groupId': id,
        },
      );
      return false;
    }
    final generation =
        writeGeneration ?? beginMetadataWrite(ownerUserId: owner, groupId: id);
    if (!_isCurrentMetadataWrite(
      owner: owner,
      groupId: id,
      generation: generation,
    )) {
      return false;
    }
    final existing = await read(groupId: id, ownerUserId: owner);
    if (!acceptsMetadataRecord(existing: existing, incoming: record)) {
      return false;
    }
    if (existing != null && samePersistedGroupRecord(existing, record)) {
      return false;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final storedRecord =
        record.updatedAt > 0 ? record : record.copyWith(updatedAt: now);
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      final list = List<MeGroupRecord>.from(_memoryByOwner[owner] ?? const []);
      list.removeWhere((e) => e.groupId == id);
      list.add(storedRecord);
      list.sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
      _memoryByOwner[owner] = list;
      _cacheRecords(owner, list);
      _publishCommit(
        ownerUserId: owner,
        kind: GroupStoreMutationKind.incremental,
        upserted: <MeGroupRecord>[storedRecord],
      );
      return true;
    }
    final db = await _openDb();
    if (!_isCurrentMetadataWrite(
      owner: owner,
      groupId: id,
      generation: generation,
    )) {
      return false;
    }
    await db.insert(
      _table,
      _rowFromRecord(owner, storedRecord, now),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    try {
      await _createGroupSearchIndexTable(db);
      await _upsertGroupSearchRow(db, owner, storedRecord);
    } catch (_) {}
    final cached = List<MeGroupRecord>.from(
      _cacheByOwner[owner]?.values ?? <MeGroupRecord>[],
    );
    cached.removeWhere((e) => ChatIdFormat.groupIdsEquivalent(e.groupId, id));
    cached.add(storedRecord);
    cached.sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    _cacheRecords(owner, cached);
    _publishCommit(
      ownerUserId: owner,
      kind: GroupStoreMutationKind.incremental,
      upserted: <MeGroupRecord>[storedRecord],
    );
    return true;
  }

  Future<void> delete({
    required String ownerUserId,
    required String groupId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final id = groupId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      final list = List<MeGroupRecord>.from(_memoryByOwner[owner] ?? const []);
      final deleted = list
          .where((e) => ChatIdFormat.groupIdsEquivalent(e.groupId, id))
          .map((e) => e.groupId)
          .toList(growable: false);
      list.removeWhere((e) => ChatIdFormat.groupIdsEquivalent(e.groupId, id));
      _memoryByOwner[owner] = list;
      _cacheRecords(owner, list);
      _publishCommit(
        ownerUserId: owner,
        kind: GroupStoreMutationKind.incremental,
        deletedGroupIds: deleted,
      );
      return;
    }
    final storedIds = (await readAll(ownerUserId: owner))
        .where((item) => ChatIdFormat.groupIdsEquivalent(item.groupId, id))
        .map((item) => item.groupId)
        .toSet();
    final hadStoredRows = storedIds.isNotEmpty;
    if (!hadStoredRows) {
      storedIds.add(id);
    }
    final db = await _openDb();
    final placeholders = List.filled(storedIds.length, '?').join(',');
    await db.delete(
      _table,
      where: 'owner_user_id = ? AND group_id IN ($placeholders)',
      whereArgs: <Object?>[owner, ...storedIds],
    );
    try {
      await _deleteGroupSearchRows(db, owner, storedIds);
    } catch (_) {}
    final cached = Map<String, MeGroupRecord>.from(
      _cacheByOwner[owner] ?? const <String, MeGroupRecord>{},
    );
    cached.removeWhere(
      (key, _) => ChatIdFormat.groupIdsEquivalent(key, id),
    );
    _cacheByOwner[owner] = cached;
    if (hadStoredRows) {
      _publishCommit(
        ownerUserId: owner,
        kind: GroupStoreMutationKind.incremental,
        deletedGroupIds: storedIds,
      );
    }
  }

  Future<void> patch({
    required String ownerUserId,
    required String groupId,
    required MeGroupRecord Function(MeGroupRecord current) transform,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final id = groupId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    final current = await read(groupId: id, ownerUserId: owner);
    if (current == null) {
      return;
    }
    await upsert(ownerUserId: owner, record: transform(current));
  }

  Future<void> clearForOwner(String? ownerUserId) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    _memoryByOwner.remove(owner);
    _cacheByOwner.remove(owner);
    _metadataWriteGenerations.removeWhere(
      (key, _) => key.startsWith('$owner|'),
    );
    _fullyCachedOwners.remove(owner);
    _indexTagBackfillDoneOwners.remove(owner);
    _memoryFullSyncMeta.remove(owner);
    if (_useMemoryOnly) {
      _publishCommit(
        ownerUserId: owner,
        kind: GroupStoreMutationKind.reset,
      );
      return;
    }
    final db = await _openDb();
    await db.delete(_table, where: 'owner_user_id = ?', whereArgs: [owner]);
    await db.delete(
      _syncMetaTable,
      where: 'owner_user_id = ?',
      whereArgs: [owner],
    );
    try {
      await db.delete(
        _searchTable,
        where: 'owner_user_id = ?',
        whereArgs: [owner],
      );
    } catch (_) {}
    _publishCommit(
      ownerUserId: owner,
      kind: GroupStoreMutationKind.reset,
    );
  }

  Future<void> clearSession() async {
    // 登出只卸内存；磁盘多账号共存，注销走 clearForOwner。
    _memoryByOwner.clear();
    _cacheByOwner.clear();
    _metadataWriteGenerations.clear();
    _fullyCachedOwners.clear();
    _indexTagBackfillDoneOwners.clear();
    _memoryFullSyncMeta.clear();
    _publishCommit(
      ownerUserId: '',
      kind: GroupStoreMutationKind.reset,
    );
  }

  /// 测试专用：整表清空（生产登出禁止调用）。
  @visibleForTesting
  Future<void> wipeAllDiskForTest() async {
    _memoryByOwner.clear();
    _cacheByOwner.clear();
    _metadataWriteGenerations.clear();
    _fullyCachedOwners.clear();
    _indexTagBackfillDoneOwners.clear();
    _memoryFullSyncMeta.clear();
    if (_useMemoryOnly) {
      _publishCommit(
        ownerUserId: '',
        kind: GroupStoreMutationKind.reset,
      );
      return;
    }
    final db = await _openDb();
    await db.delete(_table);
    await db.delete(_syncMetaTable);
    try {
      await db.delete(_searchTable);
    } catch (_) {}
    _publishCommit(
      ownerUserId: '',
      kind: GroupStoreMutationKind.reset,
    );
  }

  MeGroupRecord _recordFromRow(Map<String, Object?> row) {
    return MeGroupRecord(
      groupId: row['group_id']?.toString() ?? '',
      groupType: row['group_type']?.toString() ?? '',
      groupName: row['group_name']?.toString() ?? '',
      displayAlias: row['display_alias']?.toString() ?? '',
      avatarUrl: row['avatar_url']?.toString() ?? '',
      avatarPreviewUrl: row['avatar_preview_url']?.toString() ?? '',
      avatarVersion: (row['avatar_version'] as int?) ?? 0,
      notice: row['notice']?.toString() ?? '',
      memberCount: (row['member_count'] as int?) ?? 0,
      myRole: (row['my_role'] as int?) ?? 200,
      myNameCard: row['my_name_card']?.toString() ?? '',
      joinedAt: (row['joined_at'] as int?) ?? 0,
      updatedAt: (row['updated_at'] as int?) ?? 0,
      ownerUserId: row['owner_group_user_id']?.toString() ?? '',
      noticeUpdatedAt: (row['notice_updated_at'] as int?) ?? 0,
      noticeUpdatedBy: row['notice_updated_by']?.toString() ?? '',
      isAllMuted: (row['is_all_muted'] as int? ?? 0) != 0,
      gameEnabled: (row['game_enabled'] as int? ?? 0) != 0,
    );
  }

  Map<String, Object?> _rowFromRecord(
    String owner,
    MeGroupRecord record,
    int localUpdatedAt,
  ) {
    return <String, Object?>{
      'owner_user_id': owner,
      'group_id': record.groupId,
      'group_type': record.groupType,
      'group_name': record.groupName,
      'display_alias': record.displayAlias,
      'avatar_url': record.avatarUrl,
      'avatar_preview_url': record.avatarPreviewUrl,
      'avatar_version': record.avatarVersion,
      'notice': record.notice,
      'member_count': record.memberCount,
      'my_role': record.myRole,
      'my_name_card': record.myNameCard,
      'joined_at': record.joinedAt,
      'updated_at': record.updatedAt > 0 ? record.updatedAt : localUpdatedAt,
      'owner_group_user_id': record.ownerUserId,
      'notice_updated_at': record.noticeUpdatedAt,
      'notice_updated_by': record.noticeUpdatedBy,
      'is_all_muted': record.isAllMuted ? 1 : 0,
      'game_enabled': record.gameEnabled ? 1 : 0,
      'index_tag': MyGroupAzSkeleton.computeIndexTag(
        groupName: record.groupName,
        groupId: record.groupId,
      ),
    };
  }

  void _cacheRecords(String owner, List<MeGroupRecord> records) {
    final bucket = <String, MeGroupRecord>{};
    for (final record in records) {
      final id = record.groupId.trim();
      if (id.isEmpty) {
        continue;
      }
      bucket[id] = record;
    }
    _cacheByOwner[owner] = bucket;
  }

  /// 单测注入：指定 owner 下写入内存缓存（不落库）。
  @visibleForTesting
  void debugPutCachedRecord({
    required String ownerUserId,
    required MeGroupRecord record,
  }) {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    final id = record.groupId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    final bucket = _cacheByOwner.putIfAbsent(
      owner,
      () => <String, MeGroupRecord>{},
    );
    bucket[id] = record;
  }

  /// 单测：强制 [readCached] 使用的 owner（绕过未登录）。
  @visibleForTesting
  String? debugOwnerUserIdOverride;

  @visibleForTesting
  void debugClearOwnerOverride() {
    debugOwnerUserIdOverride = null;
  }

  @visibleForTesting
  void debugRemoveCachedRecord({
    required String ownerUserId,
    required String groupId,
  }) {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    final id = groupId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    _cacheByOwner[owner]?.removeWhere(
      (key, _) => ChatIdFormat.groupIdsEquivalent(key, id),
    );
  }
}
