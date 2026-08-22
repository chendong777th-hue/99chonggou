/// V2TimFriendGroupModifyParam
///
/// {@category Models}
///
class V2TimFriendGroupModifyParam {
    late String groupName;
    String? newGroupName;
    List<String>? addUserIDList;
    List<String>? deleteUserIDList;

  V2TimFriendGroupModifyParam({
    required this.groupName,
    this.newGroupName,
    this.addUserIDList,
    this.deleteUserIDList,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['friendship_modify_friend_group_param_name'] = groupName;
    data['friendship_modify_friend_group_param_new_name'] = newGroupName;
    data['friendship_modify_friend_group_param_add_identifier_array'] = addUserIDList;
    data['friendship_modify_friend_group_param_delete_identifier_array'] = deleteUserIDList;

    return data;
  }

  String toLogString() {
    String res = "groupName: $groupName|newGroupName: $newGroupName|addUserIDList: $addUserIDList|deleteUserIDList: $deleteUserIDList";
    return res;
  }
}
