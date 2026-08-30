import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';

class ReadReceiptOutboxRecord {
  const ReadReceiptOutboxRecord({
    required this.ownerUserId,
    required this.messageId,
    required this.attemptCount,
    required this.nextRetryAtMs,
  });

  final String ownerUserId;
  final String messageId;
  final int attemptCount;
  final int nextRetryAtMs;
}

/// Durable at-least-once queue for peer read receipts.
///
/// Rows are inserted before the SDK call and removed only after code == 0.
/// Duplicate receipt submission is safe and preferable to silently losing it.
class ReadReceiptOutboxStore {
  ReadReceiptOutboxStore._();

  static final ReadReceiptOutboxStore instance =
      ReadReceiptOutboxStore._();

  static const _table = 'read_receipt_outbox';
  static const int maxRetryAttempts = 10;
  static const int _deadLetterRetryAtMs = 253402300799000;
  final Map<String, ReadReceiptOutboxRecord> _webRows =
      <String, ReadReceiptOutboxRecord>{};
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
          message_id TEXT NOT NULL,
          attempt_count INTEGER NOT NULL DEFAULT 0,
          next_retry_at INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (owner_user_id, message_id)
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_read_receipt_outbox_due
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
    required Iterable<String> messageIds,
  }) async {
    final owner = ownerUserId.trim();
    final ids = messageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (owner.isEmpty || ids.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) {
      for (final id in ids) {
        _webRows.putIfAbsent(
          '$owner|$id',
          () => ReadReceiptOutboxRecord(
            ownerUserId: owner,
            messageId: id,
            attemptCount: 0,
            nextRetryAtMs: 0,
          ),
        );
      }
      return;
    }
    await _ensureSchema();
    await ConversationLocalStore.instance
        .runImIngressTransaction<void>((db) async {
      for (final id in ids) {
        await db.rawInsert('''
          INSERT OR IGNORE INTO $_table (
            owner_user_id, message_id, attempt_count, next_retry_at,
            created_at, updated_at
          ) VALUES (?, ?, 0, 0, ?, ?)
        ''', <Object?>[owner, id, now, now]);
      }
    });
  }

  Future<void> acknowledge({
    required String ownerUserId,
    required Iterable<String> messageIds,
  }) async {
    final owner = ownerUserId.trim();
    final ids = messageIds.map((id) => id.trim()).where((id) => id.isNotEmpty);
    if (owner.isEmpty) return;
    if (kIsWeb) {
      for (final id in ids) {
        _webRows.remove('$owner|$id');
      }
      return;
    }
    await _ensureSchema();
    await ConversationLocalStore.instance
        .runImIngressTransaction<void>((db) async {
      for (final id in ids) {
        await db.delete(
          _table,
          where: 'owner_user_id = ? AND message_id = ?',
          whereArgs: <Object?>[owner, id],
        );
      }
    });
  }

  Future<List<ReadReceiptOutboxRecord>> listDue({
    required String ownerUserId,
    int limit = 100,
  }) async {
    final owner = ownerUserId.trim();
    if (owner.isEmpty) return const <ReadReceiptOutboxRecord>[];
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
        .runImIngressTransaction<List<ReadReceiptOutboxRecord>>((db) async {
      final rows = await db.query(
        _table,
        where: 'owner_user_id = ? AND next_retry_at <= ?',
        whereArgs: <Object?>[owner, now],
        orderBy: 'next_retry_at ASC, created_at ASC',
        limit: limit,
      );
      return rows
          .map((row) => ReadReceiptOutboxRecord(
                ownerUserId: row['owner_user_id']?.toString() ?? '',
                messageId: row['message_id']?.toString() ?? '',
                attemptCount: row['attempt_count'] as int? ?? 0,
                nextRetryAtMs: row['next_retry_at'] as int? ?? 0,
              ))
          .toList(growable: false);
    });
  }

  Future<void> markRetry({
    required String ownerUserId,
    required Iterable<ReadReceiptOutboxRecord> records,
  }) async {
    final owner = ownerUserId.trim();
    if (owner.isEmpty) return;
    final rows = records.toList(growable: false);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) {
      for (final row in rows) {
        final attempt = row.attemptCount + 1;
        _webRows['$owner|${row.messageId}'] = ReadReceiptOutboxRecord(
          ownerUserId: owner,
          messageId: row.messageId,
          attemptCount: attempt,
          nextRetryAtMs: attempt >= maxRetryAttempts
              ? _deadLetterRetryAtMs
              : now + _backoffMs(attempt),
        );
      }
      return;
    }
    await _ensureSchema();
    await ConversationLocalStore.instance
        .runImIngressTransaction<void>((db) async {
      for (final row in rows) {
        final attempt = row.attemptCount + 1;
        await db.update(
          _table,
          <String, Object?>{
            'attempt_count': attempt,
            'next_retry_at': attempt >= maxRetryAttempts
                ? _deadLetterRetryAtMs
                : now + _backoffMs(attempt),
            'updated_at': now,
          },
          where: 'owner_user_id = ? AND message_id = ?',
          whereArgs: <Object?>[owner, row.messageId],
        );
      }
    });
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
