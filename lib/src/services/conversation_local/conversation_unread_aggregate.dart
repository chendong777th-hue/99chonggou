import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_unread_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

/// Tab / 桌面角标用的会话未读聚合（不依赖 UI 窗口全表）。
class ConversationUnreadAggregate extends ChangeNotifier {
  ConversationUnreadAggregate._() {
    archivedConversationC2cIDsNotifier.addListener(_onArchivedChanged);
    archivedConversationGroupIDsNotifier.addListener(_onArchivedChanged);
  }

  static final ConversationUnreadAggregate instance =
      ConversationUnreadAggregate._();

  static const Duration _defaultDebounce = Duration(milliseconds: 220);
  static const Duration _bulkDebounce = Duration(milliseconds: 800);
  // Realtime commits are already serialized by ConversationSyncService. A
  // single frame is enough to coalesce a burst without making the bottom-tab
  // badge wait for the normal reload debounce window.
  static const Duration _realtimeDebounce = Duration(milliseconds: 16);

  static const Set<String> _bulkRefreshReasons = <String>{
    'drain_db_only',
    'paced_sync_no_full_reload',
    'dirty_retry',
    'apply_out_of_window',
    // archived_changed：归档后要尽快从底部导航扣掉未读，不用 bulk 长防抖。
  };

  static const String _uiApplyDeferredPrefix = 'ui_apply_deferred_';

  /// Refresh reasons allowed to publish a true `(0,0)` when previous sums
  /// were non-zero. All other reasons defer once via [zeroConfirmReason].
  static const Set<String> _allowZeroRefreshReasons = <String>{
    'zero_confirm',
    // Intentional local clears from ConversationListNotifier.
    'zero_unread',
    'zero_unread_many',
    'zero_unread_many_empty',
  };

  /// Follow-up reason after deferring a surprising all-zero store refresh.
  static const String zeroConfirmReason = 'zero_confirm';

  int _c2cNotifiableUnreadSum = 0;
  int _groupNotifiableUnreadSum = 0;
  Timer? _debounce;
  String? _debounceReason;
  Future<void>? _refreshInFlight;
  bool _refreshDirty = false;
  int _deltaCommitCount = 0;
  int _storeCalibrationCount = 0;
  int _scheduledRefreshCount = 0;
  int _sessionClearGeneration = 0;

  /// R1: zero-confirm 连续 defer 次数上限。超过后强制应用 Store 结果，
  /// 避免新消息到达时 Store 写入延迟导致 defer 循环吞掉非零未读。
  int _zeroConfirmDeferrals = 0;
  static const int _maxZeroConfirmDeferrals = 2;

  int get c2cNotifiableUnreadSum => _c2cNotifiableUnreadSum;

  int get groupNotifiableUnreadSum => _groupNotifiableUnreadSum;

  void _onArchivedChanged() {
    scheduleRefresh(reason: 'archived_changed');
  }

  static bool isBulkRefreshReason(String reason) {
    if (_bulkRefreshReasons.contains(reason)) {
      return true;
    }
    return reason.startsWith(_uiApplyDeferredPrefix);
  }

  static bool isRealtimeRefreshReason(String reason) {
    return reason == 'realtime_commit';
  }

  void scheduleRefresh({String reason = 'manual'}) {
    _scheduledRefreshCount++;
    _debounce?.cancel();
    _debounceReason = reason;
    final delay = isRealtimeRefreshReason(reason)
        ? _realtimeDebounce
        : (isBulkRefreshReason(reason) ? _bulkDebounce : _defaultDebounce);
    final generation = _sessionClearGeneration;
    _debounce = Timer(delay, () {
      _debounce = null;
      if (generation != _sessionClearGeneration) {
        return;
      }
      final r = _debounceReason ?? reason;
      _debounceReason = null;
      unawaited(refreshFromStore(reason: r));
    });
  }

  /// 窗内 apply 增量；不触发全表扫描。
  void applyNotifiableDeltas(List<ConversationUnreadDelta> deltas) {
    if (deltas.isEmpty) {
      return;
    }
    _deltaCommitCount++;
    var c2c = _c2cNotifiableUnreadSum;
    var group = _groupNotifiableUnreadSum;
    var touched = false;
    for (final sample in deltas) {
      if (sample.delta == 0) {
        continue;
      }
      touched = true;
      if (sample.isGroup) {
        group = math.max(0, group + sample.delta);
      } else {
        c2c = math.max(0, c2c + sample.delta);
      }
    }
    if (!touched) {
      return;
    }
    if (c2c == _c2cNotifiableUnreadSum && group == _groupNotifiableUnreadSum) {
      return;
    }
    _c2cNotifiableUnreadSum = c2c;
    _groupNotifiableUnreadSum = group;
    if (kDebugMode) {
      debugPrint(
        'ConversationUnreadAggregate: delta '
        'c2c=$c2c group=$group samples=${deltas.length}',
      );
    }
    notifyListeners();
  }

  /// 编辑态按 scope 全部已读时立即隐藏 Tab 角标；随后仍由本地库刷新校准。
  void clearScopeOptimistically({required bool isGroup}) {
    var changed = false;
    if (isGroup) {
      changed = _groupNotifiableUnreadSum != 0;
      _groupNotifiableUnreadSum = 0;
    } else {
      changed = _c2cNotifiableUnreadSum != 0;
      _c2cNotifiableUnreadSum = 0;
    }
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> refreshFromStore({String reason = 'manual'}) async {
    // An explicit refresh supersedes any queued debounce for the same state.
    // This also prevents a manually confirmed zero from running again after
    // the account boundary or test teardown has already cleared its owner.
    _debounce?.cancel();
    _debounce = null;
    _debounceReason = null;
    if (_refreshInFlight != null) {
      _refreshDirty = true;
      return _refreshInFlight!;
    }
    final generation = _sessionClearGeneration;
    final task = _refreshFromStoreOnce(reason: reason);
    _refreshInFlight = task;
    try {
      await task;
    } finally {
      if (generation == _sessionClearGeneration &&
          identical(_refreshInFlight, task)) {
        _refreshInFlight = null;
        if (_refreshDirty) {
          _refreshDirty = false;
          unawaited(refreshFromStore(reason: 'dirty_retry'));
        }
      }
    }
  }

  /// Same resolution order as [ConversationLocalStore] `_resolveOwner(null)`:
  /// debug override (tests) then login user id.
  String _resolvedOwnerForRefresh() {
    return ConversationLocalStore.instance.resolvedOwnerUserId().trim();
  }

  Future<void> _refreshFromStoreOnce({required String reason}) async {
    final owner = _resolvedOwnerForRefresh();
    if (owner.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'ConversationUnreadAggregate: skip refresh reason=$reason '
          '(empty owner; keep c2c=$_c2cNotifiableUnreadSum '
          'group=$_groupNotifiableUnreadSum)',
        );
      }
      return;
    }
    final identity = SessionIdentityService.instance.capture(
      ownerUserId: owner,
    );
    final clearGeneration = _sessionClearGeneration;
    _storeCalibrationCount++;

    final archivedC2c = archivedConversationC2cIDsNotifier.value;
    final archivedGroup = archivedConversationGroupIDsNotifier.value;
    final excludedUserIds = <String>{
      ...PlatformOfficialAccountService.officialAccountIds.where(
        PlatformOfficialAccountService.shouldHideInConversationList,
      ),
    };
    final sums =
        await ConversationLocalStore.instance.sumNotifiableUnreadByScope(
      archivedC2c: archivedC2c,
      archivedGroup: archivedGroup,
      excludedUserIds: excludedUserIds,
      ownerUserId: owner,
    );
    if (clearGeneration != _sessionClearGeneration ||
        !SessionIdentityService.instance.isCurrent(
          identity,
          currentOwnerUserId: _resolvedOwnerForRefresh(),
        )) {
      return;
    }

    final goingToAllZero = sums.c2c == 0 && sums.group == 0;
    final hadUnread =
        _c2cNotifiableUnreadSum > 0 || _groupNotifiableUnreadSum > 0;
    if (goingToAllZero &&
        hadUnread &&
        !_allowZeroRefreshReasons.contains(reason)) {
      // R1: 连续 defer 超过上限后强制清零。避免 Store 写入延迟时
      // 新消息的 scheduleRefresh 反复取消 zero_confirm debounce，
      // 导致聚合永远不更新（Tab 角标不显示但会话行有红点）。
      if (_zeroConfirmDeferrals >= _maxZeroConfirmDeferrals) {
        _zeroConfirmDeferrals = 0;
        if (kDebugMode) {
          debugPrint(
            'ConversationUnreadAggregate: force apply zero after '
            '$_maxZeroConfirmDeferrals deferrals',
          );
        }
      } else {
        _zeroConfirmDeferrals++;
        if (kDebugMode) {
          debugPrint(
            'ConversationUnreadAggregate: defer zero refresh reason=$reason '
            'attempt=$_zeroConfirmDeferrals '
            '(had c2c=$_c2cNotifiableUnreadSum '
            'group=$_groupNotifiableUnreadSum)',
          );
        }
        scheduleRefresh(reason: zeroConfirmReason);
        return;
      }
    } else {
      // 非零结果或确认清零成功——重置计数器。
      _zeroConfirmDeferrals = 0;
    }

    if (sums.c2c == _c2cNotifiableUnreadSum &&
        sums.group == _groupNotifiableUnreadSum) {
      return;
    }
    // R2: Store 全量校准可能因写入延迟返回旧值（比增量 delta 更低）。
    // 非显式清零 reason 下，Store 返回值不得低于当前聚合值——
    // 避免 applyNotifiableDeltas 已经正确 +1 但 Store 查询返回 0 覆盖回 0。
    // 显式清零 reason（zero_unread / zero_confirm / zero_unread_many）允许下降到 0。
    final allowDecrease = _allowZeroRefreshReasons.contains(reason) ||
        reason == zeroConfirmReason;
    final effectiveC2c =
        allowDecrease ? sums.c2c : math.max(sums.c2c, _c2cNotifiableUnreadSum);
    final effectiveGroup = allowDecrease
        ? sums.group
        : math.max(sums.group, _groupNotifiableUnreadSum);
    _c2cNotifiableUnreadSum = effectiveC2c;
    _groupNotifiableUnreadSum = effectiveGroup;
    if (kDebugMode) {
      debugPrint(
        'ConversationUnreadAggregate: refresh reason=$reason '
        'c2c=$effectiveC2c group=$effectiveGroup '
        '(store c2c=${sums.c2c} group=${sums.group} allowDec=$allowDecrease)',
      );
    }
    notifyListeners();
  }

  @visibleForTesting
  void setSumsForTest({required int c2c, required int group}) {
    _c2cNotifiableUnreadSum = c2c;
    _groupNotifiableUnreadSum = group;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _debounce?.cancel();
    _debounce = null;
    _debounceReason = null;
    _refreshInFlight = null;
    _refreshDirty = false;
    _zeroConfirmDeferrals = 0;
    _c2cNotifiableUnreadSum = 0;
    _groupNotifiableUnreadSum = 0;
    _deltaCommitCount = 0;
    _storeCalibrationCount = 0;
    _scheduledRefreshCount = 0;
    _sessionClearGeneration++;
  }

  @visibleForTesting
  int get deltaCommitCountForTest => _deltaCommitCount;

  @visibleForTesting
  int get storeCalibrationCountForTest => _storeCalibrationCount;

  @visibleForTesting
  int get scheduledRefreshCountForTest => _scheduledRefreshCount;

  @visibleForTesting
  Duration debounceForReasonForTest(String reason) {
    if (isRealtimeRefreshReason(reason)) {
      return _realtimeDebounce;
    }
    return isBulkRefreshReason(reason) ? _bulkDebounce : _defaultDebounce;
  }

  void clearSession() {
    _sessionClearGeneration++;
    _debounce?.cancel();
    _debounce = null;
    _debounceReason = null;
    _refreshInFlight = null;
    _refreshDirty = false;
    _zeroConfirmDeferrals = 0;
    if (_c2cNotifiableUnreadSum == 0 && _groupNotifiableUnreadSum == 0) {
      return;
    }
    _c2cNotifiableUnreadSum = 0;
    _groupNotifiableUnreadSum = 0;
    notifyListeners();
  }
}
