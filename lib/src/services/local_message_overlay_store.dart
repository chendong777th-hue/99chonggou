import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// In-memory UI-only rows that must never enter the formal message history.
///
/// The store is deliberately account/session agnostic. Its owner is the chat
/// page lifecycle; callers clear it when the IM domain changes.
class LocalMessageOverlayStore extends ChangeNotifier {
  LocalMessageOverlayStore._();

  static final LocalMessageOverlayStore instance = LocalMessageOverlayStore._();

  final Map<String, Map<String, V2TimMessage>> _messagesByConversation =
      <String, Map<String, V2TimMessage>>{};
  String _ownerUserId = '';
  int _domainGeneration = -1;

  /// Binds the ephemeral projection to the active IM domain.
  ///
  /// Overlay rows are never durable message facts. Any account or listener
  /// generation change therefore invalidates the complete in-memory projection
  /// before a late callback can make it visible in the next session.
  void configureScope({
    required String ownerUserId,
    required int domainGeneration,
  }) {
    final owner = ownerUserId.trim();
    if (_ownerUserId == owner && _domainGeneration == domainGeneration) {
      return;
    }
    _ownerUserId = owner;
    _domainGeneration = domainGeneration;
    _clearWithoutNotify();
    notifyListeners();
  }

  /// Invalidates overlays immediately at an IM/account boundary.
  void invalidateScope() {
    _ownerUserId = '';
    _domainGeneration = -1;
    if (_messagesByConversation.isEmpty) {
      return;
    }
    _clearWithoutNotify();
    notifyListeners();
  }

  List<V2TimMessage> messagesFor(
    String conversationID, {
    bool? isGroup,
  }) {
    final buckets = _lookupKeys(conversationID, isGroup: isGroup)
        .map((key) => _messagesByConversation[key])
        .whereType<Map<String, V2TimMessage>>();
    final byMessage = <String, V2TimMessage>{};
    for (final bucket in buckets) {
      byMessage.addAll(bucket);
    }
    if (byMessage.isEmpty) {
      return const <V2TimMessage>[];
    }
    final result = byMessage.values.map(_clone).toList(growable: false)
      ..sort(_compareNewestFirst);
    return result;
  }

  bool upsert(String conversationID, V2TimMessage message) {
    final conversationKey = _canonicalConversationKey(conversationID);
    final messageKey = _messageKey(message);
    if (conversationKey.isEmpty || messageKey.isEmpty) {
      return false;
    }
    final bucket = _messagesByConversation.putIfAbsent(
      conversationKey,
      () => <String, V2TimMessage>{},
    );
    final next = _clone(message);
    final previous = bucket[messageKey];
    if (previous != null && _sameSnapshot(previous, next)) {
      return false;
    }
    bucket[messageKey] = next;
    notifyListeners();
    return true;
  }

  int removeWhere(
    String conversationID,
    bool Function(V2TimMessage message) test,
  ) {
    final conversationKey = _canonicalConversationKey(conversationID);
    final bucket = _messagesByConversation[conversationKey];
    if (bucket == null || bucket.isEmpty) {
      return 0;
    }
    final removed =
        bucket.keys.where((key) => test(bucket[key]!)).toList(growable: false);
    if (removed.isEmpty) {
      return 0;
    }
    for (final key in removed) {
      bucket.remove(key);
    }
    if (bucket.isEmpty) {
      _messagesByConversation.remove(conversationKey);
    }
    notifyListeners();
    return removed.length;
  }

  void clearConversation(String conversationID) {
    final keys = _lookupKeys(conversationID);
    var removed = false;
    for (final key in keys) {
      removed = _messagesByConversation.remove(key) != null || removed;
    }
    if (!removed) {
      return;
    }
    notifyListeners();
  }

  void clearAll() {
    if (_messagesByConversation.isEmpty) {
      return;
    }
    _messagesByConversation.clear();
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() => clearAll();

  void _clearWithoutNotify() {
    _messagesByConversation.clear();
  }

  static String _canonicalConversationKey(String conversationID) {
    final value = conversationID.trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('c2c_') || value.startsWith('group_')) {
      return value;
    }
    if (value.toUpperCase().contains('TGS#')) {
      return value.startsWith('group_') ? value : 'group_$value';
    }
    return 'c2c_$value';
  }

  static Iterable<String> _lookupKeys(
    String conversationID, {
    bool? isGroup,
  }) sync* {
    final value = conversationID.trim();
    if (value.isEmpty) {
      return;
    }
    yield value;
    if (value.startsWith('c2c_')) {
      yield value.substring(4);
    } else if (value.startsWith('group_')) {
      yield value.substring(6);
    }
    if (isGroup == true) {
      final raw = value.startsWith('group_') ? value.substring(6) : value;
      yield 'group_$raw';
    } else if (isGroup == false) {
      final raw = value.startsWith('c2c_') ? value.substring(4) : value;
      yield 'c2c_$raw';
    } else {
      yield _canonicalConversationKey(value);
    }
  }

  static String _messageKey(V2TimMessage message) {
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isNotEmpty) {
      return msgID;
    }
    return message.id?.trim() ?? '';
  }

  static V2TimMessage _clone(V2TimMessage message) {
    try {
      return V2TimMessage.fromJson(
        Map<String, dynamic>.from(message.toJson()),
      );
    } catch (_) {
      return message;
    }
  }

  static bool _sameSnapshot(V2TimMessage left, V2TimMessage right) {
    return left.msgID == right.msgID &&
        left.id == right.id &&
        left.timestamp == right.timestamp &&
        left.localCustomData == right.localCustomData &&
        left.customElem?.data == right.customElem?.data;
  }

  static int _compareNewestFirst(V2TimMessage left, V2TimMessage right) {
    final leftTs = left.timestamp ?? 0;
    final rightTs = right.timestamp ?? 0;
    if (leftTs != rightTs) {
      return rightTs.compareTo(leftTs);
    }
    return _messageKey(right).compareTo(_messageKey(left));
  }
}
