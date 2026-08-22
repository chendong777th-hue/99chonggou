import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/search_local/pinyin_index.dart';
import 'package:tencent_cloud_chat_demo/src/services/search_local/search_id_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lock_profile_log.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';

/// 自托管好友通讯录本地库（按登录账号隔离）。在线状态不由本库提供。
class FriendLocalStore {
  FriendLocalStore._();

  static final FriendLocalStore instance = FriendLocalStore._();

  static const _dbName = 'friend_local_v1.db';
  static const _table = 'friends';
  static const _searchTable = 'friend_search_index';
  static const _ftsTable = 'contact_fts';
  static const int _dbVersion = 2;
  static const int defaultSearchPageSize = 80;

  Database? _db;
  final Map<String, List<MeFriendRecord>> _memoryByOwner = {};
  bool _factoryReady = false;
  bool? _ftsAvailable;

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

  Future<void> _createFriendsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_table (
        owner_user_id TEXT NOT NULL,
        friend_user_id TEXT NOT NULL,
        friend_nickname TEXT NOT NULL DEFAULT '',
        friend_avatar_url TEXT NOT NULL DEFAULT '',
        remark TEXT NOT NULL DEFAULT '',
        added_at INTEGER NOT NULL DEFAULT 0,
        peer_deleted_me INTEGER NOT NULL DEFAULT 0,
        can_message INTEGER NOT NULL DEFAULT 1,
        in_my_friend_list INTEGER NOT NULL DEFAULT 1,
        is_friend INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (owner_user_id, friend_user_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_friends_owner ON $_table(owner_user_id)',
    );
  }

  Future<void> _createSearchIndexTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_searchTable (
        owner_user_id TEXT NOT NULL,
        friend_user_id TEXT NOT NULL,
        haystack TEXT NOT NULL DEFAULT '',
        PRIMARY KEY (owner_user_id, friend_user_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_friend_search_owner_id '
      'ON $_searchTable(owner_user_id, friend_user_id)',
    );
  }

  Future<bool> _tryCreateFts(DatabaseExecutor db) async {
    try {
      await db.execute('DROP TABLE IF EXISTS $_ftsTable');
      await db.execute('''
        CREATE VIRTUAL TABLE $_ftsTable USING fts5(
          owner_user_id UNINDEXED,
          user_id UNINDEXED,
          body,
          tokenize='unicode61'
        )
      ''');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureFtsFlag(Database db) async {
    if (_ftsAvailable != null) {
      return;
    }
    try {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [_ftsTable],
      );
      _ftsAvailable = rows.isNotEmpty;
    } catch (_) {
      _ftsAvailable = false;
    }
  }

  Future<Database> _openDb() async {
    final existing = SqfliteLifecycleGuard.beforeOpen(_db);
    if (existing != null) {
      await _ensureFtsFlag(existing);
      return existing;
    }
    await _ensureDatabaseFactory();
    final basePath = await getDatabasesPath();
    final path = p.join(basePath, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createFriendsTable(db);
        await _createSearchIndexTable(db);
        _ftsAvailable = await _tryCreateFts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createSearchIndexTable(db);
          _ftsAvailable = await _tryCreateFts(db);
          await _rebuildSearchIndexForAllOwners(db);
        }
      },
      onOpen: (db) async {
        await _createSearchIndexTable(db);
        await _ensureFtsFlag(db);
        if (_ftsAvailable != true) {
          _ftsAvailable = await _tryCreateFts(db);
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

  Future<void> _rebuildSearchIndexForAllOwners(DatabaseExecutor db) async {
    final owners = await db.rawQuery(
      'SELECT DISTINCT owner_user_id FROM $_table',
    );
    for (final row in owners) {
      final owner = row['owner_user_id']?.toString() ?? '';
      if (owner.isEmpty) {
        continue;
      }
      await _rebuildSearchIndexForOwner(db, owner);
    }
  }

  Future<void> _rebuildSearchIndexForOwner(
    DatabaseExecutor db,
    String owner,
  ) async {
    await db.delete(
      _searchTable,
      where: 'owner_user_id = ?',
      whereArgs: [owner],
    );
    if (_ftsAvailable == true) {
      try {
        await db.delete(
          _ftsTable,
          where: 'owner_user_id = ?',
          whereArgs: [owner],
        );
      } catch (_) {}
    }
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ?',
      whereArgs: [owner],
    );
    final batch = db.batch();
    for (final row in rows) {
      final record = _recordFromRow(row);
      _enqueueSearchUpsert(batch, owner, record);
    }
    await batch.commit(noResult: true);
  }

  void _enqueueSearchUpsert(
    Batch batch,
    String owner,
    MeFriendRecord record,
  ) {
    final id = record.friendUserId.trim();
    if (id.isEmpty) {
      return;
    }
    final haystack = PinyinIndex.friendHaystack(
      userId: id,
      nickname: record.friendNickname,
      remark: record.remark,
    );
    batch.insert(
      _searchTable,
      <String, Object?>{
        'owner_user_id': owner,
        'friend_user_id': id,
        'haystack': haystack,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (_ftsAvailable == true) {
      batch.insert(_ftsTable, <String, Object?>{
        'owner_user_id': owner,
        'user_id': id,
        'body': haystack,
      });
    }
  }

  Future<void> _upsertSearchRow(
    DatabaseExecutor db,
    String owner,
    MeFriendRecord record,
  ) async {
    final id = record.friendUserId.trim();
    if (id.isEmpty) {
      return;
    }
    final haystack = PinyinIndex.friendHaystack(
      userId: id,
      nickname: record.friendNickname,
      remark: record.remark,
    );
    await db.insert(
      _searchTable,
      <String, Object?>{
        'owner_user_id': owner,
        'friend_user_id': id,
        'haystack': haystack,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (_ftsAvailable == true) {
      try {
        await db.delete(
          _ftsTable,
          where: 'owner_user_id = ? AND user_id = ?',
          whereArgs: [owner, id],
        );
        await db.insert(_ftsTable, <String, Object?>{
          'owner_user_id': owner,
          'user_id': id,
          'body': haystack,
        });
      } catch (_) {
        _ftsAvailable = false;
      }
    }
  }

  Future<void> _deleteSearchRow(
    DatabaseExecutor db,
    String owner,
    String friendUserId,
  ) async {
    await db.delete(
      _searchTable,
      where: 'owner_user_id = ? AND friend_user_id = ?',
      whereArgs: [owner, friendUserId],
    );
    if (_ftsAvailable == true) {
      try {
        await db.delete(
          _ftsTable,
          where: 'owner_user_id = ? AND user_id = ?',
          whereArgs: [owner, friendUserId],
        );
      } catch (_) {}
    }
  }

  String currentOwnerUserId() {
    return ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
  }

  String _resolveOwner(String? ownerUserId) {
    final explicit = ChatIdFormat.rawUserUid(ownerUserId);
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return currentOwnerUserId();
  }

  bool get _useMemoryOnly => kIsWeb;

  /// 测试可见：当前进程是否启用了 FTS5。
  @visibleForTesting
  bool? get debugFtsAvailable => _ftsAvailable;

  Future<List<MeFriendRecord>> readAll({String? ownerUserId}) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return const [];
    }
    if (_useMemoryOnly) {
      return List.unmodifiable(_memoryByOwner[owner] ?? const []);
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ?',
      whereArgs: [owner],
      orderBy: 'friend_user_id ASC',
    );
    return rows.map(_recordFromRow).toList(growable: false);
  }

  Future<List<MeFriendRecord>> readByIds({
    required List<String> friendUserIds,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final ids = friendUserIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (owner.isEmpty || ids.isEmpty) {
      return const [];
    }
    if (_useMemoryOnly) {
      final map = <String, MeFriendRecord>{
        for (final item in _memoryByOwner[owner] ?? const <MeFriendRecord>[])
          item.friendUserId: item,
      };
      return [
        for (final id in ids)
          if (map[id] != null) map[id]!,
      ];
    }
    final db = await _openDb();
    final out = <MeFriendRecord>[];
    const chunk = 200;
    for (var i = 0; i < ids.length; i += chunk) {
      final slice = ids.sublist(i, i + chunk > ids.length ? ids.length : i + chunk);
      final placeholders = List.filled(slice.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT * FROM $_table WHERE owner_user_id = ? '
        'AND friend_user_id IN ($placeholders)',
        <Object?>[owner, ...slice],
      );
      final byId = <String, MeFriendRecord>{};
      for (final row in rows) {
        final record = _recordFromRow(row);
        byId[record.friendUserId] = record;
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

  Future<List<V2TimFriendInfo>> loadAsV2TimFriends({
    String? ownerUserId,
  }) async {
    final records = await readAll(ownerUserId: ownerUserId);
    return records.map((e) => e.toV2TimFriendInfo()).toList(growable: false);
  }

  Future<List<V2TimFriendInfo>> loadAsV2TimFriendsByIds({
    required List<String> friendUserIds,
    String? ownerUserId,
  }) async {
    final records = await readByIds(
      friendUserIds: friendUserIds,
      ownerUserId: ownerUserId,
    );
    return records.map((e) => e.toV2TimFriendInfo()).toList(growable: false);
  }

  /// 本地好友关键字搜索：返回 ID 页（cursor = 上一页最后 friend_user_id）。
  Future<SearchIdPage> searchFriendIds({
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
      return _searchFriendIdsInMemory(
        owner: owner,
        needle: needle,
        pageSize: pageSize,
        cursor: cursor,
      );
    }

    final db = await _openDb();
    await _ensureFtsFlag(db);

    List<Map<String, Object?>> rows;
    if (_ftsAvailable == true && _isAsciiKeyword(needle)) {
      rows = await _searchFriendIdsViaFts(
        db: db,
        owner: owner,
        needle: needle,
        pageSize: pageSize + 1,
        cursor: cursor,
      );
    } else {
      rows = await _searchFriendIdsViaLike(
        db: db,
        owner: owner,
        needle: needle,
        pageSize: pageSize + 1,
        cursor: cursor,
      );
    }

    final ids = <String>[];
    for (final row in rows) {
      final id = row['friend_user_id']?.toString() ??
          row['user_id']?.toString() ??
          '';
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
    final hasMore = ids.length > pageSize;
    final pageIds =
        hasMore ? ids.sublist(0, pageSize) : List<String>.from(ids);
    return SearchIdPage(
      ids: pageIds,
      nextCursor: pageIds.isEmpty ? null : pageIds.last,
      hasMore: hasMore,
    );
  }

  bool _isAsciiKeyword(String needle) {
    return RegExp(r'^[a-z0-9_@.\-]+$').hasMatch(needle);
  }

  String _ftsMatchQuery(String needle) {
    final escaped = needle.replaceAll('"', '""');
    return '"$escaped"*';
  }

  Future<List<Map<String, Object?>>> _searchFriendIdsViaLike({
    required Database db,
    required String owner,
    required String needle,
    required int pageSize,
    String? cursor,
  }) async {
    final args = <Object?>[owner, '%$needle%'];
    final cursorClause = (cursor != null && cursor.trim().isNotEmpty)
        ? ' AND friend_user_id > ?'
        : '';
    if (cursorClause.isNotEmpty) {
      args.add(cursor!.trim());
    }
    args.add(pageSize);
    return db.rawQuery(
      'SELECT friend_user_id FROM $_searchTable '
      'WHERE owner_user_id = ? AND haystack LIKE ?$cursorClause '
      'ORDER BY friend_user_id ASC LIMIT ?',
      args,
    );
  }

  Future<List<Map<String, Object?>>> _searchFriendIdsViaFts({
    required Database db,
    required String owner,
    required String needle,
    required int pageSize,
    String? cursor,
  }) async {
    try {
      final args = <Object?>[owner, _ftsMatchQuery(needle)];
      final cursorClause = (cursor != null && cursor.trim().isNotEmpty)
          ? ' AND user_id > ?'
          : '';
      if (cursorClause.isNotEmpty) {
        args.add(cursor!.trim());
      }
      args.add(pageSize);
      return await db.rawQuery(
        'SELECT user_id FROM $_ftsTable '
        'WHERE owner_user_id = ? AND $_ftsTable MATCH ?$cursorClause '
        'ORDER BY user_id ASC LIMIT ?',
        args,
      );
    } catch (_) {
      _ftsAvailable = false;
      return _searchFriendIdsViaLike(
        db: db,
        owner: owner,
        needle: needle,
        pageSize: pageSize,
        cursor: cursor,
      );
    }
  }

  SearchIdPage _searchFriendIdsInMemory({
    required String owner,
    required String needle,
    required int pageSize,
    String? cursor,
  }) {
    final all = _memoryByOwner[owner] ?? const <MeFriendRecord>[];
    final matched = <String>[];
    for (final item in all) {
      final id = item.friendUserId.trim();
      if (id.isEmpty) {
        continue;
      }
      if (cursor != null &&
          cursor.trim().isNotEmpty &&
          id.compareTo(cursor.trim()) <= 0) {
        continue;
      }
      final haystack = PinyinIndex.friendHaystack(
        userId: id,
        nickname: item.friendNickname,
        remark: item.remark,
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

  Future<void> replaceAll({
    required String ownerUserId,
    required List<MeFriendRecord> records,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final normalized = records
        .where((e) => e.friendUserId.isNotEmpty)
        .map((e) => e.copyWith())
        .toList(growable: false);
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      _memoryByOwner[owner] = normalized;
      return;
    }
    final db = await _openDb();
    await profiledTransaction<void>(
      db,
      dbTag: _dbName,
      op: 'replaceAll',
      extras: <String, Object?>{'count': normalized.length},
      action: (txn) async {
        final batch = txn.batch();
        batch.delete(_table, where: 'owner_user_id = ?', whereArgs: [owner]);
        batch.delete(
          _searchTable,
          where: 'owner_user_id = ?',
          whereArgs: [owner],
        );
        for (final item in normalized) {
          batch.insert(_table, _rowFromRecord(owner, item, now));
          _enqueueSearchUpsert(batch, owner, item);
        }
        await batch.commit(noResult: true);
        if (_ftsAvailable == true) {
          try {
            await txn.delete(
              _ftsTable,
              where: 'owner_user_id = ?',
              whereArgs: [owner],
            );
            for (final item in normalized) {
              final id = item.friendUserId.trim();
              if (id.isEmpty) {
                continue;
              }
              await txn.insert(_ftsTable, <String, Object?>{
                'owner_user_id': owner,
                'user_id': id,
                'body': PinyinIndex.friendHaystack(
                  userId: id,
                  nickname: item.friendNickname,
                  remark: item.remark,
                ),
              });
            }
          } catch (_) {
            _ftsAvailable = false;
          }
        }
      },
    );
  }

  Future<void> upsert({
    required String ownerUserId,
    required MeFriendRecord record,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final id = record.friendUserId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      final list = List<MeFriendRecord>.from(_memoryByOwner[owner] ?? const []);
      list.removeWhere((e) => e.friendUserId == id);
      list.add(record);
      list.sort((a, b) => a.friendUserId.compareTo(b.friendUserId));
      _memoryByOwner[owner] = list;
      return;
    }
    final db = await _openDb();
    await db.insert(
      _table,
      _rowFromRecord(owner, record, now),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _upsertSearchRow(db, owner, record);
  }

  Future<void> delete({
    required String ownerUserId,
    required String friendUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final id = friendUserId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      final list = List<MeFriendRecord>.from(_memoryByOwner[owner] ?? const []);
      list.removeWhere((e) => e.friendUserId == id);
      _memoryByOwner[owner] = list;
      return;
    }
    final db = await _openDb();
    await db.delete(
      _table,
      where: 'owner_user_id = ? AND friend_user_id = ?',
      whereArgs: [owner, id],
    );
    await _deleteSearchRow(db, owner, id);
  }

  Future<void> patch({
    required String ownerUserId,
    required String friendUserId,
    required MeFriendRecord Function(MeFriendRecord current) transform,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final id = friendUserId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    final all = await readAll(ownerUserId: owner);
    final index = all.indexWhere((e) => e.friendUserId == id);
    if (index < 0) {
      return;
    }
    await upsert(ownerUserId: owner, record: transform(all[index]));
  }

  Future<void> clearForOwner(String? ownerUserId) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    _memoryByOwner.remove(owner);
    if (_useMemoryOnly) {
      return;
    }
    final db = await _openDb();
    await db.delete(_table, where: 'owner_user_id = ?', whereArgs: [owner]);
    await db.delete(
      _searchTable,
      where: 'owner_user_id = ?',
      whereArgs: [owner],
    );
    if (_ftsAvailable == true) {
      try {
        await db.delete(
          _ftsTable,
          where: 'owner_user_id = ?',
          whereArgs: [owner],
        );
      } catch (_) {}
    }
  }

  Future<void> clearSession() async {
    // 登出只卸内存；磁盘多账号共存，注销走 clearForOwner。
    _memoryByOwner.clear();
  }

  /// 测试专用：整表清空（生产登出禁止调用）。
  @visibleForTesting
  Future<void> wipeAllDiskForTest() async {
    _memoryByOwner.clear();
    if (_useMemoryOnly) {
      return;
    }
    final db = await _openDb();
    await db.delete(_table);
    try {
      await db.delete(_searchTable);
    } catch (_) {}
    if (_ftsAvailable == true) {
      try {
        await db.delete(_ftsTable);
      } catch (_) {}
    }
  }

  MeFriendRecord _recordFromRow(Map<String, Object?> row) {
    return MeFriendRecord(
      friendUserId: row['friend_user_id']?.toString() ?? '',
      remark: row['remark']?.toString() ?? '',
      friendNickname: row['friend_nickname']?.toString() ?? '',
      friendAvatarUrl: row['friend_avatar_url']?.toString() ?? '',
      addedAt: (row['added_at'] as int?) ?? 0,
      peerDeletedMe: (row['peer_deleted_me'] as int? ?? 0) != 0,
      canMessage: (row['can_message'] as int? ?? 1) != 0,
      inMyFriendList: (row['in_my_friend_list'] as int? ?? 1) != 0,
      isFriend: (row['is_friend'] as int? ?? 1) != 0,
    );
  }

  Map<String, Object?> _rowFromRecord(
    String owner,
    MeFriendRecord record,
    int updatedAt,
  ) {
    return <String, Object?>{
      'owner_user_id': owner,
      'friend_user_id': record.friendUserId,
      'friend_nickname': record.friendNickname,
      'friend_avatar_url': record.friendAvatarUrl,
      'remark': record.remark,
      'added_at': record.addedAt,
      'peer_deleted_me': record.peerDeletedMe ? 1 : 0,
      'can_message': record.canMessage ? 1 : 0,
      'in_my_friend_list': record.inMyFriendList ? 1 : 0,
      'is_friend': record.isFriend ? 1 : 0,
      'updated_at': updatedAt,
    };
  }
}
