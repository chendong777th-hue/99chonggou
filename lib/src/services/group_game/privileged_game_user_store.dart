import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 特权用户（群游戏）状态本地库，按登录账号隔离。
class PrivilegedGameUserStore {
  PrivilegedGameUserStore._();

  static final PrivilegedGameUserStore instance = PrivilegedGameUserStore._();

  static const _dbName = 'privileged_game_user_v1.db';
  static const _table = 'privileged_game_users';

  Database? _db;
  final Map<String, bool> _memoryByOwner = {};
  bool _factoryReady = false;

  bool get _useMemoryOnly => kIsWeb;

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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            owner_user_id TEXT PRIMARY KEY,
            game_enabled INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0
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

  Future<bool?> read({String? ownerUserId}) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    if (_useMemoryOnly) {
      return _memoryByOwner[owner];
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      columns: const ['game_enabled'],
      where: 'owner_user_id = ?',
      whereArgs: [owner],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final raw = rows.first['game_enabled'];
    if (raw is int) {
      return raw != 0;
    }
    if (raw is bool) {
      return raw;
    }
    return null;
  }

  Future<void> write({
    required String ownerUserId,
    required bool gameEnabled,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      _memoryByOwner[owner] = gameEnabled;
      return;
    }
    final db = await _openDb();
    await db.insert(
      _table,
      {
        'owner_user_id': owner,
        'game_enabled': gameEnabled ? 1 : 0,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearOwner(String ownerUserId) async {
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    _memoryByOwner.remove(owner);
    if (_useMemoryOnly) {
      return;
    }
    final db = await _openDb();
    await db.delete(
      _table,
      where: 'owner_user_id = ?',
      whereArgs: [owner],
    );
  }
}
