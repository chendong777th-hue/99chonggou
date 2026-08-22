import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart';

class V2TimGroupSearchResult {
  /// 满足搜索条件的群组列表是否已经全部返回
  bool? isFinished;
  /// 满足搜索条件的群组总数量
  int? totalCount;
  /// 下一次云端搜索的起始位置
  String? nextCursor;
  /// 当前一次云端搜索返回的群组列表
  List<V2TimGroupInfo>? groupList;

  V2TimGroupSearchResult({
    this.isFinished,
    this.totalCount,
    this.nextCursor,
    this.groupList,
  });

  V2TimGroupSearchResult.fromJson(Map json) {
    isFinished = json['group_search_result_is_finished'];
    totalCount = json['group_search_result_total_count'];
    nextCursor = json['group_search_result_next_cursor'];
    if (json['group_search_result_group_list'] != null) {
      groupList = List.empty(growable: true);
      json['group_search_result_group_list'].forEach((v) {
        groupList!.add(V2TimGroupInfo.fromJson(v));
      });
    } else {
      groupList = [];
    }
  }

  String toLogString() {
    String res = "isFinished:$isFinished|totalCount:$totalCount|nextCursor:$nextCursor|groupInfoList:${json.encode(groupList?.map((e) => e.toJson()).toList())}";
    return res;
  }

}