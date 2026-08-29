import 'dart:collection';
import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

class _CustomParseEntry {
  const _CustomParseEntry({required this.payload, required this.value});

  final String payload;
  final Object value;
}

/// Process-memory-only cache for pure custom-message parsing results.
/// Dynamic UI, wallet network state and call repository state must never enter it.
class CustomMessageParseCache {
  CustomMessageParseCache._();

  static final CustomMessageParseCache instance = CustomMessageParseCache._();
  static const int maxEntries = 512;
  static const Object _nullValue = Object();

  final LinkedHashMap<String, _CustomParseEntry> _entries =
      LinkedHashMap<String, _CustomParseEntry>();

  String _conversationKey(V2TimMessage message) {
    final groupID = message.groupID?.trim() ?? '';
    if (groupID.isNotEmpty) return 'group:$groupID';
    final userID = message.userID?.trim() ?? '';
    if (userID.isNotEmpty) return 'c2c:$userID';
    return '';
  }

  String _stableIdentity(V2TimMessage message) {
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isNotEmpty) return 'msg:$msgID';
    final id = message.id?.trim() ?? '';
    if (id.isNotEmpty) return 'id:$id';
    final seq = message.seq?.trim() ?? '';
    if (seq.isNotEmpty) return 'seq:$seq';
    final timestamp = message.timestamp ?? 0;
    final random = message.random ?? 0;
    return timestamp > 0 || random != 0 ? 'wire:$timestamp:$random' : '';
  }

  String _payloadHash(String payload) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(payload)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }

  T? parse<T>({
    required V2TimMessage message,
    required String payload,
    required String parserVersion,
    required T? Function() parser,
  }) {
    final conversation = _conversationKey(message);
    final identity = _stableIdentity(message);
    final version = parserVersion.trim();
    if (conversation.isEmpty || identity.isEmpty || version.isEmpty) {
      return parser();
    }
    final key = '$conversation|$identity|$version|${_payloadHash(payload)}';
    final cached = _entries.remove(key);
    if (cached != null && cached.payload == payload) {
      _entries[key] = cached;
      return identical(cached.value, _nullValue) ? null : cached.value as T;
    }
    final value = parser();
    _entries[key] = _CustomParseEntry(
      payload: payload,
      value: value == null ? _nullValue : value as Object,
    );
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return value;
  }

  Map<String, dynamic>? decodeMap({
    required V2TimMessage message,
    required String payload,
    required String parserVersion,
  }) {
    final parsed = parse<Map<String, dynamic>>(
      message: message,
      payload: payload,
      parserVersion: parserVersion,
      parser: () {
        try {
          final decoded = jsonDecode(payload);
          return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
        } catch (_) {
          return null;
        }
      },
    );
    return parsed == null ? null : Map<String, dynamic>.from(parsed);
  }

  void clearConversation(String conversationKey) {
    final normalized = conversationKey.trim();
    if (normalized.isEmpty) return;
    _entries.removeWhere((key, _) => key.startsWith('$normalized|'));
  }

  void clear() => _entries.clear();

  int get lengthForTesting => _entries.length;
}
