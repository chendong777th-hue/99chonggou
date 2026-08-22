import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';

/// V2TimFriendCheckFriendTypeParam
///
/// {@category Models}
///
class V2TimFriendCheckFriendTypeParam {
    late List<String> userIDList;
    late FriendTypeEnum checkType;

  V2TimFriendCheckFriendTypeParam({
    required this.userIDList,
    required this.checkType,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['friendship_check_friendtype_param_identifier_array'] = userIDList;
    data['friendship_check_friendtype_param_check_type'] = EnumUtils.dartFriendTypeEnum2CType(checkType);

    return data;
  }

  String toLogString() {
    String res = "userIDList:$userIDList|checkType:$checkType";
    return res;
  }
}
