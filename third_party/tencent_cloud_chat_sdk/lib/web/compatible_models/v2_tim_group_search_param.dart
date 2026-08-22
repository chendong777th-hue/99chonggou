import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupSearchParam
///
/// {@category Models}
///
class V2TimGroupSearchParam {
  static const int V2TIM_KEYWORD_LIST_MATCH_TYPE_OR = 0;
  static const int V2TIM_KEYWORD_LIST_MATCH_TYPE_AND = 1;

  late List<String> keywordList;
  bool isSearchGroupID = true;
  bool isSearchGroupName = true;

  /// 设置指定关键字列表匹配类型，可设置为“或”关系搜索或者“与”关系搜索（仅云端搜索有效），web 不支持
  int keywordListMatchType = V2TIM_KEYWORD_LIST_MATCH_TYPE_OR;

  /// 设置每次云端搜索返回结果的条数（必须大于 0，最大支持 100，默认 20，仅云端搜索有效），web 不支持
  int searchCount = 20;

  /// 设置每次云端搜索的起始位置。第一次填空字符串，续拉时填写 V2TimGroupSearchResult 中的返回值（仅云端搜索有效），web 不支持
  String searchCursor = "";

  V2TimGroupSearchParam({
    required this.keywordList,
    this.isSearchGroupID = true,
    this.isSearchGroupName = true,
    this.keywordListMatchType = V2TIM_KEYWORD_LIST_MATCH_TYPE_OR,
    this.searchCount = 20,
    this.searchCursor = "",
  });

  V2TimGroupSearchParam.fromJson(Map json) {
    json = Utils.formatJson(json);
    keywordList = json['keywordList'];
    isSearchGroupID = json['isSearchGroupID'];
    isSearchGroupName = json['isSearchGroupName'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['keywordList'] = keywordList;
    data['isSearchGroupID'] = isSearchGroupID;
    data['isSearchGroupName'] = isSearchGroupName;
    return data;
  }
  String toLogString() {
    String res = "${json.encode(keywordList)}|isSearchGroupID:$isSearchGroupID|isSearchGroupName:$isSearchGroupName";
    return res;
  }
}
