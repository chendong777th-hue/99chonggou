import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupApplication
///
/// {@category Models}
///
class V2TimGroupApplication {
  late String groupID;
  late String? fromUser;
  late String? fromUserNickName;
  late String? fromUserFaceUrl;
  late String? toUser;
  late int? addTime;
  late String? requestMsg;
  late String? handledMsg;
  late int type;
  late int handleStatus;
  late int handleResult;
  late String _authentication;

  V2TimGroupApplication({
    required this.groupID,
    this.fromUser,
    this.fromUserNickName,
    this.fromUserFaceUrl,
    this.toUser,
    this.addTime,
    this.requestMsg,
    this.handledMsg,
    required this.type,
    required this.handleStatus,
    required this.handleResult,
    authentication = '',
  }) : _authentication = authentication;

  V2TimGroupApplication.fromJson(Map json) {
    json = Utils.formatJson(json);
    groupID = json['group_pendency_group_id'] ?? '';
    fromUser = json['group_pendency_form_identifier'];
    fromUserNickName = json['group_pendency_from_nick_name'];
    fromUserFaceUrl = json['group_pendency_from_face_url'];
    toUser = json['group_pendency_to_identifier'];
    addTime = json['group_pendency_add_time'];
    requestMsg = json['group_pendency_apply_invite_msg'];
    handledMsg = json['group_pendency_approval_msg'];
    type = json['group_pendency_pendency_type'] ?? 0;
    handleStatus = json['group_pendency_handled'] ?? 0;
    handleResult = json['group_pendency_handle_result'] ?? 0;
    _authentication = json['group_pendency_authentication'] ?? '';
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_pendency_group_id'] = groupID;
    data['group_pendency_form_identifier'] = fromUser;
    data['group_pendency_from_nick_name'] = fromUserNickName;
    data['group_pendency_from_face_url'] = fromUserFaceUrl;
    data['group_pendency_to_identifier'] = toUser;
    data['group_pendency_add_time'] = addTime;
    data['group_pendency_apply_invite_msg'] = requestMsg;
    data['group_pendency_approval_msg'] = handledMsg;
    data['group_pendency_pendency_type'] = type;
    data['group_pendency_handled'] = handleStatus;
    data['group_pendency_handle_result'] = handleResult;
    data['group_pendency_authentication'] = _authentication;
    return data;
  }

  String get authentication => _authentication;

  String toLogString() {
    String res = "groupID:$groupID|fromUser:$fromUser|toUser:$toUser|addTime:$addTime|type:$type|handleStatus:$handleStatus|handleResult:$handleResult|authentication:$_authentication";
    return res;
  }
}

// {
//   "groupID":"",
//   "fromUser":"",
//    "fromUserNickName":"",
//    "fromUserFaceUrl":"",
//    "toUser":"",
//    "addTime":0,
//    "requestMsg":"",
//    "handledMsg":"",
//    "type":0,
//    "handleStatus":0,
//    "handleResult":0
// }
