// IM-08 P0-High B2 完整修复：撤回事件本地账本
//
// vendor tui_chat_separate_view_model.dart 主动撤回调 SDK revokeMessage
// (line 5856/7834/8409)。SDK 成功后应触发 onRecvMessageRevoked,
// 但事件可能被丢弃/延迟,导致:
//  - UI 已通过 applyAppMessageRevoked 更新,但下次冷启动不知道哪些 msgID 撤回过
//  - 历史回放时,撤回事件和原消息同时出现,渲染顺序依赖 SDK listener
//
// 本 ledger 由 tencent_advanced_message_adapter._submitRevoked 调用,
// 持久化每个收到的撤回 msgID + ownerUserId,跨重启可查。
//
// 注意:vendor 不能改,所以"主动撤回 SDK 失败"仍然无法拦截。本 ledger
// 只解决"SDK 成功但回调丢失"的情况。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageWithdrawLedger {
  MessageWithdrawLedger._();

  static final MessageWithdrawLedger instance = MessageWithdrawLedger._();

  static const String _storageKey = 'im_withdraw_ledger_v1';
  static const Duration _ttl = Duration(days: 30);
  static const int _maxEntries = 5000;

  final Map<String, int> _entries = <String, int>{}; // msgID -> observedAtMs
  int _clearGeneration = 0;
  Future<void>? _readyTask;
  Future<void>? _persistTask;
  bool _ready = false;

  Future<void> ensureReady() {
    if (_ready) return Future<void>.value();
    final running = _readyTask;
    if (running != null) return running;
    final generation = _clearGeneration;
    late final Future<void> task;
    task = _load(generation);
    _readyTask = task;
    unawaited(task.whenComplete(() {
      if (identical(_readyTask, task)) _readyTask = null;
    }));
    return _readyTask!;
  }

  Future<void> _load(int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _clearGeneration) return;
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final item in decoded) {
        if (item is! Map) continue;
        final id = item['id']?.toString().trim() ?? '';
        final atMs = int.tryParse(item['atMs']?.toString() ?? '');
        if (id.isEmpty || atMs == null) continue;
        if (now - atMs <= _ttl.inMilliseconds) {
          _entries[id] = atMs;
        }
      }
    } catch (_) {
      // ledger 加载失败不应阻塞 UI/SDK 路径
    } finally {
      if (generation == _clearGeneration) {
        _ready = true;
        _purgeExpired();
      }
    }
  }

  Future<void> persist() {
    final previous = _persistTask;
    late final Future<void> task;
    task = () async {
      if (previous != null) {
        try { await previous; } catch (_) {}
      }
      await ensureReady();
      try {
        final prefs = await SharedPreferences.getInstance();
        _purgeExpired();
        final payload = _entries.entries
            .map((e) => <String, Object>{
              'id': e.key,
              'atMs': e.value,
            })
            .toList(growable: false);
        await prefs.setString(_storageKey, jsonEncode(payload));
      } catch (_) {}
    }();
    _persistTask = task;
    return task.whenComplete(() {
      if (identical(_persistTask, task)) _persistTask = null;
    });
  }

  /// 记录一条撤回事件。供 tencent_advanced_message_adapter._submitRevoked 调用。
  Future<void> recordRevoked(String msgID) async {
    final id = msgID.trim();
    if (id.isEmpty) return;
    await ensureReady();
    _entries[id] = DateTime.now().millisecondsSinceEpoch;
    if (_entries.length > _maxEntries) {
      _purgeExpired();
    }
    unawaited(persist());
  }

  /// 是否记录过该 msgID 被撤回。
  Future<bool> wasRevoked(String msgID) async {
    final id = msgID.trim();
    if (id.isEmpty) return false;
    await ensureReady();
    final atMs = _entries[id];
    if (atMs == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - atMs;
    if (age > _ttl.inMilliseconds) {
      _entries.remove(id);
      return false;
    }
    return true;
  }

  void _purgeExpired() {
    final cutoff = DateTime.now().millisecondsSinceEpoch - _ttl.inMilliseconds;
    _entries.removeWhere((_, atMs) => atMs < cutoff);
  }

  /// 切账号时清空本地账本(冷启动恢复后由 SDK listener 重建)。
  void clearLocal() {
    _clearGeneration++;
    _entries.clear();
    _ready = false;
  }

  @visibleForTesting
  Map<String, int> debugEntries() => Map<String, int>.unmodifiable(_entries);
}
