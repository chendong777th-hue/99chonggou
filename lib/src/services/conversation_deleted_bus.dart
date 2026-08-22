import 'package:flutter/foundation.dart';

/// UI signal after conversations are actually removed from local store.
/// Prefer this over raw SDK deleted callbacks (history-clear can false-fire).
class ConversationDeletedBus {
  ConversationDeletedBus._();

  static final ConversationDeletedBus instance = ConversationDeletedBus._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  List<String> _lastDeletedIds = const <String>[];

  List<String> get lastDeletedIds =>
      List<String>.unmodifiable(_lastDeletedIds);

  void notifyDeleted(List<String> conversationIds) {
    final cleaned = conversationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) {
      return;
    }
    _lastDeletedIds = cleaned;
    revision.value++;
  }
}
