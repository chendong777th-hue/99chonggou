// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimFriendshipListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimGroupListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_change_info_type.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitAppBar/tim_uikit_appbar_title.dart';
import 'package:tuple/tuple.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class TIMUIKitAppBar extends StatefulWidget implements PreferredSizeWidget {
  /// Appbar config
  final AppBar? config;

  /// Allow show conversation total unread count
  final bool showTotalUnReadCount;

  /// Conversation id
  final String conversationID;

  /// conversation name
  final String conversationShowName;

  final int? conversationType;

  /// If allow update the conversation show name automatically.
  final bool isConversationShowNameFixed;

  final bool showC2cMessageEditStatus;

  final GestureTapDownCallback? onClickTitle;

  const TIMUIKitAppBar({
    Key? key,
    this.config,
    this.isConversationShowNameFixed = false,
    this.showTotalUnReadCount = true,
    this.conversationID = "",
    this.conversationShowName = "",
    this.conversationType,
    this.showC2cMessageEditStatus = true,
    this.onClickTitle,
  }) : super(key: key);

  @override
  Size get preferredSize =>
      config?.preferredSize ?? const Size.fromHeight(56.0);

  @override
  State<StatefulWidget> createState() => _TIMUIKitAppBarState();
}

class _TIMUIKitAppBarState extends TIMUIKitState<TIMUIKitAppBar> {
  final FriendshipServices _friendshipServices =
      serviceLocator<FriendshipServices>();
  final GroupServices _groupServices = serviceLocator<GroupServices>();

  V2TimFriendshipListener? _friendshipListener;
  V2TimGroupListener? _groupListener;

  String _conversationShowName = "";

  void _onDisplayNameChanged() {
    if (!mounted) {
      return;
    }
    String? name;
    if (widget.conversationType == 2) {
      name = DisplayNameStore.instance.group(widget.conversationID);
    } else if (widget.conversationType == 1) {
      name = DisplayNameStore.instance.c2c(widget.conversationID);
    } else {
      name = DisplayNameStore.instance.group(widget.conversationID) ??
          DisplayNameStore.instance.c2c(widget.conversationID);
    }
    final text = name;
    if (text != null && text.isNotEmpty && text != _conversationShowName) {
      setState(() {
        _conversationShowName = text;
      });
    }
  }

  _addConversationShowNameListener() {
    _friendshipListener = V2TimFriendshipListener(
      onFriendInfoChanged: (infoList) {
        try {
          final convPeer = ErrorMessageConverter.normalizedPeerUserId(
            widget.conversationID,
          );
          final changedInfo = infoList.firstWhere(
            (element) =>
                convPeer.isNotEmpty &&
                ErrorMessageConverter.normalizedPeerUserId(element.userID) ==
                    convPeer,
          );
          final remark = changedInfo.friendRemark?.trim() ?? '';
          final nick = changedInfo.userProfile?.nickName?.trim() ?? '';
          final uid = changedInfo.userID?.trim() ?? widget.conversationID;
          final text = remark.isNotEmpty
              ? remark
              : (nick.isNotEmpty ? nick : uid);
          DisplayNameStore.instance.setC2C(uid, text, notify: false);
          _conversationShowName = text;
          setState(() {});
          // ignore: empty_catches
        } catch (e) {}
      },
    );
    if (_friendshipListener != null) {
      _friendshipServices.addFriendListener(listener: _friendshipListener!);
    }
  }

  _addGroupListener() {
    _groupListener = V2TimGroupListener(
      onGroupInfoChanged: (groupID, changeInfos) {
        try {
          if (groupID == widget.conversationID) {
            final groupNameChangeInfo = changeInfos.firstWhere((element) =>
                element.type ==
                GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_NAME);
            if (groupNameChangeInfo.value != null) {
              _conversationShowName = groupNameChangeInfo.value!;
              setState(() {});
            }
          }
          // ignore: empty_catches
        } catch (e) {}
      },
    );
    if (_groupListener != null) {
      _groupServices.addGroupListener(listener: _groupListener!);
    }
  }

  String _getTotalUnReadCount(int unreadCount) {
    return unreadCount < 99 ? unreadCount.toString() : "99";
  }

  @override
  void initState() {
    super.initState();
    _conversationShowName = widget.conversationShowName;
    DisplayNameStore.instance.addListener(_onDisplayNameChanged);
    _onDisplayNameChanged();
    if (!widget.isConversationShowNameFixed) {
      _addConversationShowNameListener();
      _addGroupListener();
    }
  }

  @override
  void dispose() {
    DisplayNameStore.instance.removeListener(_onDisplayNameChanged);
    if (!widget.isConversationShowNameFixed) {
      _groupServices.removeGroupListener(listener: _groupListener);
      _friendshipServices.removeFriendListener(listener: _friendshipListener);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(TIMUIKitAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationShowName != widget.conversationShowName) {
      final cached = widget.conversationType == 2
          ? DisplayNameStore.instance.group(widget.conversationID)
          : DisplayNameStore.instance.c2c(widget.conversationID);
      final name = cached?.trim().isNotEmpty == true
          ? cached!.trim()
          : widget.conversationShowName;
      if (name.isNotEmpty) {
        setState(() {
          _conversationShowName = name;
        });
      } else {
        updateTitleFuture();
      }
    }
    if (oldWidget.conversationID != widget.conversationID ||
        oldWidget.conversationType != widget.conversationType) {
      _onDisplayNameChanged();
    }
  }

  void updateTitleFuture() async {
    final cached = DisplayNameStore.instance.c2c(widget.conversationID) ??
        DisplayNameStore.instance.group(widget.conversationID);
    if (cached != null && cached.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _conversationShowName = cached.trim();
        });
      }
      return;
    }
    try {
      final res = await _friendshipServices
          .getFriendsInfo(userIDList: [widget.conversationID]);
      if (res != null && res.isNotEmpty && res.first.resultCode == 0) {
        if (!mounted) {
          return;
        }
        final friendInfo = res.first.friendInfo;
        final remark = friendInfo?.friendRemark?.trim() ?? '';
        final nick = friendInfo?.userProfile?.nickName?.trim() ?? '';
        final uid = friendInfo?.userID?.trim() ?? widget.conversationID;
        final text = remark.isNotEmpty
            ? remark
            : (nick.isNotEmpty ? nick : uid);
        DisplayNameStore.instance.setC2C(uid, text, notify: false);
        setState(() {
          _conversationShowName = text;
        });
      }
      // ignore: empty_catches
    } catch (e) {}
  }

  Widget _buildMultiSelectCancelButton(
    TUITheme theme,
    TUIChatSeparateViewModel chatVM,
  ) {
    final color = theme.chatHeaderBackTextColor ??
        theme.appbarTextColor ??
        theme.primaryColor ??
        hexToColor('010000');
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {
          chatVM.updateMultiSelectStatus(false);
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
          foregroundColor: color,
        ),
        child: Text(
          TIM_t('取消'),
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            height: 1.15,
          ),
        ),
      ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;

    final setAppbar = widget.config;
    final TUIChatSeparateViewModel chatVM =
        Provider.of<TUIChatSeparateViewModel>(context);
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    return Selector2<ChatUiStateStore, TUIChatGlobalModel,
        Tuple3<bool, int, int>>(
      shouldRebuild: (prev, next) =>
          prev.item1 != next.item1 ||
          prev.item2 != next.item2 ||
          prev.item3 != next.item3,
      selector: (_, uiStateStore, model) => Tuple3(
            uiStateStore.isMultiSelect(widget.conversationID),
            model.totalUnReadCount,
            uiStateStore.selectedCount(widget.conversationID),
          ),
      builder: (context, data, _) {
        final isMultiSelect = data.item1;
        final unReadCount = data.item2;
        final selectedCount = data.item3;
        final showMultiSelectChrome = !isDesktopScreen && isMultiSelect;
        final selectedCountLabel = '$selectedCount';
        final titleColor = theme.chatHeaderTitleTextColor ??
            theme.appbarTextColor ??
            hexToColor("010000");
        return AppBar(
          backgroundColor: setAppbar?.backgroundColor ??
              theme.chatHeaderBgColor ??
              theme.appbarBgColor ??
              theme.primaryColor,
          actionsIconTheme: setAppbar?.actionsIconTheme,
          foregroundColor: setAppbar?.foregroundColor,
          elevation: setAppbar?.elevation ?? (isDesktopScreen ? 0 : 1),
          scrolledUnderElevation: setAppbar?.scrolledUnderElevation,
          surfaceTintColor: setAppbar?.surfaceTintColor,
          bottom: setAppbar?.bottom,
          bottomOpacity: setAppbar?.bottomOpacity ?? 1.0,
          titleSpacing: showMultiSelectChrome
              ? 0
              : setAppbar?.titleSpacing,
          automaticallyImplyLeading:
              setAppbar?.automaticallyImplyLeading ?? false,
          shadowColor: setAppbar?.shadowColor ?? theme.weakDividerColor,
          excludeHeaderSemantics: setAppbar?.excludeHeaderSemantics ?? false,
          toolbarHeight: setAppbar?.toolbarHeight,
          titleTextStyle: setAppbar?.titleTextStyle,
          toolbarOpacity: setAppbar?.toolbarOpacity ?? 1.0,
          toolbarTextStyle: setAppbar?.toolbarTextStyle,
          iconTheme: setAppbar?.iconTheme ??
              const IconThemeData(
                color: Colors.white,
              ),
          title: showMultiSelectChrome
              ? Text(
                  selectedCount <= 0
                      ? TIM_t('选择消息')
                      : TIM_t_para(
                          '已选择{{option1}}条',
                          '已选择$selectedCountLabel条',
                        )(option1: selectedCountLabel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : TIMUIKitAppBarTitle(
                  title: setAppbar?.title,
                  onClick: widget.onClickTitle,
                  textStyle: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                  ),
                  conversationShowName: _conversationShowName,
                  showC2cMessageEditStatus: widget.showC2cMessageEditStatus,
                  fromUser: widget.conversationID,
                ),
          centerTitle: showMultiSelectChrome
              ? true
              : (setAppbar?.centerTitle ?? (isDesktopScreen ? false : true)),
          // 聊天页默认 leadingWidth=48 给返回键；「取消」文案比箭头宽，不能沿用，否则被裁切。
          leadingWidth: showMultiSelectChrome
              ? 88
              : (setAppbar?.leadingWidth ?? (isDesktopScreen ? 8 : 70)),
          leading: showMultiSelectChrome
              ? _buildMultiSelectCancelButton(theme, chatVM)
              : setAppbar?.leading ??
                  (isDesktopScreen
                      ? Container()
                      : Row(
                          children: [
                            IconButton(
                              padding: const EdgeInsets.only(left: 16),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.arrow_back_ios,
                                color: theme.chatHeaderBackTextColor ??
                                    theme.primaryColor ??
                                    hexToColor("010000"),
                                size: 17,
                              ),
                              onPressed: () async {
                                chatVM.repliedMessage = null;
                                Navigator.pop(context);
                              },
                            ),
                            if (widget.showTotalUnReadCount && unReadCount > 0)
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.cautionColor,
                                ),
                                child: Text(_getTotalUnReadCount(unReadCount)),
                              ),
                          ],
                        )),
          actions: showMultiSelectChrome
              ? const <Widget>[
                  SizedBox(width: 88),
                ]
              : setAppbar?.actions,
        );
      },
    );
  }
}
