import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMemberEnter
///
/// {@category Models}
///
class V2TimMemberEnter {
  late String groupID;
  late List<V2TimGroupMemberInfo?>? memberList = List.empty(growable: true);

  V2TimMemberEnter({required this.groupID, this.memberList});

  V2TimMemberEnter.fromJson(Map json) {
    json = Utils.formatJson(json);
    groupID = json['groupID'] ?? '';
    memberList = List.empty(growable: true);
    if (json['memberList'] != null) {
      json['memberList'].forEach((v) {
        memberList!.add(V2TimGroupMemberInfo.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['groupID'] = groupID;
    if (memberList != null) {
      data['memberList'] = memberList?.map((v) => v?.toJson()).toList();
    }
    return data;
  }
  String toLogString() {
    String res = "groupID:$groupID|memberList:${json.encode(memberList?.map((e) => e?.toLogString()).toList())}";
    return res;
  }
}
// {
//   "groupID":"",
//   "memberList":[{}]
// }
