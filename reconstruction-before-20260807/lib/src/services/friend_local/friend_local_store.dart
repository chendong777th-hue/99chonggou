import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
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

  Database? _db;
  final Map<String, List<MeFriendRecord>> _memoryByOwner = {};
  bool _factoryReady = false;

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
    final existing = _db;
    if (existing != null) {
      return existing;
    }
    await _ensureDatabaseFactory();
    final basePath = await getDatabasesPath();
    final path = p.join(basePath, _dbName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
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
      },
    );
    return _db!;
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

  Future<List<V2TimFriendInfo>> loadAsV2TimFriends({String? ownerUserId}) async {
    final records = await readAll(ownerUserId: ownerUserId);
    return records
        .map((e) => e.toV2TimFriendInfo())
        .toList(growable: false);
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
    if (_useMemoryOnly) {
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
        await txn.delete(_table, where: 'owner_user_id = ?', whereArgs: [owner]);
        for (final item in normalized) {
          await txn.insert(_table, _rowFromRecord(owner, item, now));
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
    if (_useMemoryOnly) {
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
    if (_useMemoryOnly) {
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
  }

  Future<void> clearSession() async {
    _memoryByOwner.clear();
    if (_useMemoryOnly) {
      return;
    }
    final db = _db;
    if (db == null) {
      return;
    }
    await db.delete(_table);
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
