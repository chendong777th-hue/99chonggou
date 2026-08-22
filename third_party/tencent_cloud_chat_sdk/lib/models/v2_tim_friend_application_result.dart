import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimFriendApplicationResult
///
/// {@category Models}
///
class V2TimFriendApplicationResult {
  late int? unreadCount;
  late List<V2TimFriendApplication?>? friendApplicationList =
      List.empty(growable: true);

  V2TimFriendApplicationResult({
    this.unreadCount,
    this.friendApplicationList,
  });

  V2TimFriendApplicationResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    unreadCount = json['pendency_page_unread_num'];
    friendApplicationList = [];
    if (json['pendency_page_pendency_info_array'] != null) {
      json['pendency_page_pendency_info_array'].forEach((v) {
        friendApplicationList!.add(V2TimFriendApplication.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['unreadCount'] = unreadCount;
    data['friendApplicationList'] =
        friendApplicationList?.map((v) => v?.toJson()).toList();
    return data;
  }
  String toLogString() {
    String res = "unreadCount:$unreadCount|friendApplicationList:${json.encode(friendApplicationList?.map((e) => e?.toLogString()).toList())}";
    return res;
  }
}
// {
//   "unreadCount":0,
//   "friendApplicationList":{},
// }
