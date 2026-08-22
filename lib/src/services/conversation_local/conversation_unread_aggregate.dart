import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
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

  void scheduleRefresh({String reason = 'manual'}) {
    _debounce?.cancel();
    _debounceReason = reason;
    final delay =
        isBulkRefreshReason(reason) ? _bulkDebounce : _defaultDebounce;
    _debounce = Timer(delay, () {
      _debounce = null;
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
    if (c2c == _c2cNotifiableUnreadSum &&
        group == _groupNotifiableUnreadSum) {
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

  Future<void> refreshFromStore({String reason = 'manual'}) async {
    if (_refreshInFlight != null) {
      _refreshDirty = true;
      return _refreshInFlight!;
    }
    final task = _refreshFromStoreOnce(reason: reason);
    _refreshInFlight = task;
    try {
      await task;
    } finally {
      _refreshInFlight = null;
      if (_refreshDirty) {
        _refreshDirty = false;
        unawaited(refreshFromStore(reason: 'dirty_retry'));
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
    );

    final goingToAllZero = sums.c2c == 0 && sums.group == 0;
    final hadUnread =
        _c2cNotifiableUnreadSum > 0 || _groupNotifiableUnreadSum > 0;
    if (goingToAllZero &&
        hadUnread &&
        !_allowZeroRefreshReasons.contains(reason)) {
      if (kDebugMode) {
        debugPrint(
          'ConversationUnreadAggregate: defer zero refresh reason=$reason '
          '(had c2c=$_c2cNotifiableUnreadSum '
          'group=$_groupNotifiableUnreadSum)',
        );
      }
      scheduleRefresh(reason: zeroConfirmReason);
      return;
    }

    if (sums.c2c == _c2cNotifiableUnreadSum &&
        sums.group == _groupNotifiableUnreadSum) {
      return;
    }
    _c2cNotifiableUnreadSum = sums.c2c;
    _groupNotifiableUnreadSum = sums.group;
    if (kDebugMode) {
      debugPrint(
        'ConversationUnreadAggregate: refresh reason=$reason '
        'c2c=${sums.c2c} group=${sums.group}',
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
    _c2cNotifiableUnreadSum = 0;
    _groupNotifiableUnreadSum = 0;
  }

  @visibleForTesting
  Duration debounceForReasonForTest(String reason) {
    return isBulkRefreshReason(reason) ? _bulkDebounce : _defaultDebounce;
  }

  void clearSession() {
    _debounce?.cancel();
    _debounce = null;
    _debounceReason = null;
    _refreshInFlight = null;
    _refreshDirty = false;
    if (_c2cNotifiableUnreadSum == 0 && _groupNotifiableUnreadSum == 0) {
      return;
    }
    _c2cNotifiableUnreadSum = 0;
    _groupNotifiableUnreadSum = 0;
    notifyListeners();
  }
}
