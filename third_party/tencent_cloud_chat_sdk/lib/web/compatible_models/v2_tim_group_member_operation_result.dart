import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupMemberOperationResult
///
/// {@category Models}
///
class V2TimGroupMemberOperationResult {
  late String? memberID;
  late int? result;

  V2TimGroupMemberOperationResult({
    this.memberID,
    this.result,
  });

  V2TimGroupMemberOperationResult.fromJson(Map json) {
    json = Utils.formatJson(json);
    memberID = json['memberID'];
    result = json['result'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['memberID'] = memberID;
    data['result'] = result;
    return data;
  }
  String toLogString() {
    String res = "memberID:$memberID|result:$result";
    return res;
  }
}

// {
//   "memberID":"",
//   "result":0,
// }
