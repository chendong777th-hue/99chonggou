import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/picker_user_filter.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/tim_uikit_conversation_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/az_list_view.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/radio_button.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class RecentForwardList extends StatefulWidget {
  final bool isMultiSelect;
  final Function(List<V2TimConversation> conversationList)? onChanged;
  final String keyword;
  final String sectionTitle;
  final bool showSectionHeader;
  final LastMessageBuilder? lastMessageBuilder;
  final LastMessageAbstractBuilder? lastMessageAbstractBuilder;

  const RecentForwardList({
    Key? key,
    this.isMultiSelect = true,
    this.onChanged,
    this.keyword = "",
    this.sectionTitle = "",
    this.showSectionHeader = true,
    this.lastMessageBuilder,
    this.lastMessageAbstractBuilder,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _RecentForwardListState();
}

class _RecentForwardListState extends TIMUIKitState<RecentForwardList> {
  final TUIConversationViewModel _conversationViewModel = serviceLocator<TUIConversationViewModel>();
  final List<V2TimConversation> _selectedConversation = [];

  List<ISuspensionBeanImpl<V2TimConversation?>> _buildMemberList(
    List<V2TimConversation?> conversationList,
  ) {
    final keyword = widget.keyword.trim().toLowerCase();
    final List<ISuspensionBeanImpl<V2TimConversation?>> showList = [];
    for (final item in conversationList) {
      if (item == null) {
        continue;
      }
      if (shouldHideConversationFromPickers(item)) {
        continue;
      }
      final showName = (item.showName ?? "").trim();
      if (keyword.isNotEmpty && !showName.toLowerCase().contains(keyword)) {
        continue;
      }
      showList.add(ISuspensionBeanImpl(memberInfo: item, tagIndex: "#"));
    }
    return showList;
  }

  Widget _buildSectionHeader(String title, TUITheme theme) {
    final sectionBackgroundColor =
        theme.selectPanelBgColor ?? theme.weakDividerColor ?? const Color(0xFFF5F5F5);
    return Container(
      height: 32,
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.only(left: 16.0),
      color: sectionBackgroundColor,
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        softWrap: true,
        style: TextStyle(
          fontSize: 13.0,
          color: theme.weakTextColor,
        ),
      ),
    );
  }

  Widget _buildConversationItem(V2TimConversation conversation) {
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final isGroupConversation = conversation.type == 2;
    final checkboxTopPadding = isGroupConversation
        ? (isDesktopScreen ? 18.0 : 22.0)
        : (isDesktopScreen ? 22.0 : 26.0);

    final conversationItem = TIMUIKitConversationItem(
      conversationID: conversation.conversationID,
      faceUrl: conversation.faceUrl ?? "",
      nickName: conversation.showName ?? "",
      lastMsg: conversation.lastMessage,
      isPined: conversation.isPinned ?? false,
      unreadCount: conversation.unreadCount ?? 0,
      groupAtInfoList: conversation.groupAtInfoList ?? [],
      isDisturb: (conversation.recvOpt ?? 0) != 0,
      draftText: conversation.draftText,
      draftTimestamp: conversation.draftTimestamp,
      lastMessageBuilder: widget.lastMessageBuilder,
      lastMessageAbstractBuilder: widget.lastMessageAbstractBuilder,
      convType: conversation.type,
    );

    void handleTap() {
      if (widget.isMultiSelect) {
        final isSelected = _selectedConversation.contains(conversation);
        if (isSelected) {
          _selectedConversation.remove(conversation);
        } else {
          _selectedConversation.add(conversation);
        }
        if (widget.onChanged != null) {
          widget.onChanged!(_selectedConversation);
        }
        setState(() {});
      } else if (widget.onChanged != null) {
        widget.onChanged!([conversation]);
      }
    }

    if (!widget.isMultiSelect) {
      return InkWell(
        onTap: handleTap,
        child: conversationItem,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 16, top: checkboxTopPadding),
          child: CheckBoxButton(
            isChecked: _selectedConversation.contains(conversation),
            onChanged: (value) {
              if (value) {
                _selectedConversation.add(conversation);
              } else {
                _selectedConversation.remove(conversation);
              }
              setState(() {});
              widget.onChanged?.call(_selectedConversation);
            },
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: handleTap,
            child: conversationItem,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;

    if (!widget.isMultiSelect) {
      _selectedConversation.clear();
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _conversationViewModel),
      ],
      builder: (context, w) {
        final recentConvList =
            serviceLocator<TUIConversationViewModel>().conversationList;
        final showList = _buildMemberList(recentConvList);
        final listBackgroundColor =
            theme.conversationItemBgColor ?? theme.weakBackgroundColor ?? Colors.white;

        return Container(
          color: listBackgroundColor,
          child: Column(
            children: [
              if (widget.showSectionHeader)
                _buildSectionHeader(
                  widget.sectionTitle.isNotEmpty ? widget.sectionTitle : TIM_t("最近"),
                  theme,
                ),
              Expanded(
                child: AZListViewContainer(
                  memberList: showList,
                  isShowIndexBar: false,
                  susItemBuilder: (context, index) => Container(),
                  itemBuilder: (context, index) {
                    final conversation = showList[index].memberInfo;
                    if (conversation != null) {
                      return _buildConversationItem(conversation);
                    }
                    return Container();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
