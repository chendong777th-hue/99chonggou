import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimApplicationProcessed
///
/// {@category Models}
///

class V2TimApplicationProcessed {
  late String groupID;
  late V2TimGroupMemberInfo opUser;
  late bool isAgreeJoin;
  late String? opReason;

  V2TimApplicationProcessed({
    required this.groupID,
    required this.opUser,
    required this.isAgreeJoin,
    this.opReason,
  });

  V2TimApplicationProcessed.fromJson(Map json) {
    json = Utils.formatJson(json);
    groupID = json['groupID'];
    opUser = V2TimGroupMemberInfo.fromJson(json['opUser'] ?? {});
    isAgreeJoin = json['isAgreeJoin'];
    opReason = json['opReason'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['groupID'] = groupID;
    data['opUser'] = opUser.toJson();
    data['isAgreeJoin'] = isAgreeJoin;
    data['opReason'] = opReason;
    return data;
  }

  String toLogString() {
    String res = "groupID:$groupID|opUser:${opUser.toLogString()}|isAgreeJoin:$isAgreeJoin|opReason:$opReason";
    return res;
  }
}
// {
//     "groupID": "",
//     "opUser": {},
//     "isAgreeJoin": true,
//     "opReason": ""
// }
