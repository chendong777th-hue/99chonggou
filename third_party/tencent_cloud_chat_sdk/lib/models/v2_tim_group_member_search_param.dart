import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupMemberSearchParam
///
/// {@category Models}
///
class V2TimGroupMemberSearchParam {
  static const int V2TIM_KEYWORD_LIST_MATCH_TYPE_OR = 0;
  static const int V2TIM_KEYWORD_LIST_MATCH_TYPE_AND = 1;

  /// 搜索关键字列表, 最多支持 5 个如果是本地搜索, 您需主动设置 keyword 是否匹配群成员 ID 、昵称、备注、群名片。 如果是云端搜索, keyword 会自动匹配群成员 ID 、昵称、群名片
  late List<String> keywordList;
  /// 指定群 ID 列表, 若为不填则搜索全部群中的群成员
  List<String>? groupIDList;
  /// 搜索域列表 (仅本地搜索有效)
  bool isSearchMemberUserID = true;
  bool isSearchMemberNickName = true;
  bool isSearchMemberRemark = true;
  bool isSearchMemberNameCard = true;

  /// 设置指定关键字列表匹配类型，可设置为“或”关系搜索或者“与”关系搜索（仅云端搜索有效），默认为 “或” 关系搜索
  int keywordListMatchType = V2TIM_KEYWORD_LIST_MATCH_TYPE_OR;

  /// 设置每次云端搜索返回结果的条数（必须大于 0，最大支持 100，默认 20，仅云端搜索有效）
  int searchCount = 20;

  /// 设置每次云端搜索的起始位置。第一次填空字符串，续拉时填写 V2TimGroupSearchResult 中的返回值（仅云端搜索有效）
  String searchCursor = '';

  // 1.9 群成员搜索 Field 的枚举
  // 用户 ID
  static const int _kTIMGroupMemberSearchFieldKey_Identifier = 0x01;
  // 昵称
  static const int _kTIMGroupMemberSearchFieldKey_NickName = 0x01 << 1;
  // 备注
  static const int _kTIMGroupMemberSearchFieldKey_Remark = 0x01 << 2;
  // 名片
  static const int _kTIMGroupMemberSearchFieldKey_NameCard = 0x01 << 3;

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

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_search_member_params_keyword_list'] = keywordList;
    data['group_search_member_params_groupid_list'] = groupIDList;
    List<int> searchFieldList = [];
    if (isSearchMemberUserID) {
      searchFieldList.add(_kTIMGroupMemberSearchFieldKey_Identifier);
    }
    if (isSearchMemberNickName) {
      searchFieldList.add(_kTIMGroupMemberSearchFieldKey_NickName);
    }
    if (isSearchMemberRemark) {
      searchFieldList.add(_kTIMGroupMemberSearchFieldKey_Remark);
    }
    if (isSearchMemberNameCard) {
      searchFieldList.add(_kTIMGroupMemberSearchFieldKey_NameCard);
    }
    data['group_search_member_params_field_list'] = searchFieldList;
    // 云端搜索
    if (keywordListMatchType == V2TIM_KEYWORD_LIST_MATCH_TYPE_OR) {
      data['group_member_search_params_keyword_list_match_type'] = 0;
    } else {
      data['group_member_search_params_keyword_list_match_type'] = 1;
    }

    data['group_member_search_params_search_count'] = searchCount;
    data['group_member_search_params_search_cursor'] = searchCursor;
    return data;
  }

  String toLogString() {
    String res =
        "keywordList:${json.encode(keywordList)}|groupIDList:${json.encode(groupIDList ?? [])}|isSearchMemberUserID:$isSearchMemberUserID|isSearchMemberNickName:$isSearchMemberNickName|isSearchMemberRemark:$isSearchMemberRemark|isSearchMemberNameCard:$isSearchMemberNameCard";
    return res;
  }
}
