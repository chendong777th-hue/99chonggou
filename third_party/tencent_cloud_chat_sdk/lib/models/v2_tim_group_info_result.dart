import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_imsdk_bindings_generated.dart';
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
    resultCode = json['get_groups_info_result_code'];
    resultMessage = json['get_groups_info_result_desc'];
    groupInfo = V2TimGroupInfo.fromJson(json['get_groups_info_result_info']);
    if (resultCode == TIMErrCode.ERR_SVR_GROUP_PERMISSION_DENY.value) {
      groupInfo?.groupType = "";
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['get_groups_info_result_code'] = resultCode;
    data['get_groups_info_result_desc'] = resultMessage;
    data['get_groups_info_result_info'] = groupInfo?.toJson();
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
