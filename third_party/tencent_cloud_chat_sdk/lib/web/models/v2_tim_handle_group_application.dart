import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class HandleGroupApplication {
  static formateParams(Map<String, dynamic> params, String type) => mapToJSObj({
        'handleAction': type,
        'handleMessage': params['reason'],
        'message': parse(params['webMessageInstance'])
      });
}
