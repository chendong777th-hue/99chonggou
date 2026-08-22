import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimGroupMemberInfo {
  String? userID;
  String? nickName;
  String? nameCard;
  String? friendRemark;
  String? faceUrl;
  List<String>? onlineDevices = [];

  V2TimGroupMemberInfo({
    this.userID,
    this.nickName,
    this.nameCard,
    this.friendRemark,
    this.faceUrl,
    this.onlineDevices,
  });

  V2TimGroupMemberInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['userID'] ?? "";
    nickName = json['nickName'];
    nameCard = json['nameCard'];
    friendRemark = json['friendRemark'];
    faceUrl = json['faceUrl'];
    onlineDevices = List<String>.from(json["onlineDevices"] ?? []);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userID'] = userID;
    data['nickName'] = nickName;
    data['nameCard'] = nameCard;
    data['friendRemark'] = friendRemark;
    data['faceUrl'] = faceUrl;
    data["onlineDevices"] = onlineDevices ?? [];

    return data;
  }
  String toLogString() {
    String res = "userID:$userID|onlineDevices:${json.encode(onlineDevices)}";
    return res;
  }
}

// {
//   "userID":"",
//   "nickName":"",
//   "nameCard":"",
//   "friendRemark":"",
//   "faceUrl":""
// }
