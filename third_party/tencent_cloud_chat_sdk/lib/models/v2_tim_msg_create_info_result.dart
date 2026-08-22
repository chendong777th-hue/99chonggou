import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupMemberInfoResult
///
/// {@category Models}
///

class V2TimMsgCreateInfoResult {
  String? id;
  V2TimMessage? messageInfo;

  V2TimMsgCreateInfoResult({
    this.id,
    this.messageInfo,
  });

  V2TimMsgCreateInfoResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    id = json['id'];
    messageInfo = json['messageInfo'] != null
        ? V2TimMessage.fromJson(json['messageInfo'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    if (messageInfo != null) {
      data['messageInfo'] = messageInfo?.toJson();
    }
    return data;
  }
  String toLogString() {
    String res = "id:$id|messageInfo:${messageInfo?.toLogString()}";
    return res;
  }
}
// {
//   "nextSeq":0,
//   "memberInfoList":[{}]
// }
