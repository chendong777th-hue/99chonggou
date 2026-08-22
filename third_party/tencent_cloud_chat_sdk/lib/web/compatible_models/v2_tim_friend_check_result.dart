import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimFriendCheckResult
///
/// {@category Models}
///
class V2TimFriendCheckResult {
  late String userID;
  late int resultCode;
  late String? resultInfo;
  late int resultType;

  V2TimFriendCheckResult({
    required this.userID,
    required this.resultCode,
    this.resultInfo,
    required this.resultType,
  });

  V2TimFriendCheckResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['userID'] ?? "";
    resultCode = json['resultCode'];
    resultInfo = json['resultInfo'];
    resultType = json['resultType'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userID'] = userID;
    data['resultCode'] = resultCode;
    data['resultInfo'] = resultInfo;
    data['resultType'] = resultType;
    return data;
  }
  String toLogString() {
    String res = "userID:$userID|resultCode:$resultCode|resultInfo:$resultInfo|resultType:$resultType";
    return res;
  }
}

// {
//   "userID" : "",
//     "resultCode" : 0,
//     "resultInfo" : "",
//     "resultType" : 0,
// }
