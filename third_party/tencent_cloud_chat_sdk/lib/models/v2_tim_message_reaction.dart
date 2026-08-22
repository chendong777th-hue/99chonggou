import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_info.dart';
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
    reactionID = json['message_reaction_id'] ?? "";
    totalUserCount = json['message_reaction_total_user_count'] ?? 0;
    partialUserList = List.empty(growable: true);
    if (json['message_reaction_partial_user_info_array'] != null) {
      json['message_reaction_partial_user_info_array'].forEach((v) {
        partialUserList.add(V2TimUserInfo.fromJson(v));
      });
    } else {
      partialUserList = [];
    }
    reactedByMyself = json['message_reaction_reacted_by_myself'] ?? false;
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
