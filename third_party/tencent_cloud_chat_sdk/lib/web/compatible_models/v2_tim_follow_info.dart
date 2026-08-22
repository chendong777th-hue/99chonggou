import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimFollowInfo {
  String? resultInfo;
  int? followersCount;
  String? userID;
  int? resultCode;
  int? mutualFollowersCount;
  int? followingCount;

  V2TimFollowInfo({
    this.resultInfo,
    this.followersCount,
    this.userID,
    this.resultCode,
    this.mutualFollowersCount,
    this.followingCount,
  });

  V2TimFollowInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    resultInfo = json['resultInfo'];
    followersCount = json['followersCount'];
    resultCode = json['resultCode'];
    userID = json['userID'] ?? "";
    mutualFollowersCount = json['mutualFollowersCount'];
    followingCount = json['followingCount'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['resultInfo'] = resultInfo;
    data['followersCount'] = followersCount;
    data['resultCode'] = resultCode;
    data['userID'] = userID;
    data['mutualFollowersCount'] = mutualFollowersCount;
    data['followingCount'] = followingCount;
    return data;
  }
  String toLogString() {
    String res = "resultInfo:$resultInfo|followersCount:$followersCount|resultCode:$resultCode|userID:$userID|mutualFollowersCount:$mutualFollowersCount|followingCount:$followingCount";
    return res;
  }
}
