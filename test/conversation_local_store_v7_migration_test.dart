import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v6 database adds fingerprint column in place and keeps legacy rows',
      () async {
    final basePath = await getDatabasesPath();
    final dbPath = '$basePath${Platform.pathSeparator}conversation_local_v1.db';
    await deleteDatabase(dbPath);

    final legacyConversation = V2TimConversation(
      conversationID: 'c2c_migration_peer',
      type: 1,
      userID: 'migration_peer',
      showName: 'Migration peer',
      unreadCount: 3,
      orderkey: 99,
      customData: 'legacy-data',
    );
    final rawJson = jsonEncode(legacyConversation.toJson());

    final legacyDb = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
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
            updated_at INTEGER NOT NULL DEFAULT 0,
            read_cleared_at INTEGER NOT NULL DEFAULT 0,
            history_cleared_at INTEGER NOT NULL DEFAULT 0,
            local_draft_text TEXT NOT NULL DEFAULT '',
            local_draft_updated_at INTEGER NOT NULL DEFAULT 0,
            last_msg_id TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (owner_user_id, conversation_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE conversation_sync_meta (
            owner_user_id TEXT PRIMARY KEY,
            next_seq TEXT NOT NULL DEFAULT '0',
            have_more INTEGER NOT NULL DEFAULT 1,
            has_synced_once INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    await legacyDb.insert('conversations', <String, Object?>{
      'owner_user_id': 'migration_owner',
      'conversation_id': legacyConversation.conversationID,
      'conv_type': legacyConversation.type,
      'user_id': legacyConversation.userID,
      'show_name': legacyConversation.showName,
      'unread_count': legacyConversation.unreadCount,
      'order_key': legacyConversation.orderkey,
      'active_time': legacyConversation.orderkey,
      'raw_json': rawJson,
    });
    await legacyDb.close();

    ConversationLocalStore.bypassUpsertCoalesceForTest = true;
    ConversationLocalStore.instance.debugOwnerUserId = 'migration_owner';

    final restored = await ConversationLocalStore.instance.conversationById(
      legacyConversation.conversationID,
    );
    expect(restored?.customData, 'legacy-data');
    expect(restored?.unreadCount, 3);

    final inspectionDb = await openDatabase(
      dbPath,
      readOnly: true,
      singleInstance: false,
    );
    final versionRows = await inspectionDb.rawQuery('PRAGMA user_version');
    final version = versionRows.single.values.single as int;
    final columns = await inspectionDb.rawQuery(
      'PRAGMA table_info(conversations)',
    );
    // Store 当前 _dbVersion=7：打开旧库会执行 v7 type 索引升级。
    expect(version, 7);
    expect(
      columns.any((row) => row['name'] == 'raw_json_fingerprint'),
      isTrue,
    );
    final countRows =
        await inspectionDb.rawQuery('SELECT COUNT(*) FROM conversations');
    expect(countRows.single.values.single, 1);
    await inspectionDb.close();

    final migrated = await ConversationLocalStore.instance.upsertBatch(
      conversations: [legacyConversation],
    );
    expect(migrated, hasLength(1));

    final fingerprintDb = await openDatabase(
      dbPath,
      readOnly: true,
      singleInstance: false,
    );
    final rows = await fingerprintDb.query(
      'conversations',
      columns: const ['raw_json', 'raw_json_fingerprint'],
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: const ['migration_owner', 'c2c_migration_peer'],
    );
    expect(rows, hasLength(1));
    final persistedJson =
        jsonDecode(rows.single['raw_json']! as String) as Map<String, dynamic>;
    expect(persistedJson['conv_custom_data'], 'legacy-data');
    expect(persistedJson['conv_unread_num'], 3);
    expect(rows.single['raw_json_fingerprint'], isNotEmpty);
    await fingerprintDb.close();

    ConversationLocalStore.instance.debugOwnerUserId = null;
  });
}
