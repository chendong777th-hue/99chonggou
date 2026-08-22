import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';

/// 群通知进聊前服务端校验结果。
enum GroupNoticeOpenGate {
  allow,
  denyNotInGroup,
  unavailable,
}

/// 将 [MeGroupApi.fetchGroupDetail] 结果映射为进聊门禁（无网络副作用）。
GroupNoticeOpenGate interpretMeGroupDetailForOpen({
  MeGroupRecord? record,
  String? errorCode,
}) {
  final code = (errorCode ?? '').trim().toUpperCase();
  if (code.isNotEmpty) {
    if (code.contains('NOT_GROUP_MEMBER') ||
        code.contains('GROUP_NOT_FOUND') ||
        code.contains('GROUP_DISMISSED')) {
      return GroupNoticeOpenGate.denyNotInGroup;
    }
    return GroupNoticeOpenGate.unavailable;
  }
  if (record == null) {
    return GroupNoticeOpenGate.denyNotInGroup;
  }
  if (record.myRole < GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER) {
    return GroupNoticeOpenGate.denyNotInGroup;
  }
  return GroupNoticeOpenGate.allow;
}
