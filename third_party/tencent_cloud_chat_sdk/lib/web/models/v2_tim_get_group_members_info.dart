import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class GetGroupMembersInfo {
  static Object formatParams(Map<String, dynamic> params) => mapToJSObj(
      {'groupID': params['groupID'], 'userIDList': params['memberList']});
}
