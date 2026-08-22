import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

final groupMemberRoleMapping = {"Owner": 400, "Admin": 300, "Member": 200};

class TransferGroupOwner {
  static Object formatParams(Map<String, dynamic> params) => mapToJSObj(
      {'groupID': params['groupID'], 'newOwnerID': params['userID']});
}
