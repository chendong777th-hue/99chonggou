import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';

/// V2TimFriendInfoResult
///
/// {@category Models}
///

class V2TimFriendInfoResult {
  late int resultCode;
  late String? resultInfo;
  late int? relation;
  V2TimFriendInfo? friendInfo;

  V2TimFriendInfoResult({
    required this.resultCode,
    this.resultInfo,
    this.relation,
    this.friendInfo,
  });

  V2TimFriendInfoResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    resultCode = json['resultCode'];
    resultInfo = json['resultInfo'];
    relation = json['relation'];
    friendInfo = json['friendInfo'] != null
        ? V2TimFriendInfo.fromJson(json['friendInfo'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['resultCode'] = resultCode;
    data['resultInfo'] = resultInfo;
    data['relation'] = relation;
    if (friendInfo != null) {
      data['friendInfo'] = friendInfo?.toJson();
    }
    return data;
  }
  String toLogString() {
    String res = "resultCode:$resultCode|resultInfo:$resultInfo|relation:$relation";
    return res;
  }
}

// {
//   "resultCode":0,
//   "resultInfo":"",
//   "relation":0,
//   "friendInfo":"_$V2TimFriendInfo"
// }
