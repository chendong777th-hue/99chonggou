import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lock_profile_log.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';

/// 群成员分页缓存（按 owner + groupId 隔离）。
class GroupMemberLocalStore {
  GroupMemberLocalStore._();

  static final GroupMemberLocalStore instance = GroupMemberLocalStore._();

  static const _dbName = 'group_member_local_v1.db';
  static const _table = 'group_members';
  static const _readByIdsChunkSize = 200;

  Database? _db;
  final Map<String, Map<String, List<GroupMemberRecord>>> _memoryByOwner = {};
  bool _factoryReady = false;

  bool get _useMemoryOnly => kIsWeb;

  @visibleForTesting
  static List<GroupMemberRecord> dedupeGroupMemberRecords(
    List<GroupMemberRecord> records,
  ) {
    final byUserId = <String, GroupMemberRecord>{};
    for (final record in records) {
      final userId = ChatIdFormat.rawUserUid(record.userId);
      if (userId.isEmpty) {
        continue;
      }
      byUserId[userId] =
          record.userId == userId ? record : record.copyWith(userId: userId);
    }
    return byUserId.values.toList(growable: false);
  }

  @visibleForTesting
  static bool samePersistedGroupMemberRecord(
    GroupMemberRecord existing,
    GroupMemberRecord incoming,
  ) {
    return existing.userId == incoming.userId &&
        existing.nickname == incoming.nickname &&
        existing.avatarUrl == incoming.avatarUrl &&
        existing.friendRemark == incoming.friendRemark &&
        existing.nameCard == incoming.nameCard &&
        existing.role == incoming.role &&
        existing.joinedAt == incoming.joinedAt &&
        existing.isSelf == incoming.isSelf &&
        existing.muteUntil == incoming.muteUntil &&
        existing.invitedByUserId == incoming.invitedByUserId &&
        existing.invitedByNickname == incoming.invitedByNickname &&
        existing.joinChannel == incoming.joinChannel;
  }

  @visibleForTesting
  static List<GroupMemberRecord> groupMemberRecordsToUpsert({
    required List<GroupMemberRecord> existing,
    required List<GroupMemberRecord> normalized,
  }) {
    final existingByUserId = <String, GroupMemberRecord>{
      for (final record in existing) record.userId: record,
    };
    return normalized.where((record) {
      final old = existingByUserId[record.userId];
      return old == null || !samePersistedGroupMemberRecord(old, record);
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
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            owner_user_id TEXT NOT NULL,
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            nickname TEXT NOT NULL DEFAULT '',
            avatar_url TEXT NOT NULL DEFAULT '',
            friend_remark TEXT NOT NULL DEFAULT '',
            name_card TEXT NOT NULL DEFAULT '',
            role INTEGER NOT NULL DEFAULT 200,
            joined_at INTEGER NOT NULL DEFAULT 0,
            is_self INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            mute_until INTEGER NOT NULL DEFAULT 0,
            invited_by_user_id TEXT NOT NULL DEFAULT '',
            invited_by_nickname TEXT NOT NULL DEFAULT '',
            join_channel TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (owner_user_id, group_id, user_id)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_group_members_owner_group ON $_table(owner_user_id, group_id)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN mute_until INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN invited_by_user_id TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN invited_by_nickname TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN join_channel TEXT NOT NULL DEFAULT ''",
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

  Future<List<GroupMemberRecord>> readAll({
    required String groupId,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final gid = groupId.trim();
    if (owner.isEmpty || gid.isEmpty) {
      return const <GroupMemberRecord>[];
    }
    if (_useMemoryOnly) {
      return List<GroupMemberRecord>.from(
        _memoryByOwner[owner]?[gid] ?? const [],
      );
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND group_id = ?',
      whereArgs: [owner, gid],
      orderBy: 'role DESC, joined_at ASC, user_id ASC',
    );
    return rows.map(_recordFromRow).toList(growable: false);
  }

  Future<List<V2TimGroupMemberFullInfo>> loadAsV2TimMembers({
    required String groupId,
    String? ownerUserId,
    int? limit,
  }) async {
    final records = await readAll(groupId: groupId, ownerUserId: ownerUserId);
    final sliced = (limit != null && limit > 0 && records.length > limit)
        ? records.take(limit).toList(growable: false)
        : records;
    return sliced.map(_toV2TimMember).toList(growable: false);
  }

  Future<List<V2TimGroupMemberFullInfo>> readByUserIds({
    required String groupId,
    required List<String> userIds,
    String? ownerUserId,
  }) async {
    final records = await readRecordsByUserIds(
      groupId: groupId,
      userIds: userIds,
      ownerUserId: ownerUserId,
    );
    return records.map(_toV2TimMember).toList(growable: false);
  }

  Future<GroupMemberRecord?> readRecord({
    required String groupId,
    required String userId,
    String? ownerUserId,
  }) async {
    final uid = ChatIdFormat.rawUserUid(userId);
    if (uid.isEmpty) {
      return null;
    }
    final list = await readRecordsByUserIds(
      groupId: groupId,
      userIds: <String>[uid],
      ownerUserId: ownerUserId,
    );
    for (final record in list) {
      if (record.userId == uid) {
        return record;
      }
    }
    return null;
  }

  Future<List<GroupMemberRecord>> readRecordsByUserIds({
    required String groupId,
    required List<String> userIds,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final gid = groupId.trim();
    final wanted =
        userIds.map(ChatIdFormat.rawUserUid).where((e) => e.isNotEmpty).toSet();
    if (owner.isEmpty || gid.isEmpty || wanted.isEmpty) {
      return const <GroupMemberRecord>[];
    }
    if (_useMemoryOnly) {
      final all = await readAll(groupId: gid, ownerUserId: owner);
      return all
          .where((record) => wanted.contains(record.userId))
          .toList(growable: false);
    }
    final db = await _openDb();
    final records = await _readRecordsByUserIds(
      db,
      owner: owner,
      groupId: gid,
      userIds: wanted.toList(growable: false),
    );
    records.sort((a, b) {
      final roleCmp = b.role.compareTo(a.role);
      if (roleCmp != 0) return roleCmp;
      final joinedCmp = a.joinedAt.compareTo(b.joinedAt);
      if (joinedCmp != 0) return joinedCmp;
      return a.userId.compareTo(b.userId);
    });
    return records;
  }

  Future<void> replacePage({
    required String ownerUserId,
    required String groupId,
    required int offset,
    required List<GroupMemberRecord> records,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final gid = groupId.trim();
    if (owner.isEmpty || gid.isEmpty) {
      return;
    }
    if (offset <= 0) {
      await clearGroup(ownerUserId: owner, groupId: gid);
    }
    await upsertMany(ownerUserId: owner, groupId: gid, records: records);
  }

  /// Reconciles an authoritative complete member snapshot in one transaction.
  /// Unchanged rows are retained, missing rows are removed, and only changed or
  /// new rows are written.
  Future<void> replaceSnapshot({
    required String ownerUserId,
    required String groupId,
    required List<GroupMemberRecord> records,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final gid = groupId.trim();
    final normalized = dedupeGroupMemberRecords(records);
    if (owner.isEmpty || gid.isEmpty) {
      return;
    }
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      final byGroup = _memoryByOwner.putIfAbsent(owner, () => {});
      byGroup[gid] = List<GroupMemberRecord>.from(normalized)
        ..sort((a, b) {
          final roleCmp = b.role.compareTo(a.role);
          if (roleCmp != 0) return roleCmp;
          final joinedCmp = a.joinedAt.compareTo(b.joinedAt);
          if (joinedCmp != 0) return joinedCmp;
          return a.userId.compareTo(b.userId);
        });
      return;
    }

    final db = await _openDb();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await profiledTransaction<void>(
      db,
      dbTag: _dbName,
      op: 'replaceSnapshot',
      extras: <String, Object?>{'count': normalized.length},
      action: (txn) async {
        final rows = await txn.query(
          _table,
          where: 'owner_user_id = ? AND group_id = ?',
          whereArgs: [owner, gid],
        );
        final existing = rows.map(_recordFromRow).toList(growable: false);
        final incomingIds = normalized.map((item) => item.userId).toSet();
        final toDelete = existing
            .where((item) => !incomingIds.contains(item.userId))
            .map((item) => item.userId)
            .toList(growable: false);
        final toUpsert = groupMemberRecordsToUpsert(
          existing: existing,
          normalized: normalized,
        );
        if (toDelete.isEmpty && toUpsert.isEmpty) {
          SqfliteLockProfileLog.event(
            'replaceSnapshot_skip',
            extras: <String, Object?>{
              'db': _dbName,
              'count': normalized.length,
            },
          );
          return;
        }
        final batch = txn.batch();
        for (final userId in toDelete) {
          batch.delete(
            _table,
            where: 'owner_user_id = ? AND group_id = ? AND user_id = ?',
            whereArgs: [owner, gid, userId],
          );
        }
        for (final item in toUpsert) {
          batch.insert(
            _table,
            _rowFromRecord(owner, gid, item, now),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      },
    );
  }

  Future<void> upsertMany({
    required String ownerUserId,
    required String groupId,
    required List<GroupMemberRecord> records,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final gid = groupId.trim();
    final normalized = dedupeGroupMemberRecords(records);
    if (owner.isEmpty || gid.isEmpty || normalized.isEmpty) {
      return;
    }
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      final byGroup = _memoryByOwner.putIfAbsent(owner, () => {});
      final list = offsetList(byGroup, gid);
      final toUpsert = groupMemberRecordsToUpsert(
        existing: list,
        normalized: normalized,
      );
      for (final item in toUpsert) {
        list.removeWhere((e) => e.userId == item.userId);
        list.add(item);
      }
      list.sort((a, b) {
        final roleCmp = b.role.compareTo(a.role);
        if (roleCmp != 0) return roleCmp;
        return a.joinedAt.compareTo(b.joinedAt);
      });
      byGroup[gid] = list;
      return;
    }
    final db = await _openDb();
    final existing = await _readRecordsByUserIds(
      db,
      owner: owner,
      groupId: gid,
      userIds:
          normalized.map((record) => record.userId).toList(growable: false),
    );
    final toUpsert = groupMemberRecordsToUpsert(
      existing: existing,
      normalized: normalized,
    );
    if (toUpsert.isEmpty) {
      SqfliteLockProfileLog.event(
        'upsertMany_skip',
        extras: <String, Object?>{
          'db': _dbName,
          'count': normalized.length,
          'unchanged': normalized.length,
        },
      );
      return;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await profiledTransaction<void>(
      db,
      dbTag: _dbName,
      op: 'upsertMany',
      extras: <String, Object?>{
        'count': toUpsert.length,
        'unchanged': normalized.length - toUpsert.length,
      },
      action: (txn) async {
        for (final item in toUpsert) {
          await txn.insert(
            _table,
            _rowFromRecord(owner, gid, item, now),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      },
    );
  }

  Future<List<GroupMemberRecord>> _readRecordsByUserIds(
    Database db, {
    required String owner,
    required String groupId,
    required List<String> userIds,
  }) async {
    final records = <GroupMemberRecord>[];
    for (var offset = 0;
        offset < userIds.length;
        offset += _readByIdsChunkSize) {
      final end = offset + _readByIdsChunkSize > userIds.length
          ? userIds.length
          : offset + _readByIdsChunkSize;
      final chunk = userIds.sublist(offset, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.query(
        _table,
        where:
            'owner_user_id = ? AND group_id = ? AND user_id IN ($placeholders)',
        whereArgs: <Object?>[owner, groupId, ...chunk],
      );
      records.addAll(rows.map(_recordFromRow));
    }
    return records;
  }

  List<GroupMemberRecord> offsetList(
      Map<String, List<GroupMemberRecord>> byGroup, String gid) {
    return List<GroupMemberRecord>.from(byGroup[gid] ?? const []);
  }

  Future<void> deleteUsers({
    required String ownerUserId,
    required String groupId,
    required List<String> userIds,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final gid = groupId.trim();
    final ids = userIds
        .map(ChatIdFormat.rawUserUid)
        .where((e) => e.isNotEmpty)
        .toList();
    if (owner.isEmpty || gid.isEmpty || ids.isEmpty) {
      return;
    }
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      final byGroup = _memoryByOwner[owner];
      final list = byGroup?[gid];
      if (list == null) {
        return;
      }
      list.removeWhere((e) => ids.contains(e.userId));
      return;
    }
    final db = await _openDb();
    for (final userId in ids) {
      await db.delete(
        _table,
        where: 'owner_user_id = ? AND group_id = ? AND user_id = ?',
        whereArgs: [owner, gid, userId],
      );
    }
  }

  Future<void> clearGroup({
    required String ownerUserId,
    required String groupId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final gid = groupId.trim();
    if (owner.isEmpty || gid.isEmpty) {
      return;
    }
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      _memoryByOwner[owner]?.remove(gid);
      return;
    }
    final db = await _openDb();
    await db.delete(
      _table,
      where: 'owner_user_id = ? AND group_id = ?',
      whereArgs: [owner, gid],
    );
  }

  Future<void> patchUser({
    required String ownerUserId,
    required String groupId,
    required String userId,
    required GroupMemberRecord Function(GroupMemberRecord current) transform,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final gid = groupId.trim();
    final uid = ChatIdFormat.rawUserUid(userId);
    if (owner.isEmpty || gid.isEmpty || uid.isEmpty) {
      return;
    }
    final all = await readAll(groupId: gid, ownerUserId: owner);
    final index = all.indexWhere((e) => e.userId == uid);
    if (index < 0) {
      return;
    }
    await upsertMany(
      ownerUserId: owner,
      groupId: gid,
      records: [transform(all[index])],
    );
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
  }

  V2TimGroupMemberFullInfo _toV2TimMember(GroupMemberRecord record) {
    return V2TimGroupMemberFullInfo(
      userID: record.userId,
      role: record.role,
      joinTime: record.joinedAt > 0 ? record.joinedAt ~/ 1000 : null,
      nickName: record.nickname,
      nameCard: record.nameCard,
      friendRemark: record.friendRemark,
      faceUrl: record.avatarUrl,
      muteUntil: record.muteUntil > 0 ? record.muteUntil : null,
    );
  }

  GroupMemberRecord _recordFromRow(Map<String, Object?> row) {
    return GroupMemberRecord(
      userId: row['user_id']?.toString() ?? '',
      nickname: row['nickname']?.toString() ?? '',
      avatarUrl: row['avatar_url']?.toString() ?? '',
      friendRemark: row['friend_remark']?.toString() ?? '',
      nameCard: row['name_card']?.toString() ?? '',
      role: (row['role'] as int?) ?? 200,
      joinedAt: (row['joined_at'] as int?) ?? 0,
      isSelf: (row['is_self'] as int? ?? 0) != 0,
      muteUntil: (row['mute_until'] as int?) ?? 0,
      invitedByUserId: row['invited_by_user_id']?.toString() ?? '',
      invitedByNickname: row['invited_by_nickname']?.toString() ?? '',
      joinChannel: row['join_channel']?.toString() ?? '',
    );
  }

  Map<String, Object?> _rowFromRecord(
    String owner,
    String groupId,
    GroupMemberRecord record,
    int updatedAt,
  ) {
    return <String, Object?>{
      'owner_user_id': owner,
      'group_id': groupId,
      'user_id': record.userId,
      'nickname': record.nickname,
      'avatar_url': record.avatarUrl,
      'friend_remark': record.friendRemark,
      'name_card': record.nameCard,
      'role': record.role,
      'joined_at': record.joinedAt,
      'is_self': record.isSelf ? 1 : 0,
      'updated_at': updatedAt,
      'mute_until': record.muteUntil,
      'invited_by_user_id': record.invitedByUserId,
      'invited_by_nickname': record.invitedByNickname,
      'join_channel': record.joinChannel,
    };
  }
}
