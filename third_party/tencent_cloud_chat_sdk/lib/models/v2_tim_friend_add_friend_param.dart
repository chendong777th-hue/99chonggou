import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';

/// V2TimFriendAddFriendParam
///
/// {@category Models}
///
class V2TimFriendAddFriendParam {
    late String userID;
    String? remark;
    String? friendGroup;
    String? addWording;
    String? addSource;
    late FriendTypeEnum addType;

  V2TimFriendAddFriendParam({
    required this.userID,
    this.remark,
    this.friendGroup,
    this.addWording,
    this.addSource,
    required this.addType,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['friendship_add_friend_param_identifier'] = userID;
    data['friendship_add_friend_param_friend_type'] = EnumUtils.dartFriendTypeEnum2CType(addType);
    data['friendship_add_friend_param_remark'] = remark;
    data['friendship_add_friend_param_group_name'] = friendGroup;
    data['friendship_add_friend_param_add_source'] = addSource;
    data['friendship_add_friend_param_add_wording'] = addWording;

    return data;
  }

  String toLogString() {
    String res = "userID:$userID|remark:$remark|friendGroup:$friendGroup|addWording:$addWording|addSource:$addSource|addType:$addType";
    return res;
  }
}
