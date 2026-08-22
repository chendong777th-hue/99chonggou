import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info.dart';
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
    errorCode = json['group_topic_info_result_error_code'];
    errorMessage = json['group_topic_operation_result_error_message'];
    if (json['group_topic_info_result_topic_info'] != null) {
      topicInfo = V2TimTopicInfo.fromJson(json['group_topic_info_result_topic_info']);
    }
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["group_topic_info_result_error_code"] = errorCode;
    data["group_topic_info_result_error_message"] = errorMessage;
    data["group_topic_info_result_topic_info"] = topicInfo?.toJson();
    return data;
  }
  String toLogString() {
    String res = "errorCode:$errorCode|errorMessage:$errorMessage|topicInfo:${topicInfo?.toLogString()}";
    return res;
  }
}
