import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimUserStatus
///
/// {@category Models}
///
class V2TimUserStatus {
  String? userID;
  int? statusType;
  String? customStatus;

  V2TimUserStatus({
    this.userID,
    this.statusType,
    this.customStatus,
  });

  V2TimUserStatus.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['userID'] ?? "";
    statusType = json['statusType'];
    customStatus = json['customStatus'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userID'] = userID;
    data['statusType'] = statusType;
    data['customStatus'] = customStatus;
    return data;
  }
  String toLogString() {
    String res = "userID:$userID|statusType:$statusType";
    return res;
  }
}

// {
//   "userId":"",
//   "role":""
// }
