import 'v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimFriendInfo
///
/// {@category Models}
///
class V2TimFriendInfo {
  late String userID;
  late String? friendRemark;
  List<String>? friendGroups = List.empty(growable: true);
  Map<String, String>? friendCustomInfo;
  V2TimUserFullInfo? userProfile;

  V2TimFriendInfo({
    required this.userID,
    this.friendRemark,
    this.friendGroups,
    this.friendCustomInfo,
    this.userProfile,
  });

  V2TimFriendInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['userID'] ?? "";
    friendRemark = json['friendRemark'];
    friendGroups = json['friendGroups'].cast<String>();
    friendCustomInfo = json['friendCustomInfo'] == null
        ? <String, String>{}
        : Map<String, String>.from(json['friendCustomInfo']);
    userProfile = json['userProfile'] != null
        ? V2TimUserFullInfo.fromJson(json['userProfile'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userID'] = userID;
    data['friendRemark'] = friendRemark;
    data['friendGroups'] = friendGroups;
    data['friendCustomInfo'] = friendCustomInfo;
    if (userProfile != null) {
      data['userProfile'] = userProfile!.toJson();
    }
    return data;
  }
  String toLogString() {
    String res = "userID:$userID|friendRemark:$friendRemark|friendGroups:$friendGroups|friendCustomInfo:$friendCustomInfo";
    return res;
  }
}
// {
//   "userID":"",
//   "friendRemark":"",
//   "friendGroups":[""],
//   "friendCustomInfo":{},
//   "userProfile":{}
// }
