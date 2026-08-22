import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimTopicPermissionResult {
  String topicID;
  int resultCode;
  String resultMessage;
  int topicPermission;
  String groupID;
  String germissionGroupID;

  V2TimTopicPermissionResult({
    required this.topicID,
    required this.resultCode,
    required this.resultMessage,
    required this.topicPermission,
    required this.groupID,
    required this.germissionGroupID,
  });
  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from({
      'topicID': topicID,
      'resultCode': resultCode,
      'resultMessage': resultMessage,
      'topicPermission': topicPermission,
      'groupID': groupID,
      'germissionGroupID': germissionGroupID,
    });
  }

  static V2TimTopicPermissionResult fromJson(Map json) {
    json = Utils.formatJson(json);
    return V2TimTopicPermissionResult(
      topicID: json['topicID'] ?? "",
      resultCode: json['resultCode'] ?? 0,
      resultMessage: json['resultMessage'] ?? "",
      topicPermission: json['topicPermission'] ?? 0,
      groupID: json['groupID'] ?? "",
      germissionGroupID: json['germissionGroupID'] ?? "",
    );
  }
  String toLogString() {
    String res = "topicID:$topicID|groupID:$groupID|resultCode:$resultCode|topicPermission:$topicPermission|germissionGroupID:$germissionGroupID";
    return res;
  }
}
