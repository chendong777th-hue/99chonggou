/// V2TimGroupKickGroupMemberParam
///
/// {@category Models}
///
class V2TimGroupKickGroupMemberParam {
  late String groupID;
  late List<String> userList;
  int? duration;
  String? reason;


  V2TimGroupKickGroupMemberParam({
    required this.groupID, 
    required this.userList, 
    this.duration, 
    this.reason
  });

  Map<dynamic, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["group_delete_member_param_group_id"] = groupID;
    data["group_delete_member_param_identifier_array"] = userList;
    if (duration != null) {
      data["group_delete_member_param_duration"] = duration;
    }
    data["group_delete_member_param_user_data"] = reason;
    return data;
  }

  String toLogString() {
    String res = "groupID: $groupID|userList: $userList|duration: $duration|reason: $reason";
    return res;
  }
}
