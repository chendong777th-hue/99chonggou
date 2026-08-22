import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_showAll.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_search_not_support.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class TIMUIKitConversationFilterMsgPage extends StatefulWidget {
  const TIMUIKitConversationFilterMsgPage({
    super.key,
    required this.conversation,
    required this.pageTitle,
    required this.onTapMessage,
    this.searchTimePosition = 0,
    this.searchTimePeriod = 0,
    this.senderUserIds,
    this.messageAbstractBuilder,
  });

  final V2TimConversation conversation;
  final String pageTitle;
  final int searchTimePosition;
  final int searchTimePeriod;
  final List<String>? senderUserIds;
  final void Function(V2TimConversation conversation, V2TimMessage? message)
      onTapMessage;
  /// Returns a display abstract for custom (and other) messages; null keeps
  /// the built-in type labels.
  final String? Function(V2TimMessage message)? messageAbstractBuilder;

  factory TIMUIKitConversationFilterMsgPage.byDate({
    required V2TimConversation conversation,
    required DateTime date,
    required void Function(V2TimConversation, V2TimMessage?) onTapMessage,
    String? Function(V2TimMessage message)? messageAbstractBuilder,
  }) {
    final range = dateSearchTimeRange(date);
    final title = DateFormat.yMMMd().format(date);
    return TIMUIKitConversationFilterMsgPage(
      conversation: conversation,
      pageTitle: title,
      searchTimePosition: range.searchTimePosition,
      searchTimePeriod: range.searchTimePeriod,
      onTapMessage: onTapMessage,
      messageAbstractBuilder: messageAbstractBuilder,
    );
  }

  factory TIMUIKitConversationFilterMsgPage.byMember({
    required V2TimConversation conversation,
    required String memberShowName,
    required String senderUserId,
    required void Function(V2TimConversation, V2TimMessage?) onTapMessage,
    String? Function(V2TimMessage message)? messageAbstractBuilder,
  }) {
    return TIMUIKitConversationFilterMsgPage(
      conversation: conversation,
      pageTitle: memberShowName,
      senderUserIds: [senderUserId],
      onTapMessage: onTapMessage,
      messageAbstractBuilder: messageAbstractBuilder,
    );
  }

  @override
  State<TIMUIKitConversationFilterMsgPage> createState() =>
      _TIMUIKitConversationFilterMsgPageState();
}

class _TIMUIKitConversationFilterMsgPageState
    extends TIMUIKitState<TIMUIKitConversationFilterMsgPage> {
  final TUISearchViewModel _model = serviceLocator<TUISearchViewModel>();

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModelChanged);
    _load(reset: true);
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    _model.clearConversationFilterResults();
    super.dispose();
  }

  void _onModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _load({required bool reset}) {
    _model.searchConversationWithFilter(
      conversationId: widget.conversation.conversationID,
      groupID: resolveGroupIdFromConversation(widget.conversation),
      userID: widget.conversation.userID,
      reset: reset,
      searchTimePosition: widget.searchTimePosition,
      searchTimePeriod: widget.searchTimePeriod,
      userIDList: widget.senderUserIds,
    );
  }

  (bool isRevoke, bool isRevokeByAdmin) _isRevokeMessage(V2TimMessage? message) {
    if (message == null) {
      return (false, false);
    }
    if (message.status == 6) {
      return (true, false);
    }
    try {
      final customData = jsonDecode(message.cloudCustomData ?? '{}');
      final isRevoke = customData['isRevoke'] ?? false;
      final revokeByAdmin = customData['revokeByAdmin'] ?? false;
      return (isRevoke, revokeByAdmin);
    } catch (_) {
      return (false, false);
    }
  }

  String _getMsgElem(V2TimMessage message) {
    final msgType = message.elemType;
    final revokeStatus = _isRevokeMessage(message);
    if (revokeStatus.$1) {
      final isSelf = message.isSelf ?? true;
      final option2 = revokeStatus.$2
          ? TIM_t('管理员')
          : (isSelf ? TIM_t('您') : message.nickName ?? message.sender);
      return TIM_t_para('{{option2}}撤回了一条消息', '$option2撤回了一条消息')(
        option2: option2,
      );
    }
    final abstract = widget.messageAbstractBuilder?.call(message)?.trim();
    if (abstract != null && abstract.isNotEmpty) {
      return abstract;
    }
    switch (msgType) {
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return TIM_t('[自定义]');
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return TIM_t('[语音]');
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return message.textElem?.text ?? '';
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return TIM_t('[表情]');
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        final option1 = message.fileElem?.fileName ?? TIM_t('[文件]');
        return TIM_t_para('[文件] {{option1}}', '[文件] $option1')(option1: option1);
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return TIM_t('[图片]');
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return TIM_t('[视频]');
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return TIM_t('[位置]');
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        return TIM_t('[聊天记录]');
      default:
        return TIM_t('未知消息');
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    if (PlatformUtils().isWeb) {
      return TIMUIKitSearchNotSupport();
    }

    final theme = value.theme;
    final messages = _model.conversationFilterMessages;
    final loading = _model.conversationFilterLoading && messages.isEmpty;
    final showLoadMore =
        _model.conversationFilterHasMore && messages.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.chatBgColor ?? theme.wideBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.chatHeaderBgColor ?? theme.appbarBgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(
          color: theme.primaryColor ?? theme.chatHeaderBackTextColor,
        ),
        title: Text(
          widget.pageTitle,
          style: TextStyle(
            fontSize: 17,
            color: theme.chatHeaderTitleTextColor ?? theme.darkTextColor,
          ),
        ),
      ),
      body: loading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.primaryColor,
                strokeWidth: 2,
              ),
            )
          : messages.isEmpty
              ? Center(
                  child: Text(
                    TIM_t('暂无数据'),
                    style: TextStyle(color: theme.weakTextColor),
                  ),
                )
              : ListView(
                  children: [
                    ...messages.map(
                      (message) {
                        final senderName = MessageUtils.getDisplayName(message);
                        return Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: TIMUIKitSearchItem(
                          faceUrl: message.faceUrl ?? '',
                          showName: senderName,
                          lineOne: senderName,
                          lineOneRight: message.timestamp != null
                              ? TimeAgo().getTimeForMessage(message.timestamp!)
                              : null,
                          lineTwo: _getMsgElem(message),
                          onClick: () {
                            widget.onTapMessage(widget.conversation, message);
                          },
                        ),
                      );
                      },
                    ),
                    if (showLoadMore)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: TIMUIKitSearchShowALl(
                          textShow: TIM_t('更多聊天记录'),
                          onClick: () => _load(reset: false),
                        ),
                      ),
                  ],
                ),
    );
  }
}
