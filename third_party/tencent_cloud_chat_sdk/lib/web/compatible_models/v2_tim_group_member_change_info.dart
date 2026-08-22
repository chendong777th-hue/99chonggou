import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TIMGroupMemberChangeInfo
///
/// {@category Models}
///
class V2TimGroupMemberChangeInfo {
  String? userID;
  int? muteTime;

  V2TimGroupMemberChangeInfo({
    this.userID,
    this.muteTime,
  });

  V2TimGroupMemberChangeInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['userID'] ?? "";
    muteTime = json['muteTime'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userID'] = userID;
    data['muteTime'] = muteTime;
    return data;
  }
  String toLogString() {
    String res = "userID:$userID|muteTime:$muteTime";
    return res;
  }
}

// {
//   "userID":"",
//   "muteTime":0
// }
