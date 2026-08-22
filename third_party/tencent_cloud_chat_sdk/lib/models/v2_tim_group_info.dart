import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';
import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';

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
  int? unreadMsgCount;
  bool? isVisible = false;
  bool? isSearchable = false;

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
    this.unreadMsgCount,
    this.isVisible,
    this.isSearchable,
  });

  V2TimGroupInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    approveOpt = EnumUtils.cGroupAddOption2DartEnum(json["group_detail_info_approve_option"]).index;
    groupID = json['group_detail_info_group_id'] ?? '';
    groupType = GroupType.convertGroupTypeEnum(json['group_detail_info_group_type'] ?? 0);
    groupName = json['group_detail_info_group_name'];
    notification = json['group_detail_info_notification'];
    introduction = json['group_detail_info_introduction'];
    faceUrl = json['group_detail_info_face_url'];
    isAllMuted = json['group_detail_info_is_shutup_all'];
    owner = json['group_detail_info_owner_identifier'];

    createTime = json['group_detail_info_create_time'];
    groupAddOpt = EnumUtils.cGroupAddOption2DartEnum(json['group_detail_info_add_option']).index;
    lastInfoTime = json['group_detail_info_last_info_time'];
    lastMessageTime = json['group_detail_info_last_msg_time'];
    memberCount = json['group_detail_info_member_num'];
    onlineCount = json['group_detail_info_online_member_num'];
    isSupportTopic = json["group_detail_info_is_support_topic"];
    isEnablePermissionGroup = json["group_detail_info_enable_permission_group"] ?? false;

    Map<String, dynamic> jsonGroupSelfInfo = json["group_base_info_self_info"];
    role = jsonGroupSelfInfo['group_self_info_role'];
    joinTime = jsonGroupSelfInfo['group_self_info_join_time'];
    unreadMsgCount = jsonGroupSelfInfo['group_self_info_unread_num'];
    recvOpt = jsonGroupSelfInfo['group_self_info_msg_flag'];

    var jsonCustomInfo = List<Map<String, dynamic>>.from(json["group_detail_info_custom_info"] ?? []);
    if (jsonCustomInfo.isNotEmpty) {
      customInfo = Tools.jsonList2Map<String>(jsonCustomInfo, 'group_info_custom_string_info_key', 'group_info_custom_string_info_value');
    }

    memberMaxCount = json['group_detail_info_max_member_num'] ?? 0;
    defaultPermissions = json['group_detail_info_default_permissions'] ?? 0;
    isVisible = json['group_modify_info_param_visible'];
    isSearchable = json['group_modify_info_param_searchable'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_detail_info_group_id'] = groupID;
    data['group_detail_info_group_type'] = groupType;
    data['group_detail_info_group_name'] = groupName;
    data['group_detail_info_notification'] = notification;
    data['group_detail_info_introduction'] = introduction;
    data['group_detail_info_face_url'] = faceUrl;
    data['group_detail_info_is_shutup_all'] = isAllMuted;
    data['group_detail_info_owner_identifier'] = owner;
    data['group_detail_info_create_time'] = createTime;
    if (groupAddOpt != null) {
      data['group_detail_info_add_option'] = EnumUtils.dartGroupAddOptType2CType(groupAddOpt!);
    }
    data['group_detail_info_last_info_time'] = lastInfoTime;
    data['group_detail_info_last_msg_time'] = lastMessageTime;
    data['group_detail_info_member_num'] = memberCount;
    data['group_detail_info_online_member_num'] = onlineCount;

    Map<String, dynamic> jsonGroupSelfInfo = {};
    jsonGroupSelfInfo['group_self_info_role'] = role;
    jsonGroupSelfInfo['group_self_info_join_time'] = joinTime;
    jsonGroupSelfInfo['group_self_info_unread_num'] = unreadMsgCount;
    jsonGroupSelfInfo['group_self_info_msg_flag'] = recvOpt;
    data['group_base_info_self_info'] = jsonGroupSelfInfo;

    if (customInfo != null && customInfo!.isNotEmpty) {
      List<Map<String, String>> jsonCustomInfo = customInfo!.entries.map((entry) => {"group_info_custom_string_info_key": entry.key, "group_info_custom_string_info_value": entry.value}).toList();
      data['group_detail_info_custom_info'] = jsonCustomInfo;
    }
    data['group_detail_info_is_support_topic'] = isSupportTopic;
    if (approveOpt != null) {
      data["group_detail_info_approve_option"] = EnumUtils.dartGroupAddOptType2CType(approveOpt!);
    }
    data["group_detail_info_enable_permission_group"] = isEnablePermissionGroup ?? false;
    data["group_detail_info_max_member_num"] = memberMaxCount ?? 0;
    data["group_detail_info_default_permissions"] = defaultPermissions ?? 0;
    data['group_modify_info_param_visible'] = isVisible;
    data['group_modify_info_param_searchable'] = isSearchable;
    return data;
  }
  String toLogString() {
    String res =
        "groupID:$groupID|groupType:$groupType|groupName:$groupName|isAllMuted:$isAllMuted|owner:$owner|groupAddOpt:$groupAddOpt|isSupportTopic:$isSupportTopic|approveOpt:$approveOpt|isEnablePermissionGroup:$isEnablePermissionGroup|defaultPermissions:$defaultPermissions|recvOpt:$recvOpt|unreadMsgCount:$unreadMsgCount|lastMessageTime:$lastMessageTime|memberCount:$memberCount";
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
