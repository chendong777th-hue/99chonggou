import 'dart:convert';
import 'dart:ffi';

import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart';

/// V2TimMessageSearchResult
///
/// {@category Models}
///
class V2GroupMemberInfoSearchResult {
  /// 当前一次云端搜索返回的群成员列表
  Map<String, dynamic>? groupMemberSearchResultItems;
  /// 满足搜索条件的群成员列表是否已经全部返回（仅云端搜索有效）
  bool? isFinished;
  /// 满足搜索条件的群成员总数量（仅云端搜索有效）
  int? totalCount;
  /// 下一次云端搜索的起始位置（仅云端搜索有效）
  String? nextCursor;

  V2GroupMemberInfoSearchResult({
    this.groupMemberSearchResultItems,
  });

  // tim_group_manager searchGroupMembers 中会对本地搜索返回的结果预处理，然后再调用该方法
  V2GroupMemberInfoSearchResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    Map<String, dynamic> resultMap = {};
    json.forEach((key, value) {
      var tempArr = [];
      if (value is List) {
        for (var element in value) {
          tempArr.add(V2TimGroupMemberFullInfo.fromJson(element));
        }
        resultMap[key] = tempArr;
      }
    });
    groupMemberSearchResultItems = resultMap;
  }

  // tim_group_manager searchCloudGroupMembers 在 v2_tim_value_callback 中处理云端搜索的结果
  V2GroupMemberInfoSearchResult.fromJsonForCloudSearch(Map json) {
    isFinished = json['group_member_search_result_is_finished'];
    totalCount = json['group_member_search_result_total_count'];
    nextCursor = json['group_member_search_result_next_cursor'];

    final memberListStr = json['group_member_search_result_member_list'] as String;
    final List<dynamic> memberList = jsonDecode(memberListStr);
    Map<String, dynamic> resultMap = {};
    for (var item in memberList) {
      final groupId = item['group_search_member_result_groupid'] as String;
      final memberInfoList = item['group_search_member_result_member_info_list'];

      if (memberInfoList.isNotEmpty) {
        resultMap[groupId] = memberInfoList.map((e) => V2TimGroupMemberFullInfo.fromJson(e)).toList();
      } else {
        resultMap[groupId] = [];
      }
    }
    groupMemberSearchResultItems = resultMap;
  }

  String toLogString() {
    String res = json.encode(groupMemberSearchResultItems);
    return res;
  }
}
