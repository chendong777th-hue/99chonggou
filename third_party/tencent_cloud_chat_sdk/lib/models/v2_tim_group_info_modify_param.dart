import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';

import 'v2_tim_group_info.dart';

/// V2TimGroupInfoModifyParam
///
/// {@category Models}
///
class V2TimGroupInfoModifyParam {
  // 未定义
  final int _kTIMGroupModifyInfoFlag_None = 0x00;
  // 修改群组名称
  final int _kTIMGroupModifyInfoFlag_Name = 0x01;
  // 修改群公告
  final int _kTIMGroupModifyInfoFlag_Notification = 0x01 << 1;
  // 修改群简介
  final int _kTIMGroupModifyInfoFlag_Introduction = 0x01 << 2;
  // 修改群头像URL
  final int _kTIMGroupModifyInfoFlag_FaceUrl = 0x01 << 3;
  // 申请加群管理员审批选项
  final int _kTIMGroupModifyInfoFlag_AddOption = 0x01 << 4;
  // 修改群最大成员数
  final int _kTIMGroupModifyInfoFlag_MaxMemberNum = 0x01 << 5;
  // 修改群是否可见
  final int _kTIMGroupModifyInfoFlag_Visible = 0x01 << 6;
  // 修改群是否允许被搜索
  final int _kTIMGroupModifyInfoFlag_Searchable = 0x01 << 7;
  // 修改群是否全体禁言
  final int _kTIMGroupModifyInfoFlag_ShutupAll = 0x01 << 8;
  // 修改群自定义信息
  final int _kTIMGroupModifyInfoFlag_Custom = 0x01 << 9;
  // 话题自定义字段
  final int _kTIMGroupTopicModifyInfoFlag_CustomString = 0x01 << 11;
  // 邀请进群管理员审批选项
  final int _kTIMGroupModifyInfoFlag_ApproveOption = 0x01 << 12;
  // 开启权限组功能，仅支持社群，7.8 版本开始支持
  final int _kTIMGroupModifyInfoFlag_EnablePermissionGroup = 0x1 << 13;
  // 群默认权限，仅支持社群，7.8 版本开始支持
  final int _kTIMGroupModifyInfoFlag_DefaultPermissions = 0x1 << 14;
  // 修改群主
  final int _kTIMGroupModifyInfoFlag_Owner = 0x01 << 31;

  V2TimGroupInfo groupInfo;
  late int modifyFlag;

  V2TimGroupInfoModifyParam({required this.groupInfo}) {
      modifyFlag = 0;
      modifyFlag |= groupInfo.groupName != null ? _kTIMGroupModifyInfoFlag_Name : 0;
      modifyFlag |= groupInfo.notification != null ? _kTIMGroupModifyInfoFlag_Notification : 0;
      modifyFlag |= groupInfo.introduction != null ? _kTIMGroupModifyInfoFlag_Introduction : 0;
      modifyFlag |= groupInfo.faceUrl != null ? _kTIMGroupModifyInfoFlag_FaceUrl : 0;
      modifyFlag |= groupInfo.groupAddOpt != null ? _kTIMGroupModifyInfoFlag_AddOption : 0;
      modifyFlag |= groupInfo.approveOpt != null ? _kTIMGroupModifyInfoFlag_ApproveOption : 0;
      modifyFlag |= groupInfo.memberMaxCount != null ? _kTIMGroupModifyInfoFlag_MaxMemberNum : 0;
      modifyFlag |= groupInfo.isVisible != null ? _kTIMGroupModifyInfoFlag_Visible : 0;
      modifyFlag |= groupInfo.isSearchable != null ? _kTIMGroupModifyInfoFlag_Searchable : 0;
      modifyFlag |= groupInfo.isAllMuted != null ? _kTIMGroupModifyInfoFlag_ShutupAll : 0;
      modifyFlag |= groupInfo.owner != null ? _kTIMGroupModifyInfoFlag_Owner : 0;
      modifyFlag |= groupInfo.customInfo != null ? _kTIMGroupModifyInfoFlag_Custom : 0;
      modifyFlag |= groupInfo.isEnablePermissionGroup != null ? _kTIMGroupModifyInfoFlag_EnablePermissionGroup : 0;
      modifyFlag |= groupInfo.defaultPermissions != null ? _kTIMGroupModifyInfoFlag_DefaultPermissions : 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_modify_info_param_group_id'] = groupInfo.groupID;
    data['group_modify_info_param_modify_flag'] = modifyFlag;
    data['group_modify_info_param_group_name'] = groupInfo.groupName;
    data['group_modify_info_param_notification'] = groupInfo.notification;
    data['group_modify_info_param_introduction'] = groupInfo.introduction;
    data['group_modify_info_param_face_url'] = groupInfo.faceUrl;
    data['group_modify_info_param_add_option'] = groupInfo.groupAddOpt;
    data['group_modify_info_param_approve_option'] = groupInfo.approveOpt;
    data['group_modify_info_param_max_member_num'] = groupInfo.memberMaxCount;
    data['group_modify_info_param_visible'] = groupInfo.isVisible;
    data['group_modify_info_param_searchable'] = groupInfo.isSearchable;
    data['group_modify_info_param_is_shutup_all'] = groupInfo.isAllMuted;
    data['group_modify_info_param_owner'] = groupInfo.owner;
    if (groupInfo.customInfo != null && groupInfo.customInfo!.isNotEmpty) {
      var jsonCustomInfo = Tools.map2JsonList(groupInfo.customInfo!, "group_info_custom_string_info_key", "group_info_custom_string_info_value");
      data['group_modify_info_param_custom_info'] = jsonCustomInfo;
    }
    data['group_modify_info_param_enable_permission_group'] = groupInfo.isEnablePermissionGroup;
    data['group_modify_info_param_default_permissions'] = groupInfo.defaultPermissions;

    return data;
  }
  String toLogString() {
    String res =
        "groupInfo:${groupInfo.toLogString()}|modifyFlag:$modifyFlag";
    return res;
  }
}
