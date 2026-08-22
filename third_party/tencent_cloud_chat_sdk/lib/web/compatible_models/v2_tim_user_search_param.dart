import 'dart:convert';

class V2TimUserSearchParam {
  static const int V2TIM_KEYWORD_LIST_MATCH_TYPE_OR = 0;
  static const int V2TIM_KEYWORD_LIST_MATCH_TYPE_AND = 1;

  /// 搜索的关键字列表，关键字列表最多支持 5 个，keyword 会自动匹配用户 ID、昵称。
  late List<String> keywordList;

  /// 指定关键字列表匹配类型，可设置为“或”关系搜索或者“与”关系搜索。
  int keywordListMatchType = V2TIM_KEYWORD_LIST_MATCH_TYPE_OR;

  /// 用户性别（如果不设置，默认男性和女性都会返回）
  int gender = 0;

  /// 用户最小生日（如果不设置，默认值为 0）
  int minBirthday = 0;

  /// 用户最大生日（如果不设置，默认 birthday >= minBirthday 的用户都会返回）
  int maxBirthday = 0;

  /// 每次云端搜索返回结果的条数（必须大于 0，最大支持 100，默认 20）
  int searchCount = 20;

  /// 每次云端搜索的起始位置。第一次填空字符串，续拉时填写 V2TimUserSearchResult 中的返回值。
  String searchCursor = '';

  V2TimUserSearchParam({
    required this.keywordList,
    this.keywordListMatchType = V2TIM_KEYWORD_LIST_MATCH_TYPE_OR,
    this.gender = 0,
    this.minBirthday = 0,
    this.maxBirthday = 0,
    this.searchCount = 20,
    this.searchCursor = '',
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_search_param_keyword_list'] = keywordList;
    data['user_search_param_keyword_list_match_type'] = keywordListMatchType;
    data['user_search_param_gender'] = gender;
    data['user_search_param_min_birthday'] = minBirthday;
    data['user_search_param_max_birthday'] = maxBirthday;
    data['user_search_param_search_count'] = searchCount;
    data['user_search_param_search_cursor'] = searchCursor;
    return data;
  }

  String toLogString() {
    String result =
        'keywordList:${json.encode(keywordList)}|keywordListMatchType:$keywordListMatchType|gender:$gender|minBirthday:$minBirthday|maxBirthday:$maxBirthday|searchCount:$searchCount|searchCursor:$searchCursor';
    return result;
  }
}
