import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';

/// V2TimMessageSearchResult
///
/// {@category Models}
///
class V2GroupMemberInfoSearchResult {
  /// 当前一次云端搜索返回的群成员列表
  Map<String, dynamic>? groupMemberSearchResultItems;
  /// 满足搜索条件的群成员列表是否已经全部返回（仅云端搜索有效），web 不支持
  bool? isFinished;
  /// 满足搜索条件的群成员总数量（仅云端搜索有效），web 不支持
  int? totalCount;
  /// 下一次云端搜索的起始位置（仅云端搜索有效），web 不支持
  String? nextCursor;

  V2GroupMemberInfoSearchResult({
    this.groupMemberSearchResultItems,
  });

  V2GroupMemberInfoSearchResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    Map<String, dynamic> myMap = {};
    json.forEach((key, value) {
      var tempArr = [];
      if (value is List) {
        for (var element in value) {
          tempArr.add(V2TimGroupMemberFullInfo.fromJson(element));
        }
        myMap[key] = tempArr;
      }
    });
    groupMemberSearchResultItems = myMap;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (groupMemberSearchResultItems != null) {
      var map = groupMemberSearchResultItems;
      var newMap = {};
      map?.forEach((key, value) {
        newMap[key] = value.map((v) => v.toJson()).toList();
      });
      data['messageSearchResultItems'] = newMap;
    }
    return data;
  }
  String toLogString() {
    String res = json.encode(groupMemberSearchResultItems);
    return res;
  }
}
