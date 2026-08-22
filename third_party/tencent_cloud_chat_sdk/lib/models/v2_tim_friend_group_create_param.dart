/// V2TimFriendGroupCreateParam
///
/// {@category Models}
///
class V2TimFriendGroupCreateParam {
    late List<String> groupNameList;
    late List<String> userIDList;

  V2TimFriendGroupCreateParam({
    required this.groupNameList,
    required this.userIDList,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['friendship_create_friend_group_param_name_array'] = groupNameList;
    data['friendship_create_friend_group_param_identifier_array'] = userIDList;

    return data;
  }

  String toLogString() {
    String res = "groupNameList:$groupNameList|userIDList:$userIDList";
    return res;
  }
}
