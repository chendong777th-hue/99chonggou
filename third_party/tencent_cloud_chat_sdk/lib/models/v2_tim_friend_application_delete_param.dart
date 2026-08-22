import 'package:tencent_cloud_chat_sdk/enum/friend_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';

/// V2TimFriendApplicationDeleteParam
///
/// {@category Models}
///
class V2TimFriendApplicationDeleteParam {
  late List<String> userIDList;
  late FriendApplicationTypeEnum applicationType;

  V2TimFriendApplicationDeleteParam({
    required this.userIDList,
    required this.applicationType,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['friendship_delete_pendency_param_identifier_array'] = userIDList;
    data['friendship_delete_pendency_param_type'] = EnumUtils.dartFriendApplicationTypeEnum2CType(applicationType);
    return data;
  }

  String toLogString() {
    String res = "userIDList:$userIDList|applicationType:$applicationType";
    return res;
  }
}
