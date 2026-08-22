import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimFriendGroup
///
/// {@category Models}
///
class V2TimFriendGroup {
  late String? name;
  late int? friendCount;
  late List<String>? friendIDList;

  V2TimFriendGroup({
    this.name,
    this.friendCount,
    this.friendIDList,
  });

  V2TimFriendGroup.fromJson(Map json) {
    json = Utils.formatJson(json);
    name = json['name'];
    friendCount = json['friendCount'];
    friendIDList = json['friendIDList'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['friendCount'] = friendCount;
    data['friendIDList'] = friendIDList;
    return data;
  }
  String toLogString() {
    String res = "name:$name|friendCount:$friendCount|friendIDList:${json.encode(friendIDList ?? [])}";
    return res;
  }
}
// {
//   "name":"",
//   "friendCount":0,
//   "friendIDList":[""]
// }
