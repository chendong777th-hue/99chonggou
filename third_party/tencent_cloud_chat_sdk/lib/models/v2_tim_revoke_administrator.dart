import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimRevokeAdministrator
///
/// {@category Models}
///
class V2TimRevokeAdministrator {
  late String groupID;
  late V2TimGroupMemberInfo opUser;
  late List<V2TimGroupMemberInfo?>? memberList = List.empty(growable: true);

  V2TimRevokeAdministrator({
    required this.groupID,
    required this.opUser,
    this.memberList,
  });

  V2TimRevokeAdministrator.fromJson(Map json) {
    json = Utils.formatJson(json);
    groupID = json['groupID'] ?? '';
    opUser = V2TimGroupMemberInfo.fromJson(json['opUser'] ?? {});
    memberList = List.empty(growable: true);
    if (json['memberList'] != null) {
      json['memberList'].forEach((v) {
        memberList!.add(V2TimGroupMemberInfo.fromJson(v));
      });
    } else {
      memberList = [];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['groupID'] = groupID;
    data['opUser'] = opUser.toJson();
    if (memberList != null) {
      data['memberList'] = memberList?.map((v) => v?.toJson()).toList();
    }
    return data;
  }

  String toLogString() {
    String res = "groupID:$groupID|opUser:${opUser.toLogString()}|memberList:${json.encode(memberList?.map((e) => e?.toLogString()).toList())}";
    return res;
  }
}
// {
//   "groupID":"",
//   "opUser":{},
//   "memberList":[{}]
// }
