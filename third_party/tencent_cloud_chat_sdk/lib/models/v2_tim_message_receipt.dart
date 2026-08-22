import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_imsdk_bindings_generated.dart';
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
    userID = '';
    groupID = null;
    var convType = json['msg_receipt_conv_type'];
    if (convType == TIMConvType.kTIMConv_C2C.value) {
      userID = json['msg_receipt_conv_id'] ?? "";
    } else if (convType == TIMConvType.kTIMConv_Group.value) {
      groupID = json['msg_receipt_conv_id'];
    }
    timestamp = json['msg_receipt_time_stamp'] ?? 0;
    msgID = json['msg_receipt_msg_id'];
    readCount = json['msg_receipt_read_count'];
    unreadCount = json['msg_receipt_unread_count'];
    isPeerRead = json["msg_receipt_is_peer_read"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['msg_receipt_conv_type'] = TIMConvType.kTIMConv_C2C.value;
    data['msg_receipt_conv_id'] = userID;
    data['msg_receipt_time_stamp'] = timestamp;
    if (groupID != null) {
      data['msg_receipt_conv_id'] = groupID;
      data['msg_receipt_conv_type'] = TIMConvType.kTIMConv_Group.value;
    }
    data['msg_receipt_msg_id'] = msgID;
    data['msg_receipt_read_count'] = readCount;
    data['msg_receipt_unread_count'] = unreadCount;
    data["msg_receipt_is_peer_read"] = isPeerRead;
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
