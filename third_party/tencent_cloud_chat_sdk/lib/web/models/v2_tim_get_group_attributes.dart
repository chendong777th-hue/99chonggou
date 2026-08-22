import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class GetGroupAttributes {
  static formateParams(Map<String, dynamic> params) =>
      mapToJSObj({'groupID': params['groupID'], 'keyList': params['keys']});
}
