import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';

bool groupJoinApplicationIsPending(V2TimGroupApplication application) {
  return application.handleStatus == 0 && application.handleResult == 0;
}

bool groupJoinApplicationIsSelfHosted(V2TimGroupApplication application) {
  return application.authentication
      .trim()
      .startsWith(GroupJoinApplicationService.applicationAuthPrefix);
}

bool groupJoinApplicationIsInviteType(V2TimGroupApplication application) {
  return application.type == 1 || application.type == 2;
}

bool groupJoinApplicationIsInviteParticipant({
  required V2TimGroupApplication application,
  required String currentUserId,
}) {
  if (!groupJoinApplicationIsInviteType(application)) {
    return false;
  }
  final self = ChatIdFormat.rawUserUid(currentUserId);
  if (self.isEmpty) {
    return false;
  }
  final from = ChatIdFormat.rawUserUid(application.fromUser);
  final to = ChatIdFormat.rawUserUid(application.toUser);
  return from == self || to == self;
}

bool groupJoinApplicationIsAdminOfGroup(
  String groupId,
  Set<String> adminGroupIds,
) {
  final trimmed = groupId.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (adminGroupIds.contains(trimmed)) {
    return true;
  }
  final normalized = ChatIdFormat.normalizeGroupId(trimmed);
  return normalized.isNotEmpty && adminGroupIds.contains(normalized);
}

bool groupJoinApplicationCanApprove({
  required V2TimGroupApplication application,
  required Set<String> adminGroupIds,
}) {
  if (!groupJoinApplicationIsPending(application) ||
      !groupJoinApplicationIsSelfHosted(application)) {
    return false;
  }
  return groupJoinApplicationIsAdminOfGroup(application.groupID, adminGroupIds);
}

/// 当前用户是否可在群通知里点「同意/拒绝」。
/// 邀请人 / 被邀请人即使本地误判为管理员，也不能自行审批邀请单。
bool groupJoinApplicationCanApproveForCurrentUser({
  required V2TimGroupApplication application,
  required Set<String> adminGroupIds,
  required String currentUserId,
}) {
  if (!groupJoinApplicationCanApprove(
    application: application,
    adminGroupIds: adminGroupIds,
  )) {
    return false;
  }
  if (groupJoinApplicationIsInviteParticipant(
    application: application,
    currentUserId: currentUserId,
  )) {
    return false;
  }
  return true;
}

/// 审批通过后写入群聊 member_added 灰字的目标用户。
({String operatorUserId, List<String> memberUserIds})
    groupJoinApplicationMemberAddedTargets(
  V2TimGroupApplication application,
) {
  final from = ChatIdFormat.rawUserUid(application.fromUser);
  final to = ChatIdFormat.rawUserUid(application.toUser);
  if (groupJoinApplicationIsInviteType(application)) {
    // Invite applications carry inviter in fromUser and invitee in toUser.
    // If toUser is absent, the target is unknown; falling back to fromUser
    // would render the inviter as both operator and invited member.
    if (from.isEmpty || to.isEmpty || from == to) {
      return (
        operatorUserId: from,
        memberUserIds: const <String>[],
      );
    }
    final member = to;
    final operator = from;
    return (
      operatorUserId: operator,
      memberUserIds: member.isEmpty ? const <String>[] : <String>[member],
    );
  }
  return (
    operatorUserId: from,
    memberUserIds: from.isEmpty ? const <String>[] : <String>[from],
  );
}

bool groupJoinApplicationIsWaitingAsParticipant({
  required V2TimGroupApplication application,
  required Set<String> adminGroupIds,
  required String currentUserId,
}) {
  if (!groupJoinApplicationIsPending(application) ||
      !groupJoinApplicationIsSelfHosted(application)) {
    return false;
  }
  if (groupJoinApplicationCanApproveForCurrentUser(
    application: application,
    adminGroupIds: adminGroupIds,
    currentUserId: currentUserId,
  )) {
    return false;
  }
  final self = ChatIdFormat.rawUserUid(currentUserId);
  if (self.isEmpty) {
    return false;
  }
  final from = ChatIdFormat.rawUserUid(application.fromUser);
  final to = ChatIdFormat.rawUserUid(application.toUser);
  if (from == self || to == self) {
    return true;
  }
  if (application.type == 0 && from == self) {
    return true;
  }
  // 非管理员在列表里看到的 pending 记录，一律视为等待管理员审批。
  return !groupJoinApplicationIsAdminOfGroup(application.groupID, adminGroupIds);
}
