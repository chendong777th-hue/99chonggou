import 'dart:async';

import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 批量设/取消管理员：HTTP 受理后的乐观态对账。
///
/// - TCP 同 role 确认 → tip suppress，避免灰字双发
/// - TCP 异 role → 以 TCP 为准，不清 tip suppress（允许正确 tip）
/// - 超时未确认 → 由服务层拉成员列表纠偏
class GroupMemberRolePending {
  GroupMemberRolePending._();

  static final GroupMemberRolePending instance = GroupMemberRolePending._();

  static const Duration ttl = Duration(seconds: 15);
  static const Duration tipSuppressTtl = Duration(seconds: 30);

  final Map<String, GroupMemberRolePendingEntry> _pending = {};
  final Map<String, _TipSuppressEntry> _tipSuppress = {};
  final Map<String, Timer> _timers = {};

  void Function(String groupId)? onReconcileDue;

  static String keyOf(String groupId, String userId) {
    return '${groupId.trim()}|${ChatIdFormat.rawUserUid(userId)}';
  }

  void register({
    required String groupId,
    required String userId,
    required int expectedRole,
    required int previousRole,
    required String operatorUserId,
    int? createdAtMs,
  }) {
    final gid = groupId.trim();
    final uid = ChatIdFormat.rawUserUid(userId);
    if (gid.isEmpty || uid.isEmpty || expectedRole <= 0) {
      return;
    }
    final key = keyOf(gid, uid);
    _pending[key] = GroupMemberRolePendingEntry(
      groupId: gid,
      userId: uid,
      expectedRole: expectedRole,
      previousRole: previousRole,
      operatorUserId: ChatIdFormat.rawUserUid(operatorUserId),
      createdAtMs: createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    _scheduleReconcile(gid);
  }

  /// TCP `member_role_changed`：确认或覆盖 pending。
  /// 返回 true 表示应跳过后续 tip（与乐观 tip 同 role）。
  bool acknowledgeTcp({
    required String groupId,
    required String userId,
    required int role,
  }) {
    final key = keyOf(groupId, userId);
    final entry = _pending.remove(key);
    if (entry == null) {
      return consumeTipSuppress(
        groupId: groupId,
        userId: userId,
        role: role,
      );
    }
    if (entry.expectedRole == role) {
      _tipSuppress[key] = _TipSuppressEntry(
        role: role,
        at: DateTime.now(),
      );
      _maybeCancelTimer(entry.groupId);
      return true;
    }
    _maybeCancelTimer(entry.groupId);
    return false;
  }

  bool consumeTipSuppress({
    required String groupId,
    required String userId,
    required int role,
  }) {
    final key = keyOf(groupId, userId);
    final entry = _tipSuppress[key];
    if (entry == null) {
      return false;
    }
    if (DateTime.now().difference(entry.at) > tipSuppressTtl) {
      _tipSuppress.remove(key);
      return false;
    }
    if (entry.role != role) {
      return false;
    }
    _tipSuppress.remove(key);
    return true;
  }

  List<GroupMemberRolePendingEntry> takeExpiredForGroup(String groupId) {
    final gid = groupId.trim();
    if (gid.isEmpty) {
      return const [];
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = <GroupMemberRolePendingEntry>[];
    final keys = _pending.keys
        .where((k) => k.startsWith('$gid|'))
        .toList(growable: false);
    for (final key in keys) {
      final entry = _pending[key];
      if (entry == null) continue;
      if (now - entry.createdAtMs >= ttl.inMilliseconds) {
        _pending.remove(key);
        expired.add(entry);
      }
    }
    return expired;
  }

  List<GroupMemberRolePendingEntry> peekForGroup(String groupId) {
    final gid = groupId.trim();
    return _pending.values
        .where((e) => e.groupId == gid)
        .toList(growable: false);
  }

  bool hasPendingForGroup(String groupId) {
    final gid = groupId.trim();
    return _pending.keys.any((k) => k.startsWith('$gid|'));
  }

  void clearGroup(String groupId) {
    final gid = groupId.trim();
    _pending.removeWhere((key, _) => key.startsWith('$gid|'));
    _tipSuppress.removeWhere((key, _) => key.startsWith('$gid|'));
    _timers.remove(gid)?.cancel();
  }

  void clearAll() {
    _pending.clear();
    _tipSuppress.clear();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  void _scheduleReconcile(String groupId) {
    _timers[groupId]?.cancel();
    _timers[groupId] = Timer(ttl, () {
      _timers.remove(groupId);
      onReconcileDue?.call(groupId);
    });
  }

  void _maybeCancelTimer(String groupId) {
    if (hasPendingForGroup(groupId)) {
      return;
    }
    _timers.remove(groupId)?.cancel();
  }
}

class GroupMemberRolePendingEntry {
  const GroupMemberRolePendingEntry({
    required this.groupId,
    required this.userId,
    required this.expectedRole,
    required this.previousRole,
    required this.operatorUserId,
    required this.createdAtMs,
  });

  final String groupId;
  final String userId;
  final int expectedRole;
  final int previousRole;
  final String operatorUserId;
  final int createdAtMs;
}

class _TipSuppressEntry {
  const _TipSuppressEntry({required this.role, required this.at});

  final int role;
  final DateTime at;
}
