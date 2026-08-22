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

  test('v6 database upgrades to v7 with idx_conv_owner_type_sort', () async {
    final basePath = await getDatabasesPath();
    final dbPath = '$basePath${Platform.pathSeparator}conversation_local_v1.db';
    await deleteDatabase(dbPath);

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
        await db.execute('''
          CREATE TABLE conversation_sync_meta (
            owner_user_id TEXT PRIMARY KEY,
            next_seq TEXT NOT NULL DEFAULT '0',
            have_more INTEGER NOT NULL DEFAULT 1,
            has_synced_once INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_conv_owner_sort ON conversations(owner_user_id, is_pinned DESC, active_time DESC, order_key DESC)',
        );
      },
    );
    await legacyDb.insert('conversations', <String, Object?>{
      'owner_user_id': 'type_idx_owner',
      'conversation_id': 'c2c_peer',
      'conv_type': 1,
      'user_id': 'peer',
      'show_name': 'Peer',
      'unread_count': 1,
      'order_key': 100,
      'active_time': 100,
      'raw_json': '{}',
    });
    await legacyDb.insert('conversations', <String, Object?>{
      'owner_user_id': 'type_idx_owner',
      'conversation_id': 'group_g1',
      'conv_type': 2,
      'group_id': 'g1',
      'show_name': 'Group',
      'unread_count': 0,
      'order_key': 90,
      'active_time': 90,
      'raw_json': '{}',
    });
    await legacyDb.close();

    ConversationLocalStore.instance.debugOwnerUserId = 'type_idx_owner';
    await ConversationLocalStore.instance.closeDatabaseForTest();

    final window = await ConversationLocalStore.instance.loadUiWindow();
    expect(window, isNotEmpty);

    final inspectionDb = await openDatabase(
      dbPath,
      readOnly: true,
      singleInstance: false,
    );
    final versionRows = await inspectionDb.rawQuery('PRAGMA user_version');
    expect(versionRows.single.values.single, 7);

    final indexes = await inspectionDb.rawQuery(
      "PRAGMA index_list('conversations')",
    );
    final indexNames = indexes.map((row) => '${row['name']}').toSet();
    expect(indexNames.contains('idx_conv_owner_type_sort'), isTrue);

    final info = await inspectionDb.rawQuery(
      "PRAGMA index_info('idx_conv_owner_type_sort')",
    );
    final columns = info.map((row) => '${row['name']}').toList();
    expect(columns.take(2).toList(), ['owner_user_id', 'conv_type']);
    await inspectionDb.close();

    ConversationLocalStore.instance.debugOwnerUserId = null;
    await ConversationLocalStore.instance.closeDatabaseForTest();
  });

  test('fresh database creates type sort index onCreate', () async {
    final basePath = await getDatabasesPath();
    final dbPath = '$basePath${Platform.pathSeparator}conversation_local_v1.db';
    await deleteDatabase(dbPath);

    ConversationLocalStore.instance.debugOwnerUserId = 'fresh_owner';
    await ConversationLocalStore.instance.closeDatabaseForTest();
    await ConversationLocalStore.instance.upsertBatch(
      conversations: [
        V2TimConversation(
          conversationID: 'c2c_x',
          type: 1,
          userID: 'x',
          showName: 'X',
          orderkey: 1,
        ),
      ],
    );

    final inspectionDb = await openDatabase(
      dbPath,
      readOnly: true,
      singleInstance: false,
    );
    final indexes = await inspectionDb.rawQuery(
      "PRAGMA index_list('conversations')",
    );
    final indexNames = indexes.map((row) => '${row['name']}').toSet();
    expect(indexNames.contains('idx_conv_owner_type_sort'), isTrue);
    await inspectionDb.close();

    ConversationLocalStore.instance.debugOwnerUserId = null;
    await ConversationLocalStore.instance.closeDatabaseForTest();
  });
}
