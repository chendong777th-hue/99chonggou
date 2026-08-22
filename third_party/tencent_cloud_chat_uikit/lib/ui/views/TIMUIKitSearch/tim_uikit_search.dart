import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_indicator.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_result_item.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_result_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/picker_user_filter.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_search_friend.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_input.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_search_group.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_search_msg.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_search_not_support.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';

typedef TIMUIKitSearchBarBuilder = Widget Function(
  BuildContext context, {
  required FocusNode focusNode,
  required TextEditingController controller,
  required ValueChanged<String> onChanged,
  bool? isAutoFocus,
});

typedef TIMUIKitSearchEmptyBuilder = Widget Function(
  BuildContext context, {
  required bool hasKeyword,
  required bool isLoading,
});

class TIMUIKitSearch extends StatefulWidget {
  /// the callback after clicking the conversation item
  final Function(V2TimConversation, V2TimMessage?) onTapConversation;

  /// [Deprecated] : You are supposed to use [TIMUIKitSearchMsgDetail],
  /// if you tend to search inside a specific conversation, includes c2c and group.
  final V2TimConversation? conversation;

  /// [Deprecated] : You are supposed to use [onEnterSearchInConversation],
  /// though the effects are the same.
  final Function(V2TimConversation conversation, String initKeyword)? onEnterConversation;

  /// On click each conversation from 'Chat history' and searching for historical message in it.
  final Function(V2TimConversation conversation, String initKeyword)? onEnterSearchInConversation;

  final VoidCallback? onBack;

  final bool? isAutoFocus;

  /// 自定义搜索条（如应用内统一的 [AppSearchBar] 样式）。
  final TIMUIKitSearchBarBuilder? searchBarBuilder;

  /// 联系人搜索结果副标题（最近在线文案）。
  final MemberPresenceLabelBuilder? friendPresenceLabelBuilder;

  final MemberPresenceLoadingChecker? friendPresenceLoadingChecker;

  final void Function(List<String> userIds)? onFriendListLoaded;

  /// 业务侧在线状态刷新时触发列表重建（如 [ChangeNotifier]）。
  final Listenable? friendPresenceListenable;

  /// 无搜索结果 / 未输入关键词时的占位（插画 + 描述）。
  final TIMUIKitSearchEmptyBuilder? emptyStateBuilder;

  /// 页面被聊天页等上层路由遮挡时暂停联系人在线状态刷新，减轻返回卡顿。
  final bool pauseFriendPresenceUpdates;

  /// 点击「全部联系人」：由宿主打开独立虚拟列表页，禁止在首页原地展开。
  final ValueChanged<String>? onShowAllFriends;

  /// 点击「全部群聊」：由宿主打开独立虚拟列表页，禁止在首页原地展开。
  final ValueChanged<String>? onShowAllGroups;

  const TIMUIKitSearch(
      {required this.onTapConversation,
      Key? key,
      @Deprecated(
          "You are supposed to use [TIMUIKitSearchMsgDetail], if you tend to search inside a specific conversation, includes c2c and group")
      this.conversation,
      @Deprecated("You are supposed to use [onEnterSearchInConversation], though the effects are the same.")
      this.onEnterConversation,
      this.isAutoFocus = true,
      this.onEnterSearchInConversation,
      this.onBack,
      this.searchBarBuilder,
      this.friendPresenceLabelBuilder,
      this.friendPresenceLoadingChecker,
      this.onFriendListLoaded,
      this.friendPresenceListenable,
      this.emptyStateBuilder,
      this.pauseFriendPresenceUpdates = false,
      this.onShowAllFriends,
      this.onShowAllGroups})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => TIMUIKitSearchState();
}

class TIMUIKitSearchState extends TIMUIKitState<TIMUIKitSearch> {
  late TextEditingController textEditingController = TextEditingController();
  final model = serviceLocator<TUISearchViewModel>();
  final FocusNode focusNode = FocusNode();
  GlobalKey<dynamic> inputTextField = GlobalKey();
  List<SearchType> searchTypes = [SearchType.group, SearchType.contact, SearchType.history];

  bool _hasVisibleFriendResults(
    List<V2TimFriendInfoResult> friends,
    List<V2TimConversation?> conversations,
  ) {
    return friends.any((friend) {
      if (shouldHideUserFromPickers(friend.friendInfo?.userID)) {
        return false;
      }
      final userId = friend.friendInfo?.userID?.trim() ?? '';
      return userId.isNotEmpty;
    });
  }

  bool _hasVisibleGroupResults(
    List<V2TimGroupInfo> groups,
    List<V2TimConversation?> conversations,
  ) {
    return groups.any((group) => group.groupID.trim().isNotEmpty);
  }

  bool _hasVisibleMsgResults(
    List<V2TimMessageSearchResultItem?> msgList,
    List<V2TimConversation?> conversations,
  ) {
    return msgList.any((item) {
      final id = item?.conversationID?.trim() ?? '';
      return id.isNotEmpty;
    });
  }

  bool _hasVisibleSearchResults({
    required List<V2TimFriendInfoResult> friendResultList,
    required List<V2TimGroupInfo> groupList,
    required List<V2TimMessageSearchResultItem?> msgList,
    required List<V2TimConversation?> conversationList,
  }) {
    if (searchTypes.contains(SearchType.contact) &&
        _hasVisibleFriendResults(friendResultList, conversationList)) {
      return true;
    }
    if (searchTypes.contains(SearchType.group) &&
        _hasVisibleGroupResults(groupList, conversationList)) {
      return true;
    }
    if (searchTypes.contains(SearchType.history) &&
        _hasVisibleMsgResults(msgList, conversationList)) {
      return true;
    }
    return false;
  }

  Widget _buildDefaultEmptyState(
    BuildContext context,
    TUIKitBuildValue value, {
    required bool hasKeyword,
  }) {
    final theme = value.theme;
    final textColor = theme.weakTextColor ?? const Color(0xFF999999);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 72,
              color: textColor.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              '无搜索结果',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: textColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    model.initSearch(notify: false);
    unawaited(model.warmGlobalSearchContext());
    if (widget.isAutoFocus ?? true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          focusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    if (PlatformUtils().isWeb) {
      return TIMUIKitSearchNotSupport(onBack: widget.onBack);
    }
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: serviceLocator<TUISearchViewModel>())],
      child: GestureDetector(
        onTap: () {
          FocusScopeNode currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
          }
        },
        child: Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              widget.searchBarBuilder != null
                  ? widget.searchBarBuilder!(
                      context,
                      focusNode: focusNode,
                      controller: textEditingController,
                      onChanged: model.searchByKey,
                      isAutoFocus: widget.isAutoFocus,
                    )
                  : TIMUIKitSearchInput(
                      focusNode: focusNode,
                      key: inputTextField,
                      isAutoFocus: widget.isAutoFocus,
                      onChange: (String value) {
                        model.searchByKey(value);
                      },
                      controller: textEditingController,
                      prefixIcon: Icon(
                        Icons.search,
                        size: 16,
                        color: value.theme.weakTextColor ??
                            hexToColor("979797"),
                      ),
                    ),
              Expanded(
                child: Consumer<TUISearchViewModel>(
                  builder: (context, searchModel, _) {
                    final friendResultList = searchModel.friendList ?? [];
                    final msgList = searchModel.msgList ?? [];
                    final groupList = searchModel.groupList ?? [];
                    final conversationList = searchModel.conversationList;
                    final keyword = textEditingController.text.trim();
                    final hasKeyword = keyword.isNotEmpty;
                    final showLoading =
                        searchModel.globalSearchLoading && hasKeyword;
                    final searchFinishedForKeyword = hasKeyword &&
                        !showLoading &&
                        searchModel.completedGlobalSearchKey == keyword;
                    final hasResults = _hasVisibleSearchResults(
                      friendResultList: friendResultList,
                      groupList: groupList,
                      msgList: msgList,
                      conversationList: conversationList,
                    );
                    final showEmpty = searchFinishedForKeyword && !hasResults;
                    final emptyWidget = widget.emptyStateBuilder?.call(
                          context,
                          hasKeyword: true,
                          isLoading: false,
                        ) ??
                        _buildDefaultEmptyState(
                          context,
                          value,
                          hasKeyword: true,
                        );
                    final resultsWidget = SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        children: [
                          if (searchTypes.contains(SearchType.contact))
                            TIMUIKitSearchFriend(
                              onTapConversation: (conversation, message) {
                                focusNode.unfocus();
                                widget.onTapConversation(conversation, message);
                              },
                              friendResultList: friendResultList,
                              friendPresenceLabelBuilder:
                                  widget.friendPresenceLabelBuilder,
                              friendPresenceLoadingChecker:
                                  widget.friendPresenceLoadingChecker,
                              onFriendListLoaded: widget.onFriendListLoaded,
                              presenceListenable:
                                  widget.friendPresenceListenable,
                              pausePresenceUpdates:
                                  widget.pauseFriendPresenceUpdates,
                              onShowAll: () {
                                widget.onShowAllFriends
                                    ?.call(textEditingController.text.trim());
                              },
                            ),
                          if (searchTypes.contains(SearchType.group))
                            TIMUIKitSearchGroup(
                              groupList: groupList,
                              onTapConversation: (conversation, message) {
                                focusNode.unfocus();
                                widget.onTapConversation(conversation, message);
                              },
                              onShowAll: () {
                                widget.onShowAllGroups
                                    ?.call(textEditingController.text.trim());
                              },
                            ),
                          if (searchTypes.contains(SearchType.history))
                            TIMUIKitSearchMsg(
                              onTapConversation: widget.onTapConversation,
                              keyword: keyword,
                              totalMsgCount: searchModel.totalMsgCount,
                              msgList: msgList,
                              onEnterConversation:
                                  (V2TimConversation conversation,
                                      String searchKeyword) {
                                if (widget.onEnterSearchInConversation != null) {
                                  widget.onEnterSearchInConversation!(
                                      conversation, searchKeyword);
                                } else if (widget.onEnterConversation != null) {
                                  widget.onEnterConversation!(
                                      conversation, searchKeyword);
                                }
                              },
                            ),
                        ],
                      ),
                    );
                    final indicator = TIMUIKitSearchIndicator(
                      typeList: searchTypes,
                      onChange: (list) {
                        setState(() {
                          searchTypes = List<SearchType>.from(list);
                        });
                      },
                    );
                    return GestureDetector(
                      onTap: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                        }
                      },
                      child: Column(
                        children: [
                          if (!hasKeyword) indicator,
                          if (hasKeyword && showLoading)
                            const LinearProgressIndicator(minHeight: 2),
                          Expanded(
                            child: !hasKeyword
                                ? const SizedBox.shrink()
                                : showEmpty
                                    ? emptyWidget
                                    : hasResults
                                        ? resultsWidget
                                        : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
