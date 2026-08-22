import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_record.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';

/// 按 callId 缓存通话终态结果，供聊天气泡解析优先读取。
class CallResultRepository {
  CallResultRepository._();

  static final CallResultRepository instance = CallResultRepository._();

  static const String _prefsKey = 'call_result_canonical_v1';
  static const int _maxRecords = 128;

  final Map<String, CallResultRecord> _records = <String, CallResultRecord>{};
  bool _loaded = false;
  Future<void>? _loadTask;

  /// Bumped when a record is written; chat pages re-normalize bubbles.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  CallResultRecord? get(String callId) {
    final id = callId.trim();
    if (id.isEmpty) {
      return null;
    }
    return _records[id];
  }

  /// Newest-first records for a conversation (used to rehydrate chat bubbles).
  List<CallResultRecord> recordsForConversation(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return const <CallResultRecord>[];
    }
    final list = _records.values
        .where((record) => record.conversationId.trim() == id)
        .toList();
    list.sort((a, b) => b.endedAtMs.compareTo(a.endedAtMs));
    return list;
  }

  /// 清空某会话聊天记录时删除该会话通话缓存，避免重进会话再水合旧气泡。
  Future<int> removeByConversationId(String conversationId) async {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return 0;
    }
    await ensureLoaded();
    final toRemove = <String>[];
    for (final entry in _records.entries) {
      final recordConv = entry.value.conversationId.trim();
      if (recordConv.isEmpty) {
        continue;
      }
      if (recordConv == id ||
          MessageConversationId.sameConversation(recordConv, id)) {
        toRemove.add(entry.key);
      }
    }
    if (toRemove.isEmpty) {
      return 0;
    }
    for (final key in toRemove) {
      _records.remove(key);
    }
    revision.value++;
    await _persist();
    return toRemove.length;
  }

  /// 按来源优先级写入：server > device > signaling。
  /// 已存在更高（或同等）优先级来源的记录时，不会被较低优先级覆盖，
  /// 避免设备端本地推断覆盖服务端权威结果。
  void save(CallResultRecord record) {
    final id = record.callId.trim();
    if (id.isEmpty) {
      return;
    }
    final existing = _records[id];
    if (existing != null &&
        existing.source.priority > record.source.priority) {
      return;
    }
    // Skip no-op writes (same source + protocol + duration + direction).
    if (existing != null &&
        existing.source == record.source &&
        existing.protocolType == record.protocolType &&
        existing.durationSec == record.durationSec &&
        existing.isOutgoing == record.isOutgoing &&
        existing.operatorUserId == record.operatorUserId &&
        existing.mediaType == record.mediaType) {
      return;
    }
    _records[id] = record;
    _trimIfNeeded();
    revision.value++;
    unawaited(_persist());
  }

  Future<void> ensureLoaded() {
    if (_loaded) {
      return Future<void>.value();
    }
    return _loadTask ??= _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.trim().isEmpty) {
        _loaded = true;
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _loaded = true;
        return;
      }
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value;
        if (key.isEmpty || value is! Map) {
          continue;
        }
        final record = CallResultRecord.fromJson(Map<String, dynamic>.from(value));
        if (record.callId.isNotEmpty) {
          _records[record.callId] = record;
        }
      }
      _trimIfNeeded();
    } catch (_) {
    } finally {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    try {
      await ensureLoaded();
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        for (final entry in _records.entries) entry.key: entry.value.toJson(),
      };
      await prefs.setString(_prefsKey, jsonEncode(payload));
    } catch (_) {}
  }

  void _trimIfNeeded() {
    if (_records.length <= _maxRecords) {
      return;
    }
    final sorted = _records.entries.toList()
      ..sort((a, b) => a.value.endedAtMs.compareTo(b.value.endedAtMs));
    final removeCount = _records.length - _maxRecords;
    for (var i = 0; i < removeCount; i++) {
      _records.remove(sorted[i].key);
    }
  }
}
