import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';
import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupMemberInfoModifyParam
///
/// {@category Models}
///
class V2TimGroupMemberInfoModifyParam {
  late String groupID;
  late String userID;
  late int modifyFlag;
  String? nameCard;
  Map<String, String>? customInfo;
  int? seconds;
  GroupMemberRoleTypeEnum? role;
  ReceiveMsgOptEnum? receiveMessageOpt;

  // 未定义
  static const int kTIMGroupMemberModifyFlag_None = 0x00;
  // 修改消息接收选项
  static const int kTIMGroupMemberModifyFlag_MsgFlag = 0x01;
  // 修改成员角色
  static const int kTIMGroupMemberModifyFlag_MemberRole = 0x01 << 1;
  // 修改禁言时间
  static const int kTIMGroupMemberModifyFlag_ShutupTime = 0x01 << 2;
  // 修改群名片
  static const int kTIMGroupMemberModifyFlag_NameCard = 0x01 << 3;
  // 修改群成员自定义信息
  static const int kTIMGroupMemberModifyFlag_Custom = 0x01 << 4;

  V2TimGroupMemberInfoModifyParam({
    required this.groupID,
    required this.userID,
    this.nameCard,
    this.customInfo,
    this.seconds,
    this.role,
    this.receiveMessageOpt
  }) {
      modifyFlag = 0;
      modifyFlag |= receiveMessageOpt != null ? kTIMGroupMemberModifyFlag_MsgFlag : 0;
      modifyFlag |= role != null ? kTIMGroupMemberModifyFlag_MemberRole : 0;
      modifyFlag |= seconds != null ? kTIMGroupMemberModifyFlag_ShutupTime : 0;
      modifyFlag |= nameCard != null ? kTIMGroupMemberModifyFlag_NameCard : 0;
      modifyFlag |= customInfo != null ? kTIMGroupMemberModifyFlag_Custom : 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_modify_member_info_group_id'] = groupID;
    data['group_modify_member_info_identifier'] = userID;
    data['group_modify_member_info_modify_flag'] = modifyFlag;
    if (receiveMessageOpt != null) {
      data['group_modify_member_info_msg_flag'] = EnumUtils.dartReceiveMessageOpt2CReceiveMessageOpt(receiveMessageOpt!);
    }
    if (role != null) {
      data['group_modify_member_info_member_role'] = EnumUtils.convertGroupMemberRoleTypeEnum(role!);
    }
    data['group_modify_member_info_shutup_time'] = seconds;
    data['group_modify_member_info_name_card'] = nameCard;
    if (customInfo != null && customInfo!.isNotEmpty) {
      var jsonCustomInfo = Tools.map2JsonList(customInfo!, "group_member_info_custom_string_info_key", "group_member_info_custom_string_info_value");
      data['group_modify_member_info_custom_info'] = jsonCustomInfo;
    }

    return data;
  }

  String toLogString() {
    String res =
        "groupID:$groupID, userID:$userID, modifyFlag:$modifyFlag, receiveMessageOpt:$receiveMessageOpt, role:$role, seconds:$seconds, nameCard:$nameCard, customInfo:$customInfo";
    return res;
  }
}
