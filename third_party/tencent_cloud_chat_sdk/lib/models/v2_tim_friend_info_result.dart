import 'package:tencent_cloud_chat_sdk/enum/utils.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart';

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
    resultCode = json['friendship_friend_info_get_result_error_code'] ?? -1;
    resultInfo = json['friendship_friend_info_get_result_error_message'];
    relation = EnumUtils.cFriendshipRelationType2DartType(json['friendship_friend_info_get_result_relation_type'] ?? 0);
    friendInfo = json['friendship_friend_info_get_result_field_info'] != null
        ? V2TimFriendInfo.fromJson(json['friendship_friend_info_get_result_field_info'])
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
    String res = "resultCode:$resultCode|resultInfo:$resultInfo|relation:$relation|friendInfo:${friendInfo?.toLogString()}";
    return res;
  }
}

// {
//   "resultCode":0,
//   "resultInfo":"",
//   "relation":0,
//   "friendInfo":"_$V2TimFriendInfo"
// }
