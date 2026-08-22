import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimConversationResult
///
/// {@category Models}
///
class V2TimConversationResult {
  late String? nextSeq;
  late bool? isFinished;
  List<V2TimConversation>? conversationList = List.empty(growable: true);

  V2TimConversationResult({
    this.nextSeq,
    this.isFinished,
    this.conversationList,
  });

  V2TimConversationResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    nextSeq = json['nextSeq'] ?? "";
    isFinished = json['isFinished'] ?? true;
    if (json['conversationList'] != null) {
      conversationList = List.empty(growable: true);
      json['conversationList'].forEach((v) {
        conversationList!.add(V2TimConversation.fromJson(v));
      });
    } else {
      conversationList = [];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['nextSeq'] = nextSeq;
    data['isFinished'] = isFinished;
    if (conversationList != null) {
      data['conversationList'] = conversationList?.map((v) => v?.toJson()).toList();
    }
    return data;
  }

  String toLogString() {
    String res = "nextSeq:$nextSeq|isFinished:$isFinished|conversationList:${json.encode(conversationList?.map((e) => e?.toLogString()).toList())}";
    return res;
  }
}

// {
//   "nextSeq":0,
//   "isFinished":true,
//   "conversationList":[{}]
// }
