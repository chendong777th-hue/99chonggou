import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_reaction.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TIMMessageReactionChangeInfo {
  late String messageID;
  late List<V2TimMessageReaction> reactionList;
  V2TIMMessageReactionChangeInfo({
    required this.messageID,
    required this.reactionList,
  });
  V2TIMMessageReactionChangeInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    messageID = json['messageID'] ?? "";
    if (json['reactionList'] != null) {
      reactionList = List.empty(growable: true);
      json['reactionList'].forEach((v) {
        reactionList.add(V2TimMessageReaction.fromJson(v));
      });
    } else {
      reactionList = [];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['messageID'] = messageID;

    data['reactionList'] = reactionList.map((v) => v.toJson()).toList();
    return data;
  }
  String toLogString() {
    String res = "messageID:$messageID|reactionList:${json.encode(reactionList.map((e) => e.toLogString()).toList())}";
    return res;
  }
}
