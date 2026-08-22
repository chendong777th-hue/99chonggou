import 'package:azlistview_all_platforms/azlistview_all_platforms.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_list_role_badge.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/listener_model/tui_group_listener_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/az_list_view.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme_view_model.dart';

typedef GroupItemBuilder = Widget Function(BuildContext context, V2TimGroupInfo groupInfo);
typedef GroupCountFooterBuilder = Widget Function(BuildContext context, int count);

const _groupCountFooterMarker = '__group_count_footer__';

class TIMUIKitGroup extends StatefulWidget {
  final void Function(V2TimGroupInfo groupInfo, V2TimConversation conversation)? onTapItem;
  final Widget Function(BuildContext context)? emptyBuilder;
  final GroupItemBuilder? itemBuilder;

  /// the filter for group conversation
  final bool Function(V2TimGroupInfo? groupInfo)? groupCollector;

  /// local search keyword for group name, group id, and pinyin
  final String searchKeyword;

  /// control whether to show the alphabet index bar on mobile
  final bool isShowIndexBar;

  /// show total group count footer at the bottom of the scroll list
  final bool showGroupCount;

  /// custom footer for [showGroupCount]; defaults to a centered weak text row
  final GroupCountFooterBuilder? groupCountFooterBuilder;

  /// 列表项右侧展示当前用户在群内的角色（群主/管理员/普通成员）。
  final bool showSelfRoleBadge;

  const TIMUIKitGroup({
    Key? key,
    this.onTapItem,
    this.emptyBuilder,
    this.itemBuilder,
    this.groupCollector,
    this.searchKeyword = "",
    this.isShowIndexBar = false,
    this.showGroupCount = false,
    this.groupCountFooterBuilder,
    this.showSelfRoleBadge = false,
  })
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _TIMUIKitGroupState();
}

class _TIMUIKitGroupState extends TIMUIKitState<TIMUIKitGroup> {
  final TUIFriendShipViewModel _friendshipViewModel = serviceLocator<TUIFriendShipViewModel>();
  final TUIGroupListenerModel _groupListenerModel = serviceLocator<TUIGroupListenerModel>();

  String _getShowName(V2TimGroupInfo item) {
    final groupName = item.groupName?.trim() ?? "";
    final groupID = item.groupID;
    return groupName.isNotEmpty ? groupName : groupID;
  }

  bool _matchesSearch(V2TimGroupInfo item) {
    final keyword = widget.searchKeyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return true;
    }
    final showName = _getShowName(item);
    final normalizedName = showName.toLowerCase();
    final normalizedGroupID = item.groupID.toLowerCase();
    final pinyin = PinyinHelper.getPinyinE(showName).toLowerCase();
    return normalizedName.contains(keyword) ||
        normalizedGroupID.contains(keyword) ||
        pinyin.contains(keyword);
  }

  List<ISuspensionBeanImpl<V2TimGroupInfo>> _getShowList(List<V2TimGroupInfo> groupList) {
    final List<ISuspensionBeanImpl<V2TimGroupInfo>> showList = List.empty(growable: true);
    for (var i = 0; i < groupList.length; i++) {
      final item = groupList[i];

      final showName = _getShowName(item);
      showList.add(
        ISuspensionBeanImpl(
          memberInfo: item,
          tagIndex: memberSuspensionIndexTag(showName),
        ),
      );
    }

    SuspensionUtil.sortListBySuspensionTag(showList);

    return showList;
  }

  Widget _itemBuilder(BuildContext context, V2TimGroupInfo groupInfo) {
    final theme = Provider.of<TUIThemeViewModel>(context).theme;
    final showName = _getShowName(groupInfo);
    final faceUrl = groupInfo.faceUrl ?? "";
    final isDesktopScreen = kIsWeb ||
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final itemBackgroundColor =
        theme.conversationItemBgColor ?? theme.weakBackgroundColor ?? Colors.white;
    final memberCount = groupInfo.memberCount ?? 0;
    final memberCountLabel =
        TIM_t_para("{{option1}}人", "$memberCount人")(option1: '$memberCount');
    // 与通讯录 ContactListWithPresence 桌面密度对齐。
    final avatarSize = isDesktopScreen ? 48.0 : 40.0;
    final avatarTextGap = isDesktopScreen ? 10.0 : 12.0;
    final rowPad = isDesktopScreen ? 6.0 : 4.0;
    final titleFontSize = isDesktopScreen ? 13.0 : 15.0;
    final subtitleFontSize = isDesktopScreen ? 11.0 : 12.0;
    final minHeight = isDesktopScreen ? 64.0 : 56.0;

    return Material(
      color: isDesktopScreen
          ? (theme.wideBackgroundColor ?? itemBackgroundColor)
          : itemBackgroundColor,
      child: InkWell(
        onTap: (() async {
          if (widget.onTapItem != null) {
            V2TimConversation conversation = V2TimConversation(
              conversationID: "group_${groupInfo.groupID}",
              groupID: groupInfo.groupID,
              type: 2,
              showName: groupInfo.groupName,
              groupType: groupInfo.groupType,
              faceUrl: groupInfo.faceUrl,
            );
            final res = await TencentImSDKPlugin.v2TIMManager
                .getConversationManager()
                .getConversation(conversationID: "group_${groupInfo.groupID}");
            if (res.code == 0 && res.data != null) {
              conversation = res.data!;
            }
            widget.onTapItem!(groupInfo, conversation);
          }
        }),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: EdgeInsets.only(top: rowPad, left: 16),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(right: 16, bottom: rowPad),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: avatarSize,
                      width: avatarSize,
                      margin: EdgeInsets.only(right: avatarTextGap),
                      child: Avatar(
                        faceUrl: faceUrl,
                        showName: showName,
                        type: 2,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.conversationItemTitleTextColor ??
                                  theme.darkTextColor ??
                                  Colors.black,
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            memberCountLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.weakTextColor ??
                                  theme.conversationItemLastMessageTextColor ??
                                  CommonColor.weakTextColor,
                              fontSize: subtitleFontSize,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.showSelfRoleBadge) ...[
                      const SizedBox(width: 8),
                      GroupListSelfRoleBadge(role: groupInfo.role),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: avatarSize + avatarTextGap),
                child: Container(
                  height: 0.6,
                  color: theme.weakDividerColor ?? CommonColor.weakDividerColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  GroupItemBuilder _getItemBuilder() {
    return widget.itemBuilder ?? _itemBuilder;
  }

  Widget _buildGroupCountFooter(BuildContext context, int count, TUITheme theme) {
    final builder = widget.groupCountFooterBuilder;
    if (builder != null) {
      return builder(context, count);
    }
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Center(
        child: Text(
          '$count groups',
          style: TextStyle(
            color: theme.weakTextColor ?? CommonColor.weakTextColor,
            fontSize: isDesktopScreen ? 12 : 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _friendshipViewModel.loadGroupListData();
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _friendshipViewModel),
        ChangeNotifierProvider.value(value: _groupListenerModel),
        ChangeNotifierProvider.value(value: serviceLocator<TUIThemeViewModel>()),
      ],
      builder: (BuildContext context, Widget? w) {
        final theme = Provider.of<TUIThemeViewModel>(context).theme;
        final NeedUpdate? needUpdate = Provider.of<TUIGroupListenerModel>(context).needUpdate;
        if (needUpdate != null) {
          _groupListenerModel.needUpdate = null;
          switch (needUpdate.updateType) {
            case UpdateType.groupInfo:
              Provider.of<TUIFriendShipViewModel>(context).loadGroupListData();
              break;
            case UpdateType.memberEnter:
            case UpdateType.memberLeave:
              Provider.of<TUIFriendShipViewModel>(context).loadGroupListData();
              break;
            default:
              break;
          }
        }
        List<V2TimGroupInfo> groupList = Provider.of<TUIFriendShipViewModel>(context).groupList;
        if (widget.groupCollector != null) {
          groupList = groupList.where(widget.groupCollector!).toList();
        }
        if (widget.searchKeyword.trim().isNotEmpty) {
          groupList = groupList.where(_matchesSearch).toList();
        }
        if (groupList.isNotEmpty) {
          final showList = _getShowList(groupList);
          final effectiveList = widget.showGroupCount
              ? [
                  ...showList,
                  ISuspensionBeanImpl<Object>(
                    memberInfo: _groupCountFooterMarker,
                    tagIndex: '',
                  ),
                ]
              : showList;
          return Container(
            color: theme.weakBackgroundColor ?? Colors.white,
            child: AZListViewContainer(
                isShowIndexBar: widget.isShowIndexBar,
                memberList: effectiveList,
                itemBuilder: (context, index) {
                  final memberInfo = effectiveList[index].memberInfo;
                  if (memberInfo == _groupCountFooterMarker) {
                    return _buildGroupCountFooter(context, groupList.length, theme);
                  }
                  final groupInfo = memberInfo as V2TimGroupInfo;
                  final itemBuilder = _getItemBuilder();
                  return itemBuilder(context, groupInfo);
                }),
          );
        }

        if (widget.emptyBuilder != null) {
          return widget.emptyBuilder!(context);
        }

        return Container();
      },
    );
  }
}
