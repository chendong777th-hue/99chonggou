import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_enum.dart';

class GroupGetMemberInfoListParam {
    late String groupID;
    late GroupMemberFilterTypeEnum filter;
    int? nextSeq;
    List<String>? memberList;

    // 获取全部角色类型
    static const int _kTIMGroupMemberRoleFlag_All = 0x00;
    // 获取所有者(群主)
    static const int _kTIMGroupMemberRoleFlag_Owner = 0x01;
    // 获取管理员，不包括群主
    static const int _kTIMGroupMemberRoleFlag_Admin = 0x01 << 1;
    // 获取普通群成员，不包括群主和管理员
    static const int _kTIMGroupMemberRoleFlag_Member = 0x01 << 2;

  GroupGetMemberInfoListParam({
    required this.groupID,
    required this.filter,
    this.nextSeq,
    this.memberList
  });

  int convertGroupMemberRoleFlag(GroupMemberFilterTypeEnum filter) {
    switch (filter) {
      case GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ALL:
        return _kTIMGroupMemberRoleFlag_All;
      case GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_OWNER:
        return _kTIMGroupMemberRoleFlag_Owner;
      case GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ADMIN:
        return _kTIMGroupMemberRoleFlag_Admin;
      case GroupMemberFilterTypeEnum.  V2TIM_GROUP_MEMBER_FILTER_COMMON:
        return _kTIMGroupMemberRoleFlag_Member;
      default:
        return _kTIMGroupMemberRoleFlag_All;
    }
  }

  Map<dynamic, dynamic> toJson() {
     Map<String, dynamic> option = {"group_member_get_info_option_role_flag" : convertGroupMemberRoleFlag(filter)};

    return {
      "group_get_members_info_list_param_group_id": groupID,
      "group_get_members_info_list_param_option": option,
      "group_get_members_info_list_param_next_seq": nextSeq,
      "group_get_members_info_list_param_identifier_array": memberList,
    };
  }

  String toLogString() {
    String res = "groupID:$groupID|filter:${convertGroupMemberRoleFlag(filter)}|nextSeq:$nextSeq|memberList:$memberList";
    return res;
  }
}
