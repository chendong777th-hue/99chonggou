/// 群聊本地 member_added 提示的语义去重（邀请人 + 审批执行人双写）。
enum MemberAddedDuplicateDecision {
  publish,
  skipIncoming,
  replaceExisting,
}

MemberAddedDuplicateDecision decideMemberAddedDuplicate({
  required bool existingOperatorIsAdmin,
  required bool incomingOperatorIsAdmin,
}) {
  if (incomingOperatorIsAdmin && !existingOperatorIsAdmin) {
    return MemberAddedDuplicateDecision.skipIncoming;
  }
  if (!incomingOperatorIsAdmin && existingOperatorIsAdmin) {
    return MemberAddedDuplicateDecision.replaceExisting;
  }
  return MemberAddedDuplicateDecision.skipIncoming;
}

String memberAddedSemanticKey(String groupId, List<String> memberUserIds) {
  return _memberSemanticKey(groupId, 'member_added', memberUserIds);
}

/// member_removed 与 member_added 同病：本端即时注入、后端 change-event
/// （操作人=管理员执行账号）、实时推送三路各写一条，仅靠含操作人的
/// dedupKey 拦不住，需要按「群+动作+成员集合」做语义去重。
String memberRemovedSemanticKey(String groupId, List<String> memberUserIds) {
  return _memberSemanticKey(groupId, 'member_removed', memberUserIds);
}

/// 群资料变更（改名/头像/公告）：本端乐观 + TCP 双写按「群+动作+内容指纹」去重。
/// 不含内容指纹时短时间多次改名会被误吞；指纹相同才视为同一次变更。
String groupProfileChangedSemanticKey(
  String groupId,
  String action, {
  String contentKey = '',
}) {
  final id = groupId.trim();
  final act = action.trim().toLowerCase();
  final content = contentKey.trim();
  if (content.isEmpty) {
    return '$id|$act';
  }
  return '$id|$act|$content';
}

/// 从 TCP/乐观 notice.detail 提取群资料 tip 内容指纹。
String groupProfileTipContentKey(
  String action,
  Map<String, dynamic>? detail, {
  String changeEventId = '',
  int? occurredAtMs,
}) {
  final act = action.trim().toLowerCase();
  final map = detail ?? const <String, dynamic>{};
  var content = '';
  switch (act) {
    case 'group_name_changed':
      content = (map['groupName'] ?? map['group_name'])?.toString().trim() ?? '';
      break;
    case 'group_avatar_changed':
      for (final key in const [
        'avatarUrl',
        'avatar_url',
        'thumbUrl',
        'thumb_url',
        'faceUrl',
        'face_url',
      ]) {
        final value = map[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          content = value;
          break;
        }
      }
      break;
    case 'group_notice_changed':
      content = (map['notice'] ??
                  map['notification'] ??
                  map['groupNotice'] ??
                  map['group_notice'])
              ?.toString()
              .trim() ??
          '';
      break;
  }
  if (content.isNotEmpty) {
    return content;
  }
  final eventId = changeEventId.trim();
  if (eventId.isNotEmpty) {
    return 'eid:$eventId';
  }
  final at = occurredAtMs ?? 0;
  if (at > 0) {
    return 't:$at';
  }
  return '';
}

const Set<String> kGroupProfileTipActions = <String>{
  'group_name_changed',
  'group_avatar_changed',
  'group_notice_changed',
};

bool isGroupProfileTipAction(String action) {
  return kGroupProfileTipActions.contains(action.trim().toLowerCase());
}

String _memberSemanticKey(
  String groupId,
  String action,
  List<String> memberUserIds,
) {
  final members = memberUserIds
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList()
    ..sort();
  return '$groupId|$action|${members.join(',')}';
}

bool looksLikeAdminExecutorLabel(String? name) {
  final nick = name?.trim() ?? '';
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
