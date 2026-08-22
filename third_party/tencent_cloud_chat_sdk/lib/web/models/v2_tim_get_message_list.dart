import 'package:js/js.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

// 需要传递object时可以直接使用这种形式创建 对应博客：https://stackoverflow.com/questions/33394867/passing-dart-objects-to-js-functions-in-js-interop
@anonymous
@JS()
class GetMessageListParams {
  external String get conversationID;
  external set conversationID(String value);

  external int get count;
  external set count(int value);
}

class GetMessageList {
  late String conversationID;
  late int count;

  static formateParams(Map<String, dynamic> data) {
    // int getType = HistoryMessageGetType.V2TIM_GET_LOCAL_OLDER_MSG,
    // String? userID,
    // String? groupID,
    // int lastMsgSeq = -1,
    // required int count,
    // List<int>? messageTypeList, // web暂不处理
    // String? lastMsgID,
    // List<int>? messageSeqList,
    // int? timeBegin,
    // int? timePeriod,

    Map<String, dynamic> params = <String, dynamic>{};
    final groupID = data['groupID'] ?? '';
    final userID = data['userID'] ?? '';
    int? seq = data["lastMsgSeq"];
    int? time = data["timeBegin"];
    int getType = data["getType"] ?? 1;
    final convType = groupID != '' ? 'GROUP' : 'C2C';
    final sendToUserID = convType == 'GROUP' ? groupID : userID;
    final haveTwoValues = groupID != '' && userID != '';
    if (haveTwoValues) {
      return null;
    }

    params["conversationID"] = convType + sendToUserID;
    params["count"] = data["count"];
    params["nextReqMessageID"] = data["lastMsgID"];
    if (seq != null && seq != -1) {
      params["sequence"] = seq;
    }
    if (time != null) {
      params["time"] = time;
    }
    if (getType == 1 || getType == 3) {
      params["direction"] = 0;
    } else {
      params["direction"] = 1;
    }
    return mapToJSObj(params);
  }
}
