import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';

class MomentsLocalStore {
  MomentsLocalStore._();

  static final MomentsLocalStore instance = MomentsLocalStore._();

  static const _dbName = 'moments_local_v1.db';
  static const _postTable = 'moments_posts';
  static const _feedTable = 'moments_feed_items';
  static const _metaTable = 'moments_feed_meta';
  static const _dbVersion = 1;

  final Map<String, List<MomentPost>> _memoryPages = {};
  final Map<String, MomentPostPage> _memoryMeta = {};
  Database? _db;
  bool _factoryReady = false;

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
    await _ensureDatabaseFactory();
    final basePath = await getDatabasesPath();
    final path = p.join(basePath, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_postTable (
            owner_user_id TEXT NOT NULL,
            moment_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            created_at INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            cached_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (owner_user_id, moment_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE $_feedTable (
            owner_user_id TEXT NOT NULL,
            scope TEXT NOT NULL,
            moment_id TEXT NOT NULL,
            rank INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (owner_user_id, scope, moment_id)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_moments_feed_rank ON $_feedTable(owner_user_id, scope, rank ASC)',
        );
        await db.execute('''
          CREATE TABLE $_metaTable (
            owner_user_id TEXT NOT NULL,
            scope TEXT NOT NULL,
            next_cursor TEXT NOT NULL DEFAULT '',
            has_more INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (owner_user_id, scope)
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> closeIfOpen() async {
    final db = _db;
    _db = null;
    await SqfliteLifecycleGuard.closeDatabase(db);
  }

  Future<MomentPostPage> loadPage({
    required String ownerUserId,
    required String scope,
  }) async {
    final owner = _normalizeOwner(ownerUserId);
    final normalizedScope = _normalizeScope(scope);
    if (kIsWeb) {
      final key = _memoryKey(owner, normalizedScope);
      final meta = _memoryMeta[key];
      return MomentPostPage(
        items: List<MomentPost>.from(_memoryPages[key] ?? const []),
        nextCursor: meta?.nextCursor,
        hasMore: meta?.hasMore ?? false,
      );
    }
    final db = await _openDb();
    try {
      final rows = await db.rawQuery('''
        SELECT p.payload_json
        FROM $_feedTable f
        INNER JOIN $_postTable p
          ON p.owner_user_id = f.owner_user_id
         AND p.moment_id = f.moment_id
        WHERE f.owner_user_id = ? AND f.scope = ?
        ORDER BY f.rank ASC
      ''', [owner, normalizedScope]);
      final posts = <MomentPost>[];
      for (final row in rows) {
        final raw = row['payload_json']?.toString() ?? '';
        if (raw.isEmpty) continue;
        try {
          posts.add(
            MomentPost.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            ),
          );
        } catch (_) {}
      }
      final metaRows = await db.query(
        _metaTable,
        where: 'owner_user_id = ? AND scope = ?',
        whereArgs: [owner, normalizedScope],
        limit: 1,
      );
      final meta = metaRows.isEmpty ? null : metaRows.first;
      return MomentPostPage(
        items: posts,
        nextCursor: meta?['next_cursor']?.toString(),
        hasMore: meta?['has_more'] == 1,
      );
    } catch (_) {
      return const MomentPostPage(items: [], hasMore: false);
    }
  }

  Future<void> savePage({
    required String ownerUserId,
    required String scope,
    required MomentPostPage page,
    required bool replace,
  }) async {
    final owner = _normalizeOwner(ownerUserId);
    final normalizedScope = _normalizeScope(scope);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (kIsWeb || !SqfliteLifecycleGuard.instance.writesAllowed) {
      final key = _memoryKey(owner, normalizedScope);
      final existing = replace
          ? <MomentPost>[]
          : List<MomentPost>.from(_memoryPages[key] ?? const []);
      final seen = existing.map((post) => post.id).toSet();
      for (final post in page.items) {
        if (seen.add(post.id)) existing.add(post);
      }
      _memoryPages[key] = existing;
      _memoryMeta[key] = page;
      return;
    }
    final db = await _openDb();
    await db.transaction((txn) async {
      if (replace) {
        await txn.delete(
          _feedTable,
          where: 'owner_user_id = ? AND scope = ?',
          whereArgs: [owner, normalizedScope],
        );
      }
      final currentCount = replace
          ? 0
          : Sqflite.firstIntValue(
                await txn.rawQuery(
                  'SELECT COUNT(*) FROM $_feedTable WHERE owner_user_id = ? AND scope = ?',
                  [owner, normalizedScope],
                ),
              ) ??
              0;
      var rank = currentCount;
      for (final post in page.items) {
        if (post.id.trim().isEmpty) continue;
        await txn.insert(
          _postTable,
          {
            'owner_user_id': owner,
            'moment_id': post.id,
            'payload_json': jsonEncode(post.toJson()),
            'created_at': post.createdAt.toUtc().millisecondsSinceEpoch,
            'updated_at':
                (post.updatedAt ?? post.createdAt).toUtc().millisecondsSinceEpoch,
            'cached_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          _feedTable,
          {
            'owner_user_id': owner,
            'scope': normalizedScope,
            'moment_id': post.id,
            'rank': rank++,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await txn.insert(
        _metaTable,
        {
          'owner_user_id': owner,
          'scope': normalizedScope,
          'next_cursor': page.nextCursor ?? '',
          'has_more': page.hasMore ? 1 : 0,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> upsertPost({
    required String ownerUserId,
    required MomentPost post,
  }) async {
    final owner = _normalizeOwner(ownerUserId);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (kIsWeb || !SqfliteLifecycleGuard.instance.writesAllowed) {
      for (final entry in _memoryPages.entries) {
        if (!entry.key.startsWith('$owner|')) continue;
        final index = entry.value.indexWhere((item) => item.id == post.id);
        if (index >= 0) entry.value[index] = post;
      }
      return;
    }
    final db = await _openDb();
    await db.insert(
      _postTable,
      {
        'owner_user_id': owner,
        'moment_id': post.id,
        'payload_json': jsonEncode(post.toJson()),
        'created_at': post.createdAt.toUtc().millisecondsSinceEpoch,
        'updated_at':
            (post.updatedAt ?? post.createdAt).toUtc().millisecondsSinceEpoch,
        'cached_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePost({
    required String ownerUserId,
    required String postId,
  }) async {
    final owner = _normalizeOwner(ownerUserId);
    final id = postId.trim();
    if (id.isEmpty) return;
    if (kIsWeb || !SqfliteLifecycleGuard.instance.writesAllowed) {
      for (final entry in _memoryPages.entries) {
        if (!entry.key.startsWith('$owner|')) continue;
        entry.value.removeWhere((post) => post.id == id);
      }
      return;
    }
    final db = await _openDb();
    await db.transaction((txn) async {
      await txn.delete(
        _feedTable,
        where: 'owner_user_id = ? AND moment_id = ?',
        whereArgs: [owner, id],
      );
      await txn.delete(
        _postTable,
        where: 'owner_user_id = ? AND moment_id = ?',
        whereArgs: [owner, id],
      );
    });
  }

  @visibleForTesting
  Future<void> clearForTest() async {
    _memoryPages.clear();
    _memoryMeta.clear();
    if (kIsWeb) return;
    final db = await _openDb();
    await db.delete(_feedTable);
    await db.delete(_postTable);
    await db.delete(_metaTable);
  }

  Future<void> clearForOwner(String? ownerUserId) async {
    final owner = _normalizeOwner(ownerUserId?.trim() ?? '');
    if (owner.isEmpty || owner == '_guest') {
      return;
    }
    _memoryPages.removeWhere((key, _) => key.startsWith('$owner|'));
    _memoryMeta.removeWhere((key, _) => key.startsWith('$owner|'));
    if (kIsWeb) {
      return;
    }
    final db = await _openDb();
    await db.transaction((txn) async {
      await txn.delete(
        _feedTable,
        where: 'owner_user_id = ?',
        whereArgs: [owner],
      );
      await txn.delete(
        _postTable,
        where: 'owner_user_id = ?',
        whereArgs: [owner],
      );
      await txn.delete(
        _metaTable,
        where: 'owner_user_id = ?',
        whereArgs: [owner],
      );
    });
  }

  @visibleForTesting
  Future<void> insertRawPostForTest({
    required String ownerUserId,
    required String scope,
    required String postId,
    required String payloadJson,
  }) async {
    final owner = _normalizeOwner(ownerUserId);
    final normalizedScope = _normalizeScope(scope);
    if (kIsWeb) return;
    final db = await _openDb();
    await db.transaction((txn) async {
      await txn.insert(
        _postTable,
        {
          'owner_user_id': owner,
          'moment_id': postId,
          'payload_json': payloadJson,
          'created_at': 0,
          'updated_at': 0,
          'cached_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        _feedTable,
        {
          'owner_user_id': owner,
          'scope': normalizedScope,
          'moment_id': postId,
          'rank': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  static String feedScope() => 'feed';

  static String userScope(String userId) => 'user:${userId.trim()}';

  static String _normalizeOwner(String owner) {
    final value = owner.trim();
    return value.isEmpty ? '_guest' : value;
  }

  static String _normalizeScope(String scope) {
    final value = scope.trim();
    return value.isEmpty ? feedScope() : value;
  }

  static String _memoryKey(String owner, String scope) => '$owner|$scope';
}
