import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupApplicationResult
///
/// {@category Models}
///
class V2TimGroupApplicationResult {
  late int? unreadCount = 0;
  List<V2TimGroupApplication?>? groupApplicationList = List.empty(growable: true);

  V2TimGroupApplicationResult({
    this.unreadCount,
    this.groupApplicationList,
  });

  V2TimGroupApplicationResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    unreadCount = json['unreadCount'];
    if (json['groupApplicationList'] != null) {
      groupApplicationList = List.empty(growable: true);
      json['groupApplicationList'].forEach((v) {
        groupApplicationList!.add(V2TimGroupApplication.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['unreadCount'] = unreadCount;
    if (groupApplicationList != null) {
      data['groupApplicationList'] = groupApplicationList?.map((v) => v?.toJson()).toList();
    }
    return data;
  }

  String toLogString() {
    String res = "unreadCount:$unreadCount|groupApplicationList:${json.encode(groupApplicationList?.map((e) => e?.toLogString()).toList())}";
    return res;
  }
}
// {
//   "unreadCount":0,
//   "groupApplicationList":[]
// }
