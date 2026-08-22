/// V2TimFriendApplicationHandleParam
///
/// {@category Models}
///
class V2TimFriendApplicationHandleParam {
  late String userID;
  late int responseType;

  V2TimFriendApplicationHandleParam({
    required this.userID,
    required this.responseType,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['friend_response_identifier'] = userID;
    data['friend_response_action'] = responseType;
    return data;
  }

  String toLogString() {
    String res = "userID:$userID|responseType:$responseType";
    return res;
  }
}
