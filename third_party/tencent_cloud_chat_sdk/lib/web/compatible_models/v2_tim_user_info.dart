import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimUserInfo
///
/// {@category Models}
///
class V2TimUserInfo {
  late String userID;
  String? nickName;
  String? faceUrl;

  V2TimUserInfo({
    required this.userID,
    this.nickName,
    this.faceUrl,
  });

  V2TimUserInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['userID'] ?? "";
    nickName = json['nickName'];
    faceUrl = json['faceUrl'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userID'] = userID;
    data['nickName'] = nickName;
    data['faceUrl'] = faceUrl;
    return data;
  }
  String toLogString() {
    String res = "userID:$userID|nickName:$nickName";
    return res;
  }
}

// {
//   "userID":"",
//   "nickName":"",
//   "faceUrl":""
// }
