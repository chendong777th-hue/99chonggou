import 'package:tencent_cloud_chat_sdk/web/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

final groupMemberRoleMapping = {"Owner": 400, "Admin": 300, "Member": 200};

class SetGroupMemberRole {
  static Object formatParams(Map<String, dynamic> params) => mapToJSObj({
        'groupID': params['groupID'],
        'userID': params['userID'],
        'role': GroupMemberRoleWeb.convertGroupMemberRoleToWeb(params['role'])
      });
}
