import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupInfo
///
/// {@category Models}
///
class V2TimGroupInfo {
  late String groupID;
  late String groupType;
  String? groupName;
  String? notification;
  String? introduction;
  String? faceUrl;
  bool? isAllMuted;
  bool? isSupportTopic = false;
  String? owner;
  int? createTime;
  int? groupAddOpt;
  int? lastInfoTime;
  int? lastMessageTime;
  int? memberCount;
  int? onlineCount;
  int? role;
  int? recvOpt;
  int? joinTime;
  Map<String, String>? customInfo;
  int? approveOpt;
  bool? isEnablePermissionGroup = false;
  int? memberMaxCount;
  int? defaultPermissions;

  V2TimGroupInfo({
    required this.groupID,
    required this.groupType,
    this.groupName,
    this.notification,
    this.introduction,
    this.faceUrl,
    this.isAllMuted,
    this.owner,
    this.createTime,
    this.groupAddOpt,
    this.lastInfoTime,
    this.lastMessageTime,
    this.memberCount,
    this.onlineCount,
    this.role,
    this.recvOpt,
    this.joinTime,
    this.isSupportTopic,
    this.customInfo,
    this.approveOpt,
    this.isEnablePermissionGroup,
    this.memberMaxCount,
    this.defaultPermissions,
  });

  V2TimGroupInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    approveOpt = json["approveOpt"];
    groupID = json['groupID'] ?? "";
    groupType = json['groupType'];
    groupName = json['groupName'];
    notification = json['notification'];
    introduction = json['introduction'];
    faceUrl = json['faceUrl'];
    isAllMuted = json['isAllMuted'];
    owner = json['owner'];

    createTime = json['createTime'];
    groupAddOpt = json['groupAddOpt'];
    lastInfoTime = json['lastInfoTime'];
    lastMessageTime = json['lastMessageTime'];
    memberCount = json['memberCount'];
    onlineCount = json['onlineCount'];
    isSupportTopic = json["isSupportTopic"];
    isEnablePermissionGroup = json["isEnablePermissionGroup"] ?? false;
    role = json['role'];
    recvOpt = json['recvOpt'];
    joinTime = json['joinTime'];
    customInfo = json['customInfo'] == null
        ? <String, String>{}
        : Map<String, String>.from(json['customInfo']);
    memberMaxCount = json['memberMaxCount'] ?? 0;
    defaultPermissions = json['defaultPermissions'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['groupID'] = groupID;
    data['groupType'] = groupType;
    data['groupName'] = groupName;
    data['notification'] = notification;
    data['introduction'] = introduction;
    data['faceUrl'] = faceUrl;
    data['isAllMuted'] = isAllMuted;
    data['owner'] = owner;
    data['createTime'] = createTime;
    data['groupAddOpt'] = groupAddOpt;
    data['lastInfoTime'] = lastInfoTime;
    data['lastMessageTime'] = lastMessageTime;
    data['memberCount'] = memberCount;
    data['onlineCount'] = onlineCount;
    data['role'] = role;
    data['recvOpt'] = recvOpt;
    data['joinTime'] = joinTime;
    data['customInfo'] = customInfo;
    data['isSupportTopic'] = isSupportTopic;
    data["approveOpt"] = approveOpt;
    data["isEnablePermissionGroup"] = isEnablePermissionGroup ?? false;
    data["memberMaxCount"] = memberMaxCount ?? 0;
    data["defaultPermissions"] = defaultPermissions ?? 0;
    return data;
  }
  String toLogString() {
    String res =
        "groupID:$groupID|groupType:$groupType|groupName:$groupName|isAllMuted:$isAllMuted|owner:$owner|groupAddOpt:$groupAddOpt|isSupportTopic:$isSupportTopic|approveOpt:$approveOpt|defaultPermissions:$defaultPermissions|recvOpt:$recvOpt";
    return res;
  }
}
// {
//  "groupID":"" ,
//  "groupType":"",
//  "groupName":"",
//  "notification":"",
//  "introduction":"",
//  "faceUrl":"",
//  "allMuted":false,
//  "owner":"",
//  "createTime":0,
//  "groupAddOpt":0,
//  "lastInfoTime":0,
//  "lastMessageTime":0,
//  "memberCount":0,
//  "onlineCount":0,
//  "role":0,
//  "recvOpt":0,
//  "joinTime":0,
//  "customInfo":{}
// }
