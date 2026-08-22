import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class MuteGroupMember {
  static Object formatParams(Map<String, dynamic> params) => mapToJSObj({
        'groupID': params['groupID'],
        'userID': params['userID'],
        'muteTime': params['seconds']
      });
}
