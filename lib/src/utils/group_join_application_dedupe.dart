import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';

/// 合并同一入群事件的多条 REST 记录（如成员邀请 + 管理员审批执行记录）。
List<GroupJoinApplicationRecord> dedupeGroupJoinApplicationRecords(
  List<GroupJoinApplicationRecord> records,
) {
  final inviteByTarget = <String, GroupJoinApplicationRecord>{};
  final joinByApplicant = <String, GroupJoinApplicationRecord>{};
  final passthrough = <GroupJoinApplicationRecord>[];

  for (final record in records) {
    if (record.isInvite) {
      final target = record.toUserId?.trim() ?? '';
      if (target.isEmpty) {
        passthrough.add(record);
        continue;
      }
      final key = '${record.groupId}|invite|$target';
      final existing = inviteByTarget[key];
      inviteByTarget[key] = existing == null
          ? record
          : _pickPreferredRecord(existing, record);
    } else {
      final applicant = record.fromUserId.trim();
      if (applicant.isEmpty) {
        passthrough.add(record);
        continue;
      }
      final key = '${record.groupId}|join|$applicant';
      final existing = joinByApplicant[key];
      joinByApplicant[key] = existing == null
          ? record
          : _pickPreferredRecord(existing, record);
    }
  }

  final merged = <GroupJoinApplicationRecord>[
    ...inviteByTarget.values,
    ...joinByApplicant.values,
    ...passthrough,
  ]..sort(
      (a, b) => (b.createdAtMs ?? 0).compareTo(a.createdAtMs ?? 0),
    );
  return merged;
}

GroupJoinApplicationRecord _pickPreferredRecord(
  GroupJoinApplicationRecord current,
  GroupJoinApplicationRecord next,
) {
  if (current.isPending != next.isPending) {
    return current.isPending ? current : next;
  }
  final currentAdmin = _looksLikeAdminExecutorLabel(current);
  final nextAdmin = _looksLikeAdminExecutorLabel(next);
  if (currentAdmin != nextAdmin) {
    return currentAdmin ? next : current;
  }
  if (current.id != next.id) {
    return current.id <= next.id ? current : next;
  }
  final currentCreated = current.createdAtMs ?? 0;
  final nextCreated = next.createdAtMs ?? 0;
  return currentCreated <= nextCreated ? current : next;
}

bool _looksLikeAdminExecutorLabel(GroupJoinApplicationRecord record) {
  final nick = record.fromUserNickName?.trim() ?? '';
  if (nick.isEmpty) {
    return false;
  }
  final lower = nick.toLowerCase();
  if (lower == 'administrator' || lower == 'admin') {
    return true;
  }
  return nick == '管理员' ||
      nick == '管理員' ||
      nick.contains('管理员') ||
      nick.contains('管理員');
}
