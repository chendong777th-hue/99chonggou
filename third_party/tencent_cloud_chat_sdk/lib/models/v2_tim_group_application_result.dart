import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart';
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
    unreadCount = json['group_pendency_result_unread_num'] ?? 0;
    if (json['group_pendency_result_pendency_array'] != null) {
      groupApplicationList = List.empty(growable: true);
      json['group_pendency_result_pendency_array'].forEach((v) {
        groupApplicationList!.add(V2TimGroupApplication.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_pendency_result_unread_num'] = unreadCount;
    if (groupApplicationList != null) {
      data['group_pendency_result_pendency_array'] = groupApplicationList?.map((v) => v?.toJson()).toList();
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
