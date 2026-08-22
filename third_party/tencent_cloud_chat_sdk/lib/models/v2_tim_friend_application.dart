import 'package:tencent_cloud_chat_sdk/enum/utils.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimFriendApplication
///
/// {@category Models}
///
class V2TimFriendApplication {
  late String userID;
  late String? nickname;
  late String? faceUrl;
  late int? addTime;
  late String? addSource;
  late String? addWording;
  late int type;

  V2TimFriendApplication({
    required this.userID,
    this.nickname,
    this.faceUrl,
    this.addTime,
    this.addSource,
    this.addWording,
    required this.type,
  });

  V2TimFriendApplication.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['friend_add_pendency_info_identifier'] ?? "";
    nickname = json['friend_add_pendency_info_nick_name'];
    faceUrl = json['friend_add_pendency_info_face_url'];
    addTime = json['friend_add_pendency_info_add_time'];
    addSource = json['friend_add_pendency_info_add_source'];
    addWording = json['friend_add_pendency_info_add_wording'];
    type = EnumUtils.cFriendPendencyType2DartType(json['friend_add_pendency_info_type'] ?? 0);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['friend_add_pendency_info_identifier'] = userID;
    data['friend_add_pendency_info_nick_name'] = nickname;
    data['friend_add_pendency_info_face_url'] = faceUrl;
    data['friend_add_pendency_info_add_time'] = addTime;
    data['friend_add_pendency_info_add_source'] = addSource;
    data['friend_add_pendency_info_add_wording'] = addWording;
    data['friend_add_pendency_info_type'] = EnumUtils.dartFriendApplicationType2CType(type);
    return data;
  }

  /// 给加好友申请回调使用
  V2TimFriendApplication.fromJsonForCallback(Map json) {
    json = Utils.formatJson(json);
    userID = json['friend_add_pendency_identifier'] ?? "";
    nickname = json['friend_add_pendency_nick_name'];
    faceUrl = json['friend_add_pendency_face_url'];
    addTime = json['friend_add_pendency_add_time'];
    addSource = json['friend_add_pendency_add_source'];
    addWording = json['friend_add_pendency_add_wording'];
    type = EnumUtils.cFriendPendencyType2DartType(json['friend_add_pendency_type'] ?? 0);
  }

  /// 给加好友申请回调使用
  Map<String, dynamic> toJsonForCallback() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['friend_add_pendency_identifier'] = userID;
    data['friend_add_pendency_nick_name'] = nickname;
    data['friend_add_pendency_face_url'] = faceUrl;
    data['friend_add_pendency_add_time'] = addTime;
    data['friend_add_pendency_add_source'] = addSource;
    data['friend_add_pendency_add_wording'] = addWording;
    data['friend_add_pendency_type'] = EnumUtils.dartFriendApplicationType2CType(type);
    return data;
  }

  String toLogString() {
    String res = "userID:$userID|addTime:$addTime|addSource:$addSource|addWording:$addWording|type:$type";
    return res;
  }
}

// {
//   "userID":"",
//   "nickname":"",
//   "faceUrl":"",
//   "addTime":0,
//   "addSource":"",
//   "addWording":"",
//   "type":1
// }
