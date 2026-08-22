import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_game_round_status.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';

/// Lightweight snapshot for the fixed area above the chat message list.
///
/// Keeping this separate lets notice/banner changes update without rebuilding
/// the full chat page and message list.
class ChatTopFixStateController extends ChangeNotifier {
  String _noticeText = '';
  bool _showGroupGameBanner = false;
  int _doorCount = 6;
  GroupGameRoundStatus _roundStatus = const GroupGameRoundStatus();
  GroupLiveSession? _groupLiveSession;
  bool _watchingGroupLive = false;

  String get noticeText => _noticeText;
  bool get showGroupGameBanner => _showGroupGameBanner;
  int get doorCount => _doorCount;
  GroupGameRoundStatus get roundStatus => _roundStatus;
  GroupLiveSession? get groupLiveSession => _groupLiveSession;
  bool get watchingGroupLive => _watchingGroupLive;

  void setSnapshot({
    required String noticeText,
    required bool showGroupGameBanner,
    required int doorCount,
    required GroupGameRoundStatus roundStatus,
    GroupLiveSession? groupLiveSession,
    bool watchingGroupLive = false,
    bool notify = true,
  }) {
    final normalizedNotice = noticeText.trim();
    final normalizedDoorCount = doorCount.clamp(2, 10);
    final nextWatching = groupLiveSession != null &&
        groupLiveSession.status.isActiveSlot &&
        watchingGroupLive;
    if (_noticeText == normalizedNotice &&
        _showGroupGameBanner == showGroupGameBanner &&
        _doorCount == normalizedDoorCount &&
        _sameRoundStatus(_roundStatus, roundStatus) &&
        _sameLiveSession(_groupLiveSession, groupLiveSession) &&
        _watchingGroupLive == nextWatching) {
      return;
    }
    _noticeText = normalizedNotice;
    _showGroupGameBanner = showGroupGameBanner;
    _doorCount = normalizedDoorCount;
    _roundStatus = _copyRoundStatus(roundStatus);
    _groupLiveSession = groupLiveSession == null
        ? null
        : GroupLiveSession(
            liveSessionId: groupLiveSession.liveSessionId,
            groupId: groupLiveSession.groupId,
            roomName: groupLiveSession.roomName,
            anchorUserId: groupLiveSession.anchorUserId,
            status: groupLiveSession.status,
            scheduledStartAt: groupLiveSession.scheduledStartAt,
            expireAt: groupLiveSession.expireAt,
            startedAt: groupLiveSession.startedAt,
            endedAt: groupLiveSession.endedAt,
            endReason: groupLiveSession.endReason,
          );
    _watchingGroupLive = nextWatching;
    if (notify) {
      notifyListeners();
    }
  }

  static GroupGameRoundStatus _copyRoundStatus(GroupGameRoundStatus source) {
    return GroupGameRoundStatus(
      bankerName: source.bankerName,
      bankerDoor: source.bankerDoor,
      bankerLimit: source.bankerLimit,
      totalBetCount: source.totalBetCount,
      doorBetTotals: List<int>.unmodifiable(source.doorBetTotals),
    );
  }

  static bool _sameRoundStatus(
    GroupGameRoundStatus left,
    GroupGameRoundStatus right,
  ) {
    return left.bankerName == right.bankerName &&
        left.bankerDoor == right.bankerDoor &&
        left.bankerLimit == right.bankerLimit &&
        left.totalBetCount == right.totalBetCount &&
        listEquals(left.doorBetTotals, right.doorBetTotals);
  }

  static bool _sameLiveSession(GroupLiveSession? left, GroupLiveSession? right) {
    if (left == null && right == null) return true;
    if (left == null || right == null) return false;
    return left.liveSessionId == right.liveSessionId &&
        left.status == right.status &&
        left.roomName == right.roomName &&
        left.anchorUserId == right.anchorUserId;
  }
}
