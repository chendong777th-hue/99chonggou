import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimUserStatus
///
/// {@category Models}
///
class V2TimUserStatus {
  String? userID;
  int? statusType;
  String? customStatus;
  List<String>? onlineDevices;

  V2TimUserStatus({
    this.userID,
    this.statusType,
    this.customStatus,
    this.onlineDevices,
  });

  V2TimUserStatus.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['user_status_identifier'] ?? "";
    statusType = json['user_status_status_type'];
    customStatus = json['user_status_custom_status'];
    onlineDevices = List<String>.from(json['user_status_online_devices'] ?? []);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_status_identifier'] = userID;
    data['user_status_status_type'] = statusType;
    data['user_status_custom_status'] = customStatus;
    data['user_status_online_devices'] = onlineDevices;

    return data;
  }
  String toLogString() {
    String res = "userID:$userID|statusType:$statusType|customStatus:$customStatus|onlineDevices:$onlineDevices";
    return res;
  }
}

// {
//   "userId":"",
//   "role":""
// }
