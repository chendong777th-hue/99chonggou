import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';

/// V2TimGroupDismissed
///
/// {@category Models}
///
class V2TimGroupDismissed {
  late String groupID;
  late V2TimGroupMemberInfo opUser;

  V2TimGroupDismissed({
    required this.groupID,
    required this.opUser,
  });

  V2TimGroupDismissed.fromJson(Map json) {
    json = Utils.formatJson(json);
    groupID = json['groupID'] ?? '';
    opUser = V2TimGroupMemberInfo.fromJson(json['opUser'] ?? {});
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['groupID'] = groupID;
    data['opUser'] = opUser.toJson();
    return data;
  }
  String toLogString() {
    String res = "groupID:$groupID|opUser:${opUser.userID}";
    return res;
  }
}
// {
//   "groupID":"",
//   "opUser":{}
// }
