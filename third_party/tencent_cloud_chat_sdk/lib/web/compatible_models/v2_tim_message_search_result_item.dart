import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMessageSearchResultItem
///
/// {@category Models}
///
class V2TimMessageSearchResultItem {
  String? conversationID;
  int? messageCount;
  List<V2TimMessage>? messageList;

  V2TimMessageSearchResultItem({
    this.conversationID,
    this.messageCount,
    this.messageList,
  });

  V2TimMessageSearchResultItem.fromJson(Map json) {
    json = Utils.formatJson(json);
    conversationID = json['conversationID'];
    messageCount = json['messageCount'];
    if (json['messageList'] != null) {
      messageList = List.empty(growable: true);
      json['messageList'].forEach((v) {
        messageList?.add(V2TimMessage.fromJson(v));
      });
    } else {
      messageList = [];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['conversationID'] = conversationID;
    data['messageCount'] = messageCount;
    if (messageList != null) {
      data['messageList'] = messageList!.map((v) => v.toJson()).toList();
    }
    return data;
  }

  String toLogString() {
    String res = "conversationID:$conversationID|messageCount:$messageCount|messageList:${json.encode(messageList?.map((e) => e.toLogString()).toList())}";
    return res;
  }
}

// {
//   "userID":"",
//   "timestamp":0
// }
