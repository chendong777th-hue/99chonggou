import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimUserInfo
///
/// {@category Models}
///
class V2TimUserInfo {
  late String userID;
  String? nickName;
  String? faceUrl;

  V2TimUserInfo({
    required this.userID,
    this.nickName,
    this.faceUrl,
  });

  V2TimUserInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['user_profile_identifier'] ?? "";
    nickName = json['user_profile_nick_name'];
    faceUrl = json['user_profile_face_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_profile_identifier'] = userID;
    data['user_profile_nick_name'] = nickName;
    data['user_profile_face_url'] = faceUrl;
    return data;
  }
  String toLogString() {
    String res = "userID:$userID|nickName:$nickName|faceUrl:$faceUrl";
    return res;
  }
}

// {
//   "userID":"",
//   "nickName":"",
//   "faceUrl":""
// }
