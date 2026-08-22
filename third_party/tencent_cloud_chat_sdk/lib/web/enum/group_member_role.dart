// ignore_for_file: non_constant_identifier_names
@JS()
library js_interop;

import 'package:js/js.dart'; // Pull in our dependency

import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

@JS("TencentCloudChat")
class GroupMemberRole {
  external static dynamic TYPES; // 这个是用作枚举的
}

class GroupMemberRoleWeb {
  static String GRP_MBR_ROLE_ADMIN =
      jsToMap(GroupMemberRole.TYPES)['GRP_MBR_ROLE_ADMIN']; // 管理员
  static String GRP_MBR_ROLE_MEMBER =
      jsToMap(GroupMemberRole.TYPES)['GRP_MBR_ROLE_MEMBER']; // 成员
  static String GRP_MBR_ROLE_OWNER =
      jsToMap(GroupMemberRole.TYPES)['GRP_MBR_ROLE_OWNER']; // 群主

  static int convertGroupMemberRole(String role) {
    if (role == GRP_MBR_ROLE_ADMIN) {
      return GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN;
    }

    if (role == GRP_MBR_ROLE_MEMBER) {
      return GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
    }

    if (role == GRP_MBR_ROLE_OWNER) {
      return GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER;
    }

    return GroupMemberRoleType.V2TIM_GROUP_MEMBER_UNDEFINED;
  }

  static String convertGroupMemberRoleToWeb(int role) {
    if (role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN) {
      return GRP_MBR_ROLE_ADMIN;
    }

    if (role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER) {
      return GRP_MBR_ROLE_MEMBER;
    }

    if (role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER) {
      return GRP_MBR_ROLE_OWNER;
    }

    return '';
  }

  static String convertGroupMemberRoleParameterToWeb(int role) {
    if (role == GroupMemberFilterType.V2TIM_GROUP_MEMBER_FILTER_ADMIN) {
      return GRP_MBR_ROLE_ADMIN;
    }

    if (role == GroupMemberFilterType.V2TIM_GROUP_MEMBER_FILTER_COMMON) {
      return GRP_MBR_ROLE_MEMBER;
    }

    if (role == GroupMemberFilterType.V2TIM_GROUP_MEMBER_FILTER_OWNER) {
      return GRP_MBR_ROLE_OWNER;
    }

    return '';
  }
}
