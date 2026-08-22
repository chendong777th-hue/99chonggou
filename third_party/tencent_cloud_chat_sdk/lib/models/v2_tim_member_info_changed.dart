import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_change_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMemberInfoChanged
///
/// {@category Models}
///
class V2TimMemberInfoChanged {
  late String groupID;
  late List<V2TimGroupMemberChangeInfo?>? groupMemberChangeInfoList =
      List.empty(growable: true);

  V2TimMemberInfoChanged({
    required this.groupID,
    this.groupMemberChangeInfoList,
  });

  V2TimMemberInfoChanged.fromJson(Map json) {
    json = Utils.formatJson(json);
    groupID = json['groupID'] ?? '';
    groupMemberChangeInfoList = List.empty(growable: true);
    if (json['groupMemberChangeInfoList'] != null) {
      json['groupMemberChangeInfoList'].forEach((v) {
        groupMemberChangeInfoList?.add(V2TimGroupMemberChangeInfo.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['groupID'] = groupID;
    if (groupMemberChangeInfoList != null) {
      data['groupMemberChangeInfoList'] =
          groupMemberChangeInfoList?.map((v) => v?.toJson()).toList();
    }
    return data;
  }
  String toLogString() {
    String res = "groupID:$groupID|${json.encode(groupMemberChangeInfoList?.map((e) => e?.toLogString()).toList())}";
    return res;
  }
}
// {
//   "groupID":"",
//   "groupMemberChangeInfoList":[{}]
// }
