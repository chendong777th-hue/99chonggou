import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMember
///
/// {@category Models}
///
class V2TimMember {
  late String userId;
  late String role;

  V2TimMember({
    required this.userId,
    required this.role,
  });

  V2TimMember.fromJson(Map json) {
    json = Utils.formatJson(json);
    userId = json['userId'];
    role = json['role'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userId'] = userId;
    data['role'] = role;
    return data;
  }
  String toLogString() {
    String res = "userId:$userId|role:$role";
    return res;
  }
}

// {
//   "userId":"",
//   "role":""
// }
