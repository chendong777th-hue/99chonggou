import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class RedPacketOpenedRecord {
  final String orderId;
  final int openedAt;
  final bool claimed;

  const RedPacketOpenedRecord({
    required this.orderId,
    required this.openedAt,
    this.claimed = false,
  });
}

/// 记录用户已点击/拆开过的红包（按登录账号 + orderId 隔离）。
class RedPacketLocalStore {
  RedPacketLocalStore._();

  static final RedPacketLocalStore instance = RedPacketLocalStore._();

  static const _dbName = 'red_packet_local_v1.db';
  static const _table = 'opened_red_packets';

  Database? _db;
  bool _factoryReady = false;

  /// owner -> orderId -> record
  final Map<String, Map<String, RedPacketOpenedRecord>> _memoryByOwner = {};

  bool get _useMemoryOnly => kIsWeb;

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
      version: 2,
      onCreate: (db, version) async {
        await _createTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN claimed INTEGER NOT NULL DEFAULT 0',
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

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_table (
        owner_user_id TEXT NOT NULL,
        order_id TEXT NOT NULL,
        opened_at INTEGER NOT NULL DEFAULT 0,
        claimed INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (owner_user_id, order_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_red_packet_opened_owner ON $_table(owner_user_id)',
    );
  }

  String currentOwnerUserId() {
    final fromContact =
        ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
    if (fromContact.isNotEmpty) return fromContact;
    try {
      return ChatIdFormat.rawUserUid(
        TIMUIKitCore.getInstance().loginInfo.userID,
      );
    } catch (_) {
      return '';
    }
  }

  String _resolveOwner(String? ownerUserId) {
    final explicit = ChatIdFormat.rawUserUid(ownerUserId);
    if (explicit.isNotEmpty) return explicit;
    return currentOwnerUserId();
  }

  Map<String, RedPacketOpenedRecord> _memoryForOwner(String owner) {
    return _memoryByOwner.putIfAbsent(owner, () => {});
  }

  /// 同步读取内存缓存，供卡片 build 时立即反映「已点击」样式。
  RedPacketOpenedRecord? peekOpened({
    required String orderId,
    String? ownerUserId,
  }) {
    final id = orderId.trim();
    if (id.isEmpty) return null;
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) return null;
    return _memoryForOwner(owner)[id];
  }

  Future<RedPacketOpenedRecord?> getOpened({
    required String orderId,
    String? ownerUserId,
  }) async {
    final id = orderId.trim();
    if (id.isEmpty) return null;
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) return null;

    final cached = _memoryForOwner(owner)[id];
    if (cached != null) return cached;

    if (_useMemoryOnly) return null;

    final db = await _openDb();
    final rows = await db.query(
      _table,
      where: 'owner_user_id = ? AND order_id = ?',
      whereArgs: [owner, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final record = RedPacketOpenedRecord(
      orderId: id,
      openedAt: row['opened_at'] as int? ?? 0,
      claimed: (row['claimed'] as int? ?? 0) == 1,
    );
    _memoryForOwner(owner)[id] = record;
    return record;
  }

  Future<bool> isOpened({
    required String orderId,
    String? ownerUserId,
  }) async {
    final record = await getOpened(orderId: orderId, ownerUserId: ownerUserId);
    return record != null;
  }

  Future<void> markOpened({
    required String orderId,
    String? ownerUserId,
    int? openedAt,
    bool claimed = false,
    Iterable<String> aliasOrderIds = const [],
  }) async {
    final id = orderId.trim();
    if (id.isEmpty) return;
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) return;
    final ts = openedAt ?? DateTime.now().millisecondsSinceEpoch;

    final keys = <String>{
      id,
      for (final alias in aliasOrderIds)
        if (alias.trim().isNotEmpty) alias.trim(),
    };

    RedPacketOpenedRecord? existing;
    for (final key in keys) {
      existing ??= _memoryForOwner(owner)[key];
    }
    final nextClaimed = claimed || (existing?.claimed ?? false);
    final record = RedPacketOpenedRecord(
      orderId: id,
      openedAt: ts,
      claimed: nextClaimed,
    );

    for (final key in keys) {
      _memoryForOwner(owner)[key] = record;
    }

    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) return;

    final db = await _openDb();
    for (final key in keys) {
      await db.insert(
        _table,
        {
          'owner_user_id': owner,
          'order_id': key,
          'opened_at': ts,
          'claimed': nextClaimed ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  @visibleForTesting
  Future<void> clearForTest() async {
    _memoryByOwner.clear();
    final db = _db;
    if (db != null) {
      await db.delete(_table);
    }
  }

  Future<void> clearForOwner(String? ownerUserId) async {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
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
}
