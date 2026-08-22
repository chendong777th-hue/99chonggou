import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';

/// V2TimGrantAdministrator
///
/// {@category Models}
///
class V2TimGrantAdministrator {
  late String groupID;
  V2TimGroupMemberInfo? opUser;
  List<V2TimGroupMemberInfo>? memberList = List.empty(growable: true);

  V2TimGrantAdministrator({
    required this.groupID,
    this.opUser,
    this.memberList,
  });

  V2TimGrantAdministrator.fromJson(Map json) {
    json = Utils.formatJson(json);
    groupID = json['groupID'] ?? '';
    opUser = json['opUser'] != null
        ? V2TimGroupMemberInfo.fromJson(json['opUser'])
        : null;
    if (json['memberList'] != null) {
      memberList = List.empty(growable: true);
      json['memberList'].forEach((v) {
        memberList!.add(V2TimGroupMemberInfo.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['groupID'] = groupID;
    if (opUser != null) {
      data['opUser'] = opUser?.toJson();
    }
    if (memberList != null) {
      data['memberList'] = memberList?.map((v) => v.toJson()).toList();
    }
    return data;
  }
  String toLogString() {
    String res = "groupID:$groupID|opUser:${opUser?.userID}|memberList:${json.encode(memberList?.map((e) => e.toLogString()).toList())}";
    return res;
  }
}
// {
//   "groupID":"",
//   "opUser":{},
//   "memberList":[{}]
// }
