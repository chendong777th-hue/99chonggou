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
    errorCode = json['errorCode'];
    errorMessage = json['errorMessage'];
    topicID = json['topicID'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['errorCode'] = errorCode;
    data['errorMessage'] = errorMessage;
    data['topicID'] = topicID;
    return data;
  }
  String toLogString() {
    String res = "errorCode:$errorCode|topicID:$topicID|errorMessage:$errorMessage";
    return res;
  }
}
