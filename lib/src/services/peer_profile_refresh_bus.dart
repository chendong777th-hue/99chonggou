import 'package:flutter/foundation.dart';

import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 好友关系或用户资料（头像/昵称）变更时通知已打开的 Profile / Chat / 建群页刷新。
class PeerProfileRefreshBus {
  PeerProfileRefreshBus._();

  static final PeerProfileRefreshBus instance = PeerProfileRefreshBus._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final Set<String> _changedUserIds = <String>{};

  String? get lastUserId {
    if (_changedUserIds.isEmpty) {
      return null;
    }
    return _changedUserIds.last;
  }

  Set<String> get changedUserIds => Set<String>.unmodifiable(_changedUserIds);

  void notify(String userId) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return;
    }
    _changedUserIds.add(id);
    revision.value++;
  }

  /// 批量标记变更 peer，只 bump 一次 revision，避免全量 sync 后 UI 风暴。
  void notifyMany(Iterable<String> userIds) {
    var any = false;
    for (final raw in userIds) {
      final id = ChatIdFormat.rawUserUid(raw);
      if (id.isEmpty) {
        continue;
      }
      _changedUserIds.add(id);
      any = true;
    }
    if (any) {
      revision.value++;
    }
  }

  bool matches(String userId) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return false;
    }
    return _changedUserIds.contains(id);
  }

  void clear() {
    if (_changedUserIds.isEmpty) {
      return;
    }
    _changedUserIds.clear();
    revision.value++;
  }
}
