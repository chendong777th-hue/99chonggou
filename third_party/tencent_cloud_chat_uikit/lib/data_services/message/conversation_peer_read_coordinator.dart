import 'dart:async';

/// App 侧注入：对方已读回执到达后，把会话列表 lastMessage.isPeerRead 写回本地。
typedef ConversationPeerReadHandler = Future<void> Function({
  required String conversationID,
  String? msgID,
  int? peerReadAtSec,
});

/// UIKit 回执回调 → demo [ConversationSyncService] 的桥接（仿 ArchiveHistoryProvider）。
class ConversationPeerReadCoordinator {
  ConversationPeerReadCoordinator._();

  static ConversationPeerReadHandler? _handler;
  static final Map<String, Timer> _debounceByConv = <String, Timer>{};
  static const Duration _debounce = Duration(milliseconds: 80);

  static void register(ConversationPeerReadHandler? handler) {
    _handler = handler;
  }

  /// 短合并同一会话连发回执，避免抖列表。
  static void scheduleNotify({
    required String conversationID,
    String? msgID,
    int? peerReadAtSec,
  }) {
    final id = conversationID.trim();
    if (id.isEmpty || _handler == null) {
      return;
    }
    _debounceByConv[id]?.cancel();
    _debounceByConv[id] = Timer(_debounce, () {
      _debounceByConv.remove(id);
      final handler = _handler;
      if (handler == null) {
        return;
      }
      unawaited(
        handler(
          conversationID: id,
          msgID: msgID,
          peerReadAtSec: peerReadAtSec,
        ),
      );
    });
  }
}
