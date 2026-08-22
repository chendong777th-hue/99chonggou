import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMessageReceipt
///
/// {@category Models}
///
class V2TimMessageReceipt {
  late String userID;
  late int timestamp;
  late String? groupID;
  late String? msgID;
  late int? readCount;
  late int? unreadCount;
  bool? isPeerRead;

  V2TimMessageReceipt({
    required this.userID,
    required this.timestamp,
    this.groupID,
    this.msgID,
    this.readCount,
    this.unreadCount,
    this.isPeerRead,
  });

  V2TimMessageReceipt.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['userID'] ?? "";
    timestamp = json['timestamp'];
    msgID = json['msgID'] ?? "";
    readCount = json['readCount'];
    unreadCount = json['unreadCount'];
    groupID = json['groupID'];
    isPeerRead = json["isPeerRead"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userID'] = userID;
    data['timestamp'] = timestamp;
    data['groupID'] = groupID ?? "";
    data['msgID'] = msgID;
    data['readCount'] = readCount;
    data['unreadCount'] = unreadCount;
    data["isPeerRead"] = isPeerRead;
    return data;
  }
  String toLogString() {
    String res = "userID:$userID|timestamp:$timestamp|groupID:$groupID|msgID:$msgID|readCount:$readCount|unreadCount:$unreadCount|isPeerRead:$isPeerRead";
    return res;
  }
}

// {
//   "userID":"",
//   "timestamp":0
// }
