import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_add_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member.dart';

/// V2TimGroupCreateParam
///
/// {@category Models}
///
class V2TimGroupCreateParam {
  late String groupName;
  late String groupType;
  String? groupID;
  String? notification;
  String? introduction;
  String? faceUrl;
  bool? isAllMuted; // 接口有误，此参数无效
  bool? isSupportTopic;
  GroupAddOptTypeEnum? addOpt;
  List<V2TimGroupMember>? memberList;
  GroupAddOptTypeEnum? approveOpt;
  bool? isEnablePermissionGroup;
  int? defaultPermissions;
  int? maxMemberCount;

  V2TimGroupCreateParam({
    required this.groupName,
    required this.groupType,
    this.groupID,
    this.notification,
    this.introduction,
    this.faceUrl,
    this.isAllMuted,
    this.isSupportTopic,
    this.addOpt,
    this.memberList,
    this.approveOpt,
    this.isEnablePermissionGroup,
    this.defaultPermissions,
    this.maxMemberCount,
  });

  V2TimGroupCreateParam.fromGroupInfo(V2TimGroupInfo groupInfo) {
    groupName = groupInfo.groupName ?? '';
    groupType = groupInfo.groupType;
    groupID = groupInfo.groupID;
    notification = groupInfo.notification;
    introduction = groupInfo.introduction;
    faceUrl = groupInfo.faceUrl;
    isAllMuted = groupInfo.isAllMuted;
    isSupportTopic = groupInfo.isSupportTopic;
    if (groupInfo.groupAddOpt != null &&
        groupInfo.groupAddOpt! >= 0 &&
        groupInfo.groupAddOpt! < GroupAddOptTypeEnum.values.length) {
      addOpt = GroupAddOptTypeEnum.values[groupInfo.groupAddOpt!];
    }
    if (groupInfo.approveOpt != null &&
        groupInfo.approveOpt! >= 0 &&
        groupInfo.approveOpt! < GroupAddOptTypeEnum.values.length) {
      approveOpt = GroupAddOptTypeEnum.values[groupInfo.approveOpt!];
    }
    isEnablePermissionGroup = groupInfo.isEnablePermissionGroup;
    defaultPermissions = groupInfo.defaultPermissions;
    maxMemberCount = groupInfo.memberMaxCount;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['create_group_param_group_name'] = groupName;
    data['create_group_param_group_id'] = groupID;
    data['create_group_param_group_type'] = GroupType.convertGroupType(groupType);
    data['create_group_param_is_support_topic'] = isSupportTopic;
    data['create_group_param_group_member_array'] = memberList;
    data['create_group_param_notification'] = notification;
    data['create_group_param_introduction'] = introduction;
    data['create_group_param_face_url'] = faceUrl;
    if (addOpt != null) {
      data['create_group_param_add_option'] =
          EnumUtils.dartGroupAddOptEnum2CType(addOpt!);
    }
    if (approveOpt != null) {
      data['create_group_param_approve_option'] =
          EnumUtils.dartGroupAddOptEnum2CType(approveOpt!);
    }
    data['create_group_param_enable_permission_group'] = isEnablePermissionGroup;
    data['create_group_param_default_permissions'] = defaultPermissions;

    if (maxMemberCount != null && maxMemberCount! > 0) {
      data['create_group_param_max_member_num'] = maxMemberCount;
    }

    return data;
  }


  String toLogString() {
    String res = "groupName:$groupName|groupType:$groupType|groupID:$groupID|isSupportTopic:$isSupportTopic|memberList:${memberList?.map((member) => member.toLogString()).toList().toString()}|notification:$notification|introduction:$introduction|faceUrl:$faceUrl|addOpt:$addOpt|approveOpt:$approveOpt|isEnablePermissionGroup:$isEnablePermissionGroup|defaultPermissions:$defaultPermissions|maxMemberCount:$maxMemberCount";
    return res;
  }
}
