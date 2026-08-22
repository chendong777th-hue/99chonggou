import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/search_result_cursor.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_item.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 全局搜索「全部群聊」独立页：Virtual List + Cursor 窗口 loadMore。
class TIMUIKitSearchGroupAllPage extends StatefulWidget {
  final List<V2TimGroupInfo> groupList;
  final List<V2TimConversation?> conversationList;
  final Function(V2TimConversation, V2TimMessage?) onTapConversation;
  final String? keyword;
  final Future<
          ({List<V2TimGroupInfo> items, String? nextCursor, bool hasMore})>
      Function(String? cursor)? loadMoreFromStore;

  const TIMUIKitSearchGroupAllPage({
    Key? key,
    required this.groupList,
    required this.conversationList,
    required this.onTapConversation,
    this.keyword,
    this.loadMoreFromStore,
  }) : super(key: key);

  @override
  State<TIMUIKitSearchGroupAllPage> createState() =>
      _TIMUIKitSearchGroupAllPageState();
}

class _TIMUIKitSearchGroupAllPageState
    extends TIMUIKitState<TIMUIKitSearchGroupAllPage> {
  static const double _itemExtent = 64;
  static const double _cacheExtent = 400;

  final ScrollController _scrollController = ScrollController();
  late final List<V2TimGroupInfo> _groups;
  late final Map<String, V2TimConversation> _conversationByGroupId;
  late SearchResultCursor _cursor;
  String? _storeCursor;
  bool _storeHasMore = false;
  bool _storeLoading = false;
  bool get _useStorePagination => widget.loadMoreFromStore != null;

  @override
  void initState() {
    super.initState();
    _groups = widget.groupList
        .where((group) => group.groupID.trim().isNotEmpty)
        .toList();
    if (_useStorePagination) {
      _storeCursor = _groups.isEmpty ? null : _groups.last.groupID.trim();
      _storeHasMore = true;
      _cursor =
          SearchResultCursor(total: _groups.length, pageSize: _groups.length);
    } else {
      _cursor = SearchResultCursor(total: _groups.length);
    }
    _conversationByGroupId = <String, V2TimConversation>{};
    for (final conversation in widget.conversationList) {
      final groupId = conversation?.groupID?.trim() ?? '';
      if (groupId.isNotEmpty && conversation != null) {
        _conversationByGroupId[groupId] = conversation;
      }
    }
    _scrollController.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeLoadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
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
      _loadMoreFromStore();
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
      final existing = _groups
          .map((e) => e.groupID.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      final appended = <V2TimGroupInfo>[];
      for (final item in page.items) {
        final id = item.groupID.trim();
        if (id.isEmpty || existing.contains(id)) {
          continue;
        }
        existing.add(id);
        appended.add(item);
      }
      setState(() {
        _groups.addAll(appended);
        _storeCursor = page.nextCursor;
        _storeHasMore = page.hasMore;
        _cursor = SearchResultCursor(
          total: _groups.length,
          pageSize: _groups.length,
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

  Widget _buildRow(int index) {
    final group = _groups[index];
    final conversation = resolveSearchGroupConversation(
      group: group,
      conversationByGroupId: _conversationByGroupId,
    );
    final title = preferSearchGroupShowName(
      groupName: group.groupName,
      conversationShowName: conversation.showName,
      groupId: group.groupID,
    );
    return TIMUIKitSearchItem(
      key: ValueKey(group.groupID),
      onClick: () {
        widget.onTapConversation(conversation, null);
      },
      faceUrl: conversation.faceUrl ?? group.faceUrl ?? "",
      showName: "",
      lineOne: title,
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final theme = value.theme;
    final bg = theme.conversationItemBgColor ??
        theme.wideBackgroundColor ??
        Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.chatHeaderBgColor ?? bg,
        title: Text(
          TIM_t("群聊"),
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
      body: _groups.isEmpty
          ? Center(
              child: Text(
                TIM_t("无搜索结果"),
                style: TextStyle(
                    color: theme.weakTextColor ?? hexToColor("999999")),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemExtent: _itemExtent,
              cacheExtent: _cacheExtent,
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _cursor.displayedCount,
              itemBuilder: (context, index) => _buildRow(index),
            ),
    );
  }
}
