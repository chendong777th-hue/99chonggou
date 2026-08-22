/// 会话列表预览强摘要缓存：弱「[业务消息]」不覆盖，供 abstract 回落。
class ConversationPreviewTextCache {
  ConversationPreviewTextCache._();

  static final ConversationPreviewTextCache instance =
      ConversationPreviewTextCache._();

  final Map<String, _ConversationPreviewTextEntry> _byConversationId =
      <String, _ConversationPreviewTextEntry>{};

  String? get(String conversationID) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final text = _byConversationId[id]?.text.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String? getForMessage(String conversationID, String messageKey) {
    final id = conversationID.trim();
    final key = messageKey.trim();
    if (id.isEmpty || key.isEmpty) {
      return null;
    }
    final entry = _byConversationId[id];
    if (entry == null || entry.messageKey != key) {
      return null;
    }
    final text = entry.text.trim();
    return text.isEmpty ? null : text;
  }

  void putStrong(
    String conversationID,
    String preview, {
    String? messageKey,
  }) {
    final id = conversationID.trim();
    final text = preview.trim();
    if (id.isEmpty || text.isEmpty) {
      return;
    }
    _byConversationId[id] = _ConversationPreviewTextEntry(
      text: text,
      messageKey: messageKey?.trim(),
    );
  }

  void clear() {
    _byConversationId.clear();
  }
}

class _ConversationPreviewTextEntry {
  const _ConversationPreviewTextEntry({
    required this.text,
    required this.messageKey,
  });

  final String text;
  final String? messageKey;
}
