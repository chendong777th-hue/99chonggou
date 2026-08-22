import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

class ChatRowUiSnapshot {
  final bool isMultiSelect;
  final bool isSelected;
  final int rowRevision;
  final int modeRevision;
  final int selectionRevision;

  const ChatRowUiSnapshot({
    required this.isMultiSelect,
    required this.isSelected,
    required this.rowRevision,
    required this.modeRevision,
    required this.selectionRevision,
  });

  @override
  bool operator ==(Object other) {
    return other is ChatRowUiSnapshot &&
        other.isMultiSelect == isMultiSelect &&
        other.isSelected == isSelected &&
        other.rowRevision == rowRevision &&
        other.modeRevision == modeRevision &&
        other.selectionRevision == selectionRevision;
  }

  @override
  int get hashCode => Object.hash(
        isMultiSelect,
        isSelected,
        rowRevision,
        modeRevision,
        selectionRevision,
      );
}

class _ChatConversationUiState {
  bool isMultiSelect = false;
  final Set<String> selectedMessageKeys = <String>{};
  final Map<String, int> rowRevisionByMessageKey = <String, int>{};
  final Map<String, String> aliasToMainKey = <String, String>{};
  int modeRevision = 0;
  int selectionRevision = 0;
}

class ChatUiStateStore extends ChangeNotifier {
  final Map<String, _ChatConversationUiState> _states =
      <String, _ChatConversationUiState>{};

  static String messageKeyOf(V2TimMessage message) {
    final msgID = message.msgID?.trim();
    if (msgID != null && msgID.isNotEmpty) {
      return msgID;
    }
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    final seq = message.seq?.trim();
    if (seq != null && seq.isNotEmpty) {
      return 'seq_$seq';
    }
    final timestamp = message.timestamp;
    final sender = message.sender?.trim() ?? message.userID?.trim() ?? '';
    if (timestamp != null && timestamp > 0) {
      return 'ts_${timestamp}_$sender';
    }
    return 'local_${identityHashCode(message)}';
  }

  static String? conversationIDOf(V2TimMessage message) {
    final userID = message.userID?.trim();
    if (userID != null && userID.isNotEmpty) {
      return userID;
    }
    final groupID = message.groupID?.trim();
    if (groupID != null && groupID.isNotEmpty) {
      return groupID;
    }
    return null;
  }

  /// 与聊天 model / 历史桶一致：去掉 `c2c_` / `group_` 前缀。
  /// 避免消息行用裸 ID、底栏/顶栏用带前缀 ID 时多选状态分裂。
  @visibleForTesting
  static String normalizeConversationKey(String? conversationID) {
    var id = conversationID?.trim() ?? '';
    if (id.isEmpty) {
      return '';
    }
    final lower = id.toLowerCase();
    if (lower.startsWith('group_')) {
      return id.substring(6);
    }
    if (lower.startsWith('c2c_')) {
      return id.substring(4);
    }
    if (id.startsWith('GROUP')) {
      return id.substring(5);
    }
    if (id.startsWith('C2C')) {
      return id.substring(3);
    }
    return id;
  }

  _ChatConversationUiState _stateOf(String conversationID) {
    final key = normalizeConversationKey(conversationID);
    return _states.putIfAbsent(key, () => _ChatConversationUiState());
  }

  String _resolveKey(_ChatConversationUiState state, String messageKey) {
    final key = messageKey.trim();
    if (key.isEmpty) {
      return key;
    }
    return state.aliasToMainKey[key] ?? key;
  }

  void bindMessageAlias(
    String conversationID,
    String oldKey,
    String newKey,
  ) {
    final source = oldKey.trim();
    final target = newKey.trim();
    if (source.isEmpty || target.isEmpty || source == target) {
      return;
    }
    final state = _stateOf(conversationID);
    final resolvedTarget = _resolveKey(state, target);
    state.aliasToMainKey[source] = resolvedTarget;
    if (state.selectedMessageKeys.remove(source)) {
      state.selectedMessageKeys.add(resolvedTarget);
      state.selectionRevision++;
    }
    final sourceRevision = state.rowRevisionByMessageKey.remove(source);
    if (sourceRevision != null) {
      final current = state.rowRevisionByMessageKey[resolvedTarget] ?? 0;
      state.rowRevisionByMessageKey[resolvedTarget] =
          sourceRevision > current ? sourceRevision : current;
    }
    notifyListeners();
  }

  bool isMultiSelect(String conversationID) =>
      _stateOf(conversationID).isMultiSelect;

  int modeRevision(String conversationID) => _stateOf(conversationID).modeRevision;

  int selectionRevision(String conversationID) =>
      _stateOf(conversationID).selectionRevision;

  int selectedCount(String conversationID) =>
      _stateOf(conversationID).selectedMessageKeys.length;

  void setMultiSelect(String conversationID, bool enabled) {
    final state = _stateOf(conversationID);
    var changed = false;
    if (state.isMultiSelect != enabled) {
      state.isMultiSelect = enabled;
      state.modeRevision++;
      changed = true;
    }
    if (!enabled && state.selectedMessageKeys.isNotEmpty) {
      for (final key in state.selectedMessageKeys) {
        state.rowRevisionByMessageKey[key] =
            (state.rowRevisionByMessageKey[key] ?? 0) + 1;
      }
      state.selectedMessageKeys.clear();
      state.selectionRevision++;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  bool isMessageSelected(String conversationID, String messageKey) {
    final state = _stateOf(conversationID);
    final key = _resolveKey(state, messageKey);
    return key.isNotEmpty && state.selectedMessageKeys.contains(key);
  }

  void setMessageSelected(
    String conversationID,
    String messageKey,
    bool selected,
  ) {
    final state = _stateOf(conversationID);
    final key = _resolveKey(state, messageKey);
    if (key.isEmpty) {
      return;
    }
    final changed = selected
        ? state.selectedMessageKeys.add(key)
        : state.selectedMessageKeys.remove(key);
    if (!changed) {
      return;
    }
    state.selectionRevision++;
    state.rowRevisionByMessageKey[key] =
        (state.rowRevisionByMessageKey[key] ?? 0) + 1;
    notifyListeners();
  }

  void clearSelection(String conversationID) {
    final state = _stateOf(conversationID);
    if (state.selectedMessageKeys.isEmpty) {
      return;
    }
    for (final key in state.selectedMessageKeys) {
      state.rowRevisionByMessageKey[key] =
          (state.rowRevisionByMessageKey[key] ?? 0) + 1;
    }
    state.selectedMessageKeys.clear();
    state.selectionRevision++;
    notifyListeners();
  }

  int rowRevision(String conversationID, String messageKey) {
    final state = _stateOf(conversationID);
    final key = _resolveKey(state, messageKey);
    if (key.isEmpty) {
      return 0;
    }
    return state.rowRevisionByMessageKey[key] ?? 0;
  }

  void markMessageChanged(String conversationID, String messageKey) {
    final state = _stateOf(conversationID);
    final key = _resolveKey(state, messageKey);
    if (key.isEmpty) {
      return;
    }
    state.rowRevisionByMessageKey[key] =
        (state.rowRevisionByMessageKey[key] ?? 0) + 1;
    notifyListeners();
  }

  void markMessageChangedByMessage(
    String conversationID,
    V2TimMessage message,
  ) {
    markMessageChanged(conversationID, messageKeyOf(message));
  }

  void markMessagesChanged(String conversationID, Iterable<String> messageKeys) {
    final state = _stateOf(conversationID);
    var changed = false;
    for (final rawKey in messageKeys) {
      final key = _resolveKey(state, rawKey);
      if (key.isEmpty) {
        continue;
      }
      state.rowRevisionByMessageKey[key] =
          (state.rowRevisionByMessageKey[key] ?? 0) + 1;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  ChatRowUiSnapshot rowSnapshot({
    required String conversationID,
    required String messageKey,
  }) {
    final state = _stateOf(conversationID);
    final key = _resolveKey(state, messageKey);
    return ChatRowUiSnapshot(
      isMultiSelect: state.isMultiSelect,
      isSelected: key.isNotEmpty && state.selectedMessageKeys.contains(key),
      rowRevision: key.isEmpty ? 0 : state.rowRevisionByMessageKey[key] ?? 0,
      modeRevision: state.modeRevision,
      selectionRevision: state.selectionRevision,
    );
  }

  void clearConversationState(String conversationID, {bool notify = true}) {
    final key = normalizeConversationKey(conversationID);
    final raw = conversationID.trim();
    if (key.isEmpty && raw.isEmpty) {
      return;
    }
    var removed = false;
    if (key.isNotEmpty) {
      removed = _states.remove(key) != null || removed;
    }
    // 兼容历史未归一化的桶，避免残留幽灵状态。
    if (raw.isNotEmpty && raw != key) {
      removed = _states.remove(raw) != null || removed;
    }
    if (removed && notify) {
      notifyListeners();
    }
  }
}
