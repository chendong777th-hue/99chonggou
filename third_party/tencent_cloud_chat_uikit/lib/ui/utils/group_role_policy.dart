import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';

/// 群角色 / 禁言 / 踢人 / 禁言目标等 UI 门控的单一真相。
///
/// 纯函数、无副作用；时间单位统一为秒。
class GroupRolePolicy {
  GroupRolePolicy._();

  static bool isOwnerRole(int? role) {
    return role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER;
  }

  static bool isAdminRole(int? role) {
    return role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN;
  }

  static bool isManagerRole(int? role) {
    return isOwnerRole(role) || isAdminRole(role);
  }

  /// 群主 / 管理员不受全员禁言与个人禁言约束。
  static bool isMuteExemptRole(int? role) => isManagerRole(role);

  /// 能否发言：角色豁免 > 全员禁言 > 个人 muteUntil（秒）。
  static bool canSpeakInGroup({
    required int? role,
    required bool isAllMuted,
    required int muteUntilSeconds,
    required int nowSeconds,
  }) {
    if (isMuteExemptRole(role)) {
      return true;
    }
    if (isAllMuted) {
      return false;
    }
    return muteUntilSeconds <= nowSeconds;
  }

  /// 是否显示踢人入口（资料页「−」、聊天页菜单等）。
  ///
  /// Work：仅群主；Public / Meeting / Community：群主或管理员。
  static bool canKickMemberEntry({
    required int? selfRole,
    required String? groupType,
  }) {
    if (groupType == GroupType.Work) {
      return isOwnerRole(selfRole);
    }
    if (groupType == GroupType.Public ||
        groupType == GroupType.Meeting ||
        groupType == GroupType.Community) {
      return isManagerRole(selfRole);
    }
    return false;
  }

  /// 目标成员是否可被当前用户踢出（资料页语义）。
  ///
  /// 群主可踢 Admin + Member；管理员只能踢 Member；不可踢群主。
  static bool canKickTargetMember({
    required int? selfRole,
    required int? targetRole,
  }) {
    final target =
        targetRole ?? GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
    if (isOwnerRole(target)) {
      return false;
    }
    if (isOwnerRole(selfRole)) {
      return target == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER ||
          isAdminRole(target);
    }
    if (isAdminRole(selfRole)) {
      return target == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
    }
    return false;
  }

  /// 是否可对目标成员执行个人禁言 / 解禁。
  ///
  /// 管理端 + 非 Work + 未全员禁言 + 目标为普通成员。
  static bool canMuteTargetMember({
    required int? selfRole,
    required int? targetRole,
    required String? groupType,
    required bool isAllMuted,
  }) {
    if (!isManagerRole(selfRole)) {
      return false;
    }
    if (groupType == GroupType.Work) {
      return false;
    }
    if (isAllMuted) {
      return false;
    }
    final target =
        targetRole ?? GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
    return target == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
  }

  /// 角色排序权重：群主 < 管理员 < 其他（升序置顶）。
  static int memberSortRank(int? role) {
    if (isOwnerRole(role)) {
      return 0;
    }
    if (isAdminRole(role)) {
      return 1;
    }
    return 2;
  }

  /// 角色徽章 key：`owner` / `admin`；普通成员返回 null。
  static String? roleBadgeKey(int? role) {
    if (isOwnerRole(role)) {
      return 'owner';
    }
    if (isAdminRole(role)) {
      return 'admin';
    }
    return null;
  }
}
