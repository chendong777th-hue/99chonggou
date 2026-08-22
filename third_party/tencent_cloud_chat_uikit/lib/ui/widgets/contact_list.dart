import 'package:azlistview_all_platforms/azlistview_all_platforms.dart';
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/az_list_view.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/radio_button.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 建群 / 邀请 / 批量选好友时，单次最多勾选人数。
const int kContactListMaxGroupSelection = 100;

class ContactList extends StatefulWidget {
  final List<V2TimFriendInfo> contactList;
  final bool isCanSelectMemberItem;
  final bool isCanSlidableDelete;
  final Function(List<V2TimFriendInfo> selectedMember)?
      onSelectedMemberItemChange;
  final Function()? handleSlidableDelte;
  final Color? bgColor;

  /// 选中态解析与 reconcile 使用的完整联系人列表。
  /// 当 [contactList] 仅为搜索/筛选结果时，应传入全量列表以避免选中项被误清。
  final List<V2TimFriendInfo>? selectionContactList;

  /// tap联系人列表项回调
  final void Function(V2TimFriendInfo item)? onTapItem;

  /// 顶部列表
  final List<TopListItem>? topList;

  /// 顶部列表项构造器
  final Widget? Function(TopListItem item)? topListItemBuilder;

  /// Control if shows the online status for each user on its avatar.
  final bool isShowOnlineStatus;

  final int? maxSelectNum;

  final List<V2TimGroupMemberFullInfo?>? groupMemberList;

  /// the builder for the empty item, especially when there is no contact
  final Widget Function(BuildContext context)? emptyBuilder;

  final String? currentItem;

  final MemberPresenceLabelBuilder? presenceLabelBuilder;
  final MemberPresenceLoadingChecker? presenceLoadingChecker;
  final void Function(List<String> userIds)? onContactListLoaded;
  final Listenable? presenceListenable;

  /// 额外禁用（如进群审核中），与 [groupMemberList] 叠加。
  final Set<String>? disabledUserIds;

  /// 列表项右侧状态文案（如「进群审核中」）。
  final String? Function(String userId)? trailingStatusLabelBuilder;

  /// 初始勾选的用户 ID（如从单聊设置发起建群时预选当前好友）。
  final List<String>? initialSelectedUserIds;

  const ContactList({
    Key? key,
    required this.contactList,
    this.isCanSelectMemberItem = false,
    this.onSelectedMemberItemChange,
    this.isCanSlidableDelete = false,
    this.handleSlidableDelte,
    this.onTapItem,
    this.bgColor,
    this.selectionContactList,
    this.topList,
    this.topListItemBuilder,
    this.isShowOnlineStatus = false,
    this.maxSelectNum,
    this.groupMemberList,
    this.emptyBuilder,
    this.currentItem,
    this.presenceLabelBuilder,
    this.presenceLoadingChecker,
    this.onContactListLoaded,
    this.presenceListenable,
    this.disabledUserIds,
    this.trailingStatusLabelBuilder,
    this.initialSelectedUserIds,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => ContactListState();
}

class ContactListState extends TIMUIKitState<ContactList> {
  final Set<String> _selectedUserIds = {};
  final List<String> _selectedUserIdOrder = [];
  final TUIFriendShipViewModel friendShipViewModel =
      serviceLocator<TUIFriendShipViewModel>();

  bool get _showsPresence =>
      widget.isShowOnlineStatus || widget.presenceLabelBuilder != null;

  String? _normalizeUserId(String userId) {
    final id = userId.trim();
    return id.isEmpty ? null : id;
  }

  bool _isSelected(V2TimFriendInfo item) {
    final id = _normalizeUserId(item.userID);
    if (id == null) {
      return false;
    }
    return _selectedUserIds.contains(id);
  }

  List<V2TimFriendInfo> get _selectionSourceList =>
      widget.selectionContactList ?? widget.contactList;

  List<V2TimFriendInfo> _selectedFriends() {
    if (_selectedUserIdOrder.isEmpty) {
      return const [];
    }
    final byId = <String, V2TimFriendInfo>{
      for (final friend in _selectionSourceList)
        if (_normalizeUserId(friend.userID) case final id?) id: friend,
    };
    final selected = <V2TimFriendInfo>[];
    for (final id in _selectedUserIdOrder) {
      final friend = byId[id];
      if (friend != null) {
        selected.add(friend);
      }
    }
    return selected;
  }

  void _notifySelectionChanged() {
    widget.onSelectedMemberItemChange?.call(_selectedFriends());
  }

  void _setSingleSelection(V2TimFriendInfo item) {
    final id = _normalizeUserId(item.userID);
    if (id == null) {
      return;
    }
    _selectedUserIds
      ..clear()
      ..add(id);
    _selectedUserIdOrder
      ..clear()
      ..add(id);
  }

  void _applySelectionChange() {
    _notifySelectionChanged();
    setState(() {});
  }

  void _setSelection(V2TimFriendInfo item, bool checked) {
    final id = _normalizeUserId(item.userID);
    if (id == null) {
      return;
    }

    if (checked) {
      if (_selectedUserIds.contains(id)) {
        return;
      }
      if (selectedMemberIsOverFlow()) {
        if (widget.maxSelectNum == 1) {
          _setSingleSelection(item);
          _applySelectionChange();
        }
        return;
      }
      _selectedUserIds.add(id);
      _selectedUserIdOrder.add(id);
    } else {
      if (!_selectedUserIds.contains(id)) {
        return;
      }
      _selectedUserIds.remove(id);
      _selectedUserIdOrder.remove(id);
    }
    _applySelectionChange();
  }

  void _toggleSelection(V2TimFriendInfo item) {
    _setSelection(item, !_isSelected(item));
  }

  bool _isMemberOfGroup(String userId) {
    final list = widget.groupMemberList;
    if (list == null || list.isEmpty) {
      return false;
    }
    final target = _normalizeUserId(userId);
    if (target == null) {
      return false;
    }
    return list.indexWhere((element) {
          final id = _normalizeUserId(element?.userID ?? '');
          return id != null && id == target;
        }) >
        -1;
  }

  bool _isExtraDisabled(String userId) {
    final disabled = widget.disabledUserIds;
    if (disabled == null || disabled.isEmpty) {
      return false;
    }
    final target = _normalizeUserId(userId);
    if (target == null) {
      return false;
    }
    if (disabled.contains(target)) {
      return true;
    }
    for (final item in disabled) {
      final id = _normalizeUserId(item);
      if (id != null && id == target) {
        return true;
      }
    }
    return false;
  }

  bool _isSelectable(V2TimFriendInfo item) {
    final id = _normalizeUserId(item.userID);
    if (id == null) {
      return false;
    }
    return !_isMemberOfGroup(id) && !_isExtraDisabled(id);
  }

  List<V2TimFriendInfo> _selectableContacts() {
    return widget.contactList.where(_isSelectable).toList(growable: false);
  }

  bool get areAllSelectableSelected {
    final selectable = _selectableContacts();
    if (selectable.isEmpty) {
      return false;
    }
    return selectable.every(_isSelected);
  }

  void selectAllSelectable() {
    final selectable = _selectableContacts();
    if (selectable.isEmpty) {
      return;
    }
    var changed = false;
    for (final item in selectable) {
      final id = _normalizeUserId(item.userID);
      if (id == null || _selectedUserIds.contains(id)) {
        continue;
      }
      if (widget.maxSelectNum != null &&
          _selectedUserIds.length >= widget.maxSelectNum!) {
        break;
      }
      _selectedUserIds.add(id);
      _selectedUserIdOrder.add(id);
      changed = true;
    }
    if (changed) {
      _applySelectionChange();
    }
  }

  void clearSelection() {
    if (_selectedUserIds.isEmpty) {
      return;
    }
    _selectedUserIds.clear();
    _selectedUserIdOrder.clear();
    _applySelectionChange();
  }

  void deselectByUserId(String userId) {
    final id = _normalizeUserId(userId);
    if (id == null || !_selectedUserIds.contains(id)) {
      return;
    }
    _selectedUserIds.remove(id);
    _selectedUserIdOrder.remove(id);
    _applySelectionChange();
  }

  bool _listEqualsStrings(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  void _reconcileSelectionWithContactList() {
    final previousOrder = List<String>.from(_selectedUserIdOrder);
    final available = _selectionSourceList
        .map((item) => _normalizeUserId(item.userID))
        .whereType<String>()
        .toSet();
    _selectedUserIds.removeWhere((id) => !available.contains(id));
    _selectedUserIdOrder.removeWhere((id) => !available.contains(id));
    final selectionChanged =
        previousOrder.length != _selectedUserIdOrder.length ||
            !_listEqualsStrings(previousOrder, _selectedUserIdOrder);
    if (!mounted || !selectionChanged) {
      return;
    }
    setState(() {});
    if (widget.isCanSelectMemberItem) {
      _notifySelectionChanged();
    }
  }

  @override
  void initState() {
    super.initState();
    _seedInitialSelection();
    _schedulePresenceLoad();
  }

  void _seedInitialSelection() {
    final initials = widget.initialSelectedUserIds;
    if (initials == null || initials.isEmpty || !widget.isCanSelectMemberItem) {
      return;
    }
    var changed = false;
    for (final raw in initials) {
      final id = _normalizeUserId(raw);
      if (id == null || _selectedUserIds.contains(id)) {
        continue;
      }
      if (widget.maxSelectNum != null &&
          _selectedUserIds.length >= widget.maxSelectNum!) {
        break;
      }
      _selectedUserIds.add(id);
      _selectedUserIdOrder.add(id);
      changed = true;
    }
    if (!changed) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _notifySelectionChanged();
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(ContactList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contactList != widget.contactList ||
        oldWidget.selectionContactList != widget.selectionContactList) {
      _reconcileSelectionWithContactList();
      _schedulePresenceLoad();
    }
    if (oldWidget.disabledUserIds != widget.disabledUserIds ||
        oldWidget.groupMemberList != widget.groupMemberList) {
      _deselectBlockedUsers();
    }
  }

  void _deselectBlockedUsers() {
    final blocked = <String>{};
    for (final id in _selectedUserIds) {
      if (_isMemberOfGroup(id) || _isExtraDisabled(id)) {
        blocked.add(id);
      }
    }
    if (blocked.isEmpty) {
      return;
    }
    _selectedUserIds.removeAll(blocked);
    _selectedUserIdOrder.removeWhere(blocked.contains);
    _applySelectionChange();
  }

  void _schedulePresenceLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ids = widget.contactList
          .map((item) => item.userID.trim())
          .where((id) => id.isNotEmpty)
          .toList();
      if (ids.isEmpty) return;
      widget.onContactListLoaded?.call(ids);
    });
  }

  V2TimUserStatus? _onlineStatusOf(String userId) {
    for (final status in friendShipViewModel.userStatusList) {
      if (status.userID == userId) {
        return status;
      }
    }
    return null;
  }

  String _presenceLabel(String userId, bool imOnline) {
    final builder = widget.presenceLabelBuilder;
    if (builder != null) {
      return builder(userId, imOnline);
    }
    return imOnline ? TIM_t("在线") : TIM_t("离线");
  }

  Color _listBackgroundColor(TUITheme theme) {
    return widget.bgColor ??
        theme.weakBackgroundColor ??
        theme.wideBackgroundColor ??
        Colors.transparent;
  }

  String _getShowName(V2TimFriendInfo item) {
    return memberDisplayName(
      friendRemark: item.friendRemark,
      nickName: item.userProfile?.nickName,
      userID: item.userID,
    );
  }

  List<ISuspensionBeanImpl> _getShowList(List<V2TimFriendInfo> memberList) {
    final List<ISuspensionBeanImpl> showList = List.empty(growable: true);
    for (var i = 0; i < memberList.length; i++) {
      final item = memberList[i];
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

  bool selectedMemberIsOverFlow() {
    if (widget.maxSelectNum == null) {
      return false;
    }

    return _selectedUserIds.length >= widget.maxSelectNum!;
  }

  Widget _buildItem(TUITheme theme, V2TimFriendInfo item) {
    if (!_showsPresence) {
      return _buildItemContent(theme, item);
    }
    return AnimatedBuilder(
      animation: Listenable.merge([
        friendShipViewModel,
        if (widget.presenceListenable != null) widget.presenceListenable!,
      ]),
      builder: (context, _) => _buildItemContent(theme, item),
    );
  }

  Widget _buildItemContent(TUITheme theme, V2TimFriendInfo item) {
    final showName = _getShowName(item);
    final faceUrl = item.userProfile?.faceUrl ?? "";

    final V2TimUserStatus? onlineStatus =
        _showsPresence ? _onlineStatusOf(item.userID) : null;
    final imOnline = onlineStatus?.statusType == 1;
    final presenceLoading = _showsPresence &&
        (widget.presenceLoadingChecker?.call(item.userID, imOnline) ?? false);
    final presenceLabel = _showsPresence && !presenceLoading
        ? _presenceLabel(item.userID, imOnline)
        : '';

    final disabled =
        _isMemberOfGroup(item.userID) || _isExtraDisabled(item.userID);
    final atSelectionLimit = widget.maxSelectNum != null &&
        _selectedUserIds.length >= widget.maxSelectNum! &&
        !_isSelected(item);
    final selectionBlocked = disabled || atSelectionLimit;
    final trailingStatus =
        widget.trailingStatusLabelBuilder?.call(item.userID)?.trim() ?? '';

    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final subtitleFontSize = isDesktopScreen ? 12.0 : 12.0;
    final avatarSize = isDesktopScreen ? 40.0 : 40.0;
    final horizontalPadding = isDesktopScreen ? 20.0 : 16.0;
    final verticalPadding = isDesktopScreen ? 10.0 : 6.0;

    final avatarAndText = Row(
      children: [
        SizedBox(
          height: avatarSize,
          width: avatarSize,
          child: Avatar(
            onlineStatus: onlineStatus,
            faceUrl: faceUrl,
            showName: showName,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: isDesktopScreen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      showName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.darkTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_showsPresence) ...[
                      const SizedBox(height: 2),
                      if (presenceLoading)
                        buildMemberPresenceSubtitleSkeleton(
                          baseColor: theme.weakTextColor,
                          lineHeight: subtitleFontSize * 1.1,
                        )
                      else if (presenceLabel.isNotEmpty)
                        Text(
                          presenceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.weakTextColor ??
                                CommonColor.weakTextColor,
                            fontSize: subtitleFontSize,
                            height: 1.1,
                          ),
                        ),
                    ],
                  ],
                )
              : Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.weakDividerColor ??
                            CommonColor.weakDividerColor,
                      ),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(top: 8, bottom: 14, right: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              showName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.darkTextColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_showsPresence) ...[
                              const SizedBox(height: 2),
                              if (presenceLoading)
                                buildMemberPresenceSubtitleSkeleton(
                                  baseColor: theme.weakTextColor,
                                  lineHeight: subtitleFontSize * 1.1,
                                )
                              else if (presenceLabel.isNotEmpty)
                                Text(
                                  presenceLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.weakTextColor ??
                                        CommonColor.weakTextColor,
                                    fontSize: subtitleFontSize,
                                    height: 1.1,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      if (trailingStatus.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primaryColor ?? CommonColor.primaryColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            trailingStatus,
                            style: TextStyle(
                              color: theme.white ?? Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        if (isDesktopScreen && trailingStatus.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (theme.primaryColor ?? CommonColor.primaryColor)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              trailingStatus,
              style: TextStyle(
                color: theme.primaryColor ?? CommonColor.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
      ],
    );

    return Container(
      color: _listBackgroundColor(theme),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        isDesktopScreen ? 16 : 12,
        verticalPadding,
      ),
      child: Row(
        children: [
          if (widget.isCanSelectMemberItem)
            Padding(
              padding: EdgeInsets.only(right: isDesktopScreen ? 4 : 10),
              child: isDesktopScreen
                  ? Checkbox(
                      value: _isSelected(item),
                      onChanged: selectionBlocked
                          ? null
                          : (checked) =>
                              _setSelection(item, checked ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      activeColor: theme.primaryColor ?? CommonColor.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
                  : CheckBoxButton(
                      disabled: selectionBlocked,
                      isChecked: _isSelected(item),
                      onChanged: selectionBlocked
                          ? null
                          : (isChecked) =>
                              _setSelection(item, isChecked),
                    ),
            ),
          if (widget.isCanSelectMemberItem)
            Expanded(
              child: InkWell(
                onTap: selectionBlocked ? null : () => _toggleSelection(item),
                child: avatarAndText,
              ),
            )
          else if (widget.onTapItem != null)
            Expanded(
              child: InkWell(
                onTap: () => widget.onTapItem!(item),
                child: avatarAndText,
              ),
            )
          else
            Expanded(child: avatarAndText),
        ],
      ),
    );
  }

  Widget generateTopItem(TUITheme theme, memberInfo) {
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    if (widget.topListItemBuilder != null) {
      final customWidget = widget.topListItemBuilder!(memberInfo);
      if (customWidget != null) {
        return customWidget;
      }
    }
    return InkWell(
        onTap: () {
          if (memberInfo.onTap != null) {
            memberInfo.onTap!();
          }
        },
        child: Container(
          color: _listBackgroundColor(theme),
          padding: const EdgeInsets.only(top: 6, left: 16),
          child: Row(
            children: [
              Container(
                height: isDesktopScreen ? 30 : 40,
                width: isDesktopScreen ? 30 : 40,
                margin: const EdgeInsets.only(right: 10, bottom: 8),
                child: memberInfo.icon,
              ),
              Expanded(
                  child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.weakDividerColor ?? hexToColor("DBDBDB"),
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 8, bottom: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      memberInfo.name,
                      style: TextStyle(
                        color: theme.darkTextColor ?? hexToColor("111111"),
                        fontSize: isDesktopScreen ? 14 : 16,
                      ),
                    ),
                    Expanded(child: Container()),
                  ],
                ),
              ))
            ],
          ),
        ));
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;

    final showList = _getShowList(widget.contactList);

    if (widget.topList != null && widget.topList!.isNotEmpty) {
      final topList = widget.topList!
          .map((e) => ISuspensionBeanImpl(memberInfo: e, tagIndex: '@'))
          .toList();
      showList.insertAll(0, topList);
    }

    if (widget.contactList.isEmpty) {
      return Column(
        children: [
          ...showList.map((e) => generateTopItem(theme, e.memberInfo)).toList(),
          Expanded(
              child: widget.emptyBuilder != null
                  ? widget.emptyBuilder!(context)
                  : Container())
        ],
      );
    }

    return AZListViewContainer(
      memberList: showList,
      itemBuilder: (context, index) {
        final memberInfo = showList[index].memberInfo;
        if (memberInfo is TopListItem) {
          return generateTopItem(theme, memberInfo);
        } else {
          return Material(
            color: widget.currentItem == memberInfo.userID
                ? theme.conversationItemChooseBgColor
                : _listBackgroundColor(theme),
            child: _buildItem(theme, memberInfo),
          );
        }
      },
    );
  }
}

class TopListItem {
  final String name;
  final String id;
  final Widget? icon;
  final Function()? onTap;

  TopListItem({required this.name, required this.id, this.icon, this.onTap});
}
