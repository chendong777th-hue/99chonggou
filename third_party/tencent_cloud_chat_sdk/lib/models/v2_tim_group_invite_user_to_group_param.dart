/// V2TimGroupInviteUserToGroupParam
///
/// {@category Models}
///
class V2TimGroupInviteUserToGroupParam {
  late String groupID;
  late List<String> userList;
  String? customData;

  V2TimGroupInviteUserToGroupParam({required this.groupID, required this.userList, this.customData});

  Map<dynamic, dynamic> toJson() {
    return {
      "group_invite_member_param_group_id": groupID,
      "group_invite_member_param_identifier_array": userList,
      "group_invite_member_param_user_data": customData,
    };
  }

  String toLogString() {
    String res = "groupID: $groupID|userList: $userList|customData: $customData";
    return res;
  }
}
