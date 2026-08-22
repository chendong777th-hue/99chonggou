import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_at_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_at_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_message_window_policy.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_jitter_diag.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/back_to_bottom_capsule_policy.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/tim_uikit_chat_history_message_list_tongue.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/unread_tongue_policy.dart';

class TIMUIKitHistoryMessageListTongueContainer extends StatefulWidget {
  final Widget Function(void Function(), MessageListTongueType, int)?
      tongueItemBuilder;
  final List<V2TimGroupAtInfo?>? groupAtInfoList;
  final List<V2TimMessage?> messageList;
  /// Returns true only when the @ target was centered (or already on screen).
  final Future<bool> Function(String targetSeq) scrollToIndexBySeq;
  final Future<bool> Function(int unreadCount) scrollToFirstUnread;
  final AutoScrollController scrollController;
  final TUIChatSeparateViewModel model;
  final V2TimConversation conversation;

  /// Open-chat page SSOT for list position; when set, tongue prefers this over
  /// Global notify fan-out for position-only updates.
  final ValueListenable<HistoryMessagePosition>? pageHistoryPosition;

  const TIMUIKitHistoryMessageListTongueContainer({
    Key? key,
    this.tongueItemBuilder,
    this.groupAtInfoList,
    required this.messageList,
    required this.conversation,
    required this.scrollToIndexBySeq,
    required this.scrollToFirstUnread,
    required this.scrollController,
    required this.model,
    this.pageHistoryPosition,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      _TIMUIKitHistoryMessageListTongueContainerState();
}

class _TongueUnreadSelectorData {
  final HistoryMessagePosition messageListPosition;
  final int unreadRemaining;
  final bool unreadBelow;
  final int lockedUnreadCount;
  final bool haveMoreLatestData;

  const _TongueUnreadSelectorData({
    required this.messageListPosition,
    required this.unreadRemaining,
    required this.unreadBelow,
    required this.lockedUnreadCount,
    required this.haveMoreLatestData,
  });
}

class _TIMUIKitHistoryMessageListTongueContainerState
    extends TIMUIKitState<TIMUIKitHistoryMessageListTongueContainer> {
  bool isFinishJumpToAt = false;
  List<V2TimGroupAtInfo?>? groupAtInfoList = [];
  final TUIChatGlobalModel globalModel = serviceLocator<TUIChatGlobalModel>();
  bool isClickShowPrevious = false;
  bool _jumpingToFirstUnread = false;
  bool _entryUnreadCapsuleDismissed = false;
  bool _scrollFrameCallbackScheduled = false;
  ScrollPosition? _scrollEndListenerPosition;
  bool _showScrollToBottomCapsule = false;
  bool _scrollingToBottomInFlight = false;
  bool _userDraggedSinceLastSettle = false;

  /// 用户主动上滑并超出一屏后为 true；贴底后清零。用来区分 list-push 程序滚动。
  bool _userLeftBottomIntentionally = false;
  HistoryMessagePosition? _lastReportedPosition;
  int _entryUnreadCount = 0;
  String _lastTongueDiagnosticState = '';

  /// 「回到底部」仅在离开底部超过约一屏时出现。
  static const double _capsuleShowViewportRatio =
      BackToBottomCapsulePolicy.showViewportRatio;

  /// 隐藏滞后，避免在阈值附近闪烁。
  static const double _capsuleHideViewportRatio =
      BackToBottomCapsulePolicy.hideViewportRatio;
  static const double _bottomEpsilon = BackToBottomCapsulePolicy.bottomEpsilon;
  static const Duration _capsuleFadeDuration = Duration(milliseconds: 160);

  int get _previousUnreadCount {
    final current = widget.conversation.unreadCount ?? 0;
    final frozen = globalModel.unreadCountForTongue;
    if (_entryUnreadCapsuleDismissed) {
      return frozen;
    }
    var result = current > _entryUnreadCount ? current : _entryUnreadCount;
    if (frozen > result) {
      result = frozen;
    }
    return result;
  }

  int _resolveEntryUnreadCount() {
    final current = widget.conversation.unreadCount ?? 0;
    final frozen = globalModel.unreadCountForTongue;
    var result = current > frozen ? current : frozen;
    if (_entryUnreadCount > result) {
      result = _entryUnreadCount;
    }
    return result;
  }

  ScrollPosition? _singleScrollPositionOrNull() {
    if (!widget.scrollController.hasClients ||
        widget.scrollController.positions.length != 1) {
      return null;
    }
    return widget.scrollController.position;
  }

  bool _isProgrammaticScrollToBottomActive() {
    return _scrollingToBottomInFlight ||
        globalModel.isUserScrollToBottomInProgress(widget.model.conversationID);
  }

  void _kickStartScrollToLatest(String conversationID) {
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return;
    }
    final target = position.minScrollExtent;
    final distance = (position.pixels - target).abs();
    if (distance <= 1.0) {
      return;
    }
    final animationMs = (120 + distance * 0.18).clamp(120.0, 260.0).round();
    ChatJitterDiag.logInboundFlow(
      action: 'bottom_capsule_kick_start',
      conv: conversationID,
      extras: <String, Object?>{
        'distance': distance.toStringAsFixed(1),
        'durationMs': animationMs,
      },
    );
    unawaited(
      widget.scrollController
          .animateTo(
            target,
            duration: Duration(milliseconds: animationMs),
            curve: Curves.easeOutCubic,
          )
          .catchError((_) {}),
    );
  }

  Future<void> _scrollToLatestAndDismissUnreadCapsule() async {
    if (_scrollingToBottomInFlight) {
      return;
    }
    _scrollingToBottomInFlight = true;
    final conversationID = widget.model.conversationID;
    ChatJitterDiag.logInboundFlow(
      action: 'bottom_capsule_tap_begin',
      conv: conversationID,
      extras: <String, Object?>{
        'unread': globalModel.unreadCountForTongue,
        'position': globalModel.getMessageListPosition(conversationID).name,
      },
    );
    try {
      // Keep incoming messages visible for the whole return transaction. If
      // they are routed back into the away-from-bottom buffer, the target
      // keeps changing and continuous traffic can prevent this action from
      // ever reaching the latest row.
      globalModel.beginUserScrollToBottom(
        conversationID,
        lockMilliseconds: 2000,
      );
      if (mounted) {
        setState(() {
          _showScrollToBottomCapsule = false;
          _userLeftBottomIntentionally = false;
          isClickShowPrevious = false;
        });
      }
      _kickStartScrollToLatest(conversationID);

      // 内存窗口开启时，「回到底部」必须重拉最新一页。
      // 仅 animateTo(minExtent) 只会停在窗口内的假底部。
      if (ChatMessageWindowPolicy.enabled) {
        globalModel.beginUserScrollToBottom(
          conversationID,
          lockMilliseconds: 8000,
        );
        ChatJitterDiag.logInboundFlow(
          action: 'bottom_capsule_reload_newest_start',
          conv: conversationID,
          extras: <String, Object?>{
            'listLen': globalModel.rawMessageCount(conversationID),
            'missingNewer':
                globalModel.memoryWindowMissingNewer(conversationID),
          },
        );
        try {
          await widget.model.reloadNewestMessageWindow();
        } catch (e) {
          ChatJitterDiag.logInboundFlow(
            action: 'bottom_capsule_reload_newest_error',
            conv: conversationID,
            extras: <String, Object?>{'error': e.toString()},
          );
        }
        await WidgetsBinding.instance.endOfFrame;
        ChatJitterDiag.logInboundFlow(
          action: 'bottom_capsule_reload_newest_done',
          conv: conversationID,
          extras: <String, Object?>{
            'listLen': globalModel.rawMessageCount(conversationID),
            'missingNewer':
                globalModel.memoryWindowMissingNewer(conversationID),
          },
        );
      }

      // Reveal deferred rows before resolving the bottom scroll target. Doing
      // this after the scroll uses the old list extent and can leave the newly
      // revealed rows below the viewport. A notification is required because
      // projection-only reveals do not otherwise rebuild the message list.
      globalModel.flushDeferredIncomingMessages(
        conversationID,
        notify: true,
        userInitiated: true,
      );
      await WidgetsBinding.instance.endOfFrame;

      // Flushing 5 displayed unread rows can expose 20 authoritative rows, and
      // more may arrive while scrolling. Re-resolve the latest edge after each
      // layout instead of animating once toward a stale geometry snapshot.
      const maxSettleAttempts = 6;
      for (var attempt = 0; attempt < maxSettleAttempts; attempt++) {
        await WidgetsBinding.instance.endOfFrame;
        final position = _singleScrollPositionOrNull();
        if (position == null ||
            !position.hasPixels ||
            !position.hasContentDimensions) {
          break;
        }
        final target = position.minScrollExtent;
        final distance = (position.pixels - target).abs();
        ChatJitterDiag.logInboundFlow(
          action: 'bottom_capsule_settle_attempt',
          conv: conversationID,
          extras: <String, Object?>{
            'attempt': attempt + 1,
            'distance': distance.toStringAsFixed(1),
            'pixels': position.pixels.toStringAsFixed(1),
            'target': target.toStringAsFixed(1),
            'unread': globalModel.unreadCountForTongue,
            'queue': globalModel.pendingInboundProjectionCount(conversationID),
          },
        );
        if (distance <= 1.0) {
          // Require another completed frame at the edge. This catches rows
          // whose real height replaces a text/media placeholder one frame late.
          await WidgetsBinding.instance.endOfFrame;
          final verification = _singleScrollPositionOrNull();
          if (verification != null &&
              verification.hasPixels &&
              verification.hasContentDimensions &&
              (verification.pixels - verification.minScrollExtent).abs() <=
                  _bottomEpsilon) {
            break;
          }
          continue;
        }
        final animationMs = (180 + distance * 0.28).clamp(180.0, 420.0).round();
        globalModel.beginUserScrollToBottom(
          conversationID,
          lockMilliseconds: animationMs + 500,
        );
        try {
          await widget.scrollController.animateTo(
            target,
            duration: Duration(milliseconds: animationMs),
            curve: Curves.easeOutCubic,
          );
        } catch (_) {}
      }

      // A continuous stream can invalidate every animated attempt. Finish with
      // one frame-aligned edge correction while the return-to-bottom lock is
      // still active; subsequent inbound rows then remain pinned naturally.
      await WidgetsBinding.instance.endOfFrame;
      final finalPosition = _singleScrollPositionOrNull();
      if (finalPosition != null &&
          finalPosition.hasPixels &&
          finalPosition.hasContentDimensions &&
          (finalPosition.pixels - finalPosition.minScrollExtent).abs() > 1.0) {
        widget.scrollController.jumpTo(finalPosition.minScrollExtent);
        await WidgetsBinding.instance.endOfFrame;
      }

      final settledPosition = _singleScrollPositionOrNull();
      final reachedBottom = settledPosition != null &&
          settledPosition.hasPixels &&
          settledPosition.hasContentDimensions &&
          (settledPosition.pixels - settledPosition.minScrollExtent).abs() <=
              _bottomEpsilon;
      if (!reachedBottom) {
        ChatJitterDiag.logInboundFlow(
          action: 'bottom_capsule_tap_not_reached',
          conv: conversationID,
          extras: <String, Object?>{
            'pixels': settledPosition?.hasPixels == true
                ? settledPosition!.pixels.toStringAsFixed(1)
                : 'n/a',
            'minExtent': settledPosition?.hasContentDimensions == true
                ? settledPosition!.minScrollExtent.toStringAsFixed(1)
                : 'n/a',
            'queue': globalModel.pendingInboundProjectionCount(conversationID),
          },
        );
        if (mounted) {
          setState(() {
            _showScrollToBottomCapsule = true;
          });
        }
        return;
      }

      globalModel.unlockEntryUnreadForTongue(
        conversationID: conversationID,
        notify: false,
      );
      globalModel.clearReceivedUnreadState(
        conversationID: conversationID,
        notify: false,
      );
      widget.model.markMessageAsRead(force: true);

      var dismissedUnreadCount = _entryUnreadCount;
      if (globalModel.unreadCountForTongue > dismissedUnreadCount) {
        dismissedUnreadCount = globalModel.unreadCountForTongue;
      }
      final currentRemaining =
          globalModel.getUnreadTongueRemaining(conversationID);
      if (currentRemaining > dismissedUnreadCount) {
        dismissedUnreadCount = currentRemaining;
      }
      globalModel.markEntryUnreadTongueDismissed(
        conversationID: conversationID,
        unreadCount: dismissedUnreadCount,
        notify: false,
      );
      globalModel.clearUnreadTongueMetrics(
        conversationID,
        notify: false,
      );
      changePositionState(HistoryMessagePosition.bottom);
      ChatJitterDiag.logInboundFlow(
        action: 'bottom_capsule_tap_complete',
        conv: conversationID,
        extras: <String, Object?>{
          'dismissedUnread': dismissedUnreadCount,
          'queue': globalModel.pendingInboundProjectionCount(conversationID),
        },
      );
      if (mounted) {
        setState(() {
          _entryUnreadCapsuleDismissed = true;
          _entryUnreadCount = 0;
          _showScrollToBottomCapsule = false;
        });
      }
    } finally {
      globalModel.endUserScrollToBottom(conversationID);
      _scrollingToBottomInFlight = false;
    }
  }

  Future<void> _jumpToFirstUnreadMessage(int unreadCount) async {
    if (_jumpingToFirstUnread) {
      return;
    }
    _jumpingToFirstUnread = true;
    try {
      final didScroll = await widget.scrollToFirstUnread(unreadCount);
      if (!didScroll) {
        return;
      }
      // 点过入口「xxx条未读」后：提示立刻消失；离底时底部只保留「回到底部」，
      // 不再把同一批入口未读改成右下角「xxx条新消息」。
      final conversationID = widget.model.conversationID;
      var dismissedUnreadCount = unreadCount;
      if (_entryUnreadCount > dismissedUnreadCount) {
        dismissedUnreadCount = _entryUnreadCount;
      }
      if (globalModel.unreadCountForTongue > dismissedUnreadCount) {
        dismissedUnreadCount = globalModel.unreadCountForTongue;
      }
      final remaining = globalModel.getUnreadTongueRemaining(conversationID);
      if (remaining > dismissedUnreadCount) {
        dismissedUnreadCount = remaining;
      }
      globalModel.unlockEntryUnreadForTongue(
        conversationID: conversationID,
        notify: false,
      );
      globalModel.clearReceivedUnreadState(
        conversationID: conversationID,
        notify: false,
      );
      globalModel.markEntryUnreadTongueDismissed(
        conversationID: conversationID,
        unreadCount: dismissedUnreadCount,
        notify: false,
      );
      globalModel.clearUnreadTongueMetrics(
        conversationID,
        notify: false,
      );
      changePositionState(HistoryMessagePosition.awayTwoScreen);
      if (mounted) {
        setState(() {
          isClickShowPrevious = true;
          _entryUnreadCapsuleDismissed = true;
          _entryUnreadCount = 0;
        });
      } else {
        isClickShowPrevious = true;
        _entryUnreadCapsuleDismissed = true;
        _entryUnreadCount = 0;
      }
    } finally {
      _jumpingToFirstUnread = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _entryUnreadCount = _resolveEntryUnreadCount();
    _attachScrollListeners();
    groupAtInfoList = widget.groupAtInfoList?.reversed.toList();
  }

  @override
  void didUpdateWidget(
      covariant TIMUIKitHistoryMessageListTongueContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model.conversationID != widget.model.conversationID) {
      _detachScrollEndListener();
      isClickShowPrevious = false;
      _jumpingToFirstUnread = false;
      _entryUnreadCapsuleDismissed = false;
      _entryUnreadCount = _resolveEntryUnreadCount();
      _lastReportedPosition = null;
      _lastTongueDiagnosticState = '';
      _showScrollToBottomCapsule = false;
      _userLeftBottomIntentionally = false;
      groupAtInfoList = widget.groupAtInfoList?.reversed.toList();
      _attachScrollListeners();
      return;
    }
    final resolvedEntryUnread = _resolveEntryUnreadCount();
    if (resolvedEntryUnread > _entryUnreadCount) {
      _entryUnreadCount = resolvedEntryUnread;
    }
  }

  void changePositionState(HistoryMessagePosition newPosition) {
    if (_lastReportedPosition == newPosition) {
      return;
    }
    if (globalModel.getMessageListPosition(widget.model.conversationID) !=
        newPosition) {
      globalModel.setMessageListPosition(
          widget.model.conversationID, newPosition);
      _lastReportedPosition = newPosition;
    }
  }

  double _distanceFromBottom(ScrollPosition position) {
    return position.pixels - position.minScrollExtent;
  }

  double _oneScreenThreshold(ScrollPosition position) {
    final viewport = position.viewportDimension;
    if (viewport <= 0) {
      return 600.0;
    }
    return viewport * _capsuleShowViewportRatio;
  }

  bool _hasScrolledPastDistanceThreshold(ScrollPosition position) {
    return _distanceFromBottom(position) > _oneScreenThreshold(position);
  }

  bool _computeScrollToBottomCapsuleVisible(ScrollPosition position) {
    if (globalModel
        .isInboundPresentationBottomLocked(widget.model.conversationID)) {
      return false;
    }
    if (_isProgrammaticScrollToBottomActive()) {
      return false;
    }
    if (widget.model.isLoadingChatHistory || widget.messageList.length <= 1) {
      return false;
    }
    final distance = _distanceFromBottom(position);
    final viewport = position.viewportDimension;
    final showThreshold = _oneScreenThreshold(position);
    final hideThreshold = viewport > 0
        ? viewport * _capsuleHideViewportRatio
        : showThreshold * _capsuleHideViewportRatio;

    if (distance <= _bottomEpsilon) {
      _userLeftBottomIntentionally = false;
      // 窗口假底部：列表贴底，但更新消息还没加载，仍要给返回入口。
      return widget.model.haveMoreLatestData;
    }

    // list-push 程序滚动也会离底，但没有用户手势；正常上推不能点亮按钮。
    // 唯一例外是消息爆发保护主动冻结在一屏外：此时必须给用户返回入口。
    final burstFrozenBeyondOneScreen =
        globalModel.getMessageListPosition(widget.model.conversationID) ==
                HistoryMessagePosition.awayTwoScreen &&
            distance > showThreshold;
    if (burstFrozenBeyondOneScreen) {
      _userLeftBottomIntentionally = true;
    }
    if (globalModel.isChatListUserScrolling || _userDraggedSinceLastSettle) {
      if (distance > showThreshold) {
        _userLeftBottomIntentionally = true;
      }
    }

    if (!_userLeftBottomIntentionally) {
      return false;
    }
    if (_showScrollToBottomCapsule) {
      return distance > hideThreshold;
    }
    return distance > showThreshold;
  }

  HistoryMessagePosition _resolveScrollPositionSettled(double offset) {
    if (globalModel
        .isInboundPresentationBottomLocked(widget.model.conversationID)) {
      return HistoryMessagePosition.bottom;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null) {
      return globalModel.getMessageListPosition(widget.model.conversationID);
    }
    if (offset <= position.minScrollExtent + _bottomEpsilon &&
        !position.outOfRange &&
        !widget.model.haveMoreLatestData) {
      return HistoryMessagePosition.bottom;
    }
    if (!position.outOfRange) {
      if (_hasScrolledPastDistanceThreshold(position)) {
        return HistoryMessagePosition.awayTwoScreen;
      }
      if (offset > position.minScrollExtent + _bottomEpsilon) {
        return HistoryMessagePosition.inTwoScreen;
      }
    }
    return globalModel.getMessageListPosition(widget.model.conversationID);
  }

  void _setScrollToBottomCapsuleVisible(bool nextVisible) {
    if (_showScrollToBottomCapsule == nextVisible || !mounted) {
      return;
    }
    setState(() {
      _showScrollToBottomCapsule = nextVisible;
    });
  }

  void _applyScrollTick() {
    if (_isProgrammaticScrollToBottomActive() ||
        globalModel
            .isInboundPresentationBottomLocked(widget.model.conversationID)) {
      _setScrollToBottomCapsuleVisible(false);
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null) {
      return;
    }
    if (globalModel.isChatListUserScrolling) {
      _userDraggedSinceLastSettle = true;
    }
    _setScrollToBottomCapsuleVisible(
      _computeScrollToBottomCapsuleVisible(position),
    );
  }

  void _maybeMarkLatestUnreadOnSettle(double offset) {
    final position = _singleScrollPositionOrNull();
    final reachedBottomByUser =
        (_userDraggedSinceLastSettle || globalModel.isChatListUserScrolling) &&
            position != null &&
            offset <= position.minScrollExtent + _bottomEpsilon;
    _userDraggedSinceLastSettle = false;
    if (reachedBottomByUser) {
      globalModel.flushDeferredIncomingMessages(
        widget.model.conversationID,
        notify: true,
        userInitiated: true,
      );
      globalModel.unlockEntryUnreadForTongue(
        conversationID: widget.model.conversationID,
        notify: false,
      );
      globalModel.clearReceivedUnreadState(
        conversationID: widget.model.conversationID,
        notify: false,
      );
      widget.model.markMessageAsRead(force: true);
      return;
    }
    final conversationUnreadCount = widget.model.getConversationUnreadCount();
    final shouldKeepEntryUnreadCapsule =
        (globalModel.hasLockedEntryUnreadFor(widget.model.conversationID) ||
                _previousUnreadCount > 0) &&
            !isClickShowPrevious;
    if (offset > 0.0 ||
        conversationUnreadCount == 0 ||
        globalModel.isChatListUserScrolling ||
        shouldKeepEntryUnreadCapsule ||
        globalModel.hasLockedEntryUnreadFor(widget.model.conversationID)) {
      return;
    }
    globalModel.unlockEntryUnreadForTongue(
      conversationID: widget.model.conversationID,
      notify: false,
    );
    globalModel.flushDeferredIncomingMessages(
      widget.model.conversationID,
      notify: false,
    );
    globalModel.clearReceivedUnreadState(
      conversationID: widget.model.conversationID,
      notify: false,
    );
    widget.model.markMessageAsRead(force: true);
  }

  void _applyScrollSettledState() {
    if (!mounted || _isProgrammaticScrollToBottomActive()) {
      return;
    }
    if (globalModel
        .isInboundPresentationBottomLocked(widget.model.conversationID)) {
      changePositionState(HistoryMessagePosition.bottom);
      _setScrollToBottomCapsuleVisible(false);
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null) {
      return;
    }
    final offset = position.pixels;
    _maybeMarkLatestUnreadOnSettle(offset);
    changePositionState(_resolveScrollPositionSettled(offset));
    _setScrollToBottomCapsuleVisible(
      _computeScrollToBottomCapsuleVisible(position),
    );
  }

  void _onScrollingActivityChanged() {
    final position = _scrollEndListenerPosition;
    if (position == null || position.isScrollingNotifier.value) {
      return;
    }
    _applyScrollSettledState();
  }

  void _attachScrollEndListener(ScrollPosition position) {
    if (_scrollEndListenerPosition == position) {
      return;
    }
    _detachScrollEndListener();
    _scrollEndListenerPosition = position;
    position.isScrollingNotifier.addListener(_onScrollingActivityChanged);
  }

  void _detachScrollEndListener() {
    _scrollEndListenerPosition?.isScrollingNotifier
        .removeListener(_onScrollingActivityChanged);
    _scrollEndListenerPosition = null;
  }

  void _attachScrollListeners() {
    widget.scrollController.addListener(_onScrollControllerChanged);
    final position = _singleScrollPositionOrNull();
    if (position != null) {
      _attachScrollEndListener(position);
    }
  }

  void _detachScrollListeners() {
    _detachScrollEndListener();
    widget.scrollController.removeListener(_onScrollControllerChanged);
  }

  void _onScrollControllerChanged() {
    final position = _singleScrollPositionOrNull();
    if (position != null) {
      _attachScrollEndListener(position);
    }
    if (_scrollFrameCallbackScheduled) {
      return;
    }
    _scrollFrameCallbackScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _scrollFrameCallbackScheduled = false;
      if (mounted) {
        _applyScrollTick();
      }
    });
  }

  int _resolveDisplayUnreadCount(int unreadRemaining) {
    var result = unreadRemaining;
    final liveUnreadCount = globalModel.unreadCountForTongue;
    if (UnreadTonguePolicy.isLiveNewMessageTongueEnabled(
          unreadCount: liveUnreadCount,
        ) &&
        liveUnreadCount > result) {
      result = liveUnreadCount;
    }
    if (globalModel.hasLockedEntryUnreadFor(widget.model.conversationID)) {
      final locked = globalModel.lockedEntryUnreadCount;
      if (locked > result) {
        result = locked;
      }
    }
    final previous = _previousUnreadCount;
    if (previous > result) {
      result = previous;
    }
    return result;
  }

  MessageListTongueType _getTongueValueType(
    HistoryMessagePosition messageListPosition,
    List<V2TimGroupAtInfo?>? groupAtInfoList, {
    required int unreadRemaining,
    required bool unreadBelow,
  }) {
    if (messageListPosition == HistoryMessagePosition.notShowLatest &&
        globalModel.hasPendingScrollRestore(widget.model.conversationID)) {
      return MessageListTongueType.none;
    }
    if (groupAtInfoList != null &&
        groupAtInfoList.isNotEmpty &&
        !isFinishJumpToAt) {
      if (groupAtInfoList[0]!.atType == 1) {
        return MessageListTongueType.atMe;
      } else {
        return MessageListTongueType.atAll;
      }
    }

    final entryTipActive = !_entryUnreadCapsuleDismissed &&
        !isClickShowPrevious &&
        UnreadTonguePolicy.isEntryUnreadEnabled(
          widget.conversation,
          _resolveDisplayUnreadCount(unreadRemaining),
        ) &&
        (globalModel.hasLockedEntryUnreadFor(widget.model.conversationID) ||
            _previousUnreadCount > 0 ||
            unreadRemaining > 0);

    // 入口「xxx条未读」未点掉前：始终按入口未读处理。
    // 绝不能因上滑把同一批未读改成右下角「xxx条新消息」。
    if (entryTipActive) {
      return MessageListTongueType.showPrevious;
    }

    final liveUnreadCount = globalModel.unreadCountForTongue;
    if (UnreadTonguePolicy.isLiveNewMessageTongueEnabled(
          unreadCount: liveUnreadCount,
        ) &&
        liveUnreadCount > 0 &&
        messageListPosition != HistoryMessagePosition.bottom) {
      return MessageListTongueType.showUnread;
    }

    return MessageListTongueType.none;
  }

  MessageListTongueType _bottomCapsuleTypeWhenScrolledUp(
    MessageListTongueType valueType,
  ) {
    // 入口未读 tip 还在 / 已点过：离底只显示「回到底部」。
    if (isClickShowPrevious ||
        _entryUnreadCapsuleDismissed ||
        valueType == MessageListTongueType.showPrevious) {
      return MessageListTongueType.toLatest;
    }
    if (valueType == MessageListTongueType.showUnread) {
      return valueType;
    }
    return MessageListTongueType.toLatest;
  }

  Future<void> _onBottomCapsuleTap(
    MessageListTongueType bottomType,
    int unreadCount,
  ) async {
    if (bottomType == MessageListTongueType.showPrevious) {
      await _jumpToFirstUnreadMessage(unreadCount);
      return;
    }
    await _scrollToLatestAndDismissUnreadCapsule();
  }

  Widget _buildTongue({
    required MessageListTongueType valueType,
    required int previousCount,
    required int unreadCount,
    required VoidCallback onClick,
    String atNum = '',
  }) {
    return TIMUIKitHistoryMessageListTongue(
      previousCount: previousCount,
      tongueItemBuilder: widget.tongueItemBuilder,
      unreadCount: unreadCount,
      onClick: onClick,
      atNum: atNum,
      valueType: valueType,
    );
  }

  Widget _buildBottomCapsule({
    required bool visible,
    required MessageListTongueType valueType,
    required int displayUnreadCount,
    required Future<void> Function() onTap,
    required String atNum,
  }) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: _capsuleFadeDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 0.25),
          duration: _capsuleFadeDuration,
          curve: Curves.easeOutCubic,
          child: SafeArea(
            top: false,
            left: false,
            child: _buildTongue(
              previousCount: displayUnreadCount,
              unreadCount: displayUnreadCount,
              onClick: () {
                onTap();
              },
              atNum: atNum,
              valueType: valueType,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detachScrollListeners();
    super.dispose();
  }

  Widget _buildTongueSelector({HistoryMessagePosition? pagePosition}) {
    return Selector<TUIChatGlobalModel, _TongueUnreadSelectorData>(
      builder: (context, selectorData, child) {
        final unreadRemaining = selectorData.unreadRemaining;
        final presentationBottomLocked = globalModel
            .isInboundPresentationBottomLocked(widget.model.conversationID);
        final logicalPosition = presentationBottomLocked
            ? HistoryMessagePosition.bottom
            : selectorData.messageListPosition;
        final valueType = _getTongueValueType(
          logicalPosition,
          groupAtInfoList,
          unreadRemaining: unreadRemaining,
          unreadBelow: selectorData.unreadBelow,
        );
        final displayUnreadCount = _resolveDisplayUnreadCount(unreadRemaining);
        final isAtTongue = valueType == MessageListTongueType.atMe ||
            valueType == MessageListTongueType.atAll;
        final isEntryUnreadTip = valueType == MessageListTongueType.showPrevious;
        // 入口未读：右上角保持「xxx条未读」，上滑也不改成「新消息」。
        // 贴底或轻离底都可点；真正离开底部时右下角另给「回到底部」。
        final showEntryUnreadAtTop = isEntryUnreadTip && !isAtTongue;
        final scrolledUpBottomType =
            _bottomCapsuleTypeWhenScrolledUp(valueType);
        final livePosition = _singleScrollPositionOrNull();
        final physicallyAtBottom = livePosition != null &&
            livePosition.hasPixels &&
            livePosition.hasContentDimensions &&
            BackToBottomCapsulePolicy.isPhysicallyAtBottom(
              _distanceFromBottom(livePosition),
            );
        // 跟真实滚动距离，不跟过期的逻辑贴底位。否则人已经在底部了按钮还亮。
        final showScrolledUpBottomCapsule = !isAtTongue &&
            BackToBottomCapsulePolicy.shouldShow(
              physicallyAtBottom: physicallyAtBottom,
              leftBottomByOneScreen: _showScrollToBottomCapsule,
              missingNewerThanViewport: selectorData.haveMoreLatestData,
              presentationBottomLocked: presentationBottomLocked,
              programmaticScrollToBottom:
                  _isProgrammaticScrollToBottomActive(),
            );
        final diagnosticState = '${valueType.name}|'
            '${selectorData.messageListPosition.name}|'
            '$displayUnreadCount|$showEntryUnreadAtTop|'
            '$showScrolledUpBottomCapsule';
        if (_lastTongueDiagnosticState != diagnosticState) {
          _lastTongueDiagnosticState = diagnosticState;
          final position = _singleScrollPositionOrNull();
          ChatJitterDiag.logInboundFlow(
            action: 'tongue_state',
            conv: widget.model.conversationID,
            extras: <String, Object?>{
              'type': valueType.name,
              'bottomType': scrolledUpBottomType.name,
              'logicalPosition': logicalPosition.name,
              'rawLogicalPosition': selectorData.messageListPosition.name,
              'displayUnread': displayUnreadCount,
              'remaining': unreadRemaining,
              'entryTopVisible': showEntryUnreadAtTop,
              'bottomVisible': showScrolledUpBottomCapsule,
              'presentationLocked':
                  globalModel.isInboundPresentationBottomLocked(
                      widget.model.conversationID),
              'pixels': position?.hasPixels == true
                  ? position!.pixels.toStringAsFixed(1)
                  : 'n/a',
              'minExtent': position?.hasContentDimensions == true
                  ? position!.minScrollExtent.toStringAsFixed(1)
                  : 'n/a',
            },
          );
        }
        final atNum = groupAtInfoList?.length.toString() ?? '';
        return SizedBox.expand(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isAtTongue)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.15,
                  right: 0,
                  child: _buildTongue(
                    previousCount: displayUnreadCount,
                    unreadCount: displayUnreadCount,
                    onClick: () async {
                      if (groupAtInfoList == null ||
                          groupAtInfoList!.isEmpty) {
                        return;
                      }
                      final atInfo = groupAtInfoList![0];
                      final seq = atInfo?.seq;
                      if (seq == null || seq.trim().isEmpty) {
                        return;
                      }
                      final ok = await widget.scrollToIndexBySeq(seq);
                      if (!mounted || !ok) {
                        return;
                      }
                      setState(() {
                        if (groupAtInfoList!.length <= 1) {
                          groupAtInfoList = [];
                          isFinishJumpToAt = true;
                        } else {
                          groupAtInfoList!.removeAt(0);
                        }
                      });
                    },
                    atNum: atNum,
                    valueType: valueType,
                  ),
                ),
              if (showEntryUnreadAtTop)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.15,
                  right: 0,
                  child: _buildTongue(
                    previousCount: displayUnreadCount,
                    unreadCount: displayUnreadCount,
                    onClick: () {
                      _jumpToFirstUnreadMessage(displayUnreadCount);
                    },
                    atNum: atNum,
                    valueType: MessageListTongueType.showPrevious,
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 16,
                child: _buildBottomCapsule(
                  visible: showScrolledUpBottomCapsule,
                  valueType: scrolledUpBottomType ==
                          MessageListTongueType.showPrevious
                      ? MessageListTongueType.toLatest
                      : scrolledUpBottomType,
                  displayUnreadCount: displayUnreadCount,
                  onTap: () => _onBottomCapsuleTap(
                    scrolledUpBottomType == MessageListTongueType.showPrevious
                        ? MessageListTongueType.toLatest
                        : scrolledUpBottomType,
                    displayUnreadCount,
                  ),
                  atNum: atNum,
                ),
              ),
            ],
          ),
        );
      },
      selector: (c, model) {
        final conversationID = widget.model.conversationID;
        return _TongueUnreadSelectorData(
          messageListPosition:
              pagePosition ?? model.getMessageListPosition(conversationID),
          unreadRemaining: model.getUnreadTongueRemaining(conversationID),
          unreadBelow: model.getUnreadTongueBelow(conversationID),
          lockedUnreadCount: model.hasLockedEntryUnreadFor(conversationID)
              ? model.lockedEntryUnreadCount
              : 0,
          haveMoreLatestData: widget.model.haveMoreLatestData,
        );
      },
      shouldRebuild: (previous, next) =>
          previous.messageListPosition != next.messageListPosition ||
          previous.unreadRemaining != next.unreadRemaining ||
          previous.unreadBelow != next.unreadBelow ||
          previous.lockedUnreadCount != next.lockedUnreadCount ||
          previous.haveMoreLatestData != next.haveMoreLatestData,
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final pageHistory = widget.pageHistoryPosition;
    if (pageHistory == null) {
      return _buildTongueSelector();
    }
    return ValueListenableBuilder<HistoryMessagePosition>(
      valueListenable: pageHistory,
      builder: (context, pagePosition, _) {
        return _buildTongueSelector(pagePosition: pagePosition);
      },
    );
  }
}
