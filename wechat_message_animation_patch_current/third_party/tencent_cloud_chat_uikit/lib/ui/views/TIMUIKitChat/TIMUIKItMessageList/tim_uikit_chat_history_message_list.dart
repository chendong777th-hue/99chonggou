import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
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
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
// ignore: unused_import
import 'package:tencent_cloud_chat_uikit/ui/utils/optimize_utils.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_config.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_chat_config.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_message_enter_animation.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/keepalive_wrapper.dart';

import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'TIMUIKitTongue/tim_uikit_chat_history_message_list_tongue.dart';
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
  String findingSeq = "";
  late TIMUIKitHistoryMessageListController _controller;
  late AutoScrollController _autoScrollController;
  final GlobalKey _unreadCenterKey = GlobalKey();
  LoadingPlace loadingPlace = LoadingPlace.none;
  bool maybeHaveMoreMessageForFind = true;
  bool _scrollToFindInFlight = false;
  bool _pendingScrollToFind = false;
  bool _isLoadingPrevious = false;
  bool _triedPreviousAfterNoMore = false;
  int _lastLoadPreviousCompletedAtMs = 0;
  int _ignoreScrollLoadPrevious = 0;
  static const _loadPreviousCooldownMs = 1200;
  Timer? _loadPreviousDebounce;
  Timer? _loadingIndicatorTimer;
  AnimationController? _listPushController;
  Animation<double>? _listPushAnimation;
  double _listPushShift = 0;
  static const double _listPushEstimatedRowHeight = 56;
  static const Duration _listPushDuration = Duration(milliseconds: 240);
  int _lastRouteRestoreVersion = 0;
  int _routeRestoreAttempt = 0;
  bool _routeRestoreScheduled = false;
  TUIChatGlobalModel? _routeRestoreGlobalModel;
  TUIChatGlobalModel? _chatGlobalModel;
  List<V2TimMessage?> _cachedUnreadList = [];
  List<V2TimMessage?> _cachedReadList = [];
  int _cacheUnreadCount = -1;
  int _cacheMessageListLen = -1;
  int _cacheRestoreVersion = -1;
  String? _cacheLastMsgKey;
  String? _cacheListStateKey;
  Map<String, int> _unreadIndexMap = {};
  Map<String, int> _readIndexMap = {};
  Map<String, int> _globalIndexMap = {};
  Map<String, int> _globalMessageIdentityIndexMap = {};
  int _latestLoadSuppressedUntilMs = 0;
  String? _initialUnreadAnchorConversationID;
  int _initialUnreadAnchorCount = 0;
  int _initialUnreadAnchorAttempts = 0;
  bool _initialUnreadAnchorScheduled = false;
  bool _unreadTongueMetricsScheduled = false;
  String? _lastUnreadTongueConversationID;
  int? _lastUnreadTongueRemaining;
  int _lastUnreadTongueSafeCount = 0;


  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TIMUIKitHistoryMessageListController();
    _autoScrollController =
        _controller.scrollController ?? AutoScrollController();
    _listPushController = AnimationController(
      vsync: this,
      duration: _listPushDuration,
    );
    _listPushAnimation = Tween<double>(
      begin: _listPushEstimatedRowHeight,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _listPushController!,
      curve: Curves.easeOutCubic,
    ));
    _listPushController!.addListener(() {
      if (mounted) {
        setState(() => _listPushShift = _listPushAnimation?.value ?? 0);
      }
    });
    _listPushController!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _listPushShift = 0);
      }
    });
    _controller.addListener(_controllerListener);
    initFinding();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bindActiveScrollController();
      _onGlobalRouteRestoreChanged();
      _schedulePinScrollToBottom();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    _chatGlobalModel = nextModel;
    if (_routeRestoreGlobalModel == nextModel) {
      return;
    }
    _routeRestoreGlobalModel?.removeListener(_onGlobalRouteRestoreChanged);
    _routeRestoreGlobalModel = nextModel;
    _routeRestoreGlobalModel?.addListener(_onGlobalRouteRestoreChanged);
  }

  void _onGlobalRouteRestoreChanged() {
    if (!mounted) {
      return;
    }
    final globalModel = _routeRestoreGlobalModel;
    if (globalModel == null ||
        !globalModel.isRestoringScrollAfterMediaPreview) {
      return;
    }
    final version = globalModel.mediaPreviewRestoreVersion;
    if (version <= 0) {
      return;
    }
    if (_lastRouteRestoreVersion != version) {
      _lastRouteRestoreVersion = version;
      _routeRestoreAttempt = 0;
    }
    _scheduleRouteScrollRestore(_visibleMessageList(widget.messageList));
  }

  @override
  void didUpdateWidget(TIMUIKitHistoryMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model.conversationID != widget.model.conversationID) {
      _triedPreviousAfterNoMore = false;
      _initialUnreadAnchorConversationID = null;
      _initialUnreadAnchorCount = 0;
      _initialUnreadAnchorAttempts = 0;
      _initialUnreadAnchorScheduled = false;
      _lastUnreadTongueConversationID = null;
      _lastUnreadTongueRemaining = null;
      _lastUnreadTongueSafeCount = 0;
      _chatGlobalModel?.clearActiveChatScrollController(
          conversationID: oldWidget.model.conversationID);
      _chatGlobalModel?.clearUnreadTongueMetrics(
          oldWidget.model.conversationID, notify: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bindActiveScrollController();
        _schedulePinScrollToBottom();
      });
    }
    _onMessageListMaybeInserted(oldWidget.messageList, widget.messageList);
  }

  @override
  void dispose() {
    _loadPreviousDebounce?.cancel();
    _loadingIndicatorTimer?.cancel();
    _listPushController?.dispose();
    _routeRestoreGlobalModel?.removeListener(_onGlobalRouteRestoreChanged);
    _routeRestoreGlobalModel = null;
    _chatGlobalModel?.clearActiveChatScrollController(
        conversationID: _conversationId());
    _chatGlobalModel?.clearUnreadTongueMetrics(
        _conversationId(), notify: false);
    _controller.removeListener(_controllerListener);
    super.dispose();
  }

  String? _headMessageKey(List<V2TimMessage?> list) {
    if (list.isEmpty) {
      return null;
    }
    final head = list.first;
    if (head == null) {
      return null;
    }
    return _stableMessageListKey(head, 0);
  }

  String _conversationId() => widget.model.conversationID;

  ScrollPosition? _singleScrollPositionOrNull() {
    if (!_autoScrollController.hasClients ||
        _autoScrollController.positions.length != 1) {
      return null;
    }
    return _autoScrollController.position;
  }

  Future<bool> _alignGlobalMessageIndexToViewportTop(
    int targetGlobalIndex, {
    Duration duration = const Duration(milliseconds: 220),
  }) async {
    final scrollIndex = -targetGlobalIndex;
    try {
      await _autoScrollController.scrollToIndex(
        scrollIndex,
        preferPosition: AutoScrollPosition.middle,
      );
    } catch (_) {
      return false;
    }

    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) {
      return false;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return false;
    }
    final tagContext = _autoScrollController.tagMap[scrollIndex]?.context;
    final renderObject = tagContext?.findRenderObject();
    if (tagContext == null ||
        renderObject is! RenderBox ||
        !renderObject.attached) {
      return false;
    }

    final viewport = RenderAbstractViewport.of(renderObject);
    final revealedOffset = viewport.getOffsetToReveal(renderObject, 0).offset;
    final targetPixels = revealedOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - targetPixels).abs() <= 1.0) {
      return true;
    }
    await _autoScrollController.animateTo(
      targetPixels.toDouble(),
      duration: duration,
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  void _scheduleUnreadTongueMetricsUpdate(
    List<V2TimMessage?> messageList,
    int safeUnreadCount, {
    bool force = false,
  }) {
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    final convId = _conversationId();
    if (safeUnreadCount <= 20 || messageList.isEmpty) {
      _lastUnreadTongueConversationID = null;
      _lastUnreadTongueRemaining = null;
      _lastUnreadTongueSafeCount = 0;
      globalModel.clearUnreadTongueMetrics(convId, notify: true);
      return;
    }
    if (_unreadTongueMetricsScheduled && !force) {
      return;
    }
    _unreadTongueMetricsScheduled = true;
    final snapshot = List<V2TimMessage?>.from(messageList);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _unreadTongueMetricsScheduled = false;
      if (!mounted) {
        return;
      }
      _updateUnreadTongueMetrics(snapshot, safeUnreadCount);
    });
  }

  void _updateUnreadTongueMetrics(
    List<V2TimMessage?> messageList,
    int safeUnreadCount,
  ) {
    if (!mounted || safeUnreadCount <= 20 || messageList.isEmpty) {
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
    if (nearLatest) {
      _commitUnreadTongueMetrics(
        globalModel: globalModel,
        conversationID: convId,
        remaining: 0,
        below: true,
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
      if (!_isRealChatMessage(message)) {
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
      final revealedOffset = viewport.getOffsetToReveal(renderObject, 0);
      final leadingOffset = revealedOffset.offset - position.pixels;
      final trailingOffset = leadingOffset + renderObject.size.height;

      builtAnyUnread = true;
      if (leadingOffset <= viewportHeight + 4) {
        allBuiltUnreadBelowViewport = false;
      }
      if (trailingOffset >= -4) {
        allBuiltUnreadAboveViewport = false;
      }
      final isVisible = trailingOffset >= -4 &&
          leadingOffset <= viewportHeight + 4;
      if (isVisible) {
        if (oldestVisibleUnreadOrdinal == null ||
            ordinalFromNewest > oldestVisibleUnreadOrdinal) {
          oldestVisibleUnreadOrdinal = ordinalFromNewest;
        }
      }
    }

    if (!builtAnyUnread) {
      return;
    }

    if (oldestVisibleUnreadOrdinal != null) {
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
      _commitUnreadTongueMetrics(
        globalModel: globalModel,
        conversationID: convId,
        remaining: 0,
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
    final safeRemaining = remaining < 0 ? 0 : remaining;
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

  bool _shouldRunListPushEffects() {
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    if (globalModel.isRestoringScrollAfterMediaPreview) {
      return false;
    }
    if (!globalModel.chatConfig.messageEnterAnimationListPushEnabled) {
      return false;
    }
    final convId = _conversationId();
    if (globalModel.getMessageListPosition(convId) !=
        HistoryMessagePosition.bottom) {
      return false;
    }
    if (globalModel.unreadCountForTongue > 0) {
      return false;
    }
    if (globalModel.receivedNewMessageCount > 0) {
      return false;
    }
    return true;
  }

  void _onMessageListMaybeInserted(
    List<V2TimMessage?> oldList,
    List<V2TimMessage?> newList,
  ) {
    final newHead = _headMessageKey(newList);
    final oldHead = _headMessageKey(oldList);
    final insertedAtHead = newList.length > oldList.length &&
        newHead != null &&
        newHead != oldHead;

    if (!insertedAtHead) {
      return;
    }
    if (_shouldRunListPushEffects()) {
      _startListPushAnimation();
    } else {
      _schedulePinScrollToBottom();
    }
  }

  bool _shouldPinScrollToBottom(TUIChatGlobalModel globalModel) {
    if (globalModel.isWalletOverlayOpen) {
      return false;
    }
    if (globalModel.isMediaPickerOverlayOpen) {
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
      return false;
    }
    return true;
  }

  void _schedulePinScrollToBottom({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _pinScrollToBottomIfNeeded(attempt: attempt);
    });
  }

  void _pinScrollToBottomIfNeeded({int attempt = 0}) {
    const maxAttempts = 8;
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    if (!_shouldPinScrollToBottom(globalModel)) {
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

    const pinThreshold = 80.0;
    final nearBottom =
        position.pixels <= position.minScrollExtent + pinThreshold;
    final contentFitsViewport =
        position.maxScrollExtent <= position.minScrollExtent + pinThreshold;

    if (nearBottom || contentFitsViewport) {
      final target = position.minScrollExtent;
      if ((position.pixels - target).abs() > 0.5) {
        _autoScrollController.jumpTo(target);
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

  void _startListPushAnimation() {
    final controller = _listPushController;
    if (controller == null) {
      return;
    }
    controller
      ..stop()
      ..reset();
    if (mounted) {
      setState(() => _listPushShift = _listPushEstimatedRowHeight);
    } else {
      _listPushShift = _listPushEstimatedRowHeight;
    }
    controller.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _compensateScrollPinnedToBottom();
    });
  }

  void _compensateScrollPinnedToBottom() {
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    if (!_shouldPinScrollToBottom(globalModel)) {
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null) {
      return;
    }
    if (!position.hasPixels || !position.hasContentDimensions) {
      return;
    }
    const pinThreshold = 80.0;
    if (position.pixels > position.minScrollExtent + pinThreshold) {
      return;
    }
    _autoScrollController.jumpTo(position.minScrollExtent);
    globalModel.setMessageListPosition(
      _conversationId(),
      HistoryMessagePosition.bottom,
      notify: false,
    );
  }

  void _scheduleRouteScrollRestore(List<V2TimMessage?> renderList) {
    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    if (!globalModel.isRestoringScrollAfterMediaPreview) {
      _routeRestoreScheduled = false;
      return;
    }
    final version = globalModel.mediaPreviewRestoreVersion;
    if (version <= 0) {
      return;
    }
    if (_lastRouteRestoreVersion != version) {
      _lastRouteRestoreVersion = version;
      _routeRestoreAttempt = 0;
      _routeRestoreScheduled = false;
    }
    if (_routeRestoreAttempt >= 24) {
      globalModel.finishScrollAfterMediaPreview(_conversationId());
      _routeRestoreScheduled = false;
      return;
    }
    if (_routeRestoreScheduled) {
      return;
    }
    _routeRestoreScheduled = true;
    final snapshot = List<V2TimMessage?>.from(renderList);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeRestoreScheduled = false;
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
    if (!mounted || version != _lastRouteRestoreVersion) {
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
        _autoScrollController.jumpTo(target.toDouble());
        restored = true;
      }
    }
    if (!restored) {
      final anchorMsgId = globalModel.getScrollRestoreAnchorMsgID(convId);
      if (anchorMsgId != null && anchorMsgId.isNotEmpty) {
        final targetIndex = renderList.indexWhere((message) {
          if (message == null || message.elemType == 11) {
            return false;
          }
          return _messageIdentity(message) == anchorMsgId;
        });
        if (targetIndex >= 0 && _singleScrollPositionOrNull() != null) {
          final scrollIndex = -targetIndex;
          try {
            await _autoScrollController.scrollToIndex(
              scrollIndex,
              preferPosition: AutoScrollPosition.middle,
            );
          } catch (_) {}
          restored = true;
        }
      }
    }
    if (restored) {
      globalModel.finishScrollAfterMediaPreview(convId);
      _routeRestoreAttempt = 0;
      _routeRestoreScheduled = false;
      return;
    }
    _routeRestoreAttempt++;
    if (_routeRestoreAttempt < 3) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) {
          _scheduleRouteScrollRestore(renderList);
        }
      });
      return;
    }
    globalModel.finishScrollAfterMediaPreview(convId);
    _routeRestoreScheduled = false;
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

  _VisibleMessageAnchor? _captureVisibleAnchor(List<V2TimMessage?> renderList) {
    final position = _singleScrollPositionOrNull();
    if (position == null) {
      return null;
    }
    if (!position.hasPixels || !position.hasContentDimensions) {
      return null;
    }
    _VisibleMessageAnchor? candidate;
    double? candidateDistance;
    for (var i = 0; i < renderList.length; i++) {
      final message = renderList[i];
      if (message == null || message.elemType == 11) {
        continue;
      }
      final identity = _messageIdentity(message);
      if (identity.isEmpty) {
        continue;
      }
      final scrollIndex = -i;
      final tagContext = _autoScrollController.tagMap[scrollIndex]?.context;
      final renderObject = tagContext?.findRenderObject();
      if (tagContext == null || renderObject is! RenderBox || !renderObject.attached) {
        continue;
      }
      final viewport = RenderAbstractViewport.of(renderObject);
      final revealedOffset = viewport.getOffsetToReveal(renderObject, 0);
      final leadingOffset = revealedOffset.offset - position.pixels;
      final trailingOffset = leadingOffset + renderObject.size.height;
      if (trailingOffset < -1 || leadingOffset > position.viewportDimension + 1) {
        continue;
      }
      final distance = leadingOffset < 0 ? leadingOffset.abs() : leadingOffset;
      if (candidateDistance == null || distance < candidateDistance) {
        candidateDistance = distance;
        candidate = _VisibleMessageAnchor(
          messageId: identity,
          leadingOffset: leadingOffset,
        );
      }
    }
    return candidate;
  }

  _PreviousLoadAnchor? _anchorForPreviousLoad(List<V2TimMessage?> list) {
    for (var i = list.length - 1; i >= 0; i--) {
      final item = list[i];
      if (item == null || item.elemType == 11) {
        continue;
      }
      final msgID = item.msgID?.trim();
      final seq = int.tryParse(item.seq ?? '');
      if (msgID != null && msgID.isNotEmpty) {
        return _PreviousLoadAnchor(msgID: msgID, seq: seq);
      }
      if (seq != null && seq > 0) {
        return _PreviousLoadAnchor(msgID: null, seq: seq);
      }
    }
    return null;
  }

  bool _canScheduleLoadPrevious() {
    if (_isLoadingPrevious) {
      return false;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return nowMs - _lastLoadPreviousCompletedAtMs >= _loadPreviousCooldownMs;
  }

  void _scheduleLoadPrevious(_PreviousLoadAnchor? anchor) {
    if (anchor == null) {
      return;
    }
    if (!widget.model.haveMoreData && _triedPreviousAfterNoMore) {
      return;
    }
    _loadPreviousDebounce?.cancel();
    _loadPreviousDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!_canScheduleLoadPrevious()) {
        return;
      }
      _loadPrevious(anchor);
    });
  }

  void _compensateScrollAfterPrepend({
    required double anchorPixels,
    required double anchorMaxExtent,
    int attempt = 0,
  }) {
    const maxAttempts = 8;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _singleScrollPositionOrNull() == null) {
        if (attempt < maxAttempts) {
          _compensateScrollAfterPrepend(
            anchorPixels: anchorPixels,
            anchorMaxExtent: anchorMaxExtent,
            attempt: attempt + 1,
          );
        }
        return;
      }
      final position = _singleScrollPositionOrNull()!;
      if (!position.hasPixels || !position.hasContentDimensions) {
        if (attempt < maxAttempts) {
          _compensateScrollAfterPrepend(
            anchorPixels: anchorPixels,
            anchorMaxExtent: anchorMaxExtent,
            attempt: attempt + 1,
          );
        }
        return;
      }
      final delta = position.maxScrollExtent - anchorMaxExtent;
      if (delta <= 0.5 && attempt < maxAttempts) {
        _compensateScrollAfterPrepend(
          anchorPixels: anchorPixels,
          anchorMaxExtent: anchorMaxExtent,
          attempt: attempt + 1,
        );
        return;
      }

      // reverse 列表 older 消息追加在尾部（maxScrollExtent 侧），保持绝对 offset 即可维持视口内容。
      final clamped = anchorPixels.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - clamped).abs() > 0.5) {
        _autoScrollController.jumpTo(clamped);
      }

      if (attempt < maxAttempts - 1 &&
          ((position.pixels - clamped).abs() > 0.5 || delta <= 0.5)) {
        _compensateScrollAfterPrepend(
          anchorPixels: anchorPixels,
          anchorMaxExtent: anchorMaxExtent,
          attempt: attempt + 1,
        );
      }
    });
  }

  void _restoreScrollToVisibleAnchorAfterPrepend(
    _VisibleMessageAnchor anchor, {
    required double fallbackPixels,
    required double fallbackMaxExtent,
    int attempt = 0,
  }) {
    const maxAttempts = 10;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _singleScrollPositionOrNull() == null) {
        if (attempt < maxAttempts) {
          _restoreScrollToVisibleAnchorAfterPrepend(
            anchor,
            fallbackPixels: fallbackPixels,
            fallbackMaxExtent: fallbackMaxExtent,
            attempt: attempt + 1,
          );
        } else {
          _compensateScrollAfterPrepend(
            anchorPixels: fallbackPixels,
            anchorMaxExtent: fallbackMaxExtent,
          );
        }
        return;
      }
      final position = _singleScrollPositionOrNull()!;
      if (!position.hasPixels || !position.hasContentDimensions) {
        if (attempt < maxAttempts) {
          _restoreScrollToVisibleAnchorAfterPrepend(
            anchor,
            fallbackPixels: fallbackPixels,
            fallbackMaxExtent: fallbackMaxExtent,
            attempt: attempt + 1,
          );
        } else {
          _compensateScrollAfterPrepend(
            anchorPixels: fallbackPixels,
            anchorMaxExtent: fallbackMaxExtent,
          );
        }
        return;
      }
      final globalIndex = _globalMessageIdentityIndexMap[anchor.messageId];
      if (globalIndex == null) {
        _compensateScrollAfterPrepend(
          anchorPixels: fallbackPixels,
          anchorMaxExtent: fallbackMaxExtent,
        );
        return;
      }
      final scrollIndex = -globalIndex;
      final tagContext = _autoScrollController.tagMap[scrollIndex]?.context;
      final renderObject = tagContext?.findRenderObject();
      if (tagContext == null || renderObject is! RenderBox || !renderObject.attached) {
        if (attempt < maxAttempts) {
          _restoreScrollToVisibleAnchorAfterPrepend(
            anchor,
            fallbackPixels: fallbackPixels,
            fallbackMaxExtent: fallbackMaxExtent,
            attempt: attempt + 1,
          );
        } else {
          _compensateScrollAfterPrepend(
            anchorPixels: fallbackPixels,
            anchorMaxExtent: fallbackMaxExtent,
          );
        }
        return;
      }
      final viewport = RenderAbstractViewport.of(renderObject);
      final revealedOffset = viewport.getOffsetToReveal(renderObject, 0);
      final targetPixels = (revealedOffset.offset - anchor.leadingOffset).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - targetPixels).abs() > 0.5) {
        _autoScrollController.jumpTo(targetPixels.toDouble());
      }
      final refreshedPosition = _singleScrollPositionOrNull();
      if (refreshedPosition == null) {
        return;
      }
      final refreshedLeadingOffset =
          revealedOffset.offset - refreshedPosition.pixels;
      if ((refreshedLeadingOffset - anchor.leadingOffset).abs() > 1.0 &&
          attempt < maxAttempts - 1) {
        _restoreScrollToVisibleAnchorAfterPrepend(
          anchor,
          fallbackPixels: fallbackPixels,
          fallbackMaxExtent: fallbackMaxExtent,
          attempt: attempt + 1,
        );
      } else if ((refreshedLeadingOffset - anchor.leadingOffset).abs() > 1.0) {
        _compensateScrollAfterPrepend(
          anchorPixels: fallbackPixels,
          anchorMaxExtent: fallbackMaxExtent,
        );
      }
    });
  }

  bool _shouldAutoLoadLatest({
    required TUIChatGlobalModel globalModel,
    required int safeUnreadCount,
  }) {
    if (!widget.model.haveMoreLatestData ||
        globalModel.isRestoringScrollAfterMediaPreview ||
        globalModel.isChatListUserScrolling ||
        _isLoadingPrevious ||
        _ignoreScrollLoadPrevious > 0 ||
        safeUnreadCount > 0) {
      return false;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs < _latestLoadSuppressedUntilMs) {
      return false;
    }
    if (globalModel.getMessageListPosition(_conversationId()) !=
        HistoryMessagePosition.bottom) {
      return false;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null) {
      return false;
    }
    if (!position.hasPixels || !position.hasContentDimensions) {
      return false;
    }
    const latestTriggerThreshold = 96.0;
    return position.pixels <= position.minScrollExtent + latestTriggerThreshold;
  }

  Future<void> _loadPrevious(_PreviousLoadAnchor anchor) async {
    if (_isLoadingPrevious || !mounted) {
      return;
    }
    if (!widget.model.haveMoreData) {
      if (_triedPreviousAfterNoMore) {
        return;
      }
      _triedPreviousAfterNoMore = true;
    }
    _isLoadingPrevious = true;
    double? anchorPixels;
    double? anchorMaxExtent;
    final visibleAnchor =
        _captureVisibleAnchor(_visibleMessageList(widget.messageList));
    final loadPosition = _singleScrollPositionOrNull();
    if (loadPosition != null) {
      final position = loadPosition;
      if (position.hasPixels && position.hasContentDimensions) {
        anchorPixels = position.pixels;
        anchorMaxExtent = position.maxScrollExtent;
      }
    }
    _loadingIndicatorTimer?.cancel();
    if (mounted) {
      loadingPlace = LoadingPlace.top;
      setState(() {});
    }
    try {
      await widget.onLoadMore(
        anchor.msgID,
        LoadDirection.previous,
        null,
        anchor.seq,
      );
    } finally {
      _loadingIndicatorTimer?.cancel();
      _lastLoadPreviousCompletedAtMs = DateTime.now().millisecondsSinceEpoch;
      if (mounted) {
        _isLoadingPrevious = false;
        _latestLoadSuppressedUntilMs =
            DateTime.now().millisecondsSinceEpoch + 900;
        final shouldClearLoading = loadingPlace != LoadingPlace.none;
        if (shouldClearLoading) {
          loadingPlace = LoadingPlace.none;
        }
        if (visibleAnchor != null) {
          _ignoreScrollLoadPrevious++;
          _restoreScrollToVisibleAnchorAfterPrepend(
            visibleAnchor,
            fallbackPixels: anchorPixels ?? 0,
            fallbackMaxExtent: anchorMaxExtent ?? 0,
          );
          Future<void>.delayed(const Duration(milliseconds: 450), () {
            if (mounted && _ignoreScrollLoadPrevious > 0) {
              _ignoreScrollLoadPrevious--;
            }
          });
        } else if (anchorPixels != null && anchorMaxExtent != null) {
          _ignoreScrollLoadPrevious++;
          _compensateScrollAfterPrepend(
            anchorPixels: anchorPixels,
            anchorMaxExtent: anchorMaxExtent,
          );
          Future<void>.delayed(const Duration(milliseconds: 400), () {
            if (mounted && _ignoreScrollLoadPrevious > 0) {
              _ignoreScrollLoadPrevious--;
            }
          });
        }
        if (shouldClearLoading) {
          setState(() {});
        }
      }
    }
  }

  bool _messageMatchesTarget(V2TimMessage? current, V2TimMessage target) {
    if (current == null || current.elemType == 11) {
      return false;
    }
    final targetId = _messageIdentity(target);
    final currentId = _messageIdentity(current);
    if (targetId.isNotEmpty && currentId.isNotEmpty) {
      return currentId == targetId;
    }
    return current.timestamp != null &&
        target.timestamp != null &&
        current.timestamp == target.timestamp;
  }

  void _scheduleScrollToFindingMsg() {
    if (findingMsg == null || _scrollToFindInFlight || _pendingScrollToFind) {
      return;
    }
    _pendingScrollToFind = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScrollToFind = false;
      if (!mounted || findingMsg == null) {
        return;
      }
      _onScrollToIndex(findingMsg!);
    });
  }

  initFinding() async {
    final target = widget.initFindingMsg;
    if (target == null) {
      return;
    }
    var retries = 0;
    while (widget.messageList.isEmpty && retries < 60) {
      await Future.delayed(const Duration(milliseconds: 50));
      retries++;
      if (!mounted) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      findingMsg = target;
      maybeHaveMoreMessageForFind = true;
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
    return 'msg_${message.timestamp}_${message.seq}_$index';
  }

  bool _isFriendTipMessage(V2TimMessage? message) {
    if (message == null ||
        message.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
      return false;
    }
    final raw = message.customElem?.data;
    if (raw == null || raw.isEmpty) {
      return false;
    }
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        return data['businessID'] == 'friend_became_friends';
      }
    } catch (_) {}
    return false;
  }

  List<V2TimMessage?> _visibleMessageList(List<V2TimMessage?> source) {
    final list = <V2TimMessage?>[];
    for (final item in source) {
      if (_isFriendTipMessage(item)) {
        continue;
      }
      if (item?.elemType == 11 && (list.isEmpty || list.last?.elemType == 11)) {
        continue;
      }
      list.add(item);
    }
    return list;
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
      if (globalModel.isMessageEnterAnimationPending(messageItem)) {
        final stableKey = _messageEnterAnimationWidgetKey(messageItem);
        final enterParams = MessageEnterAnimationParams.fromStyle(
          globalModel.chatConfig.messageEnterAnimationStyle,
        );
        return _MessageEnterAnimationGate(
          message: messageItem,
          globalModel: globalModel,
          stableKey: stableKey,
          enterParams: enterParams,
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
        final text = message.textElem?.text ?? '';
        return text.length > 400 || text.split('\n').length > 12;
      default:
        return false;
    }
  }

  String _listStateCacheKey(List<V2TimMessage?> messageList) {
    final buffer = StringBuffer();
    final scanStart = messageList.length > 8 ? messageList.length - 8 : 0;
    for (var i = scanStart; i < messageList.length; i++) {
      final message = messageList[i];
      if (message == null || message.elemType == 11) {
        continue;
      }
      final id = message.msgID ?? message.id ?? '$i';
      buffer.write('$id:${message.status};');
    }
    return buffer.toString();
  }

  bool _isRealChatMessage(V2TimMessage? message) {
    return message != null && message.elemType != 11;
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
      if (_isRealChatMessage(messageList[end])) {
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
      if (!_isRealChatMessage(message)) {
        continue;
      }
      realCount++;
      if (realCount == unreadMessageCount) {
        return i;
      }
    }
    return null;
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
    if (unreadMessageCount <= 20 || messageList.isEmpty) {
      return;
    }
    final convId = _conversationId();
    if (_initialUnreadAnchorConversationID == convId &&
        _initialUnreadAnchorCount == unreadMessageCount) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialUnreadAnchorScheduled = false;
      if (!mounted) {
        return;
      }
      _scrollToLatestUnread(unreadMessageCount);
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
          notify: true,
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
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (mounted) {
            _scrollToFirstUnread(
              unreadMessageCount,
              preferTop: preferTop,
              attempt: attempt + 1,
            );
          }
        });
      }
      return;
    }
    if (_singleScrollPositionOrNull() == null) {
      if (attempt < 30) {
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (mounted) {
            _scrollToFirstUnread(
              unreadMessageCount,
              preferTop: preferTop,
              attempt: attempt + 1,
            );
          }
        });
      }
      return;
    }
    try {
      final aligned = preferTop
          ? await _alignGlobalMessageIndexToViewportTop(targetGlobalIndex)
          : await _autoScrollController.scrollToIndex(
              -targetGlobalIndex,
              preferPosition: AutoScrollPosition.middle,
            ).then((_) => true).catchError((_) => false);
      if (!aligned) {
        if (attempt < 30) {
          Future<void>.delayed(const Duration(milliseconds: 120), () {
            if (mounted) {
              _scrollToFirstUnread(
                unreadMessageCount,
                preferTop: preferTop,
                attempt: attempt + 1,
              );
            }
          });
        }
        return;
      }
      // 首次布局中图片/视频/长文本高度会在下一帧继续变化，补两次顶对齐，
      // 确保点击“xx条新消息”后稳定停在最早一条未读消息。
      if (attempt < 2) {
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (mounted) {
            _scrollToFirstUnread(
              unreadMessageCount,
              preferTop: preferTop,
              attempt: attempt + 1,
            );
          }
        });
      } else {
        _initialUnreadAnchorConversationID = _conversationId();
        _initialUnreadAnchorCount = unreadMessageCount;
        _initialUnreadAnchorAttempts = 0;
        final globalModel =
            Provider.of<TUIChatGlobalModel>(context, listen: false);
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
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (mounted) {
            _scrollToFirstUnread(
              unreadMessageCount,
              preferTop: preferTop,
              attempt: attempt + 1,
            );
          }
        });
      }
    }
  }

  Future<bool> _scrollToFirstUnreadFromTongue(int requestedUnreadCount) async {
    final unreadCount =
        Provider.of<TUIChatGlobalModel>(context, listen: false).unreadCountForTongue;
    var fallbackCount = requestedUnreadCount;
    if (_initialUnreadAnchorCount > fallbackCount) {
      fallbackCount = _initialUnreadAnchorCount;
    }
    if (unreadCount > fallbackCount) {
      fallbackCount = unreadCount;
    }
    if (fallbackCount <= 0) {
      return false;
    }
    await _scrollToFirstUnread(fallbackCount, preferTop: true);
    return true;
  }

  void _rebuildListPartitionsIfNeeded({
    required List<V2TimMessage?> messageList,
    required int safeUnreadCount,
    required int unreadEndPoint,
    required int restoreVersion,
    required String Function(V2TimMessage? message, int index)
        getMessageIdentifier,
  }) {
    final lastMsg = messageList.isNotEmpty ? messageList.last : null;
    final lastMsgKey =
        lastMsg == null ? null : getMessageIdentifier(lastMsg, 0);
    final listStateKey = _listStateCacheKey(messageList);
    if (_cacheMessageListLen == messageList.length &&
        _cacheUnreadCount == safeUnreadCount &&
        _cacheLastMsgKey == lastMsgKey &&
        _cacheListStateKey == listStateKey &&
        _cacheRestoreVersion == restoreVersion) {
      return;
    }
    _cacheRestoreVersion = restoreVersion;
    _cacheMessageListLen = messageList.length;
    _cacheUnreadCount = safeUnreadCount;
    _cacheLastMsgKey = lastMsgKey;
    _cacheListStateKey = listStateKey;
    _cachedUnreadList = safeUnreadCount == 0
        ? <V2TimMessage?>[]
        : messageList.sublist(0, unreadEndPoint).reversed.toList();
    _cachedReadList = messageList
        .sublist(unreadEndPoint, messageList.length)
        .toList();
    _unreadIndexMap = {};
    for (var i = 0; i < _cachedUnreadList.length; i++) {
      _unreadIndexMap[getMessageIdentifier(_cachedUnreadList[i], 0)] = i;
    }
    _readIndexMap = {};
    for (var i = 0; i < _cachedReadList.length; i++) {
      _readIndexMap[getMessageIdentifier(_cachedReadList[i], 0)] = i;
    }
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

  Widget _wrapListMessageItem(V2TimMessage? message, Widget child) {
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
    final resolvedGlobalIndex = globalIndex ??
        _globalIndexMap[_stableMessageListKey(messageItem, index)] ??
        index;
    Widget tile = AutoScrollTag(
      controller: _autoScrollController,
      index: -resolvedGlobalIndex,
      key: ValueKey(_stableMessageListKey(messageItem, index)),
      highlightColor: Colors.black.withOpacity(0.1),
      child: _wrapListMessageItem(
          messageItem, _getMessageItemBuilder(messageItem)),
    );
    if (index > 0 && _listPushShift > 0 && messageItem != null) {
      final globalModel =
          Provider.of<TUIChatGlobalModel>(context, listen: false);
      if (!globalModel.isMessageEnterAnimationPending(messageItem)) {
        tile = Transform.translate(
          offset: Offset(0, -_listPushShift),
          child: tile,
        );
      }
    }
    return tile;
  }

  _getMessageId(int index) {
    if (widget.messageList[index]!.elemType == 11) {
      return _getMessageId(index - 1);
    }
    return widget.messageList[index]!.msgID;
  }

  void showCantFindMsg() {
    findingMsg = null;
    findingSeq = "";
    loadingPlace = LoadingPlace.none;
    onTIMCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: TIM_t("无法定位到原消息"),
        infoCode: 6660401));
  }

  _onScrollToIndex(V2TimMessage targetMsg) async {
    if (_scrollToFindInFlight) {
      return;
    }
    final targetTimeStamp = targetMsg.timestamp;
    if (targetTimeStamp == null) {
      showCantFindMsg();
      return;
    }
    if (widget.messageList.isEmpty) {
      return;
    }
    _scrollToFindInFlight = true;
    // This method called by @ messages or messages been searched, aims to jump to target message
    loadingPlace = LoadingPlace.top;
    const int singleLoadAmount = kIsWeb ? 15 : 40;
    final lastTimestamp =
        widget.messageList[widget.messageList.length - 1]?.timestamp;
    final msgList = widget.messageList;

    try {
      if (lastTimestamp != null && targetTimeStamp >= lastTimestamp) {
        // 当前列表里应该有这个消息，试试能不能直接定位到那去
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
          findingMsg = null;
          _autoScrollController.scrollToIndex(
            targetIndex,
            preferPosition: AutoScrollPosition.middle,
          );

          // execute twice for accurate position, as the position located firstly can be wrong
          _autoScrollController.scrollToIndex(targetIndex,
              preferPosition: AutoScrollPosition.middle);
          _autoScrollController.scrollToIndex(targetIndex,
              preferPosition: AutoScrollPosition.middle);

          final jumpId = _messageIdentity(targetMsg);
          if (jumpId.isNotEmpty) {
            widget.model.jumpMsgID = jumpId;
          }
          loadingPlace = LoadingPlace.none;
        } else if (maybeHaveMoreMessageForFind && widget.model.haveMoreData) {
          findingMsg = targetMsg;
          final lastMsgId = _getMessageId(widget.messageList.length - 1);
          maybeHaveMoreMessageForFind = await widget.onLoadMore(
              lastMsgId, LoadDirection.previous, singleLoadAmount);
          if (mounted) {
            _scheduleScrollToFindingMsg();
          }
        } else {
          showCantFindMsg();
        }
      } else {
        if (maybeHaveMoreMessageForFind) {
          // if the target message not in current message list, load more
          findingMsg = targetMsg;
          final lastMsgId = _getMessageId(widget.messageList.length - 1);
          maybeHaveMoreMessageForFind = await widget.onLoadMore(
              lastMsgId, LoadDirection.previous, singleLoadAmount);
          if (mounted) {
            _scheduleScrollToFindingMsg();
          }
        } else {
          showCantFindMsg();
        }
      }
    } finally {
      _scrollToFindInFlight = false;
    }
  }

  _onScrollToIndexBySeq(String targetSeq) async {
    // This method called by tongue request jumping to target @ message
    loadingPlace = LoadingPlace.top;
    // const int singleLoadAmount = 40;
    final targetSeqInt = int.tryParse(targetSeq);
    if (targetSeqInt == null) {
      showCantFindMsg();
      loadingPlace = LoadingPlace.none;
      return;
    }
    final msgList = widget.messageList;
    int? lastSeqInt;
    String lastSeq = "";
    for (int i = msgList.length - 1; i >= 0; i--) {
      final currentMsg = msgList[i];
      final seq = currentMsg?.seq;
      final parsedSeq = int.tryParse(seq ?? "");
      if (parsedSeq != null) {
        lastSeq = seq!;
        lastSeqInt = parsedSeq;
        break;
      }
    }
    if (lastSeqInt == null) {
      showCantFindMsg();
      loadingPlace = LoadingPlace.none;
      return;
    }

    if (lastSeqInt <= targetSeqInt) {
      bool isFound = false;
      int targetIndex = 1;
      String? targetMsgID = "";
      for (int i = msgList.length - 1; i >= 0; i--) {
        final currentMsg = msgList[i];
        if (currentMsg?.seq == targetSeq) {
          isFound = true;
          targetMsgID = currentMsg?.msgID;
          targetIndex = -i;
          break;
        }
      }

      if (isFound && targetIndex != 1) {
        findingSeq = "";
        _autoScrollController.scrollToIndex(
          targetIndex,
          preferPosition: AutoScrollPosition.middle,
        );
        _autoScrollController.scrollToIndex(targetIndex,
            preferPosition: AutoScrollPosition.middle);
        if (targetMsgID != null && targetMsgID != "") {
          widget.model.jumpMsgID = targetMsgID;
        }
        loadingPlace = LoadingPlace.none;
      } else {
        showCantFindMsg();
      }
    } else {
      if (maybeHaveMoreMessageForFind) {
        findingSeq = targetSeq;
        int requestCount = lastSeqInt - targetSeqInt;
        maybeHaveMoreMessageForFind = await widget.onLoadMore(
            _getMessageId(widget.messageList.length - 1),
            LoadDirection.previous,
            requestCount,
            lastSeqInt);
      } else {
        showCantFindMsg();
      }
    }
  }

  _onScrollToIndexBegin(V2TimMessage targetMsg) {
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
        _autoScrollController.scrollToIndex(
          targetIndex,
          preferPosition: AutoScrollPosition.end,
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

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final messageList = _visibleMessageList(widget.messageList);
    if (messageList.isEmpty) {
      return Container();
    }

    final globalModel = context.read<TUIChatGlobalModel>();
    final unreadNewMessageCount = globalModel.unreadCountForTongue;
    final loadedRealMessageCount = _realMessageCount(messageList);
    final safeUnreadCount = unreadNewMessageCount > loadedRealMessageCount
        ? loadedRealMessageCount
        : unreadNewMessageCount;
    final shouldShowUnreadMessage = safeUnreadCount > 0;
    final unreadEndPoint = _realUnreadEndPoint(messageList, safeUnreadCount);
    if (unreadNewMessageCount > 20) {
      _scheduleInitialUnreadAnchor(messageList, unreadNewMessageCount);
      _scheduleUnreadTongueMetricsUpdate(messageList, safeUnreadCount);
    } else {
      globalModel.clearUnreadTongueMetrics(_conversationId(), notify: false);
    }
    String getMessageIdentifier(V2TimMessage? message, int index) {
      return _stableMessageListKey(message, index);
    }

    _rebuildListPartitionsIfNeeded(
      messageList: messageList,
      safeUnreadCount: safeUnreadCount,
      unreadEndPoint: unreadEndPoint,
      restoreVersion: globalModel.mediaPreviewRestoreVersion,
      getMessageIdentifier: getMessageIdentifier,
    );
    final unreadMessageList = _cachedUnreadList;
    final readMessageList = _cachedReadList;
    final previousAnchor = _anchorForPreviousLoad(readMessageList);
    final configuredShrinkWrap = widget.mainHistoryListConfig?.shrinkWrap ?? false;
    final unreadCenter = shouldShowUnreadMessage ? _unreadCenterKey : null;
    // Flutter does not allow CustomScrollView to use center together with
    // shrinkWrap. Keep the unread anchor behavior and disable shrinkWrap only
    // for this case to avoid breaking incoming-message rendering.
    final effectiveShrinkWrap = unreadCenter == null ? configuredShrinkWrap : false;

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

    if (findingMsg != null) {
      _scheduleScrollToFindingMsg();
    } else if (findingSeq != "") {
      _onScrollToIndexBySeq(findingSeq);
    }

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Scrollbar(
          controller: _autoScrollController,
          child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth != 0) {
                  return false;
                }
                if (notification is ScrollStartNotification) {
                  globalModel.setChatListUserScrolling(true);
                } else if (notification is ScrollUpdateNotification ||
                    notification is OverscrollNotification) {
                  if (safeUnreadCount > 20) {
                    _scheduleUnreadTongueMetricsUpdate(
                      messageList,
                      safeUnreadCount,
                    );
                  }
                  if (_ignoreScrollLoadPrevious > 0 || _isLoadingPrevious) {
                    return false;
                  }
                  final metrics = notification.metrics;
                  if (metrics.hasPixels &&
                      metrics.hasContentDimensions &&
                      metrics.pixels >= metrics.maxScrollExtent - 160) {
                    _scheduleLoadPrevious(previousAnchor);
                  }
                } else if (notification is ScrollEndNotification) {
                  globalModel.setChatListUserScrolling(false);
                  if (safeUnreadCount > 20) {
                    _scheduleUnreadTongueMetricsUpdate(
                      messageList,
                      safeUnreadCount,
                      force: true,
                    );
                  }
                  if (_ignoreScrollLoadPrevious > 0) {
                    _ignoreScrollLoadPrevious--;
                    return false;
                  }
                  if (!_isLoadingPrevious) {
                    final metrics = notification.metrics;
                    if (metrics.hasPixels &&
                        metrics.hasContentDimensions &&
                        metrics.pixels >= metrics.maxScrollExtent - 320) {
                      _scheduleLoadPrevious(previousAnchor);
                    }
                  }
                }
                return false;
              },
              child: CustomScrollView(
                center: unreadCenter,
                key: widget.mainHistoryListConfig?.key,
                primary: widget.mainHistoryListConfig?.primary,
                physics: (widget.isAllowScroll == false)
                    ? const NeverScrollableScrollPhysics()
                    : widget.mainHistoryListConfig?.physics,
                // padding: widget.mainHistoryListConfig?.padding ?? EdgeInsets.zero,
                // itemExtent: widget.mainHistoryListConfig?.itemExtent,
                // prototypeItem: widget.mainHistoryListConfig?.prototypeItem,
                cacheExtent: widget.mainHistoryListConfig?.cacheExtent ?? 800,
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
                                throttleFunctionWithMsgID(
                                    messageItem?.msgID ?? "",
                                    LoadDirection.latest);
                              }
                              return _buildScrollMessageTile(
                                messageItem,
                                index,
                                globalIndex: _globalIndexMap[
                                    getMessageIdentifier(messageItem, index)],
                              );
                            },
                            childCount: unreadMessageList.length,
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
                                throttleFunction(index, LoadDirection.latest);
                              }
                              return _buildScrollMessageTile(
                                messageItem,
                                index,
                                globalIndex: _globalIndexMap[
                                    getMessageIdentifier(messageItem, index)],
                              );
                            },
                            childCount: readMessageList.length,
                            findChildIndexCallback: (Key key) {
                              final ValueKey<String> valueKey =
                                  key as ValueKey<String>;
                              final index = _readIndexMap[valueKey.value];
                              return index;
                            })),
                  ),
                ],
              )),
        ),
        TIMUIKitHistoryMessageListTongueContainer(
          conversation: widget.conversation,
          model: widget.model,
          messageList: messageList,
          scrollController: _autoScrollController,
          scrollToIndexBySeq: _onScrollToIndexBySeq,
          scrollToFirstUnread: _scrollToFirstUnreadFromTongue,
          groupAtInfoList: widget.groupAtInfoList,
          tongueItemBuilder: widget.tongueItemBuilder,
        ),
        if (loadingPlace == LoadingPlace.top)
          Positioned(
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: const Color(0xFF9EA7B3),
                size: 24,
              ),
            ),
          ),
      ],
    );
  }
}

class _HistoryMessageListSelectorData {
  final List<V2TimMessage?> messageList;
  final int restoreVersion;
  final int messageListRevision;

  const _HistoryMessageListSelectorData({
    required this.messageList,
    required this.restoreVersion,
    required this.messageListRevision,
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

class _VisibleMessageAnchor {
  final String messageId;
  final double leadingOffset;

  const _VisibleMessageAnchor({
    required this.messageId,
    required this.leadingOffset,
  });
}

class _MessageEnterAnimationGate extends StatefulWidget {
  final V2TimMessage message;
  final Widget child;
  final TUIChatGlobalModel globalModel;
  final String stableKey;
  final MessageEnterAnimationParams enterParams;

  const _MessageEnterAnimationGate({
    required this.message,
    required this.child,
    required this.globalModel,
    required this.stableKey,
    required this.enterParams,
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
    return ChatMessageEnterAnimation(
      key: ValueKey(widget.stableKey),
      duration: widget.enterParams.duration,
      slideCurve: widget.enterParams.slideCurve,
      fallbackSlideDistance: widget.enterParams.slideDistance,
      startOpacity: widget.enterParams.startOpacity,
      slideFromInputAnchor: widget.enterParams.slideFromInputAnchor,
      onFinished: _onAnimationFinished,
      child: widget.child,
    );
  }
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
          if (previous.restoreVersion != next.restoreVersion) {
            return true;
          }
          if (previous.messageListRevision != next.messageListRevision) {
            return true;
          }
          if (previous.messageList.length != next.messageList.length) {
            return true;
          }
          return false;
        },
        selector: (context, model) {
          final messageList = model.getMessageList(conversationID) ?? [];
          return _HistoryMessageListSelectorData(
            messageList: messageList,
            restoreVersion: model.mediaPreviewRestoreVersion,
            messageListRevision: model.messageListRevisionFor(conversationID),
          );
        });
  }
}
