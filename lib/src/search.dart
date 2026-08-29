import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/tencent_page.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/self_hosted_friendship_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';

import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/contact_style_search_bar.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/route_visibility.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/ui/widgets/app_cupertino_datetime_sheet.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_last_message.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_mutual_utils.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

Widget _buildSearchEmptyState(
  BuildContext context, {
  required bool hasKeyword,
  required bool isLoading,
}) {
  if (isLoading) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
  if (!hasKeyword) {
    return const SizedBox.shrink();
  }
  final i18n = AppI18n.of(context);
  return AppEmptyState(
    message: i18n.t(
      zhHans: '未找到相关结果',
      zhHant: '未找到相關結果',
      en: 'No results found',
      ja: '該当する結果がありません',
      ko: '관련 결과를 찾을 수 없습니다',
    ),
  );
}

Widget _contactStyleSearchBar(
  BuildContext context, {
  required FocusNode focusNode,
  required TextEditingController controller,
  required ValueChanged<String> onChanged,
  bool? isAutoFocus,
}) {
  return ContactStyleSearchBar(
    controller: controller,
    focusNode: focusNode,
    autofocus: isAutoFocus ?? true,
    onChanged: onChanged,
  );
}

String _searchMemberPresenceLabel(
  BuildContext context,
  String userId,
  bool imOnline,
) {
  final presence = Provider.of<PresenceProvider>(context, listen: false);
  final friendship = serviceLocator<TUIFriendShipViewModel>();
  return presence.listLabelFor(
    userId: userId,
    imOnline: imOnline,
    isMutualFriend: friendCanMessage(friendship, userId),
  );
}

bool _searchMemberPresenceLoading(
  BuildContext context,
  String userId,
  bool imOnline,
) {
  final presence = Provider.of<PresenceProvider>(context, listen: false);
  return presence.isLastSeenLoading(userId: userId, imOnline: imOnline);
}

void _onSearchMemberListLoaded(BuildContext context, List<String> userIds) {
  if (userIds.isEmpty || !RouteVisibility.isRouteVisible(context)) {
    return;
  }
  _SearchPresenceCoordinator.of(context).schedule(userIds);
}

class _SearchPresenceCoordinator {
  _SearchPresenceCoordinator(this._presence);

  final PresenceProvider _presence;
  Timer? _debounce;
  List<String>? _pendingUserIds;

  static _SearchPresenceCoordinator of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SearchPresenceScope>()!
        .coordinator;
  }

  void schedule(List<String> userIds) {
    _pendingUserIds = userIds;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final ids = _pendingUserIds;
      if (ids == null || ids.isEmpty) {
        return;
      }
      _presence.ensure(ids);
    });
  }

  void dispose() {
    _debounce?.cancel();
  }
}

class _SearchPresenceScope extends InheritedWidget {
  const _SearchPresenceScope({
    required this.coordinator,
    required super.child,
  });

  final _SearchPresenceCoordinator coordinator;

  @override
  bool updateShouldNotify(_SearchPresenceScope oldWidget) => false;
}

class Search extends StatefulWidget {
  const Search(
      {Key? key,
      this.isAutoFocus = true,
      this.conversation,
      required this.onTapConversation,
      this.onTapConversationWithMessage,
      this.initKeyword,
      this.onBack})
      : super(key: key);

  /// if assign a specific conversation, it will only search in it; otherwise search globally
  final V2TimConversation? conversation;

  final VoidCallback? onBack;

  /// the callback after clicking the conversation item to specific message in it
  final Function(V2TimConversation, MessageAnchor?) onTapConversation;
  final Function(V2TimConversation, MessageAnchor?, V2TimMessage?)?
      onTapConversationWithMessage;

  /// initial keyword for detail search
  final String? initKeyword;

  final bool? isAutoFocus;

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  _SearchPresenceCoordinator? _presenceCoordinator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _presenceCoordinator ??= _SearchPresenceCoordinator(
      Provider.of<PresenceProvider>(context, listen: false),
    );
  }

  @override
  void dispose() {
    _presenceCoordinator?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final isConversation = (widget.conversation != null);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final appBarBackground = theme.appbarBgColor ??
        theme.chatHeaderBgColor ??
        theme.wideBackgroundColor ??
        Colors.white;
    final appBarTextColor = theme.appbarTextColor ??
        theme.chatHeaderTitleTextColor ??
        theme.darkTextColor ??
        Colors.black;
    final appBarIconColor = theme.primaryColor ??
        theme.chatHeaderBackTextColor ??
        const Color(0xFF1E90FF);
    final pageBackground =
        theme.weakBackgroundColor ?? theme.wideBackgroundColor ?? Colors.white;
    final routeVisible = RouteVisibility.isRouteVisible(context);

    void openNarrowSearchResult(
      V2TimConversation targetConversation,
      MessageAnchor? anchor,
      V2TimMessage? targetMessage,
    ) {
      FocusManager.instance.primaryFocus?.unfocus();
      openOrReuseAppChat(
        context,
        targetConversation,
        initFindingMsg: targetMessage,
        searchJumpAnchor: anchor,
      );
    }

    void handleTapConversation(
      V2TimConversation targetConversation,
      V2TimMessage? targetMessage, {
      VoidCallback? closeWidePopup,
    }) {
      final anchor = targetMessage == null
          ? null
          : MessageAnchor.fromConversationMessage(
              targetConversation,
              targetMessage,
            );

      if (!isWideScreen) {
        openNarrowSearchResult(targetConversation, anchor, targetMessage);
        return;
      }

      closeWidePopup?.call();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final onTapWithMessage = widget.onTapConversationWithMessage;
        if (onTapWithMessage != null) {
          onTapWithMessage(targetConversation, anchor, targetMessage);
        } else {
          widget.onTapConversation(targetConversation, anchor);
        }
      });
    }

    return _SearchPresenceScope(
      coordinator: _presenceCoordinator!,
      child: TencentPage(
          child: Scaffold(
            backgroundColor: pageBackground,
            appBar: isWideScreen
                ? null
                : AppBar(
                    iconTheme: IconThemeData(color: appBarIconColor),
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    surfaceTintColor: Colors.transparent,
                    backgroundColor: appBarBackground,
                    foregroundColor: appBarTextColor,
                    title: Text(
                      isConversation
                          ? (widget.conversation?.showName ??
                              widget.conversation?.conversationID ??
                              i18n.t(
                                zhHans: '相关聊天记录',
                                zhHant: '相關聊天記錄',
                                en: 'Related Chat History',
                                ja: '関連チャット履歴',
                                ko: '관련 채팅 기록',
                              ))
                          : i18n.t(
                              zhHans: '全局搜索',
                              zhHant: '全域搜尋',
                              en: 'Global Search',
                              ja: '全体検索',
                              ko: '전체 검색',
                            ),
                      style: TextStyle(
                        color: appBarTextColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            body: isConversation
                ? TIMUIKitSearchMsgDetail(
                    isAutoFocus: widget.isAutoFocus,
                    currentConversation: widget.conversation!,
                    onTapConversation: handleTapConversation,
                    keyword: widget.initKeyword ?? "",
                    searchBarBuilder: _contactStyleSearchBar,
                    emptyStateBuilder: _buildSearchEmptyState,
                    pickSearchDate: showChatHistoryDatePicker,
                    messageAbstractBuilder: buildReplyAbstractMessage,
                    memberPresenceLabelBuilder: (userId, imOnline) =>
                        _searchMemberPresenceLabel(context, userId, imOnline),
                    memberPresenceLoadingChecker: (userId, imOnline) =>
                        _searchMemberPresenceLoading(context, userId, imOnline),
                    onMemberListLoaded: (userIds) =>
                        _onSearchMemberListLoaded(context, userIds),
                    memberPresenceListenable:
                        Provider.of<PresenceProvider>(context, listen: false),
                  )
                : TIMUIKitSearch(
                    onBack: widget.onBack,
                    isAutoFocus: widget.isAutoFocus,
                    searchBarBuilder: _contactStyleSearchBar,
                    emptyStateBuilder: _buildSearchEmptyState,
                    pauseFriendPresenceUpdates: !routeVisible,
                    friendPresenceLabelBuilder: (userId, imOnline) =>
                        _searchMemberPresenceLabel(context, userId, imOnline),
                    friendPresenceLoadingChecker: (userId, imOnline) =>
                        _searchMemberPresenceLoading(context, userId, imOnline),
                    onFriendListLoaded: (userIds) =>
                        _onSearchMemberListLoaded(context, userIds),
                    friendPresenceListenable:
                        Provider.of<PresenceProvider>(context, listen: false),
                    onShowAllFriends: (keyword) {
                      final searchModel = serviceLocator<TUISearchViewModel>();
                      final friends = List<V2TimFriendInfoResult>.from(
                        searchModel.friendList ?? const [],
                      );
                      final conversations = List<V2TimConversation?>.from(
                        searchModel.conversationList,
                      );
                      final useStore =
                          SelfHostedFriendshipBridge.localSearchEnabled &&
                              keyword.trim().isNotEmpty;
                      Widget page({VoidCallback? closeWidePopup}) {
                        return TIMUIKitSearchFriendAllPage(
                          friendResultList: friends,
                          conversationList: conversations,
                          keyword: keyword,
                          loadMoreFromStore: useStore
                              ? (cursor) async {
                                  final page = await SelfHostedFriendshipBridge
                                      .searchFriendsLocal(
                                    keyword: keyword,
                                    limit: 80,
                                    cursor: cursor,
                                  );
                                  final hydrated =
                                      await SelfHostedFriendshipBridge
                                          .hydrateFriends(page.ids);
                                  final items = hydrated
                                      .map(
                                        (friend) => V2TimFriendInfoResult(
                                          resultCode: 0,
                                          resultInfo: '',
                                          relation: 0,
                                          friendInfo: friend,
                                        ),
                                      )
                                      .toList(growable: false);
                                  return (
                                    items: items,
                                    nextCursor: page.nextCursor,
                                    hasMore: page.hasMore,
                                  );
                                }
                              : null,
                          onTapConversation: (conversation, message) {
                            handleTapConversation(
                              conversation,
                              message,
                              closeWidePopup: closeWidePopup,
                            );
                          },
                          friendPresenceLabelBuilder: (userId, imOnline) =>
                              _searchMemberPresenceLabel(
                                  context, userId, imOnline),
                          friendPresenceLoadingChecker: (userId, imOnline) =>
                              _searchMemberPresenceLoading(
                                  context, userId, imOnline),
                          onFriendListLoaded: (userIds) =>
                              _onSearchMemberListLoaded(context, userIds),
                          presenceListenable: Provider.of<PresenceProvider>(
                            context,
                            listen: false,
                          ),
                        );
                      }

                      if (isWideScreen) {
                        TUIKitWidePopup.showPopupWindow(
                          operationKey: TUIKitWideModalOperationKey.chatHistory,
                          context: context,
                          width: MediaQuery.of(context)
                              .size
                              .width
                              .clamp(520, 720)
                              .toDouble(),
                          height: (MediaQuery.of(context).size.height * 0.72)
                              .clamp(480, 680)
                              .toDouble(),
                          child: (onClose) => page(closeWidePopup: onClose),
                          theme: theme,
                        );
                      } else {
                        Navigator.push(
                          context,
                          AppMaterialPageRoute(
                            builder: (context) => page(),
                            settings: const RouteSettings(
                              name: AppRoutes.searchAllFriends,
                            ),
                          ),
                        );
                      }
                    },
                    onShowAllGroups: (keyword) {
                      final searchModel = serviceLocator<TUISearchViewModel>();
                      final groups = List<V2TimGroupInfo>.from(
                        searchModel.groupList ?? const [],
                      );
                      final conversations = List<V2TimConversation?>.from(
                        searchModel.conversationList,
                      );
                      final useStore =
                          SelfHostedGroupBridge.localSearchEnabled &&
                              keyword.trim().isNotEmpty;
                      Widget page({VoidCallback? closeWidePopup}) {
                        return TIMUIKitSearchGroupAllPage(
                          groupList: groups,
                          conversationList: conversations,
                          keyword: keyword,
                          loadMoreFromStore: useStore
                              ? (cursor) async {
                                  final page = await SelfHostedGroupBridge
                                      .searchGroupsLocal(
                                    keyword: keyword,
                                    limit: 80,
                                    cursor: cursor,
                                  );
                                  final items =
                                      await SelfHostedGroupBridge.hydrateGroups(
                                          page.ids);
                                  return (
                                    items: items,
                                    nextCursor: page.nextCursor,
                                    hasMore: page.hasMore,
                                  );
                                }
                              : null,
                          onTapConversation: (conversation, message) {
                            handleTapConversation(
                              conversation,
                              message,
                              closeWidePopup: closeWidePopup,
                            );
                          },
                        );
                      }

                      if (isWideScreen) {
                        TUIKitWidePopup.showPopupWindow(
                          operationKey: TUIKitWideModalOperationKey.chatHistory,
                          context: context,
                          width: MediaQuery.of(context)
                              .size
                              .width
                              .clamp(520, 720)
                              .toDouble(),
                          height: (MediaQuery.of(context).size.height * 0.72)
                              .clamp(480, 680)
                              .toDouble(),
                          child: (onClose) => page(closeWidePopup: onClose),
                          theme: theme,
                        );
                      } else {
                        Navigator.push(
                          context,
                          AppMaterialPageRoute(
                            builder: (context) => page(),
                            settings: const RouteSettings(
                              name: AppRoutes.searchAllGroups,
                            ),
                          ),
                        );
                      }
                    },
                    onEnterSearchInConversation:
                        (V2TimConversation conversation, String keyword) {
                      if (isWideScreen) {
                        TUIKitWidePopup.showPopupWindow(
                            operationKey:
                                TUIKitWideModalOperationKey.chatHistory,
                            context: context,
                            width: MediaQuery.of(context)
                                .size
                                .width
                                .clamp(520, 720)
                                .toDouble(),
                            height: (MediaQuery.of(context).size.height * 0.72)
                                .clamp(480, 680)
                                .toDouble(),
                            child: (onClose) => TIMUIKitSearchMsgDetail(
                                  currentConversation: conversation,
                                  keyword: keyword,
                                  searchBarBuilder: _contactStyleSearchBar,
                                  emptyStateBuilder: _buildSearchEmptyState,
                                  pickSearchDate: showChatHistoryDatePicker,
                                  messageAbstractBuilder:
                                      buildReplyAbstractMessage,
                                  onTapConversation:
                                      (V2TimConversation conversation,
                                          V2TimMessage? message) {
                                    handleTapConversation(
                                      conversation,
                                      message,
                                      closeWidePopup: onClose,
                                    );
                                  },
                                  memberPresenceLabelBuilder:
                                      (userId, imOnline) =>
                                          _searchMemberPresenceLabel(
                                              context, userId, imOnline),
                                  memberPresenceLoadingChecker:
                                      (userId, imOnline) =>
                                          _searchMemberPresenceLoading(
                                              context, userId, imOnline),
                                  onMemberListLoaded: (userIds) =>
                                      _onSearchMemberListLoaded(
                                          context, userIds),
                                  memberPresenceListenable:
                                      Provider.of<PresenceProvider>(context,
                                          listen: false),
                                ),
                            theme: theme);
                      } else {
                        Navigator.push(
                            context,
                            AppMaterialPageRoute(
                              builder: (context) => Search(
                                onTapConversation: widget.onTapConversation,
                                onTapConversationWithMessage:
                                    widget.onTapConversationWithMessage,
                                conversation: conversation,
                                initKeyword: keyword,
                                onBack: widget.onBack,
                              ),
                              settings: const RouteSettings(
                                name: AppRoutes.searchInConversation,
                              ),
                            ));
                      }
                    },
                    onTapConversation: handleTapConversation,
                  ),
          ),
          name: 'search'),
    );
  }
}
