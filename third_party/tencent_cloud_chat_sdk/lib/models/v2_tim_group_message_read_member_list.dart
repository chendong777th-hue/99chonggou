import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimGroupMessageReadMemberList {
  late int nextSeq;
  late bool isFinished;
  late List<V2TimGroupMemberInfo> memberInfoList;

  V2TimGroupMessageReadMemberList({
    required this.nextSeq,
    required this.isFinished,
    required this.memberInfoList,
  });

  V2TimGroupMessageReadMemberList.fromJson(Map json) {
    json = Utils.formatJson(json);
    nextSeq = json['nextSeq'] ?? 0;
    isFinished = json['isFinished'] ?? false;
    memberInfoList = [];
    if (json['memberInfoList'] != null) {
      memberInfoList = List.empty(growable: true);
      json['memberInfoList'].forEach((v) {
        memberInfoList.add(V2TimGroupMemberInfo.fromJson(v));
      });
    } else {
      memberInfoList = List.empty(growable: true);
    }
  }

  Map<dynamic, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['nextSeq'] = nextSeq;
    data['isFinished'] = isFinished;
    data['memberInfoList'] = memberInfoList.isNotEmpty
        ? memberInfoList.map((v) => v.toJson()).toList()
        : [];
    return data;
  }
  String toLogString() {
    String res = "nextSeq:$nextSeq|isFinished:$isFinished|memberInfoList:${json.encode(memberInfoList.map((e) => e.toLogString()).toList())}";
    return res;
  }
}
