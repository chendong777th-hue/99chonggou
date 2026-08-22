import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_info.dart';
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
  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from({
      'resultCode': resultCode,
      'resultMessage': resultMessage,
      'permissionGroupInfo': permissionGroupInfo?.toJson(),
    });
  }

  static V2TimPermissionGroupInfoResult fromJson(Map json) {
    json = Utils.formatJson(json);
    return V2TimPermissionGroupInfoResult(
      resultCode: json['resultCode'],
      resultMessage: json['resultMessage'],
      permissionGroupInfo: json['permissionGroupInfo'] == null
          ? null
          : V2TimPermissionGroupInfo.fromJson(json['permissionGroupInfo']),
    );
  }
  String toLogString() {
    String res = "resultCode:$resultCode|resultMessage:$resultMessage|permissionGroupInfo:${permissionGroupInfo?.toLogString()}";
    return res;
  }
}
