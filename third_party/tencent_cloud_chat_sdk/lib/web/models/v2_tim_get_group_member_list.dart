import 'package:tencent_cloud_chat_sdk/web/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/web/models/v2_tim_group_create.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class GetGroupMemberList {
  static Object formateParams(Map<String, dynamic> params) {
    return mapToJSObj({
      "groupID": params['groupID'],
      "count": params['count'],
      "offset": params['nextSeq'],
      "role": GroupMemberRoleWeb.convertGroupMemberRoleParameterToWeb(
          params["filter"]),
    });
  }

  static formateGroupResult(List<dynamic> memberList) {
    final memberListResult = memberList.map((element) {
      final formatedElement = jsToMap(element);
      return {
        'userID': formatedElement['userID'],
        'role':
            GroupMemberRoleWeb.convertGroupMemberRole(formatedElement['role']),
        'muteUntil': formatedElement['muteUntil'],
        'joinTime': formatedElement['joinTime'],
        'nickName': formatedElement['nick'],
        'nameCard': formatedElement['nameCard'],
        'friendRemark': "",
        'faceUrl': formatedElement['avatar'],
        'customInfo': V2TimGroupCreate.convertGroupCustomInfoFromWebToDart(
            formatedElement['memberCustomField']) // need format
      };
    });
    return memberListResult.toList();
  }
}
