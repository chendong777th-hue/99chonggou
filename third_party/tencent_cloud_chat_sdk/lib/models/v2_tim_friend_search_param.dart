import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimFriendSearchParam
///
/// {@category Models}
///
class V2TimFriendSearchParam {
  late List<String> keywordList;
  bool isSearchUserID = true;
  bool isSearchNickName = true;
  bool isSearchRemark = true;
  late List<int> _searchFiledList;

  // 好友搜索的类型
  // 用户 ID
  static const int _kTIMFriendshipSearchFieldKeyIdentifier = 0x01;
  // 昵称
  static const int _kTIMFriendshipSearchFieldKeyNickName = 0x01 << 1;
  // 备注
  static const int _kTIMFriendshipSearchFieldKeyRemark = 0x01 << 2;

  V2TimFriendSearchParam({
    required this.keywordList,
    this.isSearchUserID = true,
    this.isSearchNickName = true,
    this.isSearchRemark = true,
  }) {
    _searchFiledList = [];
    if (isSearchUserID) {
      _searchFiledList.add(_kTIMFriendshipSearchFieldKeyIdentifier);
    }
    if (isSearchNickName) {
      _searchFiledList.add(_kTIMFriendshipSearchFieldKeyNickName);
    }
    if (isSearchRemark) {
      _searchFiledList.add(_kTIMFriendshipSearchFieldKeyRemark);
    }
  }

  V2TimFriendSearchParam.fromJson(Map json) {
    json = Utils.formatJson(json);
    keywordList = json['keywordList']?.cast<String>() ?? [];
    isSearchUserID = json['isSearchUserID'];
    isSearchNickName = json['isSearchNickName'];
    isSearchRemark = json['isSearchRemark'];
    _searchFiledList = [];
    if (isSearchUserID) {
      _searchFiledList.add(_kTIMFriendshipSearchFieldKeyIdentifier);
    }
    if (isSearchNickName) {
      _searchFiledList.add(_kTIMFriendshipSearchFieldKeyNickName);
    }
    if (isSearchRemark) {
      _searchFiledList.add(_kTIMFriendshipSearchFieldKeyRemark);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['friendship_search_param_keyword_list'] = keywordList;
    data['friendship_search_param_search_field_list'] = _searchFiledList;
    return data;
  }

  String toLogString() {
    String res = "keywordList:${json.encode(keywordList)}|isSearchUserID:$isSearchUserID|isSearchNickName:$isSearchNickName|isSearchRemark:$isSearchRemark";
    return res;
  }
}
