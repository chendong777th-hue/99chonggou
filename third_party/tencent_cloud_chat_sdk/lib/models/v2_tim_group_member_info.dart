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
    userID = json['group_member_info_identifier'] ?? "";
    nickName = json['group_member_info_nick_name'];
    nameCard = json['group_member_info_name_card'];
    friendRemark = json['group_member_info_friend_remark'];
    faceUrl = json['group_member_info_face_url'];
    onlineDevices = List<String>.from(json["group_member_info_online_devices"] ?? []);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_member_info_identifier'] = userID;
    data['group_member_info_nick_name'] = nickName;
    data['group_member_info_name_card'] = nameCard;
    data['group_member_info_friend_remark'] = friendRemark;
    data['group_member_info_face_url'] = faceUrl;
    data["group_member_info_online_devices"] = onlineDevices ?? [];

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
