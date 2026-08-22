import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMemberLeave
///
/// {@category Models}
///
class V2TimMemberLeave {
  late String groupID;
  late V2TimGroupMemberInfo member;

  V2TimMemberLeave({
    required this.groupID,
    required this.member,
  });

  V2TimMemberLeave.fromJson(Map json) {
    json = Utils.formatJson(json);
    groupID = json['groupID'] ?? '';
    member = V2TimGroupMemberInfo.fromJson(json['member'] ?? {});
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['groupID'] = groupID;
    data['member'] = member.toJson();
    return data;
  }
  String toLogString() {
    String res = "groupID:$groupID|member:${member.toLogString()}";
    return res;
  }
}

// {
//  "groupID":"",
//   "member":{}
// }
