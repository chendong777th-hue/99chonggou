import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 聊天 Push 与 IM 在线消息按 msgKey 去重（§12.1）。
class PushMsgKeyDedup {
  PushMsgKeyDedup._();

  static final PushMsgKeyDedup instance = PushMsgKeyDedup._();

  final Map<String, DateTime> _seen = <String, DateTime>{};
  static const Duration _ttl = Duration(minutes: 30);
  static const int _maxEntries = 200;
  static const String _storageKey = 'im_push_msgkey_dedup_v1';
  bool _ready = false;
  int _clearGeneration = 0;
  Future<void>? _readyTask;
  Future<void>? _persistTask;

  /// Loads the small cross-restart claim ledger before an IM or Push event is
  /// adjudicated. The message body remains in Tencent SDK storage; this only
  /// prevents a remote notification and an SDK callback from double-alerting.
  Future<void> ensureReady() {
    if (_ready) {
      return Future<void>.value();
    }
    final running = _readyTask;
    if (running != null) {
      return running;
    }
    final generation = _clearGeneration;
    late final Future<void> task;
    task = _load(generation);
    _readyTask = task;
    unawaited(task.whenComplete(() {
      if (identical(_readyTask, task)) {
        _readyTask = null;
      }
    }));
    return _readyTask!;
  }

  Future<void> _load(int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _clearGeneration) {
        return;
      }
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final now = DateTime.now();
          for (final item in decoded) {
            if (item is! Map) {
              continue;
            }
            final key = normalizeKey(item['key']);
            final atMs = int.tryParse(item['atMs']?.toString() ?? '');
            if (key == null || atMs == null) {
              continue;
            }
            final at = DateTime.fromMillisecondsSinceEpoch(atMs);
            if (now.difference(at) <= _ttl) {
              _seen[key] = at;
            }
          }
        }
      }
    } catch (_) {
      // Notification delivery must remain usable when preferences are
      // temporarily unavailable; the in-memory claim is still authoritative.
    } finally {
      if (generation == _clearGeneration) {
        _ready = true;
        _purgeExpired();
      }
    }
  }

  /// Flushes the current claim ledger. Push ingress awaits this before it
  /// returns so a cold-started process cannot immediately re-alert the same
  /// message after the SDK reconnects.
  Future<void> persist() {
    final previous = _persistTask;
    late final Future<void> task;
    task = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      await ensureReady();
      try {
        final prefs = await SharedPreferences.getInstance();
        _purgeExpired();
        final value = _seen.entries
            .map(
              (entry) => <String, Object>{
                'key': entry.key,
                'atMs': entry.value.millisecondsSinceEpoch,
              },
            )
            .toList(growable: false);
        await prefs.setString(_storageKey, jsonEncode(value));
      } catch (_) {}
    }();
    _persistTask = task;
    return task.whenComplete(() {
      if (identical(_persistTask, task)) {
        _persistTask = null;
      }
    });
  }

  String? msgKeyFromMessage(V2TimMessage message) {
    final msgId = message.msgID?.trim() ?? '';
    if (msgId.isNotEmpty) {
      return msgId;
    }
    final random = message.random;
    final timestamp = message.timestamp;
    final seq = message.seq?.trim() ?? '';
    if (random != null && timestamp != null && timestamp > 0) {
      return '${random}_${timestamp}_${seq.isNotEmpty ? seq : '0'}';
    }
    return null;
  }

  String? normalizeKey(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// 是否已有通道处理过该 key（只读）。
  bool wasHandled(String? msgKey) {
    final key = normalizeKey(msgKey);
    if (key == null) {
      return false;
    }
    _purgeExpired();
    return _seen.containsKey(key);
  }

  /// 尝试占用展示权：首次返回 true，重复返回 false。
  bool tryClaim(String? msgKey) {
    final key = normalizeKey(msgKey);
    if (key == null) {
      return true;
    }
    _purgeExpired();
    if (_seen.containsKey(key)) {
      trace('claim_skip', key, 'dedup');
      return false;
    }
    _seen[key] = DateTime.now();
    _enforceCapacity();
    trace('claim_ok', key, 'dedup');
    unawaited(persist());
    return true;
  }

  /// 展示失败时释放占用，允许其它通道重试。
  void releaseClaim(String? msgKey) {
    final key = normalizeKey(msgKey);
    if (key == null) {
      return;
    }
    if (_seen.remove(key) != null) {
      trace('claim_release', key, 'dedup');
      unawaited(persist());
    }
  }

  /// 仅标记已处理，不抢占。
  void markHandled(String? msgKey) {
    final key = normalizeKey(msgKey);
    if (key == null) {
      return;
    }
    _purgeExpired();
    _seen[key] = DateTime.now();
    _enforceCapacity();
    unawaited(persist());
  }

  void trace(String action, String key, String source) {
    if (kDebugMode) {
      debugPrint('NOTIF_DEDUP action=$action key=$key source=$source');
    }
  }

  void _purgeExpired() {
    final now = DateTime.now();
    _seen.removeWhere((_, at) => now.difference(at) > _ttl);
  }

  void _enforceCapacity() {
    if (_seen.length <= _maxEntries) {
      return;
    }
    final sorted = _seen.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final removeCount = _seen.length - _maxEntries;
    for (var i = 0; i < removeCount; i += 1) {
      _seen.remove(sorted[i].key);
    }
  }

  void clear() {
    _clearGeneration += 1;
    _ready = true;
    _seen.clear();
    final previous = _persistTask;
    late final Future<void> task;
    task = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_storageKey);
      } catch (_) {}
    }();
    _persistTask = task;
    unawaited(task.whenComplete(() {
      if (identical(_persistTask, task)) {
        _persistTask = null;
      }
    }));
  }

  @visibleForTesting
  Future<void> reloadForTesting() async {
    await persist();
    _seen.clear();
    _ready = false;
    _readyTask = null;
    await ensureReady();
  }
}
