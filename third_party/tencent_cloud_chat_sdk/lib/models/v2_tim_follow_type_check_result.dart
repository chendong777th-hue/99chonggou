import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';

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
    resultInfo = json['follow_type_check_result_info'];
    resultCode = json['follow_type_check_result_code'];
    userID = json['follow_type_check_result_user_id'] ?? "";
    followType = EnumUtils.cFollowType2DartType(json['follow_type_check_result_follow_type']);
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
