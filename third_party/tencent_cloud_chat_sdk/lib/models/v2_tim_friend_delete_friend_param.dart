import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';

/// V2TimFriendDeleteFriendParam
///
/// {@category Models}
///
class V2TimFriendDeleteFriendParam {
    late List<String> userIDList;
    late FriendTypeEnum deleteType;

  V2TimFriendDeleteFriendParam({
    required this.userIDList,
    required this.deleteType,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['friendship_delete_friend_param_identifier_array'] = userIDList;
    data['friendship_delete_friend_param_friend_type'] = EnumUtils.dartFriendTypeEnum2CType(deleteType);

    return data;
  }

  String toLogString() {
    String res = "userIDList:$userIDList|deleteType:$deleteType";
    return res;
  }
}
