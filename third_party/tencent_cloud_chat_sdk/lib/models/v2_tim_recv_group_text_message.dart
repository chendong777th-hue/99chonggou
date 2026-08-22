import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimRecvGroupTextMessage
///
/// {@category Models}
///
class V2TimRecvGroupTextMessage {
  late String msgID;
  late V2TimUserInfo sender;
  late String groupID;
  late String? text;

  V2TimRecvGroupTextMessage({
    required this.msgID,
    required this.sender,
    required this.groupID,
    this.text,
  });

  V2TimRecvGroupTextMessage.fromJson(Map json) {
    json = Utils.formatJson(json);
    msgID = json['msgID'] ?? '';
    sender = V2TimUserInfo.fromJson(json['sender'] ?? {});
    groupID = json['groupID'] ?? '';
    text = json['customData'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['msgID'] = msgID;
    data['sender'] = sender.toJson();
    data['groupID'] = groupID;
    data['text'] = text;
    return data;
  }
  String toLogString() {
    String res = "msgID:$msgID|${sender.toLogString()}|groupID:$groupID|text:$text";
    return res;
  }
}
// {
//   "msgID":",",
//   "sender":{},
//   "groupID":"",
//   "customData":""
// }
