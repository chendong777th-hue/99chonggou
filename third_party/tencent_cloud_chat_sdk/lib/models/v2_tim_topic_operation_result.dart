import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimTopicInfo
///
/// {@category Models}
///
class V2TimTopicOperationResult {
  int? errorCode;
  String? errorMessage;
  String? topicID;

  V2TimTopicOperationResult({
    this.errorCode,
    this.errorMessage,
    this.topicID,
  });

  V2TimTopicOperationResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    errorCode = json['group_topic_operation_result_error_code'];
    errorMessage = json['group_topic_operation_result_error_message'];
    topicID = json['group_topic_operation_result_topic_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_topic_operation_result_error_code'] = errorCode;
    data['group_topic_operation_result_error_message'] = errorMessage;
    data['group_topic_operation_result_topic_id'] = topicID;
    return data;
  }

  String toLogString() {
    String res = "errorCode:$errorCode|topicID:$topicID|errorMessage:$errorMessage";
    return res;
  }
}
