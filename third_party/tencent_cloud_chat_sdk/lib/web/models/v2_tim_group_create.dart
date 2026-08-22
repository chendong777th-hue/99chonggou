import 'package:tencent_cloud_chat_sdk/enum/group_member_role_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member.dart';
import 'package:tencent_cloud_chat_sdk/web/enum/group_add_opt.dart';
import 'package:tencent_cloud_chat_sdk/web/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/web/enum/group_receive_message_opt.dart';
import 'package:tencent_cloud_chat_sdk/web/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class V2TimGroupCreate {
  static Object formateParams(Map<String, dynamic> params) {
    final List<V2TimGroupMember>? memberList = params["memberList"];
    var formatedMemberList = List.empty(growable: true);
    if (memberList != null && memberList.isNotEmpty) {
      for (var element in memberList) {
        final memberParam = {
          "userID": element.userID,
          "role": element.role ==
                  GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_ROLE_ADMIN
              ? GroupMemberRoleWeb.convertGroupMemberRoleToWeb(
                  EnumUtils.convertGroupMemberRoleTypeEnum(element.role))
              : null,
        };
        formatedMemberList.add(mapToJSObj(memberParam));
      }
    }
    final templateMapping = <String, dynamic>{
      'name': params['groupName'],
      'type': GroupTypeWeb.convertGroupTypeToWeb(params['groupType']),
      'groupID': params['groupID'],
      'introduction': params['introduction'] ?? '',
      'joinOption': GroupAddOptWeb.convertGroupAddOptToWeb(params['addOpt']),
      'memberList': formatedMemberList,
      'groupCustomField': [],
      'avatar': params['faceUrl'] ?? '',
      'isSupportTopic': params['isSupportTopic'] ?? false,
      // "inviteOption": GroupAddOptWeb.convertGroupAddOptToWeb(params['approveOpt'])
    };
    return mapToJSObj(templateMapping);
  }

  static bool _getGroupAllMemberMutes(muteAllMembers) {
    if (muteAllMembers is bool) {
      return muteAllMembers;
    } else if (muteAllMembers is String) {
      return !(muteAllMembers == 'Off');
    }
    return false;
  }

  static Map<String, dynamic> convertGroupResultFromWebToDart(
      Map<String, dynamic> params) {
    return {
      'groupID': params["groupID"],
      'groupType': GroupTypeWeb.convertGroupType(params["type"]),
      'groupName': params["name"],
      'faceUrl': params["avatar"],
      'notification': params['notification'],
      'introduction': params['introduction'],
      'createTime': params['createTime'] == '' ? 0 : params['createTime'],
      'isSupportTopic': params['isSupportTopic'] ?? false,
      'groupAddOpt':
          GroupAddOptWeb.convertGroupAddOpt(params['joinOption']) ?? 0,
      'isAllMuted': _getGroupAllMemberMutes(params['muteAllMembers']),
      'joinTime': jsToMap(params['selfInfo'])['joinTime'] == ''
          ? 0
          : jsToMap(params['selfInfo'])['joinTime'],
      'lastInfoTime': params['lastInfoTime'] == '' ? 0 : params['lastInfoTime'],
      'lastMessageTime': jsToMap(params['lastMessage'])['lastTime'] == ''
          ? 0
          : jsToMap(params['lastMessage'])['lastTime'],
      'memberCount': params['memberCount'] == '' ? 0 : params['memberCount'],
      'onlineCount': 0, // web 不支持onlineCount
      'owner': params['ownerID'],
      'recvOpt': GroupRecvMsgOpt.convertMsgRecvOpt(
          jsToMap(params['selfInfo'])['messageRemindType']), // need to do
      'role': GroupMemberRoleWeb.convertGroupMemberRole(
          jsToMap(params['selfInfo'])['role']),
      'customInfo':
          convertGroupCustomInfoFromWebToDart(params['groupCustomField']),
    };
  }

  static List convertGroupCustomInfoFromDartToWeb(
      Map<String, dynamic> customInfo) {
    final formatedCustomInfo = customInfo.keys
        .map((e) => mapToJSObj({"key": e, "value": customInfo[e]}));
    return formatedCustomInfo.toList();
  }

  static Map<dynamic, dynamic> convertGroupCustomInfoFromWebToDart(
      List customInfo) {
    final formatedCustomInfo = {};
    for (var element in customInfo) {
      final formatedElement = jsToMap(element);
      formatedCustomInfo[formatedElement['key']] = formatedElement['value'];
    }
    return formatedCustomInfo;
  }

  static List<dynamic> formateGroupListResult(List resultFromJS) {
    if (resultFromJS.isNotEmpty) {
      final resultList = List.empty(growable: true);
      for (var element in resultFromJS) {
        final groupInfo = convertGroupResultFromWebToDart(jsToMap(element));
        resultList.add(groupInfo);
      }
      return resultList;
    } else {
      return List.empty();
    }
  }
}
