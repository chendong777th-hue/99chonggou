import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimUserFullInfo
///
/// {@category Models}
///
class V2TimUserFullInfo {
  String? userID;
  String? nickName;
  String? faceUrl;
  String? selfSignature;
  int? gender;
  int? allowType;
  Map<String, String>? customInfo;
  int? role;
  int? level;
  int? birthday;

  V2TimUserFullInfo({
    this.userID,
    this.nickName,
    this.faceUrl,
    this.selfSignature,
    this.gender,
    this.allowType,
    this.customInfo,
    this.role,
    this.level,
    this.birthday,
  });

  V2TimUserFullInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['userID'] ?? "";
    nickName = json['nickName'];
    faceUrl = json['faceUrl'];
    selfSignature = json['selfSignature'];
    gender = json['gender'];
    allowType = json['allowType'];
    customInfo = json['customInfo'] == null
        ? <String, String>{}
        : Map<String, String>.from(json['customInfo']);
    role = json['role'];
    level = json['level'];
    birthday = json['birthday'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userID'] = userID;
    data['nickName'] = nickName;
    data['faceUrl'] = faceUrl;
    data['selfSignature'] = selfSignature;
    data['gender'] = gender;
    data['allowType'] = allowType;
    data['customInfo'] = customInfo;
    data['role'] = role;
    data['level'] = level;
    data['birthday'] = birthday;
    return data;
  }
  String toLogString() {
    String res = "userID:$userID|nickName:$nickName|allowType:$allowType|role:$role";
    return res;
  }
}
// {
//   "userID":"",
//   "nickName":"",
//   "faceUrl":"",
//   "selfSignature":"",
//   "gender":0,
//   "allowType":0,
//   "customInfo":{"test":""},
//   "role":0,
//   "level":0
// }
