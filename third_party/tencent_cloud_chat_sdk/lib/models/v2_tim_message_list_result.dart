import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimConversationResult
///
/// {@category Models}
///
class V2TimMessageListResult {
  bool isFinished = false;
  List<V2TimMessage> messageList = List.empty(growable: true);

  V2TimMessageListResult({
    required this.isFinished,
    required this.messageList,
  });

  V2TimMessageListResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    isFinished = json['isFinished'] ?? false;
    if (json['messageList'] != null) {
      messageList = List.empty(growable: true);
      for (var v in List.from(json['messageList'])) {
        messageList.add(V2TimMessage.fromJson(v));
      }
    } else {
      messageList = [];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['isFinished'] = isFinished;
    if (messageList.isNotEmpty) {
      data['messageList'] = messageList.map((v) => v.toJson()).toList();
    }
    return data;
  }

  String toLogString() {
    String res = "isFinished:$isFinished|messageList:${json.encode(messageList.map((e) => e.toLogString()).toList())}";
    return res;
  }
}
