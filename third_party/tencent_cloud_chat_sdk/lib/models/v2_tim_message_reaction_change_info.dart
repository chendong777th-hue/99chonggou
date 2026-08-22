import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_reaction.dart';
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
    messageID = json['message_reaction_change_info_msg_id'] ?? "";
    reactionList = List.empty(growable: true);
    if (json['message_reaction_change_info_reaction_list'] != null) {
      json['message_reaction_change_info_reaction_list'].forEach((v) {
        reactionList.add(V2TimMessageReaction.fromJson(v));
      });
    } else {
      reactionList = [];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['message_reaction_change_info_msg_id'] = messageID;

    data['message_reaction_change_info_reaction_list'] = reactionList.map((v) => v.toJson()).toList();
    return data;
  }

  String toLogString() {
    String res = "messageID:$messageID|reactionList:${json.encode(reactionList.map((e) => e.toLogString()).toList())}";
    return res;
  }
}
