import 'dart:convert';
import 'dart:html';
import 'dart:indexed_db';

import 'package:flutter/foundation.dart';

import 'web_conversation_meta_snapshot.dart';

/// Web IndexedDB：持久化会话清空水位 / 已读清零标记（对齐移动端 SQLite 关键字段）。
class WebConversationMetaStore {
  WebConversationMetaStore._();

  static final WebConversationMetaStore instance = WebConversationMetaStore._();

  static const _dbName = 'xj_chat_conversation_meta_v1';
  static const _storeName = 'owner_meta';
  static const _dbVersion = 1;

  Future<Database> _openDb() {
    return window.indexedDB!.open(
      _dbName,
      version: _dbVersion,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final db = event.target.result as Database;
        if (!(db.objectStoreNames?.contains(_storeName) ?? false)) {
          db.createObjectStore(_storeName);
        }
      },
    );
  }

  Future<WebConversationMetaSnapshot?> load(String ownerUserId) async {
    final owner = ownerUserId.trim();
    if (owner.isEmpty) {
      return null;
    }
    try {
      final db = await _openDb();
      final txn = db.transaction(_storeName, 'readonly');
      final store = txn.objectStore(_storeName);
      final raw = await store.getObject(owner);
      await txn.completed;
      db.close();
      if (raw == null) {
        return null;
      }
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return WebConversationMetaSnapshot.fromJson(decoded);
        }
      }
      if (raw is Map) {
        return WebConversationMetaSnapshot.fromJson(
          Map<String, dynamic>.from(raw),
        );
      }
      return null;
    } catch (e, st) {
      debugPrint(
        '[WebConversationMetaStore] load failed owner=$owner err=$e\n$st',
      );
      return null;
    }
  }

  Future<void> save(
    String ownerUserId,
    WebConversationMetaSnapshot snapshot,
  ) async {
    final owner = ownerUserId.trim();
    if (owner.isEmpty) {
      return;
    }
    try {
      final db = await _openDb();
      final txn = db.transaction(_storeName, 'readwrite');
      final store = txn.objectStore(_storeName);
      final payload = jsonEncode(snapshot.toJson());
      await store.put(payload, owner);
      await txn.completed;
      db.close();
    } catch (e, st) {
      debugPrint(
        '[WebConversationMetaStore] save failed owner=$owner err=$e\n$st',
      );
    }
  }
}
