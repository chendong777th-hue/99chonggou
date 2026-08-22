import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimUserInfoResult {
  String? nextCursor;
  List<V2TimUserFullInfo>? userFullInfoList;

  V2TimUserInfoResult({
    this.nextCursor,
    this.userFullInfoList,
  });

  V2TimUserInfoResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    nextCursor = json['follow_list_result_next_cursor'];
    if (json['follow_list_result_user_info_list'] != null) {
      userFullInfoList = List.empty(growable: true);
      json['follow_list_result_user_info_list'].forEach((v) {
        userFullInfoList!.add(V2TimUserFullInfo.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['nextCursor'] = nextCursor;
    if (userFullInfoList != null) {
      data['userFullInfoList'] =
          userFullInfoList!.map((v) => v.toJson()).toList();
    }
    return data;
  }
  String toLogString() {
    String res = "nextCursor:$nextCursor|userFullInfoList:${json.encode(userFullInfoList?.map((e) => e.toLogString()).toList())}";
    return res;
  }
}
