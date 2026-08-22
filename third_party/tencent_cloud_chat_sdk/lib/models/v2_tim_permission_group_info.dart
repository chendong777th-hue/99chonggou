import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimPermissionGroupInfo {
  /////////////////////////////////////////////////////////////////////////////////
  //
  // 社群权限列表
  //
  /////////////////////////////////////////////////////////////////////////////////

  /// 修改群资料权限。该位设置为0，表示没有该权限；设置为1，表示有该权限
  static const int V2TIM_COMMUNITY_PERMISSION_MANAGE_GROUP_INFO = 0x01;

  /// 群成员管理权限，包含踢人，进群审核、修改成员资料等。该位设置为0，表示没有该权限；设置为1，表示有该权限
  static const int V2TIM_COMMUNITY_PERMISSION_MANAGE_GROUP_MEMBER = 0x01 << 1;

  /// 管理权限组资料权限，包含创建、修改、删除权限组；在权限组中添加、修改、删除话题权限。该位设置为0，表示没有该权限；设置为1，表示有该权限。
  static const int V2TIM_COMMUNITY_PERMISSION_MANAGE_PERMISSION_GROUP_INFO = 0x01 << 2;

  /// 权限组成员管理权限，包含邀请成员进权限组和把成员从权限组踢出等。该位设置为0，表示没有该权限；设置为1，表示有该权限
  static const int V2TIM_COMMUNITY_PERMISSION_MANAGE_PERMISSION_GROUP_MEMBER = 0x01 << 3;

  /// 话题管理权限，包含创建、修改、删除话题等。该位设置为0，表示没有该权限；设置为1，表示有该权限。
  static const int V2TIM_COMMUNITY_PERMISSION_MANAGE_TOPIC_IN_COMMUNITY = 0x01 << 4;

  /// 对某群成员在社群下所有话题的禁言权限。该位设置为0，表示没有该权限；设置为1，表示有该权限。
  static const int V2TIM_COMMUNITY_PERMISSION_MUTE_MEMBER = 0x01 << 5;

  /// 群成员在社群下所有话题的发消息权限。该位设置为0，表示没有该权限；设置为1，表示有该权限。
  static const int V2TIM_COMMUNITY_PERMISSION_SEND_MESSAGE = 0x01 << 6;

  /// 在社群下所有话题发 at all 消息权限。该位设置为0，表示没有该权限；设置为1，表示有该权限。
  static const int V2TIM_COMMUNITY_PERMISSION_AT_ALL = 0x01 << 7;

  /// 在社群下所有话题拉取入群前的历史消息权限。该位设置为0，表示没有该权限；设置为1，表示有该权限。
  static const int V2TIM_COMMUNITY_PERMISSION_GET_HISTORY_MESSAGE = 0x01 << 8;

  /// 在社群下所有话题撤回他人消息权限。该位设置为0，表示没有该权限；设置为1，表示有该权限。
  static const int V2TIM_COMMUNITY_PERMISSION_REVOKE_OTHER_MEMBER_MESSAGE = 0x01 << 9;

  /// 封禁社群成员权限。该位设置为0，表示没有该权限；设置为1，表示有该权限。
  static const int V2TIM_COMMUNITY_PERMISSION_BAN_MEMBER = 0x01 << 10;

  /////////////////////////////////////////////////////////////////////////////////
  //
  // 话题权限列表
  //
  /////////////////////////////////////////////////////////////////////////////////

  /// 管理当前话题的权限，包括修改当前话题的资料、删除当前话题。该位设置为0，表示没有该权限；设置为1，表示有该权限
  static const int V2TIM_TOPIC_PERMISSION_MANAGE_TOPIC = 0x01;

  /// 在当前话题中管理话题权限，包括添加、修改、移除话题权限。该位设置为0，表示没有该权限；设置为1，表示有该权限
  static const int V2TIM_TOPIC_PERMISSION_MANAGE_TOPIC_PERMISSION = 0x01 << 1;

  /// 在当前话题中禁言成员权限。该位设置为0，表示没有该权限；设置为1，表示有该权限
  static const int V2TIM_TOPIC_PERMISSION_MUTE_MEMBER = 0x01 << 2;

  /// 在当前话题中发消息权限。该位设置为0，表示没有该权限；设置为1，表示有该权限
  static const int V2TIM_TOPIC_PERMISSION_SEND_MESSAGE = 0x01 << 3;

  /// 在当前话题中拉取入群前的历史消息权限。该位设置为0，表示没有该权限；设置为1，表示有该权限
  static const int V2TIM_TOPIC_PERMISSION_GET_HISTORY_MESSAGE = 0x01 << 4;

  /// 在当前话题中撤回他人消息权限。该位设置为0，表示没有该权限；设置为1，表示有该权限
  static const int V2TIM_TOPIC_PERMISSION_REVOKE_OTHER_MEMBER_MESSAGE = 0x01 << 5;

  /// 在当前话题中发消息时有 at all 权限。该位设置为0，表示没有该权限；设置为1，表示有该权限
  static const int V2TIM_TOPIC_PERMISSION_AT_ALL = 0x01 << 6;

  String groupID;
  String? permissionGroupID;
  String permissionGroupName;
  String? customData;
  int? groupPermission;
  int? memberCount;

  V2TimPermissionGroupInfo({
    this.customData,
    required this.groupID,
    this.groupPermission,
    this.memberCount,
    this.permissionGroupID,
    required this.permissionGroupName,
  });

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from({
      'community_group_id': groupID,
      'permission_group_id': permissionGroupID,
      'permission_group_name': permissionGroupName,
      'permission_custom_data': customData,
      'group_permission': groupPermission,
      'permission_group_member_count': memberCount,
    });
  }

  static V2TimPermissionGroupInfo fromJson(Map json) {
    json = Utils.formatJson(json);
    return V2TimPermissionGroupInfo(
      groupID: json['community_group_id'] ?? "",
      permissionGroupID: json['permission_group_id'] ?? "",
      permissionGroupName: json['permission_group_name'] ?? "",
      customData: json['permission_custom_data'] ?? "",
      groupPermission: json['group_permission'] ?? 0,
      memberCount: json['permission_group_member_count'] ?? 0,
    );
  }

  String toLogString() {
    String res = "groupID:$groupID|permissionGroupID:$permissionGroupID|groupPermission:$groupPermission|memberCount:$memberCount|permissionGroupName:$permissionGroupName";
    return res;
  }
}
