import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_imsdk_bindings_generated.dart';

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
    conversationID = json['msg_search_result_item_conv_id'];
    messageCount = json['msg_search_result_item_total_message_count'];
    if (json['msg_search_result_item_message_array'] != null) {
      messageList = List.empty(growable: true);
      json['msg_search_result_item_message_array'].forEach((v) {
        messageList?.add(V2TimMessage.fromJson(v));
      });
    } else {
      messageList = [];
    }

    int convType = json['msg_search_result_item_conv_type'];
    String prefix = "group_";
    if (convType != null && convType == TIMConvType.kTIMConv_C2C.index) {
      prefix = "c2c_";
    }
    if (conversationID != null) {
      conversationID = prefix + conversationID!;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['msg_search_result_item_conv_id'] = conversationID;
    data['msg_search_result_item_total_message_count'] = messageCount;
    if (messageList != null) {
      data['msg_search_result_item_message_array'] = messageList!.map((v) => v.toJson()).toList();
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
