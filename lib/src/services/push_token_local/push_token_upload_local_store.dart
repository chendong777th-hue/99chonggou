import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

class PushTokenUploadLocalStore {
  PushTokenUploadLocalStore._();

  static final PushTokenUploadLocalStore instance = PushTokenUploadLocalStore._();

  static const _dbName = 'push_token_upload_local_v1.db';
  static const _table = 'push_token_uploads';

  Database? _db;
  bool _factoryReady = false;
  final Set<String> _memoryUploadedKeys = <String>{};

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

  bool get _useMemoryOnly => kIsWeb;

  Future<Database> _openDb() async {
    final existing = SqfliteLifecycleGuard.beforeOpen(_db);
    if (existing != null) {
      return existing;
    }
    await _ensureDatabaseFactory();
    final basePath = await getDatabasesPath();
    final dbPath = p.join(basePath, _dbName);
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            owner_user_id TEXT NOT NULL,
            device_id TEXT NOT NULL,
            platform TEXT NOT NULL,
            token_key_hash TEXT NOT NULL,
            uploaded_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(owner_user_id, device_id, platform, token_key_hash)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_push_token_upload_owner ON $_table(owner_user_id)',
        );
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

  String _memoryKey({
    required String ownerUserId,
    required String deviceId,
    required String platform,
    required String tokenKeyHash,
  }) {
    return '$ownerUserId|$deviceId|$platform|$tokenKeyHash';
  }

  Future<bool> hasSuccess({
    required String deviceId,
    required String platform,
    required String tokenKeyHash,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final normalizedDeviceId = deviceId.trim();
    final normalizedPlatform = platform.trim().toUpperCase();
    final normalizedHash = tokenKeyHash.trim();
    if (owner.isEmpty ||
        normalizedDeviceId.isEmpty ||
        normalizedPlatform.isEmpty ||
        normalizedHash.isEmpty) {
      return false;
    }
    if (_useMemoryOnly) {
      return _memoryUploadedKeys.contains(
        _memoryKey(
          ownerUserId: owner,
          deviceId: normalizedDeviceId,
          platform: normalizedPlatform,
          tokenKeyHash: normalizedHash,
        ),
      );
    }
    final db = await _openDb();
    final rows = await db.query(
      _table,
      columns: const ['token_key_hash'],
      where:
          'owner_user_id = ? AND device_id = ? AND platform = ? AND token_key_hash = ?',
      whereArgs: [owner, normalizedDeviceId, normalizedPlatform, normalizedHash],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> markSuccess({
    required String deviceId,
    required String platform,
    required String tokenKeyHash,
    String? ownerUserId,
  }) async {
    final owner = _resolveOwner(ownerUserId);
    final normalizedDeviceId = deviceId.trim();
    final normalizedPlatform = platform.trim().toUpperCase();
    final normalizedHash = tokenKeyHash.trim();
    if (owner.isEmpty ||
        normalizedDeviceId.isEmpty ||
        normalizedPlatform.isEmpty ||
        normalizedHash.isEmpty) {
      return;
    }
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      _memoryUploadedKeys.add(
        _memoryKey(
          ownerUserId: owner,
          deviceId: normalizedDeviceId,
          platform: normalizedPlatform,
          tokenKeyHash: normalizedHash,
        ),
      );
      return;
    }
    final db = await _openDb();
    await db.insert(
      _table,
      <String, Object?>{
        'owner_user_id': owner,
        'device_id': normalizedDeviceId,
        'platform': normalizedPlatform,
        'token_key_hash': normalizedHash,
        'uploaded_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearForCurrentOwner() async {
    await clearForOwner(currentOwnerUserId());
  }

  Future<void> clearForOwner(String? ownerUserId) async {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    if (_useMemoryOnly) {
      _memoryUploadedKeys.removeWhere((key) => key.startsWith('$owner|'));
      return;
    }
    final db = await _openDb();
    await db.delete(_table, where: 'owner_user_id = ?', whereArgs: [owner]);
  }

  Future<void> clearAll() async {
    if (_useMemoryOnly) {
      _memoryUploadedKeys.clear();
      return;
    }
    final db = _db;
    if (db == null) {
      return;
    }
    await db.delete(_table);
  }
}
