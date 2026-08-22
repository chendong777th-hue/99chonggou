import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimCreateGroupMemberInfo {
  String userID;
  int role;
  V2TimCreateGroupMemberInfo({
    required this.userID,
    required this.role,
  });
  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from({
      'userID': userID,
      'role': role,
    });
  }

  static V2TimCreateGroupMemberInfo fromJson(Map json) {
    json = Utils.formatJson(json);
    return V2TimCreateGroupMemberInfo(
      userID: json['userID'],
      role: json['role'],
    );
  }
  String toLogString() {
    String res = "userID:$userID|role:$role";
    return res;
  }
}
