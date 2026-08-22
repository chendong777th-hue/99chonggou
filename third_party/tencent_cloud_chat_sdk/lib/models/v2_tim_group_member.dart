import 'package:tencent_cloud_chat_sdk/enum/group_member_role_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';

class V2TimGroupMember {
  late String userID;
  late GroupMemberRoleTypeEnum role;
  V2TimGroupMember({required this.userID, required this.role});

  Map<dynamic, dynamic> toJson() {
    return {
      "group_member_info_identifier": userID,
      "group_member_info_member_role": EnumUtils.convertGroupMemberRoleTypeEnum(role)
    };
  }
  String toLogString() {
    String res = "userID:$userID|role:${EnumUtils.convertGroupMemberRoleTypeEnum(role)}";
    return res;
  }
}
