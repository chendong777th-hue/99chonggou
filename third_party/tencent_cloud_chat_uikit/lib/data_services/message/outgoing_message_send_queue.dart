import 'dart:async';

import 'package:flutter/foundation.dart';

/// Serializes SDK send calls per conversation so server [seq] matches tap order.
class OutgoingMessageSendQueue {
  OutgoingMessageSendQueue._();

  static final OutgoingMessageSendQueue instance = OutgoingMessageSendQueue._();

  final Map<String, Future<void>> _tailByConversation = {};

  static String conversationKey({
    required String receiver,
    required String groupID,
  }) {
    final group = groupID.trim();
    if (group.isNotEmpty) {
      return 'group:$group';
    }
    return 'c2c:${receiver.trim()}';
  }

  Future<T> runSerial<T>(
    String conversationKey,
    Future<T> Function() action,
  ) {
    final previous =
        _tailByConversation[conversationKey] ?? Future<void>.value();
    final queued = previous.catchError((_) {}).then((_) => action());
    late final Future<void> tail;
    tail = queued.then<void>((_) {}, onError: (_) {});
    _tailByConversation[conversationKey] = tail;
    unawaited(tail.whenComplete(() {
      if (identical(_tailByConversation[conversationKey], tail)) {
        _tailByConversation.remove(conversationKey);
      }
    }));
    return queued;
  }

  /// Releases completed tails at an account boundary. In-flight SDK calls
  /// cannot be cancelled here; their caller must also enforce session identity.
  void clearSession() {
    _tailByConversation.clear();
  }

  @visibleForTesting
  void resetForTesting() {
    clearSession();
  }

  @visibleForTesting
  bool hasPending(String conversationKey) {
    return _tailByConversation.containsKey(conversationKey);
  }
}
