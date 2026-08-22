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
    _tailByConversation[conversationKey] =
        queued.then((_) {}, onError: (_) {});
    return queued;
  }

  @visibleForTesting
  void resetForTesting() {
    _tailByConversation.clear();
  }

  @visibleForTesting
  bool hasPending(String conversationKey) {
    return _tailByConversation.containsKey(conversationKey);
  }
}
