import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimPermissionGroupInfo {
  String groupID;
  String? permissionGroupID;
  String permissionGroupName;
  String? customData;
  int? groupPermission;
  int? memberCount;

  V2TimPermissionGroupInfo({
    this.customData,
    required this.groupID,
    this.groupPermission,
    this.memberCount,
    this.permissionGroupID,
    required this.permissionGroupName,
  });

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from({
      'groupID': groupID,
      'permissionGroupID': permissionGroupID,
      'permissionGroupName': permissionGroupName,
      'customData': customData,
      'groupPermission': groupPermission,
      'memberCount': memberCount,
    });
  }

  static V2TimPermissionGroupInfo fromJson(Map json) {
    json = Utils.formatJson(json);
    return V2TimPermissionGroupInfo(
      groupID: json['groupID'] ?? "",
      permissionGroupID: json['permissionGroupID'] ?? "",
      permissionGroupName: json['permissionGroupName'] ?? "",
      customData: json['customData'] ?? "",
      groupPermission: json['groupPermission'] ?? 0,
      memberCount: json['memberCount'] ?? 0,
    );
  }
  String toLogString() {
    String res = "groupID:$groupID|permissionGroupID:$permissionGroupID|groupPermission:$groupPermission|memberCount:$memberCount|permissionGroupName:$permissionGroupName";
    return res;
  }
}
