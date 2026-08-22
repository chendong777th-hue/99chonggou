import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_asset_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_input.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_showAll.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_conversation_filter_msg_page.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_conversation_member_picker_page.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_conversation_media_file_page.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_search_not_support.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class TIMUIKitSearchMsgDetail extends StatefulWidget {
  /// Conversation need search
  final V2TimConversation currentConversation;

  /// initial keyword
  final String keyword;

  final List<V2TimMessage>? initMessageList;

  /// the callback after clicking each conversation message item
  final Function(V2TimConversation, V2TimMessage?) onTapConversation;

  final bool? isAutoFocus;

  final TIMUIKitSearchBarBuilder? searchBarBuilder;

  final MemberPresenceLabelBuilder? memberPresenceLabelBuilder;

  final MemberPresenceLoadingChecker? memberPresenceLoadingChecker;

  final void Function(List<String> userIds)? onMemberListLoaded;

  final Listenable? memberPresenceListenable;

  final TIMUIKitSearchEmptyBuilder? emptyStateBuilder;

  /// App-provided date picker (e.g. Cupertino sheet matching live schedule UI).
  /// When null, falls back to Material [showDatePicker].
  final Future<DateTime?> Function(BuildContext context)? pickSearchDate;

  /// Same abstract source as conversation last-message / reply quote for CUSTOM.
  final String? Function(V2TimMessage message)? messageAbstractBuilder;

  const TIMUIKitSearchMsgDetail({
    super.key,
    this.isAutoFocus = true,
    required this.currentConversation,
    required this.keyword,
    required this.onTapConversation,
    this.initMessageList,
    this.searchBarBuilder,
    this.memberPresenceLabelBuilder,
    this.memberPresenceLoadingChecker,
    this.onMemberListLoaded,
    this.memberPresenceListenable,
    this.emptyStateBuilder,
    this.pickSearchDate,
    this.messageAbstractBuilder,
  });

  @override
  State<StatefulWidget> createState() => TIMUIKitSearchMsgDetailState();
}

class TIMUIKitSearchMsgDetailState extends TIMUIKitState<TIMUIKitSearchMsgDetail> {
  final model = serviceLocator<TUISearchViewModel>();
  String keywordState = "";
  int currentPage = 0;
  final FocusNode focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    keywordState = widget.keyword;
    if (widget.keyword.trim().isNotEmpty) {
      _refreshResults(widget.keyword, true);
    }
  }

  void _refreshResults(String? keyword, bool isNewSearch) {
    if (isNewSearch) {
      setState(() {
        currentPage = 0;
        keywordState = keyword ?? '';
      });
    }
    final trimmed = (keyword ?? keywordState).trim();
    if (trimmed.isEmpty) {
      model.clearConversationTextResults();
      model.scheduleConversationMediaFileSearch(
        conversationId: widget.currentConversation.conversationID,
        reset: true,
        keyword: '',
      );
      return;
    }
    model.scheduleConversationMediaFileSearch(
      conversationId: widget.currentConversation.conversationID,
      reset: isNewSearch,
      keyword: trimmed,
    );
    model.scheduleConversationTextSearch(
      keyword: trimmed,
      conversationId: widget.currentConversation.conversationID,
      page: currentPage,
      reset: isNewSearch,
    );
    if (isNewSearch) {
      setState(() {
        currentPage = currentPage + 1;
      });
    }
  }

  void _openMediaFilePage(ConversationAssetTab tab) {
    focusNode.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TIMUIKitConversationMediaFilePage(
          conversation: widget.currentConversation,
          initialTab: tab,
          onTapMessage: (conversation, message) {
            widget.onTapConversation(conversation, message);
          },
        ),
      ),
    );
  }

  Future<void> _openDateSearch(TUITheme theme) async {
    focusNode.unfocus();
    final now = DateTime.now();
    final DateTime? picked;
    final customPick = widget.pickSearchDate;
    if (customPick != null) {
      picked = await customPick(context);
    } else {
      picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year - 5),
        lastDate: now,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: theme.primaryColor ?? const Color(0xFF1E90FF),
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
    }
    if (picked == null || !mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TIMUIKitConversationFilterMsgPage.byDate(
          conversation: widget.currentConversation,
          date: picked!,
          onTapMessage: widget.onTapConversation,
          messageAbstractBuilder: widget.messageAbstractBuilder,
        ),
      ),
    );
  }

  Future<void> _openMemberSearch() async {
    focusNode.unfocus();
    final groupId = resolveGroupIdFromConversation(widget.currentConversation);
    if (groupId == null || groupId.isEmpty) {
      return;
    }

    final member = await Navigator.of(context).push<V2TimGroupMemberFullInfo>(
      MaterialPageRoute(
        builder: (_) => TIMUIKitConversationMemberPickerPage(
          groupId: groupId,
          memberPresenceLabelBuilder: widget.memberPresenceLabelBuilder,
          memberPresenceLoadingChecker: widget.memberPresenceLoadingChecker,
          onMemberListLoaded: widget.onMemberListLoaded,
          presenceListenable: widget.memberPresenceListenable,
        ),
      ),
    );
    if (member == null || !mounted) {
      return;
    }

    final userId = member.userID?.trim() ?? '';
    if (userId.isEmpty) {
      return;
    }
    final showName = memberDisplayName(
      friendRemark: member.friendRemark,
      nameCard: member.nameCard,
      nickName: member.nickName,
      userID: member.userID,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TIMUIKitConversationFilterMsgPage.byMember(
          conversation: widget.currentConversation,
          memberShowName: showName,
          senderUserId: userId,
          onTapMessage: widget.onTapConversation,
          messageAbstractBuilder: widget.messageAbstractBuilder,
        ),
      ),
    );
  }

  bool get _isGroupConversation =>
      isGroupConversation(widget.currentConversation);

  (bool isRevoke, bool isRevokeByAdmin) isRevokeMessage(V2TimMessage? message) {
    if (message == null) {
      return (false, false);
    }
    if (message.status == 6) {
      return (true, false);
    }
    try {
      final customData = jsonDecode(message.cloudCustomData ?? "{}");
      final isRevoke = customData["isRevoke"] ?? false;
      final revokeByAdmin = customData["revokeByAdmin"] ?? false;
      return (isRevoke, revokeByAdmin);
    } catch (_) {
      return (false, false);
    }
  }

  String _getMsgElem(V2TimMessage message) {
    final msgType = message.elemType;
    final revokeStatus = isRevokeMessage(message);
    if (revokeStatus.$1) {
      final isSelf = message.isSelf ?? true;
      final option2 = revokeStatus.$2
          ? TIM_t("管理员")
          : (isSelf ? TIM_t("您") : message.nickName ?? message.sender);
      return TIM_t_para("{{option2}}撤回了一条消息", "$option2撤回了一条消息")(
        option2: option2,
      );
    }
    final abstract = widget.messageAbstractBuilder?.call(message)?.trim();
    if (abstract != null && abstract.isNotEmpty) {
      return abstract;
    }
    switch (msgType) {
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return TIM_t("[自定义]");
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return TIM_t("[语音]");
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return message.textElem?.text ?? '';
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return TIM_t("[表情]");
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        final option1 = message.fileElem?.fileName ?? TIM_t("[文件]");
        return TIM_t_para("[文件] {{option1}}", "[文件] $option1")(option1: option1);
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return TIM_t("[图片]");
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return TIM_t("[视频]");
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return TIM_t("[位置]");
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        return TIM_t("[聊天记录]");
      default:
        return TIM_t("未知消息");
    }
  }

  Widget _buildContentShortcuts(BuildContext context, TUITheme theme) {
    final tr = Translations.of(context);
    final primary = theme.primaryColor ?? const Color(0xFF1E90FF);
    final circleBg = primary.withValues(alpha: 0.12);

    Widget buildShortcut({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primary, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: theme.darkTextColor ?? Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    final shortcuts = <Widget>[
      buildShortcut(
        icon: Icons.photo_outlined,
        label: TIM_t('媒体'),
        onTap: () => _openMediaFilePage(ConversationAssetTab.media),
      ),
      buildShortcut(
        icon: Icons.folder_outlined,
        label: TIM_t('文件'),
        onTap: () => _openMediaFilePage(ConversationAssetTab.file),
      ),
      if (_isGroupConversation) ...[
        buildShortcut(
          icon: Icons.calendar_today_outlined,
          label: TIM_t('日期'),
          onTap: () => _openDateSearch(theme),
        ),
        buildShortcut(
          icon: Icons.person_outline,
          label: TIM_t('群成员'),
          onTap: _openMemberSearch,
        ),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
      child: Column(
        children: [
          Text(
            tr.k_1ui0gai,
            style: TextStyle(
              fontSize: 14,
              color: theme.weakTextColor ?? const Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 40,
            runSpacing: 20,
            children: shortcuts,
          ),
        ],
      ),
    );
  }

  List<Widget> _renderListMessage(
    List<V2TimMessage> msgList,
    TUITheme theme,
  ) {
    return msgList.map((message) {
      final senderName = MessageUtils.getDisplayName(message);
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: TIMUIKitSearchItem(
          faceUrl: message.faceUrl ?? "",
          showName: senderName,
          lineOne: senderName,
          lineOneRight: message.timestamp != null
              ? TimeAgo().getTimeForMessage(message.timestamp!)
              : null,
          lineTwo: _getMsgElem(message),
          onClick: () {
            focusNode.unfocus();
            widget.onTapConversation(widget.currentConversation, message);
          },
        ),
      );
    }).toList();
  }

  Widget _renderShowMore(bool showMore, TUITheme theme, {required VoidCallback onTap}) {
    if (!showMore) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: theme.conversationItemBgColor ?? theme.wideBackgroundColor,
      ),
      child: TIMUIKitSearchShowALl(
        textShow: TIM_t("更多聊天记录"),
        onClick: onTap,
      ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final theme = value.theme;
    if (PlatformUtils().isWeb) {
      return TIMUIKitSearchNotSupport();
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: serviceLocator<TUISearchViewModel>()),
      ],
      builder: (context, w) {
        final isDesktopScreen =
            TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
        final hasKeyword = keywordState.trim().isNotEmpty;

        List<V2TimMessage> searchResults = hasKeyword
            ? Provider.of<TUISearchViewModel>(context)
                .mergedConversationSearchResults(keyword: keywordState)
            : const [];

        if (searchResults.isEmpty &&
            widget.initMessageList != null &&
            widget.initMessageList!.isNotEmpty &&
            hasKeyword) {
          searchResults = widget.initMessageList!;
        }

        final totalMsgInConversationCount =
            Provider.of<TUISearchViewModel>(context).totalMsgInConversationCount;
        final textResultCount = Provider.of<TUISearchViewModel>(context)
            .currentMsgListForConversation
            .length;
        final showTextLoadMore =
            hasKeyword && totalMsgInConversationCount > textResultCount;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktopScreen)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: Avatar(
                          faceUrl: widget.currentConversation.faceUrl ?? "",
                          showName: "",
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.currentConversation.showName ??
                              widget.currentConversation.userID ??
                              "",
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.darkTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              widget.searchBarBuilder != null
                  ? widget.searchBarBuilder!(
                      context,
                      focusNode: focusNode,
                      controller: _controller,
                      onChanged: (value) => _refreshResults(value, true),
                      isAutoFocus: widget.isAutoFocus,
                    )
                  : TIMUIKitSearchInput(
                      focusNode: focusNode,
                      controller: _controller,
                      isAutoFocus: widget.isAutoFocus,
                      onChange: (value) => _refreshResults(value, true),
                      initValue: widget.keyword,
                      prefixIcon: Icon(
                        Icons.search,
                        size: 16,
                        color: theme.weakTextColor ?? hexToColor("979797"),
                      ),
                    ),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  child: ListView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      _buildContentShortcuts(context, theme),
                      if (hasKeyword && searchResults.isEmpty)
                        widget.emptyStateBuilder?.call(
                              context,
                              hasKeyword: true,
                              isLoading: false,
                            ) ??
                            Padding(
                              padding: const EdgeInsets.only(top: 32),
                              child: Center(
                                child: Text(
                                  TIM_t('无搜索结果'),
                                  style: TextStyle(color: theme.weakTextColor),
                                ),
                              ),
                            )
                      else if (hasKeyword)
                        ..._renderListMessage(searchResults, theme),
                      _renderShowMore(
                        showTextLoadMore,
                        theme,
                        onTap: () {
                          setState(() => currentPage = currentPage + 1);
                          model.getMsgForConversation(
                            keywordState,
                            widget.currentConversation.conversationID,
                            currentPage,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
