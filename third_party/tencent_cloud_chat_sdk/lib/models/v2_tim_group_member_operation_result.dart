import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupMemberOperationResult
///
/// {@category Models}
///
class V2TimGroupMemberOperationResult {
  late String? memberID;
  late int? result;

  // 错误码含义参考：
  // 操作失败
  static const int _OPERATION_RESULT_FAIL = 0;
  // 操作成功
  static const int _OPERATION_RESULT_SUCC = 1;
  // 无效操作，加群时已经是群成员 或者 移除群组时不在群内
  static const int _OPERATION_RESULT_INVALID = 2;
  // 等待处理，邀请入群时等待对方处理
  static const int _OPERATION_RESULT_PENDING = 3;
  // 操作失败，创建群指定初始群成员列表或邀请入群时，被邀请者加入的群总数超限
  static const int _OPERATION_RESULT_OVERLIMIT = 4;

  V2TimGroupMemberOperationResult({
    this.memberID,
    this.result,
  });

  V2TimGroupMemberOperationResult.fromJson(Map json) {
    const String inviteResultUserID = "group_invite_member_result_identifier";
    const String inviteResultCode = "group_invite_member_result_result";

    const String deleteResultUserID = "group_delete_member_result_identifier";
    const String deleteResultCode = "group_delete_member_result_result";

    json = Utils.formatJson(json);
    if (json.containsKey(inviteResultUserID) || json.containsKey(inviteResultCode)) {
      memberID = json[inviteResultUserID];
      result = json[inviteResultCode];
    } else if (json.containsKey(deleteResultUserID) || json.containsKey(deleteResultCode)) {
      memberID = json[deleteResultUserID];
      result = json[deleteResultCode];
    } else {
      print('invalid V2TimGroupMemberOperationResult json result');
      memberID = null;
      result = null;
    }
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
