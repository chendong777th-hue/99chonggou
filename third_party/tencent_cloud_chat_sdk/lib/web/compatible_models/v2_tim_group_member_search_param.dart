import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupMemberSearchParam
///
/// {@category Models}
///
class V2TimGroupMemberSearchParam {
  static const int V2TIM_KEYWORD_LIST_MATCH_TYPE_OR = 0;
  static const int V2TIM_KEYWORD_LIST_MATCH_TYPE_AND = 1;

  late List<String> keywordList;
  List<String>? groupIDList;
  bool isSearchMemberUserID = true;
  bool isSearchMemberNickName = true;
  bool isSearchMemberRemark = true;
  bool isSearchMemberNameCard = true;

  /// 设置指定关键字列表匹配类型，可设置为“或”关系搜索或者“与”关系搜索（仅云端搜索有效），默认为 “或” 关系搜索，web 不支持
  int keywordListMatchType = V2TIM_KEYWORD_LIST_MATCH_TYPE_OR;

  /// 设置每次云端搜索返回结果的条数（必须大于 0，最大支持 100，默认 20，仅云端搜索有效），web 不支持
  int searchCount = 20;

  /// 设置每次云端搜索的起始位置。第一次填空字符串，续拉时填写 V2TimGroupSearchResult 中的返回值（仅云端搜索有效），web 不支持
  String searchCursor = '';

  V2TimGroupMemberSearchParam({
    required this.keywordList,
    this.groupIDList,
    this.isSearchMemberUserID = true,
    this.isSearchMemberNickName = true,
    this.isSearchMemberRemark = true,
    this.isSearchMemberNameCard = true,
    this.keywordListMatchType = V2TIM_KEYWORD_LIST_MATCH_TYPE_OR,
    this.searchCount = 20,
    this.searchCursor = '',
  });

  V2TimGroupMemberSearchParam.fromJson(Map json) {
    json = Utils.formatJson(json);
    keywordList = json['keywordList'];
    groupIDList = json['groupIDList'];
    isSearchMemberUserID = json['isSearchMemberUserID'];
    isSearchMemberNickName = json['isSearchMemberNickName'];
    isSearchMemberRemark = json['isSearchMemberRemark'];
    isSearchMemberNameCard = json['isSearchMemberNameCard'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['keywordList'] = keywordList;
    data['groupIDList'] = groupIDList;
    data['isSearchMemberUserID'] = isSearchMemberUserID;
    data['isSearchMemberNickName'] = isSearchMemberNickName;
    data['isSearchMemberRemark'] = isSearchMemberRemark;
    data['isSearchMemberNameCard'] = isSearchMemberNameCard;
    return data;
  }
  String toLogString() {
    String res =
        "keywordList:${json.encode(keywordList)}|groupIDList:${json.encode(groupIDList)}|isSearchMemberUserID:$isSearchMemberUserID|isSearchMemberNickName:$isSearchMemberNickName|isSearchMemberRemark:$isSearchMemberRemark|isSearchMemberNameCard:$isSearchMemberNameCard";
    return res;
  }
}
