/// 群治理相关客户端上限，需与 99chat-server 配置保持一致。
class GroupGovernanceLimits {
  GroupGovernanceLimits._();

  static const int maxAdminCount = 30;

  /// 任意一次网络成员列表请求的上限；禁止循环翻到空。
  static const int groupMemberPageSize = 100;

  /// 邀请增量与 TCP `member_added` 重快照短窗去重。
  static const Duration membershipSyncCooldown = Duration(seconds: 4);
}
