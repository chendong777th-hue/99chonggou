import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TIMTopicInfoResult
///
/// {@category Models}
///
class V2TimTopicInfoResult {
  int? errorCode;
  String? errorMessage;
  V2TimTopicInfo? topicInfo;

  V2TimTopicInfoResult({
    this.errorCode,
    this.errorMessage,
    this.topicInfo,
  });

  V2TimTopicInfoResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    errorCode = json['errorCode'];
    errorMessage = json['errorMessage'];
    if (json['topicInfo'] != null) {
      topicInfo = V2TimTopicInfo.fromJson(json['topicInfo']);
    }
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["errorCode"] = errorCode;
    data["errorMessage"] = errorMessage;
    data["topicInfo"] = topicInfo?.toJson();
    return data;
  }
  String toLogString() {
    String res = "errorCode:$errorCode|errorMessage:$errorMessage|topicInfo:${topicInfo?.toLogString()}";
    return res;
  }
}
