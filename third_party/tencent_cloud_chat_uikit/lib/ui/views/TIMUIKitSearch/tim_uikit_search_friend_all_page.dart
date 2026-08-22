import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/picker_user_filter.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/search_result_cursor.dart';

/// 全局搜索「全部联系人」独立页：Virtual List + Cursor 窗口 loadMore。
class TIMUIKitSearchFriendAllPage extends StatefulWidget {
  final List<V2TimFriendInfoResult> friendResultList;
  final List<V2TimConversation?> conversationList;
  final Function(V2TimConversation, V2TimMessage?) onTapConversation;
  final MemberPresenceLabelBuilder? friendPresenceLabelBuilder;
  final MemberPresenceLoadingChecker? friendPresenceLoadingChecker;
  final void Function(List<String> userIds)? onFriendListLoaded;
  final Listenable? presenceListenable;

  /// 非空时触底走库级分页，而不是仅切内存窗口。
  final String? keyword;
  final Future<
          ({
            List<V2TimFriendInfoResult> items,
            String? nextCursor,
            bool hasMore
          })>
      Function(String? cursor)? loadMoreFromStore;

  const TIMUIKitSearchFriendAllPage({
    Key? key,
    required this.friendResultList,
    required this.conversationList,
    required this.onTapConversation,
    this.friendPresenceLabelBuilder,
    this.friendPresenceLoadingChecker,
    this.onFriendListLoaded,
    this.presenceListenable,
    this.keyword,
    this.loadMoreFromStore,
  }) : super(key: key);

  @override
  State<TIMUIKitSearchFriendAllPage> createState() =>
      _TIMUIKitSearchFriendAllPageState();
}

class _TIMUIKitSearchFriendAllPageState
    extends TIMUIKitState<TIMUIKitSearchFriendAllPage> {
  static const double _itemExtent = 64;
  static const double _cacheExtent = 400;

  final ScrollController _scrollController = ScrollController();
  final FriendshipServices _friendshipServices =
      serviceLocator<FriendshipServices>();
  final Map<String, V2TimUserStatus> _userStatusById = {};
  late final List<V2TimFriendInfoResult> _friends;
  late final Map<String, V2TimConversation> _conversationByUserId;
  late SearchResultCursor _cursor;
  Timer? _presenceDebounce;
  String? _lastPresenceKey;
  String? _storeCursor;
  bool _storeHasMore = false;
  bool _storeLoading = false;
  bool get _useStorePagination => widget.loadMoreFromStore != null;

  @override
  void initState() {
    super.initState();
    _friends = widget.friendResultList
        .where((friend) {
          if (shouldHideUserFromPickers(friend.friendInfo?.userID)) {
            return false;
          }
          final userId = friend.friendInfo?.userID?.trim() ?? '';
          return userId.isNotEmpty;
        })
        .toList();
    if (_useStorePagination) {
      _storeCursor = _friends.isEmpty
          ? null
          : (_friends.last.friendInfo?.userID?.trim());
      _storeHasMore = true;
      _cursor = SearchResultCursor(total: _friends.length, pageSize: _friends.length);
    } else {
      _cursor = SearchResultCursor(total: _friends.length);
    }
    _conversationByUserId = <String, V2TimConversation>{};
    for (final conversation in widget.conversationList) {
      final userId = conversation?.userID?.trim() ?? '';
      if (userId.isNotEmpty && conversation != null) {
        _conversationByUserId[userId] = conversation;
      }
    }
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeLoadMore();
        _scheduleVisiblePresence();
      }
    });
  }

  @override
  void dispose() {
    _presenceDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _maybeLoadMore();
    _scheduleVisiblePresence();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!shouldLoadMoreByScroll(
      pixels: position.pixels,
      maxScrollExtent: position.maxScrollExtent,
      itemExtent: _itemExtent,
    )) {
      return;
    }
    if (_useStorePagination) {
      unawaited(_loadMoreFromStore());
      return;
    }
    if (!_cursor.hasMore) {
      return;
    }
    if (_cursor.loadMore()) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _maybeLoadMore();
        }
      });
    }
  }

  Future<void> _loadMoreFromStore() async {
    final loader = widget.loadMoreFromStore;
    if (loader == null || _storeLoading || !_storeHasMore) {
      return;
    }
    _storeLoading = true;
    try {
      final page = await loader(_storeCursor);
      if (!mounted) {
        return;
      }
      if (page.items.isEmpty) {
        setState(() {
          _storeHasMore = page.hasMore;
          _storeCursor = page.nextCursor;
        });
        return;
      }
      final existing = _friends
          .map((e) => e.friendInfo?.userID?.trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet();
      final appended = <V2TimFriendInfoResult>[];
      for (final item in page.items) {
        final id = item.friendInfo?.userID?.trim() ?? '';
        if (id.isEmpty || existing.contains(id)) {
          continue;
        }
        existing.add(id);
        appended.add(item);
      }
      setState(() {
        _friends.addAll(appended);
        _storeCursor = page.nextCursor;
        _storeHasMore = page.hasMore;
        _cursor = SearchResultCursor(
          total: _friends.length,
          pageSize: _friends.length,
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _maybeLoadMore();
        }
      });
    } finally {
      _storeLoading = false;
    }
  }

  void _scheduleVisiblePresence() {
    _presenceDebounce?.cancel();
    _presenceDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      _ensureVisiblePresence();
    });
  }

  void _ensureVisiblePresence() {
    final displayed = _cursor.displayedCount;
    if (displayed <= 0) {
      return;
    }
    final position = _scrollController.hasClients
        ? _scrollController.position
        : null;
    final viewport = position?.viewportDimension ??
        MediaQuery.sizeOf(context).height;
    final offset = position?.pixels ?? 0;
    final first = max(0, (offset / _itemExtent).floor() - 2);
    final visibleCount = (viewport / _itemExtent).ceil() + 4;
    final last = min(displayed, first + visibleCount);
    final userIds = <String>[];
    for (var i = first; i < last; i++) {
      final id = _friends[i].friendInfo?.userID?.trim() ?? '';
      if (id.isNotEmpty) {
        userIds.add(id);
      }
    }
    if (userIds.isEmpty) {
      return;
    }
    final key = userIds.join('|');
    if (_lastPresenceKey == key) {
      return;
    }
    _lastPresenceKey = key;
    final useAppPresence = widget.friendPresenceLabelBuilder != null;
    if (useAppPresence) {
      widget.onFriendListLoaded?.call(userIds);
      return;
    }
    unawaited(_loadUserStatus(userIds));
  }

  Future<void> _loadUserStatus(List<String> userIds) async {
    const chunkSize = 100;
    for (var i = 0; i < userIds.length; i += chunkSize) {
      final chunk = userIds.sublist(i, min(i + chunkSize, userIds.length));
      final statuses =
          await _friendshipServices.getUserStatus(userIDList: chunk);
      for (final status in statuses) {
        final id = status.userID?.trim() ?? '';
        if (id.isNotEmpty) {
          _userStatusById[id] = status;
        }
      }
    }
    if (!mounted) {
      return;
    }
    widget.onFriendListLoaded?.call(userIds);
    setState(() {});
  }

  bool _isImOnline(String userId) {
    return _userStatusById[userId]?.statusType == 1;
  }

  String? _presenceSubtitle(String userId) {
    final builder = widget.friendPresenceLabelBuilder;
    if (builder == null) {
      return _isImOnline(userId) ? TIM_t('在线') : TIM_t('离线');
    }
    return builder(userId, _isImOnline(userId));
  }

  String _showName(V2TimFriendInfoResult conv) {
    final remark = conv.friendInfo?.friendRemark;
    if (remark != null && remark.isNotEmpty) {
      return remark;
    }
    final nick = conv.friendInfo?.userProfile?.nickName;
    if (nick != null && nick.isNotEmpty) {
      return nick;
    }
    return conv.friendInfo?.userID?.trim() ?? '';
  }

  Widget _buildRow(int index) {
    final conv = _friends[index];
    final userId = conv.friendInfo?.userID?.trim() ?? '';
    final conversation = resolveSearchC2cConversation(
      friendInfo: conv.friendInfo,
      conversationByUserId: _conversationByUserId,
    );
    final showNickName = _showName(conv);
    final imOnline = _isImOnline(userId);
    final presenceLoading =
        widget.friendPresenceLoadingChecker?.call(userId, imOnline) ?? false;
    final presenceSubtitle =
        presenceLoading ? null : _presenceSubtitle(userId);
    final presenceSubtitleWidget = presenceLoading
        ? buildMemberPresenceSubtitleSkeleton(lineHeight: 19)
        : null;

    return TIMUIKitSearchItem(
      key: ValueKey(userId),
      onClick: () {
        widget.onTapConversation(conversation, null);
      },
      faceUrl: conv.friendInfo?.userProfile?.faceUrl ?? "",
      showName: showNickName,
      lineOne: showNickName,
      lineTwo: presenceSubtitle,
      lineTwoWidget: presenceSubtitleWidget,
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollController,
      itemExtent: _itemExtent,
      cacheExtent: _cacheExtent,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _cursor.displayedCount,
      itemBuilder: (context, index) => _buildRow(index),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final theme = value.theme;
    final bg = theme.conversationItemBgColor ??
        theme.wideBackgroundColor ??
        Colors.white;
    final listenable = widget.presenceListenable;

    Widget list = _buildList();
    if (listenable != null) {
      list = ListenableBuilder(
        listenable: listenable,
        builder: (context, _) => _buildList(),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.chatHeaderBgColor ?? bg,
        title: Text(
          TIM_t("联系人"),
          style: TextStyle(
            color: theme.appbarTextColor ?? theme.darkTextColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(
          color: theme.appbarTextColor ?? theme.darkTextColor,
        ),
      ),
      body: _friends.isEmpty
          ? Center(
              child: Text(
                TIM_t("无搜索结果"),
                style: TextStyle(
                    color: theme.weakTextColor ?? hexToColor("999999")),
              ),
            )
          : list,
    );
  }
}
