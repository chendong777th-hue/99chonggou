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
    userID = json['userID'] ?? "";
    nickname = json['nickname'];
    faceUrl = json['faceUrl'];
    addTime = json['addTime'];
    addSource = json['addSource'];
    addWording = json['addWording'];
    type = json['type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userID'] = userID;
    data['nickname'] = nickname;
    data['faceUrl'] = faceUrl;
    data['addTime'] = addTime;
    data['addSource'] = addSource;
    data['addWording'] = addWording;
    data['type'] = type;
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
