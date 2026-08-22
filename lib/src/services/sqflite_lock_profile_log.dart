import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lock_profile_flags.dart';

/// 发布版可见：SQLite op/txn 与生命周期对照。过滤：`[SqfliteLock]`
///
/// 用法：进后台前后对照 `lifecycle` 的 `active=` 快照与 `txn_end costMs`。
class SqfliteLockProfileLog {
  SqfliteLockProfileLog._();

  static int _seq = 0;
  static int _nextToken = 0;
  static final Map<int, _ActiveEntry> _active = <int, _ActiveEntry>{};

  static bool get _on => SqfliteLockProfileFlags.enabled;

  /// 生命周期变化；附带当前进行中 op/txn 快照。
  static void lifecycle(AppLifecycleState state) {
    if (!_on) {
      return;
    }
    _print(
      'lifecycle',
      extras: <String, Object?>{
        'state': state.name,
        'active': _active.length,
        'snapshot': _snapshot(),
      },
    );
  }

  static int beginOp({
    required String dbTag,
    required String op,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!_on) {
      return -1;
    }
    final token = ++_nextToken;
    final startMs = DateTime.now().millisecondsSinceEpoch;
    _active[token] = _ActiveEntry(
      token: token,
      kind: 'op',
      dbTag: dbTag,
      op: op,
      startMs: startMs,
    );
    _print(
      'op_begin',
      extras: <String, Object?>{
        'db': dbTag,
        'op': op,
        'token': token,
        'active': _active.length,
        ...extras,
      },
    );
    return token;
  }

  static void endOp(
    int token, {
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!_on || token < 0) {
      return;
    }
    final entry = _active.remove(token);
    final now = DateTime.now().millisecondsSinceEpoch;
    final costMs = entry == null ? -1 : now - entry.startMs;
    _print(
      'op_end',
      extras: <String, Object?>{
        'db': entry?.dbTag ?? '-',
        'op': entry?.op ?? '-',
        'token': token,
        'costMs': costMs,
        'active': _active.length,
        ...extras,
      },
    );
  }

  static int beginTxn({
    required String dbTag,
    required String op,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!_on) {
      return -1;
    }
    final token = ++_nextToken;
    final startMs = DateTime.now().millisecondsSinceEpoch;
    _active[token] = _ActiveEntry(
      token: token,
      kind: 'txn',
      dbTag: dbTag,
      op: op,
      startMs: startMs,
    );
    _print(
      'txn_begin',
      extras: <String, Object?>{
        'db': dbTag,
        'op': op,
        'token': token,
        'active': _active.length,
        ...extras,
      },
    );
    return token;
  }

  static void endTxn(
    int token, {
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!_on || token < 0) {
      return;
    }
    final entry = _active.remove(token);
    final now = DateTime.now().millisecondsSinceEpoch;
    final costMs = entry == null ? -1 : now - entry.startMs;
    _print(
      'txn_end',
      extras: <String, Object?>{
        'db': entry?.dbTag ?? '-',
        'op': entry?.op ?? '-',
        'token': token,
        'costMs': costMs,
        'active': _active.length,
        ...extras,
      },
    );
  }

  static void event(
    String name, {
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!_on) {
      return;
    }
    _print(
      name,
      extras: <String, Object?>{
        'active': _active.length,
        ...extras,
      },
    );
  }

  static String _snapshot() {
    if (_active.isEmpty) {
      return '-';
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final parts = <String>[];
    for (final e in _active.values) {
      parts.add('${e.kind}:${e.dbTag}/${e.op}@${now - e.startMs}ms');
    }
    return parts.join('|');
  }

  static void _print(
    String event, {
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    final seq = ++_seq;
    final ms = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer('[SqfliteLock] #$seq t=$ms event=$event');
    for (final entry in extras.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      buffer.write(' ${entry.key}=$value');
    }
    // ignore: avoid_print
    print(buffer.toString());
  }
}

class _ActiveEntry {
  const _ActiveEntry({
    required this.token,
    required this.kind,
    required this.dbTag,
    required this.op,
    required this.startMs,
  });

  final int token;
  final String kind;
  final String dbTag;
  final String op;
  final int startMs;
}

/// 带 begin/end 的 `db.transaction` 薄封装；业务逻辑放进 [action]。
Future<T> profiledTransaction<T>(
  Database db, {
  required String dbTag,
  required String op,
  Map<String, Object?> extras = const <String, Object?>{},
  required Future<T> Function(Transaction txn) action,
}) async {
  final token = SqfliteLockProfileLog.beginTxn(
    dbTag: dbTag,
    op: op,
    extras: extras,
  );
  try {
    return await db.transaction((txn) => action(txn));
  } finally {
    SqfliteLockProfileLog.endTxn(token);
  }
}
