import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_info.dart';

class V2TimUserSearchResult {
  bool? isFinished;
  int? totalCount;
  String? nextCursor;
  List<V2TimUserInfo>? userInfoList;

  V2TimUserSearchResult({
    this.isFinished,
    this.totalCount,
    this.nextCursor,
    this.userInfoList,
  });

  V2TimUserSearchResult.fromJson(Map json) {
    isFinished = json['user_search_result_is_finished'];
    totalCount = json['user_search_result_total_count'];
    nextCursor = json['user_search_result_next_cursor'];
    if (json['user_search_result_user_list'] != null) {
      userInfoList = List.empty(growable: true);
      json['user_search_result_user_list'].forEach((v) {
        userInfoList!.add(V2TimUserInfo.fromJson(v));
      });
    } else {
      userInfoList = [];
    }
  }

  String toLogString() {
     String result = "isFinished:$isFinished|totalCount:$totalCount|nextCursor:$nextCursor|userInfoList:${json.encode(userInfoList)}";
     return result;
  }
}