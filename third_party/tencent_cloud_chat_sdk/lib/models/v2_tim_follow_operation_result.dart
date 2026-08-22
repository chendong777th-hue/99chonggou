import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimFollowOperationResult {
  String? resultInfo;
  String? userID;
  int? resultCode;

  V2TimFollowOperationResult({
    this.resultInfo,
    this.userID,
    this.resultCode,
  });

  V2TimFollowOperationResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    resultInfo = json['resultInfo'];
    resultCode = json['resultCode'];
    userID = json['userID'] ?? "";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['resultInfo'] = resultInfo;
    data['resultCode'] = resultCode;
    data['userID'] = userID;
    return data;
  }
  String toLogString() {
    String res = "resultInfo:$resultInfo|resultCode:$resultCode|userID:$userID";
    return res;
  }
}
