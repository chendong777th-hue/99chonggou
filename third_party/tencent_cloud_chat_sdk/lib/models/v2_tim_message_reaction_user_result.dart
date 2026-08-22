import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimMessageReactionUserResult {
  late List<V2TimUserInfo> userInfoList;
  late int nextSeq;
  late bool isFinished;
  V2TimMessageReactionUserResult({
    required this.userInfoList,
    required this.nextSeq,
    required this.isFinished,
  });
  V2TimMessageReactionUserResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    nextSeq = json['message_reaction_user_result_next_seq'] ?? 0;
    isFinished = json['message_reaction_user_result_is_finished'] ?? true;
    userInfoList = List.empty(growable: true);
    if (json['message_reaction_user_result_user_info_array'] != null) {
      json['message_reaction_user_result_user_info_array'].forEach((v) {
        userInfoList.add(V2TimUserInfo.fromJson(v));
      });
    } else {
      userInfoList = [];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['nextSeq'] = nextSeq;
    data['isFinished'] = isFinished;
    data['userInfoList'] = userInfoList.map((v) => v.toJson()).toList();
    return data;
  }
  String toLogString() {
    String res = "nextSeq:$nextSeq|isFinished:$isFinished|userInfoList:${json.encode(userInfoList.map((e) => e.toLogString()).toList())}";
    return res;
  }
}
