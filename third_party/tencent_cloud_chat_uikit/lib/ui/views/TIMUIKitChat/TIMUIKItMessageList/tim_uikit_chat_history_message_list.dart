import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_at_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_at_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/visible_sender_profile_refresh.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_message_window_policy.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
// ignore: unused_import
import 'package:tencent_cloud_chat_uikit/ui/utils/optimize_utils.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_config.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_chat_config.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_message_enter_animation.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_message_row_reveal.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_message_input_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/keepalive_wrapper.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_jitter_diag.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_resource_sample.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_geom_settle_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_open_layout_ready.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_inbound_scroll_follow.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/chat_list_pagination_ui_gate.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/chat_list_viewport_insert_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/chat_list_route_scroll_restore.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/chat_page_ui_notifiers.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_height_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_scroll_physics.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/at_me_jump.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/first_unread_jump.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/search_jump_latest_gate.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_open_perf_log.dart';

import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'TIMUIKitTongue/tim_uikit_chat_history_message_list_tongue.dart';
import 'TIMUIKitTongue/unread_tongue_policy.dart';
import 'TIMUIKitTongue/tim_uikit_chat_history_message_list_tongue_container.dart';

enum LoadingPlace {
  none,
  top,
  bottom,
}

enum ScrollType { toIndex, toIndexBegin }

class TIMUIKitHistoryMessageListController extends ChangeNotifier {
  AutoScrollController? scrollController = AutoScrollController();
  late ScrollType scrollType;
  late V2TimMessage targetMessage;

  TIMUIKitHistoryMessageListController({
    AutoScrollController? scrollController,
  }) {
    if (scrollController != null) {
      this.scrollController = scrollController;
    }
  }

  scrollToIndex(V2TimMessage message) {
    scrollType = ScrollType.toIndex;
    targetMessage = message;
    notifyListeners();
  }

  scrollToIndexBegin(V2TimMessage message) {
    scrollType = ScrollType.toIndexBegin;
    targetMessage = message;
    notifyListeners();
  }
}

class TIMUIKitHistoryMessageList extends StatefulWidget {
  /// message list
  final List<V2TimMessage?> messageList;

  /// tongue item builder
  final TongueItemBuilder? tongueItemBuilder;

  /// group at info, it can get from conversation info
  final List<V2TimGroupAtInfo?>? groupAtInfoList;

  /// use for build message item
  final Widget Function(BuildContext, V2TimMessage?)? itemBuilder;

  /// can controll message list scroll
  final TIMUIKitHistoryMessageListController? controller;

  /// use for message jump, if passed will jump to target message.
  final V2TimMessage? initFindingMsg;
  final MessageAnchor? searchJumpAnchor;

  /// use for load more message
  final Future<bool> Function(String?, LoadDirection direction, [int?, int?])
      onLoadMore;

  /// configuration for list view
  final TIMUIKitHistoryMessageListConfig? mainHistoryListConfig;

  final TUIChatSeparateViewModel model;

  final bool isAllowScroll;

  final V2TimConversation conversation;

  const TIMUIKitHistoryMessageList(
      {Key? key,
      required this.model,
      required this.messageList,
      this.itemBuilder,
      this.controller,
      required this.onLoadMore,
      this.tongueItemBuilder,
      this.groupAtInfoList,
      this.initFindingMsg,
      this.searchJumpAnchor,
      this.isAllowScroll = true,
      this.mainHistoryListConfig,
      required this.conversation})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _TIMUIKitHistoryMessageListState();
}

class _TIMUIKitHistoryMessageListState
    extends TIMUIKitState<TIMUIKitHistoryMessageList>
    with TickerProviderStateMixin {
  V2TimMessage? findingMsg;
  MessageAnchor? findingAnchor;
  String findingSeq = "";
  late TIMUIKitHistoryMessageListController _controller;
  late AutoScrollController _autoScrollController;
  final GlobalKey _unreadCenterKey = GlobalKey();
  LoadingPlace loadingPlace = LoadingPlace.none;
  bool maybeHaveMoreMessageForFind = true;
  bool _scrollToFindInFlight = false;
  bool _pendingScrollToFind = false;
  int _findingRetryCount = 0;
  final ChatListPaginationUiGate _paginationUi = ChatListPaginationUiGate();
  final ChatListViewportInsertController _viewportInsert =
      ChatListViewportInsertController();
  final ChatListRouteScrollRestore _routeScroll = ChatListRouteScrollRestore();
  final ChatPageUiNotifiers _pageUi = ChatPageUiNotifiers();

  // debounce 触发时读取的最新锚点。顶部回弹会持续产生滚动事件，
  // 若每次都重置计时器会把 debounce 无限饿死；改为"已有计时器在跑就不重置、
  // 只更新锚点"，保证一定能在 120ms 后触发一次加载。
  _PreviousLoadAnchor? _pendingLoadPreviousAnchor;
  bool _userScrollGestureActive = false;
  Timer? _postScrollInboundFlushTimer;
  Timer? _unreadTongueMetricsThrottleTimer;
  static const int _postScrollInboundFlushDelayMs = 160;
  static const int _scrollingUnreadTongueMetricsThrottleMs = 80;
  static const _loadLatestCooldownMs =
      ChatListPaginationUiGate.loadLatestCooldownMs;
  static const _loadPreviousDebounceMs =
      ChatListPaginationUiGate.loadPreviousDebounceMs;
  static const _loadPreviousCooldownMs =
      ChatListPaginationUiGate.loadPreviousCooldownMs;
  static const _historyScrollProtectMs =
      ChatListPaginationUiGate.historyScrollProtectMs;
  static const _loadPreviousScrollUnlockMs =
      ChatListPaginationUiGate.loadPreviousScrollUnlockMs;
  static const _scrollPaginationCompensationMs =
      ChatListPaginationUiGate.scrollPaginationCompensationMs;
  static const _incomingWhileReadingCompensationMs =
      ChatListPaginationUiGate.incomingWhileReadingCompensationMs;
  static const _readingHistoryThresholdPx =
      ChatListPaginationUiGate.readingHistoryThresholdPx;
  static const _loadPreviousTopReachResetPx =
      ChatListPaginationUiGate.loadPreviousTopReachResetPx;
  static const _loadPreviousTopNearPx =
      ChatListPaginationUiGate.loadPreviousTopNearPx;
  static const _loadPreviousOverscrollTolerancePx =
      ChatListPaginationUiGate.loadPreviousOverscrollTolerancePx;
  static const _minTopHistoryLoadingVisibleMs =
      ChatListPaginationUiGate.minTopHistoryLoadingVisibleMs;
  static const double _continuousViewportPushBasePixelsPerSecond =
      ChatListViewportInsertController
          .continuousViewportPushBasePixelsPerSecond;
  static const double _continuousViewportPushMaxPixelsPerSecond =
      ChatListViewportInsertController.continuousViewportPushMaxPixelsPerSecond;
  static const int _continuousViewportPushSpeedRampRows =
      ChatListViewportInsertController.continuousViewportPushSpeedRampRows;
  static const int _continuousViewportPushMeasureMaxAttempts =
      ChatListViewportInsertController.continuousViewportPushMeasureMaxAttempts;
  static const int _continuousViewportPushInitialLayoutSuppressMs =
      ChatListViewportInsertController
          .continuousViewportPushInitialLayoutSuppressMs;
  static const _viewportInsertSettleMs =
      ChatListViewportInsertController.viewportInsertSettleMs;
  static const _mediaSettleMs = ChatListViewportInsertController.mediaSettleMs;
  static const double _shortHistoryMessageEstimatedRowHeight =
      ChatListRouteScrollRestore.shortHistoryMessageEstimatedRowHeight;
  static const double _shortHistoryGroupTipsEstimatedRowHeight =
      ChatListRouteScrollRestore.shortHistoryGroupTipsEstimatedRowHeight;
  static const double _shortHistoryTimeDividerEstimatedRowHeight =
      ChatListRouteScrollRestore.shortHistoryTimeDividerEstimatedRowHeight;
  static const double _shortHistoryAlignmentHysteresis =
      ChatListRouteScrollRestore.shortHistoryAlignmentHysteresis;
  static const double _shortHistorySpacerRebuildTolerancePx =
      ChatListRouteScrollRestore.shortHistorySpacerRebuildTolerancePx;
  TUIChatGlobalModel? _chatGlobalModel;
  List<V2TimMessage?> _cachedUnreadList = [];
  List<V2TimMessage?> _cachedReadList = [];
  int _cacheUnreadCount = -1;
  int _cacheMessageListLen = -1;
  int _cacheUnreadEndPoint = -1;
  int _cacheMessageListRevision = -1;
  int _cacheRestoreVersion = -1;
  String? _cacheLastMsgKey;
  String? _cacheHeadMsgKey;
  String? _cacheListStateKey;
  Map<String, int> _unreadIndexMap = {};
  Map<String, int> _readIndexMap = {};
  Map<String, int> _globalIndexMap = {};
  Map<String, int> _globalMessageIdentityIndexMap = {};
  bool _deferUnreadCenterPartition = false;
  int _lastDiagLayoutSafeUnread = -1;
  int _lastDiagLayoutUnread = -1;
  double? _incomingScrollAnchorPixels;
  int _incomingScrollAnchorGeneration = 0;
  int _searchJumpStabilizeUntilMs = 0;
  int _searchJumpGeneration = 0;
  String? _initialUnreadAnchorConversationID;
  int _initialUnreadAnchorCount = 0;
  int _initialUnreadAnchorAttempts = 0;
  bool _initialUnreadAnchorScheduled = false;
  bool _initialUnreadAnchorInFlight = false;
  int _completedEntryUnreadCount = 0;
  _UnreadMessageAnchor? _firstUnreadAnchor;
  bool _firstUnreadAnchorJumped = false;
  bool _unreadTongueMetricsScheduled = false;
  List<V2TimMessage?>? _pendingUnreadTongueMetricsList;
  int _pendingUnreadTongueMetricsSafeCount = 0;
  int _lastUnreadTongueMetricsRunAtMs = 0;
  String? _lastUnreadTongueConversationID;
  int? _lastUnreadTongueRemaining;
  int _lastUnreadTongueSafeCount = 0;
  bool _unreadEntryBottomPinScheduled = false;
  TUIChatSeparateViewModel? _boundSeparateModel;
  int _lastHandledPinSeq = 0;
  int _lastHandledScrollFollowSeq = 0;
  int _lastInboundPresentationSupersedeSeq = 0;
  int _forcePinGeneration = 0;

  /// CVP 量高失败兜底：跳过 list-push / 媒体稳定 / settle 等待，立刻贴底。
  bool _forcePinIgnoreInsertWindows = false;
  InboundScrollFollow? _inboundScrollFollow;
  late final int _createdAtMs;

  /// 进页揭示门：未 ready 时透明，避免贴底首帧再抬升。
  bool _historyOpenRevealReady = false;

  /// 一旦对用户亮过首屏，epoch 重置也不得再 Opacity=0，否则会「先出记录再闪一下」。
  bool _historyOpenRevealPainted = false;
  bool _compactHistoryCacheExtent = false;
  int _historyOpenRevealPostFrameCount = 0;
  int? _historyOpenRevealDeadlineMs;
  bool _historyOpenRevealWaitScheduled = false;
  bool _historyOpenRevealStarveLogged = false;

  /// 短历史：测前 starve 日志上限；长历史：2帧/120ms。
  int _historyOpenRevealMaxPostFrames = 2;
  int _historyOpenRevealTimeoutMs = 120;

  /// 短历史测后稳定窗。
  int _historyOpenRevealStableFrames = 0;
  int? _historyOpenRevealMeasuredAtMs;
  int _historyOpenRevealFramesSinceMeasured = 0;
  double? _historyOpenRevealLastSpacer;
  double? _historyOpenRevealLastContentH;
  bool _historyOpenRevealRowBumpPending = false;
  int? _historyOpenRevealReadyAtMs;
  int _historyOpenRevealHoldFrames = 0;
  int? _historyOpenRevealLastListLen;
  int? _historyOpenRevealLastListRev;
  int _layoutReadyEpochSigned = -1;
  int _layoutReadyEpochSeen = 0;

  /// 长历史 maxExtent 稳定采样。
  int _historyOpenRevealLongStableFrames = 0;
  double? _historyOpenRevealLastMaxExtent;
  int? _historyOpenRevealLongArmAtMs;

  /// 软超时遇上 loadPrevious 在飞时，最多再等这么久。
  int? _historyOpenRevealLongLoadWaitDeadlineMs;

  /// reveal 后因异步历史写回清过 latch / 装不下时：禁止再 `spacer_prime`。
  bool _blockShortSpacerReprimeAfterReveal = false;

  @override
  void initState() {
    super.initState();
    _createdAtMs = DateTime.now().millisecondsSinceEpoch;
    ChatJitterDiag.logWidgetLifecycle(
      widget: 'HistoryMessageList',
      phase: 'initState',
      stateHash: identityHashCode(this),
      conv: widget.model.conversationID,
      keyDebug: widget.key?.toString(),
    );
    ChatGeomSettleTrace.begin(
      conversationID: widget.model.conversationID,
      openSeq: ChatJitterDiag.openSeq,
      capture: _captureGeomSettleSnapshot,
    );
    final convId = widget.model.conversationID;
    final globalModel = widget.model.globalModel;
    // Page UI is SSOT for open-chat scroll flags; GlobalModel mirrors via attach.
    globalModel.attachOpenChatPageUi(
      conversationId: convId,
      historyPosition: _pageUi.historyPosition,
      userScrolling: _pageUi.userScrolling,
    );
    globalModel.setChatListUserScrolling(false);
    // 本地已有消息时进页立刻补种行高（会话列表预载可能未跑到）。
    ChatMessageHeightCache.instance.seedEstimatesForMessages(
      globalModel.getMessageList(convId) ?? const <V2TimMessage>[],
    );
    _routeScroll.openedWithCachedHistory =
        globalModel.rawMessageCount(convId) > 0;
    if (_routeScroll.openedWithCachedHistory &&
        globalModel.hasInitialHistoryLoaded(convId)) {
      _routeScroll.wasInitialHistoryBootstrapping = false;
    }
    if (!ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled) {
      _routeScroll.clearShortHistoryAlignmentLatch();
      ChatGeomSettleTrace.noteReason(
        'short_history_top_align_disabled',
        extras: <String, Object?>{
          'openedWithCachedHistory': _routeScroll.openedWithCachedHistory,
          'rawCount': globalModel.rawMessageCount(convId),
        },
      );
      ChatOpenPerfLog.mark(
        'short_history_top_align_disabled',
        conversationID: convId,
        extras: <String, Object?>{
          'openedWithCachedHistory': _routeScroll.openedWithCachedHistory,
        },
      );
    }
    // 暖窗：仅完整首屏立刻 ready。列表预热的几条消息若先亮，会贴底留白。
    // miss 时走短历史测高/稳定窗（见 _evaluateHistoryOpenReveal）。
    // 贴底模式：不依赖 short contentH 缓存，有完整暖窗即可 ready。
    if (_routeScroll.openedWithCachedHistory) {
      if (!ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled) {
        if (_isCompleteCachedOpenWindow(globalModel)) {
          _commitHistoryOpenRevealReady(
            source: 'opened_with_cache_bottom_align',
            bridgeSignal: false,
          );
        }
      } else {
        final cached =
            globalModel.getMessageList(convId) ?? const <V2TimMessage>[];
        final signature = TUIChatGlobalModel.historyIdentitySignature(cached);
        final lastMeasured =
            ChatMessageHeightCache.instance.measuredContentHeightFor(
          conversationID: convId,
          identitySignature: signature,
        );
        if (lastMeasured != null && lastMeasured > 0) {
          _commitHistoryOpenRevealReady(
            source: 'opened_with_cache',
            bridgeSignal: false,
          );
        } else {
          ChatGeomSettleTrace.noteReason(
            'warm_open_reveal_deferred_no_measured_content_h',
            extras: <String, Object?>{
              'len': cached.length,
            },
          );
        }
      }
    }
    _controller = widget.controller ?? TIMUIKitHistoryMessageListController();
    _autoScrollController =
        _controller.scrollController ?? AutoScrollController();
    _viewportInsert.rowRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _viewportInsert.rowRevealAnimation = CurvedAnimation(
      parent: _viewportInsert.rowRevealController!,
      curve: Curves.easeOutCubic,
    );
    _viewportInsert.rowRevealController!.addStatusListener((status) {
      if (_viewportInsert.suppressRowRevealStatus) {
        return;
      }
      if (status == AnimationStatus.completed) {
        _pinScrollToBottomImmediate();
        _completeRowRevealTransaction();
      }
    });
    _controller.addListener(_controllerListener);
    initFinding();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bindActiveScrollController();
      _onGlobalRouteRestoreChanged();
      if (!_mayUseShortHistoryTopAlignment()) {
        _releaseShortHistoryAlignmentAndPinBottom();
      }
    });
    _bindSeparateModelListener();
    _scheduleChatOpenPerfProbe(reason: 'initState');
    ChatHistoryOpenLayoutReady.epochRevision
        .addListener(_onLayoutReadyEpochRevision);
  }

  void _onLayoutReadyEpochRevision() {
    if (!mounted) {
      return;
    }
    _syncHistoryOpenRevealEpochOrReset();
  }

  void _scheduleChatOpenPerfProbe({required String reason}) {
    final convId = _conversationId();
    final count = widget.messageList.length;
    final globalModel = widget.model.globalModel;
    final initialLoaded = globalModel.hasInitialHistoryLoaded(convId);
    // 列表即将/正在挂图片气泡：同步开短暂 decode defer，覆盖首帧尖刺。
    if (count > 0) {
      globalModel.beginChatOpenImageDecodeDefer();
    }
    ChatOpenPerfLog.markHistoryListBuilt(
      conversationID: convId,
      messageCount: count,
      initialLoaded: initialLoaded,
      bootstrapping: !initialLoaded,
    );
    if (count <= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final painted = widget.messageList.length;
      if (painted <= 0) {
        return;
      }
      ChatOpenPerfLog.markMessagesFirstVisible(
        conversationID: _conversationId(),
        messageCount: painted,
        source: reason,
      );
      // Geom 的 visible 门对齐用户真正看见的揭示帧，避免 Opacity=0 阶段误结算。
      if (_historyOpenRevealReady) {
        ChatGeomSettleTrace.markMessagesVisible(
          conversationID: _conversationId(),
          messageCount: painted,
          source: reason,
        );
      }
    });
  }

  void _resetHistoryOpenRevealGate({bool resetPainted = true}) {
    _historyOpenRevealReady = false;
    if (resetPainted) {
      _historyOpenRevealPainted = false;
    }
    _historyOpenRevealPostFrameCount = 0;
    _historyOpenRevealDeadlineMs = null;
    _historyOpenRevealWaitScheduled = false;
    _historyOpenRevealStarveLogged = false;
    _historyOpenRevealMaxPostFrames = 2;
    _historyOpenRevealTimeoutMs = 120;
    _historyOpenRevealStableFrames = 0;
    _historyOpenRevealMeasuredAtMs = null;
    _historyOpenRevealFramesSinceMeasured = 0;
    _historyOpenRevealLastSpacer = null;
    _historyOpenRevealLastContentH = null;
    _historyOpenRevealRowBumpPending = false;
    _historyOpenRevealReadyAtMs = null;
    _historyOpenRevealHoldFrames = 0;
    _historyOpenRevealLastListLen = null;
    _historyOpenRevealLastListRev = null;
    _layoutReadyEpochSigned = -1;
    _layoutReadyEpochSeen = 0;
    _historyOpenRevealLongStableFrames = 0;
    _historyOpenRevealLastMaxExtent = null;
    _historyOpenRevealLongArmAtMs = null;
    _historyOpenRevealLongLoadWaitDeadlineMs = null;
  }

  /// prepare 后二次 begin 会抬 epoch；作废旧代际 ready / 采样并重跑稳定窗。
  void _syncHistoryOpenRevealEpochOrReset() {
    final epoch = ChatHistoryOpenLayoutReady.epochOf(_conversationId());
    if (epoch == 0 || epoch == _layoutReadyEpochSeen) {
      return;
    }
    final hadSigned =
        _layoutReadyEpochSigned >= 0 && _layoutReadyEpochSigned != epoch;
    final softResettle = !hadSigned &&
        (_historyOpenRevealReady ||
            _historyOpenRevealStableFrames > 0 ||
            _historyOpenRevealHoldFrames > 0 ||
            _historyOpenRevealMeasuredAtMs != null ||
            _historyOpenRevealLongArmAtMs != null);
    if (!hadSigned && !softResettle) {
      _layoutReadyEpochSeen = epoch;
      return;
    }
    ChatGeomSettleTrace.noteReason(
      'layout_ready_epoch_reset',
      extras: <String, Object?>{
        'signed': _layoutReadyEpochSigned,
        'seen': _layoutReadyEpochSeen,
        'current': epoch,
        'wasReady': _historyOpenRevealReady,
        'soft': softResettle && !hadSigned,
      },
    );
    _resetHistoryOpenRevealGate(resetPainted: false);
    _layoutReadyEpochSeen = epoch;
    if (!mounted) {
      return;
    }
    final shortCandidate =
        ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled &&
            (_routeScroll.shortHistoryAlignmentLatched ||
                _routeScroll.shortHistoryBottomSpacerHeight > 1 ||
                _mayUseShortHistoryTopAlignment());
    _scheduleHistoryOpenRevealWait(shortHistory: shortCandidate);
  }

  bool _historyOpenRevealWaitExpired() {
    if (_historyOpenRevealPostFrameCount >= _historyOpenRevealMaxPostFrames) {
      return true;
    }
    final deadline = _historyOpenRevealDeadlineMs;
    if (deadline == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch >= deadline;
  }

  bool get _isPostRevealMicroSuppressWindow {
    if (!_historyOpenRevealReady) {
      return false;
    }
    final readyAt = _historyOpenRevealReadyAtMs;
    if (readyAt == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch - readyAt < 500;
  }

  int _msSinceHistoryOpenRevealReady() {
    final readyAt = _historyOpenRevealReadyAtMs;
    if (readyAt == null) {
      return 0;
    }
    return DateTime.now().millisecondsSinceEpoch - readyAt;
  }

  void _commitHistoryOpenRevealReady({
    required String source,
    bool bridgeSignal = true,
  }) {
    if (_historyOpenRevealReady) {
      _historyOpenRevealPainted = true;
      return;
    }
    final epoch = ChatHistoryOpenLayoutReady.epochOf(_conversationId());
    _historyOpenRevealReady = true;
    // Jump while Opacity is still 0 so the first painted frame is already at
    // the latest edge — otherwise smooth pin after reveal looks like content
    // floating up from the bottom.
    _pinScrollToBottomImmediate();
    _historyOpenRevealPainted = true;
    _historyOpenRevealReadyAtMs = DateTime.now().millisecondsSinceEpoch;
    final isLongPath = source.startsWith('long_');
    ChatGeomSettleTrace.noteReason(
      'history_open_reveal_ready',
      extras: <String, Object?>{
        'source': source,
        'postFrames': _historyOpenRevealPostFrameCount,
        if (isLongPath) ...<String, Object?>{
          'longStableFrames': _historyOpenRevealLongStableFrames,
          'lastMaxExtent': _historyOpenRevealLastMaxExtent,
        } else ...<String, Object?>{
          'stableFrames': _historyOpenRevealStableFrames,
          'holdFrames': _historyOpenRevealHoldFrames,
          'framesSinceMeasured': _historyOpenRevealFramesSinceMeasured,
          'measured': _routeScroll.shortHistoryContentHeightMeasured,
          'latched': _routeScroll.shortHistoryAlignmentLatched,
        },
        'openedWithCachedHistory': _routeScroll.openedWithCachedHistory,
        'epoch': epoch,
        'bridgeSignal': bridgeSignal,
      },
    );
    if (bridgeSignal) {
      _layoutReadyEpochSigned = epoch;
      ChatHistoryOpenLayoutReady.signal(
        _conversationId(),
        epoch: epoch,
      );
    }
    final painted = widget.messageList.length;
    if (painted > 0) {
      ChatGeomSettleTrace.markMessagesVisible(
        conversationID: _conversationId(),
        messageCount: painted,
        source: 'history_open_reveal_$source',
      );
    }
  }

  void _armHistoryOpenRevealWaitBudget({required bool shortHistory}) {
    if (shortHistory) {
      // 仅用于「测前」starve 诊断，绝不据此强制 reveal。
      _historyOpenRevealMaxPostFrames = 45;
      _historyOpenRevealTimeoutMs = 1500;
    } else {
      // 长历史：maxExtent 稳定 / 400ms 软超时，不再用 2 帧骗开整页。
      _historyOpenRevealMaxPostFrames = 48;
      _historyOpenRevealTimeoutMs = 400;
    }
    _historyOpenRevealDeadlineMs ??=
        DateTime.now().millisecondsSinceEpoch + _historyOpenRevealTimeoutMs;
  }

  void _noteShortHistoryRevealMeasureStarve() {
    if (_historyOpenRevealStarveLogged) {
      return;
    }
    _historyOpenRevealStarveLogged = true;
    ChatGeomSettleTrace.noteReason(
      'short_reveal_measure_starve',
      extras: <String, Object?>{
        'postFrames': _historyOpenRevealPostFrameCount,
        'measured': _routeScroll.shortHistoryContentHeightMeasured,
        'latched': _routeScroll.shortHistoryAlignmentLatched,
        'spacer':
            _routeScroll.shortHistoryBottomSpacerHeight.toStringAsFixed(1),
        'contentH': _routeScroll.shortHistoryContentHeight.toStringAsFixed(1),
      },
    );
  }

  void _onShortHistoryFirstMeasured() {
    _historyOpenRevealMeasuredAtMs ??= DateTime.now().millisecondsSinceEpoch;
    _historyOpenRevealStableFrames = 0;
    _historyOpenRevealHoldFrames = 0;
    _historyOpenRevealFramesSinceMeasured = 0;
    _historyOpenRevealLastSpacer = null;
    _historyOpenRevealLastContentH = null;
    _historyOpenRevealLastListLen = null;
    _historyOpenRevealLastListRev = null;
    _historyOpenRevealRowBumpPending = false;
    _scheduleHistoryOpenRevealWait(shortHistory: true);
  }

  void _noteShortHistoryRowHeightBumpForReveal(double delta) {
    if (_historyOpenRevealReady || delta.abs() < 8) {
      return;
    }
    _historyOpenRevealRowBumpPending = true;
    _historyOpenRevealStableFrames = 0;
    _historyOpenRevealHoldFrames = 0;
  }

  void _noteShortHistoryListIdentityForReveal() {
    if (_historyOpenRevealReady) {
      return;
    }
    final len = widget.messageList.length;
    final rev =
        widget.model.globalModel.messageListRevisionFor(_conversationId());
    final lenChanged = _historyOpenRevealLastListLen != null &&
        _historyOpenRevealLastListLen != len;
    final revChanged = _historyOpenRevealLastListRev != null &&
        _historyOpenRevealLastListRev != rev;
    if (lenChanged || revChanged) {
      _historyOpenRevealStableFrames = 0;
      _historyOpenRevealHoldFrames = 0;
      _historyOpenRevealLastSpacer = null;
      _historyOpenRevealLastContentH = null;
    }
    _historyOpenRevealLastListLen = len;
    _historyOpenRevealLastListRev = rev;
  }

  bool _tickShortHistoryRevealStableWindow() {
    _noteShortHistoryListIdentityForReveal();
    final spacer = _routeScroll.shortHistoryBottomSpacerHeight;
    final contentH = _routeScroll.shortHistoryContentHeight;
    if (_historyOpenRevealRowBumpPending) {
      _historyOpenRevealStableFrames = 0;
      _historyOpenRevealHoldFrames = 0;
      _historyOpenRevealRowBumpPending = false;
    } else if (_historyOpenRevealLastSpacer != null &&
        _historyOpenRevealLastContentH != null) {
      final dSpacer = (spacer - _historyOpenRevealLastSpacer!).abs();
      final dContentH = (contentH - _historyOpenRevealLastContentH!).abs();
      if (dSpacer > 1 || dContentH > 1) {
        _historyOpenRevealStableFrames = 0;
        _historyOpenRevealHoldFrames = 0;
      } else {
        _historyOpenRevealStableFrames++;
      }
    } else {
      _historyOpenRevealStableFrames = 0;
      _historyOpenRevealHoldFrames = 0;
    }
    _historyOpenRevealLastSpacer = spacer;
    _historyOpenRevealLastContentH = contentH;
    return _historyOpenRevealStableFrames >= 2;
  }

  bool _shortHistoryRevealStableTimedOut() {
    final measuredAt = _historyOpenRevealMeasuredAtMs;
    if (measuredAt == null) {
      return false;
    }
    if (_historyOpenRevealFramesSinceMeasured >= 8) {
      return true;
    }
    return DateTime.now().millisecondsSinceEpoch - measuredAt >= 250;
  }

  bool _isHistoryOpenPreviousLoadInFlight() {
    return _paginationUi.isLoadingPrevious ||
        _paginationUi.loadPreviousTask != null;
  }

  void _noteLongHistoryListIdentityForReveal() {
    if (_historyOpenRevealReady) {
      return;
    }
    final len = widget.messageList.length;
    final rev =
        widget.model.globalModel.messageListRevisionFor(_conversationId());
    final lenChanged = _historyOpenRevealLastListLen != null &&
        _historyOpenRevealLastListLen != len;
    final revChanged = _historyOpenRevealLastListRev != null &&
        _historyOpenRevealLastListRev != rev;
    if (lenChanged || revChanged) {
      _historyOpenRevealLongStableFrames = 0;
      _historyOpenRevealLastMaxExtent = null;
    }
    _historyOpenRevealLastListLen = len;
    _historyOpenRevealLastListRev = rev;
  }

  bool _tickLongHistoryExtentStableWindow() {
    _noteLongHistoryListIdentityForReveal();
    if (_isHistoryOpenPreviousLoadInFlight()) {
      _historyOpenRevealLongStableFrames = 0;
      _historyOpenRevealLastMaxExtent = null;
      return false;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null || !position.hasContentDimensions) {
      _historyOpenRevealLongStableFrames = 0;
      _historyOpenRevealLastMaxExtent = null;
      return false;
    }
    final maxExtent = position.maxScrollExtent;
    // 贴底短内容：maxExtent≈0 对「已确认的短会话」是正常态。
    // 未灌满的预热窗绝不能据此揭开，否则会先看到底部几条、上半空白。
    if (widget.messageList.isNotEmpty &&
        maxExtent <= 1 &&
        !ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled) {
      if (!_isCompleteCachedOpenWindow(widget.model.globalModel)) {
        _historyOpenRevealLongStableFrames = 0;
        _historyOpenRevealLastMaxExtent = maxExtent;
        return false;
      }
      _historyOpenRevealLastMaxExtent = maxExtent;
      _historyOpenRevealLongStableFrames++;
      return _historyOpenRevealLongStableFrames >= 2;
    }
    // 有消息但尚未形成可滚范围：extent=0 不得冒充稳定。
    if (widget.messageList.isNotEmpty && maxExtent <= 1) {
      _historyOpenRevealLongStableFrames = 0;
      _historyOpenRevealLastMaxExtent = maxExtent;
      return false;
    }
    if (_historyOpenRevealLastMaxExtent != null) {
      final delta = (maxExtent - _historyOpenRevealLastMaxExtent!).abs();
      if (delta > 1) {
        _historyOpenRevealLongStableFrames = 0;
      } else {
        _historyOpenRevealLongStableFrames++;
      }
    } else {
      _historyOpenRevealLongStableFrames = 0;
    }
    _historyOpenRevealLastMaxExtent = maxExtent;
    return _historyOpenRevealLongStableFrames >= 2;
  }

  bool _longHistoryRevealSoftTimedOut() {
    final armedAt = _historyOpenRevealLongArmAtMs;
    if (armedAt == null) {
      return false;
    }
    final elapsed = DateTime.now().millisecondsSinceEpoch - armedAt;
    final position = _singleScrollPositionOrNull();
    final underfilled = position != null &&
        position.hasContentDimensions &&
        position.maxScrollExtent <= 1 &&
        !_isCompleteCachedOpenWindow(widget.model.globalModel);
    return elapsed >= (underfilled ? 1200 : 400);
  }

  bool _longHistoryRevealLoadWaitTimedOut() {
    final deadline = _historyOpenRevealLongLoadWaitDeadlineMs;
    if (deadline == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch >= deadline;
  }

  void _scheduleHistoryOpenRevealWait({required bool shortHistory}) {
    _armHistoryOpenRevealWaitBudget(shortHistory: shortHistory);
    if (_historyOpenRevealWaitScheduled || _historyOpenRevealReady) {
      return;
    }
    _historyOpenRevealWaitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _historyOpenRevealWaitScheduled = false;
      if (!mounted) {
        return;
      }
      _syncHistoryOpenRevealEpochOrReset();
      if (_historyOpenRevealReady) {
        return;
      }
      _historyOpenRevealPostFrameCount++;
      if (shortHistory) {
        // 顶对齐总闸关闭时禁止走 short latch/测高等待，否则会在
        // !latchedOrSpaced / !measured 分支里无限续等，Opacity=0 永久空白。
        if (!ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled) {
          _scheduleHistoryOpenRevealWait(shortHistory: false);
          return;
        }
        final measured = _routeScroll.shortHistoryContentHeightMeasured;
        final latchedOrSpaced = _routeScroll.shortHistoryAlignmentLatched ||
            _routeScroll.shortHistoryBottomSpacerHeight > 1;
        if (!measured) {
          if (_historyOpenRevealWaitExpired()) {
            _noteShortHistoryRevealMeasureStarve();
            // 测高饿死时强制揭开，避免会话页永久透明。
            setState(() {
              _commitHistoryOpenRevealReady(source: 'short_measure_starve');
            });
            return;
          }
          _scheduleHistoryOpenRevealWait(shortHistory: true);
          return;
        }
        if (!latchedOrSpaced) {
          // 已测高但未 latch：改走长历史揭示，禁止空转。
          _scheduleHistoryOpenRevealWait(shortHistory: false);
          return;
        }
        _historyOpenRevealMeasuredAtMs ??=
            DateTime.now().millisecondsSinceEpoch;
        _historyOpenRevealFramesSinceMeasured++;
        final stable = _tickShortHistoryRevealStableWindow();
        if (stable) {
          _historyOpenRevealHoldFrames++;
          if (_historyOpenRevealHoldFrames >= 2) {
            setState(() {
              _commitHistoryOpenRevealReady(source: 'short_stable_hold');
            });
            return;
          }
          _scheduleHistoryOpenRevealWait(shortHistory: true);
          return;
        }
        if (_shortHistoryRevealStableTimedOut()) {
          if (_historyOpenRevealHoldFrames < 1) {
            _historyOpenRevealHoldFrames++;
            _scheduleHistoryOpenRevealWait(shortHistory: true);
            return;
          }
          setState(() {
            _commitHistoryOpenRevealReady(source: 'short_stable_timeout');
          });
          return;
        }
        _scheduleHistoryOpenRevealWait(shortHistory: true);
        return;
      }
      _historyOpenRevealLongArmAtMs ??= DateTime.now().millisecondsSinceEpoch;
      if (_tickLongHistoryExtentStableWindow()) {
        setState(() {
          _commitHistoryOpenRevealReady(source: 'long_extent_stable');
        });
        return;
      }
      if (_longHistoryRevealSoftTimedOut()) {
        if (_isHistoryOpenPreviousLoadInFlight()) {
          _historyOpenRevealLongLoadWaitDeadlineMs ??=
              DateTime.now().millisecondsSinceEpoch + 300;
          if (!_longHistoryRevealLoadWaitTimedOut()) {
            ChatGeomSettleTrace.noteReason(
              'long_stable_timeout_wait_load',
              extras: <String, Object?>{
                'loadingPrevious': _paginationUi.isLoadingPrevious,
                'taskInFlight': _paginationUi.loadPreviousTask != null,
              },
            );
            _scheduleHistoryOpenRevealWait(shortHistory: false);
            return;
          }
        }
        setState(() {
          _commitHistoryOpenRevealReady(source: 'long_stable_timeout');
        });
        return;
      }
      _scheduleHistoryOpenRevealWait(shortHistory: false);
    });
  }

  /// 统一揭示门：短历史测后稳定+hold；长历史 maxExtent 稳定；空会话确认后放行。
  /// 暖窗若已有会话实测 contentH 会在 initState ready；否则仍走本路径。
  bool _evaluateHistoryOpenReveal({
    required List<V2TimMessage?> messageList,
    required double viewportHeight,
  }) {
    _syncHistoryOpenRevealEpochOrReset();
    if (_historyOpenRevealReady) {
      return true;
    }
    if (viewportHeight <= 0) {
      return false;
    }
    if (messageList.isEmpty) {
      final globalModel = widget.model.globalModel;
      if (!_isInitialHistoryBootstrapping(globalModel)) {
        _commitHistoryOpenRevealReady(source: 'empty_history');
        return true;
      }
      return false;
    }

    final shortCandidate =
        ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled &&
            (_routeScroll.shortHistoryAlignmentLatched ||
                _routeScroll.shortHistoryBottomSpacerHeight > 1 ||
                _mayUseShortHistoryTopAlignment());

    if (shortCandidate) {
      if (_routeScroll.shortHistoryContentHeightMeasured &&
          (_routeScroll.shortHistoryAlignmentLatched ||
              _routeScroll.shortHistoryBottomSpacerHeight > 1)) {
        _historyOpenRevealMeasuredAtMs ??=
            DateTime.now().millisecondsSinceEpoch;
      }
      _armHistoryOpenRevealWaitBudget(shortHistory: true);
      if (!_routeScroll.shortHistoryContentHeightMeasured &&
          _historyOpenRevealWaitExpired()) {
        _noteShortHistoryRevealMeasureStarve();
      }
      _scheduleHistoryOpenRevealWait(shortHistory: true);
      return false;
    }

    _armHistoryOpenRevealWaitBudget(shortHistory: false);
    _historyOpenRevealLongArmAtMs ??= DateTime.now().millisecondsSinceEpoch;
    _scheduleHistoryOpenRevealWait(shortHistory: false);
    return false;
  }

  void _bindSeparateModelListener() {
    if (_boundSeparateModel == widget.model) {
      return;
    }
    _boundSeparateModel?.removeListener(_onSeparateModelUpdated);
    _boundSeparateModel = widget.model;
    _lastSeparateListRelevantEpoch = _separateListRelevantEpoch(widget.model);
    _boundSeparateModel?.addListener(_onSeparateModelUpdated);
  }

  /// 仅当「列表本身」相关状态变化时才整表 setState。
  /// selfMemberInfo / groupInfo / 禁言等变更不应在进场时掀翻消息列表。
  int _separateListRelevantEpoch(TUIChatSeparateViewModel model) {
    // 暖窗已在屏上时，进页 settle 内 loading/haveMore 抖动不必掀翻列表；
    // 日志里一次打开可出现十余次 separate_model_set_state。
    final multiSelectRevision =
        model.chatUiStateStore.modeRevision(model.conversationID);
    if (_routeScroll.openedWithCachedHistory && _isInitialRouteSettleWindow) {
      return Object.hash(
        model.jumpMsgID,
        model.isMultiSelect,
        multiSelectRevision,
      );
    }
    return Object.hash(
      model.isLoadingChatHistory,
      model.haveMoreData,
      model.haveMoreLatestData,
      model.jumpMsgID,
      model.isMultiSelect,
      multiSelectRevision,
    );
  }

  int _lastSeparateListRelevantEpoch = -1;

  void _onSeparateModelUpdated() {
    if (!mounted) {
      return;
    }
    final epoch = _separateListRelevantEpoch(widget.model);
    if (epoch == _lastSeparateListRelevantEpoch) {
      ChatJitterDiag.log(
        'separate_model_skip',
        extras: <String, Object?>{
          'reason': 'list_irrelevant',
          'loading': widget.model.isLoadingChatHistory,
        },
      );
      return;
    }
    _lastSeparateListRelevantEpoch = epoch;
    ChatJitterDiag.log(
      'separate_model_set_state',
      extras: <String, Object?>{
        'loading': widget.model.isLoadingChatHistory,
        'haveMore': widget.model.haveMoreData,
        'jump': widget.model.jumpMsgID,
      },
    );
    setState(() {});
  }

  /// 首屏进页阶段的历史加载一律静默：暖窗已出列表时后台 hydrate 不盖转圈，
  /// 空列表也不用全屏 spinner 挡（直接空态等数据）。
  bool _shouldSilenceInitialHistoryLoading(TUIChatGlobalModel globalModel) {
    if (!globalModel.hasInitialHistoryLoaded(_conversationId())) {
      return true;
    }
    // 有暖缓存时进页后 hydrate 仍会短暂 isLoadingChatHistory；
    // 前 2.5s 内不显示居中/全屏转圈，避免「闪一下转圈又没了」。
    if (_routeScroll.openedWithCachedHistory &&
        DateTime.now().millisecondsSinceEpoch - _createdAtMs < 2500) {
      return true;
    }
    return false;
  }

  bool _shouldShowCenterHistoryLoading({
    required bool isLoadingHistory,
    required List<V2TimMessage?> messageList,
    required int effectiveUnreadNewMessageCount,
    required int loadedRealMessageCount,
    required TUIChatGlobalModel globalModel,
  }) {
    if (!isLoadingHistory) {
      return false;
    }
    if (_shouldSilenceInitialHistoryLoading(globalModel)) {
      return false;
    }
    if (messageList.isEmpty) {
      return true;
    }
    return effectiveUnreadNewMessageCount >=
            UnreadTonguePolicy.groupMinUnreadCount &&
        UnreadTonguePolicy.entryUnreadTongueEnabled &&
        loadedRealMessageCount < effectiveUnreadNewMessageCount;
  }

  Widget _buildCenterHistoryLoadingOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: _buildHistoryLoadingSpinner(size: 36, strokeWidth: 3),
        ),
      ),
    );
  }

  static const Color _historyLoadingSpinnerColor = Color(0xFF007AFF);

  Widget _buildHistoryLoadingSpinner({
    double size = 22,
    double strokeWidth = 2.5,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: _historyLoadingSpinnerColor,
      ),
    );
  }

  bool get _paginationPrependRevealActive =>
      _paginationUi.paginationPrependRevealPending &&
      !_paginationUi.silentTopHistoryLoading;

  bool _shouldHideMessageDuringPaginationPrependReveal(int? globalIndex) {
    if (!_paginationPrependRevealActive || globalIndex == null) {
      return false;
    }
    final fromIndex = _paginationUi.paginationPrependRevealFromGlobalIndex;
    return fromIndex > 0 && globalIndex >= fromIndex;
  }

  void _beginPaginationPrependReveal({
    required int listLenBefore,
    required bool nearTopLoad,
  }) {
    _paginationUi.paginationPrependRevealPending = false;
    _paginationUi.paginationPrependRevealFromGlobalIndex = 0;
    if (!nearTopLoad || _paginationUi.silentTopHistoryLoading) {
      return;
    }
    final insertCount = _rawMessageCount() - listLenBefore;
    if (insertCount <= 0 || listLenBefore <= 0) {
      return;
    }
    _paginationUi.paginationPrependRevealPending = true;
    _paginationUi.paginationPrependRevealFromGlobalIndex = listLenBefore;
    ChatHistoryTrace.log(
      'load_previous_prepend_reveal_arm',
      conversationID: _conversationId(),
      extras: <String, Object?>{
        'listLenBefore': listLenBefore,
        'listLenAfter': _rawMessageCount(),
        'fromGlobalIndex': listLenBefore,
      },
    );
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || !_paginationUi.paginationPrependRevealPending) {
        return;
      }
      ChatHistoryTrace.log(
        'load_previous_prepend_reveal_fallback',
        conversationID: _conversationId(),
      );
      _commitPaginationPrependReveal();
    });
  }

  void _commitPaginationPrependReveal({bool notify = true}) {
    if (!_paginationUi.paginationPrependRevealPending) {
      return;
    }
    _paginationUi.paginationPrependRevealPending = false;
    _paginationUi.paginationPrependRevealFromGlobalIndex = 0;
    _clearTopHistoryLoading(notify: false);
    ChatHistoryTrace.log(
      'load_previous_prepend_reveal_commit',
      conversationID: _conversationId(),
    );
    if (notify && mounted) {
      setState(() {});
    }
  }

  void _cancelPaginationPrependReveal({bool notify = true}) {
    if (!_paginationUi.paginationPrependRevealPending) {
      return;
    }
    _paginationUi.paginationPrependRevealPending = false;
    _paginationUi.paginationPrependRevealFromGlobalIndex = 0;
    if (notify && mounted) {
      setState(() {});
    }
  }

  bool get _shouldShowTopHistoryLoading {
    // 首屏静默补拉：仍走 loadPrevious，但不渲染顶部转圈。
    if (_paginationUi.silentTopHistoryLoading) {
      return false;
    }
    if (_paginationPrependRevealActive) {
      return true;
    }
    if (_paginationUi.isLoadingPrevious ||
        _paginationUi.pendingLoadPrevious ||
        loadingPlace == LoadingPlace.top) {
      return true;
    }
    if (_paginationUi.topHistoryLoadingShownAtMs <= 0) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch -
            _paginationUi.topHistoryLoadingShownAtMs <
        _minTopHistoryLoadingVisibleMs;
  }

  void _scheduleMinTopHistoryLoadingHold() {
    final shownAt = _paginationUi.topHistoryLoadingShownAtMs;
    if (shownAt <= 0) {
      return;
    }
    final remain = _minTopHistoryLoadingVisibleMs -
        (DateTime.now().millisecondsSinceEpoch - shownAt);
    if (remain <= 0) {
      _paginationUi.topHistoryLoadingShownAtMs = 0;
      return;
    }
    Future<void>.delayed(Duration(milliseconds: remain), () {
      if (!mounted) {
        return;
      }
      _paginationUi.topHistoryLoadingShownAtMs = 0;
      setState(() {});
    });
  }

  Widget _buildTopHistoryLoadingIndicator({double size = 22}) {
    return _buildHistoryLoadingSpinner(size: size);
  }

  void _clearTopHistoryLoading({bool notify = true}) {
    _paginationUi.pendingLoadPrevious = false;
    _paginationUi.silentTopHistoryLoading = false;
    if (loadingPlace == LoadingPlace.top) {
      loadingPlace = LoadingPlace.none;
    }
    if (_paginationUi.topHistoryLoadingShownAtMs > 0 &&
        DateTime.now().millisecondsSinceEpoch -
                _paginationUi.topHistoryLoadingShownAtMs >=
            _minTopHistoryLoadingVisibleMs) {
      _paginationUi.topHistoryLoadingShownAtMs = 0;
    }
    if (notify && mounted) {
      setState(() {});
    }
  }

  void _markTopHistoryLoadingScheduled({bool silent = false}) {
    _paginationUi.pendingLoadPrevious = true;
    _paginationUi.silentTopHistoryLoading = silent;
    if (silent) {
      // 静默：不占 loadingPlace、不记最短可见时间，避免闪一下转圈。
      if (mounted) {
        setState(() {});
      }
      return;
    }
    loadingPlace = LoadingPlace.top;
    _paginationUi.topHistoryLoadingShownAtMs =
        DateTime.now().millisecondsSinceEpoch;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    _chatGlobalModel = nextModel;
    if (_routeScroll.routeRestoreGlobalModel == nextModel) {
      return;
    }
    _routeScroll.routeRestoreGlobalModel?.removeListener(_onGlobalModelUpdated);
    _routeScroll.routeRestoreGlobalModel = nextModel;
    _routeScroll.routeRestoreGlobalModel?.addListener(_onGlobalModelUpdated);
  }

  bool _isViewportInsertSettling() =>
      _viewportInsert.isViewportInsertSettling();

  void _beginViewportInsertSettle() =>
      _viewportInsert.beginViewportInsertSettle();

  int _viewportInsertSettleRemainingMs() =>
      _viewportInsert.viewportInsertSettleRemainingMs();

  void _onGlobalModelUpdated() {
    _onGlobalRouteRestoreChanged();
    _onInboundPresentationSupersede();
    if (_viewportInsert.viewportInsertSlideActive) {
      return;
    }
    _onInboundScrollFollowTick();
    final globalModel = _routeScroll.routeRestoreGlobalModel;
    if (globalModel != null &&
        globalModel.chatConfig.inboundScrollFollowEnabled &&
        globalModel.isChunkedRevealActive(_conversationId())) {
      return;
    }
    _onPinToBottomRequested();
  }

  void _onInboundPresentationSupersede() {
    final globalModel = _routeScroll.routeRestoreGlobalModel;
    if (globalModel == null) {
      return;
    }
    final seq = globalModel.inboundPresentationSupersedeSeq;
    if (seq == _lastInboundPresentationSupersedeSeq) {
      return;
    }
    _lastInboundPresentationSupersedeSeq = seq;
    _abortViewportInsertSlideForSupersede();
  }

  /// Chunk layer cancelled this push to keep only the newest bubble. Snap open
  /// without acking projection — [MessageInboundChunkedReveal] owns that ack.
  void _abortViewportInsertSlideForSupersede() {
    if (!_viewportInsert.viewportInsertSlideActive &&
        _viewportInsert.activeRowRevealMessages.isEmpty &&
        _viewportInsert.queuedViewportInsertMessages.isEmpty) {
      return;
    }
    ChatJitterDiag.logInboundFlow(
      action: 'viewport_slide_abort_supersede',
      conv: _conversationId(),
      extras: _readingHistoryScrollSnapshot(),
    );
    _viewportInsert.viewportInsertSlideGeneration++;
    _viewportInsert.rowRevealGeneration++;
    _viewportInsert.viewportInsertSlideActive = false;
    _viewportInsert.continuousViewportPushActive = false;
    _viewportInsert.continuousViewportPushLastElapsed = null;
    _viewportInsert.continuousViewportPushLastCommandedPixels = null;
    _viewportInsert.continuousViewportPushIntegrationScheduled = false;
    _viewportInsert.continuousViewportPushInitialLayoutUntilMsByKey.clear();
    _viewportInsert.continuousViewportPushRemainingRowExtents.clear();
    ++_viewportInsert.continuousViewportPushIntegrationGeneration;
    _viewportInsert.continuousViewportPushTicker?.stop();
    _cancelForcePinScroll();
    final globalModel = _chatGlobalModel;
    if (globalModel != null) {
      for (final message in _viewportInsert.activeRowRevealMessages.values) {
        globalModel.finishMessageEnterAnimation(message);
      }
      for (final message
          in _viewportInsert.queuedViewportInsertMessages.values) {
        globalModel.finishMessageEnterAnimation(message);
      }
    }
    _viewportInsert.activeRowRevealMessages.clear();
    _viewportInsert.queuedViewportInsertMessages.clear();
    _viewportInsert.rowRevealFullExtentByKey.clear();
    final controller = _viewportInsert.rowRevealController;
    if (controller != null) {
      controller.stop();
      if (controller.value < 1) {
        // Messages already cleared so statusListener complete is a no-op.
        controller.value = 1;
      }
    }
  }

  InboundScrollFollow _ensureInboundScrollFollow() {
    return _inboundScrollFollow ??= InboundScrollFollow(
      scrollController: _autoScrollController,
      shouldFollow: () {
        final model = _chatGlobalModel;
        return mounted &&
            model != null &&
            !model.isChatListUserScrolling &&
            _shouldPinScrollToBottom(model);
      },
      defaultSmoothDuration: Duration(
        milliseconds:
            _chatGlobalModel?.chatConfig.inboundScrollFollowDurationMs ?? 100,
      ),
    );
  }

  void _onInboundScrollFollowTick() {
    if (!mounted) {
      return;
    }
    final globalModel = _routeScroll.routeRestoreGlobalModel;
    if (globalModel == null) {
      return;
    }
    if (!globalModel.chatConfig.inboundScrollFollowEnabled) {
      return;
    }
    final seq = globalModel.inboundScrollFollowSeq;
    if (seq == _lastHandledScrollFollowSeq) {
      return;
    }
    _lastHandledScrollFollowSeq = seq;

    final sessionEnding = globalModel.inboundScrollFollowSessionEnding;
    final chunk = globalModel.lastInboundScrollFollowChunk;
    if (!sessionEnding && chunk.isEmpty) {
      return;
    }
    if (!_shouldPinScrollToBottom(globalModel)) {
      return;
    }

    final mode = globalModel.chatConfig.inboundScrollFollowMode;
    final durationMs = globalModel.chatConfig.inboundScrollFollowDurationMs;
    _ensureInboundScrollFollow().handleChunk(
      chunk: chunk,
      sessionEnding: sessionEnding,
      mode: mode,
      smoothDuration: Duration(milliseconds: durationMs),
    );

    if (sessionEnding) {
      globalModel.setMessageListPosition(
        _conversationId(),
        HistoryMessagePosition.bottom,
        notify: false,
      );
    }
  }

  void _onPinToBottomRequested() {
    if (!mounted) {
      return;
    }
    final globalModel = _routeScroll.routeRestoreGlobalModel;
    if (globalModel == null) {
      return;
    }
    if (globalModel.isBulkMessageSyncActive(_conversationId())) {
      return;
    }
    if (globalModel.isUserScrollToBottomInProgress(_conversationId())) {
      return;
    }
    final seq = globalModel.pinToBottomRequestSeq;
    if (seq == _lastHandledPinSeq) {
      return;
    }
    final convId = globalModel.pinToBottomRequestConvId;
    if (convId == null ||
        !TUIChatGlobalModel.isSameConversationIdForHistory(
          convId,
          _conversationId(),
        )) {
      return;
    }
    _lastHandledPinSeq = seq;
    if (globalModel.pinToBottomForce) {
      _scheduleForcePinScrollToBottom();
    } else {
      _schedulePinScrollToBottom();
    }
  }

  void _onGlobalRouteRestoreChanged() {
    if (!mounted) {
      return;
    }
    final globalModel = _routeScroll.routeRestoreGlobalModel;
    if (globalModel == null ||
        !globalModel.isRestoringScrollAfterMediaPreview) {
      return;
    }
    final version = globalModel.mediaPreviewRestoreVersion;
    if (version <= 0) {
      return;
    }
    if (_routeScroll.lastRouteRestoreVersion != version) {
      _routeScroll.lastRouteRestoreVersion = version;
      _routeScroll.routeRestoreAttempt = 0;
    }
    _scheduleRouteScrollRestore(_visibleMessageList(widget.messageList));
  }

  @override
  void didUpdateWidget(TIMUIKitHistoryMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageList.isEmpty && widget.messageList.isNotEmpty) {
      // 冷开 local-first：initState 时 rawCount=0，这里补标，避免后续云端
      // 补数走「非暖窗 bootstrap 结束 → pin 底」造成跳动。
      _routeScroll.openedWithCachedHistory = true;
      _scheduleChatOpenPerfProbe(reason: 'didUpdate_first_messages');
    }
    if (oldWidget.model.conversationID != widget.model.conversationID) {
      _clearShortHistoryAlignmentLatch();
      _resetHistoryOpenRevealGate();
      _routeScroll.shortHistoryAlignmentSuppressedByLiveInsert = false;
      _paginationUi.triedPreviousAfterNoMore = false;
      _initialUnreadAnchorConversationID = null;
      _initialUnreadAnchorCount = 0;
      _initialUnreadAnchorAttempts = 0;
      _initialUnreadAnchorScheduled = false;
      _initialUnreadAnchorInFlight = false;
      _completedEntryUnreadCount = 0;
      _firstUnreadAnchor = null;
      _firstUnreadAnchorJumped = false;
      _lastUnreadTongueConversationID = null;
      _lastUnreadTongueRemaining = null;
      _lastUnreadTongueSafeCount = 0;
      _unreadEntryBottomPinScheduled = false;
      _lastHandledPinSeq = 0;
      _lastHandledScrollFollowSeq = 0;
      _lastInboundPresentationSupersedeSeq = 0;
      if (_viewportInsert.continuousViewportPushActive) {
        _viewportInsert.continuousViewportPushTicker?.stop();
        _chatGlobalModel?.endInboundViewportPush(
          oldWidget.model.conversationID,
        );
      }
      _viewportInsert.continuousViewportPushActive = false;
      _viewportInsert.continuousViewportPushLastElapsed = null;
      _viewportInsert.continuousViewportPushLastCommandedPixels = null;
      _viewportInsert.continuousViewportPushIntegrationScheduled = false;
      _viewportInsert.continuousViewportPushInitialLayoutUntilMsByKey.clear();
      _viewportInsert.continuousViewportPushRemainingRowExtents.clear();
      ++_viewportInsert.continuousViewportPushIntegrationGeneration;
      _viewportInsert.viewportInsertSlideGeneration++;
      _viewportInsert.viewportInsertSlideActive = false;
      _viewportInsert.activeRowRevealMessages.clear();
      _viewportInsert.queuedViewportInsertMessages.clear();
      _viewportInsert.rowRevealFullExtentByKey.clear();
      _cancelForcePinScroll();
      _inboundScrollFollow?.dispose();
      _inboundScrollFollow = null;
      _deferUnreadCenterPartition = false;
      _incomingScrollAnchorPixels = null;
      _incomingScrollAnchorGeneration++;
      _lastDiagLayoutSafeUnread = -1;
      _lastDiagLayoutUnread = -1;
      _paginationUi.previousLoadConsumedThisTopReach = false;
      _paginationUi.lastTopReachConsumedAnchorKey = null;
      _paginationUi.previousLoadInFlightAnchorKey = null;
      _paginationUi.loadPreviousDebounce?.cancel();
      _paginationUi.loadPreviousDebounce = null;
      _pendingLoadPreviousAnchor = null;
      _paginationUi.loadPreviousTask = null;
      _bindSeparateModelListener();
      _chatGlobalModel?.clearActiveChatScrollController(
          conversationID: oldWidget.model.conversationID);
      _chatGlobalModel?.clearUnreadTongueMetrics(oldWidget.model.conversationID,
          notify: false);
      _chatGlobalModel?.clearEntryUnreadTongueDismissed(
          oldWidget.model.conversationID,
          notify: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bindActiveScrollController();
        _schedulePinScrollToBottom();
      });
    }
    final newestSideAbsorbed = _onMessageListMaybeInserted(
      oldWidget.messageList,
      widget.messageList,
    );
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    _handleInitialHistoryBootstrapTransition(globalModel);
    final listLenChanged =
        oldWidget.messageList.length != widget.messageList.length;
    final currentRev = globalModel.messageListRevisionFor(_conversationId());
    final listRevChanged = _historyOpenRevealLastListRev != null &&
        _historyOpenRevealLastListRev != currentRev;
    if ((listLenChanged || listRevChanged) &&
        !_historyOpenRevealReady &&
        _layoutReadyEpochSigned < 0) {
      _historyOpenRevealStableFrames = 0;
      _historyOpenRevealHoldFrames = 0;
      _historyOpenRevealLastSpacer = null;
      _historyOpenRevealLastContentH = null;
      _historyOpenRevealLastListLen = null;
      _historyOpenRevealLastListRev = null;
      if (_mayUseShortHistoryTopAlignment() ||
          _routeScroll.shortHistoryAlignmentLatched ||
          _routeScroll.shortHistoryBottomSpacerHeight > 1) {
        _scheduleHistoryOpenRevealWait(shortHistory: true);
      }
    }
    if (listLenChanged && !_isInitialHistoryBootstrapping(globalModel)) {
      final oldLen = oldWidget.messageList.length;
      final newLen = widget.messageList.length;
      final convId = _conversationId();
      // 进页后云端补历史：贴底时旧消息只往上长，禁止 contentH/spacer 重置与
      // 二次 pin，否则最新气泡会跟着整表「蹦」一下。
      final openCloudFillAtBottom = newLen > oldLen &&
          !_isReadingHistory() &&
          globalModel.hasInitialHistoryLoaded(convId) &&
          globalModel.mayHaveOlderHistory(convId) &&
          globalModel.getMessageListPosition(convId) ==
              HistoryMessagePosition.bottom;
      if (openCloudFillAtBottom) {
        ChatGeomSettleTrace.noteReason(
          'open_cloud_fill_keep_bottom_anchor',
          extras: <String, Object?>{
            'oldLen': oldLen,
            'newLen': newLen,
          },
        );
        return;
      }
      final shortSpacerLatched = _routeScroll.shortHistoryAlignmentLatched ||
          _routeScroll.shortHistoryBottomSpacerHeight > 0;
      var asyncHistoryAbsorbed = false;
      if (ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled &&
          !newestSideAbsorbed &&
          _historyOpenRevealReady &&
          shortSpacerLatched &&
          mounted &&
          !_isReadingHistory() &&
          oldLen != newLen) {
        final absorb = _absorbAsyncHistoryListChangeIntoShortSpacer(
          oldList: oldWidget.messageList,
          newList: widget.messageList,
        );
        if (absorb == _AsyncSpacerAbsorbResult.ok) {
          asyncHistoryAbsorbed = true;
        } else if (absorb == _AsyncSpacerAbsorbResult.overflow) {
          _clearShortHistoryAlignmentLatch();
          _blockShortSpacerReprimeAfterReveal = true;
          ChatGeomSettleTrace.noteReason(
            'short_spacer_reprime_blocked_after_reveal',
            extras: <String, Object?>{
              'cause': 'async_history_overflow',
              'oldLen': oldLen,
              'newLen': newLen,
            },
          );
        }
      }
      final significantGrow =
          newLen >= oldLen + 3 || (oldLen > 0 && newLen >= oldLen * 2);
      if (!asyncHistoryAbsorbed &&
          significantGrow &&
          (_routeScroll.shortHistoryAlignmentLatched ||
              _routeScroll.shortHistoryBottomSpacerHeight > 0) &&
          mounted &&
          !_isReadingHistory()) {
        ChatGeomSettleTrace.noteReason(
          'short_spacer_cleared_on_len_grow',
          extras: <String, Object?>{
            'oldLen': oldLen,
            'newLen': newLen,
            'spacer':
                _routeScroll.shortHistoryBottomSpacerHeight.toStringAsFixed(1),
            'contentH':
                _routeScroll.shortHistoryContentHeight.toStringAsFixed(1),
          },
        );
        _clearShortHistoryAlignmentLatch();
        if (_historyOpenRevealReady) {
          _blockShortSpacerReprimeAfterReveal = true;
          ChatGeomSettleTrace.noteReason(
            'short_spacer_reprime_blocked_after_reveal',
            extras: <String, Object?>{
              'cause': 'cleared_on_len_grow',
              'oldLen': oldLen,
              'newLen': newLen,
            },
          );
        }
      }
      final keepShortHistoryContent = mounted &&
          !_isReadingHistory() &&
          (_routeScroll.shortHistoryAlignmentLatched ||
              _routeScroll.shortHistoryBottomSpacerHeight > 0) &&
          !(
              // reveal 后异步历史写回导致变短：禁止死守旧大 spacer（tip 会被顶）。
              _historyOpenRevealReady && newLen < oldLen) &&
          !_contentExceedsShortHistoryViewport(
            messageList: widget.messageList,
            viewportHeight: _resolvedShortHistoryViewportForDecision(context),
            context: context,
          );
      if (keepShortHistoryContent) {
        ChatGeomSettleTrace.noteReason(
          'content_h_reset_skipped_keep_short_history',
          extras: <String, Object?>{
            'spacer':
                _routeScroll.shortHistoryBottomSpacerHeight.toStringAsFixed(1),
            'contentH':
                _routeScroll.shortHistoryContentHeight.toStringAsFixed(1),
            'oldLen': oldLen,
            'newLen': newLen,
          },
        );
      } else if (!asyncHistoryAbsorbed) {
        _assignShortHistoryContentHeight(-1,
            reason: 'content_h_reset_on_list_len_change');
      }
      if (mounted &&
          !_isReadingHistory() &&
          (_routeScroll.shortHistoryAlignmentLatched ||
              _routeScroll.shortHistoryBottomSpacerHeight > 0)) {
        final viewport = _resolvedShortHistoryViewportForDecision(context);
        if (_contentExceedsShortHistoryViewport(
          messageList: widget.messageList,
          viewportHeight: viewport,
          context: context,
        )) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isHistoryScrollProtected && !_isReadingHistory()) {
              setState(() {
                _releaseShortHistoryAlignmentAndPinBottom();
                if (_historyOpenRevealReady) {
                  _blockShortSpacerReprimeAfterReveal = true;
                }
              });
            }
          });
        }
      }
    }
  }

  bool _isInitialHistoryBootstrapping(TUIChatGlobalModel globalModel) {
    final convId = _conversationId();
    // 仅「首轮尚未确认」才算 bootstrapping。
    // 已确认空会话后的后台 loadChatRecord 不再挡空态，避免每次进空会话先转圈。
    return !globalModel.hasInitialHistoryLoaded(convId);
  }

  bool _isCompleteCachedOpenWindow(TUIChatGlobalModel globalModel) {
    final convId = _conversationId();
    final rawCount = globalModel.rawMessageCount(convId);
    if (rawCount >= HistoryMessageDartConstant.initialOpenFetchCount) {
      return true;
    }
    return globalModel.hasInitialHistoryLoaded(convId) &&
        !globalModel.mayHaveOlderHistory(convId);
  }

  void _handleInitialHistoryBootstrapTransition(
    TUIChatGlobalModel globalModel,
  ) {
    final bootstrapping = _isInitialHistoryBootstrapping(globalModel);
    if (_routeScroll.wasInitialHistoryBootstrapping && !bootstrapping) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        // 暖/冷开同一语义：短历史已顶部对齐（或仍应顶部对齐）时，
        // bootstrap 完成不要 clear，否则 spacer 0→prime 再弹一次。
        if (_routeScroll.openedWithCachedHistory) {
          return;
        }
        if (_shouldPreserveShortHistoryLatchAfterOpenHydrate(context)) {
          ChatGeomSettleTrace.noteReason(
            'bootstrap_skip_clear_keep_short_history',
            extras: <String, Object?>{
              'spacer': _routeScroll.shortHistoryBottomSpacerHeight
                  .toStringAsFixed(1),
              'contentH':
                  _routeScroll.shortHistoryContentHeight.toStringAsFixed(1),
              'latched': _routeScroll.shortHistoryAlignmentLatched,
            },
          );
          return;
        }
        _clearShortHistoryAlignmentLatch();
        // 长历史 / 已超出视口：hydrate 完成后回到底部；用户已上滑则保持原位。
        // 进页阶段只用 jump，避免 soft pin 的 animateTo「从底部往上飘」。
        if (!_isHistoryScrollProtected &&
            globalModel.getMessageListPosition(_conversationId()) ==
                HistoryMessagePosition.bottom) {
          _pinScrollToBottomImmediate();
        }
      });
    }
    _routeScroll.wasInitialHistoryBootstrapping = bootstrapping;
  }

  /// 进页 hydrate/bootstrap 完成后是否应保留短历史顶部 latch。
  /// 超出视口则 false（允许 clear+贴底）；读历史则 true（不 clear、不 pin）。
  bool _shouldPreserveShortHistoryLatchAfterOpenHydrate(BuildContext context) {
    if (!mounted) {
      return false;
    }
    if (_routeScroll.shortHistoryAlignmentSuppressedByLiveInsert) {
      return false;
    }
    if (_isReadingHistory()) {
      return true;
    }
    final viewport = _resolvedShortHistoryViewportForDecision(context);
    if (_contentExceedsShortHistoryViewport(
      messageList: widget.messageList,
      viewportHeight: viewport,
      context: context,
    )) {
      return false;
    }
    if (_routeScroll.shortHistoryAlignmentLatched ||
        _routeScroll.shortHistoryBottomSpacerHeight > 0) {
      return true;
    }
    return _shouldAlignShortHistoryToTop(
      messageList: widget.messageList,
      safeUnreadCount: 0,
      viewportHeight: viewport,
      context: context,
    );
  }

  @override
  void deactivate() {
    ChatJitterDiag.logWidgetLifecycle(
      widget: 'HistoryMessageList',
      phase: 'deactivate',
      stateHash: identityHashCode(this),
      conv: _conversationId(),
      livedMs: DateTime.now().millisecondsSinceEpoch - _createdAtMs,
      keyDebug: widget.key?.toString(),
      ancestors: _ancestorChainForDiag(),
    );
    super.deactivate();
  }

  @override
  void dispose() {
    VisibleSenderProfileRefresh.cancelPending();
    ChatHistoryOpenLayoutReady.epochRevision
        .removeListener(_onLayoutReadyEpochRevision);
    ChatGeomSettleTrace.end(reason: 'dispose');
    ChatJitterDiag.logWidgetLifecycle(
      widget: 'HistoryMessageList',
      phase: 'dispose',
      stateHash: identityHashCode(this),
      conv: _conversationId(),
      livedMs: DateTime.now().millisecondsSinceEpoch - _createdAtMs,
      keyDebug: widget.key?.toString(),
    );
    _pendingLoadPreviousAnchor = null;
    _paginationUi.pendingLoadPrevious = false;
    _paginationUi.disposeTimers();
    _clearScrollPaginationCompensation();
    _viewportInsert.viewportInsertSlideGeneration++;
    _viewportInsert.rowRevealGeneration++;
    _viewportInsert.viewportInsertSlideActive = false;
    _viewportInsert.continuousViewportPushActive = false;
    _viewportInsert.continuousViewportPushInitialLayoutUntilMsByKey.clear();
    _viewportInsert.continuousViewportPushRemainingRowExtents.clear();
    ++_viewportInsert.continuousViewportPushIntegrationGeneration;
    _viewportInsert.continuousViewportPushTicker?.dispose();
    _viewportInsert.continuousViewportPushTicker = null;
    _viewportInsert.viewportInsertSettleUntilMs = 0;
    _routeScroll.routeRestoreGlobalModel?.removeListener(_onGlobalModelUpdated);
    _routeScroll.routeRestoreGlobalModel = null;
    final globalModel = _chatGlobalModel;
    if (globalModel != null) {
      for (final message in _viewportInsert.activeRowRevealMessages.values) {
        globalModel.finishMessageEnterAnimation(message);
      }
      for (final message
          in _viewportInsert.queuedViewportInsertMessages.values) {
        globalModel.finishMessageEnterAnimation(message);
      }
      _viewportInsert.activeRowRevealMessages.clear();
      _viewportInsert.queuedViewportInsertMessages.clear();
      _viewportInsert.rowRevealFullExtentByKey.clear();
      if (globalModel.isChunkedRevealActive(_conversationId())) {
        globalModel.cancelInboundProjectionRevealToBuffer(_conversationId());
      }
    }
    _viewportInsert.activeRowRevealMessages.clear();
    _viewportInsert.queuedViewportInsertMessages.clear();
    _viewportInsert.rowRevealFullExtentByKey.clear();
    _viewportInsert.rowRevealController?.dispose();
    _acknowledgeInboundProjectionRevealIfNeeded();
    _inboundScrollFollow?.dispose();
    _inboundScrollFollow = null;
    _postScrollInboundFlushTimer?.cancel();
    _postScrollInboundFlushTimer = null;
    _unreadTongueMetricsThrottleTimer?.cancel();
    _unreadTongueMetricsThrottleTimer = null;
    _pendingUnreadTongueMetricsList = null;
    _chatGlobalModel?.clearActiveChatScrollController(
        conversationID: _conversationId());
    _chatGlobalModel?.setMemoryWindowSuppressed(_conversationId(), false);
    _setUserScrolling(false);
    _chatGlobalModel?.clearUnreadTongueMetrics(_conversationId(),
        notify: false);
    _chatGlobalModel?.clearEntryUnreadTongueDismissed(_conversationId(),
        notify: false);
    _controller.removeListener(_controllerListener);
    _boundSeparateModel?.removeListener(_onSeparateModelUpdated);
    _boundSeparateModel = null;
    (_chatGlobalModel ?? widget.model.globalModel).detachOpenChatPageUi(
      historyPosition: _pageUi.historyPosition,
      userScrolling: _pageUi.userScrolling,
    );
    _pageUi.dispose();
    super.dispose();
  }

  void _setUserScrolling(bool scrolling) {
    // Writes ChatPageUiNotifiers via GlobalModel attach bridge (single write path).
    final global = _chatGlobalModel ?? widget.model.globalModel;
    final wasScrolling = global.isChatListUserScrolling;
    if (scrolling) {
      _postScrollInboundFlushTimer?.cancel();
      _postScrollInboundFlushTimer = null;
    }
    global.setChatListUserScrolling(scrolling);
    if (wasScrolling && !scrolling) {
      final rawCount = global.rawMessageCount(_conversationId());
      if (ChatJitterDiag.enabled) {
        double? pixels;
        final position = _singleScrollPositionOrNull();
        if (position != null && position.hasPixels) {
          pixels = position.pixels;
        }
        ChatJitterDiag.noteScrollIdle(
          pixels: pixels,
          rawMessageCount: rawCount,
        );
      }
      ChatResourceSample.onRawMessageCount(rawCount);
      final convId = _conversationId();
      final listPosition = global.getMessageListPosition(convId);
      if (listPosition == HistoryMessagePosition.bottom) {
        ChatResourceSample.onBottom(rawMessageCount: rawCount);
        if (!_isSearchJumpStabilizing &&
            rawCount > ChatMessageWindowPolicy.softMax) {
          global.setMemoryWindowSuppressed(convId, false);
          global.applyMessageMemoryWindowNow(
            convId,
            memoryWindowPreferLatest: true,
          );
        }
      }
    }
  }

  void _setCompactHistoryCacheExtent(bool compact) {
    if (_compactHistoryCacheExtent == compact || !mounted) {
      return;
    }
    setState(() {
      _compactHistoryCacheExtent = compact;
    });
  }

  double _effectiveHistoryCacheExtent() {
    final normal = widget.mainHistoryListConfig?.cacheExtent ?? 800;
    if (!_compactHistoryCacheExtent) {
      return normal;
    }
    final compact = widget.mainHistoryListConfig?.scrollingCacheExtent;
    if (compact == null || compact <= 0) {
      return normal;
    }
    return min(normal, compact);
  }

  void _schedulePostScrollInboundFlush(TUIChatGlobalModel globalModel) {
    _postScrollInboundFlushTimer?.cancel();
    _postScrollInboundFlushTimer = Timer(
      const Duration(milliseconds: _postScrollInboundFlushDelayMs),
      () {
        _postScrollInboundFlushTimer = null;
        if (!mounted) {
          return;
        }
        if (globalModel.isChatListUserScrolling) {
          return;
        }
        if (_isReadingHistory()) {
          return;
        }
        final convId = _conversationId();
        ChatJitterDiag.logInboundFlow(
          action: 'post_scroll_flush_fire',
          conv: convId,
          extras: <String, Object?>{
            'buffered': globalModel.deferredIncomingBufferedCount(convId),
            'delayMs': _postScrollInboundFlushDelayMs,
          },
        );
        globalModel.flushDeferredIncomingMessages(
          convId,
          notify: false,
        );
      },
    );
  }

  String _conversationId() => widget.model.conversationID;

  String _ancestorChainForDiag() {
    if (!mounted) return 'unmounted';
    final types = <String>[];
    context.visitAncestorElements((element) {
      types.add(element.widget.runtimeType.toString());
      return types.length < 8;
    });
    return types.join('>');
  }

  bool get _isHistoryScrollProtected {
    final globalModel =
        _routeScroll.routeRestoreGlobalModel ?? _chatGlobalModel;
    return _paginationUi.isHistoryScrollProtected(
      mediaPreviewRestoring:
          globalModel?.isRestoringScrollAfterMediaPreview ?? false,
    );
  }

  void _beginHistoryScrollProtection({int? milliseconds}) {
    _paginationUi.beginHistoryScrollProtection(milliseconds: milliseconds);
  }

  int _tongueMetricsUnreadCount(
    int safeUnreadCount,
    TUIChatGlobalModel globalModel,
  ) {
    final convId = _conversationId();
    if (globalModel.hasLockedEntryUnreadFor(convId)) {
      return globalModel.lockedEntryUnreadCount;
    }
    return safeUnreadCount;
  }

  bool _isOverscrollingPastTop(ScrollMetrics metrics) {
    if (!metrics.hasPixels || !metrics.hasContentDimensions) {
      return false;
    }
    return metrics.pixels >
        metrics.maxScrollExtent + _loadPreviousOverscrollTolerancePx;
  }

  double _clampScrollPixelsForPosition(ScrollPosition position, double pixels) {
    if (!position.hasContentDimensions) {
      return pixels;
    }
    return pixels.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  bool _isReadingHistory({double? threshold}) {
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return false;
    }
    final effectiveThreshold = threshold ?? _readingHistoryThresholdPx;
    return position.pixels > position.minScrollExtent + effectiveThreshold;
  }

  Map<String, Object?> _readingHistoryScrollSnapshot() {
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return const <String, Object?>{'scrollReady': false};
    }
    return <String, Object?>{
      'scrollReady': true,
      'pixels': position.pixels.toStringAsFixed(1),
      'minExtent': position.minScrollExtent.toStringAsFixed(1),
      'maxExtent': position.maxScrollExtent.toStringAsFixed(1),
      'viewport': position.viewportDimension.toStringAsFixed(1),
      'distanceFromBottom':
          (position.pixels - position.minScrollExtent).toStringAsFixed(1),
    };
  }

  void _logReadingHistoryIncoming(
    String action, {
    Map<String, Object?> extras = const <String, Object?>{},
    TUIChatGlobalModel? globalModel,
  }) {
    final model = globalModel ?? _chatGlobalModel;
    ChatJitterDiag.logReadingHistoryIncoming(
      action: action,
      conv: _conversationId(),
      extras: <String, Object?>{
        'deferPartition': _deferUnreadCenterPartition,
        'readingHistory': _isReadingHistory(),
        'anchorPixels': _incomingScrollAnchorPixels,
        'historyProtected': _isHistoryScrollProtected,
        if (model != null)
          'listPosition': model.getMessageListPosition(_conversationId()).name,
        if (model != null) 'tongueUnread': model.unreadCountForTongue,
        ..._readingHistoryScrollSnapshot(),
        ...extras,
      },
    );
  }

  int _layoutUnreadCount(int safeUnreadCount) {
    if (safeUnreadCount <= 0) {
      return 0;
    }
    // 进房贴底、尚未点击「未读」跳转：禁止 unread center 切分，
    // 否则 CustomScrollView.center 会把视口锚到首条未读附近（像自动跳转）。
    final globalModel = _chatGlobalModel;
    if (globalModel != null &&
        !_firstUnreadAnchorJumped &&
        globalModel.getMessageListPosition(_conversationId()) ==
            HistoryMessagePosition.bottom) {
      return 0;
    }
    if (!_deferUnreadCenterPartition) {
      return safeUnreadCount;
    }
    if (!_isReadingHistory()) {
      return safeUnreadCount;
    }
    return 0;
  }

  void _maybeLatchUnreadCenterDeferral() {
    if (!_isReadingHistory()) {
      return;
    }
    if (_deferUnreadCenterPartition) {
      return;
    }
    _deferUnreadCenterPartition = true;
    _logReadingHistoryIncoming('defer_partition_latch');
  }

  void _maybeReleaseUnreadCenterDeferral() {
    if (!_deferUnreadCenterPartition) {
      return;
    }
    if (_isReadingHistory()) {
      return;
    }
    _deferUnreadCenterPartition = false;
    _clearIncomingScrollAnchor(reason: 'release_defer');
    _logReadingHistoryIncoming('defer_partition_release');
  }

  bool _shouldCompensateScrollForPagination() {
    if (_paginationUi.isLoadingPrevious) {
      return true;
    }
    final until = _paginationUi.scrollPaginationCompensationUntilMs;
    return until > 0 && DateTime.now().millisecondsSinceEpoch < until;
  }

  void _captureIncomingScrollAnchor(TUIChatGlobalModel globalModel) {
    if (globalModel.isChatListUserScrolling) {
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return;
    }
    if (_incomingScrollAnchorPixels == null) {
      _incomingScrollAnchorPixels = position.pixels;
    }
  }

  void _clearIncomingScrollAnchor({String? reason}) {
    if (_incomingScrollAnchorPixels == null) {
      return;
    }
    _incomingScrollAnchorPixels = null;
    _incomingScrollAnchorGeneration++;
    if (reason != null) {
      _logReadingHistoryIncoming(
        'scroll_anchor_clear',
        extras: <String, Object?>{'reason': reason},
      );
    }
  }

  void _scheduleIncomingScrollAnchorRestore({int attempt = 0}) {
    final generation = _incomingScrollAnchorGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _incomingScrollAnchorGeneration) {
        return;
      }
      _restoreIncomingScrollAnchorIfNeeded(
        attempt: attempt,
        generation: generation,
      );
    });
  }

  void _restoreIncomingScrollAnchorIfNeeded({
    required int attempt,
    required int generation,
  }) {
    if (!mounted || generation != _incomingScrollAnchorGeneration) {
      return;
    }
    final globalModel = _chatGlobalModel;
    if (globalModel?.isChatListUserScrolling ?? false) {
      return;
    }
    if (!_deferUnreadCenterPartition && !_isReadingHistory()) {
      _clearIncomingScrollAnchor();
      return;
    }
    final anchor = _incomingScrollAnchorPixels;
    if (anchor == null) {
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      if (attempt < 8) {
        _scheduleIncomingScrollAnchorRestore(attempt: attempt + 1);
      }
      return;
    }
    final target = anchor.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final before = position.pixels;
    final drift = (before - target).abs();
    if (drift > 1.0) {
      _geomJumpTo(target, reason: 'jump__restoreIncomingScrollAnchorIfNeeded');
      _logReadingHistoryIncoming(
        'scroll_anchor_restore',
        globalModel: globalModel,
        extras: <String, Object?>{
          'anchor': anchor.toStringAsFixed(1),
          'before': before.toStringAsFixed(1),
          'target': target.toStringAsFixed(1),
          'drift': drift.toStringAsFixed(1),
          'attempt': attempt,
          'maxExtent': position.maxScrollExtent.toStringAsFixed(1),
        },
      );
    }
    if (attempt < 8) {
      _scheduleIncomingScrollAnchorRestore(attempt: attempt + 1);
    } else {
      _clearIncomingScrollAnchor();
    }
  }

  void _beginIncomingWhileReadingAnchorLock(TUIChatGlobalModel globalModel) {
    // 上拉分页已有专属的消息锚点与 extent 补偿。入站消息若在此期间再用
    // 加载前 pixels 建立多帧恢复，会和分页恢复争夺位置，造成来回跳动。
    if (_paginationUi.isLoadingPrevious ||
        _shouldCompensateScrollForPagination()) {
      _clearIncomingScrollAnchor(reason: 'pagination_precedence');
      _logReadingHistoryIncoming(
        'scroll_anchor_skip_pagination',
        globalModel: globalModel,
      );
      return;
    }
    _captureIncomingScrollAnchor(globalModel);
    _incomingScrollAnchorGeneration++;
    _logReadingHistoryIncoming(
      'scroll_anchor_lock',
      globalModel: globalModel,
      extras: <String, Object?>{
        'anchor': _incomingScrollAnchorPixels?.toStringAsFixed(1),
      },
    );
    _scheduleIncomingScrollAnchorRestore();
  }

  void _beginIncomingWhileReadingCompensation() {
    _beginHistoryScrollProtection(
        milliseconds: _incomingWhileReadingCompensationMs);
  }

  void _beginScrollPaginationCompensation() {
    _extendScrollPaginationCompensation(
      milliseconds: _scrollPaginationCompensationMs,
    );
  }

  void _extendScrollPaginationCompensation({int? milliseconds}) {
    final extendMs = milliseconds ?? _scrollPaginationCompensationMs;
    final until = DateTime.now().millisecondsSinceEpoch + extendMs;
    if (until > _paginationUi.scrollPaginationCompensationUntilMs) {
      _paginationUi.scrollPaginationCompensationUntilMs = until;
    }
  }

  void _clearScrollPaginationCompensation() {
    _paginationUi.scrollPaginationCompensationUntilMs = 0;
  }

  void _scheduleScrollPaginationCompensationEnd({
    required int generation,
    required double anchorPixels,
    required double anchorMaxExtent,
  }) {
    _scheduleScrollPaginationPrependRestore(
      generation: generation,
      anchorPixels: anchorPixels,
      anchorMaxExtent: anchorMaxExtent,
      attempt: 0,
    );
  }

  void _scheduleScrollPaginationPrependRestore({
    required int generation,
    required double anchorPixels,
    required double anchorMaxExtent,
    required int attempt,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _paginationUi.scrollPaginationCompensationGeneration != generation) {
        return;
      }
      unawaited(_restoreScrollAfterPaginationPrepend(
        generation: generation,
        anchorPixels: anchorPixels,
        anchorMaxExtent: anchorMaxExtent,
        attempt: attempt,
      ));
    });
  }

  Future<void> _restoreScrollAfterPaginationPrepend({
    required int generation,
    required double anchorPixels,
    required double anchorMaxExtent,
    required int attempt,
  }) async {
    const maxPinnedAnchorAttempts = 4;
    if (!mounted ||
        _paginationUi.scrollPaginationCompensationGeneration != generation) {
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      if (attempt < maxPinnedAnchorAttempts - 1) {
        _scheduleScrollPaginationPrependRestore(
          generation: generation,
          anchorPixels: anchorPixels,
          anchorMaxExtent: anchorMaxExtent,
          attempt: attempt + 1,
        );
      } else {
        _clearPaginationRestoreAnchor();
        _clearScrollPaginationCompensation();
        _cancelPaginationPrependReveal(notify: false);
        if (mounted) {
          setState(() {});
        }
      }
      return;
    }

    const compensationPath = 'reverse_append_native';
    final pinnedAtLoad = _wasPinnedNearTopForPagination(
      anchorPixels: anchorPixels,
      anchorMaxExtent: anchorMaxExtent,
    );
    final overscrollAtLoad =
        HistoryPaginationScrollPhysics.wasOverscrollingPastTop(
      anchorPixels: anchorPixels,
      anchorMaxExtent: anchorMaxExtent,
      tolerancePx: ChatListPaginationUiGate.loadPreviousOverscrollTolerancePx,
    );

    double? expectedExtentDeltaPixels;
    if (anchorMaxExtent > 0) {
      expectedExtentDeltaPixels =
          HistoryPaginationScrollPhysics.computeExtentDeltaRestorePixels(
        anchorPixels: anchorPixels,
        anchorMaxExtent: anchorMaxExtent,
        newMaxScrollExtent: position.maxScrollExtent,
        minScrollExtent: position.minScrollExtent,
      );
    }

    // 不再调用 jumpTo/scrollToIndex，也不按 extent 增长修正。reverse sliver
    // 中旧历史追加不会改变既有行索引，保留 pixels 即可保持可见内容位置。

    final restoreMsgIDForLog =
        _paginationUi.paginationRestoreAnchorMsgID?.trim() ?? '';
    _clearPaginationRestoreAnchor();
    _clearScrollPaginationCompensation();
    _cancelPaginationPrependReveal(notify: false);
    ChatHistoryTrace.log(
      'load_previous_scroll_compensation_done',
      conversationID: _conversationId(),
      extras: <String, Object?>{
        'anchorPixels': anchorPixels,
        'anchorMaxExtent': anchorMaxExtent,
        'pixels': position.pixels,
        'maxExtent': position.maxScrollExtent,
        'restoreMsgID': restoreMsgIDForLog,
        'path': compensationPath,
        'attempt': attempt,
        'pinnedAtLoad': pinnedAtLoad,
        'overscrollAtLoad': overscrollAtLoad,
        'expectedExtentDeltaPixels': expectedExtentDeltaPixels,
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _clearPaginationRestoreAnchor() {
    _paginationUi.paginationRestoreAnchorMsgID = null;
    _paginationUi.paginationRestoreAnchorSeq = null;
  }

  bool _wasPinnedNearTopForPagination({
    required double anchorPixels,
    required double anchorMaxExtent,
  }) {
    if (anchorMaxExtent <= 0) {
      return false;
    }
    return anchorPixels >= anchorMaxExtent - _loadPreviousTopNearPx;
  }

  ScrollPhysics? _buildHistoryScrollPhysics() {
    if (widget.isAllowScroll == false) {
      return const NeverScrollableScrollPhysics();
    }
    final globalModel = _chatGlobalModel ??
        Provider.of<TUIChatGlobalModel>(context, listen: false);
    // 全屏预览（尤其 opaque:false 下滑透出聊天）期间禁用列表滚动，
    // 避免下滑关闭手势穿透把会话记录拖走。
    if (globalModel.shouldLockChatScrollForMediaPreview) {
      return const NeverScrollableScrollPhysics();
    }
    // reverse sliver 的旧历史追加不会改变既有行位置。使用调用方/平台原生
    // physics，避免按 maxExtent 增长修正而把视口推向新批次最旧端。
    return widget.mainHistoryListConfig?.physics;
  }

  ScrollPosition? _singleScrollPositionOrNull() {
    if (!_autoScrollController.hasClients) {
      return null;
    }
    if (_autoScrollController.positions.length == 1) {
      return _autoScrollController.position;
    }
    for (final position in _autoScrollController.positions) {
      if (position.hasPixels && position.hasContentDimensions) {
        return position;
      }
    }
    return _autoScrollController.positions.isEmpty
        ? null
        : _autoScrollController.positions.first;
  }

  ChatGeomSettleSnapshot? _captureGeomSettleSnapshot() {
    if (!mounted) {
      return null;
    }
    final position = _singleScrollPositionOrNull();
    return ChatGeomSettleTrace.snapshot(
      pixels: position?.hasPixels == true ? position!.pixels : null,
      minExtent: position?.hasContentDimensions == true
          ? position!.minScrollExtent
          : null,
      maxExtent: position?.hasContentDimensions == true
          ? position!.maxScrollExtent
          : null,
      viewport: position?.hasContentDimensions == true
          ? position!.viewportDimension
          : null,
      spacer: _routeScroll.shortHistoryBottomSpacerHeight,
      contentH: _routeScroll.shortHistoryContentHeight,
      latched: _routeScroll.shortHistoryAlignmentLatched,
    );
  }

  void _geomJumpTo(double pixels, {required String reason}) {
    ChatGeomSettleTrace.noteReason(
      reason,
      extras: <String, Object?>{
        'target': pixels.toStringAsFixed(1),
      },
    );
    _autoScrollController.jumpTo(pixels);
  }

  Future<void> _geomScrollToIndex(
    int index, {
    required String reason,
    AutoScrollPosition preferPosition = AutoScrollPosition.middle,
  }) {
    ChatGeomSettleTrace.noteReason(
      reason,
      extras: <String, Object?>{
        'index': index,
        'prefer': preferPosition.toString(),
      },
    );
    return _autoScrollController.scrollToIndex(
      index,
      preferPosition: preferPosition,
    );
  }

  void _assignShortHistorySpacer(
    double nextHeight, {
    required String reason,
  }) {
    var normalized = nextHeight <= 1 ? 0.0 : nextHeight;
    if (!ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled &&
        normalized > 0) {
      ChatGeomSettleTrace.noteReason(
        'short_history_spacer_blocked_top_align_disabled',
        extras: <String, Object?>{
          'reason': reason,
          'blockedNext': normalized.toStringAsFixed(1),
        },
      );
      normalized = 0.0;
    }
    final prev = _routeScroll.shortHistoryBottomSpacerHeight;
    final delta = (normalized - prev).abs();
    if (_isPostRevealMicroSuppressWindow) {
      final sinceReady = _msSinceHistoryOpenRevealReady();
      final maxSuppressDelta = sinceReady < 200 ? 4.0 : 2.0;
      if (delta <= maxSuppressDelta) {
        ChatGeomSettleTrace.noteReason(
          'spacer_micro_suppressed_post_reveal',
          extras: <String, Object?>{
            'prev': prev.toStringAsFixed(1),
            'next': normalized.toStringAsFixed(1),
            'delta': (normalized - prev).toStringAsFixed(1),
            'sinceReadyMs': sinceReady,
            'maxDelta': maxSuppressDelta,
            'reason': reason,
          },
        );
        return;
      }
    }
    ChatGeomSettleTrace.noteReason(
      reason,
      extras: <String, Object?>{
        'prev': prev.toStringAsFixed(1),
        'next': normalized.toStringAsFixed(1),
        'delta': (normalized - prev).toStringAsFixed(1),
      },
    );
    _routeScroll.shortHistoryBottomSpacerHeight = normalized;
  }

  void _assignShortHistoryContentHeight(
    double nextHeight, {
    required String reason,
  }) {
    final normalized = nextHeight < 0 ? -1.0 : nextHeight;
    final prev = _routeScroll.shortHistoryContentHeight;
    ChatGeomSettleTrace.noteReason(
      reason,
      extras: <String, Object?>{
        'prev': prev.toStringAsFixed(1),
        'next': normalized.toStringAsFixed(1),
        'delta': (normalized - prev).toStringAsFixed(1),
      },
    );
    _routeScroll.shortHistoryContentHeight = normalized;
    if (normalized < 0) {
      _routeScroll.shortHistoryContentHeightMeasured = false;
    } else if (reason == 'content_h_measure' || reason == 'content_h_set') {
      final becameMeasured = !_routeScroll.shortHistoryContentHeightMeasured;
      _routeScroll.shortHistoryContentHeightMeasured = true;
      if (becameMeasured) {
        _onShortHistoryFirstMeasured();
      }
    } else if (reason == 'content_h_prime_last_measured') {
      // 会话上次实测：视为已测 SSOT，禁止 _resolved* 用偏高估盖回（暖开 183→259）。
      _routeScroll.shortHistoryContentHeightMeasured = true;
    }
  }

  Future<bool> _alignGlobalMessageIndexToViewportTop(
    int targetGlobalIndex, {
    Duration duration = const Duration(milliseconds: 220),
    bool animate = true,
  }) async {
    return _jumpToFirstUnreadGlobalIndex(targetGlobalIndex);
  }

  _FirstUnreadJumpFrameCheck? _checkFirstUnreadJumpFrame(
      int targetGlobalIndex) {
    final scrollIndex = -targetGlobalIndex;
    final tagContext = _autoScrollController.tagMap[scrollIndex]?.context;
    if (tagContext == null) {
      return _FirstUnreadJumpFrameCheck.notReady(targetGlobalIndex);
    }
    final scrollable = Scrollable.maybeOf(tagContext);
    if (scrollable == null) {
      return _FirstUnreadJumpFrameCheck.notReady(targetGlobalIndex);
    }
    final targetRenderObject = tagContext.findRenderObject();
    final viewportRenderObject = scrollable.context.findRenderObject();
    if (targetRenderObject is! RenderBox ||
        !targetRenderObject.attached ||
        viewportRenderObject is! RenderBox ||
        !viewportRenderObject.attached ||
        !targetRenderObject.hasSize ||
        !viewportRenderObject.hasSize ||
        _renderObjectNeedsLayout(targetRenderObject) ||
        _renderObjectNeedsLayout(viewportRenderObject)) {
      return _FirstUnreadJumpFrameCheck.notReady(targetGlobalIndex);
    }

    final targetTop = targetRenderObject
        .localToGlobal(Offset.zero, ancestor: viewportRenderObject)
        .dy;
    const tolerance = 12.0;
    final targetPixels = RenderAbstractViewport.of(targetRenderObject)
        .getOffsetToReveal(targetRenderObject, 0)
        .offset;
    return _FirstUnreadJumpFrameCheck(
      targetGlobalIndex: targetGlobalIndex,
      isReady: true,
      topDelta: targetTop,
      tolerance: tolerance,
      targetPixels: targetPixels,
    );
  }

  Future<bool> _correctFirstUnreadJumpToTop(int targetGlobalIndex) async {
    final check = _checkFirstUnreadJumpFrame(targetGlobalIndex);
    if (check == null) {
      return false;
    }
    if (!check.isReady) {
      try {
        await _geomScrollToIndex(
          -targetGlobalIndex,
          preferPosition: AutoScrollPosition.begin,
          reason: 'scroll_to_index_begin',
        );
      } catch (_) {}
      return false;
    }
    if (check.isTopAligned) {
      return true;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      try {
        await _geomScrollToIndex(
          -targetGlobalIndex,
          preferPosition: AutoScrollPosition.begin,
          reason: 'scroll_to_index_begin',
        );
      } catch (_) {}
      return false;
    }
    final targetPixels = check.targetPixels?.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (targetPixels == null) {
      try {
        await _geomScrollToIndex(
          -targetGlobalIndex,
          preferPosition: AutoScrollPosition.begin,
          reason: 'scroll_to_index_begin',
        );
      } catch (_) {}
      return false;
    }
    if ((position.pixels - targetPixels).abs() <= 0.5) {
      try {
        await _geomScrollToIndex(
          -targetGlobalIndex,
          preferPosition: AutoScrollPosition.begin,
          reason: 'scroll_to_index_begin',
        );
      } catch (_) {}
      return false;
    }
    _geomJumpTo(targetPixels.toDouble(), reason: 'first_unread_jump_pixels');
    return false;
  }

  Future<bool> _stabilizeFirstUnreadJumpTarget(int targetGlobalIndex) async {
    var stableFrames = 0;
    for (var attempt = 0; attempt < 20; attempt++) {
      _lockSearchJumpStabilization(milliseconds: 4000);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return false;
      }

      final corrected = await _correctFirstUnreadJumpToTop(targetGlobalIndex);
      if (!mounted) {
        return false;
      }
      if (corrected) {
        stableFrames++;
        if (stableFrames >= 3) {
          return true;
        }
      } else {
        stableFrames = 0;
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    final finalCheck = _checkFirstUnreadJumpFrame(targetGlobalIndex);
    return finalCheck?.isTopAligned ?? false;
  }

  Future<bool> _jumpToFirstUnreadGlobalIndex(int targetGlobalIndex) async {
    if (!mounted || targetGlobalIndex < 0) {
      return false;
    }
    if (!_scrollMetricsReady()) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || !_scrollMetricsReady()) {
        return false;
      }
    }

    _lockSearchJumpStabilization(milliseconds: 4000);
    _paginationUi.ignoreScrollLoadPrevious += 2;

    try {
      for (var attempt = 0; attempt < 12; attempt++) {
        try {
          await _geomScrollToIndex(
            -targetGlobalIndex,
            preferPosition: AutoScrollPosition.begin,
            reason: 'scroll_to_index_begin',
          );
        } catch (_) {}
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) {
          return false;
        }
        final check = _checkFirstUnreadJumpFrame(targetGlobalIndex);
        if (check?.isReady == true) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      return _stabilizeFirstUnreadJumpTarget(targetGlobalIndex);
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted && _paginationUi.ignoreScrollLoadPrevious >= 2) {
          _paginationUi.ignoreScrollLoadPrevious -= 2;
        }
      });
    }
  }

  void _scheduleUnreadTongueMetricsUpdate(
    List<V2TimMessage?> messageList,
    int safeUnreadCount, {
    bool force = false,
  }) {
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    final convId = _conversationId();
    if (force) {
      _unreadTongueMetricsThrottleTimer?.cancel();
      _unreadTongueMetricsThrottleTimer = null;
      _pendingUnreadTongueMetricsList = null;
      _pendingUnreadTongueMetricsSafeCount = 0;
    }
    if (safeUnreadCount <= 0 || messageList.isEmpty) {
      _unreadTongueMetricsThrottleTimer?.cancel();
      _unreadTongueMetricsThrottleTimer = null;
      _pendingUnreadTongueMetricsList = null;
      _pendingUnreadTongueMetricsSafeCount = 0;
      if (globalModel.hasLockedEntryUnreadFor(convId)) {
        return;
      }
      _lastUnreadTongueConversationID = null;
      _lastUnreadTongueRemaining = null;
      _lastUnreadTongueSafeCount = 0;
      globalModel.clearUnreadTongueMetrics(convId, notify: true);
      return;
    }
    if (!force &&
        (globalModel.isChatListUserScrolling || _userScrollGestureActive)) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final waitMs = _scrollingUnreadTongueMetricsThrottleMs -
          (now - _lastUnreadTongueMetricsRunAtMs);
      if (waitMs > 0) {
        _pendingUnreadTongueMetricsList = messageList;
        _pendingUnreadTongueMetricsSafeCount = safeUnreadCount;
        _unreadTongueMetricsThrottleTimer ??=
            Timer(Duration(milliseconds: waitMs), () {
          _unreadTongueMetricsThrottleTimer = null;
          if (!mounted) {
            return;
          }
          final pendingList = _pendingUnreadTongueMetricsList;
          final pendingSafeCount = _pendingUnreadTongueMetricsSafeCount;
          _pendingUnreadTongueMetricsList = null;
          _pendingUnreadTongueMetricsSafeCount = 0;
          if (pendingList == null || pendingSafeCount <= 0) {
            return;
          }
          _enqueueUnreadTongueMetricsPostFrame(
            pendingList,
            pendingSafeCount,
          );
        });
        return;
      }
    }
    _enqueueUnreadTongueMetricsPostFrame(
      messageList,
      safeUnreadCount,
      force: force,
    );
  }

  void _enqueueUnreadTongueMetricsPostFrame(
    List<V2TimMessage?> messageList,
    int safeUnreadCount, {
    bool force = false,
  }) {
    if (_unreadTongueMetricsScheduled && !force) {
      return;
    }
    _unreadTongueMetricsScheduled = true;
    final snapshot = messageList;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _unreadTongueMetricsScheduled = false;
      if (!mounted) {
        return;
      }
      _lastUnreadTongueMetricsRunAtMs = DateTime.now().millisecondsSinceEpoch;
      _updateUnreadTongueMetrics(snapshot, safeUnreadCount);
    });
  }

  void _updateUnreadTongueMetrics(
    List<V2TimMessage?> messageList,
    int safeUnreadCount,
  ) {
    if (!mounted || safeUnreadCount <= 0 || messageList.isEmpty) {
      return;
    }
    // 已点过入口未读并跳走：不再用入口未读数刷右下角「新消息」胶囊。
    if (_firstUnreadAnchorJumped) {
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return;
    }

    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    final convId = _conversationId();
    final nearLatest = position.pixels <= position.minScrollExtent + 24;

    if (nearLatest &&
        safeUnreadCount > 0 &&
        !_firstUnreadAnchorJumped &&
        globalModel.getMessageListPosition(convId) ==
            HistoryMessagePosition.bottom) {
      _commitUnreadTongueMetrics(
        globalModel: globalModel,
        conversationID: convId,
        remaining: safeUnreadCount,
        below: false,
        safeUnreadCount: safeUnreadCount,
      );
      return;
    }

    final viewportHeight = position.viewportDimension;
    var realUnreadOrdinal = 0;
    var builtAnyUnread = false;
    var allBuiltUnreadBelowViewport = true;
    var allBuiltUnreadAboveViewport = true;
    int? oldestVisibleUnreadOrdinal;

    for (var i = 0;
        i < messageList.length && realUnreadOrdinal < safeUnreadCount;
        i++) {
      final message = messageList[i];
      if (!_isUnreadAnchorMessage(message)) {
        continue;
      }
      final ordinalFromNewest = realUnreadOrdinal;
      realUnreadOrdinal++;
      final tagContext = _autoScrollController.tagMap[-i]?.context;
      final renderObject = tagContext?.findRenderObject();
      if (tagContext == null ||
          renderObject is! RenderBox ||
          !renderObject.attached) {
        continue;
      }
      final viewport = RenderAbstractViewport.of(renderObject);
      if (viewport is! RenderBox || !viewport.attached) {
        continue;
      }
      final leadingOffset =
          renderObject.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final trailingOffset = leadingOffset + renderObject.size.height;

      builtAnyUnread = true;
      if (leadingOffset <= viewportHeight + 4) {
        allBuiltUnreadBelowViewport = false;
      }
      if (trailingOffset >= -4) {
        allBuiltUnreadAboveViewport = false;
      }
      final isVisible =
          trailingOffset >= -4 && leadingOffset <= viewportHeight + 4;
      if (isVisible) {
        if (oldestVisibleUnreadOrdinal == null ||
            ordinalFromNewest > oldestVisibleUnreadOrdinal) {
          oldestVisibleUnreadOrdinal = ordinalFromNewest;
        }
      }
    }

    if (!builtAnyUnread) {
      // Lazy slivers may have none of the unread rows mounted. Preserve a
      // deterministic count instead of retaining stale metrics indefinitely.
      _commitUnreadTongueMetrics(
        globalModel: globalModel,
        conversationID: convId,
        remaining: safeUnreadCount,
        below: !nearLatest,
        safeUnreadCount: safeUnreadCount,
      );
      return;
    }

    if (oldestVisibleUnreadOrdinal != null) {
      // messageList is newest -> oldest. At the first unread anchor, the
      // oldest visible unread ordinal is safeUnreadCount - 1, so the capsule
      // shows the full unread count. When the user scrolls down toward the
      // latest message, the ordinal becomes smaller and the count decreases.
      _commitUnreadTongueMetrics(
        globalModel: globalModel,
        conversationID: convId,
        remaining: oldestVisibleUnreadOrdinal + 1,
        below: true,
        safeUnreadCount: safeUnreadCount,
      );
      return;
    }

    if (allBuiltUnreadBelowViewport) {
      _commitUnreadTongueMetrics(
        globalModel: globalModel,
        conversationID: convId,
        remaining: safeUnreadCount,
        below: true,
        safeUnreadCount: safeUnreadCount,
      );
      return;
    }

    if (allBuiltUnreadAboveViewport) {
      if (globalModel.hasLockedEntryUnreadFor(convId) &&
          globalModel.getMessageListPosition(convId) ==
              HistoryMessagePosition.bottom &&
          !_firstUnreadAnchorJumped) {
        _commitUnreadTongueMetrics(
          globalModel: globalModel,
          conversationID: convId,
          remaining: safeUnreadCount,
          below: false,
          safeUnreadCount: safeUnreadCount,
        );
        return;
      }
      _commitUnreadTongueMetrics(
        globalModel: globalModel,
        conversationID: convId,
        // Keep the count source consistent with the buffered unread state.
        // Returning zero here makes the tongue immediately rebound to the
        // global count on the next selector rebuild.
        remaining: safeUnreadCount,
        below: false,
        safeUnreadCount: safeUnreadCount,
      );
    }
  }

  void _commitUnreadTongueMetrics({
    required TUIChatGlobalModel globalModel,
    required String conversationID,
    required int remaining,
    required bool below,
    required int safeUnreadCount,
  }) {
    if (_lastUnreadTongueConversationID != conversationID) {
      _lastUnreadTongueConversationID = conversationID;
      _lastUnreadTongueRemaining = null;
      _lastUnreadTongueSafeCount = 0;
    }
    final safeRemaining = remaining.clamp(0, safeUnreadCount).toInt();
    var effectiveRemaining = safeRemaining;
    final lastRemaining = _lastUnreadTongueRemaining;
    // 滚动查看历史/向上翻旧消息时，提示条数字不能反向增加；
    // 它只表示“下面还剩多少条新消息没看”。真正收到的新消息会通过
    // safeUnreadCount 增长重新进入窗口，历史分页不会把数字越翻越大。
    if (lastRemaining != null &&
        safeUnreadCount <= _lastUnreadTongueSafeCount &&
        safeRemaining > lastRemaining) {
      effectiveRemaining = lastRemaining;
    }
    _lastUnreadTongueRemaining = effectiveRemaining;
    if (safeUnreadCount > _lastUnreadTongueSafeCount) {
      _lastUnreadTongueSafeCount = safeUnreadCount;
    }
    globalModel.setUnreadTongueMetrics(
      conversationID: conversationID,
      remaining: effectiveRemaining,
      below: below,
    );
  }

  void _bindActiveScrollController() {
    if (!mounted) return;
    final convId = _conversationId();
    if (convId.isEmpty) return;
    _chatGlobalModel?.bindActiveChatScrollController(
      conversationID: convId,
      scrollController: _autoScrollController,
    );
  }

  bool _shouldRunRowReveal({bool forLiveListPush = false}) {
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    if (!globalModel.shouldAnimateInboundPresentation ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return false;
    }
    if (globalModel.isBulkMessageSyncActive(_conversationId())) {
      return false;
    }
    if (_isSearchJumpStabilizing) {
      return false;
    }
    if (globalModel.isRestoringScrollAfterMediaPreview) {
      return false;
    }
    if (globalModel.isMessageContextMenuOverlayOpen) {
      return false;
    }
    if (!globalModel.chatConfig.messageEnterAnimationListPushEnabled) {
      return false;
    }
    // 短历史 / 进页 settle：收消息历史曾经为避免抢手势关掉 list-push，但发送会退回
    // 「气泡 slide + force-pin + 清 spacer」叠层抖动。直播插入统一走 list-push
    //（短列表用 row_reveal_grow，无二次滚底）。
    if (!forLiveListPush) {
      if (_mayUseShortHistoryTopAlignment()) {
        return false;
      }
      if (_isInitialRouteSettleWindow) {
        return false;
      }
    }
    final convId = _conversationId();
    if (globalModel.getMessageListPosition(convId) !=
        HistoryMessagePosition.bottom) {
      return false;
    }
    // 物理已离开底部超过约一屏：即使用户逻辑位姿仍是 bottom，也不上推。
    final scrollPosition = _singleScrollPositionOrNull();
    if (scrollPosition != null &&
        scrollPosition.hasPixels &&
        scrollPosition.hasContentDimensions &&
        !globalModel.isInboundPresentationBottomLocked(convId)) {
      final viewport = scrollPosition.viewportDimension;
      final distance = scrollPosition.pixels - scrollPosition.minScrollExtent;
      if (viewport > 0 && distance > viewport) {
        return false;
      }
    }
    return true;
  }

  bool _isWechatInsertAnimationStyle(TUIChatGlobalModel globalModel) {
    return globalModel.chatConfig.messageEnterAnimationStyle ==
        MessageEnterAnimationStyle.wechat;
  }

  bool _useWechatListPushTranslate(TUIChatGlobalModel globalModel) {
    return _isWechatInsertAnimationStyle(globalModel) &&
        globalModel.chatConfig.messageEnterAnimationListPushEnabled;
  }

  void _acknowledgeInboundProjectionRevealIfNeeded() {
    final globalModel = _chatGlobalModel;
    final convId = _conversationId();
    if (globalModel == null || convId.isEmpty) {
      return;
    }
    if (!globalModel.isInboundProjectionRevealWaiting(convId)) {
      return;
    }
    globalModel.completeInboundProjectionReveal(convId);
  }

  void _pinScrollToBottomImmediate() {
    final globalModel = _chatGlobalModel;
    if (globalModel == null ||
        !mounted ||
        _viewportInsert.viewportInsertSlideActive ||
        _isViewportInsertSettling()) {
      return;
    }
    if (!_shouldPinScrollToBottom(globalModel)) {
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return;
    }
    final target = position.minScrollExtent;
    if ((position.pixels - target).abs() > 0.5) {
      _geomJumpTo(target, reason: 'pin_bottom_immediate');
    }
    globalModel.setMessageListPosition(
      _conversationId(),
      HistoryMessagePosition.bottom,
      notify: false,
    );
  }

  double _estimatedInsertedExtent(List<V2TimMessage> messages) {
    final screenWidth = mounted ? MediaQuery.sizeOf(context).width : null;
    var extent = 0.0;
    for (final message in messages) {
      extent += ChatMessageHeightCache.instance.heightFor(message) ??
          ChatMessageHeightCache.instance.estimateRowHeight(
            message,
            screenWidth:
                screenWidth ?? ChatMessageHeightCache.defaultScreenWidth,
          ) ??
          _shortHistoryMessageEstimatedRowHeight;
    }
    return extent;
  }

  double? _cachedInsertedExtent(List<V2TimMessage> messages) {
    var extent = 0.0;
    for (final message in messages) {
      final key = _stableMessageListKey(message, 0);
      final revealedHeight = _viewportInsert.rowRevealFullExtentByKey[key];
      if (revealedHeight != null && revealedHeight > 0) {
        extent += revealedHeight;
        continue;
      }
      final height = ChatMessageHeightCache.instance.heightFor(message);
      if (height == null || height <= 0) {
        return null;
      }
      extent += height;
    }
    return extent > 0 ? extent : null;
  }

  /// 短消息 560px/s；气泡高度 ≥ 屏高 30% 视为长消息，720px/s。
  static const double _listPushTallBubbleViewportRatio = 0.30;
  static const double _listPushShortPixelsPerSecond = 560.0;
  static const double _listPushTallPixelsPerSecond = 720.0;

  double _listPushPixelsPerSecond({
    required double extent,
    required double viewportHeight,
  }) {
    if (viewportHeight <= 0 || extent <= 0) {
      return _listPushShortPixelsPerSecond;
    }
    if (extent / viewportHeight >= _listPushTallBubbleViewportRatio) {
      return _listPushTallPixelsPerSecond;
    }
    return _listPushShortPixelsPerSecond;
  }

  int _listPushDurationMs({
    required double motionExtent,
    required double viewportHeight,
  }) {
    final pps = _listPushPixelsPerSecond(
      extent: motionExtent,
      viewportHeight: viewportHeight,
    );
    final rawMs = ((motionExtent / pps) * 1000).round();
    // 高气泡上推更快：缩短上限，避免 clamp 到 1200ms 仍显慢。
    final maxMs =
        motionExtent >= viewportHeight * _listPushTallBubbleViewportRatio
            ? 700
            : 1200;
    return rawMs.clamp(160, maxMs);
  }

  /// didUpdateWidget 里、本帧 build 前调用：新行以 progress=0 进树，避免全高闪一帧。
  void _armZeroHeightViewportInsert(List<V2TimMessage> messages) {
    final controller = _viewportInsert.rowRevealController;
    if (controller == null || messages.isEmpty) {
      return;
    }
    if (controller.isAnimating ||
        _viewportInsert.activeRowRevealMessages.isNotEmpty) {
      _finishActiveRowRevealImmediately();
    }
    // 取消已排程的普通 row-reveal forward，避免抢同一 controller。
    ++_viewportInsert.rowRevealGeneration;
    _viewportInsert.activeRowRevealMessages.clear();
    final screenWidth = mounted ? MediaQuery.sizeOf(context).width : null;
    for (final message in messages) {
      // 长文本必须用真实屏宽估高；默认 390 会明显偏矮 → 上推后再长高 → 二次顶历史。
      if (screenWidth != null && screenWidth > 0) {
        ChatMessageHeightCache.instance.seedEstimateIfAbsent(
          message,
          screenWidth: screenWidth,
        );
      } else {
        ChatMessageHeightCache.instance.seedPlaceholderIfAbsent(message);
      }
      _viewportInsert
          .activeRowRevealMessages[_stableMessageListKey(message, 0)] = message;
    }
    _viewportInsert.suppressRowRevealStatus = true;
    controller.stop();
    controller.value = 0;
    _viewportInsert.suppressRowRevealStatus = false;
  }

  /// 把零高行一次撑满（不触发 status complete），供视口补偿滚动使用。
  void _expandArmedViewportInsertToFullHeight() {
    final controller = _viewportInsert.rowRevealController;
    if (controller == null || _viewportInsert.activeRowRevealMessages.isEmpty) {
      return;
    }
    _viewportInsert.suppressRowRevealStatus = true;
    controller.stop();
    controller.value = 1;
    _viewportInsert.suppressRowRevealStatus = false;
  }

  void _releaseArmedViewportInsertReveal() {
    final messages = _viewportInsert.takeArmedRevealMessages();
    if (messages.isEmpty) {
      return;
    }
    final globalModel = _chatGlobalModel ??
        (mounted
            ? Provider.of<TUIChatGlobalModel>(context, listen: false)
            : null);
    if (globalModel != null) {
      for (final message in messages) {
        _viewportInsert.rowRevealFullExtentByKey.remove(
          _stableMessageListKey(message, 0),
        );
        globalModel.finishMessageEnterAnimation(message);
      }
      globalModel.completeInboundProjectionReveal(_conversationId());
    }
    _viewportInsert.snapRevealControllerComplete();
  }

  void _beginMediaSettleForMessages(
    List<V2TimMessage> messages, {
    int? holdMs,
  }) {
    _viewportInsert.beginMediaSettleForKeys(
      messages.map((message) => _stableMessageListKey(message, 0)),
      holdMs: holdMs,
    );
  }

  bool _isMediaSettlingForKey(String key) =>
      _viewportInsert.isMediaSettlingForKey(key);

  void _silentAbsorbExtentDelta(double delta) {
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return;
    }
    if (delta.abs() < 0.5) {
      return;
    }
    // reverse 列表贴底（pixels==min）时底边就是布局锚点：行高无论变高还是
    // 变矮，viewport 底部内容都不动，任何 correctBy 都是反向制造位移——
    // 变高会修成负 offset（进页 scrollPx -4~-46 的过滚缺口，随后被 pin 弹回，
    // 即肉眼可见的「抖」）；变矮会把列表修离底部（日志里停在 16.8px）。
    if (position.pixels <= position.minScrollExtent + 0.5) {
      return;
    }
    // 离底时（上推动画/settle 中）照常吸收，但修正量夹在滚动范围内，
    // 防止把 offset 推进过滚区。
    final target = (position.pixels - delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final correction = target - position.pixels;
    if (correction.abs() < 0.5) {
      return;
    }
    try {
      position.correctBy(correction);
    } catch (_) {
      final target = position.minScrollExtent;
      if ((position.pixels - target).abs() > 0.5) {
        _geomJumpTo(target, reason: 'jump__silentAbsorbExtentDelta');
      }
    }
  }

  bool _shouldSuppressContinuousInitialHeightCorrection(String rowKey) {
    final until = _viewportInsert
            .continuousViewportPushInitialLayoutUntilMsByKey[rowKey] ??
        0;
    if (until <= 0) {
      return false;
    }
    if (DateTime.now().millisecondsSinceEpoch < until) {
      return true;
    }
    _viewportInsert.continuousViewportPushInitialLayoutUntilMsByKey
        .remove(rowKey);
    return false;
  }

  void _snapArmedViewportInsertRevealOpen() {
    final controller = _viewportInsert.rowRevealController;
    if (_viewportInsert.activeRowRevealMessages.isEmpty) {
      return;
    }
    if (controller != null) {
      controller.stop();
      if (controller.value < 1) {
        controller.value = 1;
      }
    }
    if (_viewportInsert.activeRowRevealMessages.isNotEmpty) {
      _completeRowRevealTransaction();
    }
  }

  void _beginInboundViewportPushPresentation() {
    final model = _chatGlobalModel ??
        (mounted
            ? Provider.of<TUIChatGlobalModel>(context, listen: false)
            : null);
    model?.beginInboundViewportPush(_conversationId());
  }

  void _endInboundViewportPushPresentation() {
    final model = _chatGlobalModel ??
        (mounted
            ? Provider.of<TUIChatGlobalModel>(context, listen: false)
            : null);
    model?.endInboundViewportPush(_conversationId());
  }

  void _queueViewportInsertMessages(List<V2TimMessage> messages) {
    final screenWidth = mounted ? MediaQuery.sizeOf(context).width : null;
    final suppressInitialLayoutUntil = DateTime.now().millisecondsSinceEpoch +
        _continuousViewportPushInitialLayoutSuppressMs;
    for (final message in messages) {
      if (screenWidth != null && screenWidth > 0) {
        ChatMessageHeightCache.instance.seedEstimateIfAbsent(
          message,
          screenWidth: screenWidth,
        );
      } else {
        ChatMessageHeightCache.instance.seedPlaceholderIfAbsent(message);
      }
      final rowKey = _stableMessageListKey(message, 0);
      _viewportInsert.queuedViewportInsertMessages[rowKey] = message;
      // 必须在零高行首次布局前标记。若等到 commit 才标记，placeholder ->
      // 实测高度产生的 silentAbsorb 已在上一帧排队，会与 fullExtent 重复补偿。
      _viewportInsert.continuousViewportPushInitialLayoutUntilMsByKey[rowKey] =
          suppressInitialLayoutUntil;
    }
    ChatJitterDiag.logInboundFlow(
      action: 'viewport_slide_queue',
      conv: _conversationId(),
      extras: <String, Object?>{
        'added': messages.length,
        'queued': _viewportInsert.queuedViewportInsertMessages.length,
        'generation': _viewportInsert.viewportInsertSlideGeneration,
        'cvpTx': _viewportInsert.continuousViewportPushDiagTransaction,
      },
    );
  }

  void _drainQueuedViewportInsertMessages() {
    if (!mounted || _viewportInsert.queuedViewportInsertMessages.isEmpty) {
      return;
    }
    final queued = List<V2TimMessage>.from(
        _viewportInsert.queuedViewportInsertMessages.values);
    _viewportInsert.queuedViewportInsertMessages.clear();
    _startWechatViewportInsertSlide(queued);
    // 排队行先前绑定的是静止 0；重建后才会绑定本轮 controller。
    if (mounted) {
      setState(() {});
    }
  }

  void _startContinuousViewportInsertPush(List<V2TimMessage> messages) {
    final position = _singleScrollPositionOrNull();
    if (messages.isEmpty ||
        position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      _finishIncomingMessagesWithoutRowReveal(messages);
      return;
    }

    // 内容尚未铺满视口时没有可校正的 scroll extent，沿用短列表 grow。
    if (!_viewportInsert.continuousViewportPushActive &&
        position.maxScrollExtent <= position.minScrollExtent + 0.5) {
      _startWechatViewportInsertSlide(messages);
      return;
    }

    final model = _chatGlobalModel ??
        Provider.of<TUIChatGlobalModel>(context, listen: false);
    _lastHandledPinSeq = model.pinToBottomRequestSeq;
    _cancelForcePinScroll();

    if (!_viewportInsert.continuousViewportPushActive) {
      if (_viewportInsert.activeRowRevealMessages.isNotEmpty ||
          (_viewportInsert.rowRevealController?.isAnimating ?? false)) {
        _finishActiveRowRevealImmediately();
      }
      _viewportInsert.continuousViewportPushActive = true;
      _viewportInsert.viewportInsertSlideActive = true;
      ++_viewportInsert.viewportInsertSlideGeneration;
      ++_viewportInsert.continuousViewportPushDiagTransaction;
      _viewportInsert.continuousViewportPushDiagFrame = 0;
      _viewportInsert.continuousViewportPushLastCommandedPixels =
          position.pixels;
      _beginInboundViewportPushPresentation();
      _viewportInsert.continuousViewportPushTicker ??=
          createTicker(_onContinuousViewportPushTick);
      ChatJitterDiag.logInboundFlow(
        action: 'continuous_viewport_push_begin',
        conv: _conversationId(),
        extras: <String, Object?>{
          'pixels': position.pixels.toStringAsFixed(1),
          'minExtent': position.minScrollExtent.toStringAsFixed(1),
          'maxExtent': position.maxScrollExtent.toStringAsFixed(1),
          'viewport': position.viewportDimension.toStringAsFixed(1),
          'cvpTx': _viewportInsert.continuousViewportPushDiagTransaction,
        },
      );
    }

    _queueViewportInsertMessages(messages);
    _scheduleContinuousViewportPushIntegration();
  }

  void _scheduleContinuousViewportPushIntegration({int attempt = 0}) {
    if (_viewportInsert.continuousViewportPushIntegrationScheduled ||
        _viewportInsert.queuedViewportInsertMessages.isEmpty) {
      return;
    }
    _viewportInsert.continuousViewportPushIntegrationScheduled = true;
    final generation =
        ++_viewportInsert.continuousViewportPushIntegrationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportInsert.continuousViewportPushIntegrationScheduled = false;
      if (!mounted ||
          !_viewportInsert.continuousViewportPushActive ||
          generation !=
              _viewportInsert.continuousViewportPushIntegrationGeneration ||
          _viewportInsert.queuedViewportInsertMessages.isEmpty) {
        return;
      }

      final measuredEntries = List<MapEntry<String, V2TimMessage>>.from(
        _viewportInsert.queuedViewportInsertMessages.entries,
      );
      var fullExtent = 0.0;
      var allMeasured = true;
      for (final entry in measuredEntries) {
        final height = _viewportInsert.rowRevealFullExtentByKey[entry.key];
        if (height == null || height <= 0.5) {
          allMeasured = false;
          break;
        }
        fullExtent += height;
      }
      if (!allMeasured || fullExtent <= 0.5) {
        if (attempt < _continuousViewportPushMeasureMaxAttempts) {
          _scheduleContinuousViewportPushIntegration(attempt: attempt + 1);
        } else {
          final pending = List<V2TimMessage>.from(
              _viewportInsert.queuedViewportInsertMessages.values);
          _viewportInsert.queuedViewportInsertMessages.clear();
          _finishIncomingMessagesWithoutRowReveal(pending);
          _finishContinuousViewportPush(
            reachedBottom: false,
            forcePinOnMiss: true,
          );
        }
        return;
      }

      SchedulerBinding.instance.scheduleFrameCallback((_) {
        if (!mounted ||
            !_viewportInsert.continuousViewportPushActive ||
            generation !=
                _viewportInsert.continuousViewportPushIntegrationGeneration) {
          return;
        }
        final currentPosition = _singleScrollPositionOrNull();
        if (currentPosition == null ||
            !currentPosition.hasPixels ||
            !currentPosition.hasContentDimensions ||
            (_chatGlobalModel?.isChatListUserScrolling ?? false)) {
          _finishContinuousViewportPush(reachedBottom: false);
          return;
        }

        final committed =
            measuredEntries.map((entry) => entry.value).toList(growable: false);
        final committedKeys = measuredEntries.map((entry) => entry.key).toSet();

        // 真实高度已在零高帧完成测量。frame callback 发生在 layout/paint 前：
        // 先修正 offset，再让这些行以全高重建，同一帧互相抵消，不产生可见 jump。
        final pixelsBeforeCorrection = currentPosition.pixels;
        final minBeforeCorrection = currentPosition.minScrollExtent;
        final maxBeforeCorrection = currentPosition.maxScrollExtent;
        ChatJitterDiag.logInboundFlow(
          action: 'cvp_integrate_before',
          conv: _conversationId(),
          extras: <String, Object?>{
            'cvpTx': _viewportInsert.continuousViewportPushDiagTransaction,
            'rows': committed.length,
            'measuredExtent': fullExtent.toStringAsFixed(2),
            'pixels': pixelsBeforeCorrection.toStringAsFixed(2),
            'min': minBeforeCorrection.toStringAsFixed(2),
            'max': maxBeforeCorrection.toStringAsFixed(2),
            'viewport': currentPosition.viewportDimension.toStringAsFixed(2),
            'outOfRange': currentPosition.outOfRange,
            'queuedTotal': _viewportInsert.queuedViewportInsertMessages.length,
          },
        );
        currentPosition.correctBy(fullExtent);
        _viewportInsert.continuousViewportPushLastCommandedPixels =
            currentPosition.pixels;
        ChatJitterDiag.logInboundFlow(
          action: 'cvp_integrate_after_correct',
          conv: _conversationId(),
          extras: <String, Object?>{
            'cvpTx': _viewportInsert.continuousViewportPushDiagTransaction,
            'requestedCorrection': fullExtent.toStringAsFixed(2),
            'pixelsBefore': pixelsBeforeCorrection.toStringAsFixed(2),
            'pixelsAfter': currentPosition.pixels.toStringAsFixed(2),
            'appliedCorrection':
                (currentPosition.pixels - pixelsBeforeCorrection)
                    .toStringAsFixed(2),
            'maxStill': currentPosition.maxScrollExtent.toStringAsFixed(2),
            'outOfRange': currentPosition.outOfRange,
          },
        );
        for (final key in committedKeys) {
          _viewportInsert.queuedViewportInsertMessages.remove(key);
        }
        for (final entry in measuredEntries) {
          if (!committedKeys.contains(entry.key)) {
            continue;
          }
          final height = _viewportInsert.rowRevealFullExtentByKey[entry.key];
          if (height != null && height > 0.5) {
            _viewportInsert.continuousViewportPushRemainingRowExtents
                .add(height);
          }
        }
        final globalModel = _chatGlobalModel;
        if (globalModel != null) {
          for (final message in committed) {
            globalModel.finishMessageEnterAnimation(message);
          }
          globalModel.completeInboundProjectionReveal(_conversationId());
        }
        for (final key in committedKeys) {
          _viewportInsert.rowRevealFullExtentByKey.remove(key);
        }
        final suppressInitialLayoutUntil =
            DateTime.now().millisecondsSinceEpoch +
                _continuousViewportPushInitialLayoutSuppressMs;
        for (final key in committedKeys) {
          _viewportInsert.continuousViewportPushInitialLayoutUntilMsByKey[key] =
              suppressInitialLayoutUntil;
        }
        _beginMediaSettleForMessages(committed, holdMs: 1200);
        if (mounted) {
          setState(() {});
        }
        ChatJitterDiag.logInboundFlow(
          action: 'continuous_viewport_push_integrate',
          conv: _conversationId(),
          extras: <String, Object?>{
            'rows': committed.length,
            'extent': fullExtent.toStringAsFixed(1),
            'pixels': currentPosition.pixels.toStringAsFixed(1),
            'cvpTx': _viewportInsert.continuousViewportPushDiagTransaction,
          },
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          final laidOutPosition = _singleScrollPositionOrNull();
          if (laidOutPosition == null ||
              !laidOutPosition.hasPixels ||
              !laidOutPosition.hasContentDimensions) {
            return;
          }
          ChatJitterDiag.logInboundFlow(
            action: 'cvp_integrate_post_layout',
            conv: _conversationId(),
            extras: <String, Object?>{
              'cvpTx': _viewportInsert.continuousViewportPushDiagTransaction,
              'measuredExtent': fullExtent.toStringAsFixed(2),
              'pixelsBefore': pixelsBeforeCorrection.toStringAsFixed(2),
              'pixelsAfter': laidOutPosition.pixels.toStringAsFixed(2),
              'pixelsDelta': (laidOutPosition.pixels - pixelsBeforeCorrection)
                  .toStringAsFixed(2),
              'maxBefore': maxBeforeCorrection.toStringAsFixed(2),
              'maxAfter': laidOutPosition.maxScrollExtent.toStringAsFixed(2),
              'maxDelta':
                  (laidOutPosition.maxScrollExtent - maxBeforeCorrection)
                      .toStringAsFixed(2),
              'extentError': (laidOutPosition.maxScrollExtent -
                      maxBeforeCorrection -
                      fullExtent)
                  .toStringAsFixed(2),
              'outOfRange': laidOutPosition.outOfRange,
            },
          );
        });
        final pendingDistance =
            currentPosition.pixels - currentPosition.minScrollExtent;
        if (currentPosition.viewportDimension > 0 &&
            pendingDistance > currentPosition.viewportDimension) {
          ChatJitterDiag.logInboundFlow(
            action: 'continuous_viewport_push_burst_freeze',
            conv: _conversationId(),
            extras: <String, Object?>{
              'distance': pendingDistance.toStringAsFixed(1),
              'viewport': currentPosition.viewportDimension.toStringAsFixed(1),
            },
          );
          if (_viewportInsert.queuedViewportInsertMessages.isNotEmpty) {
            _scheduleContinuousViewportPushIntegration();
            return;
          }
          _finishContinuousViewportPush(reachedBottom: false);
          return;
        }
        _startContinuousViewportPushTicker();
        if (_viewportInsert.queuedViewportInsertMessages.isNotEmpty) {
          _scheduleContinuousViewportPushIntegration();
        }
      });
    });
  }

  void _startContinuousViewportPushTicker() {
    // Ticker.start 会以当前帧为时间原点。预置 zero 后，下一次 vsync 可直接
    // 使用首段 elapsed；旧逻辑首个 callback 只赋值后 return，白白空转一帧。
    _viewportInsert.startContinuousViewportPushTicker();
  }

  /// 按积压气泡行数选速：1 行 ~500px/s，升到 4 行 ~920px/s。
  /// pendingRows = 已提交未消化行 + 仍在零高队列的行。
  double _continuousViewportPushSpeedPxPerSec() =>
      _viewportInsert.continuousViewportPushSpeedPxPerSec();

  void _consumeContinuousViewportPushTravel(double travel) {
    _viewportInsert.consumeContinuousViewportPushTravel(travel);
  }

  void _onContinuousViewportPushTick(Duration elapsed) {
    if (!mounted || !_viewportInsert.continuousViewportPushActive) {
      _viewportInsert.continuousViewportPushTicker?.stop();
      return;
    }
    final globalModel = _chatGlobalModel;
    if (globalModel == null || globalModel.isChatListUserScrolling) {
      _finishContinuousViewportPush(reachedBottom: false);
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      _finishContinuousViewportPush(reachedBottom: false);
      return;
    }
    final previousElapsed = _viewportInsert.continuousViewportPushLastElapsed;
    _viewportInsert.continuousViewportPushLastElapsed = elapsed;
    if (previousElapsed == null) {
      return;
    }
    final elapsedMicros =
        (elapsed - previousElapsed).inMicroseconds.clamp(0, 50000);
    final pendingRows =
        _viewportInsert.continuousViewportPushRemainingRowExtents.length +
            _viewportInsert.queuedViewportInsertMessages.length;
    final speed = _continuousViewportPushSpeedPxPerSec();
    final travel = speed * elapsedMicros / 1000000;
    final pixelsBefore = position.pixels;
    final externalDrift =
        _viewportInsert.continuousViewportPushLastCommandedPixels == null
            ? 0.0
            : pixelsBefore -
                _viewportInsert.continuousViewportPushLastCommandedPixels!;
    final target =
        max(position.minScrollExtent, position.pixels - travel).toDouble();
    if ((position.pixels - target).abs() > 0.1) {
      _geomJumpTo(target, reason: 'cvp_tick');
    }
    final pixelsAfter =
        _singleScrollPositionOrNull()?.pixels ?? position.pixels;
    final actualTravel = pixelsBefore - pixelsAfter;
    _consumeContinuousViewportPushTravel(actualTravel);
    _viewportInsert.continuousViewportPushLastCommandedPixels = pixelsAfter;
    final reachedBottom = (target - position.minScrollExtent).abs() <= 0.5;
    final frame = ++_viewportInsert.continuousViewportPushDiagFrame;
    // debugPrint 会在 UI isolate 上格式化并节流。120Hz 下逐帧记录会反过来制造
    // 动画卡顿；仅保留起始帧、每 15 帧采样、异常漂移和结束帧。
    final shouldLogTick = frame <= 3 ||
        frame % 15 == 0 ||
        externalDrift.abs() > 0.5 ||
        reachedBottom;
    if (shouldLogTick) {
      ChatJitterDiag.logInboundFlow(
        action: 'cvp_tick',
        conv: _conversationId(),
        extras: <String, Object?>{
          'cvpTx': _viewportInsert.continuousViewportPushDiagTransaction,
          'tick': frame,
          'elapsedUs': elapsedMicros,
          'pendingRows': pendingRows,
          'speed': speed.toStringAsFixed(1),
          'requestedTravel': travel.toStringAsFixed(2),
          'pixelsBefore': pixelsBefore.toStringAsFixed(2),
          'target': target.toStringAsFixed(2),
          'pixelsAfter': pixelsAfter.toStringAsFixed(2),
          'actualTravel': actualTravel.toStringAsFixed(2),
          'externalDriftSinceLastTick': externalDrift.toStringAsFixed(2),
          'min': position.minScrollExtent.toStringAsFixed(2),
          'max': position.maxScrollExtent.toStringAsFixed(2),
          'viewport': position.viewportDimension.toStringAsFixed(2),
          'queued': _viewportInsert.queuedViewportInsertMessages.length,
          'integrationScheduled':
              _viewportInsert.continuousViewportPushIntegrationScheduled,
          'outOfRange': position.outOfRange,
        },
      );
    }
    if (reachedBottom &&
        _viewportInsert.queuedViewportInsertMessages.isEmpty &&
        !_viewportInsert.continuousViewportPushIntegrationScheduled) {
      _finishContinuousViewportPush(reachedBottom: true);
    }
  }

  void _finishContinuousViewportPush({
    required bool reachedBottom,
    bool forcePinOnMiss = false,
  }) {
    if (!_viewportInsert.continuousViewportPushActive) {
      return;
    }
    _viewportInsert.continuousViewportPushTicker?.stop();
    _viewportInsert.continuousViewportPushLastElapsed = null;
    _viewportInsert.continuousViewportPushLastCommandedPixels = null;
    _viewportInsert.continuousViewportPushActive = false;
    _viewportInsert.viewportInsertSlideActive = false;
    _viewportInsert.continuousViewportPushIntegrationScheduled = false;
    _viewportInsert.continuousViewportPushInitialLayoutUntilMsByKey.clear();
    _viewportInsert.continuousViewportPushRemainingRowExtents.clear();
    ++_viewportInsert.continuousViewportPushIntegrationGeneration;
    _beginViewportInsertSettle();
    _cancelForcePinScroll();
    if (_viewportInsert.queuedViewportInsertMessages.isNotEmpty) {
      final pending = List<V2TimMessage>.from(
          _viewportInsert.queuedViewportInsertMessages.values);
      _finishIncomingMessagesWithoutRowReveal(pending);
      if (mounted) {
        setState(() {});
      }
    }
    final globalModel = _chatGlobalModel;
    final shouldForcePinOnMiss = forcePinOnMiss &&
        !reachedBottom &&
        mounted &&
        !(globalModel?.isChatListUserScrolling ?? false);
    if (reachedBottom && globalModel != null) {
      globalModel.setMessageListPosition(
        _conversationId(),
        HistoryMessagePosition.bottom,
        notify: false,
      );
    } else if (globalModel != null && !shouldForcePinOnMiss) {
      final position = _singleScrollPositionOrNull();
      if (position != null &&
          position.hasPixels &&
          position.hasContentDimensions) {
        final distance = position.pixels - position.minScrollExtent;
        final nextPosition = position.viewportDimension > 0 &&
                distance > position.viewportDimension
            ? HistoryMessagePosition.awayTwoScreen
            : HistoryMessagePosition.inTwoScreen;
        globalModel.setMessageListPosition(
          _conversationId(),
          nextPosition,
          notify: false,
        );
        if (nextPosition == HistoryMessagePosition.awayTwoScreen) {
          // correctBy 是静默修正，不会产生 ScrollNotification。爆发冻结后补发一次
          // 同位置通知，让 tongue 立即按“一屏外”状态显示回到底部入口。
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            final settledPosition = _singleScrollPositionOrNull();
            if (settledPosition != null && settledPosition.hasPixels) {
              _geomJumpTo(settledPosition.pixels,
                  reason: 'jump__finishIncomingMessagesWithoutRowReveal');
            }
          });
        }
      }
    }
    _endInboundViewportPushPresentation();
    ChatJitterDiag.logInboundFlow(
      action: 'continuous_viewport_push_end',
      conv: _conversationId(),
      extras: <String, Object?>{
        'cvpTx': _viewportInsert.continuousViewportPushDiagTransaction,
        'ticks': _viewportInsert.continuousViewportPushDiagFrame,
        'reachedBottom': reachedBottom,
        'forcePinOnMiss': shouldForcePinOnMiss,
        'queued': _viewportInsert.queuedViewportInsertMessages.length,
        'pixels': _singleScrollPositionOrNull()?.pixels.toStringAsFixed(2),
        'min':
            _singleScrollPositionOrNull()?.minScrollExtent.toStringAsFixed(2),
        'max':
            _singleScrollPositionOrNull()?.maxScrollExtent.toStringAsFixed(2),
      },
    );
    if (shouldForcePinOnMiss) {
      ChatJitterDiag.logInboundFlow(
        action: 'cvp_measure_miss_force_pin',
        conv: _conversationId(),
        extras: <String, Object?>{
          'cvpTx': _viewportInsert.continuousViewportPushDiagTransaction,
        },
      );
      _scheduleForcePinScrollToBottom(ignoreInsertWindows: true);
    }
  }

  void _startWechatViewportInsertSlide(List<V2TimMessage> messages) {
    if (_viewportInsert.viewportInsertSlideActive) {
      _queueViewportInsertMessages(messages);
      return;
    }
    final controller = _viewportInsert.rowRevealController;
    final beforePosition = _singleScrollPositionOrNull();
    if (messages.isEmpty ||
        controller == null ||
        beforePosition == null ||
        !beforePosition.hasPixels ||
        !beforePosition.hasContentDimensions) {
      _finishIncomingMessagesWithoutRowReveal(messages);
      return;
    }

    // 发送会同时 requestPinToBottom(force)。先消费掉这次 pin，避免
    // cancel 之后又被 _onPinToBottomRequested 重新 schedule，和上推动画抢滚。
    final pinModel = _chatGlobalModel ??
        (mounted
            ? Provider.of<TUIChatGlobalModel>(context, listen: false)
            : null);
    if (pinModel != null) {
      _lastHandledPinSeq = pinModel.pinToBottomRequestSeq;
    }
    _cancelForcePinScroll();

    // 上推会短暂 jump 离底；先锁贴底语义，避免右侧「回到底部」闪一下。
    _beginInboundViewportPushPresentation();

    // Build 前零高：本帧不把旧消息顶走。
    _armZeroHeightViewportInsert(messages);

    final oldPixels = beforePosition.pixels;
    final oldMaxScrollExtent = beforePosition.maxScrollExtent;
    final generation = ++_viewportInsert.viewportInsertSlideGeneration;
    _viewportInsert.viewportInsertSlideActive = true;
    ChatJitterDiag.logInboundFlow(
      action: 'viewport_slide_schedule',
      conv: _conversationId(),
      extras: <String, Object?>{
        'rows': messages.length,
        'pixels': oldPixels.toStringAsFixed(1),
        'minExtent': beforePosition.minScrollExtent.toStringAsFixed(1),
        'maxExtent': oldMaxScrollExtent.toStringAsFixed(1),
        'armedZeroHeight': true,
        'hasOutgoing': messages.any((m) => m.isSelf == true),
        'mode': 'viewport_scroll',
        'generation': generation,
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          generation != _viewportInsert.viewportInsertSlideGeneration) {
        // 被更新一轮覆盖时，由新一代持有锁；勿 end 掉新锁。
        return;
      }

      var position = _singleScrollPositionOrNull();
      if (position == null ||
          !position.hasPixels ||
          !position.hasContentDimensions) {
        _viewportInsert.viewportInsertSlideActive = false;
        _releaseArmedViewportInsertReveal();
        _endInboundViewportPushPresentation();
        return;
      }

      if (_chatGlobalModel?.isChatListUserScrolling ?? false) {
        _viewportInsert.viewportInsertSlideActive = false;
        _releaseArmedViewportInsertReveal();
        _endInboundViewportPushPresentation();
        return;
      }

      final cachedExtent = _cachedInsertedExtent(messages);
      final estimatedExtent = _estimatedInsertedExtent(messages);
      var chosenExtent = (cachedExtent != null && cachedExtent > 0)
          ? cachedExtent
          : estimatedExtent;
      if (chosenExtent <= 0.5) {
        chosenExtent = _shortHistoryMessageEstimatedRowHeight;
      }

      final viewportHeight = position.viewportDimension;
      // 能否补偿要看「展开后」的可滚空间。旧逻辑用展开前 maxScrollExtent：
      // 当气泡高度 > 当前剩余可滚高度时会误判 no_scroll_room → grow，
      // 整段可见历史会被 SizeTransition 一起顶走。
      // 列表已可滚（oldMax > 0）时，expand 后 max 大约 +chosenExtent，应走 atomic。
      // 仅短列表（内容未铺满视口、max≈0）才走零→满 grow。
      final canCompensateJump = oldMaxScrollExtent > 0.5 &&
          (oldPixels + chosenExtent) > position.minScrollExtent + 0.5;

      // 短列表无滚动空间：收/发都走零→满 grow，直接从底部顶起。
      // 有空间时收/发统一走下方 atomic（expand 后同帧实测 jump + animateTo），
      // 不再把发送单独拆成 grow，否则观感会分叉。
      if (!canCompensateJump) {
        final durationMs = _listPushDurationMs(
          motionExtent: chosenExtent,
          viewportHeight: viewportHeight,
        );
        ChatJitterDiag.logInboundFlow(
          action: 'viewport_slide_start',
          conv: _conversationId(),
          extras: <String, Object?>{
            'rows': messages.length,
            'chosenExtent': chosenExtent.toStringAsFixed(1),
            'durationMs': durationMs,
            'mode': 'row_reveal_grow',
            'reason': 'no_scroll_room',
            'hasOutgoing': messages.any((m) => m.isSelf == true),
          },
        );
        controller.duration = Duration(milliseconds: durationMs);
        try {
          await controller.forward(from: 0);
        } catch (_) {
        } finally {
          if (mounted &&
              generation == _viewportInsert.viewportInsertSlideGeneration) {
            _viewportInsert.viewportInsertSlideActive = false;
            _beginViewportInsertSettle();
            // 收尾仍保持一段 absorb 窗，避免 grow 结束后二次 layout 再 pin 顶历史。
            _beginMediaSettleForMessages(messages, holdMs: 900);
            _cancelForcePinScroll();
            if (_viewportInsert.activeRowRevealMessages.isNotEmpty) {
              _releaseArmedViewportInsertReveal();
            } else {
              _acknowledgeInboundProjectionRevealIfNeeded();
            }
            _drainQueuedViewportInsertMessages();
            _endInboundViewportPushPresentation();
            ChatJitterDiag.logInboundFlow(
              action: 'viewport_slide_end',
              conv: _conversationId(),
              extras: <String, Object?>{
                'mode': 'row_reveal_grow',
                'generation': generation,
              },
            );
          }
        }
        return;
      }

      // 收/发统一：撑满后 flushLayout 用实测高度 jump，再 animateTo 从底部上推。
      _expandArmedViewportInsertToFullHeight();
      try {
        RendererBinding.instance.pipelineOwner.flushLayout();
      } catch (_) {
        // Layout pipeline may be unavailable in rare teardown races.
      }

      position = _singleScrollPositionOrNull();
      if (position == null ||
          !position.hasPixels ||
          !position.hasContentDimensions) {
        _viewportInsert.viewportInsertSlideActive = false;
        _releaseArmedViewportInsertReveal();
        _endInboundViewportPushPresentation();
        return;
      }

      final measuredExtent =
          max(0.0, position.maxScrollExtent - oldMaxScrollExtent);
      // 补偿只能使用真实 layout 高度。预估偏大时 jump 会把历史向下拉一帧，
      // 随后的 animateTo 又向上推，正是录像里的方向反转。
      final pushExtent =
          measuredExtent > 0.5 ? measuredExtent : (cachedExtent ?? 0.0);
      if (pushExtent <= 0.5) {
        ChatJitterDiag.logInboundFlow(
          action: 'viewport_slide_no_measured_extent',
          conv: _conversationId(),
          extras: <String, Object?>{
            'estimatedExtent': estimatedExtent.toStringAsFixed(1),
            'measuredExtent': measuredExtent.toStringAsFixed(1),
          },
        );
        _viewportInsert.viewportInsertSlideActive = false;
        _beginViewportInsertSettle();
        _beginMediaSettleForMessages(messages, holdMs: 900);
        if (_viewportInsert.activeRowRevealMessages.isNotEmpty) {
          _releaseArmedViewportInsertReveal();
        }
        _drainQueuedViewportInsertMessages();
        _endInboundViewportPushPresentation();
        return;
      }
      // 展开后若仍几乎跳不动（极端短列表误判），回退 grow，避免「闪全高」。
      final predictedStart = oldPixels + pushExtent;
      if (predictedStart > position.maxScrollExtent + 0.5 &&
          (position.maxScrollExtent - position.minScrollExtent) < 0.5) {
        ChatJitterDiag.logInboundFlow(
          action: 'viewport_slide_fallback_grow',
          conv: _conversationId(),
          extras: <String, Object?>{
            'pushExtent': pushExtent.toStringAsFixed(1),
            'maxExtent': position.maxScrollExtent.toStringAsFixed(1),
          },
        );
        // 已 expand 到 1：直接收尾，不再二次动画顶历史。
        _viewportInsert.viewportInsertSlideActive = false;
        _beginViewportInsertSettle();
        _beginMediaSettleForMessages(messages, holdMs: 900);
        _cancelForcePinScroll();
        if (_viewportInsert.activeRowRevealMessages.isNotEmpty) {
          _releaseArmedViewportInsertReveal();
        } else {
          _acknowledgeInboundProjectionRevealIfNeeded();
        }
        _drainQueuedViewportInsertMessages();
        _endInboundViewportPushPresentation();
        return;
      }
      final start = (oldPixels + pushExtent).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _geomJumpTo(start.toDouble(),
          reason: 'jump__releaseArmedViewportInsertReveal');
      position = _singleScrollPositionOrNull() ?? position;

      // 上推过程中文本还可能继续长高，提前进入 media-settle，走 silentAbsorb。
      _beginMediaSettleForMessages(messages, holdMs: 1200);

      if (!mounted ||
          generation != _viewportInsert.viewportInsertSlideGeneration) {
        return;
      }

      if (_chatGlobalModel?.isChatListUserScrolling ?? false) {
        _viewportInsert.viewportInsertSlideActive = false;
        _releaseArmedViewportInsertReveal();
        _endInboundViewportPushPresentation();
        return;
      }

      final travel = max(0.0, position.pixels - position.minScrollExtent);
      final motionExtent = travel > 0.5 ? travel : pushExtent;
      final target = position.minScrollExtent;
      final animateViewportHeight = position.viewportDimension;
      final animateDurationMs = _listPushDurationMs(
        motionExtent: motionExtent,
        viewportHeight: animateViewportHeight,
      );

      ChatJitterDiag.logInboundFlow(
        action: 'viewport_slide_start',
        conv: _conversationId(),
        extras: <String, Object?>{
          'rows': messages.length,
          'estimatedExtent': estimatedExtent.toStringAsFixed(1),
          'cachedExtent': cachedExtent?.toStringAsFixed(1),
          'measuredExtent': measuredExtent.toStringAsFixed(1),
          'chosenExtent': chosenExtent.toStringAsFixed(1),
          'pushExtent': pushExtent.toStringAsFixed(1),
          'motionExtent': motionExtent.toStringAsFixed(1),
          'viewportHeight': animateViewportHeight.toStringAsFixed(1),
          'pps': _listPushPixelsPerSecond(
            extent: motionExtent,
            viewportHeight: animateViewportHeight,
          ).toStringAsFixed(0),
          'start': position.pixels.toStringAsFixed(1),
          'target': target.toStringAsFixed(1),
          'durationMs': animateDurationMs,
          'mode': 'viewport_scroll_atomic',
        },
      );

      _beginMediaSettleForMessages(
        messages,
        holdMs: max(_mediaSettleMs, animateDurationMs + 400),
      );

      try {
        await _autoScrollController.animateTo(
          target,
          duration: Duration(milliseconds: animateDurationMs),
          curve: Curves.linear,
        );
      } catch (_) {
      } finally {
        if (mounted &&
            generation == _viewportInsert.viewportInsertSlideGeneration) {
          _viewportInsert.viewportInsertSlideActive = false;
          _beginViewportInsertSettle();
          // 注意：不要用默认 400ms 覆盖上面的长窗，否则晚到的长高会走 pin 再顶历史。
          _beginMediaSettleForMessages(messages, holdMs: 1200);
          _cancelForcePinScroll();
          if (_viewportInsert.activeRowRevealMessages.isNotEmpty) {
            _releaseArmedViewportInsertReveal();
          } else {
            _acknowledgeInboundProjectionRevealIfNeeded();
          }
          _drainQueuedViewportInsertMessages();
          final globalModel = _chatGlobalModel;
          final endPosition = _singleScrollPositionOrNull();
          final reachedBottom = endPosition != null &&
              endPosition.hasPixels &&
              (endPosition.pixels - endPosition.minScrollExtent).abs() <= 1 &&
              !(globalModel?.isChatListUserScrolling ?? false);
          if (globalModel != null && reachedBottom) {
            globalModel.setMessageListPosition(
              _conversationId(),
              HistoryMessagePosition.bottom,
              notify: false,
            );
          }
          _endInboundViewportPushPresentation();
          ChatJitterDiag.logInboundFlow(
            action: 'viewport_slide_end',
            conv: _conversationId(),
            extras: <String, Object?>{
              'reachedBottom': reachedBottom,
              'pixels': endPosition?.hasPixels == true
                  ? endPosition!.pixels.toStringAsFixed(1)
                  : 'n/a',
              'minExtent': endPosition?.hasContentDimensions == true
                  ? endPosition!.minScrollExtent.toStringAsFixed(1)
                  : 'n/a',
              'userScrolling': globalModel?.isChatListUserScrolling,
              'generation': generation,
              'mode': 'viewport_scroll_atomic',
            },
          );
        }
      }
    });
  }

  bool _isRouteBackGestureInProgress() {
    if (!mounted) {
      return false;
    }
    return Navigator.maybeOf(context)?.userGestureInProgress ?? false;
  }

  void _onHeadMessageLaidOut(V2TimMessage message, Size size, Rect globalRect) {
    final previousHeight = ChatMessageHeightCache.instance.heightFor(message);
    if (size.height > 0) {
      ChatMessageHeightCache.instance.remember(message, size.height);
      final msgId = message.msgID?.trim() ?? message.id?.trim() ?? '';
      final shortId = msgId.length > 28
          ? '${msgId.substring(0, 12)}…${msgId.substring(msgId.length - 8)}'
          : msgId;
      ChatGeomSettleTrace.noteReason(
        'row_height_remember',
        extras: <String, Object?>{
          'msgId': shortId,
          'prev': previousHeight?.toStringAsFixed(1),
          'next': size.height.toStringAsFixed(1),
          'delta': previousHeight == null
              ? 'n/a'
              : (size.height - previousHeight).toStringAsFixed(1),
        },
      );
      if (previousHeight != null) {
        _noteShortHistoryRowHeightBumpForReveal(size.height - previousHeight);
      }
    }
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    final rowKey = _stableMessageListKey(message, 0);
    final heightDelta =
        previousHeight == null ? 0.0 : size.height - previousHeight;
    final inMediaSettle = _isMediaSettlingForKey(rowKey);
    final suppressContinuousInitialCorrection =
        _shouldSuppressContinuousInitialHeightCorrection(rowKey);
    if (previousHeight != null &&
        heightDelta.abs() > 1 &&
        suppressContinuousInitialCorrection) {
      ChatJitterDiag.logInboundFlow(
        action: 'cvp_initial_height_correction_suppressed',
        conv: _conversationId(),
        extras: <String, Object?>{
          'before': previousHeight.toStringAsFixed(1),
          'after': size.height.toStringAsFixed(1),
          'delta': heightDelta.toStringAsFixed(1),
          'cvpTx': _viewportInsert.continuousViewportPushDiagTransaction,
        },
      );
    }
    if (previousHeight != null &&
        heightDelta.abs() > 1 &&
        !suppressContinuousInitialCorrection &&
        !globalModel.isChatListUserScrolling &&
        !_isRouteBackGestureInProgress() &&
        _shouldPinScrollToBottom(globalModel)) {
      // 上推进行中 / settle / 媒体稳定窗：长高必须 silentAbsorb。
      // 以前 slide 期间直接跳过 → 长文本二次 layout 把历史整体顶走，再 pin 一次。
      // 贴底时长高也优先 absorb：pin 会整表跳到底，观感就是「历史被一起推」。
      final preferSilentAbsorb = _viewportInsert.viewportInsertSlideActive ||
          _isViewportInsertSettling() ||
          inMediaSettle ||
          globalModel.isInboundPresentationBottomLocked(_conversationId());
      if (preferSilentAbsorb) {
        ChatJitterDiag.logInboundFlow(
          action: 'silent_extent_absorb',
          conv: _conversationId(),
          extras: <String, Object?>{
            'before': previousHeight.toStringAsFixed(1),
            'after': size.height.toStringAsFixed(1),
            'delta': heightDelta.toStringAsFixed(1),
            'mediaSettle': inMediaSettle,
            'viewportSlide': _viewportInsert.viewportInsertSlideActive,
          },
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              globalModel.isChatListUserScrolling ||
              _isRouteBackGestureInProgress()) {
            return;
          }
          _silentAbsorbExtentDelta(heightDelta);
        });
      } else {
        // 贴底时长高优先 silentAbsorb，避免 pin 整表跳造成「历史一起被推」。
        final scrollPosition = _singleScrollPositionOrNull();
        final nearBottom = scrollPosition != null &&
            scrollPosition.hasPixels &&
            scrollPosition.hasContentDimensions &&
            (scrollPosition.pixels - scrollPosition.minScrollExtent).abs() <=
                80;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          if (nearBottom) {
            _silentAbsorbExtentDelta(heightDelta);
          } else {
            _pinScrollToBottomImmediate();
          }
        });
      }
    }
    if (previousHeight != null &&
        (previousHeight - size.height).abs() >= 8 &&
        (globalModel.isChunkedRevealActive(_conversationId()) ||
            _viewportInsert.viewportInsertSlideActive ||
            inMediaSettle)) {
      ChatJitterDiag.logInboundFlow(
        action: 'row_height_changed',
        conv: _conversationId(),
        extras: <String, Object?>{
          'before': previousHeight.toStringAsFixed(1),
          'after': size.height.toStringAsFixed(1),
          'delta': (size.height - previousHeight).toStringAsFixed(1),
          'viewportSlide': _viewportInsert.viewportInsertSlideActive,
          'mediaSettle': inMediaSettle,
        },
        throttleKey: 'row_height_changed',
        minIntervalMs: 100,
      );
    }
    if (globalModel.isSendFlyOverlayPendingForMessage(message)) {
      globalModel.reportSendFlyTargetRect(message, globalRect);
    }
  }

  /// Returns true when newest-side inserts were absorbed into short spacer
  /// (caller must not double-absorb async history delta).
  bool _onMessageListMaybeInserted(
    List<V2TimMessage?> oldList,
    List<V2TimMessage?> newList,
  ) {
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    if (_isInitialHistoryBootstrapping(globalModel)) {
      globalModel.completeInboundProjectionReveal(_conversationId());
      return false;
    }
    // 用户正在手动滑动列表时，进入后异步刷新/后台 merge 追加消息不应把列表
    // 拽回底部（否则表现为「刚进入上滑一点又被弹回底部」）。此时保持原位，
    // 新消息由未读提示条呈现，与微信一致。发送消息走独立 force-pin 路径，
    // 不经过这里，因此不受影响。
    if (globalModel.isChatListUserScrolling) {
      globalModel.completeInboundProjectionReveal(_conversationId());
      return false;
    }
    if (newList.length <= oldList.length) {
      return false;
    }
    final growth = newList.length - oldList.length;
    final oldKeys = oldList
        .asMap()
        .entries
        .map((entry) => _stableMessageListKey(entry.value, entry.key))
        .toSet();
    // 只认「最新侧连续新增」：从列表头往下扫，一碰到旧消息就停。
    // 全表 key 差分会把 tip 重写 / id↔msgID 切换误判成「历史也被插入」，
    // 零高 + list-push 时表现为旧消息连同历史一起再推一遍。
    final insertedMessages = <V2TimMessage>[];
    var insertedTipRows = 0;
    for (var index = 0; index < newList.length; index++) {
      final message = newList[index];
      if (message == null) {
        continue;
      }
      if (message.elemType == 11) {
        final tipKey = _stableMessageListKey(message, index);
        if (!oldKeys.contains(tipKey)) {
          insertedTipRows++;
        }
        continue;
      }
      final key = _stableMessageListKey(message, index);
      if (oldKeys.contains(key)) {
        break;
      }
      insertedMessages.add(message);
    }
    if (insertedMessages.isEmpty) {
      globalModel.completeInboundProjectionReveal(_conversationId());
      return false;
    }
    final outgoingMediaInserted =
        insertedMessages.where(_isOutgoingMediaMessage).toList(growable: false);
    if (outgoingMediaInserted.isNotEmpty) {
      _beginMediaSettleForMessages(outgoingMediaInserted, holdMs: 1200);
    }
    // growth 保护：key 抖动时前缀可能吞进历史行；最多只认本轮长度增量。
    if (insertedMessages.length > growth) {
      ChatJitterDiag.logInboundFlow(
        action: 'list_insert_prefix_capped',
        conv: _conversationId(),
        extras: <String, Object?>{
          'rawInserted': insertedMessages.length,
          'growth': growth,
          'oldLen': oldList.length,
          'newLen': newList.length,
        },
      );
      insertedMessages.removeRange(growth, insertedMessages.length);
    }
    // 短历史顶部对齐：发送/插入优先吃 spacer（顶部不动），只有装不下才释放并上推。
    var absorbedShortHistoryInsert = false;
    if (_routeScroll.shortHistoryAlignmentLatched ||
        _routeScroll.shortHistoryBottomSpacerHeight > 0) {
      if (_absorbInsertedRowsIntoShortHistorySpacer(
        insertedMessages,
        insertedTipRows: insertedTipRows,
      )) {
        absorbedShortHistoryInsert = true;
        ChatJitterDiag.logInboundFlow(
          action: 'short_history_spacer_absorb_insert',
          conv: _conversationId(),
          extras: <String, Object?>{
            'inserted': insertedMessages.length,
            'insertedTipRows': insertedTipRows,
            'spacer':
                _routeScroll.shortHistoryBottomSpacerHeight.toStringAsFixed(1),
          },
        );
      } else {
        _clearShortHistoryAlignmentLatch();
        // 内容已放不进视口：本会话剩余生命周期改贴底，避免下一帧又造回大 spacer。
        _routeScroll.shortHistoryAlignmentSuppressedByLiveInsert = true;
      }
    }
    if (absorbedShortHistoryInsert) {
      // 吃 spacer 成功：禁止 list-push / pin，否则会把已顶部锚定的消息再往上推。
      // 估高偏小时多行自消息可能仍溢出视口：下一帧实测后必要时退场并贴底。
      _finishIncomingMessagesWithoutRowReveal(insertedMessages);
      final hasOutgoingSelf = insertedMessages.any((m) => m.isSelf == true);
      if (hasOutgoingSelf) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _breakShortHistoryIfOutgoingOverflowsViewport();
        });
      }
      return true;
    }
    final fastForwardInsertedMessages = insertedMessages
        .where(globalModel.consumeInboundFastForwardFlag)
        .toList(growable: false);
    final fastForwardKeys = fastForwardInsertedMessages
        .map((message) => _stableMessageListKey(message, 0))
        .toSet();
    if (fastForwardInsertedMessages.isNotEmpty) {
      for (final message in fastForwardInsertedMessages) {
        globalModel.finishMessageEnterAnimation(message);
      }
      // Fast-forwarded rows intentionally skip animation. Commit them at the
      // latest edge before the retained animated tail starts on the next tick.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pinScrollToBottomImmediate();
        }
      });
    }
    final animatingMessages = insertedMessages
        .where(
          (message) =>
              !fastForwardKeys.contains(_stableMessageListKey(message, 0)),
        )
        .where(globalModel.isMessageEnterAnimationPending)
        .toList(growable: false);
    final incomingInsertedMessages = insertedMessages
        .where(
          (message) =>
              message.isSelf != true &&
              !fastForwardKeys.contains(_stableMessageListKey(message, 0)),
        )
        .toList(growable: false);
    final outgoingAnimatingMessages = animatingMessages
        .where((message) => message.isSelf == true)
        .toList(growable: false);
    // 自己发的文本要马上全高出现；零高 list-push 会先空一帧，像发送顿挫。
    final outgoingTextInserted = outgoingAnimatingMessages
        .where(
          (message) => message.elemType == MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        )
        .toList(growable: false);
    final outgoingNonTextAnimating = outgoingAnimatingMessages
        .where(
          (message) => message.elemType != MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        )
        .toList(growable: false);
    final incomingAnimatingMessages = animatingMessages
        .where((message) => message.isSelf != true)
        .toList(growable: false);
    final position = _singleScrollPositionOrNull();
    ChatJitterDiag.logInboundFlow(
      action: 'list_insert_classified',
      conv: _conversationId(),
      extras: <String, Object?>{
        'oldLen': oldList.length,
        'newLen': newList.length,
        'inserted': insertedMessages.length,
        'incoming': incomingInsertedMessages.length,
        'outgoingAnimating': outgoingAnimatingMessages.length,
        'animating': incomingAnimatingMessages.length,
        'growth': growth,
        'insertedTipRows': insertedTipRows,
        'untrackedGrowth': growth - insertedMessages.length - insertedTipRows,
        'fastForward': fastForwardInsertedMessages.length,
        'queue': globalModel.pendingInboundProjectionCount(_conversationId()),
        'waiting':
            globalModel.isInboundProjectionRevealWaiting(_conversationId()),
        'logicalPosition':
            globalModel.getMessageListPosition(_conversationId()).name,
        'pixels': position?.hasPixels == true
            ? position!.pixels.toStringAsFixed(1)
            : 'n/a',
        'minExtent': position?.hasContentDimensions == true
            ? position!.minScrollExtent.toStringAsFixed(1)
            : 'n/a',
      },
    );
    if (incomingInsertedMessages.isEmpty &&
        outgoingAnimatingMessages.isEmpty &&
        _viewportInsert.activeRowRevealMessages.isEmpty &&
        !_viewportInsert.viewportInsertSlideActive &&
        !(_viewportInsert.rowRevealController?.isAnimating ?? false) &&
        globalModel.isInboundProjectionRevealWaiting(_conversationId())) {
      globalModel.completeInboundProjectionReveal(_conversationId());
    }
    if (oldList.isEmpty && newList.isNotEmpty) {
      _finishIncomingMessagesWithoutRowReveal(incomingInsertedMessages);
      _finishIncomingMessagesWithoutRowReveal(outgoingAnimatingMessages);
      return false;
    }
    // 自动 list-push 本身会暂时把 pixels 推离 minExtent；这不是用户在读历史。
    // 若此时锁定阅读锚点，restore 会逐帧把 ticker 拉回旧 offset，形成来回抖动。
    final inboundPushOwnsViewport =
        _viewportInsert.continuousViewportPushActive ||
            _viewportInsert.viewportInsertSlideActive ||
            globalModel.isInboundPresentationBottomLocked(_conversationId());
    if (inboundPushOwnsViewport) {
      _clearIncomingScrollAnchor(reason: 'inbound_push_owns_viewport');
    }
    // 上拉分页 prepend 必须优先于「读历史锚点锁」。否则会把 offset 拉回插入前，
    // 与 HistoryPaginationScrollPhysics / 分页 restore 对打，表现为历史加载完朝新消息跳一下。
    if (_paginationUi.isLoadingPrevious ||
        _paginationUi.loadPreviousTask != null ||
        _paginationUi.previousLoadInFlightAnchorKey != null ||
        _shouldCompensateScrollForPagination()) {
      _clearIncomingScrollAnchor(reason: 'pagination_prepend');
      _finishIncomingMessagesWithoutRowReveal(incomingInsertedMessages);
      _finishIncomingMessagesWithoutRowReveal(outgoingAnimatingMessages);
      return false;
    }
    if (_isReadingHistory() && !inboundPushOwnsViewport) {
      _logReadingHistoryIncoming(
        'head_insert',
        globalModel: globalModel,
        extras: <String, Object?>{
          'oldLen': oldList.length,
          'newLen': newList.length,
          'inserted': insertedMessages.length,
          'userScrolling': globalModel.isChatListUserScrolling,
        },
      );
      _maybeLatchUnreadCenterDeferral();
      _beginIncomingWhileReadingAnchorLock(globalModel);
      _beginIncomingWhileReadingCompensation();
      _beginHistoryScrollProtection(milliseconds: 400);
    }
    final wechatListPush = _useWechatListPushTranslate(globalModel);
    // 收到的消息、自己发的图片/视频仍走零高 list-push；自己发的文本立刻全高落位。
    var listPushMessages = <V2TimMessage>[
      ...incomingInsertedMessages,
      if (wechatListPush) ...outgoingNonTextAnimating,
    ];
    // 同一帧多条必须整批进入同一个零高事务。以前只动画最新 1 条、其余直接
    // 全高落位；快速收消息时这些 overflow 会先顶动历史，再由最新气泡上推。
    // atomic 路径会按整批实测高度做一次补偿，因此不会让历史随批次跳动。
    if (listPushMessages.length > 1) {
      ChatJitterDiag.logInboundFlow(
        action: 'list_push_batch',
        conv: _conversationId(),
        extras: <String, Object?>{
          'animated': listPushMessages.length,
          'queuedBehindActive': _viewportInsert.viewportInsertSlideActive,
        },
      );
    }
    if (wechatListPush &&
        (listPushMessages.isNotEmpty || outgoingMediaInserted.isNotEmpty)) {
      _finishIncomingMessagesWithoutRowReveal(outgoingTextInserted);
      final pushMessages = <V2TimMessage>[
        ...listPushMessages,
        ...outgoingMediaInserted,
      ];
      if (_shouldRunRowReveal(forLiveListPush: true)) {
        _startContinuousViewportInsertPush(pushMessages);
      } else if (!_isHistoryScrollProtected &&
          !_isReadingHistory() &&
          !globalModel.isChunkedRevealActive(_conversationId()) &&
          !(_chatGlobalModel?.isBulkMessageSyncActive(_conversationId()) ??
              false)) {
        // 发送路径里 suppressOutgoingPinScroll 只挡 soft pin，不该吞掉落位；
        // force-pin 会单独处理贴底。
        _finishIncomingMessagesWithoutRowReveal(pushMessages);
        if (!(_chatGlobalModel?.shouldSuppressOutgoingPinScroll() ?? false)) {
          _schedulePinScrollToBottom();
        }
      } else {
        _finishIncomingMessagesWithoutRowReveal(pushMessages);
      }
    } else if (incomingInsertedMessages.isNotEmpty && _shouldRunRowReveal()) {
      if (incomingAnimatingMessages.isNotEmpty) {
        _startRowRevealTransaction(incomingAnimatingMessages);
      } else {
        _finishIncomingMessagesWithoutRowReveal(incomingInsertedMessages);
        _schedulePinScrollToBottom();
      }
      _finishIncomingMessagesWithoutRowReveal(outgoingAnimatingMessages);
    } else if (!_isHistoryScrollProtected &&
        !(_chatGlobalModel?.shouldSuppressOutgoingPinScroll() ?? false) &&
        !_isReadingHistory() &&
        !globalModel.isChunkedRevealActive(_conversationId()) &&
        !(_chatGlobalModel?.isBulkMessageSyncActive(_conversationId()) ??
            false)) {
      _finishIncomingMessagesWithoutRowReveal(incomingInsertedMessages);
      _finishIncomingMessagesWithoutRowReveal(outgoingAnimatingMessages);
      _schedulePinScrollToBottom();
    } else {
      _finishIncomingMessagesWithoutRowReveal(incomingInsertedMessages);
      _finishIncomingMessagesWithoutRowReveal(outgoingAnimatingMessages);
    }
    if (_isReadingHistory() && !_shouldRunRowReveal()) {
      _logReadingHistoryIncoming(
        'pin_blocked',
        globalModel: globalModel,
        extras: <String, Object?>{
          'historyProtected': _isHistoryScrollProtected,
          'suppressOutgoingPin':
              _chatGlobalModel?.shouldSuppressOutgoingPinScroll() ?? false,
        },
      );
    }
    return false;
  }

  bool _shouldPinScrollToBottom(TUIChatGlobalModel globalModel) {
    if (_mayUseShortHistoryTopAlignment()) {
      return false;
    }
    // 用户正在手动滑动时不做滚底补偿（list-push 补偿阈值 80px 会把「上滑一点」
    // 的用户拽回底部）。发送消息的 force-pin 不经过这里，不受影响。
    if (globalModel.isChatListUserScrolling) {
      return false;
    }
    if (_isSearchJumpStabilizing) {
      return false;
    }
    if (globalModel.isWalletOverlayOpen) {
      return false;
    }
    if (globalModel.isMediaPickerOverlayOpen) {
      return false;
    }
    if (globalModel.isMediaPreviewOverlayOpen) {
      return false;
    }
    if (globalModel.isMessageContextMenuOverlayOpen) {
      return false;
    }
    if (globalModel.isRestoringScrollAfterMediaPreview) {
      return false;
    }
    final convId = _conversationId();
    if (globalModel.hasPendingScrollRestore(convId)) {
      return false;
    }
    final listPosition = globalModel.getMessageListPosition(convId);
    if (listPosition == HistoryMessagePosition.notShowLatest ||
        listPosition == HistoryMessagePosition.awayTwoScreen) {
      return false;
    }
    if (globalModel.unreadCountForTongue > 0) {
      final listPosition = globalModel.getMessageListPosition(convId);
      if (listPosition != HistoryMessagePosition.bottom) {
        return false;
      }
    }
    if (_isReadingHistory() || _deferUnreadCenterPartition) {
      return false;
    }
    return true;
  }

  /// 进页布局冻结窗：覆盖 hydrate + 首轮 loadLatest 常见耗时，避免 spacer/loading 抖。
  bool get _isInitialRouteSettleWindow =>
      DateTime.now().millisecondsSinceEpoch - _createdAtMs < 2500;

  void _schedulePinScrollToBottomOnUnreadEntry({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _pinScrollToBottomOnUnreadEntry(attempt: attempt);
    });
  }

  void _pinScrollToBottomOnUnreadEntry({int attempt = 0}) {
    const maxAttempts = 12;
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    final convId = _conversationId();
    if (globalModel.unreadCountForTongue <= 0 ||
        globalModel.getMessageListPosition(convId) !=
            HistoryMessagePosition.bottom ||
        _firstUnreadAnchorJumped) {
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      if (attempt < maxAttempts) {
        _schedulePinScrollToBottomOnUnreadEntry(attempt: attempt + 1);
      }
      return;
    }
    const pinThreshold = 80.0;
    final target = position.minScrollExtent;
    if ((position.pixels - target).abs() > 0.5) {
      _geomJumpTo(target, reason: 'pin_unread_entry');
    }
    globalModel.setMessageListPosition(
      convId,
      HistoryMessagePosition.bottom,
      notify: false,
    );
    final frozenUnread = globalModel.unreadCountForTongue;
    if (frozenUnread > 0) {
      globalModel.setUnreadTongueMetrics(
        conversationID: convId,
        remaining: frozenUnread,
        below: false,
        notify: true,
      );
    }
    if (attempt < maxAttempts - 1 && position.pixels > target + pinThreshold) {
      _schedulePinScrollToBottomOnUnreadEntry(attempt: attempt + 1);
    }
  }

  void _schedulePinScrollToBottom({int attempt = 0}) {
    if (_isHistoryScrollProtected) {
      return;
    }
    if (attempt == 0) {
      scheduleMicrotask(() {
        if (!mounted) {
          return;
        }
        _pinScrollToBottomImmediate();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _pinScrollToBottomIfNeeded(attempt: attempt);
    });
  }

  void _cancelForcePinScroll() {
    _forcePinGeneration++;
    _forcePinIgnoreInsertWindows = false;
  }

  void _scheduleForcePinScrollToBottom({
    int attempt = 0,
    int? generation,
    bool ignoreInsertWindows = false,
  }) {
    final gen = generation ?? ++_forcePinGeneration;
    if (generation == null) {
      _forcePinIgnoreInsertWindows = ignoreInsertWindows;
    }
    // 上拉历史保护窗口内不要直接放弃：延后重试，保证发送/点输入框仍能回底。
    if (_isHistoryScrollProtected) {
      final maxAttempts = _isInitialRouteSettleWindow ? 4 : 8;
      if (attempt < maxAttempts) {
        Future<void>.delayed(const Duration(milliseconds: 48), () {
          if (!mounted || gen != _forcePinGeneration) {
            return;
          }
          _scheduleForcePinScrollToBottom(
              attempt: attempt + 1, generation: gen);
        });
      }
      return;
    }
    if (_isRouteBackGestureInProgress() ||
        (_chatGlobalModel?.isChatListUserScrolling ?? false)) {
      _cancelForcePinScroll();
      return;
    }
    if (attempt == 0) {
      scheduleMicrotask(() {
        if (!mounted || gen != _forcePinGeneration) {
          return;
        }
        _forcePinScrollToBottomIfNeeded(
          attempt: attempt,
          generation: gen,
        );
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || gen != _forcePinGeneration) {
        return;
      }
      _forcePinScrollToBottomIfNeeded(attempt: attempt, generation: gen);
    });
  }

  void _forcePinScrollToBottomIfNeeded({
    int attempt = 0,
    required int generation,
  }) {
    if (generation != _forcePinGeneration) {
      return;
    }
    // 进入本方法即 force-pin 意图（软贴底走 _pinScrollToBottomIfNeeded）。
    // 短历史顶部对齐期间必须先退场再贴底，否则发送多行后最新气泡不可见。
    if (_routeScroll.shortHistoryAlignmentLatched ||
        _routeScroll.shortHistoryBottomSpacerHeight > 0) {
      _clearShortHistoryAlignmentLatch();
      _routeScroll.shortHistoryAlignmentSuppressedByLiveInsert = true;
    }
    if (!_forcePinIgnoreInsertWindows &&
        _viewportInsert.viewportInsertSlideActive) {
      // list-push 拥有本轮上推：结束后再视需要补一次贴底，勿直接丢弃 force-pin。
      final maxAttempts = _isInitialRouteSettleWindow ? 4 : 8;
      if (attempt < maxAttempts) {
        Future<void>.delayed(const Duration(milliseconds: 48), () {
          if (!mounted || generation != _forcePinGeneration) {
            return;
          }
          _scheduleForcePinScrollToBottom(
            attempt: attempt + 1,
            generation: generation,
          );
        });
      }
      return;
    }
    if (!_forcePinIgnoreInsertWindows &&
        _viewportInsert.hasAnyMediaSettling()) {
      // 图片/视频首帧 layout、decode 期间勿 force-pin，与 silentAbsorb 对打会抖。
      // 出站媒体稳定窗最长 1200ms；24 * 64ms = 1536ms，必须覆盖完整
      // 稳定窗。旧值 6/16 次会在 384/1024ms 提前耗尽，pin seq 又已消费，
      // 导致相册返回后新图片留在视口外，必须手动滑动才能看到。
      const maxAttempts = 24;
      if (attempt < maxAttempts) {
        Future<void>.delayed(const Duration(milliseconds: 64), () {
          if (!mounted || generation != _forcePinGeneration) {
            return;
          }
          _scheduleForcePinScrollToBottom(
            attempt: attempt + 1,
            generation: generation,
          );
        });
      }
      return;
    }
    if (!_forcePinIgnoreInsertWindows &&
        _viewportInsert.continuousViewportPushActive) {
      final maxAttempts = _isInitialRouteSettleWindow ? 4 : 8;
      if (attempt < maxAttempts) {
        Future<void>.delayed(const Duration(milliseconds: 48), () {
          if (!mounted || generation != _forcePinGeneration) {
            return;
          }
          _scheduleForcePinScrollToBottom(
            attempt: attempt + 1,
            generation: generation,
          );
        });
      }
      return;
    }
    if (_isRouteBackGestureInProgress() ||
        (_chatGlobalModel?.isChatListUserScrolling ?? false)) {
      _cancelForcePinScroll();
      return;
    }
    if (!_forcePinIgnoreInsertWindows && _isViewportInsertSettling()) {
      final delayMs = _viewportInsertSettleRemainingMs();
      Future<void>.delayed(Duration(milliseconds: max(delayMs, 16)), () {
        if (!mounted || generation != _forcePinGeneration) {
          return;
        }
        _scheduleForcePinScrollToBottom(
            attempt: attempt, generation: generation);
      });
      return;
    }
    final maxAttempts = _isInitialRouteSettleWindow ? 4 : 8;
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    if (globalModel.isChatListUserScrolling) {
      _cancelForcePinScroll();
      return;
    }
    if (globalModel.isUserScrollToBottomInProgress(_conversationId())) {
      return;
    }
    if (globalModel.isWalletOverlayOpen ||
        (!_forcePinIgnoreInsertWindows &&
            globalModel.isMediaPickerOverlayOpen) ||
        globalModel.isMediaPreviewOverlayOpen ||
        globalModel.isMessageContextMenuOverlayOpen ||
        globalModel.isRestoringScrollAfterMediaPreview) {
      return;
    }
    final convId = _conversationId();
    if (globalModel.hasPendingScrollRestore(convId)) {
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null) {
      if (attempt < maxAttempts) {
        _scheduleForcePinScrollToBottom(
          attempt: attempt + 1,
          generation: generation,
        );
      }
      return;
    }
    if (!position.hasPixels || !position.hasContentDimensions) {
      if (attempt < maxAttempts) {
        _scheduleForcePinScrollToBottom(
          attempt: attempt + 1,
          generation: generation,
        );
      }
      return;
    }

    final target = position.minScrollExtent;
    final awayFromBottom = (position.pixels - target).abs() > 0.5;
    // Already near bottom during outgoing suppress: stop chasing frames.
    if (!awayFromBottom && globalModel.shouldSuppressOutgoingPinScroll()) {
      return;
    }
    if (awayFromBottom) {
      ChatJitterDiag.logScroll(
        reason: 'force_pin_bottom_a$attempt',
        pixels: position.pixels,
        minExtent: target,
        maxExtent: position.maxScrollExtent,
      );
      _scrollToBottomTarget(target, globalModel);
    }
    globalModel.setMessageListPosition(
      convId,
      HistoryMessagePosition.bottom,
      notify: false,
    );

    // Only keep chasing bottom while layout is still drifting. Unconditional
    // 8-frame retries after list-push often re-nudge settled content.
    if (attempt < maxAttempts - 1 && awayFromBottom) {
      _scheduleForcePinScrollToBottom(
        attempt: attempt + 1,
        generation: generation,
      );
    }
  }

  void _pinScrollToBottomIfNeeded({int attempt = 0}) {
    if (_viewportInsert.viewportInsertSlideActive) {
      return;
    }
    if (_isRouteBackGestureInProgress() ||
        (_chatGlobalModel?.isChatListUserScrolling ?? false)) {
      return;
    }
    if (_isViewportInsertSettling()) {
      final delayMs = _viewportInsertSettleRemainingMs();
      Future<void>.delayed(Duration(milliseconds: max(delayMs, 16)), () {
        if (!mounted) {
          return;
        }
        _schedulePinScrollToBottom(attempt: attempt);
      });
      return;
    }
    final maxAttempts = _isInitialRouteSettleWindow ? 3 : 8;
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    if (globalModel.isBulkMessageSyncActive(_conversationId())) {
      return;
    }
    if (globalModel.isUserScrollToBottomInProgress(_conversationId())) {
      return;
    }
    if (!_shouldPinScrollToBottom(globalModel)) {
      return;
    }
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null) {
      if (attempt < maxAttempts) {
        _schedulePinScrollToBottom(attempt: attempt + 1);
      }
      return;
    }
    if (!position.hasPixels || !position.hasContentDimensions) {
      if (attempt < maxAttempts) {
        _schedulePinScrollToBottom(attempt: attempt + 1);
      }
      return;
    }

    const bottomEpsilon = 24.0;
    final nearBottom =
        position.pixels <= position.minScrollExtent + bottomEpsilon;
    final contentFitsViewport =
        position.maxScrollExtent <= position.minScrollExtent + bottomEpsilon;

    if (nearBottom || contentFitsViewport) {
      final target = position.minScrollExtent;
      if ((position.pixels - target).abs() > 0.5) {
        _scrollToBottomTarget(target, globalModel);
      }
      globalModel.setMessageListPosition(
        _conversationId(),
        HistoryMessagePosition.bottom,
        notify: false,
      );
    }

    if (attempt < maxAttempts - 1 && (nearBottom || contentFitsViewport)) {
      _schedulePinScrollToBottom(attempt: attempt + 1);
    }
  }

  void _scrollToBottomTarget(double target, TUIChatGlobalModel globalModel) {
    // 用户手指优先：异步媒体布局、发送回调或旧的 post-frame pin 可能在
    // 手势已经开始后才到达。此时再 jump/animate 会抢夺 ScrollPosition，
    // 表现为列表卡住、拖动方向反转或松手后又被拉回底部。调用方大多有
    // 自己的保护，但这里是所有贴底路径的最后一道闸门。
    if (globalModel.isChatListUserScrolling || _userScrollGestureActive) {
      return;
    }
    // Open / just-revealed: always jump. Smooth follow is for live inbound only.
    if (!_historyOpenRevealPainted ||
        _isInitialRouteSettleWindow ||
        _isPostRevealMicroSuppressWindow) {
      _geomJumpTo(target, reason: 'scroll_to_bottom_instant_open');
      return;
    }
    final useSmooth = globalModel.chatConfig.inboundScrollFollowEnabled &&
        globalModel.chatConfig.inboundScrollFollowMode ==
            InboundScrollFollowMode.smooth;
    if (useSmooth) {
      unawaited(
        _autoScrollController.animateTo(
          target,
          duration: Duration(
            milliseconds: globalModel.chatConfig.inboundScrollFollowDurationMs,
          ),
          curve: Curves.easeInOut,
        ),
      );
      return;
    }
    _geomJumpTo(target, reason: 'scroll_to_bottom_target');
  }

  void _startRowRevealTransaction(List<V2TimMessage> messages) {
    final controller = _viewportInsert.rowRevealController;
    if (controller == null || messages.isEmpty) {
      _finishIncomingMessagesWithoutRowReveal(messages);
      return;
    }
    if (controller.isAnimating ||
        _viewportInsert.activeRowRevealMessages.isNotEmpty) {
      _finishActiveRowRevealImmediately();
    }
    final generation = ++_viewportInsert.rowRevealGeneration;
    _viewportInsert.activeRowRevealMessages.clear();
    for (final message in messages) {
      _viewportInsert
          .activeRowRevealMessages[_stableMessageListKey(message, 0)] = message;
    }
    final globalModel = _chatGlobalModel ??
        Provider.of<TUIChatGlobalModel>(context, listen: false);
    final pendingCount =
        globalModel.pendingInboundProjectionCount(_conversationId());
    final durationMs = _isWechatInsertAnimationStyle(globalModel)
        ? 240
        : switch (pendingCount) {
            >= 40 => 200,
            >= 16 => 280,
            >= 6 => 360,
            >= 2 => 440,
            _ => 520,
          };
    controller.duration = Duration(milliseconds: durationMs);
    controller.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _viewportInsert.rowRevealGeneration ||
          _viewportInsert.activeRowRevealMessages.isEmpty ||
          controller.isCompleted) {
        return;
      }
      if (controller.isAnimating) {
        controller.stop();
      }
      controller.forward(from: 0);
    });
  }

  void _finishIncomingMessagesWithoutRowReveal(List<V2TimMessage> messages) {
    if (messages.isEmpty) {
      return;
    }
    final globalModel = _chatGlobalModel ??
        (mounted
            ? Provider.of<TUIChatGlobalModel>(context, listen: false)
            : null);
    if (globalModel == null) {
      return;
    }
    for (final message in messages) {
      final key = _stableMessageListKey(message, 0);
      _viewportInsert.queuedViewportInsertMessages.remove(key);
      _viewportInsert.rowRevealFullExtentByKey.remove(key);
      globalModel.finishMessageEnterAnimation(message);
    }
    globalModel.completeInboundProjectionReveal(_conversationId());
  }

  void _finishActiveRowRevealImmediately() {
    final controller = _viewportInsert.rowRevealController;
    if (controller == null || _viewportInsert.activeRowRevealMessages.isEmpty) {
      return;
    }
    if (controller.value < 1) {
      controller.stop();
      controller.value = 1;
    }
    _completeRowRevealTransaction();
  }

  void _completeRowRevealTransaction() {
    if (_viewportInsert.activeRowRevealMessages.isEmpty) {
      return;
    }
    final messages =
        List<V2TimMessage>.from(_viewportInsert.activeRowRevealMessages.values);
    _viewportInsert.activeRowRevealMessages.clear();
    final globalModel = _chatGlobalModel ??
        Provider.of<TUIChatGlobalModel>(context, listen: false);
    for (final message in messages) {
      globalModel.finishMessageEnterAnimation(message);
    }
    globalModel.completeInboundProjectionReveal(_conversationId());
    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleRouteScrollRestore(List<V2TimMessage?> renderList) {
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    if (!globalModel.isRestoringScrollAfterMediaPreview) {
      _routeScroll.routeRestoreScheduled = false;
      return;
    }
    final version = globalModel.mediaPreviewRestoreVersion;
    if (version <= 0) {
      return;
    }
    if (_routeScroll.lastRouteRestoreVersion != version) {
      _routeScroll.lastRouteRestoreVersion = version;
      _routeScroll.routeRestoreAttempt = 0;
      _routeScroll.routeRestoreScheduled = false;
    }
    if (_routeScroll.routeRestoreAttempt >= 24) {
      globalModel.finishScrollAfterMediaPreview(_conversationId());
      _routeScroll.routeRestoreScheduled = false;
      return;
    }
    if (_routeScroll.routeRestoreScheduled) {
      return;
    }
    _routeScroll.routeRestoreScheduled = true;
    final snapshot = List<V2TimMessage?>.from(renderList);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeScroll.routeRestoreScheduled = false;
      if (!mounted) {
        return;
      }
      _restoreRouteScroll(snapshot, version);
    });
  }

  Future<void> _restoreRouteScroll(
    List<V2TimMessage?> renderList,
    int version,
  ) async {
    if (!mounted || version != _routeScroll.lastRouteRestoreVersion) {
      return;
    }
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    final convId = _conversationId();
    var restored = false;
    final offset = globalModel.getScrollRestoreOffset(convId);
    final offsetPosition = _singleScrollPositionOrNull();
    if (offset != null && offsetPosition != null) {
      final position = offsetPosition;
      if (position.hasPixels && position.hasContentDimensions) {
        final target = offset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if ((position.pixels - target).abs() > 0.5) {
          _geomJumpTo(target.toDouble(),
              reason: 'jump__scheduleRouteScrollRestore');
        }
        restored = true;
      }
    }
    if (!restored) {
      // 不要用 scrollToIndex(middle) 兜底：会把入口图片气泡拽到视口正中。
      // 预览路由 maintainState，列表位姿应保持；只重试 offset jump，否则就地解锁。
      _routeScroll.routeRestoreAttempt++;
      if (_routeScroll.routeRestoreAttempt < 3 && offset != null) {
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (mounted) {
            _scheduleRouteScrollRestore(renderList);
          }
        });
        return;
      }
      globalModel.finishScrollAfterMediaPreview(convId);
      _routeScroll.routeRestoreScheduled = false;
      return;
    }
    globalModel.finishScrollAfterMediaPreview(convId);
    _routeScroll.routeRestoreAttempt = 0;
    _routeScroll.routeRestoreScheduled = false;
  }

  String _messageIdentity(V2TimMessage message) {
    final msgID = message.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      return msgID;
    }
    final id = message.id;
    if (id != null && id.toString().isNotEmpty) {
      return id.toString();
    }
    return '';
  }

  RenderBox? _viewportRenderBoxFor(BuildContext tagContext) {
    final scrollable = Scrollable.maybeOf(tagContext);
    final viewportRenderObject = scrollable?.context.findRenderObject();
    if (viewportRenderObject is! RenderBox ||
        !viewportRenderObject.attached ||
        !viewportRenderObject.hasSize ||
        _renderObjectNeedsLayout(viewportRenderObject)) {
      return null;
    }
    return viewportRenderObject;
  }

  int? _globalIndexForMessageIdentity(String messageId) {
    if (messageId.isEmpty) {
      return null;
    }
    final mapped = _globalMessageIdentityIndexMap[messageId];
    if (mapped != null) {
      return mapped;
    }
    final messageList = _currentVisibleMessageList();
    for (var i = 0; i < messageList.length; i++) {
      final message = messageList[i];
      if (message == null || message.elemType == 11) {
        continue;
      }
      if (_messageIdentity(message) == messageId) {
        return i;
      }
    }
    return null;
  }

  int _rawMessageCount() {
    return _chatGlobalModel?.rawMessageCount(_conversationId()) ??
        widget.messageList.length;
  }

  void _finishPreviousLoadPagination() {
    _paginationUi.finishPreviousLoadInFlight();
    if (!_isSearchJumpStabilizing) {
      final gm = _chatGlobalModel;
      final conv = _conversationId();
      if (gm != null) {
        final position = gm.getMessageListPosition(conv);
        final stillReadingHistory =
            position == HistoryMessagePosition.awayTwoScreen ||
                position == HistoryMessagePosition.notShowLatest;
        if (!stillReadingHistory) {
          gm.setMemoryWindowSuppressed(conv, false);
          if (gm.rawMessageCount(conv) > ChatMessageWindowPolicy.softMax) {
            gm.applyMessageMemoryWindowNow(
              conv,
              memoryWindowAnchorMsgID:
                  _paginationUi.paginationRestoreAnchorMsgID,
              memoryWindowAnchorSeq:
                  _paginationUi.paginationRestoreAnchorSeq?.toString(),
            );
          }
        }
      }
    }
  }

  bool _shouldAllowLoadPreviousDespiteTopReach(
    _PreviousLoadAnchor? anchor, {
    bool bypassTopReachConsumed = false,
  }) {
    return _paginationUi.shouldAllowLoadPreviousAtTopReach(
      bypassTopReachConsumed: bypassTopReachConsumed,
    );
  }

  int _messageSortTime(V2TimMessage message) {
    return message.timestamp ?? int.tryParse(message.seq?.trim() ?? '') ?? 0;
  }

  _PreviousLoadAnchor? _anchorFromMessage(V2TimMessage message) {
    final msgID = message.msgID?.trim();
    final seq = int.tryParse(message.seq ?? '');
    if (msgID != null && msgID.isNotEmpty) {
      return _PreviousLoadAnchor(msgID: msgID, seq: seq);
    }
    if (seq != null && seq > 0) {
      return _PreviousLoadAnchor(msgID: null, seq: seq);
    }
    return null;
  }

  _PreviousLoadAnchor? _anchorForPreviousLoad(List<V2TimMessage?> list) {
    // 上拉锚点：仅 SDK 可翻页消息，或归档消息（走归档分页）。
    // 本地 tip（ce_ / localGroupTips）永远不参与上拉游标。
    final sdkCapable = <V2TimMessage>[];
    final archiveOnly = <V2TimMessage>[];
    for (final item in list) {
      if (item == null || item.elemType == 11) {
        continue;
      }
      if (HistoryPaginationAnchor.isLocalInjectedMessage(item)) {
        continue;
      }
      if (HistoryPaginationAnchor.canUseForSdkPagination(item)) {
        sdkCapable.add(item);
      } else if (HistoryPaginationAnchor.isArchiveHistoryMessage(item)) {
        archiveOnly.add(item);
      }
    }
    final picked = HistoryPaginationAnchor.oldestSdkPaginationAnchor(
          sdkCapable,
        ) ??
        HistoryPaginationAnchor.oldestArchiveCursorAnchor(archiveOnly);
    if (picked == null) {
      // tip-only / 无可翻页实体时勿刷日志。
      return null;
    }
    if (!HistoryPaginationAnchor.canUseForSdkPagination(picked)) {
      ChatHistoryTrace.log(
        'anchor_previous_non_sdk',
        conversationID: _conversationId(),
        extras: <String, Object?>{
          'msgID': picked.msgID,
          'seq': picked.seq,
          'ts': picked.timestamp,
        },
      );
    }
    return _anchorFromMessage(picked);
  }

  /// 向下滑加载更新消息：锚点取当前已加载窗口里时间最新的一条。
  _PreviousLoadAnchor? _anchorForLatestLoad(List<V2TimMessage?> list) {
    V2TimMessage? picked;
    for (final item in list) {
      if (item == null || item.elemType == 11) {
        continue;
      }
      // 本地 tip 不上参与最新方向分页锚点。
      if (HistoryPaginationAnchor.isLocalInjectedMessage(item)) {
        continue;
      }
      if (!HistoryPaginationAnchor.canUseForSdkPagination(item) &&
          !HistoryPaginationAnchor.isArchiveHistoryMessage(item)) {
        continue;
      }
      if (picked == null || _messageSortTime(item) > _messageSortTime(picked)) {
        picked = item;
      }
    }
    return picked == null ? null : _anchorFromMessage(picked);
  }

  bool _isSearchJumpHistoryMode(TUIChatGlobalModel globalModel) {
    if (widget.searchJumpAnchor != null || widget.initFindingMsg != null) {
      return true;
    }
    final position = globalModel.getMessageListPosition(_conversationId());
    return position == HistoryMessagePosition.notShowLatest;
  }

  bool _canProbeLatestHistory(TUIChatGlobalModel globalModel) {
    return widget.model.haveMoreLatestData ||
        _isSearchJumpHistoryMode(globalModel);
  }

  bool _canScheduleLoadPrevious() {
    return _paginationUi.canScheduleLoadPrevious(
      searchJumpStabilizing: _isSearchJumpStabilizing,
      historyScrollProtected: _isHistoryScrollProtected,
    );
  }

  String _previousLoadAnchorKey(_PreviousLoadAnchor anchor) {
    final msgID = anchor.msgID?.trim() ?? '';
    if (msgID.isNotEmpty) {
      return 'msg:$msgID';
    }
    return 'seq:${anchor.seq ?? -1}';
  }

  bool _isNearTopForHistoryLoad(ScrollMetrics metrics) {
    if (!metrics.hasPixels || !metrics.hasContentDimensions) {
      return false;
    }
    // 内容不足一屏（不可滚动）时，iOS 回弹会让 pixels 反复抖动，
    // 若仍判定 near-top 会导致分页调度死循环。此时交给首屏加载即可。
    if (metrics.maxScrollExtent <= 0) {
      return false;
    }
    if (_isOverscrollingPastTop(metrics)) {
      return false;
    }
    return metrics.pixels >= metrics.maxScrollExtent - _loadPreviousTopNearPx;
  }

  bool _shouldTriggerLoadPreviousFromScroll(
    ScrollMetrics metrics, {
    _PreviousLoadAnchor? anchor,
    bool bypassTopReachConsumed = false,
  }) {
    String? blockReason;
    if (!_shouldAllowLoadPreviousDespiteTopReach(
      anchor,
      bypassTopReachConsumed: bypassTopReachConsumed,
    )) {
      blockReason = 'consumed_this_top_reach';
    } else if (_paginationUi.ignoreScrollLoadPrevious > 0) {
      blockReason = 'ignore_scroll';
    } else if (_paginationUi.isLoadingPrevious) {
      blockReason = 'loading_previous';
    } else if (_paginationUi.loadPreviousTask != null) {
      blockReason = 'load_task_in_flight';
    } else if (_isSearchJumpStabilizing) {
      blockReason = 'search_jump_stabilizing';
    } else if (_isHistoryScrollProtected) {
      blockReason = 'scroll_protected';
    }
    if (blockReason != null) {
      _logScrollLoadPreviousBlocked(
        metrics: metrics,
        reason: blockReason,
      );
      return false;
    }
    if (!metrics.hasPixels || !metrics.hasContentDimensions) {
      return false;
    }
    // 不可滚动列表（内容不足一屏）不参与滚动分页，避免回弹抖动触发死循环。
    if (metrics.maxScrollExtent <= 0) {
      return false;
    }
    if (_isOverscrollingPastTop(metrics)) {
      return false;
    }
    final nearTop =
        metrics.pixels >= metrics.maxScrollExtent - _loadPreviousTopNearPx;
    if (nearTop) {
      ChatHistoryTrace.log(
        'scroll_near_top',
        conversationID: _conversationId(),
        extras: <String, Object?>{
          'pixels': metrics.pixels.toStringAsFixed(1),
          'maxExtent': metrics.maxScrollExtent.toStringAsFixed(1),
          'haveMoreData': widget.model.haveMoreData,
        },
      );
    }
    return nearTop;
  }

  void _logScrollLoadPreviousBlocked({
    required ScrollMetrics metrics,
    required String reason,
  }) {
    if (!metrics.hasPixels || !metrics.hasContentDimensions) {
      return;
    }
    if (metrics.pixels < metrics.maxScrollExtent - _loadPreviousTopNearPx) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _paginationUi.lastScrollBlockLogMs < 800) {
      return;
    }
    _paginationUi.lastScrollBlockLogMs = nowMs;
    ChatHistoryTrace.log(
      'scroll_load_blocked',
      conversationID: _conversationId(),
      extras: <String, Object?>{
        'reason': reason,
        'pixels': metrics.pixels.toStringAsFixed(1),
        'maxExtent': metrics.maxScrollExtent.toStringAsFixed(1),
        'haveMoreData': widget.model.haveMoreData,
        'triedAfterNoMore': _paginationUi.triedPreviousAfterNoMore,
      },
    );
  }

  void _scheduleLoadPrevious(
    _PreviousLoadAnchor? anchor, {
    bool silent = false,
    bool allowAfterRevealForViewportFill = false,
    bool bypassTopReachConsumed = false,
  }) {
    if (silent && _historyOpenRevealReady && !allowAfterRevealForViewportFill) {
      ChatGeomSettleTrace.noteReason(
        'schedule_previous_silent_blocked_post_reveal',
        extras: <String, Object?>{
          'haveMoreData': widget.model.haveMoreData,
          'anchorMsgID': anchor?.msgID,
        },
      );
      return;
    }
    if (anchor == null) {
      ChatHistoryTrace.log(
        'schedule_previous_no_anchor',
        conversationID: _conversationId(),
        extras: <String, Object?>{
          'haveMoreData': widget.model.haveMoreData,
        },
      );
      return;
    }
    if (_isSearchJumpStabilizing ||
        _isHistoryScrollProtected ||
        !_shouldAllowLoadPreviousDespiteTopReach(
          anchor,
          bypassTopReachConsumed: bypassTopReachConsumed,
        ) ||
        _paginationUi.loadPreviousTask != null) {
      ChatHistoryTrace.log(
        'schedule_previous_blocked',
        conversationID: _conversationId(),
        extras: <String, Object?>{
          'searchJump': _isSearchJumpStabilizing,
          'scrollProtected': _isHistoryScrollProtected,
          'consumedTopReach': _paginationUi.previousLoadConsumedThisTopReach,
          'taskInFlight': _paginationUi.loadPreviousTask != null,
        },
      );
      return;
    }
    if (!widget.model.haveMoreData && _paginationUi.triedPreviousAfterNoMore) {
      ChatHistoryTrace.log(
        'schedule_previous_no_more',
        conversationID: _conversationId(),
        extras: const <String, Object?>{
          'triedAfterNoMore': true,
        },
      );
      return;
    }
    final anchorKey = _previousLoadAnchorKey(anchor);
    if (_paginationUi.previousLoadInFlightAnchorKey == anchorKey) {
      ChatHistoryTrace.log(
        'schedule_previous_duplicate_anchor',
        conversationID: _conversationId(),
        extras: <String, Object?>{
          'anchorKey': anchorKey,
        },
      );
      return;
    }
    if (!_canScheduleLoadPrevious()) {
      ChatHistoryTrace.log(
        'schedule_previous_cooldown',
        conversationID: _conversationId(),
        extras: <String, Object?>{
          'loadingPrevious': _paginationUi.isLoadingPrevious,
          'searchJump': _isSearchJumpStabilizing,
          'scrollProtected': _isHistoryScrollProtected,
        },
      );
      return;
    }
    ChatHistoryTrace.log(
      'schedule_previous_debounce',
      conversationID: _conversationId(),
      extras: <String, Object?>{
        'anchorMsgID': anchor.msgID,
        'anchorSeq': anchor.seq,
        'haveMoreData': widget.model.haveMoreData,
        'silent': silent,
      },
    );
    _markTopHistoryLoadingScheduled(silent: silent);
    // 始终记录最新锚点，供计时器触发时使用。
    _pendingLoadPreviousAnchor = anchor;
    // 已有计时器在跑时不要重置：否则连续滚动（尤其顶部橡皮筋回弹）会把
    // debounce 无限重启，导致加载永远等不到静默期而触发不了。
    if (_paginationUi.loadPreviousDebounce?.isActive ?? false) {
      return;
    }
    _paginationUi.loadPreviousDebounce =
        Timer(const Duration(milliseconds: _loadPreviousDebounceMs), () {
      final pendingAnchor = _pendingLoadPreviousAnchor ?? anchor;
      _pendingLoadPreviousAnchor = null;
      if (!_canScheduleLoadPrevious()) {
        _clearTopHistoryLoading();
        ChatHistoryTrace.log(
          'schedule_previous_debounce_cancelled',
          conversationID: _conversationId(),
          extras: const <String, Object?>{'reason': 'cooldown_after_debounce'},
        );
        return;
      }
      if (_paginationUi.previousLoadInFlightAnchorKey ==
          _previousLoadAnchorKey(pendingAnchor)) {
        _clearTopHistoryLoading();
        return;
      }
      _loadPrevious(pendingAnchor);
    });
  }

  bool _allowsLatestHistoryPagination(TUIChatGlobalModel globalModel) {
    if (_isSearchJumpHistoryMode(globalModel)) {
      return true;
    }
    final listPosition = globalModel.getMessageListPosition(_conversationId());
    // 读历史（一屏外/非最新）期间禁止 latest 探测 replace 列表；回底后再补拉。
    return listPosition == HistoryMessagePosition.bottom ||
        listPosition == HistoryMessagePosition.inTwoScreen;
  }

  bool _shouldAttemptLatestHistoryLoad({
    required TUIChatGlobalModel globalModel,
    required int safeUnreadCount,
    bool fromItemBuilder = false,
  }) {
    if (!_canProbeLatestHistory(globalModel) ||
        globalModel.isRestoringScrollAfterMediaPreview ||
        _paginationUi.isLoadingPrevious ||
        _paginationUi.isLoadingLatest) {
      return false;
    }
    final listPosition = globalModel.getMessageListPosition(_conversationId());
    final searchJump = _isSearchJumpHistoryMode(globalModel);
    if (!SearchJumpLatestGate.shouldAllowLatestPagination(
      position: listPosition,
      haveMoreLatestData: widget.model.haveMoreLatestData,
      memoryWindowMissingNewer:
          globalModel.memoryWindowMissingNewer(_conversationId()),
    )) {
      return false;
    }
    // 上翻补偿忽略期内：普通 latest 探测暂停；但内存窗口已裁掉较新端时仍允许补拉。
    if (_paginationUi.ignoreScrollLoadPrevious > 0 &&
        !globalModel.memoryWindowMissingNewer(_conversationId())) {
      return false;
    }
    if (!_allowsLatestHistoryPagination(globalModel)) {
      return false;
    }
    if (fromItemBuilder && searchJump) {
      return true;
    }
    return _isNearLatestScrollEdge(
      _singleScrollPositionOrNull(),
      relaxed: searchJump,
    );
  }

  bool _canScheduleLoadLatest() => _paginationUi.canScheduleLoadLatest();

  void _scheduleLoadLatest(
    _PreviousLoadAnchor? anchor, {
    required TUIChatGlobalModel globalModel,
    required int safeUnreadCount,
  }) {
    if (anchor == null) {
      return;
    }
    // 进页 settle：暖窗已贴底展示时推迟向下探测，避免 loadLatest 原样回写叠在 spacer 校正上。
    if (_routeScroll.openedWithCachedHistory && _isInitialRouteSettleWindow) {
      return;
    }
    if (globalModel.isUserScrollToBottomInProgress(_conversationId())) {
      return;
    }
    if (!_shouldLoadLatestOnScroll(
      globalModel: globalModel,
      safeUnreadCount: safeUnreadCount,
    )) {
      return;
    }
    _paginationUi.loadLatestDebounce?.cancel();
    _paginationUi.loadLatestDebounce =
        Timer(const Duration(milliseconds: 220), () {
      if (!_canScheduleLoadLatest()) {
        return;
      }
      _loadLatest(anchor, globalModel: globalModel);
    });
  }

  Future<void> _loadLatest(
    _PreviousLoadAnchor anchor, {
    required TUIChatGlobalModel globalModel,
    int drainRound = 0,
  }) async {
    if (_paginationUi.isLoadingLatest || !mounted) {
      return;
    }
    if (!_canProbeLatestHistory(globalModel)) {
      return;
    }
    const maxDrainRounds = 6;
    final searchJump = _isSearchJumpHistoryMode(globalModel);
    final loadPosition = _singleScrollPositionOrNull();
    final wasNearLatest = loadPosition != null &&
        _isNearLatestScrollEdge(loadPosition, relaxed: searchJump);
    final beforeCount =
        globalModel.getMessageList(_conversationId())?.length ?? 0;

    _paginationUi.isLoadingLatest = true;
    if (mounted && drainRound == 0) {
      loadingPlace = LoadingPlace.top;
      setState(() {});
    }
    try {
      await widget.model.loadChatRecord(
        direction: LoadDirection.latest,
        count: HistoryMessageDartConstant.getCount,
        lastMsgID: anchor.msgID,
        lastMsgSeq: anchor.seq ?? -1,
      );
      if (!mounted) {
        return;
      }
      final afterCount =
          globalModel.getMessageList(_conversationId())?.length ?? 0;
      final loadedMore = afterCount > beforeCount;
      if (wasNearLatest && loadedMore) {
        await _pinScrollToLatestAfterAppend();
      }
      if (loadedMore &&
          widget.model.haveMoreLatestData &&
          wasNearLatest &&
          drainRound < maxDrainRounds) {
        final nextAnchor = _anchorForLatestLoad(
          _visibleMessageList(
            globalModel.getMessageList(_conversationId()) ?? widget.messageList,
          ),
        );
        final stillNearLatest = _isNearLatestScrollEdge(
          _singleScrollPositionOrNull(),
          relaxed: searchJump,
        );
        if (nextAnchor != null && stillNearLatest) {
          _paginationUi.isLoadingLatest = false;
          await _loadLatest(
            nextAnchor,
            globalModel: globalModel,
            drainRound: drainRound + 1,
          );
          return;
        }
      }
    } finally {
      _paginationUi.lastLoadLatestCompletedAtMs =
          DateTime.now().millisecondsSinceEpoch;
      if (mounted) {
        _paginationUi.isLoadingLatest = false;
        if (loadingPlace == LoadingPlace.top) {
          loadingPlace = LoadingPlace.none;
          setState(() {});
        }
      }
    }
  }

  Future<void> _pinScrollToLatestAfterAppend({int attempt = 0}) async {
    const maxAttempts = 12;
    if (!mounted) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      if (attempt < maxAttempts) {
        await Future<void>.delayed(const Duration(milliseconds: 32));
        return _pinScrollToLatestAfterAppend(attempt: attempt + 1);
      }
      return;
    }
    final target = position.minScrollExtent;
    if ((position.pixels - target).abs() > 0.5) {
      _geomJumpTo(target, reason: 'jump__pinScrollToLatestAfterAppend');
    }
    if (attempt < maxAttempts - 1) {
      await Future<void>.delayed(const Duration(milliseconds: 48));
      return _pinScrollToLatestAfterAppend(attempt: attempt + 1);
    }
  }

  bool _renderObjectNeedsLayout(RenderObject renderObject) {
    var needsLayout = false;
    assert(() {
      needsLayout = renderObject.debugNeedsLayout;
      return true;
    }());
    return needsLayout;
  }

  bool _isNearLatestScrollEdge(
    ScrollMetrics? metrics, {
    bool relaxed = false,
  }) {
    if (metrics == null) {
      return false;
    }
    if (!metrics.hasPixels || !metrics.hasContentDimensions) {
      return false;
    }
    final viewport = metrics.viewportDimension;
    final threshold = relaxed ? (viewport * 0.35).clamp(160.0, 720.0) : 96.0;
    return metrics.pixels <= metrics.minScrollExtent + threshold;
  }

  bool _shouldLoadLatestOnScroll({
    required TUIChatGlobalModel globalModel,
    required int safeUnreadCount,
  }) {
    return _shouldAttemptLatestHistoryLoad(
      globalModel: globalModel,
      safeUnreadCount: safeUnreadCount,
    );
  }

  bool _shouldAutoLoadLatest({
    required TUIChatGlobalModel globalModel,
    required int safeUnreadCount,
  }) {
    return _shouldAttemptLatestHistoryLoad(
      globalModel: globalModel,
      safeUnreadCount: safeUnreadCount,
      fromItemBuilder: true,
    );
  }

  bool get _isSearchJumpStabilizing {
    return DateTime.now().millisecondsSinceEpoch < _searchJumpStabilizeUntilMs;
  }

  void _lockSearchJumpStabilization({int milliseconds = 900}) {
    final until = DateTime.now().millisecondsSinceEpoch + milliseconds;
    if (until > _searchJumpStabilizeUntilMs) {
      _searchJumpStabilizeUntilMs = until;
    }
    // 搜索/引用定位拉史期间禁止窗口裁剪，避免目标消息被 trim。
    _chatGlobalModel?.setMemoryWindowSuppressed(_conversationId(), true);
  }

  Future<void> _loadPrevious(_PreviousLoadAnchor anchor) async {
    if (_paginationUi.loadPreviousTask != null) {
      return _paginationUi.loadPreviousTask;
    }
    if (_paginationUi.isLoadingPrevious || !mounted) {
      _clearTopHistoryLoading();
      return;
    }
    if (!widget.model.haveMoreData && _paginationUi.triedPreviousAfterNoMore) {
      _clearTopHistoryLoading();
      return;
    }

    _paginationUi.markTopReachConsumedForPreviousLoad(
      _previousLoadAnchorKey(anchor),
    );
    _paginationUi.loadPreviousDebounce?.cancel();
    _paginationUi.loadPreviousDebounce = null;
    final task = _loadPreviousImpl(anchor);
    _paginationUi.loadPreviousTask = task;
    try {
      await task;
    } finally {
      if (identical(_paginationUi.loadPreviousTask, task)) {
        _paginationUi.loadPreviousTask = null;
      }
    }
  }

  Future<void> _loadPreviousImpl(_PreviousLoadAnchor anchor) async {
    if (_paginationUi.isLoadingPrevious || !mounted) {
      _clearTopHistoryLoading();
      return;
    }
    if (!widget.model.haveMoreData) {
      if (_paginationUi.triedPreviousAfterNoMore) {
        _clearTopHistoryLoading();
        return;
      }
      _paginationUi.triedPreviousAfterNoMore = true;
    }
    _paginationUi.isLoadingPrevious = true;
    _paginationUi.pendingLoadPrevious = false;
    _paginationUi.previousLoadInFlightAnchorKey =
        _previousLoadAnchorKey(anchor);
    _paginationUi.paginationRestoreAnchorMsgID = anchor.msgID;
    _paginationUi.paginationRestoreAnchorSeq = anchor.seq;
    _beginHistoryScrollProtection();
    _beginScrollPaginationCompensation();
    _paginationUi.ignoreScrollLoadPrevious += 2;
    // 上拉分页 + 读历史期间禁止窗口裁剪，避免刚 prepend 的行被 trim 掉。
    if (!_isSearchJumpStabilizing) {
      _chatGlobalModel?.setMemoryWindowSuppressed(_conversationId(), true);
    }
    _chatGlobalModel?.setMemoryWindowAnchor(
      _conversationId(),
      msgID: anchor.msgID,
      seq: anchor.seq?.toString(),
    );
    _chatGlobalModel?.setMessageListPosition(
      _conversationId(),
      HistoryMessagePosition.notShowLatest,
      notify: false,
    );
    // 上拉分页期间勿清空 short-history spacer，否则 maxScrollExtent 先缩后扩导致补偿失真。
    double anchorPixels = 0;
    double anchorMaxExtent = 0;
    final loadPosition = _singleScrollPositionOrNull();
    if (loadPosition != null &&
        loadPosition.hasPixels &&
        loadPosition.hasContentDimensions) {
      anchorMaxExtent = loadPosition.maxScrollExtent;
      anchorPixels = loadPosition.pixels;
    }
    _paginationUi.loadingIndicatorTimer?.cancel();
    if (mounted) {
      // 静默补拉不改 loadingPlace，避免顶部转圈被点亮。
      if (!_paginationUi.silentTopHistoryLoading) {
        loadingPlace = LoadingPlace.top;
      }
      setState(() {});
    }
    var loaded = false;
    final listLenBefore = _rawMessageCount();
    final compensationGeneration =
        ++_paginationUi.scrollPaginationCompensationGeneration;
    try {
      ChatHistoryTrace.log(
        'load_previous_start',
        conversationID: _conversationId(),
        extras: <String, Object?>{
          'anchorMsgID': anchor.msgID,
          'anchorSeq': anchor.seq,
          'listLenBefore': listLenBefore,
          'widgetListLenBefore': widget.messageList.length,
          'haveMoreData': widget.model.haveMoreData,
          'anchorPixels': anchorPixels,
          'anchorMaxExtent': anchorMaxExtent,
          'memorySuppressed':
              _chatGlobalModel?.isMemoryWindowSuppressed(_conversationId()) ??
                  false,
          'position':
              _chatGlobalModel?.getMessageListPosition(_conversationId()).name,
        },
      );
      ChatJitterDiag.log(
        'history_pagination',
        conv: _conversationId(),
        extras: <String, Object?>{
          'stage': 'ui_load_start',
          'anchorMsgID': anchor.msgID,
          'anchorSeq': anchor.seq,
          'listLenBefore': listLenBefore,
          'widgetListLenBefore': widget.messageList.length,
          'anchorPixels': anchorPixels,
          'anchorMaxExtent': anchorMaxExtent,
        },
      );
      loaded = await widget.onLoadMore(
        anchor.msgID,
        LoadDirection.previous,
        null,
        anchor.seq,
      );
    } catch (error) {
      ChatHistoryTrace.log(
        'load_previous_error',
        conversationID: _conversationId(),
        extras: <String, Object?>{
          'error': error.toString(),
        },
      );
      _paginationUi.previousLoadConsumedThisTopReach = false;
      _paginationUi.lastTopReachConsumedAnchorKey = null;
      _clearScrollPaginationCompensation();
      rethrow;
    } finally {
      _paginationUi.loadingIndicatorTimer?.cancel();
      _paginationUi.lastLoadPreviousCompletedAtMs =
          DateTime.now().millisecondsSinceEpoch;
      if (mounted) {
        _paginationUi.isLoadingPrevious = false;
        _paginationUi.latestLoadSuppressedUntilMs =
            DateTime.now().millisecondsSinceEpoch + _historyScrollProtectMs;
        _beginHistoryScrollProtection();
        final listLenAfter = _rawMessageCount();
        // 分页层可能返回 loaded=true 但列表未增长；视口补偿只应在真正 prepend 后执行。
        final effectiveLoaded = loaded && listLenAfter > listLenBefore;
        if (!effectiveLoaded) {
          // 空批/拒绝 shrink/无新增：保留贴顶消费位，避免同顶连拉导致列表振荡。
          _clearPaginationRestoreAnchor();
          _clearScrollPaginationCompensation();
          _cancelPaginationPrependReveal(notify: false);
          _clearTopHistoryLoading(notify: false);
        } else {
          // 不做 opacity 隐藏 + 二次 reveal：依赖 ScrollPhysics 同步补偿，新消息直接从顶部插入。
          _cancelPaginationPrependReveal(notify: false);
          _clearTopHistoryLoading(notify: false);
          _extendScrollPaginationCompensation();
          _scheduleScrollPaginationCompensationEnd(
            generation: compensationGeneration,
            anchorPixels: anchorPixels,
            anchorMaxExtent: anchorMaxExtent,
          );
          // 列表已增长：放开同一次贴顶消费位，便于继续上滑/回弹拉下一页。
          // 空批仍走上方分支保留消费位；此处不自动连拉，等下一次滚动事件。
          _paginationUi.releaseTopReachConsumedAfterSuccessfulPage(
            haveMoreData: widget.model.haveMoreData,
          );
        }
        _scheduleMinTopHistoryLoadingHold();
        ChatHistoryTrace.log(
          'load_previous_done',
          conversationID: _conversationId(),
          extras: <String, Object?>{
            'loaded': loaded,
            'effectiveLoaded': effectiveLoaded,
            'listLenBefore': listLenBefore,
            'listLenAfter': listLenAfter,
            'widgetListLenAfter': widget.messageList.length,
            'haveMoreData': widget.model.haveMoreData,
            'triedAfterNoMore': _paginationUi.triedPreviousAfterNoMore,
            'delta': listLenAfter - listLenBefore,
            'topReachConsumed': _paginationUi.previousLoadConsumedThisTopReach,
            'releasedTopReach': effectiveLoaded && widget.model.haveMoreData,
          },
        );
        ChatJitterDiag.log(
          'history_pagination',
          conv: _conversationId(),
          extras: <String, Object?>{
            'stage': 'ui_load_done',
            'loaded': loaded,
            'effectiveLoaded': effectiveLoaded,
            'listLenBefore': listLenBefore,
            'listLenAfter': listLenAfter,
            'widgetListLenAfter': widget.messageList.length,
            'delta': listLenAfter - listLenBefore,
          },
        );
        ChatResourceSample.onRawMessageCount(_rawMessageCount());
        setState(() {});
        _finishPreviousLoadPagination();
        Future<void>.delayed(
            const Duration(milliseconds: _loadPreviousScrollUnlockMs), () {
          if (mounted) {
            if (_paginationUi.ignoreScrollLoadPrevious >= 2) {
              _paginationUi.ignoreScrollLoadPrevious -= 2;
            } else if (_paginationUi.ignoreScrollLoadPrevious > 0) {
              _paginationUi.ignoreScrollLoadPrevious = 0;
            }
          }
        });
      } else {
        _paginationUi.previousLoadInFlightAnchorKey = null;
      }
    }
  }

  bool _messageMatchesTarget(V2TimMessage? current, V2TimMessage target) {
    if (current == null || current.elemType == 11 || current.elemType == 101) {
      return false;
    }
    final targetMsgID = target.msgID?.trim() ?? '';
    final currentMsgID = current.msgID?.trim() ?? '';
    if (targetMsgID.isNotEmpty && currentMsgID.isNotEmpty) {
      return currentMsgID == targetMsgID;
    }
    final targetId = target.id?.trim() ?? '';
    final currentId = current.id?.trim() ?? '';
    if (targetId.isNotEmpty && currentId.isNotEmpty) {
      return currentId == targetId;
    }
    final targetSeq = target.seq?.trim() ?? '';
    final currentSeq = current.seq?.trim() ?? '';
    if (targetSeq.isNotEmpty && currentSeq.isNotEmpty) {
      return currentSeq == targetSeq;
    }
    if ((targetMsgID.isNotEmpty &&
            currentMsgID.isNotEmpty &&
            currentMsgID != targetMsgID) ||
        (targetId.isNotEmpty &&
            currentId.isNotEmpty &&
            currentId != targetId) ||
        (targetSeq.isNotEmpty &&
            currentSeq.isNotEmpty &&
            currentSeq != targetSeq)) {
      return false;
    }
    final targetSender = target.sender?.trim() ?? target.userID?.trim() ?? '';
    final currentSender =
        current.sender?.trim() ?? current.userID?.trim() ?? '';
    if (current.timestamp != null &&
        target.timestamp != null &&
        current.timestamp == target.timestamp) {
      return targetSender.isNotEmpty &&
          currentSender.isNotEmpty &&
          targetSender == currentSender &&
          target.elemType != null &&
          current.elemType != null &&
          target.elemType == current.elemType;
    }
    return false;
  }

  int? _globalIndexForTargetMessage(V2TimMessage target) {
    final messageList = _visibleMessageList(widget.messageList);
    int? matchedIndex;
    for (var i = 0; i < messageList.length; i++) {
      if (_messageMatchesTarget(messageList[i], target)) {
        if (matchedIndex != null) {
          return null;
        }
        matchedIndex = i;
      }
    }
    return matchedIndex;
  }

  int? _globalIndexForAnchor(MessageAnchor target) {
    final messageList = _visibleMessageList(widget.messageList);
    int? matchedIndex;
    for (var i = 0; i < messageList.length; i++) {
      if (target.matches(messageList[i])) {
        if (matchedIndex != null) {
          return null;
        }
        matchedIndex = i;
      }
    }
    return matchedIndex;
  }

  int? _globalIndexForSeq(String targetSeq) {
    final messageList = _visibleMessageList(widget.messageList);
    final want = int.tryParse(targetSeq.trim());
    for (var i = 0; i < messageList.length; i++) {
      final message = messageList[i];
      if (message == null ||
          message.elemType == 11 ||
          message.elemType == 101) {
        continue;
      }
      final raw = message.seq?.trim() ?? '';
      if (raw == targetSeq.trim()) {
        return i;
      }
      if (want != null) {
        final current = int.tryParse(raw);
        if (current != null && current == want) {
          return i;
        }
      }
    }
    return null;
  }

  V2TimMessage? _messageForAnchor(MessageAnchor target) {
    final messageList = _visibleMessageList(widget.messageList);
    for (final message in messageList) {
      if (target.matches(message)) {
        return message;
      }
    }
    return null;
  }

  bool _scrollMetricsReady() {
    final position = _singleScrollPositionOrNull();
    return position != null &&
        position.hasPixels &&
        position.hasContentDimensions &&
        position.maxScrollExtent.isFinite &&
        position.minScrollExtent.isFinite;
  }

  bool _isInitialFindingTarget(V2TimMessage target) {
    final initial = widget.initFindingMsg;
    return initial != null && _messageMatchesTarget(initial, target);
  }

  void _scheduleScrollToFindingMsgDelayed({
    Duration delay = const Duration(milliseconds: 120),
  }) {
    Future<void>.delayed(delay, () {
      if (mounted) {
        _scheduleScrollToFindingMsg();
      }
    });
  }

  int? _resolveSearchJumpGlobalIndex(_SearchJumpTarget target) {
    return target.resolveIndex();
  }

  _SearchJumpFrameCheck? _checkSearchJumpTargetFrame(
    _SearchJumpTarget target,
  ) {
    final targetGlobalIndex = _resolveSearchJumpGlobalIndex(target);
    if (targetGlobalIndex == null) {
      return null;
    }
    final tagContext =
        _autoScrollController.tagMap[-targetGlobalIndex]?.context;
    if (tagContext == null) {
      return _SearchJumpFrameCheck.notReady(targetGlobalIndex);
    }
    final scrollable = Scrollable.maybeOf(tagContext);
    if (scrollable == null) {
      return _SearchJumpFrameCheck.notReady(targetGlobalIndex);
    }
    final targetRenderObject = tagContext.findRenderObject();
    final viewportRenderObject = scrollable.context.findRenderObject();
    if (targetRenderObject is! RenderBox ||
        viewportRenderObject is! RenderBox ||
        !targetRenderObject.attached ||
        !viewportRenderObject.attached ||
        !targetRenderObject.hasSize ||
        !viewportRenderObject.hasSize ||
        _renderObjectNeedsLayout(targetRenderObject) ||
        _renderObjectNeedsLayout(viewportRenderObject)) {
      return _SearchJumpFrameCheck.notReady(targetGlobalIndex);
    }

    final targetTop = targetRenderObject
        .localToGlobal(Offset.zero, ancestor: viewportRenderObject)
        .dy;
    final targetCenter = targetTop + targetRenderObject.size.height / 2;
    final viewportCenter = viewportRenderObject.size.height / 2;
    final centerDelta = targetCenter - viewportCenter;
    final tolerance =
        (viewportRenderObject.size.height * 0.08).clamp(28.0, 72.0);
    return _SearchJumpFrameCheck(
      targetGlobalIndex: targetGlobalIndex,
      isReady: true,
      centerDelta: centerDelta,
      tolerance: tolerance,
    );
  }

  Future<bool> _correctSearchJumpTargetToCenter(
    _SearchJumpTarget target,
  ) async {
    final check = _checkSearchJumpTargetFrame(target);
    if (check == null) {
      return false;
    }
    final targetGlobalIndex = check.targetGlobalIndex;
    if (!check.isReady) {
      await _geomScrollToIndex(
        -targetGlobalIndex,
        preferPosition: AutoScrollPosition.middle,
        reason: 'scroll_to_index_middle',
      );
      return false;
    }
    if (check.isCentered) {
      return true;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      await _geomScrollToIndex(
        -targetGlobalIndex,
        preferPosition: AutoScrollPosition.middle,
        reason: 'scroll_to_index_middle',
      );
      return false;
    }
    await _geomScrollToIndex(
      -targetGlobalIndex,
      preferPosition: AutoScrollPosition.middle,
      reason: 'scroll_to_index_middle',
    );
    return false;
  }

  Future<bool> _stabilizeCenteredSearchJumpTarget(
    _SearchJumpTarget target, {
    required int generation,
  }) async {
    var stableFrames = 0;
    for (var attempt = 0; attempt < 14; attempt++) {
      _lockSearchJumpStabilization(milliseconds: 2600);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _searchJumpGeneration) {
        return false;
      }

      final centered = await _correctSearchJumpTargetToCenter(target);
      if (!mounted || generation != _searchJumpGeneration) {
        return false;
      }
      if (centered) {
        stableFrames++;
        if (stableFrames >= 4) {
          return true;
        }
      } else {
        stableFrames = 0;
      }
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (!mounted || generation != _searchJumpGeneration) {
        return false;
      }
    }

    final finalCheck = _checkSearchJumpTargetFrame(target);
    return finalCheck != null && finalCheck.isReady && finalCheck.isCentered;
  }

  Future<bool> _centerOnGlobalIndex(
    int targetGlobalIndex, {
    int attempt = 0,
    _SearchJumpTarget? target,
    int? generation,
  }) async {
    if (!mounted) {
      return false;
    }
    _lockSearchJumpStabilization(milliseconds: 2600);
    if (!_scrollMetricsReady()) {
      if (attempt < 12) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return _centerOnGlobalIndex(
          targetGlobalIndex,
          attempt: attempt + 1,
          target: target,
          generation: generation,
        );
      }
      return false;
    }

    // 只使用 scroll_to_index 自带的安全定位，避免在图片/视频/长文本还没
    // layout 完成时手动 getOffsetToReveal / jumpTo 触发 debugNeedsLayout 红屏。
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return false;
      }
      final resolvedTargetGlobalIndex = target == null
          ? targetGlobalIndex
          : (_resolveSearchJumpGlobalIndex(target) ?? targetGlobalIndex);
      await _geomScrollToIndex(
        -resolvedTargetGlobalIndex,
        preferPosition: AutoScrollPosition.middle,
        reason: 'scroll_to_index_middle',
      );
      final stabilized = target == null
          ? true
          : await _stabilizeCenteredSearchJumpTarget(
              target,
              generation: generation ?? _searchJumpGeneration,
            );
      _lockSearchJumpStabilization(milliseconds: 1600);
      return stabilized;
    } catch (_) {
      if (attempt < 8) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (mounted) {
          return _centerOnGlobalIndex(
            targetGlobalIndex,
            attempt: attempt + 1,
            target: target,
            generation: generation,
          );
        }
      }
      return false;
    }
  }

  void _scheduleScrollToFindingMsg() {
    if ((findingMsg == null && findingAnchor == null) ||
        _scrollToFindInFlight ||
        _pendingScrollToFind) {
      return;
    }
    _pendingScrollToFind = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScrollToFind = false;
      if (!mounted) {
        return;
      }
      final anchor = findingAnchor;
      if (anchor != null) {
        _onScrollToAnchor(anchor);
        return;
      }
      if (findingMsg != null) {
        _onScrollToIndex(findingMsg!);
      }
    });
  }

  initFinding() async {
    final anchor = widget.searchJumpAnchor;
    final target = widget.initFindingMsg;
    if (anchor == null && target == null) {
      return;
    }
    var retries = 0;
    while (widget.messageList.isEmpty && retries < 60) {
      final jumpStatus =
          _chatGlobalModel?.getSearchJumpStatus(_conversationId()) ??
              SearchJumpStatus.idle;
      if (jumpStatus == SearchJumpStatus.failed ||
          jumpStatus == SearchJumpStatus.success) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 50));
      retries++;
      if (!mounted) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    MessageAnchor? resolvedAnchor = anchor;
    if (resolvedAnchor == null && target != null) {
      resolvedAnchor = MessageAnchor.fromConversationMessage(
        widget.conversation,
        target,
      );
    }
    final jumpStatus =
        _chatGlobalModel?.getSearchJumpStatus(_conversationId()) ??
            SearchJumpStatus.idle;
    if (jumpStatus == SearchJumpStatus.failed) {
      setState(() {
        _findingRetryCount = 0;
        findingAnchor = null;
        findingMsg = null;
        maybeHaveMoreMessageForFind = false;
        loadingPlace = LoadingPlace.none;
      });
      return;
    }
    setState(() {
      _findingRetryCount = 0;
      findingAnchor = resolvedAnchor;
      findingMsg = target;
      maybeHaveMoreMessageForFind = resolvedAnchor == null && target != null;
    });
    _scheduleScrollToFindingMsg();
  }

  _controllerListener() {
    final scrollType = _controller.scrollType;
    final targetMessage = _controller.targetMessage;
    switch (scrollType) {
      case ScrollType.toIndex:
        _onScrollToIndex(targetMessage);
        break;
      case ScrollType.toIndexBegin:
        _onScrollToIndexBegin(targetMessage);
        break;
      default:
    }
  }

  String _messageEnterAnimationWidgetKey(V2TimMessage message) {
    final id = message.id;
    if (id != null && id.toString().isNotEmpty) {
      return 'msg_enter_${id.toString()}';
    }
    final msgID = message.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      return 'msg_enter_$msgID';
    }
    return 'msg_enter_${message.timestamp}_${message.seq}';
  }

  String _stableMessageListKey(V2TimMessage? message, int index) {
    if (message == null) {
      return 'empty_$index';
    }
    if (message.elemType == 11) {
      return 'time_${message.timestamp ?? index}';
    }
    final outgoingStableId = readOutgoingStableId(message);
    if (outgoingStableId != null) {
      return 'outgoing_$outgoingStableId';
    }
    final id = message.id;
    if (id != null && id.toString().isNotEmpty) {
      // Keep the list key stable across send-status transitions.
      // If the key changes when a self message flips between sending/fail/success,
      // Flutter treats the row as a different item and remounts it, which makes
      // the outgoing bubble visibly jump/shake multiple times.
      return 'msg_${id.toString()}';
    }
    final msgID = message.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      return 'msgid_$msgID';
    }
    // Position-independent fallback. The key MUST stay stable when a message
    // changes index, otherwise `findChildIndexCallback` (which is populated
    // with the identifier computed at index 0) cannot relocate the recycled
    // element and Flutter pins the row at a stale slot until the element tree
    // is torn down (i.e. only an app restart fixes the visual order).
    final sender = message.sender ?? message.userID ?? '';
    final random = message.random ?? '';
    final seq = message.seq ?? '';
    return 'msg_${sender}_${message.timestamp ?? ''}_${seq}_${random}_${message.elemType}';
  }

  List<V2TimMessage?> _visibleMessageList(List<V2TimMessage?> source) {
    final list = <V2TimMessage?>[];
    for (final item in source) {
      if (item == null) {
        continue;
      }
      // 零高度消息先丢掉，再折叠因此贴在一起的时间分割线，避免孤儿分割线。
      if (item.elemType != 11 &&
          item.elemType != 101 &&
          !TUIChatGlobalModel.messageAnchorsTimeDivider(item)) {
        continue;
      }
      if (item.elemType == 11 && (list.isEmpty || list.last?.elemType == 11)) {
        continue;
      }
      list.add(item);
    }
    return list;
  }

  List<V2TimMessage?> _currentVisibleMessageList() {
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    final currentMessages = globalModel.getMessageList(_conversationId());
    return _visibleMessageList(
      currentMessages == null
          ? widget.messageList
          : List<V2TimMessage?>.from(currentMessages),
    );
  }

  Widget _getMessageItemBuilder(V2TimMessage? messageItem) {
    if (widget.itemBuilder != null) {
      final child = widget.itemBuilder!(context, messageItem);
      if (messageItem == null) {
        return child;
      }
      final elemType = messageItem.elemType;
      if (elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS ||
          elemType == 11 ||
          elemType == 101) {
        return child;
      }
      final globalModel =
          Provider.of<TUIChatGlobalModel>(context, listen: false);
      final skipEnterAnimation = widget
              .mainHistoryListConfig?.skipMessageEnterAnimationForMessage
              ?.call(messageItem) ??
          globalModel.chatConfig.skipMessageEnterAnimationForMessage
              ?.call(messageItem) ??
          false;
      if (skipEnterAnimation ||
          _deferUnreadCenterPartition ||
          _isReadingHistory() ||
          globalModel.isBulkMessageSyncActive(_conversationId()) ||
          (messageItem.isSelf == true &&
              messageItem.elemType == MessageElemType.V2TIM_ELEM_TYPE_TEXT)) {
        if (globalModel.isMessageEnterAnimationPending(messageItem)) {
          globalModel.finishMessageEnterAnimation(messageItem);
        }
        return child;
      }
      if (globalModel.isMessageEnterAnimationPending(messageItem)) {
        final rowKey = _stableMessageListKey(messageItem, 0);
        final wechatListPush = _useWechatListPushTranslate(globalModel);
        // Row reveal / WeChat list-push owns the motion. A bubble slide on top
        // would double-push (inbound and self).
        if (_viewportInsert.activeRowRevealMessages.containsKey(rowKey) ||
            (wechatListPush && _viewportInsert.viewportInsertSlideActive)) {
          return child;
        }
        // 发送在微信 list-push 模式下永不走气泡滑入：否则会与 list-push /
        // force-pin 叠成「出现抖动」。list-push 收尾会 finish；若本帧未武装
        // 上推则立刻 finish，避免 pending 粘住。
        if (wechatListPush && messageItem.isSelf == true) {
          if (!_viewportInsert.activeRowRevealMessages.containsKey(rowKey) &&
              !_viewportInsert.viewportInsertSlideActive) {
            globalModel.finishMessageEnterAnimation(messageItem);
          }
          return child;
        }
        if (_isSearchJumpStabilizing) {
          globalModel.finishMessageEnterAnimation(messageItem);
          return child;
        }
        final stableKey = _messageEnterAnimationWidgetKey(messageItem);
        final enterParams = MessageEnterAnimationParams.fromStyle(
          globalModel.chatConfig.messageEnterAnimationStyle,
          isOutgoing: messageItem.isSelf == true,
        );
        return _MessageEnterAnimationGate(
          message: messageItem,
          globalModel: globalModel,
          stableKey: stableKey,
          enterParams: enterParams,
          animateExtent: false,
          onEnterAnimationFinished: messageItem.isSelf != true && wechatListPush
              ? _acknowledgeInboundProjectionRevealIfNeeded
              : null,
          child: child,
        );
      }
      return child;
    }
    return Container();
  }

  bool _isHeavyListMessage(V2TimMessage? message) {
    if (message == null) {
      return false;
    }
    switch (message.elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        final checker = widget.mainHistoryListConfig?.isHeavyCustomMessage;
        return checker != null ? checker(message) : false;
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        // 不再因「文字长」KeepAlive；避免 Window≈120 时长文 Element 常驻。
        // 特殊交互态如需保活，由业务显式 checker / 其它路径处理。
        return false;
      default:
        return false;
    }
  }

  bool _isOutgoingMediaMessage(V2TimMessage message) {
    if (message.isSelf != true) {
      return false;
    }
    switch (message.elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return true;
      default:
        return false;
    }
  }

  String _listStateCacheKey(List<V2TimMessage?> messageList) {
    final buffer = StringBuffer();
    // messageList is newest-first; scan the head where sends/reorders happen.
    final scanEnd = messageList.length > 16 ? 16 : messageList.length;
    for (var i = 0; i < scanEnd; i++) {
      final message = messageList[i];
      if (message == null || message.elemType == 11) {
        continue;
      }
      final id = message.msgID ?? message.id ?? '$i';
      final seq = message.seq ?? '';
      buffer.write('$id:$seq:${message.status};');
    }
    return buffer.toString();
  }

  bool _isRealChatMessage(V2TimMessage? message) {
    return message != null && message.elemType != 11;
  }

  bool _isUnreadAnchorMessage(V2TimMessage? message) {
    return _isRealChatMessage(message) && message?.elemType != 101;
  }

  int _unreadAnchorMessageCount(List<V2TimMessage?> messageList) {
    return messageList.where(_isUnreadAnchorMessage).length;
  }

  int _realUnreadEndPoint(
    List<V2TimMessage?> messageList,
    int unreadMessageCount,
  ) {
    if (unreadMessageCount <= 0 || messageList.isEmpty) {
      return 0;
    }
    var realCount = 0;
    var end = 0;
    while (end < messageList.length && realCount < unreadMessageCount) {
      if (_isUnreadAnchorMessage(messageList[end])) {
        realCount++;
      }
      end++;
    }
    if (end < messageList.length && messageList[end]?.elemType == 11) {
      end++;
    }
    return end.clamp(0, messageList.length).toInt();
  }

  int? _firstUnreadGlobalIndex(
    List<V2TimMessage?> messageList,
    int unreadMessageCount,
  ) {
    if (unreadMessageCount <= 0 || messageList.isEmpty) {
      return null;
    }
    var realCount = 0;
    for (var i = 0; i < messageList.length; i++) {
      final message = messageList[i];
      if (!_isUnreadAnchorMessage(message)) {
        continue;
      }
      realCount++;
      if (realCount == unreadMessageCount) {
        return i;
      }
    }
    return null;
  }

  _UnreadMessageAnchor? _unreadAnchorFromCount(
    List<V2TimMessage?> messageList,
    int unreadMessageCount,
  ) {
    var realCount = 0;
    V2TimMessage? message;
    for (final item in messageList) {
      if (!_isUnreadAnchorMessage(item)) {
        continue;
      }
      realCount++;
      if (realCount == unreadMessageCount) {
        message = item;
        break;
      }
    }
    if (message == null) {
      return null;
    }
    final identity = _messageIdentity(message);
    final seq = int.tryParse(message.seq?.trim() ?? '');
    if (identity.isEmpty && (seq == null || seq <= 0)) {
      return null;
    }
    return _UnreadMessageAnchor(
      conversationID: _conversationId(),
      identity: identity,
      seq: seq,
    );
  }

  int? _globalIndexForUnreadAnchor(
    List<V2TimMessage?> messageList,
    _UnreadMessageAnchor anchor,
  ) {
    for (var i = 0; i < messageList.length; i++) {
      final message = messageList[i];
      if (!_isUnreadAnchorMessage(message)) {
        continue;
      }
      if (anchor.identity.isNotEmpty &&
          _messageIdentity(message!) == anchor.identity) {
        return i;
      }
      if (anchor.seq != null &&
          int.tryParse(message!.seq?.trim() ?? '') == anchor.seq) {
        return i;
      }
    }
    return null;
  }

  void _captureFirstUnreadAnchor(
    List<V2TimMessage?> messageList,
    int unreadMessageCount,
  ) {
    if (unreadMessageCount <= 0 ||
        _unreadAnchorMessageCount(messageList) < unreadMessageCount ||
        (_firstUnreadAnchor != null &&
            _firstUnreadAnchor!.conversationID == _conversationId())) {
      return;
    }
    _firstUnreadAnchor =
        _unreadAnchorFromCount(messageList, unreadMessageCount);
  }

  Future<_UnreadMessageAnchor?> _ensureFirstUnreadAnchor(
    int unreadMessageCount,
  ) async {
    final existing = _firstUnreadAnchor;
    if (existing != null && existing.conversationID == _conversationId()) {
      return existing;
    }
    // 大未读禁止按条数追翻；仅小未读 count_fallback 可用。
    if (unreadMessageCount > FirstUnreadJump.maxCountFallbackUnread) {
      return null;
    }
    final maxRounds = (unreadMessageCount / 80).ceil() + 6;
    for (var round = 0; round < maxRounds && mounted; round++) {
      final messageList = _currentVisibleMessageList();
      _captureFirstUnreadAnchor(messageList, unreadMessageCount);
      final captured = _firstUnreadAnchor;
      if (captured != null) {
        return captured;
      }
      final previousAnchor = _anchorForPreviousLoad(messageList);
      final loadedCount = _unreadAnchorMessageCount(messageList);
      final remaining = unreadMessageCount - loadedCount;
      final requestCount = remaining.clamp(1, 80).toInt();
      var loadedMore = false;
      if (previousAnchor != null) {
        loadedMore = await widget.onLoadMore(
          previousAnchor.msgID,
          LoadDirection.previous,
          requestCount,
          previousAnchor.seq,
        );
      } else {
        loadedMore = await widget.model.loadChatRecord(
          count: requestCount,
          direction: LoadDirection.previous,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!loadedMore &&
          _unreadAnchorMessageCount(_currentVisibleMessageList()) <
              unreadMessageCount) {
        final beforeCount = _unreadAnchorMessageCount(messageList);
        await widget.model.loadChatRecord(
          count: requestCount,
          direction: LoadDirection.previous,
          lastMsgID: previousAnchor?.msgID,
          lastMsgSeq: previousAnchor?.seq ?? -1,
        );
        await Future<void>.delayed(const Duration(milliseconds: 120));
        final afterCount =
            _unreadAnchorMessageCount(_currentVisibleMessageList());
        if (afterCount <= beforeCount) {
          break;
        }
      }
    }
    return _firstUnreadAnchor;
  }

  int? _latestUnreadGlobalIndex(
    List<V2TimMessage?> messageList,
    int unreadMessageCount,
  ) {
    if (unreadMessageCount <= 0 || messageList.isEmpty) {
      return null;
    }
    var realCount = 0;
    for (var i = 0; i < messageList.length; i++) {
      final message = messageList[i];
      if (!_isRealChatMessage(message)) {
        continue;
      }
      realCount++;
      if (realCount <= unreadMessageCount) {
        return i;
      }
      break;
    }
    return null;
  }

  int _realMessageCount(List<V2TimMessage?> messageList) {
    var count = 0;
    for (final message in messageList) {
      if (_isRealChatMessage(message)) {
        count++;
      }
    }
    return count;
  }

  void _scheduleInitialUnreadAnchor(
    List<V2TimMessage?> messageList,
    int unreadMessageCount,
  ) {
    if (unreadMessageCount <= 0 || messageList.isEmpty) {
      return;
    }
    final convId = _conversationId();
    if (_initialUnreadAnchorConversationID == convId &&
        _initialUnreadAnchorCount == unreadMessageCount) {
      return;
    }
    if (_initialUnreadAnchorScheduled || _initialUnreadAnchorInFlight) {
      return;
    }
    if (_realMessageCount(messageList) < unreadMessageCount) {
      if (_initialUnreadAnchorAttempts < 30 && !_initialUnreadAnchorScheduled) {
        _initialUnreadAnchorAttempts++;
        _initialUnreadAnchorScheduled = true;
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          _initialUnreadAnchorScheduled = false;
          if (mounted) {
            _scheduleInitialUnreadAnchor(
              _visibleMessageList(widget.messageList),
              unreadMessageCount,
            );
          }
        });
      }
      return;
    }
    _initialUnreadAnchorScheduled = true;
    _initialUnreadAnchorInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initialUnreadAnchorScheduled = false;
      if (!mounted) {
        _initialUnreadAnchorInFlight = false;
        return;
      }
      try {
        await _scrollToFirstUnread(
          unreadMessageCount,
          preferTop: true,
          animate: false,
          stabilize: false,
        );
      } finally {
        _initialUnreadAnchorInFlight = false;
      }
    });
  }

  Future<void> _scrollToLatestUnread(
    int unreadMessageCount, {
    int attempt = 0,
  }) async {
    if (!mounted || unreadMessageCount <= 0) {
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      if (attempt < 30) {
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (mounted) {
            _scrollToLatestUnread(
              unreadMessageCount,
              attempt: attempt + 1,
            );
          }
        });
      }
      return;
    }
    try {
      await _autoScrollController.animateTo(
        position.minScrollExtent,
        duration: attempt == 0
            ? const Duration(milliseconds: 1)
            : const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
      if (attempt < 2) {
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (mounted) {
            _scrollToLatestUnread(
              unreadMessageCount,
              attempt: attempt + 1,
            );
          }
        });
      } else {
        _initialUnreadAnchorConversationID = _conversationId();
        _initialUnreadAnchorCount = unreadMessageCount;
        _initialUnreadAnchorAttempts = 0;
        _completedEntryUnreadCount = 0;
        final globalModel =
            Provider.of<TUIChatGlobalModel>(context, listen: false);
        globalModel.setUnreadCountForTongue(unreadMessageCount, notify: false);
        globalModel.setUnreadTongueMetrics(
          conversationID: _conversationId(),
          remaining: unreadMessageCount,
          below: false,
          notify: true,
        );
        globalModel.setMessageListPosition(
          _conversationId(),
          HistoryMessagePosition.bottom,
          notify: false,
        );
      }
    } catch (_) {
      if (attempt < 30) {
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (mounted) {
            _scrollToLatestUnread(
              unreadMessageCount,
              attempt: attempt + 1,
            );
          }
        });
      }
    }
  }

  Future<void> _scrollToFirstUnread(
    int unreadMessageCount, {
    bool preferTop = false,
    bool animate = true,
    bool stabilize = true,
    int attempt = 0,
  }) async {
    if (!mounted || unreadMessageCount <= 0) {
      return;
    }
    final messageList = _visibleMessageList(widget.messageList);
    final targetGlobalIndex = _firstUnreadGlobalIndex(
      messageList,
      unreadMessageCount,
    );
    if (targetGlobalIndex == null) {
      if (attempt < 30) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (mounted) {
          await _scrollToFirstUnread(
            unreadMessageCount,
            preferTop: preferTop,
            animate: animate,
            stabilize: stabilize,
            attempt: attempt + 1,
          );
        }
      }
      return;
    }
    if (_singleScrollPositionOrNull() == null) {
      if (attempt < 30) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (mounted) {
          await _scrollToFirstUnread(
            unreadMessageCount,
            preferTop: preferTop,
            animate: animate,
            stabilize: stabilize,
            attempt: attempt + 1,
          );
        }
      }
      return;
    }
    try {
      final aligned = preferTop
          ? await _alignGlobalMessageIndexToViewportTop(
              targetGlobalIndex,
              animate: animate,
            )
          : await () async {
              ChatGeomSettleTrace.noteReason(
                'finding_scroll_to_index',
                extras: <String, Object?>{'index': -targetGlobalIndex},
              );
              return _autoScrollController
                  .scrollToIndex(
                    -targetGlobalIndex,
                    preferPosition: AutoScrollPosition.middle,
                  )
                  .then((_) => true)
                  .catchError((_) => false);
            }();
      if (!aligned) {
        if (attempt < 30) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          if (mounted) {
            await _scrollToFirstUnread(
              unreadMessageCount,
              preferTop: preferTop,
              animate: animate,
              stabilize: stabilize,
              attempt: attempt + 1,
            );
          }
        }
        return;
      }
      // 首次布局中图片/视频/长文本高度会在下一帧继续变化，补两次顶对齐，
      // 确保点击“xx条新消息”后稳定停在最早一条未读消息。
      if (stabilize && attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (mounted) {
          await _scrollToFirstUnread(
            unreadMessageCount,
            preferTop: preferTop,
            animate: animate,
            stabilize: stabilize,
            attempt: attempt + 1,
          );
        }
      } else {
        _initialUnreadAnchorConversationID = _conversationId();
        _initialUnreadAnchorCount = unreadMessageCount;
        _initialUnreadAnchorAttempts = 0;
        _completedEntryUnreadCount = 0;
        final globalModel =
            Provider.of<TUIChatGlobalModel>(context, listen: false);
        _lastUnreadTongueConversationID = null;
        _lastUnreadTongueRemaining = null;
        _lastUnreadTongueSafeCount = 0;
        globalModel.setUnreadCountForTongue(unreadMessageCount, notify: false);
        globalModel.setUnreadTongueMetrics(
          conversationID: _conversationId(),
          remaining: unreadMessageCount,
          below: true,
          notify: false,
        );
        globalModel.setMessageListPosition(
          _conversationId(),
          HistoryMessagePosition.awayTwoScreen,
          notify: false,
        );
        _scheduleUnreadTongueMetricsUpdate(
          _visibleMessageList(widget.messageList),
          unreadMessageCount,
          force: true,
        );
      }
    } catch (_) {
      if (attempt < 30) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (mounted) {
          await _scrollToFirstUnread(
            unreadMessageCount,
            preferTop: preferTop,
            animate: animate,
            stabilize: stabilize,
            attempt: attempt + 1,
          );
        }
      }
    }
  }

  Future<bool> _scrollToUnreadAnchor(
    _UnreadMessageAnchor anchor, {
    int attempt = 0,
    bool triedSequenceLoad = false,
  }) async {
    if (!mounted || anchor.conversationID != _conversationId()) {
      return false;
    }
    final messageList = _currentVisibleMessageList();
    final targetGlobalIndex = _globalIndexForUnreadAnchor(messageList, anchor);
    if (targetGlobalIndex == null) {
      if (!triedSequenceLoad && anchor.seq != null && anchor.seq! > 0) {
        final loaded =
            await widget.model.loadListForSpecificMessage(seq: anchor.seq!);
        if (loaded && mounted) {
          await WidgetsBinding.instance.endOfFrame;
          return _scrollToUnreadAnchor(
            anchor,
            attempt: attempt,
            triedSequenceLoad: true,
          );
        }
      }
      if (attempt < 8) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (mounted) {
          return _scrollToUnreadAnchor(
            anchor,
            attempt: attempt + 1,
            triedSequenceLoad: triedSequenceLoad,
          );
        }
      }
      return false;
    }
    return _jumpToFirstUnreadGlobalIndex(targetGlobalIndex);
  }

  Future<bool> _scrollToFirstUnreadFromTongue(int requestedUnreadCount) async {
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    final convId = _conversationId();
    globalModel.flushDeferredIncomingMessages(
      convId,
      notify: false,
      userInitiated: true,
    );
    _deferUnreadCenterPartition = false;
    _clearIncomingScrollAnchor(reason: 'jump_first_unread');
    var fallbackCount = requestedUnreadCount;
    if (globalModel.hasLockedEntryUnreadFor(convId)) {
      final lockedCount = globalModel.lockedEntryUnreadCount;
      if (lockedCount > fallbackCount) {
        fallbackCount = lockedCount;
      }
    }
    final unreadCount = globalModel.unreadCountForTongue;
    if (_initialUnreadAnchorCount > fallbackCount) {
      fallbackCount = _initialUnreadAnchorCount;
    }
    if (unreadCount > fallbackCount) {
      fallbackCount = unreadCount;
    }
    if (fallbackCount <= 0) {
      return false;
    }
    _firstUnreadAnchorJumped = true;
    _unreadEntryBottomPinScheduled = true;
    if (mounted) {
      loadingPlace = LoadingPlace.top;
      setState(() {});
    }
    try {
      final didScroll = await _jumpToFirstUnreadAroundWindow(fallbackCount);
      if (!didScroll) {
        _firstUnreadAnchorJumped = false;
        _showCantFindFirstUnread();
        return false;
      }
      _initialUnreadAnchorConversationID = convId;
      _initialUnreadAnchorCount = fallbackCount;
      _initialUnreadAnchorAttempts = 0;
      globalModel.setMessageListPosition(
        convId,
        HistoryMessagePosition.awayTwoScreen,
        notify: false,
      );
      // 跳到首条未读后：清掉入口未读胶囊计数，避免右下角变成「xxx条新消息」。
      globalModel.unlockEntryUnreadForTongue(
        conversationID: convId,
        notify: false,
      );
      globalModel.clearReceivedUnreadState(
        conversationID: convId,
        notify: false,
      );
      globalModel.markEntryUnreadTongueDismissed(
        conversationID: convId,
        unreadCount: fallbackCount,
        notify: false,
      );
      globalModel.clearUnreadTongueMetrics(convId, notify: true);
      return true;
    } finally {
      if (mounted) {
        loadingPlace = LoadingPlace.none;
        setState(() {});
      }
    }
  }

  void _showCantFindFirstUnread() {
    onTIMCallback(TIMCallback(
      type: TIMCallbackType.INFO,
      infoRecommendText: TIM_t("无法定位到首条未读"),
      infoCode: 6660401,
    ));
  }

  Future<V2TimConversation> _conversationWithFreshReadCursor() async {
    final local = widget.conversation;
    final id = local.conversationID?.trim() ?? '';
    if (id.isEmpty) {
      return local;
    }
    try {
      final fresh = await serviceLocator<ConversationService>()
          .getConversation(conversationID: id);
      if (fresh == null) {
        return local;
      }
      // Prefer live read cursors from SDK; keep UI lastMessage if fresher.
      if ((fresh.groupReadSequence ?? 0) > 0) {
        local.groupReadSequence = fresh.groupReadSequence;
      }
      if ((fresh.c2cReadTimestamp ?? 0) > 0) {
        local.c2cReadTimestamp = fresh.c2cReadTimestamp;
      }
      if (fresh.lastMessage != null) {
        local.lastMessage = fresh.lastMessage;
      }
      return local;
    } catch (_) {
      return local;
    }
  }

  int? _newestMessageSeqForUnreadJump() {
    final list = _currentVisibleMessageList();
    for (final msg in list) {
      final seq = int.tryParse(msg?.seq?.trim() ?? '') ?? 0;
      if (seq > 0) {
        return seq;
      }
    }
    return int.tryParse(widget.conversation.lastMessage?.seq?.trim() ?? '');
  }

  void _logFirstUnreadJump(String event, Map<String, Object?> extras) {
    // 入口未读跳转诊断日志默认关闭，避免刷屏。
    if (!ChatHistoryTrace.enabled) {
      return;
    }
    final buffer = StringBuffer('[FirstUnreadJump] event=$event');
    extras.forEach((key, value) {
      if (value == null) {
        return;
      }
      buffer.write(' $key=$value');
    });
    // ignore: avoid_print
    print(buffer.toString());
    ChatHistoryTrace.log(
      event,
      conversationID: _conversationId(),
      extras: extras,
    );
  }

  Future<bool> _jumpToFirstUnreadAroundWindow(int fallbackCount) async {
    final conversation = await _conversationWithFreshReadCursor();
    if (!mounted) {
      return false;
    }
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    final convId = _conversationId();
    final isGroup = conversation.type != 1;
    final last = conversation.lastMessage;
    final lastSeq = _newestMessageSeqForUnreadJump() ??
        int.tryParse(last?.seq?.trim() ?? '');
    final lockedSeq = globalModel.lockedFirstUnreadSeqFor(convId);
    final target = FirstUnreadJump.resolve(
      unreadCount: fallbackCount,
      isGroup: isGroup,
      groupReadSequence: conversation.groupReadSequence,
      c2cReadTimestamp: conversation.c2cReadTimestamp,
      lastMessageSeq: lastSeq,
      lastMessageTimestamp: last?.timestamp,
      lockedFirstUnreadSeq: lockedSeq > 0 ? lockedSeq : null,
    );
    _logFirstUnreadJump('entry_unread_jump_begin', <String, Object?>{
      'unread': fallbackCount,
      'isGroup': isGroup,
      'strategy': target?.strategy,
      'seq': target?.seq,
      'readTs': target?.timestampSec,
      'groupReadSeq': conversation.groupReadSequence,
      'c2cReadTs': conversation.c2cReadTimestamp,
      'lastSeq': lastSeq,
      'lockedSeq': lockedSeq,
    });
    if (target == null) {
      _logFirstUnreadJump('entry_unread_jump_no_target', <String, Object?>{
        'unread': fallbackCount,
        'isGroup': isGroup,
        'groupReadSeq': conversation.groupReadSequence,
        'lastSeq': lastSeq,
        'lockedSeq': lockedSeq,
      });
      return false;
    }

    // Fast path: already have first unread by count in memory (small windows).
    var targetGlobalIndex = _firstUnreadGlobalIndex(
      _currentVisibleMessageList(),
      fallbackCount,
    );
    if (targetGlobalIndex != null &&
        fallbackCount <= FirstUnreadJump.maxCountFallbackUnread) {
      return _finishFirstUnreadJump(targetGlobalIndex);
    }

    if ((target.strategy == 'group_read_seq' ||
            target.strategy == 'seq_from_unread' ||
            target.strategy == 'locked_seq') &&
        target.seq != null) {
      final readSeq = target.groupReadCursorSeq ?? 0;
      // Fast path ONLY when the loaded window already covers the unread
      // boundary. A latest-only window has every seq > readSeq, so
      // `_globalIndexForFirstUnreadAfterSeq` would falsely hit the oldest
      // row in the latest page (e.g. target 295381 → land on 297463).
      targetGlobalIndex = _globalIndexForSeq(target.seq!.toString());
      if (targetGlobalIndex == null) {
        final oldestLoaded = _oldestLoadedSeqInWindow();
        if (oldestLoaded != null && oldestLoaded <= target.seq!) {
          targetGlobalIndex = _globalIndexForFirstUnreadAfterSeq(readSeq);
        }
      }
      if (targetGlobalIndex == null) {
        final loaded =
            await widget.model.loadListForSpecificMessage(seq: target.seq!);
        if (!mounted) {
          return false;
        }
        if (!loaded) {
          _logFirstUnreadJump('entry_unread_jump_load_fail', <String, Object?>{
            'seq': target.seq,
            'strategy': target.strategy,
          });
          return false;
        }
        // 整窗替换后等两帧，再按 seq 重定位（勿沿用替换前的最新页 index）。
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) {
          return false;
        }
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) {
          return false;
        }
        targetGlobalIndex = _globalIndexForSeq(target.seq!.toString());
        final oldestAfterLoad = _oldestLoadedSeqInWindow();
        if (targetGlobalIndex == null &&
            oldestAfterLoad != null &&
            oldestAfterLoad <= target.seq!) {
          targetGlobalIndex = _globalIndexForFirstUnreadAfterSeq(readSeq);
        }
        // Closest is only OK within a small seq neighborhood of the target.
        final closest = _globalIndexForClosestSeq(
          target.seq!,
          preferAtOrAfter: true,
        );
        if (targetGlobalIndex == null && closest != null) {
          final closestSeq = int.tryParse(
                _currentVisibleMessageList()[closest]?.seq?.trim() ?? '',
              ) ??
              0;
          if (closestSeq > 0 && (closestSeq - target.seq!).abs() <= 20) {
            targetGlobalIndex = closest;
          }
        }
        _logFirstUnreadJump(
            'entry_unread_jump_after_replace', <String, Object?>{
          'seq': target.seq,
          'index': targetGlobalIndex,
          'listLen': _currentVisibleMessageList().length,
          'oldestSeq': oldestAfterLoad,
          'newestSeq': _newestLoadedSeqInWindow(),
        });
      }
      if (targetGlobalIndex == null) {
        _logFirstUnreadJump(
            'entry_unread_jump_index_missing', <String, Object?>{
          'seq': target.seq,
          'listLen': _currentVisibleMessageList().length,
          'oldestSeq': _oldestLoadedSeqInWindow(),
        });
        return false;
      }
      final landedSeq = int.tryParse(
            _currentVisibleMessageList()[targetGlobalIndex]?.seq?.trim() ?? '',
          ) ??
          0;
      if (landedSeq > 0 && (landedSeq - target.seq!).abs() > 50) {
        _logFirstUnreadJump(
            'entry_unread_jump_landed_too_far', <String, Object?>{
          'wantSeq': target.seq,
          'landedSeq': landedSeq,
          'index': targetGlobalIndex,
        });
        return false;
      }
      return _finishFirstUnreadJump(
        targetGlobalIndex,
        preferSeq: target.seq!.toString(),
      );
    }

    if (target.strategy == 'c2c_read_ts' && target.timestampSec != null) {
      final readTs = target.timestampSec!;
      targetGlobalIndex = _globalIndexForFirstUnreadAfterTimestamp(readTs);
      if (targetGlobalIndex != null) {
        return _finishFirstUnreadJump(targetGlobalIndex);
      }
      // 无按时间 around API：仅小未读允许 count_fallback 追翻。
      if (fallbackCount > FirstUnreadJump.maxCountFallbackUnread) {
        _logFirstUnreadJump(
            'entry_unread_jump_c2c_too_large', <String, Object?>{
          'unread': fallbackCount,
          'readTs': readTs,
        });
        return false;
      }
    }

    if (target.strategy == 'count_fallback' ||
        target.strategy == 'c2c_read_ts') {
      if (fallbackCount > FirstUnreadJump.maxCountFallbackUnread) {
        return false;
      }
      _firstUnreadAnchor = null;
      final anchor = await _ensureFirstUnreadAnchor(fallbackCount);
      if (anchor != null) {
        targetGlobalIndex = _globalIndexForUnreadAnchor(
          _currentVisibleMessageList(),
          anchor,
        );
      }
      targetGlobalIndex ??= _firstUnreadGlobalIndex(
        _currentVisibleMessageList(),
        fallbackCount,
      );
      if (targetGlobalIndex == null) {
        return false;
      }
      return _finishFirstUnreadJump(targetGlobalIndex);
    }

    return false;
  }

  int? _oldestLoadedSeqInWindow() {
    final list = _currentVisibleMessageList();
    int? oldest;
    for (final msg in list) {
      if (!_isUnreadAnchorMessage(msg)) {
        continue;
      }
      final seq = int.tryParse(msg?.seq?.trim() ?? '') ?? 0;
      if (seq <= 0) {
        continue;
      }
      if (oldest == null || seq < oldest) {
        oldest = seq;
      }
    }
    return oldest;
  }

  int? _newestLoadedSeqInWindow() {
    final list = _currentVisibleMessageList();
    int? newest;
    for (final msg in list) {
      if (!_isUnreadAnchorMessage(msg)) {
        continue;
      }
      final seq = int.tryParse(msg?.seq?.trim() ?? '') ?? 0;
      if (seq <= 0) {
        continue;
      }
      if (newest == null || seq > newest) {
        newest = seq;
      }
    }
    return newest;
  }

  int? _globalIndexForClosestSeq(int targetSeq,
      {bool preferAtOrAfter = false}) {
    final messageList = _currentVisibleMessageList();
    int? bestIndex;
    var bestDelta = 1 << 30;
    for (var i = 0; i < messageList.length; i++) {
      final message = messageList[i];
      if (!_isUnreadAnchorMessage(message)) {
        continue;
      }
      final seq = int.tryParse(message?.seq?.trim() ?? '') ?? 0;
      if (seq <= 0) {
        continue;
      }
      if (preferAtOrAfter && seq < targetSeq) {
        continue;
      }
      final delta = (seq - targetSeq).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestIndex = i;
      }
    }
    if (bestIndex != null) {
      return bestIndex;
    }
    // Fallback: any closest seq (including older).
    for (var i = 0; i < messageList.length; i++) {
      final message = messageList[i];
      if (!_isUnreadAnchorMessage(message)) {
        continue;
      }
      final seq = int.tryParse(message?.seq?.trim() ?? '') ?? 0;
      if (seq <= 0) {
        continue;
      }
      final delta = (seq - targetSeq).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  Future<bool> _finishFirstUnreadJump(
    int targetGlobalIndex, {
    String? preferSeq,
  }) async {
    final list = _currentVisibleMessageList();
    String? anchorMsgID;
    String? anchorSeq;
    if (targetGlobalIndex >= 0 && targetGlobalIndex < list.length) {
      final msg = list[targetGlobalIndex];
      anchorMsgID = msg?.msgID;
      anchorSeq = msg?.seq?.trim();
    }
    anchorSeq ??= preferSeq?.trim();

    // Prefer the same centering path as @me jump — more tolerant after
    // around-window list replacement than strict top-align stabilization.
    var didScroll = false;
    if (anchorSeq != null && anchorSeq.isNotEmpty) {
      didScroll = await _centerOnAtMeSeq(anchorSeq, targetGlobalIndex);
    } else {
      didScroll = await _jumpToFirstUnreadGlobalIndex(targetGlobalIndex);
    }
    // Soft success: index was resolvable after load; one scroll attempt is enough
    // even if pixel alignment is imperfect (layout settling / media height).
    if (!didScroll &&
        targetGlobalIndex >= 0 &&
        targetGlobalIndex < _currentVisibleMessageList().length) {
      try {
        await _geomScrollToIndex(
          -targetGlobalIndex,
          preferPosition: AutoScrollPosition.begin,
          reason: 'first_unread_soft_scroll',
        );
        await WidgetsBinding.instance.endOfFrame;
        didScroll = true;
      } catch (_) {}
    }
    if (didScroll) {
      _releaseSearchJumpMemoryWindowSuppress(
        anchorMsgID: anchorMsgID,
        anchorSeq: anchorSeq,
      );
      _logFirstUnreadJump('entry_unread_jump_success', <String, Object?>{
        'index': targetGlobalIndex,
        'msgID': anchorMsgID,
        'seq': anchorSeq,
        'haveMoreData': widget.model.haveMoreData,
        'haveMoreLatestData': widget.model.haveMoreLatestData,
      });
    } else {
      _logFirstUnreadJump('entry_unread_jump_scroll_fail', <String, Object?>{
        'index': targetGlobalIndex,
        'seq': anchorSeq,
        'listLen': _currentVisibleMessageList().length,
      });
    }
    return didScroll;
  }

  int? _globalIndexForFirstUnreadAfterSeq(int readSeq) {
    if (readSeq <= 0) {
      return null;
    }
    final messageList = _currentVisibleMessageList();
    int? bestIndex;
    int? bestSeq;
    for (var i = 0; i < messageList.length; i++) {
      final message = messageList[i];
      if (!_isUnreadAnchorMessage(message)) {
        continue;
      }
      final seq = int.tryParse(message?.seq?.trim() ?? '');
      if (seq == null || seq <= readSeq) {
        continue;
      }
      if (bestSeq == null || seq < bestSeq) {
        bestSeq = seq;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  int? _globalIndexForFirstUnreadAfterTimestamp(int readTs) {
    if (readTs <= 0) {
      return null;
    }
    final messageList = _currentVisibleMessageList();
    int? bestIndex;
    int? bestTs;
    for (var i = 0; i < messageList.length; i++) {
      final message = messageList[i];
      if (!_isUnreadAnchorMessage(message)) {
        continue;
      }
      final ts = message?.timestamp;
      if (ts == null || ts <= readTs) {
        continue;
      }
      if (bestTs == null || ts < bestTs) {
        bestTs = ts;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  void _rebuildListPartitionsIfNeeded({
    required List<V2TimMessage?> messageList,
    required int safeUnreadCount,
    required int unreadEndPoint,
    required int restoreVersion,
    required int messageListRevision,
    required String Function(V2TimMessage? message, int index)
        getMessageIdentifier,
  }) {
    final lastMsg = messageList.isNotEmpty ? messageList.last : null;
    final lastMsgKey =
        lastMsg == null ? null : getMessageIdentifier(lastMsg, 0);
    final headMsg = messageList.isNotEmpty ? messageList.first : null;
    final headMsgKey =
        headMsg == null ? null : getMessageIdentifier(headMsg, 0);
    final listStateKey = _listStateCacheKey(messageList);
    if (_cacheMessageListLen == messageList.length &&
        _cacheUnreadCount == safeUnreadCount &&
        _cacheUnreadEndPoint == unreadEndPoint &&
        _cacheLastMsgKey == lastMsgKey &&
        _cacheHeadMsgKey == headMsgKey &&
        _cacheListStateKey == listStateKey &&
        _cacheRestoreVersion == restoreVersion &&
        _cacheMessageListRevision == messageListRevision) {
      return;
    }
    final delta = messageList.length - _cacheMessageListLen;
    final canAppendReadTail = delta > 0 &&
        _cacheMessageListLen > 0 &&
        _cacheHeadMsgKey != null &&
        headMsgKey == _cacheHeadMsgKey &&
        _cacheUnreadCount == safeUnreadCount &&
        _cacheUnreadEndPoint == unreadEndPoint &&
        unreadEndPoint <= _cacheMessageListLen &&
        _cacheListStateKey == listStateKey &&
        _cacheRestoreVersion == restoreVersion;
    if (canAppendReadTail) {
      final appended =
          messageList.sublist(_cacheMessageListLen, messageList.length);
      final readStartInCache = _cachedReadList.length;
      _cachedReadList.addAll(appended);
      for (var i = 0; i < appended.length; i++) {
        final globalIndex = _cacheMessageListLen + i;
        final message = appended[i];
        final stableKey = getMessageIdentifier(message, globalIndex);
        _readIndexMap[stableKey] = readStartInCache + i;
        _globalIndexMap[stableKey] = globalIndex;
        if (message != null && message.elemType != 11) {
          final identity = _messageIdentity(message);
          if (identity.isNotEmpty) {
            _globalMessageIdentityIndexMap[identity] = globalIndex;
          }
        }
      }
      ChatJitterDiag.log(
        'partition_incremental_tail',
        extras: <String, Object?>{
          'delta': delta,
          'readLen': _cachedReadList.length,
          'rev': messageListRevision,
        },
      );
      _cacheRestoreVersion = restoreVersion;
      _cacheMessageListRevision = messageListRevision;
      _cacheMessageListLen = messageList.length;
      _cacheUnreadCount = safeUnreadCount;
      _cacheUnreadEndPoint = unreadEndPoint;
      _cacheLastMsgKey = lastMsgKey;
      _cacheHeadMsgKey = headMsgKey;
      _cacheListStateKey = listStateKey;
      return;
    }
    final changed = <String>[];
    if (_cacheMessageListLen != messageList.length) {
      changed.add('len:$_cacheMessageListLen→${messageList.length}');
    }
    if (_cacheUnreadCount != safeUnreadCount) {
      changed.add('unread:$_cacheUnreadCount→$safeUnreadCount');
    }
    if (_cacheLastMsgKey != lastMsgKey) {
      changed.add('lastMsg');
    }
    if (_cacheListStateKey != listStateKey) {
      changed.add('listState');
    }
    if (_cacheRestoreVersion != restoreVersion) {
      changed.add('restore:$_cacheRestoreVersion→$restoreVersion');
    }
    if (_cacheMessageListRevision != messageListRevision) {
      changed.add('rev:$_cacheMessageListRevision→$messageListRevision');
    }
    ChatJitterDiag.log(
      'partition_cache_miss',
      extras: <String, Object?>{
        'changed': changed.join(','),
        'rev': messageListRevision,
        'unread': safeUnreadCount,
        'len': messageList.length,
      },
    );
    _cacheRestoreVersion = restoreVersion;
    _cacheMessageListRevision = messageListRevision;
    _cacheMessageListLen = messageList.length;
    _cacheUnreadCount = safeUnreadCount;
    _cacheUnreadEndPoint = unreadEndPoint;
    _cacheLastMsgKey = lastMsgKey;
    _cacheHeadMsgKey = headMsgKey;
    _cacheListStateKey = listStateKey;
    _cachedUnreadList = safeUnreadCount == 0
        ? <V2TimMessage?>[]
        : messageList.sublist(0, unreadEndPoint).reversed.toList();
    _cachedReadList =
        messageList.sublist(unreadEndPoint, messageList.length).toList();
    _unreadIndexMap = {};
    for (var i = 0; i < _cachedUnreadList.length; i++) {
      _unreadIndexMap[getMessageIdentifier(_cachedUnreadList[i], 0)] = i;
    }
    _readIndexMap = {};
    for (var i = 0; i < _cachedReadList.length; i++) {
      _readIndexMap[getMessageIdentifier(_cachedReadList[i], 0)] = i;
    }
    _logRenderedReadOrder();
    _globalIndexMap = {};
    _globalMessageIdentityIndexMap = {};
    for (var i = 0; i < messageList.length; i++) {
      _globalIndexMap[getMessageIdentifier(messageList[i], i)] = i;
      final message = messageList[i];
      if (message != null && message.elemType != 11) {
        final identity = _messageIdentity(message);
        if (identity.isNotEmpty) {
          _globalMessageIdentityIndexMap[identity] = i;
        }
      }
    }
  }

  /// Logs the exact order the read partition will render, which is what the
  /// user actually sees. `_cachedReadList` is newest-first (index 0 is painted
  /// at the bottom in the reversed viewport). Compare this with the
  /// `[IM_SEND_ORDER]` logs: if this order is correct but the screen looks
  /// wrong, the problem is Flutter element recycling, not the data pipeline.
  void _logRenderedReadOrder() {
    if (!ChatJitterDiag.enabled) {
      return;
    }
    final list = _cachedReadList;
    if (list.isEmpty) {
      return;
    }
    final buffer = StringBuffer();
    final scanEnd = list.length > 8 ? 8 : list.length;
    for (var i = 0; i < scanEnd; i++) {
      final message = list[i];
      if (message == null) {
        buffer.write('#$i=null;');
        continue;
      }
      if (message.elemType == 11) {
        buffer.write('#$i=divider;');
        continue;
      }
      final tag = message.msgID?.trim().isNotEmpty == true
          ? message.msgID!.trim()
          : (message.id?.trim() ?? '');
      buffer.write('#$i seq=${message.seq ?? ''} ts=${message.timestamp ?? ''} '
          'st=${message.status ?? ''} key=${_stableMessageListKey(message, i)} '
          'tag=$tag;');
    }
    debugPrint(
      '[IM_RENDER_ORDER] conv=${_conversationId()} readLen=${list.length} '
      'bottomUp=$buffer',
    );
    final position = _singleScrollPositionOrNull();
    ChatJitterDiag.logListRebuild(
      reason: 'im_render_order',
      readLen: list.length,
      scrollPixels: position?.hasPixels == true ? position!.pixels : null,
      maxExtent: position?.hasContentDimensions == true
          ? position!.maxScrollExtent
          : null,
      spacer: _routeScroll.shortHistoryBottomSpacerHeight,
      caller: ChatJitterDiag.compactStack(),
    );
  }

  bool _isShortHistoryTopAlignmentBlocked(int safeUnreadCount) {
    return safeUnreadCount > 0 ||
        findingMsg != null ||
        findingAnchor != null ||
        widget.initFindingMsg != null ||
        widget.searchJumpAnchor != null;
  }

  bool _isKeyboardInsetActive(BuildContext context) {
    return ChatKeyboardLayoutScope.bottomInsetOf(context) > 0;
  }

  void _clearShortHistoryAlignmentLatch() {
    ChatGeomSettleTrace.noteReason(
      'short_history_latch_clear',
      extras: <String, Object?>{
        'prevSpacer':
            _routeScroll.shortHistoryBottomSpacerHeight.toStringAsFixed(1),
        'prevContentH':
            _routeScroll.shortHistoryContentHeight.toStringAsFixed(1),
      },
    );
    _routeScroll.clearShortHistoryAlignmentLatch();
  }

  /// 短历史吃 spacer「估高成功」后的溢出兜底：自消息实测仍超视口时退出顶部对齐并贴底。
  void _breakShortHistoryIfOutgoingOverflowsViewport() {
    if (!_routeScroll.shortHistoryAlignmentLatched &&
        _routeScroll.shortHistoryBottomSpacerHeight <= 0) {
      return;
    }
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    final messageList = globalModel.getMessageList(_conversationId()) ??
        const <V2TimMessage?>[];
    final viewport = _resolvedShortHistoryViewportForDecision(context);
    if (!_contentExceedsShortHistoryViewport(
      messageList: messageList,
      viewportHeight: viewport,
      context: context,
    )) {
      return;
    }
    ChatJitterDiag.logInboundFlow(
      action: 'short_history_outgoing_overflow_break',
      conv: _conversationId(),
      extras: <String, Object?>{
        'viewport': viewport.toStringAsFixed(1),
        'spacer':
            _routeScroll.shortHistoryBottomSpacerHeight.toStringAsFixed(1),
      },
    );
    _clearShortHistoryAlignmentLatch();
    _routeScroll.shortHistoryAlignmentSuppressedByLiveInsert = true;
    _scheduleForcePinScrollToBottom();
  }

  /// 新消息进入顶部对齐的短历史时，按新行估高收缩底部 spacer，
  /// 让消息原地接在最后一条下方、保持顶部锚定。返回 false 表示
  /// 内容已放不进视口（或状态不满足），应回落为贴底布局。
  /// 估高误差由下一帧的实测测量（_maybeScheduleShortHistoryTopAlignment）
  /// 自行校正。
  bool _absorbInsertedRowsIntoShortHistorySpacer(
    List<V2TimMessage> insertedMessages, {
    int insertedTipRows = 0,
  }) {
    if (!_routeScroll.shortHistoryAlignmentLatched &&
        _routeScroll.shortHistoryBottomSpacerHeight <= 0) {
      return false;
    }
    var insertedHeight = 0.0;
    for (final message in insertedMessages) {
      if (message.elemType == 11) {
        insertedHeight += _shortHistoryTimeDividerEstimatedRowHeight;
        continue;
      }
      final cachedHeight = ChatMessageHeightCache.instance.heightFor(message);
      if (cachedHeight != null && cachedHeight > 0) {
        insertedHeight += cachedHeight;
        continue;
      }
      insertedHeight += ChatMessageHeightCache.instance.estimateRowHeight(
            message,
          ) ??
          (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS
              ? _shortHistoryGroupTipsEstimatedRowHeight
              : _shortHistoryMessageEstimatedRowHeight);
    }
    if (insertedTipRows > 0) {
      insertedHeight +=
          insertedTipRows * _shortHistoryTimeDividerEstimatedRowHeight;
    }
    if (insertedHeight <= 0) {
      return true;
    }
    final next = _routeScroll.shortHistoryBottomSpacerHeight - insertedHeight;
    // 仅「装不下」才失败：spacer 吃到 0 仍算成功（刚好铺满），不要提前上推。
    if (next < 0) {
      return false;
    }
    _assignShortHistorySpacer(next <= 1 ? 0.0 : next,
        reason: 'spacer_absorb_insert');
    _routeScroll.shortHistoryAlignmentLatched = true;
    if (_routeScroll.shortHistoryContentHeight >= 0) {
      _assignShortHistoryContentHeight(
        _routeScroll.shortHistoryContentHeight + insertedHeight,
        reason: 'content_h_absorb_insert_add',
      );
    } else {
      _assignShortHistoryContentHeight(insertedHeight,
          reason: 'content_h_absorb_insert');
    }
    return true;
  }

  /// reveal 后暖开归档/云补导致的中间插入或缩窗：用 Δcontent 对冲 spacer，钉住 tip。
  _AsyncSpacerAbsorbResult _absorbAsyncHistoryListChangeIntoShortSpacer({
    required List<V2TimMessage?> oldList,
    required List<V2TimMessage?> newList,
  }) {
    if (!_routeScroll.shortHistoryAlignmentLatched &&
        _routeScroll.shortHistoryBottomSpacerHeight <= 0) {
      return _AsyncSpacerAbsorbResult.skipped;
    }
    final oldKeys = <String>{};
    for (var i = 0; i < oldList.length; i++) {
      final message = oldList[i];
      if (message == null) {
        continue;
      }
      oldKeys.add(_asyncHistoryIdentityKey(message, i));
    }
    final newKeys = <String>{};
    for (var i = 0; i < newList.length; i++) {
      final message = newList[i];
      if (message == null) {
        continue;
      }
      newKeys.add(_asyncHistoryIdentityKey(message, i));
    }
    var addedHeight = 0.0;
    for (var i = 0; i < newList.length; i++) {
      final message = newList[i];
      if (message == null) {
        continue;
      }
      final key = _asyncHistoryIdentityKey(message, i);
      if (oldKeys.contains(key)) {
        continue;
      }
      addedHeight += _estimateShortHistoryRowHeight(message);
    }
    var removedHeight = 0.0;
    for (var i = 0; i < oldList.length; i++) {
      final message = oldList[i];
      if (message == null) {
        continue;
      }
      final key = _asyncHistoryIdentityKey(message, i);
      if (newKeys.contains(key)) {
        continue;
      }
      removedHeight += _estimateShortHistoryRowHeight(message);
    }
    final deltaContent = addedHeight - removedHeight;
    if (deltaContent.abs() < 0.5) {
      return _AsyncSpacerAbsorbResult.skipped;
    }
    final prevSpacer = _routeScroll.shortHistoryBottomSpacerHeight;
    final nextSpacer = prevSpacer - deltaContent;
    if (nextSpacer < 0) {
      return _AsyncSpacerAbsorbResult.overflow;
    }
    final reason = deltaContent > 0
        ? 'short_spacer_absorb_async_grow'
        : 'short_spacer_absorb_async_shrink';
    _assignShortHistorySpacer(
      nextSpacer <= 1 ? 0.0 : nextSpacer,
      reason: reason,
    );
    _routeScroll.shortHistoryAlignmentLatched = true;
    if (_routeScroll.shortHistoryContentHeight >= 0) {
      _assignShortHistoryContentHeight(
        (_routeScroll.shortHistoryContentHeight + deltaContent)
            .clamp(0.0, double.infinity)
            .toDouble(),
        reason: '${reason}_content_h',
      );
    }
    ChatGeomSettleTrace.noteReason(
      reason,
      extras: <String, Object?>{
        'oldLen': oldList.length,
        'newLen': newList.length,
        'addedH': addedHeight.toStringAsFixed(1),
        'removedH': removedHeight.toStringAsFixed(1),
        'deltaContent': deltaContent.toStringAsFixed(1),
        'prevSpacer': prevSpacer.toStringAsFixed(1),
        'nextSpacer':
            _routeScroll.shortHistoryBottomSpacerHeight.toStringAsFixed(1),
      },
    );
    return _AsyncSpacerAbsorbResult.ok;
  }

  String _asyncHistoryIdentityKey(V2TimMessage message, int index) {
    final msgId = message.msgID?.trim() ?? '';
    if (msgId.isNotEmpty) {
      return 'msgid_$msgId';
    }
    return _stableMessageListKey(message, index);
  }

  double _estimateShortHistoryRowHeight(V2TimMessage message) {
    if (message.elemType == 11) {
      return _shortHistoryTimeDividerEstimatedRowHeight;
    }
    final cachedHeight = ChatMessageHeightCache.instance.heightFor(message);
    if (cachedHeight != null && cachedHeight > 0) {
      return cachedHeight;
    }
    return ChatMessageHeightCache.instance.estimateRowHeight(message) ??
        (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS
            ? _shortHistoryGroupTipsEstimatedRowHeight
            : _shortHistoryMessageEstimatedRowHeight);
  }

  void _updateShortHistoryBaselineViewport(double viewportHeight) {
    if (viewportHeight > 0 && !_isKeyboardInsetActive(context)) {
      _routeScroll.shortHistoryBaselineViewportHeight = viewportHeight;
    }
  }

  void _tryLatchShortHistoryAlignment({
    required List<V2TimMessage?> messageList,
    required int safeUnreadCount,
    required double viewportHeight,
    required BuildContext context,
  }) {
    if (!ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled) {
      if (_routeScroll.shortHistoryAlignmentLatched ||
          _routeScroll.shortHistoryBottomSpacerHeight > 0) {
        _clearShortHistoryAlignmentLatch();
      }
      return;
    }
    if (_isShortHistoryTopAlignmentBlocked(safeUnreadCount)) {
      _clearShortHistoryAlignmentLatch();
      return;
    }
    if (_contentExceedsShortHistoryViewport(
      messageList: messageList,
      viewportHeight: viewportHeight,
      context: context,
    )) {
      // 键盘动画中视口会瞬时变矮：清 latch 后再 re-prime 会造成 211↔379 大跳。
      if (_isKeyboardInsetActive(context) ||
          _routeScroll.shortHistoryAlignmentLatched) {
        return;
      }
      _clearShortHistoryAlignmentLatch();
      return;
    }
    if (_shouldAlignShortHistoryToTop(
      messageList: messageList,
      safeUnreadCount: safeUnreadCount,
      viewportHeight: viewportHeight,
      context: context,
    )) {
      _routeScroll.shortHistoryAlignmentLatched = true;
      _updateShortHistoryBaselineViewport(viewportHeight);
    } else if (!_routeScroll.shortHistoryAlignmentLatched) {
      _clearShortHistoryAlignmentLatch();
    }
  }

  bool _contentExceedsShortHistoryViewport({
    required List<V2TimMessage?> messageList,
    required double viewportHeight,
    required BuildContext context,
    double? measuredContentHeight,
  }) {
    if (viewportHeight <= 0) {
      return false;
    }
    final verticalPadding = _resolvedHistoryListVerticalPadding(context);
    var contentHeight = measuredContentHeight ?? -1.0;
    if (contentHeight < 0) {
      final tilesHeight = _visibleHistoryTilesHeight(
        expectedMessageCount: _shortHistoryTileCount(messageList),
      );
      if (tilesHeight >= 0) {
        contentHeight = tilesHeight;
      }
    }
    if (contentHeight < 0) {
      contentHeight = _resolvedShortHistoryContentHeight(messageList);
    }
    return contentHeight > 0 &&
        contentHeight + verticalPadding + _shortHistoryAlignmentHysteresis >=
            viewportHeight;
  }

  bool _shouldKeepShortHistoryTopAlignment({
    required List<V2TimMessage?> messageList,
    required int safeUnreadCount,
    required double viewportHeight,
    required BuildContext context,
  }) {
    if (!ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled) {
      return false;
    }
    if (_isShortHistoryTopAlignmentBlocked(safeUnreadCount)) {
      return false;
    }
    if (_routeScroll.shortHistoryAlignmentSuppressedByLiveInsert) {
      return false;
    }
    // 已 latch：键盘开关过程中始终保持顶部对齐（只重算 spacer，不释放）。
    if (_routeScroll.shortHistoryAlignmentLatched) {
      return true;
    }
    // 键盘弹出后用当前（变矮的）视口判定/算 spacer；
    // 无键盘时可用 baseline，避免输入栏微抖导致反复 latch。
    final resolvedViewport = _isKeyboardInsetActive(context)
        ? viewportHeight
        : (_routeScroll.shortHistoryBaselineViewportHeight > 0
            ? _routeScroll.shortHistoryBaselineViewportHeight
            : viewportHeight);
    if (_contentExceedsShortHistoryViewport(
      messageList: messageList,
      viewportHeight: resolvedViewport,
      context: context,
    )) {
      return false;
    }
    return _shouldAlignShortHistoryToTop(
      messageList: messageList,
      safeUnreadCount: safeUnreadCount,
      viewportHeight: resolvedViewport,
      context: context,
    );
  }

  double _resolvedShortHistoryViewportForDecision(BuildContext context) {
    final position = _singleScrollPositionOrNull();
    if (position != null &&
        position.hasContentDimensions &&
        position.viewportDimension > 0) {
      return position.viewportDimension;
    }
    if (_routeScroll.shortHistoryBaselineViewportHeight > 0) {
      return _routeScroll.shortHistoryBaselineViewportHeight;
    }
    return _shortHistoryAvailableViewportHeight(context);
  }

  void _releaseShortHistoryAlignmentAndPinBottom() {
    final wasShort = _routeScroll.shortHistoryAlignmentLatched ||
        _routeScroll.shortHistoryBottomSpacerHeight > 0 ||
        _routeScroll.shortHistoryContentHeight >= 0;
    _clearShortHistoryAlignmentLatch();
    if (wasShort && mounted && !_isHistoryScrollProtected) {
      // 进页 settle 内只清 latch，禁止强制 pin，避免估高校正触发贴底跳动。
      if (_isInitialRouteSettleWindow) {
        return;
      }
      _schedulePinScrollToBottom();
    }
  }

  double _shortHistoryAvailableViewportHeight(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context).height;
    final viewPadding = MediaQuery.paddingOf(context);
    // 聊天区域约为全屏去掉顶栏、输入栏与安全区后的高度。
    return (viewport - viewPadding.top - viewPadding.bottom) * 0.62;
  }

  bool _shouldAlignShortHistoryToTop({
    required List<V2TimMessage?> messageList,
    required int safeUnreadCount,
    required double viewportHeight,
    required BuildContext context,
  }) {
    if (!ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled) {
      return false;
    }
    if (_routeScroll.shortHistoryAlignmentSuppressedByLiveInsert) {
      return false;
    }
    if (_isShortHistoryTopAlignmentBlocked(safeUnreadCount)) {
      return false;
    }
    if (_shortHistoryRealMessageCount(messageList) == 0) {
      return false;
    }
    if (viewportHeight <= 0) {
      return false;
    }
    final verticalPadding = _resolvedHistoryListVerticalPadding(context);
    final contentHeight = _resolvedShortHistoryContentHeight(messageList);
    if (contentHeight > 0) {
      return contentHeight +
              verticalPadding +
              _shortHistoryAlignmentHysteresis <
          viewportHeight;
    }
    final estimate = _estimateShortHistoryContentHeight(messageList);
    return estimate > 0 &&
        estimate + verticalPadding + _shortHistoryAlignmentHysteresis <
            viewportHeight;
  }

  bool _mayUseShortHistoryTopAlignment() {
    if (!ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled) {
      return false;
    }
    if (findingMsg != null ||
        findingAnchor != null ||
        widget.initFindingMsg != null ||
        widget.searchJumpAnchor != null) {
      return false;
    }
    if (_shortHistoryRealMessageCount(widget.messageList) == 0) {
      return false;
    }
    if (!mounted) {
      return _estimateShortHistoryContentHeight(widget.messageList) > 0;
    }
    if (_routeScroll.shortHistoryAlignmentSuppressedByLiveInsert) {
      return false;
    }
    if (_routeScroll.shortHistoryAlignmentLatched ||
        _routeScroll.shortHistoryBottomSpacerHeight > 0) {
      return true;
    }
    final available = _resolvedShortHistoryViewportForDecision(context);
    return _shouldAlignShortHistoryToTop(
      messageList: widget.messageList,
      safeUnreadCount: 0,
      viewportHeight: available,
      context: context,
    );
  }

  double _resolvedHistoryListVerticalPadding(BuildContext context) {
    final padding = widget.mainHistoryListConfig?.padding;
    if (padding == null) {
      return 0;
    }
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    return padding.resolve(direction).vertical;
  }

  double _visibleHistoryTilesHeight({required int expectedMessageCount}) {
    var total = 0.0;
    var measured = 0;
    for (final tag in _autoScrollController.tagMap.values) {
      final tagContext = tag.context;
      final renderObject = tagContext?.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        continue;
      }
      total += renderObject.size.height;
      measured++;
    }
    // 短列表会完整构建所有消息行；只有全部行都拿到布局尺寸时才采用
    // 实测总高，避免可见 tag 尚未齐全时用部分高度生成过大的 spacer。
    return measured < expectedMessageCount ? -1 : total;
  }

  int _shortHistoryRealMessageCount(List<V2TimMessage?> messageList) {
    return messageList
        .where((message) => message != null && message.elemType != 11)
        .length;
  }

  /// 短历史测高期望的 tile 数（含时间分割线），与 AutoScrollTag 一一对应。
  int _shortHistoryTileCount(List<V2TimMessage?> messageList) {
    return messageList.where((message) => message != null).length;
  }

  List<V2TimMessage> _nonNullHistoryMessages(List<V2TimMessage?> messageList) {
    return messageList.whereType<V2TimMessage>().toList(growable: false);
  }

  String _historyIdentitySignatureForList(List<V2TimMessage?> messageList) {
    return TUIChatGlobalModel.historyIdentitySignature(
      _nonNullHistoryMessages(messageList),
    );
  }

  double _estimateShortHistoryContentHeight(List<V2TimMessage?> messageList) {
    final screenWidth = mounted
        ? MediaQuery.sizeOf(context).width
        : ChatMessageHeightCache.defaultScreenWidth;
    var total = 0.0;
    var counted = 0;
    for (final message in messageList) {
      if (message == null) {
        continue;
      }
      // 时间分割线必须计入：空会话首条会「先气泡、后闪时间」，contentH 偏小再回弹。
      if (message.elemType == 11) {
        counted++;
        total += _shortHistoryTimeDividerEstimatedRowHeight;
        continue;
      }
      counted++;
      final cachedHeight = ChatMessageHeightCache.instance.heightFor(message);
      if (cachedHeight != null && cachedHeight > 0) {
        total += cachedHeight;
        continue;
      }
      // 缓存未命中时用类型感知估高（文本 TextPainter / 图视频占位），避免一律 56。
      final estimated = ChatMessageHeightCache.instance.estimateRowHeight(
            message,
            screenWidth: screenWidth,
          ) ??
          (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS
              ? _shortHistoryGroupTipsEstimatedRowHeight
              : _shortHistoryMessageEstimatedRowHeight);
      total += estimated;
    }
    return counted == 0 ? -1 : total;
  }

  double _resolvedShortHistoryContentHeight(List<V2TimMessage?> messageList) {
    final estimate = _estimateShortHistoryContentHeight(messageList);
    if (_routeScroll.shortHistoryContentHeight >= 0) {
      // 实测落地后 display 必须以 stored 为 SSOT，禁止 estimate 软覆盖
      //（日志里 spacer 201↔127 即 estimate=549 盖住 measured=475）。
      if (_routeScroll.shortHistoryContentHeightMeasured) {
        if (estimate > _routeScroll.shortHistoryContentHeight + 8) {
          ChatGeomSettleTrace.noteReason(
            'estimate_resolve_blocked_after_measure',
            extras: <String, Object?>{
              'estimate': estimate.toStringAsFixed(1),
              'contentH':
                  _routeScroll.shortHistoryContentHeight.toStringAsFixed(1),
            },
          );
        }
        return _routeScroll.shortHistoryContentHeight;
      }
      // 仅估高阶段：首帧若只量到气泡、时间分割线尚未入 tagMap，stored 会偏小；
      // 用含 divider 的估高兜住，避免 spacer 先过大再回弹。
      if (estimate > _routeScroll.shortHistoryContentHeight + 8) {
        return estimate;
      }
      return _routeScroll.shortHistoryContentHeight;
    }
    return estimate;
  }

  void _setShortHistoryContentHeight(double nextHeight) {
    final normalized = nextHeight < 0 ? -1.0 : nextHeight;
    if ((_routeScroll.shortHistoryContentHeight - normalized).abs() <= 0.5) {
      return;
    }
    final prev = _routeScroll.shortHistoryContentHeight;
    setState(() {
      _assignShortHistoryContentHeight(normalized, reason: 'content_h_set');
    });
    ChatJitterDiag.logLayoutPulse(
      reason: 'short_history_content_h',
      contentH: normalized,
      spacer: _routeScroll.shortHistoryBottomSpacerHeight,
      latched: _routeScroll.shortHistoryAlignmentLatched,
    );
    ChatJitterDiag.log(
      'content_h_change',
      extras: <String, Object?>{
        'prev': prev.toStringAsFixed(1),
        'next': normalized.toStringAsFixed(1),
        'delta': (normalized - prev).toStringAsFixed(1),
      },
    );
  }

  void _setShortHistoryBottomSpacer(double nextHeight) {
    final normalized = nextHeight <= 1 ? 0.0 : nextHeight;
    if ((_routeScroll.shortHistoryBottomSpacerHeight - normalized).abs() <= 1) {
      return;
    }
    final prev = _routeScroll.shortHistoryBottomSpacerHeight;
    _assignShortHistorySpacer(normalized, reason: 'spacer_set');
    final position = _singleScrollPositionOrNull();
    ChatJitterDiag.logLayoutPulse(
      reason: 'short_history_spacer',
      spacer: normalized,
      contentH: _routeScroll.shortHistoryContentHeight,
      scrollPixels: position?.hasPixels == true ? position!.pixels : null,
      maxExtent: position?.hasContentDimensions == true
          ? position!.maxScrollExtent
          : null,
      latched: _routeScroll.shortHistoryAlignmentLatched,
    );
    ChatJitterDiag.log(
      'spacer_change',
      extras: <String, Object?>{
        'prev': prev.toStringAsFixed(1),
        'next': normalized.toStringAsFixed(1),
        'delta': (normalized - prev).toStringAsFixed(1),
      },
    );
  }

  double _shortHistorySpacerForViewport(
    BuildContext context,
    double viewportHeight, {
    required List<V2TimMessage?> messageList,
    required int safeUnreadCount,
  }) {
    if (!_shouldKeepShortHistoryTopAlignment(
      messageList: messageList,
      safeUnreadCount: safeUnreadCount,
      viewportHeight: viewportHeight,
      context: context,
    )) {
      return 0;
    }
    final contentHeight = _resolvedShortHistoryContentHeight(messageList);
    if (contentHeight < 0) {
      return 0;
    }
    final verticalPadding = _resolvedHistoryListVerticalPadding(context);
    var target = viewportHeight - contentHeight - verticalPadding;
    if (target < 0) {
      target = 0;
    }
    return target;
  }

  double _displayShortHistoryBottomSpacer(
    BuildContext context, {
    required List<V2TimMessage?> messageList,
    required int safeUnreadCount,
    required double viewportHeight,
  }) {
    if (!ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled) {
      if (_routeScroll.shortHistoryAlignmentLatched ||
          _routeScroll.shortHistoryBottomSpacerHeight > 0) {
        _clearShortHistoryAlignmentLatch();
      }
      return 0;
    }
    final keyboardActive = _isKeyboardInsetActive(context);
    final keyboardJustDismissed =
        _routeScroll.shortHistoryKeyboardJustDismissed;

    _primeShortHistorySpacerFromEstimate(
      context: context,
      messageList: messageList,
      safeUnreadCount: safeUnreadCount,
      viewportHeight: viewportHeight,
    );
    if (viewportHeight > 0) {
      _tryLatchShortHistoryAlignment(
        messageList: messageList,
        safeUnreadCount: safeUnreadCount,
        viewportHeight: viewportHeight,
        context: context,
      );
    }
    // B2：latch 后 estimate 不得覆盖已有 contentH（尤其实测后）。
    final estimate = _estimateShortHistoryContentHeight(messageList);
    if (_routeScroll.shortHistoryAlignmentLatched &&
        estimate > 0 &&
        _routeScroll.shortHistoryContentHeight >= 0 &&
        estimate > _routeScroll.shortHistoryContentHeight + 8) {
      ChatGeomSettleTrace.noteReason(
        'estimate_blocked_after_measure',
        extras: <String, Object?>{
          'estimate': estimate.toStringAsFixed(1),
          'contentH': _routeScroll.shortHistoryContentHeight.toStringAsFixed(1),
          'measured': _routeScroll.shortHistoryContentHeightMeasured,
        },
      );
    }

    // 已 latch：始终用「视口 − 内容」算 spacer（含键盘动画帧）。
    // 不再用 delta 累积——收起后 delta/拦截一旦不同步，spacer 会停在键盘矮值，
    // 表现为顶部大空白、消息沉在中下部，且要等下一轮才慢慢纠正。
    if (_routeScroll.shortHistoryAlignmentLatched && viewportHeight > 0) {
      final contentHeight = _resolvedShortHistoryContentHeight(messageList);
      if (contentHeight >= 0) {
        final verticalPadding = _resolvedHistoryListVerticalPadding(context);
        var target = viewportHeight - contentHeight - verticalPadding;
        if (target < 0) {
          target = 0;
        }
        final normalized = target <= 1 ? 0.0 : target;
        final prevVp = _routeScroll.shortHistoryLastTrackedViewportHeight;
        final viewportGrew = prevVp > 0 && viewportHeight > prevVp + 1;
        final viewportShrunk = prevVp > 0 && viewportHeight + 1 < prevVp;
        // 估高误差抬高 spacer（视口没变）仍拦截；视口变大/键盘收起/变矮必须跟。
        final wouldGrow =
            normalized > _routeScroll.shortHistoryBottomSpacerHeight + 1;
        if (wouldGrow &&
            !keyboardActive &&
            !keyboardJustDismissed &&
            !viewportGrew &&
            !viewportShrunk &&
            _routeScroll.shortHistoryBottomSpacerHeight > 1) {
          if (viewportHeight > 0) {
            _routeScroll.shortHistoryLastTrackedViewportHeight = viewportHeight;
          }
          return _routeScroll.shortHistoryBottomSpacerHeight;
        }
        if ((normalized - _routeScroll.shortHistoryBottomSpacerHeight).abs() >
            1) {
          _assignShortHistorySpacer(normalized, reason: 'spacer_set');
          if (keyboardJustDismissed || viewportGrew) {
            ChatJitterDiag.logLayoutPulse(
              reason: keyboardJustDismissed
                  ? 'short_history_spacer_keyboard_dismiss'
                  : 'short_history_spacer_viewport_grow',
              spacer: normalized,
              contentH: contentHeight,
              latched: true,
            );
          }
        }
        _routeScroll.shortHistoryLastTrackedViewportHeight = viewportHeight;
        return _routeScroll.shortHistoryBottomSpacerHeight;
      }
    }

    final spacer = _shortHistorySpacerForViewport(
      context,
      viewportHeight,
      messageList: messageList,
      safeUnreadCount: safeUnreadCount,
    );
    if ((spacer - _routeScroll.shortHistoryBottomSpacerHeight).abs() > 1) {
      _assignShortHistorySpacer(spacer, reason: 'spacer_display_sync');
    }
    if (viewportHeight > 0) {
      _routeScroll.shortHistoryLastTrackedViewportHeight = viewportHeight;
    }
    if (_routeScroll.shortHistoryAlignmentLatched ||
        _routeScroll.shortHistoryBottomSpacerHeight > 1) {
      return _routeScroll.shortHistoryBottomSpacerHeight;
    }
    return spacer;
  }

  /// 首帧用估高预填 contentH/spacer，避免暖窗短列表先贴底、测高后再跳到顶部。
  void _primeShortHistorySpacerFromEstimate({
    required BuildContext context,
    required List<V2TimMessage?> messageList,
    required int safeUnreadCount,
    required double viewportHeight,
  }) {
    if (!ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled) {
      return;
    }
    if (viewportHeight <= 0 ||
        _isShortHistoryTopAlignmentBlocked(safeUnreadCount) ||
        _routeScroll.shortHistoryAlignmentSuppressedByLiveInsert) {
      return;
    }
    final signature = _historyIdentitySignatureForList(messageList);
    final lastMeasured =
        ChatMessageHeightCache.instance.measuredContentHeightFor(
      conversationID: _conversationId(),
      identitySignature: signature,
    );
    final estimate = lastMeasured != null && lastMeasured > 0
        ? lastMeasured
        : _estimateShortHistoryContentHeight(messageList);
    if (lastMeasured != null && lastMeasured > 0) {
      ChatGeomSettleTrace.noteReason(
        'content_h_prime_last_measured',
        extras: <String, Object?>{
          'contentH': lastMeasured.toStringAsFixed(1),
        },
      );
    }
    // B2：仅 contentH 未就绪且未实测时允许 estimate 写入；禁止抬高覆盖。
    if (estimate > 0 &&
        _routeScroll.shortHistoryContentHeight < 0 &&
        !_routeScroll.shortHistoryContentHeightMeasured) {
      _assignShortHistoryContentHeight(
        estimate,
        reason: lastMeasured != null && lastMeasured > 0
            ? 'content_h_prime_last_measured'
            : 'content_h_prime_estimate',
      );
    }
    if (!_shouldAlignShortHistoryToTop(
      messageList: messageList,
      safeUnreadCount: safeUnreadCount,
      viewportHeight: viewportHeight,
      context: context,
    )) {
      return;
    }
    final target = _shortHistorySpacerForViewport(
      context,
      viewportHeight,
      messageList: messageList,
      safeUnreadCount: safeUnreadCount,
    );
    // 已 latch：键盘收起后用公式恢复 spacer，禁止再走「从 0 re-prime」
    //（日志里 spacer_prime 211→379 就是这条路径抖起来的）。
    if (target > 1 &&
        _routeScroll.shortHistoryBottomSpacerHeight <= 1 &&
        _routeScroll.shortHistoryAlignmentLatched) {
      if (_blockShortSpacerReprimeAfterReveal) {
        ChatGeomSettleTrace.noteReason(
          'short_spacer_reprime_blocked_after_reveal',
          extras: <String, Object?>{
            'cause': 'spacer_prime_relatch',
            'target': target.toStringAsFixed(1),
          },
        );
        return;
      }
      _assignShortHistorySpacer(target, reason: 'spacer_prime_relatch');
      _routeScroll.shortHistoryLastTrackedViewportHeight = viewportHeight;
      return;
    }
    if (target > 1 && _routeScroll.shortHistoryBottomSpacerHeight <= 1) {
      if (_blockShortSpacerReprimeAfterReveal) {
        ChatGeomSettleTrace.noteReason(
          'short_spacer_reprime_blocked_after_reveal',
          extras: <String, Object?>{
            'cause': 'spacer_prime',
            'target': target.toStringAsFixed(1),
          },
        );
        return;
      }
      _assignShortHistorySpacer(target, reason: 'spacer_prime');
      _routeScroll.shortHistoryAlignmentLatched = true;
      _updateShortHistoryBaselineViewport(viewportHeight);
      _routeScroll.shortHistoryLastTrackedViewportHeight = viewportHeight;
      ChatJitterDiag.logLayoutPulse(
        reason: 'short_history_spacer_prime',
        spacer: target,
        contentH: _routeScroll.shortHistoryContentHeight,
        latched: true,
      );
    }
  }

  void _persistShortHistoryMeasuredContentHeight(
    List<V2TimMessage?> messageList,
    double contentHeight,
  ) {
    if (contentHeight <= 0) {
      return;
    }
    ChatMessageHeightCache.instance.rememberMeasuredContentHeight(
      conversationID: _conversationId(),
      identitySignature: _historyIdentitySignatureForList(messageList),
      contentHeight: contentHeight,
    );
  }

  /// Apply measured spacer; when Δ large and scroll room exists, compensate
  /// pixels so content does not visibly jump. At maxExtent≈0 compensation is
  /// a no-op — warm/cold reveal deferral + lastMeasured prime cover that case.
  void _applyShortHistorySpacerMeasureTarget({
    required double target,
    required double viewportHeight,
  }) {
    final normalized = target <= 1 ? 0.0 : target;
    final prev = _routeScroll.shortHistoryBottomSpacerHeight;
    final delta = normalized - prev;
    final absDelta = delta.abs();
    final globalModel = _chatGlobalModel;
    final userScrolling = globalModel?.isChatListUserScrolling == true ||
        _pageUi.userScrolling.value;
    final position = _singleScrollPositionOrNull();
    final canLockAnchor = !userScrolling &&
        !_isHistoryScrollProtected &&
        absDelta > _shortHistorySpacerRebuildTolerancePx &&
        position != null &&
        position.hasPixels &&
        position.hasContentDimensions &&
        position.maxScrollExtent > 1;

    _assignShortHistorySpacer(normalized, reason: 'spacer_measure_target');
    _routeScroll.shortHistoryLastTrackedViewportHeight = viewportHeight;

    if (!canLockAnchor || position == null) {
      return;
    }
    // reverse 列表底 spacer 变高且贴底时消息上移；有滚动余量时把 pixels 往同向推回。
    final nextPixels = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((nextPixels - position.pixels).abs() > 0.5) {
      _geomJumpTo(nextPixels, reason: 'spacer_measure_lock_anchor');
    }
  }

  void _scheduleShortViewportHistoryFill(_PreviousLoadAnchor? anchor) {
    // 缓存暖开时也可能只恢复到几条消息。只要模型明确还有历史且列表仍
    // 不可滚动，就继续静默补页；否则用户无法通过滚动触发上一页。
    if (_routeScroll.shortViewportHistoryFillScheduled ||
        anchor == null ||
        !widget.model.haveMoreData ||
        _paginationUi.isLoadingPrevious ||
        _paginationUi.loadPreviousTask != null ||
        _isHistoryScrollProtected ||
        _isSearchJumpStabilizing) {
      return;
    }
    _routeScroll.shortViewportHistoryFillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeScroll.shortViewportHistoryFillScheduled = false;
      if (!mounted ||
          !widget.model.haveMoreData ||
          _paginationUi.isLoadingPrevious ||
          _paginationUi.loadPreviousTask != null ||
          _isHistoryScrollProtected ||
          _isSearchJumpStabilizing) {
        return;
      }
      final position = _singleScrollPositionOrNull();
      if (position == null ||
          !position.hasContentDimensions ||
          position.maxScrollExtent > 1) {
        return;
      }
      // 不可滚动时没有 ScrollUpdate，主动补一页直到填满 viewport 或模型
      // 明确返回无更多。该入口不参与 iOS 顶部回弹判定，避免原来的死循环。
      // 首屏自动补拉静默：不显示顶部转圈。页面已 reveal 或缓存暖开时也
      // 必须允许该专用入口补页，直到列表可滚动或模型返回无更多。
      _scheduleLoadPrevious(
        anchor,
        silent: true,
        allowAfterRevealForViewportFill: true,
        bypassTopReachConsumed: true,
      );
    });
  }

  void _scheduleShortHistoryTopAlignment({
    required BuildContext context,
    required List<V2TimMessage?> messageList,
    required int safeUnreadCount,
  }) {
    if (_shouldCompensateScrollForPagination()) {
      return;
    }
    if (_paginationUi.isLoadingPrevious || _isHistoryScrollProtected) {
      return;
    }
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    // 暖窗已出屏时允许首帧估高 latch；仅冷启动空壳仍等 bootstrap 结束。
    if (_isInitialHistoryBootstrapping(globalModel) &&
        !_routeScroll.openedWithCachedHistory) {
      return;
    }
    final scrollPosition = _singleScrollPositionOrNull();
    final fallbackViewport = _isKeyboardInsetActive(context) &&
            scrollPosition != null &&
            scrollPosition.hasContentDimensions &&
            scrollPosition.viewportDimension > 0
        ? scrollPosition.viewportDimension
        : _shortHistoryAvailableViewportHeight(context);
    if (!_shouldKeepShortHistoryTopAlignment(
      messageList: messageList,
      safeUnreadCount: safeUnreadCount,
      viewportHeight: fallbackViewport,
      context: context,
    )) {
      if (_routeScroll.shortHistoryBottomSpacerHeight > 0 ||
          _routeScroll.shortHistoryContentHeight >= 0 ||
          _routeScroll.shortHistoryAlignmentLatched) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isHistoryScrollProtected) {
            _releaseShortHistoryAlignmentAndPinBottom();
            setState(() {});
          }
        });
      }
      return;
    }
    if (_routeScroll.shortHistoryAlignmentMeasureScheduled) {
      return;
    }
    _routeScroll.shortHistoryAlignmentMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeScroll.shortHistoryAlignmentMeasureScheduled = false;
      if (!mounted) {
        return;
      }
      final keyboardActive = _isKeyboardInsetActive(context);
      final contentHeight = _visibleHistoryTilesHeight(
        expectedMessageCount: _shortHistoryTileCount(messageList),
      );
      if (contentHeight < 0) {
        return;
      }
      final position = _singleScrollPositionOrNull();
      if (position != null && position.hasContentDimensions) {
        final viewportHeight = position.viewportDimension;
        _tryLatchShortHistoryAlignment(
          messageList: messageList,
          safeUnreadCount: safeUnreadCount,
          viewportHeight: viewportHeight,
          context: context,
        );
        if (!_shouldKeepShortHistoryTopAlignment(
          messageList: messageList,
          safeUnreadCount: safeUnreadCount,
          viewportHeight: viewportHeight,
          context: context,
        )) {
          if (_routeScroll.shortHistoryBottomSpacerHeight > 0 ||
              _routeScroll.shortHistoryContentHeight >= 0 ||
              _routeScroll.shortHistoryAlignmentLatched) {
            if (!_isHistoryScrollProtected) {
              setState(() {
                _releaseShortHistoryAlignmentAndPinBottom();
              });
            }
          }
          return;
        }
        // 键盘动画中只更新 contentH，spacer 由 display 路径按视口 delta 跟。
        if (!keyboardActive) {
          final verticalPadding = _resolvedHistoryListVerticalPadding(context);
          var target = viewportHeight - contentHeight - verticalPadding;
          if (target < 0) {
            target = 0;
          }
          _applyShortHistorySpacerMeasureTarget(
            target: target,
            viewportHeight: viewportHeight,
          );
        }
      }
      final estimate = _estimateShortHistoryContentHeight(messageList);
      if (_routeScroll.shortHistoryContentHeight < 0 &&
          estimate > 0 &&
          (contentHeight - estimate).abs() <= 24) {
        _assignShortHistoryContentHeight(contentHeight,
            reason: 'content_h_measure');
        _persistShortHistoryMeasuredContentHeight(messageList, contentHeight);
        return;
      }
      if (keyboardActive) {
        // 键盘态只升不降 contentH，避免漏测时间线时把估高压小再抖。
        if (contentHeight > _routeScroll.shortHistoryContentHeight + 0.5) {
          _assignShortHistoryContentHeight(contentHeight,
              reason: 'content_h_measure');
          _persistShortHistoryMeasuredContentHeight(messageList, contentHeight);
        }
        return;
      }
      // 实测与当前值差异很小（首帧估算基本命中）时静默记录，
      // 不再触发整帧重建；spacer 的毫厘修正会让首屏列表可见地跳动。
      final delta = _routeScroll.shortHistoryContentHeight < 0
          ? double.infinity
          : (_routeScroll.shortHistoryContentHeight - contentHeight).abs();
      if (delta <= _shortHistorySpacerRebuildTolerancePx) {
        _assignShortHistoryContentHeight(contentHeight,
            reason: 'content_h_measure');
        _persistShortHistoryMeasuredContentHeight(messageList, contentHeight);
        // 静默校正 spacer（不 setState）：顶部锚定不变，只微调底部留白。
        if (position != null &&
            position.hasContentDimensions &&
            _routeScroll.shortHistoryAlignmentLatched) {
          final viewportHeight = position.viewportDimension;
          final verticalPadding = _resolvedHistoryListVerticalPadding(context);
          var target = viewportHeight - contentHeight - verticalPadding;
          if (target < 0) {
            target = 0;
          }
          _applyShortHistorySpacerMeasureTarget(
            target: target,
            viewportHeight: viewportHeight,
          );
        }
        return;
      }
      // 进页 settle 窗口：只静默更新 contentH / spacer，不 setState、不 pin。
      if (_isInitialRouteSettleWindow) {
        _assignShortHistoryContentHeight(contentHeight,
            reason: 'content_h_measure');
        _persistShortHistoryMeasuredContentHeight(messageList, contentHeight);
        if (position != null && position.hasContentDimensions) {
          final viewportHeight = position.viewportDimension;
          final verticalPadding = _resolvedHistoryListVerticalPadding(context);
          var target = viewportHeight - contentHeight - verticalPadding;
          if (target < 0) {
            target = 0;
          }
          _applyShortHistorySpacerMeasureTarget(
            target: target,
            viewportHeight: viewportHeight,
          );
        }
        return;
      }
      _setShortHistoryContentHeight(contentHeight);
      _persistShortHistoryMeasuredContentHeight(messageList, contentHeight);
      if (mounted) {
        setState(() {});
      }
    });
  }

  Widget _wrapListMessageItem(V2TimMessage? message, Widget child) {
    final skipRepaint = message != null &&
        (widget.mainHistoryListConfig?.skipRepaintBoundaryForMessage
                ?.call(message) ??
            false);
    if (skipRepaint) {
      return ClipRect(
        clipBehavior: Clip.hardEdge,
        child: ColoredBox(
          color: Colors.transparent,
          child: child,
        ),
      );
    }
    final content = RepaintBoundary(child: child);
    if (!_isHeavyListMessage(message)) {
      return content;
    }
    return KeepAliveWrapper(keepAlive: true, child: content);
  }

  Widget _buildScrollMessageTile(
    V2TimMessage? messageItem,
    int index, {
    int? globalIndex,
  }) {
    // Group only: enqueue near-visible senders for capped/TTL getUsersInfo.
    // Cost ∝ built rows, never ∝ total group members.
    if (messageItem != null && messageItem.isSelf != true) {
      final groupId = messageItem.groupID?.trim() ??
          widget.conversation.groupID?.trim() ??
          '';
      if (groupId.isNotEmpty) {
        VisibleSenderProfileRefresh.noteSender(
          messageItem.sender ?? messageItem.userID,
          selfUserId: TIMUIKitCore.getInstance().loginUserInfo?.userID,
        );
      }
    }
    final resolvedGlobalIndex = globalIndex ??
        _globalIndexMap[_stableMessageListKey(messageItem, index)] ??
        index;
    Widget tile = AutoScrollTag(
      controller: _autoScrollController,
      index: -resolvedGlobalIndex,
      key: ValueKey(_stableMessageListKey(messageItem, index)),
      // 搜索/引用/转发消息定位只负责滚动到目标，不再让 AutoScrollTag
      // 自动闪烁边框/遮罩。转发消息卡片自身带边框时，高亮闪烁会被误认为
      // 定位抖动或消息状态异常。
      highlightColor: Colors.transparent,
      child: _wrapListMessageItem(
          messageItem, _getMessageItemBuilder(messageItem)),
    );
    if (resolvedGlobalIndex == 0 && messageItem != null) {
      tile = _HeadMessageLayoutReporter(
        message: messageItem,
        onLaidOut: _onHeadMessageLaidOut,
        child: tile,
      );
    }
    final rowRevealKey =
        messageItem == null ? null : _stableMessageListKey(messageItem, 0);
    if (rowRevealKey != null) {
      final isActive =
          _viewportInsert.activeRowRevealMessages.containsKey(rowRevealKey);
      final isQueued = _viewportInsert.queuedViewportInsertMessages
          .containsKey(rowRevealKey);
      // list-push 用 controller 线性速度，与 duration=高度/320 一致；
      // 普通 row-reveal 仍走 easeOutCubic。
      final Animation<double>? activeProgress = !isActive
          ? null
          : (_viewportInsert.viewportInsertSlideActive
              ? _viewportInsert.rowRevealController
              : (_viewportInsert.rowRevealAnimation ??
                  _viewportInsert.rowRevealController));
      final rowProgress = activeProgress ??
          (isQueued
              ? const AlwaysStoppedAnimation<double>(0)
              : const AlwaysStoppedAnimation<double>(1));
      tile = ChatMessageRowReveal(
        key: ValueKey<String>(rowRevealKey),
        progress: rowProgress,
        onFullHeightChanged: (height) {
          if (isActive || isQueued) {
            final previousHeight =
                _viewportInsert.rowRevealFullExtentByKey[rowRevealKey];
            _viewportInsert.rowRevealFullExtentByKey[rowRevealKey] = height;
            if (previousHeight == null ||
                (height - previousHeight).abs() > 0.5) {
              final position = _singleScrollPositionOrNull();
              ChatJitterDiag.logInboundFlow(
                action: 'cvp_row_measured',
                conv: _conversationId(),
                extras: <String, Object?>{
                  'cvpTx':
                      _viewportInsert.continuousViewportPushDiagTransaction,
                  'rowKeyHash': rowRevealKey.hashCode,
                  'active': isActive,
                  'queued': isQueued,
                  'before': previousHeight?.toStringAsFixed(2) ?? 'none',
                  'height': height.toStringAsFixed(2),
                  'pixels': position?.hasPixels == true
                      ? position!.pixels.toStringAsFixed(2)
                      : 'n/a',
                  'min': position?.hasContentDimensions == true
                      ? position!.minScrollExtent.toStringAsFixed(2)
                      : 'n/a',
                  'max': position?.hasContentDimensions == true
                      ? position!.maxScrollExtent.toStringAsFixed(2)
                      : 'n/a',
                  'phase': SchedulerBinding.instance.schedulerPhase.name,
                },
              );
            }
          }
        },
        child: tile,
      );
    }
    if (_shouldHideMessageDuringPaginationPrependReveal(resolvedGlobalIndex)) {
      tile = Opacity(opacity: 0, child: tile);
    }
    return tile;
  }

  _getMessageId(int index) {
    if (widget.messageList[index]!.elemType == 11) {
      return _getMessageId(index - 1);
    }
    return widget.messageList[index]!.msgID;
  }

  void _releaseSearchJumpMemoryWindowSuppress({
    String? anchorMsgID,
    String? anchorSeq,
  }) {
    final gm = _chatGlobalModel;
    final conv = _conversationId();
    if (gm == null) {
      return;
    }
    gm.setMemoryWindowSuppressed(conv, false);
    gm.applyMessageMemoryWindowNow(
      conv,
      memoryWindowAnchorMsgID: anchorMsgID,
      memoryWindowAnchorSeq: anchorSeq,
    );
  }

  void showCantFindMsg() {
    _findingRetryCount = 0;
    findingMsg = null;
    findingAnchor = null;
    findingSeq = "";
    loadingPlace = LoadingPlace.none;
    _releaseSearchJumpMemoryWindowSuppress();
    _chatGlobalModel?.setSearchJumpStatus(
      _conversationId(),
      SearchJumpStatus.failed,
      notify: true,
    );
    if (mounted) {
      setState(() {});
    }
    onTIMCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: TIM_t("无法定位到原消息"),
        infoCode: 6660401));
  }

  _onScrollToAnchor(MessageAnchor targetAnchor) async {
    if (_scrollToFindInFlight) {
      return;
    }
    _lockSearchJumpStabilization(milliseconds: 2600);
    if (widget.messageList.isEmpty) {
      final jumpStatus =
          _chatGlobalModel?.getSearchJumpStatus(_conversationId()) ??
              SearchJumpStatus.idle;
      if (jumpStatus == SearchJumpStatus.failed) {
        return;
      }
      _scheduleScrollToFindingMsgDelayed();
      return;
    }
    _scrollToFindInFlight = true;
    loadingPlace = LoadingPlace.top;
    final generation = ++_searchJumpGeneration;
    final searchTarget = _SearchJumpTarget(
      resolveIndex: () => _globalIndexForAnchor(targetAnchor),
    );
    try {
      final targetGlobalIndex = _resolveSearchJumpGlobalIndex(searchTarget);
      if (targetGlobalIndex != null) {
        final centered = await _centerOnGlobalIndex(
          targetGlobalIndex,
          target: searchTarget,
          generation: generation,
        );
        if (centered) {
          _findingRetryCount = 0;
          final matched = _messageForAnchor(targetAnchor);
          findingAnchor = null;
          findingMsg = null;
          final jumpId = matched == null
              ? targetAnchor.stableKey
              : _messageIdentity(matched);
          if (jumpId.isNotEmpty) {
            widget.model.jumpMsgID = jumpId;
          }
          loadingPlace = LoadingPlace.none;
          _releaseSearchJumpMemoryWindowSuppress(
            anchorMsgID: matched?.msgID ?? targetAnchor.msgID,
            anchorSeq: matched?.seq ?? targetAnchor.seq,
          );
          _chatGlobalModel?.setSearchJumpStatus(
            _conversationId(),
            SearchJumpStatus.success,
            notify: true,
          );
          if (mounted) setState(() {});
          return;
        }
      }
      if (_findingRetryCount < 40) {
        _findingRetryCount++;
        findingAnchor = targetAnchor;
        _scheduleScrollToFindingMsgDelayed();
      } else {
        showCantFindMsg();
      }
    } finally {
      _scrollToFindInFlight = false;
    }
  }

  _onScrollToIndex(V2TimMessage targetMsg) async {
    if (_scrollToFindInFlight) {
      return;
    }
    _lockSearchJumpStabilization(milliseconds: 2600);
    final targetTimeStamp = targetMsg.timestamp;
    if (targetTimeStamp == null) {
      showCantFindMsg();
      return;
    }
    if (widget.messageList.isEmpty) {
      final jumpStatus =
          _chatGlobalModel?.getSearchJumpStatus(_conversationId()) ??
              SearchJumpStatus.idle;
      if (jumpStatus == SearchJumpStatus.failed) {
        return;
      }
      _scheduleScrollToFindingMsgDelayed();
      return;
    }
    _scrollToFindInFlight = true;
    loadingPlace = LoadingPlace.top;
    const int singleLoadAmount = HistoryMessageDartConstant.getCount;
    final generation = ++_searchJumpGeneration;
    final searchTarget = _SearchJumpTarget(
      resolveIndex: () => _globalIndexForTargetMessage(targetMsg),
    );

    try {
      final targetGlobalIndex = _resolveSearchJumpGlobalIndex(searchTarget);
      if (targetGlobalIndex != null) {
        maybeHaveMoreMessageForFind = false;
        final centered = await _centerOnGlobalIndex(
          targetGlobalIndex,
          target: searchTarget,
          generation: generation,
        );
        if (centered) {
          _findingRetryCount = 0;
          findingMsg = null;
          final jumpId = _messageIdentity(targetMsg);
          if (jumpId.isNotEmpty) {
            widget.model.jumpMsgID = jumpId;
          }
          loadingPlace = LoadingPlace.none;
          _releaseSearchJumpMemoryWindowSuppress(
            anchorMsgID: targetMsg.msgID,
            anchorSeq: targetMsg.seq,
          );
          if (mounted) {
            setState(() {});
          }
          return;
        }

        // 已经在当前窗口里找到目标，只是列表还没稳定到可滚动状态。
        // 不要继续拉历史，否则会把搜索跳转变成连续 older 分页，导致红屏。
        if (_findingRetryCount < 12) {
          _findingRetryCount++;
          findingMsg = targetMsg;
          _scheduleScrollToFindingMsgDelayed();
        } else {
          showCantFindMsg();
        }
        return;
      }

      // 从搜索结果进入聊天时，Provider 已经按目标消息构建上下文窗口。
      // 如果此刻还没找到，优先等待列表刷新，不主动继续翻旧消息，避免
      // 连续触发 group_history_message older 拉取造成无法定位和红屏。
      if (_isInitialFindingTarget(targetMsg)) {
        if (_findingRetryCount < 40) {
          _findingRetryCount++;
          findingMsg = targetMsg;
          _scheduleScrollToFindingMsgDelayed();
        } else {
          showCantFindMsg();
        }
        return;
      }

      if (maybeHaveMoreMessageForFind && widget.model.haveMoreData) {
        findingMsg = targetMsg;
        final lastMsgId = _getMessageId(widget.messageList.length - 1);
        _lockSearchJumpStabilization(milliseconds: 2600);
        maybeHaveMoreMessageForFind = await widget.onLoadMore(
          lastMsgId,
          LoadDirection.previous,
          singleLoadAmount,
        );
        _lockSearchJumpStabilization(milliseconds: 2600);
        if (mounted) {
          _scheduleScrollToFindingMsg();
        }
      } else {
        showCantFindMsg();
      }
    } finally {
      _scrollToFindInFlight = false;
    }
  }

  /// Tongue 「@我」：优先内存命中；否则 around-seq 开窗（同搜索跳转），禁止 seq 差追翻。
  Future<bool> _onScrollToIndexBySeq(String targetSeq) async {
    if (_scrollToFindInFlight) {
      return false;
    }
    _lockSearchJumpStabilization(milliseconds: 2600);
    loadingPlace = LoadingPlace.top;
    // Clear legacy chase flag so build() cannot re-enter this path.
    findingSeq = "";

    final targetSeqInt = AtMeJump.parseTargetSeq(targetSeq);
    final canonicalSeq = AtMeJump.canonicalSeqString(targetSeq);
    if (targetSeqInt == null || canonicalSeq == null) {
      showCantFindMsg();
      loadingPlace = LoadingPlace.none;
      return false;
    }

    _scrollToFindInFlight = true;
    try {
      var targetGlobalIndex = _globalIndexForSeq(canonicalSeq);
      if (targetGlobalIndex == null) {
        ChatHistoryTrace.log(
          'at_me_around_jump_begin',
          conversationID: _conversationId(),
          extras: <String, Object?>{
            'targetSeq': canonicalSeq,
            'listLen': widget.messageList.length,
            'haveMoreData': widget.model.haveMoreData,
            'haveMoreLatestData': widget.model.haveMoreLatestData,
          },
        );
        final loaded =
            await widget.model.loadListForSpecificMessage(seq: targetSeqInt);
        if (!mounted) {
          return false;
        }
        if (!loaded) {
          ChatHistoryTrace.log(
            'at_me_around_jump_fail',
            conversationID: _conversationId(),
            extras: <String, Object?>{'targetSeq': canonicalSeq},
          );
          showCantFindMsg();
          loadingPlace = LoadingPlace.none;
          return false;
        }
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) {
          return false;
        }
        targetGlobalIndex = _globalIndexForSeq(canonicalSeq);
      }

      if (targetGlobalIndex == null) {
        ChatHistoryTrace.log(
          'at_me_around_jump_missing_after_load',
          conversationID: _conversationId(),
          extras: <String, Object?>{
            'targetSeq': canonicalSeq,
            'listLen': widget.messageList.length,
          },
        );
        showCantFindMsg();
        loadingPlace = LoadingPlace.none;
        return false;
      }

      final centered = await _centerOnAtMeSeq(
        canonicalSeq,
        targetGlobalIndex,
      );
      if (!centered) {
        showCantFindMsg();
      }
      ChatHistoryTrace.log(
        centered
            ? 'at_me_around_jump_success'
            : 'at_me_around_jump_center_fail',
        conversationID: _conversationId(),
        extras: <String, Object?>{
          'targetSeq': canonicalSeq,
          'listLen': widget.messageList.length,
          'haveMoreData': widget.model.haveMoreData,
          'haveMoreLatestData': widget.model.haveMoreLatestData,
          'position': _chatGlobalModel
                  ?.getMessageListPosition(_conversationId())
                  .name ??
              '',
        },
      );
      return centered;
    } finally {
      _scrollToFindInFlight = false;
      if (mounted && loadingPlace != LoadingPlace.none) {
        loadingPlace = LoadingPlace.none;
      }
    }
  }

  Future<bool> _centerOnAtMeSeq(
    String canonicalSeq,
    int targetGlobalIndex,
  ) async {
    String? targetMsgID;
    final messageList = _visibleMessageList(widget.messageList);
    if (targetGlobalIndex >= 0 && targetGlobalIndex < messageList.length) {
      targetMsgID = messageList[targetGlobalIndex]?.msgID;
    }
    final generation = ++_searchJumpGeneration;
    final searchTarget = _SearchJumpTarget(
      resolveIndex: () => _globalIndexForSeq(canonicalSeq),
    );
    final centered = await _centerOnGlobalIndex(
      targetGlobalIndex,
      target: searchTarget,
      generation: generation,
    );
    if (centered && targetMsgID != null && targetMsgID.isNotEmpty) {
      widget.model.jumpMsgID = targetMsgID;
    }
    loadingPlace = LoadingPlace.none;
    if (centered) {
      _releaseSearchJumpMemoryWindowSuppress(
        anchorMsgID: targetMsgID,
        anchorSeq: canonicalSeq,
      );
    }
    if (mounted) {
      setState(() {});
    }
    return centered;
  }

  _onScrollToIndexBegin(V2TimMessage targetMsg) {
    _lockSearchJumpStabilization(milliseconds: 2600);
    final lastTimestamp =
        widget.messageList[widget.messageList.length - 1]?.timestamp;
    final msgList = widget.messageList;
    final int targetTimeStamp = targetMsg.timestamp!;

    if (targetTimeStamp >= lastTimestamp!) {
      bool isFound = false;
      int targetIndex = 1;
      for (int i = msgList.length - 1; i >= 0; i--) {
        final currentMsg = msgList[i];
        if (_messageMatchesTarget(currentMsg, targetMsg)) {
          isFound = true;
          targetIndex = -i;
          break;
        }
      }
      if (isFound && targetIndex != 1) {
        final targetGlobalIndex = -targetIndex;
        final generation = ++_searchJumpGeneration;
        final searchTarget = _SearchJumpTarget(
          resolveIndex: () => _globalIndexForTargetMessage(targetMsg),
        );
        _centerOnGlobalIndex(
          targetGlobalIndex,
          target: searchTarget,
          generation: generation,
        );
      }
    }
  }

  List<V2TimMessage?> _getReceivedMessageList(int receivedMessageListCount) {
    if (receivedMessageListCount == 0) {
      return [];
    }
    final haveTimeStampMessage =
        widget.messageList[receivedMessageListCount]?.elemType == 11;
    final endPoint = haveTimeStampMessage
        ? receivedMessageListCount + 1
        : receivedMessageListCount;
    return widget.messageList.sublist(0, endPoint).reversed.toList();
  }

  Widget _buildTongueContainer(List<V2TimMessage?> messageList) {
    return TIMUIKitHistoryMessageListTongueContainer(
      conversation: widget.conversation,
      model: widget.model,
      messageList: messageList,
      scrollController: _autoScrollController,
      scrollToIndexBySeq: _onScrollToIndexBySeq,
      scrollToFirstUnread: _scrollToFirstUnreadFromTongue,
      groupAtInfoList: widget.groupAtInfoList,
      tongueItemBuilder: widget.tongueItemBuilder,
      pageHistoryPosition: _pageUi.historyPosition,
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final messageList = _visibleMessageList(widget.messageList);
    final globalModel = context.read<TUIChatGlobalModel>();
    _handleInitialHistoryBootstrapTransition(globalModel);
    if (messageList.isEmpty) {
      final jumpStatus = globalModel.getSearchJumpStatus(_conversationId());
      final isSearchJump =
          widget.searchJumpAnchor != null || widget.initFindingMsg != null;
      if (isSearchJump && jumpStatus == SearchJumpStatus.loading) {
        return Center(
          child: _buildHistoryLoadingSpinner(size: 36, strokeWidth: 3),
        );
      }
      if (isSearchJump &&
          jumpStatus == SearchJumpStatus.failed &&
          !widget.model.isLoadingChatHistory) {
        return Container();
      }
      final convId = _conversationId();
      final stillBootstrapping = !globalModel.hasInitialHistoryLoaded(convId);
      // 已确认过历史（含确认空会话）：直接空态，不要因后台补拉再全屏转圈。
      if (!stillBootstrapping) {
        return Container();
      }
      // 首屏冷启动静默：不用全屏转圈挡视野；有锁定未读时继续走下方 tongue 布局。
      if (!globalModel.hasLockedEntryUnreadFor(convId)) {
        return Container();
      }
    }

    final rawUnreadNewMessageCount = globalModel.unreadCountForTongue;
    final dismissedEntryUnreadCount =
        globalModel.getDismissedEntryUnreadTongueCount(_conversationId());
    final completedEntryUnreadCount =
        dismissedEntryUnreadCount > _completedEntryUnreadCount
            ? dismissedEntryUnreadCount
            : _completedEntryUnreadCount;
    final unreadNewMessageCount =
        globalModel.hasLockedEntryUnreadFor(_conversationId())
            ? globalModel.lockedEntryUnreadCount
            : (rawUnreadNewMessageCount <= completedEntryUnreadCount
                ? 0
                : rawUnreadNewMessageCount);
    final tongueEnabled = UnreadTonguePolicy.isEntryUnreadEnabled(
      widget.conversation,
      unreadNewMessageCount,
    );
    final effectiveUnreadNewMessageCount =
        tongueEnabled ? unreadNewMessageCount : 0;
    final loadedRealMessageCount = _unreadAnchorMessageCount(messageList);
    final safeUnreadCount =
        effectiveUnreadNewMessageCount > loadedRealMessageCount
            ? loadedRealMessageCount
            : effectiveUnreadNewMessageCount;
    final layoutUnreadCount = _layoutUnreadCount(safeUnreadCount);
    if (ChatJitterDiag.enabled &&
        safeUnreadCount > 0 &&
        (layoutUnreadCount != _lastDiagLayoutUnread ||
            safeUnreadCount != _lastDiagLayoutSafeUnread)) {
      _lastDiagLayoutUnread = layoutUnreadCount;
      _lastDiagLayoutSafeUnread = safeUnreadCount;
      if (layoutUnreadCount < safeUnreadCount) {
        _logReadingHistoryIncoming(
          'layout_partition_deferred',
          globalModel: globalModel,
          extras: <String, Object?>{
            'safeUnread': safeUnreadCount,
            'layoutUnread': layoutUnreadCount,
            'centerSplit': layoutUnreadCount > 0,
          },
        );
      } else if (_deferUnreadCenterPartition) {
        _logReadingHistoryIncoming(
          'layout_partition_active',
          globalModel: globalModel,
          extras: <String, Object?>{
            'safeUnread': safeUnreadCount,
            'layoutUnread': layoutUnreadCount,
          },
        );
      }
    }
    final shouldShowUnreadMessage = layoutUnreadCount > 0;
    final unreadEndPoint = _realUnreadEndPoint(messageList, layoutUnreadCount);
    final tongueMetricsUnreadCount =
        _tongueMetricsUnreadCount(safeUnreadCount, globalModel);
    if (_firstUnreadAnchorJumped &&
        globalModel.getMessageListPosition(_conversationId()) ==
            HistoryMessagePosition.bottom) {
      _firstUnreadAnchor = null;
      _firstUnreadAnchorJumped = false;
    } else {
      _captureFirstUnreadAnchor(messageList, effectiveUnreadNewMessageCount);
    }
    if (effectiveUnreadNewMessageCount > 0) {
      if (!_unreadEntryBottomPinScheduled &&
          !_firstUnreadAnchorJumped &&
          !_deferUnreadCenterPartition &&
          !_isReadingHistory() &&
          globalModel.getMessageListPosition(_conversationId()) ==
              HistoryMessagePosition.bottom) {
        _unreadEntryBottomPinScheduled = true;
        _schedulePinScrollToBottomOnUnreadEntry();
      }
      _scheduleUnreadTongueMetricsUpdate(messageList, tongueMetricsUnreadCount);
    } else {
      globalModel.clearUnreadTongueMetrics(_conversationId(), notify: false);
    }
    String getMessageIdentifier(V2TimMessage? message, int index) {
      return _stableMessageListKey(message, index);
    }

    _rebuildListPartitionsIfNeeded(
      messageList: messageList,
      safeUnreadCount: layoutUnreadCount,
      unreadEndPoint: unreadEndPoint,
      restoreVersion: globalModel.mediaPreviewRestoreVersion,
      messageListRevision:
          globalModel.messageListRevisionFor(_conversationId()),
      getMessageIdentifier: getMessageIdentifier,
    );
    final unreadMessageList = _cachedUnreadList;
    final readMessageList = _cachedReadList;
    final previousAnchor = _anchorForPreviousLoad(readMessageList) ??
        _anchorForPreviousLoad(messageList);
    final latestAnchor = _anchorForLatestLoad(messageList);
    final configuredShrinkWrap =
        widget.mainHistoryListConfig?.shrinkWrap ?? false;
    final unreadCenter = shouldShowUnreadMessage ? _unreadCenterKey : null;
    // Flutter does not allow CustomScrollView to use center together with
    // shrinkWrap. Keep the unread anchor behavior and disable shrinkWrap only
    // for this case to avoid breaking incoming-message rendering.
    final effectiveShrinkWrap =
        unreadCenter == null ? configuredShrinkWrap : false;
    final keyboardActive = _isKeyboardInsetActive(context);
    _routeScroll.shortHistoryKeyboardJustDismissed =
        _routeScroll.shortHistoryKeyboardWasActive && !keyboardActive;
    if (_routeScroll.shortHistoryKeyboardJustDismissed) {
      // 收起键盘：保留 latch，清 baseline 让 spacer 按完整视口重算。
      _routeScroll.shortHistoryBaselineViewportHeight = -1;
    }
    _routeScroll.shortHistoryKeyboardWasActive = keyboardActive;
    _scheduleShortHistoryTopAlignment(
      context: context,
      messageList: messageList,
      safeUnreadCount: layoutUnreadCount,
    );

    final throttleFunction =
        OptimizeUtils.multiThrottle((index, LoadDirection direction) async {
      final msgID =
          TIMUIKitChatUtils.getMessageIDWithinIndex(readMessageList, index);
      await widget.onLoadMore(msgID, direction);
    }, 20);

    final throttleFunctionWithMsgID =
        OptimizeUtils.multiThrottle((msgID, LoadDirection direction) async {
      await widget.onLoadMore(msgID, direction);
    }, 200);

    if (findingAnchor != null || findingMsg != null) {
      _scheduleScrollToFindingMsg();
    }

    final shouldShowCenterHistoryLoading = messageList.isEmpty
        ? !_shouldSilenceInitialHistoryLoading(globalModel) &&
            (widget.model.isLoadingChatHistory ||
                globalModel.hasLockedEntryUnreadFor(_conversationId()))
        : _shouldShowCenterHistoryLoading(
            isLoadingHistory: widget.model.isLoadingChatHistory,
            messageList: messageList,
            effectiveUnreadNewMessageCount: effectiveUnreadNewMessageCount,
            loadedRealMessageCount: loadedRealMessageCount,
            globalModel: globalModel,
          );

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
            if (notification.depth != 0) {
              return false;
            }
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              _userScrollGestureActive = true;
              _setUserScrolling(true);
              _setCompactHistoryCacheExtent(true);
              _cancelForcePinScroll();
              // 只取消上推 generation，不要 snap/jump，否则会掐断用户拖动且可能丢 ScrollEnd。
              if (_viewportInsert.viewportInsertSlideActive) {
                _viewportInsert.viewportInsertSlideGeneration++;
                _viewportInsert.viewportInsertSlideActive = false;
                _releaseArmedViewportInsertReveal();
              }
              _clearIncomingScrollAnchor(reason: 'user_scroll_start');
              final metrics = notification.metrics;
              if (!_isHistoryScrollProtected &&
                  metrics.hasPixels &&
                  metrics.hasContentDimensions) {
                _paginationUi.resetTopReachConsumedIfScrolledAway(
                  pixels: metrics.pixels,
                  maxScrollExtent: metrics.maxScrollExtent,
                );
              }
            } else if (notification is ScrollUpdateNotification ||
                notification is OverscrollNotification) {
              if (notification is ScrollUpdateNotification &&
                  notification.dragDetails != null &&
                  !_compactHistoryCacheExtent) {
                _setCompactHistoryCacheExtent(true);
              }
              if (safeUnreadCount > 0) {
                _scheduleUnreadTongueMetricsUpdate(
                  messageList,
                  tongueMetricsUnreadCount,
                );
              }
              final metrics = notification.metrics;
              if (_isNearTopForHistoryLoad(metrics) &&
                  previousAnchor != null &&
                  widget.model.haveMoreData &&
                  !_paginationUi.triedPreviousAfterNoMore &&
                  !_shouldShowTopHistoryLoading &&
                  !_paginationUi.silentTopHistoryLoading &&
                  !_paginationUi.isLoadingPrevious &&
                  (_shouldTriggerLoadPreviousFromScroll(
                        metrics,
                        anchor: previousAnchor,
                      ) ||
                      (_paginationUi.loadPreviousDebounce?.isActive ??
                          false))) {
                _markTopHistoryLoadingScheduled();
              }
              if (_shouldTriggerLoadPreviousFromScroll(
                metrics,
                anchor: previousAnchor,
              )) {
                _scheduleLoadPrevious(previousAnchor);
              }
              if (!_paginationUi.isLoadingLatest &&
                  metrics.hasPixels &&
                  metrics.hasContentDimensions) {
                final nearLatest = _isNearLatestScrollEdge(
                  metrics,
                  relaxed: _isSearchJumpHistoryMode(globalModel),
                );
                if (nearLatest) {
                  _scheduleLoadLatest(
                    latestAnchor,
                    globalModel: globalModel,
                    safeUnreadCount: safeUnreadCount,
                  );
                }
              }
            } else if (notification is ScrollEndNotification) {
              // 无论是否标记过 active，都清全局滚动态，防止掐断后丢 End 导致永久失灵。
              _userScrollGestureActive = false;
              _setUserScrolling(false);
              _setCompactHistoryCacheExtent(false);
              final deferBefore = _deferUnreadCenterPartition;
              _maybeReleaseUnreadCenterDeferral();
              if (!_isReadingHistory()) {
                // 防抖后再 flush：避免松手瞬间与惯性抢主线程。
                _schedulePostScrollInboundFlush(globalModel);
              }
              if (deferBefore != _deferUnreadCenterPartition && mounted) {
                setState(() {});
              }
              if (safeUnreadCount > 0) {
                _scheduleUnreadTongueMetricsUpdate(
                  messageList,
                  tongueMetricsUnreadCount,
                  force: true,
                );
              }
              if (_isHistoryScrollProtected) {
                if (_paginationUi.ignoreScrollLoadPrevious > 0) {
                  _paginationUi.ignoreScrollLoadPrevious--;
                }
                return false;
              }
              if (_paginationUi.ignoreScrollLoadPrevious > 0) {
                _paginationUi.ignoreScrollLoadPrevious--;
                return false;
              }
              final metrics = notification.metrics;
              // ScrollEnd 不再单独触发上翻；ScrollUpdate 已覆盖，避免同一次滑动手势重复请求。
              if (!_paginationUi.isLoadingLatest &&
                  metrics.hasPixels &&
                  metrics.hasContentDimensions) {
                final nearLatest = _isNearLatestScrollEdge(
                  metrics,
                  relaxed: _isSearchJumpHistoryMode(globalModel),
                );
                if (nearLatest) {
                  _scheduleLoadLatest(
                    latestAnchor,
                    globalModel: globalModel,
                    safeUnreadCount: safeUnreadCount,
                  );
                }
              }
            }
            return false;
          }, child: LayoutBuilder(
            builder: (context, constraints) {
              _scheduleShortViewportHistoryFill(previousAnchor);
              final shortHistoryBottomSpacer = _displayShortHistoryBottomSpacer(
                context,
                messageList: messageList,
                safeUnreadCount: layoutUnreadCount,
                viewportHeight: constraints.maxHeight,
              );
              // 整页 gate Offstage 期间仍需 layout/测高；可见性由 Chat 页 gate 统一控制。
              _evaluateHistoryOpenReveal(
                messageList: messageList,
                viewportHeight: constraints.maxHeight,
              );
              final scrollView = CustomScrollView(
                center: unreadCenter,
                key: widget.mainHistoryListConfig?.key,
                primary: widget.mainHistoryListConfig?.primary,
                physics: _buildHistoryScrollPhysics(),
                // padding: widget.mainHistoryListConfig?.padding ?? EdgeInsets.zero,
                // itemExtent: widget.mainHistoryListConfig?.itemExtent,
                // prototypeItem: widget.mainHistoryListConfig?.prototypeItem,
                cacheExtent: _effectiveHistoryCacheExtent(),
                semanticChildCount:
                    widget.mainHistoryListConfig?.semanticChildCount,
                dragStartBehavior:
                    widget.mainHistoryListConfig?.dragStartBehavior ??
                        DragStartBehavior.start,
                keyboardDismissBehavior:
                    widget.mainHistoryListConfig?.keyboardDismissBehavior ??
                        ScrollViewKeyboardDismissBehavior.onDrag,
                restorationId: widget.mainHistoryListConfig?.restorationId,
                clipBehavior:
                    widget.mainHistoryListConfig?.clipBehavior ?? Clip.hardEdge,
                reverse: true,
                shrinkWrap: effectiveShrinkWrap,
                controller: _autoScrollController,
                slivers: [
                  if (shortHistoryBottomSpacer > 0)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: shortHistoryBottomSpacer,
                      ),
                    ),
                  SliverPadding(
                    padding: widget.mainHistoryListConfig?.padding ??
                        EdgeInsets.zero,
                    sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              final messageItem = unreadMessageList[index];
                              if (!globalModel
                                      .isRestoringScrollAfterMediaPreview &&
                                  index == unreadMessageList.length - 1 &&
                                  _shouldAutoLoadLatest(
                                    globalModel: globalModel,
                                    safeUnreadCount: safeUnreadCount,
                                  )) {
                                _scheduleLoadLatest(
                                  _anchorForLatestLoad(messageList),
                                  globalModel: globalModel,
                                  safeUnreadCount: safeUnreadCount,
                                );
                              }
                              return _buildScrollMessageTile(
                                messageItem,
                                index,
                                globalIndex: _globalIndexMap[
                                    getMessageIdentifier(messageItem, index)],
                              );
                            },
                            childCount: unreadMessageList.length,
                            addRepaintBoundaries: widget.mainHistoryListConfig
                                    ?.addRepaintBoundaries ??
                                true,
                            findChildIndexCallback: (Key key) {
                              final ValueKey<String> valueKey =
                                  key as ValueKey<String>;
                              final index = _unreadIndexMap[valueKey.value];
                              return index;
                            })),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.zero,
                    key: _unreadCenterKey,
                  ),
                  SliverPadding(
                    padding: widget.mainHistoryListConfig?.padding ??
                        EdgeInsets.zero,
                    sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              final messageItem = readMessageList[index];
                              if (!globalModel
                                      .isRestoringScrollAfterMediaPreview &&
                                  index == 0 &&
                                  _shouldAutoLoadLatest(
                                    globalModel: globalModel,
                                    safeUnreadCount: safeUnreadCount,
                                  )) {
                                _scheduleLoadLatest(
                                  _anchorForLatestLoad(messageList),
                                  globalModel: globalModel,
                                  safeUnreadCount: safeUnreadCount,
                                );
                              }
                              return _buildScrollMessageTile(
                                messageItem,
                                index,
                                globalIndex: _globalIndexMap[
                                    getMessageIdentifier(messageItem, index)],
                              );
                            },
                            childCount: readMessageList.length,
                            addRepaintBoundaries: widget.mainHistoryListConfig
                                    ?.addRepaintBoundaries ??
                                true,
                            findChildIndexCallback: (Key key) {
                              final ValueKey<String> valueKey =
                                  key as ValueKey<String>;
                              final index = _readIndexMap[valueKey.value];
                              return index;
                            })),
                  ),
                ],
              );
              // 未揭开前保持测高；一旦亮过就不再藏，避免 tip/二次 begin 把列表闪没。
              if (!_historyOpenRevealPainted) {
                return Opacity(
                  opacity: 0,
                  child: IgnorePointer(child: scrollView),
                );
              }
              return scrollView;
            },
          )),
        ),
        if (_shouldShowTopHistoryLoading)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: _buildTopHistoryLoadingIndicator(),
              ),
            ),
          ),
        _buildTongueContainer(messageList),
        if (shouldShowCenterHistoryLoading) _buildCenterHistoryLoadingOverlay(),
      ],
    );
  }
}

class _HistoryMessageListSelectorData {
  final List<V2TimMessage?> messageList;
  final int restoreVersion;
  final int messageListRevision;
  final int projectionRevision;
  final bool scrollLockedForOverlay;

  const _HistoryMessageListSelectorData({
    required this.messageList,
    required this.restoreVersion,
    required this.messageListRevision,
    required this.projectionRevision,
    required this.scrollLockedForOverlay,
  });
}

class _UnreadMessageAnchor {
  final String conversationID;
  final String identity;
  final int? seq;

  const _UnreadMessageAnchor({
    required this.conversationID,
    required this.identity,
    required this.seq,
  });
}

class _PreviousLoadAnchor {
  final String? msgID;
  final int? seq;

  const _PreviousLoadAnchor({
    required this.msgID,
    required this.seq,
  });
}

class _SearchJumpTarget {
  final int? Function() resolveIndex;

  const _SearchJumpTarget({
    required this.resolveIndex,
  });
}

class _FirstUnreadJumpFrameCheck {
  final int targetGlobalIndex;
  final bool isReady;
  final double topDelta;
  final double tolerance;
  final double? targetPixels;

  const _FirstUnreadJumpFrameCheck({
    required this.targetGlobalIndex,
    required this.isReady,
    required this.topDelta,
    required this.tolerance,
    this.targetPixels,
  });

  factory _FirstUnreadJumpFrameCheck.notReady(int targetGlobalIndex) {
    return _FirstUnreadJumpFrameCheck(
      targetGlobalIndex: targetGlobalIndex,
      isReady: false,
      topDelta: double.infinity,
      tolerance: 0,
    );
  }

  bool get isTopAligned => isReady && topDelta.abs() <= tolerance;
}

class _SearchJumpFrameCheck {
  final int targetGlobalIndex;
  final bool isReady;
  final double centerDelta;
  final double tolerance;
  const _SearchJumpFrameCheck({
    required this.targetGlobalIndex,
    required this.isReady,
    required this.centerDelta,
    required this.tolerance,
  });

  factory _SearchJumpFrameCheck.notReady(int targetGlobalIndex) {
    return _SearchJumpFrameCheck(
      targetGlobalIndex: targetGlobalIndex,
      isReady: false,
      centerDelta: double.infinity,
      tolerance: 0,
    );
  }

  bool get isCentered => isReady && centerDelta.abs() <= tolerance;
}

/// 仅包裹全局最新消息（globalIndex == 0），上报行高与发送浮层目标位。
/// 禁止使用 GlobalKey：未读/已读分区各有 index 0，GlobalKey 会冲突并导致列表空白。
class _HeadMessageLayoutReporter extends StatefulWidget {
  const _HeadMessageLayoutReporter({
    required this.message,
    required this.onLaidOut,
    required this.child,
  });

  final V2TimMessage message;
  final void Function(V2TimMessage message, Size size, Rect globalRect)
      onLaidOut;
  final Widget child;

  @override
  State<_HeadMessageLayoutReporter> createState() =>
      _HeadMessageLayoutReporterState();
}

class _HeadMessageLayoutReporterState
    extends State<_HeadMessageLayoutReporter> {
  int _reportAttempts = 0;

  @override
  void initState() {
    super.initState();
    _scheduleReport();
  }

  @override
  void didUpdateWidget(covariant _HeadMessageLayoutReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleReport();
  }

  void _scheduleReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportIfReady());
  }

  void _reportIfReady() {
    if (!mounted) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      if (_reportAttempts < 4) {
        _reportAttempts++;
        _scheduleReport();
      }
      return;
    }
    final offset = box.localToGlobal(Offset.zero);
    widget.onLaidOut(widget.message, box.size, offset & box.size);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _MessageEnterAnimationGate extends StatefulWidget {
  final V2TimMessage message;
  final Widget child;
  final TUIChatGlobalModel globalModel;
  final String stableKey;
  final MessageEnterAnimationParams enterParams;
  final bool animateExtent;
  final VoidCallback? onEnterAnimationFinished;

  const _MessageEnterAnimationGate({
    required this.message,
    required this.child,
    required this.globalModel,
    required this.stableKey,
    required this.enterParams,
    this.animateExtent = false,
    this.onEnterAnimationFinished,
  });

  @override
  State<_MessageEnterAnimationGate> createState() =>
      _MessageEnterAnimationGateState();
}

class _MessageEnterAnimationGateState
    extends State<_MessageEnterAnimationGate> {
  late bool _showAnimation;

  @override
  void initState() {
    super.initState();
    _showAnimation =
        widget.globalModel.isMessageEnterAnimationPending(widget.message);
  }

  void _onAnimationFinished() {
    widget.globalModel.finishMessageEnterAnimation(widget.message);
    widget.onEnterAnimationFinished?.call();
    if (mounted) {
      setState(() {
        _showAnimation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showAnimation) {
      return widget.child;
    }
    return ListenableBuilder(
      listenable: widget.globalModel,
      builder: (context, _) {
        var child = widget.child;
        if (widget.globalModel.shouldHideBubbleForSendFly(widget.message)) {
          child = Opacity(opacity: 0, child: child);
        }
        return ChatMessageEnterAnimation(
          key: ValueKey(widget.stableKey),
          duration: widget.enterParams.duration,
          slideCurve: widget.enterParams.slideCurve,
          fallbackSlideDistance: widget.enterParams.slideDistance,
          startOpacity: widget.enterParams.startOpacity,
          slideFromInputAnchor: widget.enterParams.slideFromInputAnchor,
          slideBelowInputOffset: widget.enterParams.slideBelowInputOffset,
          useOpacityFade: widget.enterParams.useOpacityFade,
          animateExtent: widget.animateExtent,
          extentCurve: widget.message.isSelf == true
              ? widget.enterParams.slideCurve
              : Curves.easeInOutCubic,
          onFinished: _onAnimationFinished,
          child: child,
        );
      },
    );
  }
}

String _recentMessageOrderSignature(List<V2TimMessage?> messageList) {
  if (messageList.isEmpty) {
    return 'empty';
  }
  final buffer = StringBuffer();
  final scanEnd = messageList.length > 16 ? 16 : messageList.length;
  for (var i = 0; i < scanEnd; i++) {
    final message = messageList[i];
    if (message == null || message.elemType == 11) {
      continue;
    }
    final msgID = message.msgID?.trim() ?? '';
    final id = message.id?.trim() ?? '';
    final seq = message.seq?.trim() ?? '';
    buffer.write(
      '${msgID.isNotEmpty ? msgID : id}|$seq|${message.status ?? ''};',
    );
  }
  return buffer.toString();
}

class TIMUIKitHistoryMessageListSelector extends TIMUIKitStatelessWidget {
  final Widget Function(BuildContext, List<V2TimMessage?>, Widget?) builder;
  final String conversationID;

  TIMUIKitHistoryMessageListSelector(
      {Key? key, required this.builder, required this.conversationID})
      : super(key: key);

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    return Selector<TUIChatGlobalModel, _HistoryMessageListSelectorData>(
        builder: (context, data, child) =>
            builder(context, data.messageList, child),
        shouldRebuild: (previous, next) {
          // restoreVersion 仅用于滚动恢复调度，不应触发整表重建（否则头像会闪一下）。
          if (previous.scrollLockedForOverlay != next.scrollLockedForOverlay) {
            return true;
          }
          if (previous.projectionRevision != next.projectionRevision) {
            return true;
          }
          if (previous.messageListRevision != next.messageListRevision) {
            return true;
          }
          if (previous.messageList.length != next.messageList.length) {
            return true;
          }
          return _recentMessageOrderSignature(previous.messageList) !=
              _recentMessageOrderSignature(next.messageList);
        },
        selector: (context, model) {
          final messageList = model.getMessageList(conversationID) ?? [];
          return _HistoryMessageListSelectorData(
            messageList: messageList,
            restoreVersion: model.mediaPreviewRestoreVersion,
            messageListRevision: model.messageListRevisionFor(conversationID),
            projectionRevision:
                model.messageProjectionRevisionFor(conversationID),
            scrollLockedForOverlay: model.shouldLockChatScrollForMediaPreview,
          );
        });
  }
}

enum _AsyncSpacerAbsorbResult {
  ok,
  overflow,
  skipped,
}
