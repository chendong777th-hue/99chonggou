import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupMemberFullInfo
///
/// {@category Models}
///
class V2TimGroupMemberFullInfo {
  late String userID;
  late int? role;
  late int? muteUntil;
  late int? joinTime;
  Map<String, String>? customInfo;
  late String? nickName;
  late String? nameCard;
  late String? friendRemark;
  late String? faceUrl;
  bool? isOnline;
  List<String>? onlineDevices = [];

  V2TimGroupMemberFullInfo({
    required this.userID,
    this.role,
    this.muteUntil,
    this.joinTime,
    this.customInfo,
    this.nickName,
    this.nameCard,
    this.friendRemark,
    this.faceUrl,
    this.isOnline,
    this.onlineDevices,
  });

  V2TimGroupMemberFullInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['group_member_info_identifier'] ?? "";
    role = json['group_member_info_member_role'];
    muteUntil = json['group_member_info_shutup_time'];

    joinTime = json['group_member_info_join_time'];
    List<dynamic>? jsonCustomInfo = json['group_member_info_custom_info'];
    if (jsonCustomInfo != null) {
      // C 接口底层用的是 group_info_custom_string_info_key 和 group_info_custom_string_info_value
      customInfo = Tools.jsonList2Map<String>(jsonCustomInfo.whereType<Map<String, dynamic>>().toList(), 'group_info_custom_string_info_key', 'group_info_custom_string_info_value');
    }
    nickName = json['group_member_info_nick_name'];
    nameCard = json['group_member_info_name_card'];
    friendRemark = json['group_member_info_friend_remark'];
    faceUrl = json['group_member_info_face_url'];
    isOnline = json["group_member_info_is_online"] ?? false;

    onlineDevices = List<String>.from(json["group_member_info_online_devices"] ?? []);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_member_info_identifier'] = userID;
    data['group_member_info_member_role'] = role;
    data['group_member_info_shutup_time'] = muteUntil;
    data['group_member_info_join_time'] = joinTime;
    if (customInfo != null) {
      data['group_member_info_custom_info'] = Tools.map2JsonList(customInfo!, 'group_member_info_custom_string_info_key', 'group_member_info_custom_string_info_value');;
    }
    data['group_member_info_nick_name'] = nickName;
    data['group_member_info_name_card'] = nameCard;
    data['group_member_info_friend_remark'] = friendRemark;
    data['group_member_info_face_url'] = faceUrl;
    data["group_member_info_is_online"] = isOnline;
    data["group_member_info_online_devices"] = onlineDevices ?? [];
    return data;
  }

  String toLogString() {
    String res = "userID:$userID|nickName:$nickName|role:$role|muteUntil:$muteUntil|joinTime:$joinTime|isOnline:$isOnline|onlineDevices:${json.encode(onlineDevices)}";
    return res;
  }
}

// {
//   "userID":"",
//   "role":0,
//   "muteUntil":0,
//   "joinTime":0,
//   "customInfo":{},
//   "nickName":"",
//   "nameCard":"",
//   "friendRemark":"",
//   "faceUrl":""
// }
