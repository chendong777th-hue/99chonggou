import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimFriendOperationResult
///
/// {@category Models}
///
class V2TimFriendOperationResult {
  late String? userID;
  late int? resultCode;
  late String? resultInfo;

  V2TimFriendOperationResult({
    required this.userID,
    this.resultCode,
    this.resultInfo,
  });

  V2TimFriendOperationResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['userID'] ?? "";
    resultCode = json['resultCode'];
    resultInfo = json['resultInfo'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userID'] = userID;
    data['resultCode'] = resultCode;
    data['resultInfo'] = resultInfo;
    return data;
  }
  String toLogString() {
    String res = "userID:$userID|resultCode:$resultCode|resultInfo:$resultInfo";
    return res;
  }
}
// {
//   "userID":"",
//   "resultCode":0,
//   "resultInfo":""
// }
