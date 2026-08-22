import 'dart:convert';

/// V2TimGroupSearchParam
///
/// {@category Models}
///
class V2TimGroupSearchParam {
  static const int V2TIM_KEYWORD_LIST_MATCH_TYPE_OR = 0;
  static const int V2TIM_KEYWORD_LIST_MATCH_TYPE_AND = 1;

  /// 搜索关键字列表, 最多支持 5 个。如果是本地搜索，您需主动设置 keyword 是否匹配群 ID、群名称。如果是云端搜索，keyword 会自动匹配群 ID、群名称
  late List<String> keywordList;

  /// 是否搜索群 ID，仅本地搜索有效
  bool isSearchGroupID = true;

  /// 是否搜索群名称，仅本地搜索有效
  bool isSearchGroupName = true;

  /// 设置指定关键字列表匹配类型，可设置为“或”关系搜索或者“与”关系搜索（仅云端搜索有效）
  int keywordListMatchType = V2TIM_KEYWORD_LIST_MATCH_TYPE_OR;

  /// 设置每次云端搜索返回结果的条数（必须大于 0，最大支持 100，默认 20，仅云端搜索有效）
  int searchCount = 20;

  /// 设置每次云端搜索的起始位置。第一次填空字符串，续拉时填写 V2TimGroupSearchResult 中的返回值（仅云端搜索有效）
  String searchCursor = "";

  // 群搜索的枚举
  // 搜索群 ID
  static const int _kTIMGroupSearchFieldKey_GroupId = 0x01;

  // 搜索群名称
  static const int _kTIMGroupSearchFieldKey_GroupName = 0x01 << 1;

  V2TimGroupSearchParam({
    required this.keywordList,
    this.isSearchGroupID = true,
    this.isSearchGroupName = true,
    this.keywordListMatchType = V2TIM_KEYWORD_LIST_MATCH_TYPE_OR,
    this.searchCount = 20,
    this.searchCursor = "",
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_search_params_keyword_list'] = keywordList;
    List<int> searchFieldList = [];
    if (isSearchGroupID) {
      searchFieldList.add(_kTIMGroupSearchFieldKey_GroupId);
    }

    if (isSearchGroupName) {
      searchFieldList.add(_kTIMGroupSearchFieldKey_GroupName);
    }

    data['group_search_params_field_list'] = searchFieldList;
    // 云端搜索
    if (keywordListMatchType == V2TIM_KEYWORD_LIST_MATCH_TYPE_OR) {
      data['group_search_params_keyword_list_match_type'] = 0;
    } else {
      data['group_search_params_keyword_list_match_type'] = 1;
    }

    data['group_search_params_search_count'] = searchCount;
    data['group_search_params_search_cursor'] = searchCursor;

    return data;
  }

  String toLogString() {
    String res =
        "keywordList:${json.encode(keywordList)}|isSearchGroupID:$isSearchGroupID|isSearchGroupName:$isSearchGroupName|keywordListMatchType:$keywordListMatchType|searchCount:$searchCount|searchCursor:$searchCursor";
    return res;
  }
}
