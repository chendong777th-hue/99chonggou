import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimMessageReaction {
  late String reactionID;

  late int totalUserCount;

  late List<V2TimUserInfo> partialUserList;

  late bool reactedByMyself;

  V2TimMessageReaction({
    required this.reactionID,
    required this.totalUserCount,
    required this.partialUserList,
    required this.reactedByMyself,
  });
  V2TimMessageReaction.fromJson(Map json) {
    json = Utils.formatJson(json);
    reactionID = json['reactionID'] ?? "";
    totalUserCount = json['totalUserCount'] ?? 0;
    if (json['partialUserList'] != null) {
      partialUserList = List.empty(growable: true);
      json['partialUserList'].forEach((v) {
        partialUserList.add(V2TimUserInfo.fromJson(v));
      });
    } else {
      partialUserList = [];
    }
    reactedByMyself = json['reactedByMyself'] ?? false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['reactionID'] = reactionID;
    data['totalUserCount'] = totalUserCount;
    data['partialUserList'] = partialUserList.map((v) => v.toJson()).toList();
    data['reactedByMyself'] = reactedByMyself;
    return data;
  }

  String toLogString() {
    String res = "reactionID:$reactionID|totalUserCount:$totalUserCount|partialUserList:${json.encode(partialUserList.map((e) => e.toLogString()).toList())}|reactedByMyself:$reactedByMyself";
    return res;
  }
}
