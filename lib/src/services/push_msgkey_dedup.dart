import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 聊天 Push 与 IM 在线消息按 msgKey 去重（§12.1）。
class PushMsgKeyDedup {
  PushMsgKeyDedup._();

  static final PushMsgKeyDedup instance = PushMsgKeyDedup._();

  final Map<String, DateTime> _seen = <String, DateTime>{};
  static const Duration _ttl = Duration(minutes: 30);
  static const int _maxEntries = 200;

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
    _seen.clear();
  }
}
