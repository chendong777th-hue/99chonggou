import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_change_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimGroupInfoChanged {
  late String groupID;
  late List<V2TimGroupChangeInfo?>? groupChangeInfoList;

  V2TimGroupInfoChanged({
    required this.groupID,
    this.groupChangeInfoList,
  });

  V2TimGroupInfoChanged.fromJson(Map json) {
    json = Utils.formatJson(json);
    groupID = json['groupID'] ?? '';
    groupChangeInfoList = null;
    if (json['groupChangeInfo'] != null) {
      groupChangeInfoList = List.empty(growable: true);
      json['groupChangeInfo'].forEach((v) {
        groupChangeInfoList!.add(V2TimGroupChangeInfo.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['groupID'] = groupID;
    if (groupChangeInfoList != null) {
      data['groupChangeInfo'] =
          groupChangeInfoList?.map((v) => v?.toJson()).toList();
    }
    return data;
  }
  String toLogString() {
    String res = "groupID:$groupID|groupChangeInfo:${json.encode(groupChangeInfoList?.map((e) => e?.toLogString()).toList())}";
    return res;
  }
}
// {
//   "groupID":"",
//   "groupChangeInfo":[{}]
// }
