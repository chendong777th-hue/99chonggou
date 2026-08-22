import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimPermissionGroupInfoResult {
  int resultCode;
  String resultMessage;
  V2TimPermissionGroupInfo? permissionGroupInfo;

  V2TimPermissionGroupInfoResult({
    required this.resultCode,
    required this.resultMessage,
    this.permissionGroupInfo,
  });

  static V2TimPermissionGroupInfoResult fromJson(Map json) {
    json = Utils.formatJson(json);
    return V2TimPermissionGroupInfoResult(
      resultCode: json['permission_group_info_result_error_code'],
      resultMessage: json['permission_group_info_result_error_message'],
      permissionGroupInfo: json['permission_group_info_result'] == null
          ? null
          : V2TimPermissionGroupInfo.fromJson(json['permission_group_info_result']),
    );
  }

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from({
      'resultCode': resultCode,
      'resultMessage': resultMessage,
      'permissionGroupInfo': permissionGroupInfo?.toJson(),
    });
  }

  String toLogString() {
    String res = "resultCode:$resultCode|resultMessage:$resultMessage|permissionGroupInfo:${permissionGroupInfo?.toLogString()}";
    return res;
  }
}
