import 'v2_tim_topic_info.dart';

/// V2TimTopicInfoSetParam
///
/// {@category Models}
///
class V2TimTopicInfoSetParam {
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

  V2TimTopicInfo topicInfo;
  late int _modifyFlag;

  V2TimTopicInfoSetParam({required this.topicInfo}) {
      _modifyFlag = 0;
      _modifyFlag |= topicInfo.topicName != null ? _kTIMGroupModifyInfoFlag_Name : 0;
      _modifyFlag |= topicInfo.notification != null ? _kTIMGroupModifyInfoFlag_Notification : 0;
      _modifyFlag |= topicInfo.introduction != null ? _kTIMGroupModifyInfoFlag_Introduction : 0;
      _modifyFlag |= topicInfo.topicFaceUrl != null ? _kTIMGroupModifyInfoFlag_FaceUrl : 0;
      _modifyFlag |= topicInfo.isAllMute != null ? _kTIMGroupModifyInfoFlag_ShutupAll : 0;
      _modifyFlag |= topicInfo.customString != null ? _kTIMGroupTopicModifyInfoFlag_CustomString : 0;
      _modifyFlag |= topicInfo.defaultPermissions != null ? _kTIMGroupModifyInfoFlag_DefaultPermissions : 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_topic_info_topic_id'] = topicInfo.topicID;
    data['group_modify_info_param_modify_flag'] = _modifyFlag;
    data['group_topic_info_topic_name'] = topicInfo.topicName;
    data['group_topic_info_introduction'] = topicInfo.introduction;
    data['group_topic_info_notification'] = topicInfo.notification;
    data['group_topic_info_topic_face_url'] = topicInfo.topicFaceUrl;
    data['group_topic_info_is_all_muted'] = topicInfo.isAllMute;
    data['group_topic_info_custom_string'] = topicInfo.customString;
    data['group_modify_info_param_default_permissions'] = topicInfo.defaultPermissions;
    if (topicInfo.draftText != null) {
      data['group_modify_info_param_draft_text'] = topicInfo.draftText;
    }

    return data;
  }
  String toLogString() {
    String res =
        "topicInfo:${topicInfo.toLogString()}|_modifyFlag:$_modifyFlag";
    return res;
  }
}
