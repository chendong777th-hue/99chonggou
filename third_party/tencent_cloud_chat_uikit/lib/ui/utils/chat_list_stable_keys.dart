import 'package:flutter/widgets.dart';

/// 聊天消息列表稳定 GlobalKey：按 conversationID 复用同一实例。
///
/// Column 条件插入子节点 / 父级 remount 时，靠这些 Key 把已有 State 挂回去，
/// 避免进页 ~300ms 整表 dispose+init（表现为 partition_cache_miss len:-1）。
final Map<String, GlobalKey> chatListContainerKeys = <String, GlobalKey>{};
final Map<String, GlobalKey> chatHistoryListKeys = <String, GlobalKey>{};

GlobalKey chatListContainerKeyFor(String conversationID) {
  final id = conversationID.trim();
  return chatListContainerKeys.putIfAbsent(
    id,
    () => GlobalKey(debugLabel: 'tim_chat_hist_container_$id'),
  );
}

GlobalKey chatHistoryListKeyFor(String conversationID) {
  final id = conversationID.trim();
  return chatHistoryListKeys.putIfAbsent(
    id,
    () => GlobalKey(debugLabel: 'tim_chat_hist_list_state_$id'),
  );
}
