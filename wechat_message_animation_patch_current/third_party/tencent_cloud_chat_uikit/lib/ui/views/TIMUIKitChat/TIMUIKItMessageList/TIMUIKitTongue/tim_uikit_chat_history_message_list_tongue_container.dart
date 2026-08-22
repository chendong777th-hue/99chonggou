import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
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
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'tim_uikit_chat_history_message_list_tongue.dart';
import 'package:tuple/tuple.dart';

class TIMUIKitHistoryMessageListTongueContainer extends StatefulWidget {
  final Widget Function(void Function(), MessageListTongueType, int)? tongueItemBuilder;
  final List<V2TimGroupAtInfo?>? groupAtInfoList;
  final List<V2TimMessage?> messageList;
  final Function(String targetSeq) scrollToIndexBySeq;
  final Future<bool> Function(int unreadCount) scrollToFirstUnread;
  final AutoScrollController scrollController;
  final TUIChatSeparateViewModel model;
  final V2TimConversation conversation;

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
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _TIMUIKitHistoryMessageListTongueContainerState();
}

class _TIMUIKitHistoryMessageListTongueContainerState extends TIMUIKitState<TIMUIKitHistoryMessageListTongueContainer> {
  bool isFinishJumpToAt = false;
  List<V2TimGroupAtInfo?>? groupAtInfoList = [];
  final TUIChatGlobalModel globalModel = serviceLocator<TUIChatGlobalModel>();
  bool isClickShowPrevious = false;
  bool _jumpingToFirstUnread = false;
  bool _entryUnreadCapsuleDismissed = false;
  Timer? _scrollPositionDebounce;
  HistoryMessagePosition? _lastReportedPosition;
  int _entryUnreadCount = 0;

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

  Future<void> _scrollToLatestAndDismissUnreadCapsule() async {
    widget.model.showLatestUnread();
    final position = _singleScrollPositionOrNull();
    if (position != null) {
      await widget.scrollController.animateTo(
        position.minScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
    var dismissedUnreadCount = _entryUnreadCount;
    if (globalModel.unreadCountForTongue > dismissedUnreadCount) {
      dismissedUnreadCount = globalModel.unreadCountForTongue;
    }
    final currentRemaining =
        globalModel.getUnreadTongueRemaining(widget.model.conversationID);
    if (currentRemaining > dismissedUnreadCount) {
      dismissedUnreadCount = currentRemaining;
    }
    globalModel.markEntryUnreadTongueDismissed(
      conversationID: widget.model.conversationID,
      unreadCount: dismissedUnreadCount,
      notify: false,
    );
    globalModel.clearUnreadTongueMetrics(
      widget.model.conversationID,
      notify: false,
    );
    globalModel.setUnreadCountForTongue(0, notify: false);
    globalModel.setMessageListPosition(
      widget.model.conversationID,
      HistoryMessagePosition.bottom,
      notify: true,
    );
    if (mounted) {
      setState(() {
        isClickShowPrevious = false;
        _entryUnreadCapsuleDismissed = true;
        _entryUnreadCount = 0;
      });
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
      globalModel.setMessageListPosition(
        widget.model.conversationID,
        HistoryMessagePosition.awayTwoScreen,
      );
      if (mounted) {
        setState(() {
          isClickShowPrevious = true;
        });
      }
    } finally {
      _jumpingToFirstUnread = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _entryUnreadCount = _resolveEntryUnreadCount();
    initScrollListener();
    groupAtInfoList = widget.groupAtInfoList?.reversed.toList();
  }

  @override
  void didUpdateWidget(covariant TIMUIKitHistoryMessageListTongueContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model.conversationID != widget.model.conversationID) {
      isClickShowPrevious = false;
      _jumpingToFirstUnread = false;
      _entryUnreadCapsuleDismissed = false;
      _entryUnreadCount = _resolveEntryUnreadCount();
      groupAtInfoList = widget.groupAtInfoList?.reversed.toList();
    }
  }

  void changePositionState(HistoryMessagePosition newPosition) {
    if (_lastReportedPosition == newPosition) {
      return;
    }
    if (globalModel.getMessageListPosition(widget.model.conversationID) != newPosition) {
      globalModel.setMessageListPosition(widget.model.conversationID, newPosition);
      _lastReportedPosition = newPosition;
    }
  }

  bool _hasScrolledPastRealMessageCount(int messageCount) {
    final position = _singleScrollPositionOrNull();
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return false;
    }

    int? newestVisibleGlobalIndex;
    for (final entry in widget.scrollController.tagMap.entries) {
      final tagIndex = entry.key;
      if (tagIndex > 0) {
        continue;
      }
      final globalIndex = -tagIndex;
      if (globalIndex < 0 || globalIndex >= widget.messageList.length) {
        continue;
      }
      final message = widget.messageList[globalIndex];
      if (message == null || message.elemType == 11 || message.elemType == 101) {
        continue;
      }

      final tagContext = entry.value.context;
      final renderObject = tagContext?.findRenderObject();
      if (tagContext == null ||
          renderObject is! RenderBox ||
          !renderObject.attached) {
        continue;
      }
      final viewport = RenderAbstractViewport.of(renderObject);
      final leadingOffset =
          viewport.getOffsetToReveal(renderObject, 0).offset - position.pixels;
      final trailingOffset = leadingOffset + renderObject.size.height;
      final isVisible = trailingOffset >= -1 &&
          leadingOffset <= position.viewportDimension + 1;
      if (isVisible &&
          (newestVisibleGlobalIndex == null ||
              globalIndex < newestVisibleGlobalIndex)) {
        newestVisibleGlobalIndex = globalIndex;
      }
    }

    if (newestVisibleGlobalIndex == null) {
      return false;
    }
    var realMessagesBelow = 0;
    for (var i = 0; i < newestVisibleGlobalIndex; i++) {
      final message = widget.messageList[i];
      if (message != null && message.elemType != 11 && message.elemType != 101) {
        realMessagesBelow++;
        if (realMessagesBelow >= messageCount) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasScrolledPastDistanceThreshold(ScrollPosition position) {
    final viewportThreshold = position.viewportDimension * 1.5;
    final threshold = viewportThreshold > 600.0 ? viewportThreshold : 600.0;
    return position.pixels > threshold;
  }

  HistoryMessagePosition _resolveScrollPosition(double offset) {
    final position = _singleScrollPositionOrNull();
    if (position == null) {
      return globalModel.getMessageListPosition(widget.model.conversationID);
    }
    if (offset <= position.minScrollExtent &&
        !position.outOfRange &&
        !widget.model.haveMoreLatestData) {
      return HistoryMessagePosition.bottom;
    }
    if (!position.outOfRange &&
        (_hasScrolledPastRealMessageCount(10) ||
            _hasScrolledPastDistanceThreshold(position))) {
      return HistoryMessagePosition.awayTwoScreen;
    }
    if (offset > 0 && !position.outOfRange) {
      return HistoryMessagePosition.inTwoScreen;
    }
    return globalModel.getMessageListPosition(widget.model.conversationID);
  }

  void _applyScrollPositionState() {
    if (!mounted) {
      return;
    }
    final position = _singleScrollPositionOrNull();
    if (position == null) {
      return;
    }
    final offset = position.pixels;
    final conversationUnreadCount = widget.model.getConversationUnreadCount();
    final shouldKeepEntryUnreadCapsule =
        _previousUnreadCount > 0 && !isClickShowPrevious;
    if (offset <= 0.0 &&
        conversationUnreadCount != 0 &&
        !globalModel.isChatListUserScrolling &&
        !shouldKeepEntryUnreadCapsule) {
      widget.model.showLatestUnread();
    }
    changePositionState(_resolveScrollPosition(offset));
  }


  scrollHandler() {
    _scrollPositionDebounce?.cancel();
    _scrollPositionDebounce = Timer(const Duration(milliseconds: 120), _applyScrollPositionState);
  }

  void initScrollListener() {
    widget.scrollController.addListener(scrollHandler);
  }

  MessageListTongueType _getTongueValueType(
    List<V2TimGroupAtInfo?>? groupAtInfoList, {
    required int unreadRemaining,
    required bool unreadBelow,
  }) {
    if (globalModel.getMessageListPosition(widget.model.conversationID) ==
            HistoryMessagePosition.notShowLatest &&
        globalModel.hasPendingScrollRestore(widget.model.conversationID)) {
      return MessageListTongueType.none;
    }
    if (groupAtInfoList != null && groupAtInfoList.isNotEmpty && !isFinishJumpToAt) {
      if (groupAtInfoList[0]!.atType == 1) {
        return MessageListTongueType.atMe;
      } else {
        return MessageListTongueType.atAll;
      }
    }

    final entryUnreadCount = _previousUnreadCount;
    if (!_entryUnreadCapsuleDismissed &&
        entryUnreadCount > 0 &&
        unreadRemaining > 0) {
      // 进入聊天页后已经自动定位到最早未读，这个胶囊只负责向下回到
      // 最新消息，并显示“下面还剩多少条未读”。
      return MessageListTongueType.showPrevious;
    }

    if (!_entryUnreadCapsuleDismissed &&
        globalModel.unreadCountForTongue > 0 &&
        unreadRemaining > 0) {
      return MessageListTongueType.showUnread;
    }

    return MessageListTongueType.none;
  }

  bool _shouldShowToLatestTongue(HistoryMessagePosition messageListPosition) {
    return messageListPosition == HistoryMessagePosition.awayTwoScreen;
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

  @override
  void dispose() {
    _scrollPositionDebounce?.cancel();
    widget.scrollController.removeListener(scrollHandler);
    super.dispose();
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    return Selector<TUIChatGlobalModel, Tuple3<HistoryMessagePosition, int, bool>>(
      builder: (context, value, child) {
        final unreadRemaining = value.item2;
        final unreadBelow = value.item3;
        final valueType = _getTongueValueType(
          groupAtInfoList,
          unreadRemaining: unreadRemaining,
          unreadBelow: unreadBelow,
        );
        final messageListPosition = value.item1;
        final shouldShowTopTongue = valueType != MessageListTongueType.none;
        final shouldShowBottomTongue = _shouldShowToLatestTongue(messageListPosition);
        return SizedBox.expand(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (shouldShowTopTongue)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.15,
                  right: 0,
                  child: _buildTongue(
                    previousCount: unreadRemaining,
                    unreadCount: unreadRemaining,
                    onClick: () async {
                      if (groupAtInfoList != null && groupAtInfoList!.isNotEmpty) {
                        if (groupAtInfoList?.length == 1) {
                          widget.scrollToIndexBySeq(groupAtInfoList![0]!.seq);

                          setState(() {
                            groupAtInfoList = [];
                            isFinishJumpToAt = true;
                          });
                        } else {
                          widget.scrollToIndexBySeq(groupAtInfoList!.removeAt(0)!.seq);
                        }
                      } else if (valueType == MessageListTongueType.showPrevious ||
                          valueType == MessageListTongueType.showUnread) {
                        await _scrollToLatestAndDismissUnreadCapsule();
                      }
                    },
                    atNum: groupAtInfoList?.length.toString() ?? "",
                    valueType: valueType,
                  ),
                ),
              if (shouldShowBottomTongue)
                Positioned(
                  right: 0,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    left: false,
                    child: _buildTongue(
                      previousCount: 0,
                      unreadCount: 0,
                      onClick: () async {
                        await _scrollToLatestAndDismissUnreadCapsule();
                      },
                      valueType: MessageListTongueType.toLatest,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      selector: (c, model) {
        final conversationID = widget.model.conversationID;
        final messageListPosition = model.getMessageListPosition(conversationID);
        final dynamicUnreadRemaining = model.getUnreadTongueRemaining(conversationID);
        final dynamicUnreadBelow = model.getUnreadTongueBelow(conversationID);
        return Tuple3(
          messageListPosition,
          dynamicUnreadRemaining,
          dynamicUnreadBelow,
        );
      },
    );
  }
}
