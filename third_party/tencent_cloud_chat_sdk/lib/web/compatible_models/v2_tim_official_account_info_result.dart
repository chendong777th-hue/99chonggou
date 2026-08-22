import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_official_account_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimOfficialAccountInfoResult
///
/// {@category Models}
///

class V2TimOfficialAccountInfoResult {
  String? resultInfo;
  V2TimOfficialAccountInfo? officialAccountInfo;
  int? resultCode;

  V2TimOfficialAccountInfoResult({
    this.resultInfo,
    this.officialAccountInfo,
    this.resultCode,
  });

  V2TimOfficialAccountInfoResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    resultInfo = json['resultInfo'];
    resultCode = json['resultCode'];
    officialAccountInfo = json['userID'] == null
        ? null
        : V2TimOfficialAccountInfo.fromJson(json['userID']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['resultInfo'] = resultInfo;
    data['resultCode'] = resultCode;
    data['officialAccountInfo'] = officialAccountInfo?.toJson();
    return data;
  }
  String toLogString() {
    String res = "resultInfo:$resultInfo|resultCode:$resultCode|officialAccountInfo:${officialAccountInfo?.toLogString()}";
    return res;
  }
}
