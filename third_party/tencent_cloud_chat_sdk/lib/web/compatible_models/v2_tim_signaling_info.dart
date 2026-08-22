import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_official_account_info_result.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimSignalingInfo
///
/// {@category Models}
///
class V2TimSignalingInfo {
  late String inviteID; // 邀请ID
  late String inviter; // 邀请人ID
  late List<dynamic> inviteeList;
  String? groupID;
  String? data;
  int? timeout;
  late int actionType;
  late int? businessID; // ios不回返回这条
  late bool? isOnlineUserOnly; // ios不回返回这条
  late OfflinePushInfo? offlinePushInfo; // ios不回返回这条
  V2TimSignalingInfo({
    required this.inviteID,
    required this.inviter,
    required this.inviteeList,
    required this.actionType,
    required this.businessID,
    required this.isOnlineUserOnly,
    required this.offlinePushInfo,
    this.groupID,
    this.data,
    this.timeout,
  });

  V2TimSignalingInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    inviteID = json['inviteID'];
    groupID = json['groupID'];
    inviter = json['inviter'];
    inviteeList = json['inviteeList'];
    data = json['data'];
    timeout = json['timeout'];
    actionType = json['actionType'];
    // 下方三个参数ios不会返回
    if (json['businessID'] != null) businessID = json['businessID'];
    if (json['isOnlineUserOnly'] != null) {
      isOnlineUserOnly = json['isOnlineUserOnly'];
    }
    if (json['offlinePushInfo'] != null) {
      offlinePushInfo = OfflinePushInfo.fromJson(json['offlinePushInfo']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['inviteID'] = inviteID;
    data['groupID'] = groupID;
    data['inviter'] = inviter;
    data['inviteeList'] = inviteeList;
    data['data'] = this.data;
    data['timeout'] = timeout;
    data['actionType'] = actionType;
    // 下方三个参数ios不会返回
    if (data['businessID'] != null) data['businessID'] = businessID;
    if (data['businessID'] != null) {
      data['isOnlineUserOnly'] = isOnlineUserOnly;
    }
    if (data['offlinePushInfo'] != null) {
      data['offlinePushInfo'] = offlinePushInfo?.toJson();
    }
    return data;
  }

  String toLogString() {
    String res = "inviteID:$inviteID|groupID:$groupID|inviter:$inviter|data:$data|actionType:$actionType";
    return res;
  }
}
