/// 聊天 Push 本地 notificationId 登记，便于按 msgKey / threadId 取消。
class ImChatNotificationRegistry {
  ImChatNotificationRegistry._();

  static final ImChatNotificationRegistry instance =
      ImChatNotificationRegistry._();

  final Map<String, Set<int>> _threadToIds = <String, Set<int>>{};
  final Map<int, String> _idToMsgKey = <int, String>{};

  static int notificationIdFor(String msgKey) {
    return msgKey.hashCode & 0x7fffffff;
  }

  static String threadIdFor({
    required String chatType,
    required String peerOrGroupId,
  }) {
    final id = peerOrGroupId.trim();
    if (chatType == 'group') {
      return 'group_$id';
    }
    return 'c2c_$id';
  }

  static String? threadIdFromConversationId(String conversationID) {
    final id = conversationID.trim();
    if (id.startsWith('group_')) {
      return 'group_${id.replaceFirst('group_', '')}';
    }
    if (id.startsWith('c2c_')) {
      return 'c2c_${id.replaceFirst('c2c_', '')}';
    }
    return null;
  }

  void register({
    required String threadId,
    required int notificationId,
    String? msgKey,
  }) {
    final thread = threadId.trim();
    if (thread.isEmpty) {
      return;
    }
    (_threadToIds[thread] ??= <int>{}).add(notificationId);
    final key = msgKey?.trim() ?? '';
    if (key.isNotEmpty) {
      _idToMsgKey[notificationId] = key;
    }
  }

  Set<int> allImChatIds() {
    final ids = <int>{};
    for (final entry in _threadToIds.values) {
      ids.addAll(entry);
    }
    return ids;
  }

  Set<int> idsForThread(String threadId) {
    return Set<int>.from(_threadToIds[threadId.trim()] ?? const <int>{});
  }

  void remove(int notificationId) {
    _idToMsgKey.remove(notificationId);
    final emptyThreads = <String>[];
    for (final entry in _threadToIds.entries) {
      entry.value.remove(notificationId);
      if (entry.value.isEmpty) {
        emptyThreads.add(entry.key);
      }
    }
    for (final thread in emptyThreads) {
      _threadToIds.remove(thread);
    }
  }

  void clearThread(String threadId) {
    final thread = threadId.trim();
    final ids = _threadToIds.remove(thread);
    if (ids == null) {
      return;
    }
    for (final id in ids) {
      _idToMsgKey.remove(id);
    }
  }

  void clearAll() {
    _threadToIds.clear();
    _idToMsgKey.clear();
  }
}
