import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_result_item.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMessageSearchResult
///
/// {@category Models}
///
class V2TimMessageSearchResult {
  /// 如果您本次搜索【指定会话】，那么返回满足搜索条件的消息总数量；
  /// 如果您本次搜索【全部会话】，那么返回满足搜索条件的消息所在的所有会话总数量。
  int? totalCount;
  /// 如果您本次搜索【指定会话】，那么返回结果列表只包含该会话结果；
  /// 如果您本次搜索【全部会话】，那么对满足搜索条件的消息根据会话 ID 分组，分页返回分组结果。
  List<V2TimMessageSearchResultItem>? messageSearchResultItems;
  /// 下一次云端搜索的起始位置
  String? searchCursor;

  V2TimMessageSearchResult({
    this.totalCount,
    this.messageSearchResultItems,
    this.searchCursor,
  });

  V2TimMessageSearchResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    totalCount = json['msg_search_result_total_count'];
    searchCursor = json["msg_search_result_search_cursor"] ?? "";
    if (json['msg_search_result_item_array'] != null) {
      messageSearchResultItems = List.empty(growable: true);
      json['msg_search_result_item_array'].forEach((v) {
        messageSearchResultItems!.add(V2TimMessageSearchResultItem.fromJson(v));
      });
    } else {
      messageSearchResultItems = [];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['totalCount'] = totalCount;
    data["searchCursor"] = searchCursor;
    if (messageSearchResultItems != null) {
      data['messageSearchResultItems'] = messageSearchResultItems?.map((v) => v.toJson()).toList();
    }
    return data;
  }

  String toLogString() {
    String res = "totalCount:$totalCount|searchCursor:$searchCursor|messageSearchResultItems:${json.encode(messageSearchResultItems?.map((e) => e.toJson()).toList())}";
    return res;
  }
}

// {
//   "userID":"",
//   "timestamp":0
// }
