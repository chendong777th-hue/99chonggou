import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_info.dart';

class V2TimUserSearchResult {
  /// 是否已经返回全部满足搜索条件的用户列表
  bool? isFinished;
  /// 满足搜索条件的用户总数量
  int? totalCount;
  /// 下一次云端搜索的起始位置
  String? nextCursor;
  /// 当前一次云端搜索返回的用户列表
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
      final List<dynamic> userList = jsonDecode(json['user_search_result_user_list']);
      for (var userInfoMap in userList) {
        userInfoList!.add(V2TimUserInfo.fromJson(userInfoMap));
      }
    } else {
      userInfoList = [];
    }
  }

  String toLogString() {
     String result = "isFinished:$isFinished|totalCount:$totalCount|nextCursor:$nextCursor|userInfoList:${json.encode(userInfoList)}";
     return result;
  }
}