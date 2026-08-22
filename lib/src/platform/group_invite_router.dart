import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';

/// 治理类群（Work/Public/Meeting/Community）邀请走 REST，不经 IM SDK。
bool shouldInviteViaRest(String? groupType) {
  return GroupJoinApi.isSelfHostedGovernanceGroupType(groupType);
}
