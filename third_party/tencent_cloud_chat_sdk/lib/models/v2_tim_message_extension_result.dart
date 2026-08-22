import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_extension.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMessageExtensionResult
///
/// {@category Models}
///
class V2TimMessageExtensionResult {
  late int resultCode;
  late String resultInfo;
  late V2TimMessageExtension? extension;

  V2TimMessageExtensionResult({
    required this.resultCode,
    required this.resultInfo,
    required this.extension,
  });

  V2TimMessageExtensionResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    resultCode = json["message_extension_result_code"] ?? -1;
    resultInfo = json["message_extension_result_info"] ?? "";
    if (json["message_extension_item"] != null) {
      extension = V2TimMessageExtension.fromJson(json["message_extension_item"]);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["message_extension_result_code"] = resultCode;
    data["message_extension_result_info"] = resultInfo;
    data["message_extension_item"] = extension?.toJson();
    return data;
  }
  String toLogString() {
    String res = "resultCode:$resultCode|resultInfo|$resultInfo|extension:${extension?.toLogString()}";
    return res;
  }
}
