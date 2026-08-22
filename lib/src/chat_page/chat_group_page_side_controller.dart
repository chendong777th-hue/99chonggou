import 'package:tencent_cloud_chat_demo/src/models/group_game_round_status.dart';

/// Group-game float + group-notice recheck flags owned by the open chat page.
class ChatGroupPageSideController {
  bool groupFeatureEnabled = false;

  /// 当前群 robot 已配对。
  bool agentRebateGroupBound = false;

  /// 当前群 robot 已开启。
  bool agentRebateGroupEnabled = false;

  /// 当前群租户下 `isAgent`。
  bool agentRebateIdentityEnabled = false;
  bool groupGameEnabled = false;
  bool groupGameFloatVisible = true;

  /// `GET /admin/my-config`：当前账号是否已绑定下注群。
  bool sangongConfigured = false;

  /// 已配置但尚未完成首次绑定引导（仅特权、未配置时为 true）。
  bool sangongNeedsSetup = false;

  bool sangongCanEditConfig = false;
  bool sangongCanManageMembers = false;
  String sangongMyRole = '';
  String sangongTenantId = '';

  int? sangongDoorCount;
  bool sangongRemoteBusy = false;
  GroupGameRoundStatus groupGameRoundStatus = const GroupGameRoundStatus();

  bool checkingGroupNotice = false;
  bool pendingGroupNoticeRecheck = false;
  bool flushingPendingGroupNotice = false;
  String groupNoticeBanner = '';

  void disableGroupGame() {
    groupGameEnabled = false;
    groupGameFloatVisible = true;
    clearSangongAccess();
  }

  void clearSangongAccess() {
    sangongConfigured = false;
    sangongNeedsSetup = false;
    sangongCanEditConfig = false;
    sangongCanManageMembers = false;
    sangongMyRole = '';
    sangongTenantId = '';
  }
}
