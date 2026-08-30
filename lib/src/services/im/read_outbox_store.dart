import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';

class ConversationReadOutboxRecord {
  const ConversationReadOutboxRecord({
    required this.ownerUserId,
    required this.conversationId,
    required this.lastReadMessageId,
    required this.lastReadAtMs,
    required this.attemptCount,
    required this.nextRetryAtMs,
  });

  final String ownerUserId;
  final String conversationId;
  final String lastReadMessageId;
  final int lastReadAtMs;
  final int attemptCount;
  final int nextRetryAtMs;
}

/// Durable conversation mark-read queue, scoped by account.
class ConversationReadOutboxStore {
  ConversationReadOutboxStore._();

  static final ConversationReadOutboxStore instance =
      ConversationReadOutboxStore._();
  static const _table = 'conversation_read_outbox';
  static const int maxRetryAttempts = 10;
  static const int _deadLetterRetryAtMs = 253402300799000;
  final Map<String, ConversationReadOutboxRecord> _webRows =
      <String, ConversationReadOutboxRecord>{};
  Future<void>? _schemaInFlight;
  bool _schemaReady = false;

  Future<void> _ensureSchema() {
    if (kIsWeb || _schemaReady) return Future<void>.value();
    final running = _schemaInFlight;
    if (running != null) return running;
    final task = ConversationLocalStore.instance
        .runImIngressTransaction<void>((db) async {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_table (
          owner_user_id TEXT NOT NULL,
          conversation_id TEXT NOT NULL,
          last_read_message_id TEXT NOT NULL DEFAULT '',
          last_read_at INTEGER NOT NULL DEFAULT 0,
          attempt_count INTEGER NOT NULL DEFAULT 0,
          next_retry_at INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (owner_user_id, conversation_id)
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_conversation_read_outbox_due
        ON $_table(owner_user_id, next_retry_at)
      ''');
    });
    _schemaInFlight = task;
    return task.then((_) {
      _schemaReady = true;
    }).whenComplete(() {
      if (identical(_schemaInFlight, task)) _schemaInFlight = null;
    });
  }

  Future<void> enqueue({
    required String ownerUserId,
    required String conversationId,
    String lastReadMessageId = '',
    int? lastReadAtMs,
  }) async {
    final owner = ownerUserId.trim();
    final conversation = conversationId.trim();
    if (owner.isEmpty || conversation.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final readAt = lastReadAtMs ?? now;
    final record = ConversationReadOutboxRecord(
      ownerUserId: owner,
      conversationId: conversation,
      lastReadMessageId: lastReadMessageId.trim(),
      lastReadAtMs: readAt,
      attemptCount: 0,
      nextRetryAtMs: 0,
    );
    if (kIsWeb) {
      final key = '$owner|$conversation';
      final current = _webRows[key];
      if (current == null || current.lastReadAtMs <= readAt) {
        _webRows[key] = record;
      }
      return;
    }
    await _ensureSchema();
    await ConversationLocalStore.instance.runImIngressTransaction<void>(
      (db) async {
        final current = await db.query(
          _table,
          columns: <String>['last_read_at', 'created_at'],
          where: 'owner_user_id = ? AND conversation_id = ?',
          whereArgs: <Object?>[owner, conversation],
          limit: 1,
        );
        final currentReadAt = current.isEmpty
            ? -1
            : (current.first['last_read_at'] as int? ?? -1);
        if (currentReadAt > readAt) return;
        final createdAt = current.isEmpty
            ? now
            : (current.first['created_at'] as int? ?? now);
        await db.rawInsert('''
          INSERT OR REPLACE INTO $_table (
            owner_user_id, conversation_id, last_read_message_id,
            last_read_at, attempt_count, next_retry_at, created_at, updated_at
          ) VALUES (?, ?, ?, ?, 0, 0, ?, ?)
        ''', <Object?>[
          owner,
          conversation,
          record.lastReadMessageId,
          readAt,
          createdAt,
          now,
        ]);
      },
    );
  }

  Future<void> enqueueMany({
    required String ownerUserId,
    required Iterable<String> conversationIds,
    int? lastReadAtMs,
  }) async {
    final owner = ownerUserId.trim();
    final ids = conversationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (owner.isEmpty || ids.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final readAt = lastReadAtMs ?? now;
    if (kIsWeb) {
      for (final id in ids) {
        final key = '$owner|$id';
        final current = _webRows[key];
        if (current != null && current.lastReadAtMs > readAt) continue;
        _webRows[key] = ConversationReadOutboxRecord(
          ownerUserId: owner,
          conversationId: id,
          lastReadMessageId: '',
          lastReadAtMs: readAt,
          attemptCount: 0,
          nextRetryAtMs: 0,
        );
      }
      return;
    }
    await _ensureSchema();
    await ConversationLocalStore.instance
        .runImIngressTransaction<void>((db) async {
      for (final id in ids) {
        final current = await db.query(
          _table,
          columns: <String>['last_read_at', 'created_at'],
          where: 'owner_user_id = ? AND conversation_id = ?',
          whereArgs: <Object?>[owner, id],
          limit: 1,
        );
        final currentReadAt = current.isEmpty
            ? -1
            : (current.first['last_read_at'] as int? ?? -1);
        if (currentReadAt > readAt) continue;
        final createdAt = current.isEmpty
            ? now
            : (current.first['created_at'] as int? ?? now);
        await db.rawInsert('''
          INSERT OR REPLACE INTO $_table (
            owner_user_id, conversation_id, last_read_message_id,
            last_read_at, attempt_count, next_retry_at, created_at, updated_at
          ) VALUES (?, ?, '', ?, 0, 0, ?, ?)
        ''', <Object?>[owner, id, readAt, createdAt, now]);
      }
    });
  }

  Future<void> acknowledge({
    required String ownerUserId,
    required String conversationId,
    required int lastReadAtMs,
  }) async {
    final owner = ownerUserId.trim();
    final conversation = conversationId.trim();
    if (owner.isEmpty || conversation.isEmpty) return;
    if (kIsWeb) {
      final key = '$owner|$conversation';
      final current = _webRows[key];
      if (current != null && current.lastReadAtMs <= lastReadAtMs) {
        _webRows.remove(key);
      }
      return;
    }
    await _ensureSchema();
    await ConversationLocalStore.instance.runImIngressTransaction<void>(
      (db) async {
        await db.delete(
          _table,
          where:
              'owner_user_id = ? AND conversation_id = ? AND last_read_at <= ?',
          whereArgs: <Object?>[owner, conversation, lastReadAtMs],
        );
      },
    );
  }

  Future<void> acknowledgeMany({
    required String ownerUserId,
    required Iterable<String> conversationIds,
    required int lastReadAtMs,
  }) async {
    final owner = ownerUserId.trim();
    final ids = conversationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (owner.isEmpty || ids.isEmpty) return;
    if (kIsWeb) {
      for (final id in ids) {
        final key = '$owner|$id';
        final current = _webRows[key];
        if (current != null && current.lastReadAtMs <= lastReadAtMs) {
          _webRows.remove(key);
        }
      }
      return;
    }
    await _ensureSchema();
    await ConversationLocalStore.instance
        .runImIngressTransaction<void>((db) async {
      for (final id in ids) {
        await db.delete(
          _table,
          where:
              'owner_user_id = ? AND conversation_id = ? AND last_read_at <= ?',
          whereArgs: <Object?>[owner, id, lastReadAtMs],
        );
      }
    });
  }

  Future<List<ConversationReadOutboxRecord>> listDue({
    required String ownerUserId,
    int limit = 500,
  }) async {
    final owner = ownerUserId.trim();
    if (owner.isEmpty) return const <ConversationReadOutboxRecord>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) {
      return _webRows.values
          .where((row) =>
              row.ownerUserId == owner && row.nextRetryAtMs <= now)
          .take(limit)
          .toList(growable: false);
    }
    await _ensureSchema();
    return ConversationLocalStore.instance
        .runImIngressTransaction<List<ConversationReadOutboxRecord>>(
      (db) async {
        final rows = await db.query(
          _table,
          where: 'owner_user_id = ? AND next_retry_at <= ?',
          whereArgs: <Object?>[owner, now],
          orderBy: 'next_retry_at ASC, updated_at ASC',
          limit: limit,
        );
        return rows
            .map((row) => ConversationReadOutboxRecord(
                  ownerUserId: row['owner_user_id']?.toString() ?? '',
                  conversationId:
                      row['conversation_id']?.toString() ?? '',
                  lastReadMessageId:
                      row['last_read_message_id']?.toString() ?? '',
                  lastReadAtMs: row['last_read_at'] as int? ?? 0,
                  attemptCount: row['attempt_count'] as int? ?? 0,
                  nextRetryAtMs: row['next_retry_at'] as int? ?? 0,
                ))
            .toList(growable: false);
      },
    );
  }

  Future<void> markRetry(ConversationReadOutboxRecord record) async {
    final attempt = record.attemptCount + 1;
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = attempt >= maxRetryAttempts
        ? _deadLetterRetryAtMs
        : now + _backoffMs(attempt);
    if (kIsWeb) {
      final key = '${record.ownerUserId}|${record.conversationId}';
      final current = _webRows[key];
      if (current == null || current.lastReadAtMs != record.lastReadAtMs) {
        return;
      }
      _webRows[key] = ConversationReadOutboxRecord(
        ownerUserId: record.ownerUserId,
        conversationId: record.conversationId,
        lastReadMessageId: record.lastReadMessageId,
        lastReadAtMs: record.lastReadAtMs,
        attemptCount: attempt,
        nextRetryAtMs: next,
      );
      return;
    }
    await _ensureSchema();
    await ConversationLocalStore.instance.runImIngressTransaction<void>(
      (db) async {
        await db.update(
          _table,
          <String, Object?>{
            'attempt_count': attempt,
            'next_retry_at': next,
            'updated_at': now,
          },
          where:
              'owner_user_id = ? AND conversation_id = ? AND last_read_at = ?',
          whereArgs: <Object?>[
            record.ownerUserId,
            record.conversationId,
            record.lastReadAtMs,
          ],
        );
      },
    );
  }

  Future<void> clearOwner(String ownerUserId) async {
    final owner = ownerUserId.trim();
    if (owner.isEmpty) return;
    _webRows.removeWhere((key, _) => key.startsWith('$owner|'));
    if (kIsWeb) return;
    await _ensureSchema();
    await ConversationLocalStore.instance.runImIngressTransaction<void>(
      (db) async {
        await db.delete(
          _table,
          where: 'owner_user_id = ?',
          whereArgs: <Object?>[owner],
        );
      },
    );
  }
}

int _backoffMs(int attempt) {
  final exponent = attempt > 6 ? 6 : attempt;
  return (1 << exponent) * 1000;
}
