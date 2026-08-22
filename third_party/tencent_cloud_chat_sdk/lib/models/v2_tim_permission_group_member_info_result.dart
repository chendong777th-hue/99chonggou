import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimPermissionGroupMemberInfoResult {
  String nextCursor;
  List<V2TimGroupMemberFullInfo>? memberInfoList;
  V2TimPermissionGroupMemberInfoResult({
    required this.nextCursor,
    this.memberInfoList,
  });
  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from({
      'nextCursor': nextCursor,
      'memberInfoList': memberInfoList ?? [],
    });
  }

  static V2TimPermissionGroupMemberInfoResult fromJson(Map json) {
    json = Utils.formatJson(json);
    return V2TimPermissionGroupMemberInfoResult(
      nextCursor: json['permission_group_member_info_result_next_cursor'] ?? '',
      memberInfoList: json['permission_group_member_info_result_array']?.map((e) => V2TimGroupMemberFullInfo.fromJson(e)).toList(),
    );
  }

  String toLogString() {
    String res = "memberInfoList:${json.encode(memberInfoList?.map((e) => e.toLogString()).toList())}|nextCursor:$nextCursor";
    return res;
  }
}
