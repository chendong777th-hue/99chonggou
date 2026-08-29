import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';

/// 按 callId 缓存通话终态结果，供聊天气泡解析优先读取。
class CallResultRepository {
  CallResultRepository._();

  static final CallResultRepository instance = CallResultRepository._();

  static const String _legacyPrefsKey = 'call_result_canonical_v1';
  static const String _prefsKeyPrefix = 'call_result_canonical_v1_';
  static const int _maxRecords = 128;

  final Map<String, Map<String, CallResultRecord>> _recordsByOwner =
      <String, Map<String, CallResultRecord>>{};
  final Set<String> _loadedOwners = <String>{};
  final Map<String, Future<void>> _loadTasks = <String, Future<void>>{};

  /// Bumped when a record is written; chat pages re-normalize bubbles.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  CallResultRecord? get(String callId) {
    final id = callId.trim();
    if (id.isEmpty) {
      return null;
    }
    final owner = _ownerForCurrentSession();
    return _recordsByOwner[owner]?[id];
  }

  /// Newest-first records for a conversation (used to rehydrate chat bubbles).
  List<CallResultRecord> recordsForConversation(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return const <CallResultRecord>[];
    }
    final list = (_recordsByOwner[_ownerForCurrentSession()]?.values ??
            const <CallResultRecord>[])
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
    final identity = SessionIdentityService.instance.capture();
    final owner = _ownerForIdentity(identity);
    await ensureLoaded(identity: identity);
    if (!_isCurrentOrGuest(identity)) {
      return 0;
    }
    final records = _recordsByOwner[owner] ?? <String, CallResultRecord>{};
    final toRemove = <String>[];
    for (final entry in records.entries) {
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
      records.remove(key);
    }
    revision.value++;
    await _persist(owner, identity);
    return toRemove.length;
  }

  /// Merge one observation into the canonical callId record.
  /// Lifecycle rank is monotonic; a terminal record can never be rolled back
  /// by a late invite/accept. For equal states, server remains authoritative.
  void save(CallResultRecord record, {SessionIdentity? identity}) {
    final capturedIdentity =
        identity ?? SessionIdentityService.instance.capture();
    if (!_isCurrentOrGuest(capturedIdentity)) {
      return;
    }
    final owner = _ownerForIdentity(capturedIdentity);
    final records = _recordsByOwner.putIfAbsent(
      owner,
      () => <String, CallResultRecord>{},
    );
    final id = record.callId.trim();
    if (id.isEmpty) {
      return;
    }
    final existing = records[id];
    final incomingStatus = record.effectiveStatus;
    if (existing != null) {
      final currentStatus = existing.effectiveStatus;
      if (incomingStatus.rank < currentStatus.rank) return;
      if (incomingStatus.rank == currentStatus.rank &&
          existing.source.priority > record.source.priority) return;
    }
    if (existing != null &&
        incomingStatus.rank == existing.effectiveStatus.rank) {
      record = _mergeFields(existing, record);
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
    records[id] = record;
    _trimIfNeeded(records);
    revision.value++;
    unawaited(_persist(owner, capturedIdentity));
  }

  CallResultRecord _mergeFields(
      CallResultRecord current, CallResultRecord next) {
    return CallResultRecord(
      callId: next.callId.isNotEmpty ? next.callId : current.callId,
      conversationId: next.conversationId.isNotEmpty
          ? next.conversationId
          : current.conversationId,
      callerUserId: next.callerUserId.isNotEmpty
          ? next.callerUserId
          : current.callerUserId,
      operatorUserId: next.operatorUserId.isNotEmpty
          ? next.operatorUserId
          : current.operatorUserId,
      peerUserId:
          next.peerUserId.isNotEmpty ? next.peerUserId : current.peerUserId,
      protocolType: next.protocolType.name == 'unknown'
          ? current.protocolType
          : next.protocolType,
      durationSec:
          next.durationSec > 0 ? next.durationSec : current.durationSec,
      endedAtMs: next.endedAtMs > 0 ? next.endedAtMs : current.endedAtMs,
      isOutgoing: next.isOutgoing ?? current.isOutgoing,
      source: next.source.priority >= current.source.priority
          ? next.source
          : current.source,
      mediaType:
          next.mediaType.trim().isNotEmpty ? next.mediaType : current.mediaType,
      status: next.status ?? current.status,
      roomName: next.roomName.isNotEmpty ? next.roomName : current.roomName,
      startedAtMs:
          next.startedAtMs > 0 ? next.startedAtMs : current.startedAtMs,
      acceptedAtMs:
          next.acceptedAtMs > 0 ? next.acceptedAtMs : current.acceptedAtMs,
    );
  }

  Future<void> ensureLoaded({SessionIdentity? identity}) {
    final capturedIdentity =
        identity ?? SessionIdentityService.instance.capture();
    final owner = _ownerForIdentity(capturedIdentity);
    if (_loadedOwners.contains(owner)) {
      return Future<void>.value();
    }
    return _loadTasks[owner] ??= _loadFromPrefs(owner, capturedIdentity);
  }

  Future<void> _loadFromPrefs(
    String owner,
    SessionIdentity identity,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKeyForOwner(owner));
      if (!_isCurrentOrGuest(identity)) {
        return;
      }
      if (raw == null || raw.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value;
        if (key.isEmpty || value is! Map) {
          continue;
        }
        final record =
            CallResultRecord.fromJson(Map<String, dynamic>.from(value));
        if (record.callId.isNotEmpty) {
          _recordsByOwner
              .putIfAbsent(
                owner,
                () => <String, CallResultRecord>{},
              )
              .putIfAbsent(record.callId, () => record);
        }
      }
      _trimIfNeeded(_recordsByOwner[owner] ?? <String, CallResultRecord>{});
    } catch (_) {
    } finally {
      if (_isCurrentOrGuest(identity)) {
        _loadedOwners.add(owner);
      }
      _loadTasks.remove(owner);
    }
  }

  Future<void> _persist(String owner, SessionIdentity identity) async {
    try {
      await ensureLoaded(identity: identity);
      final prefs = await SharedPreferences.getInstance();
      if (!_isCurrentOrGuest(identity)) {
        return;
      }
      final records = _recordsByOwner[owner] ?? <String, CallResultRecord>{};
      final payload = <String, dynamic>{
        for (final entry in records.entries) entry.key: entry.value.toJson(),
      };
      if (!_isCurrentOrGuest(identity)) {
        return;
      }
      await prefs.setString(_prefsKeyForOwner(owner), jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> clearForOwner(String ownerUserId) async {
    final owner = ownerUserId.trim();
    if (owner.isEmpty) {
      return;
    }
    _recordsByOwner.remove(_ownerForUserId(owner));
    _loadedOwners.remove(_ownerForUserId(owner));
    revision.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyForOwner(owner));
    // The old key was global and cannot be attributed safely. It must never
    // be read by a logged-in account, so remove it at the next account purge.
    await prefs.remove(_legacyPrefsKey);
  }

  void _trimIfNeeded(Map<String, CallResultRecord> records) {
    if (records.length <= _maxRecords) {
      return;
    }
    final sorted = records.entries.toList()
      ..sort((a, b) => a.value.endedAtMs.compareTo(b.value.endedAtMs));
    final removeCount = records.length - _maxRecords;
    for (var i = 0; i < removeCount; i++) {
      records.remove(sorted[i].key);
    }
  }

  String _ownerForCurrentSession() {
    return _ownerForIdentity(SessionIdentityService.instance.capture());
  }

  String _ownerForIdentity(SessionIdentity identity) {
    return _ownerForUserId(identity.ownerUserId);
  }

  String _ownerForUserId(String ownerUserId) {
    final owner = ownerUserId.trim();
    return owner.isEmpty ? '_guest' : owner;
  }

  String _prefsKeyForOwner(String owner) {
    return '$_prefsKeyPrefix${ContactSocialCacheStore.accountScopeForUserId(owner)}';
  }

  bool _isCurrent(SessionIdentity identity) {
    return identity.ownerUserId.isNotEmpty &&
        SessionIdentityService.instance.isCurrent(identity);
  }

  bool _isCurrentOrGuest(SessionIdentity identity) {
    if (identity.ownerUserId.isEmpty) {
      final current = SessionIdentityService.instance.capture();
      return current.ownerUserId.isEmpty &&
          current.generation == identity.generation;
    }
    return _isCurrent(identity);
  }
}
