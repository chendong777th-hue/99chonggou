import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimFollowTypeCheckResult {
  String? resultInfo;
  String? userID;
  int? resultCode;
  int? followType;

  V2TimFollowTypeCheckResult({
    this.resultInfo,
    this.userID,
    this.resultCode,
    this.followType,
  });

  V2TimFollowTypeCheckResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    resultInfo = json['resultInfo'];
    resultCode = json['resultCode'];
    userID = json['userID'] ?? "";
    followType = json['followType'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['resultInfo'] = resultInfo;
    data['resultCode'] = resultCode;
    data['userID'] = userID;
    data['followType'] = followType;
    return data;
  }
  String toLogString() {
    String res = "resultInfo:$resultInfo|resultCode:$resultCode|userID:$userID|followType:$followType";
    return res;
  }
}
