import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class SetGroupAttributes {
  static foramteParams(Map<String, dynamic> params) => mapToJSObj({
        'groupID': params['groupID'],
        'groupAttributes': mapToJSObj(params['attributes'])
      });
}
