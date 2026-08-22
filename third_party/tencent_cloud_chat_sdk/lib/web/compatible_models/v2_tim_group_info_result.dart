import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupInfoResult
///
/// {@category Models}
///

class V2TimGroupInfoResult {
  late int? resultCode;
  late String? resultMessage;
  late V2TimGroupInfo? groupInfo;

  V2TimGroupInfoResult({
    this.resultCode,
    this.resultMessage,
    this.groupInfo,
  });

  V2TimGroupInfoResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    resultCode = json['resultCode'];
    resultMessage = json['resultMessage'];
    groupInfo = V2TimGroupInfo.fromJson(json['groupInfo']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['resultCode'] = resultCode;
    data['resultMessage'] = resultMessage;
    data['groupInfo'] = groupInfo?.toJson();
    return data;
  }
  String toLogString() {
    String res = "resultCode:$resultCode|resultMessage:$resultMessage|groupInfo:${groupInfo?.toLogString()}";
    return res;
  }
}

// {
//   "resultCode":0,
//   "resultMessage":"",
//   "groupInfo":{}
// }
