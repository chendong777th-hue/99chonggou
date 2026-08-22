// ignore_for_file: must_be_immutable

import 'package:azlistview_all_platforms/azlistview_all_platforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable_plus_plus/flutter_slidable_plus_plus.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/profile/user_profile_local_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/az_list_view.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/radio_button.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme_view_model.dart';

class GroupProfileMemberList extends StatefulWidget {
  static String AT_ALL_USER_ID = "__kImSDK_MesssageAtALL__";
  final List<V2TimGroupMemberFullInfo?> memberList;
  final Function(String userID)? removeMember;
  final bool canSlideDelete;
  final bool canSelectMember;
  final bool canAtAll;

  // when the @ need filter some group types
  final String? groupType;
  final Function(List<V2TimGroupMemberFullInfo> selectedMember)? onSelectedMemberChange;
  // notice: onTapMemberItem and onSelectedMemberChange use together will triger together
  final Function(V2TimGroupMemberFullInfo memberInfo, TapDownDetails? tapDetails)? onTapMemberItem;
  // When sliding to the bottom bar callBack
  final Function()? touchBottomCallBack;

  final int? maxSelectNum;

  final MemberPresenceLabelBuilder? presenceLabelBuilder;
  final MemberPresenceLoadingChecker? presenceLoadingChecker;
  final MemberPresenceOnlineResolver? presenceOnlineResolver;
  final void Function(List<String> userIds)? onMemberListLoaded;
  final Listenable? presenceListenable;

  /// 列表为空时自定义占位（如搜索无结果）；未传则显示「暂无群成员」。
  final WidgetBuilder? emptyBuilder;

  /// 右侧 26 字母索引条；关闭时同步隐藏 A/B/C 分组头。
  final bool isShowIndexBar;

  Widget? customTopArea;

  GroupProfileMemberList({
    Key? key,
    required this.memberList,
    this.groupType,
    this.removeMember,
    this.canSlideDelete = true,
    this.canSelectMember = false,
    this.canAtAll = false,
    this.onSelectedMemberChange,
    this.onTapMemberItem,
    this.customTopArea,
    this.touchBottomCallBack,
    this.maxSelectNum,
    this.presenceLabelBuilder,
    this.presenceLoadingChecker,
    this.presenceOnlineResolver,
    this.onMemberListLoaded,
    this.presenceListenable,
    this.emptyBuilder,
    this.isShowIndexBar = true,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _GroupProfileMemberListState();
}

class _GroupProfileMemberListState extends TIMUIKitState<GroupProfileMemberList> {
  final TUIFriendShipViewModel _friendShipModel =
      serviceLocator<TUIFriendShipViewModel>();
  final Set<String> _selectedUserIds = {};
  final List<String> _selectedUserIdOrder = [];
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  DateTime? _lastLoadMoreAt;
  static const _loadMoreCooldown = Duration(milliseconds: 600);
  static const _nearBottomThreshold = 5;

  String? _normalizeUserId(String userId) {
    final id = userId.trim();
    return id.isEmpty ? null : id;
  }

  bool _isSelected(V2TimGroupMemberFullInfo member) {
    final id = _normalizeUserId(member.userID);
    if (id == null) {
      return false;
    }
    return _selectedUserIds.contains(id);
  }

  List<V2TimGroupMemberFullInfo> _selectedMembers() {
    if (_selectedUserIdOrder.isEmpty) {
      return const [];
    }
    final byId = <String, V2TimGroupMemberFullInfo>{};
    for (final member in widget.memberList) {
      if (member == null) {
        continue;
      }
      final id = _normalizeUserId(member.userID);
      if (id != null) {
        byId[id] = member;
      }
    }
    final selected = <V2TimGroupMemberFullInfo>[];
    for (final id in _selectedUserIdOrder) {
      final member = byId[id];
      if (member != null) {
        selected.add(member);
      } else if (_isAtAllMember(id)) {
        selected.add(
          V2TimGroupMemberFullInfo(
            userID: GroupProfileMemberList.AT_ALL_USER_ID,
            nickName: TIM_t("所有人"),
          ),
        );
      }
    }
    return selected;
  }

  void _notifySelectionChanged() {
    widget.onSelectedMemberChange?.call(_selectedMembers());
  }

  void _applySelectionChange() {
    _notifySelectionChanged();
    setState(() {});
  }

  void _setSelection(V2TimGroupMemberFullInfo member, bool checked) {
    final id = _normalizeUserId(member.userID);
    if (id == null) {
      return;
    }

    if (checked) {
      if (_selectedUserIds.contains(id)) {
        return;
      }
      if (widget.maxSelectNum != null &&
          _selectedUserIds.length >= widget.maxSelectNum!) {
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

  void _toggleSelection(V2TimGroupMemberFullInfo member) {
    _setSelection(member, !_isSelected(member));
  }

  void _reconcileSelectionWithMemberList() {
    final previousOrder = List<String>.from(_selectedUserIdOrder);
    final available = widget.memberList
        .whereType<V2TimGroupMemberFullInfo>()
        .map((member) => _normalizeUserId(member.userID))
        .whereType<String>()
        .toSet();
    _selectedUserIds.removeWhere((id) => !available.contains(id));
    _selectedUserIdOrder.removeWhere((id) => !available.contains(id));
    final selectionChanged = previousOrder.length != _selectedUserIdOrder.length ||
        !_listEqualsStrings(previousOrder, _selectedUserIdOrder);
    if (!mounted || !selectionChanged) {
      return;
    }
    setState(() {});
    if (widget.canSelectMember) {
      _notifySelectionChanged();
    }
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

  bool _sameMemberList(
    List<V2TimGroupMemberFullInfo?> a,
    List<V2TimGroupMemberFullInfo?> b,
  ) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i]?.userID != b[i]?.userID || a[i]?.role != b[i]?.role) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    widget.presenceListenable?.addListener(_onPresenceChanged);
    UserProfileLocalBridge.changeListenable?.addListener(_onPresenceChanged);
    _itemPositionsListener.itemPositions.addListener(_onItemPositionsChanged);
    _schedulePresenceLoad();
  }

  @override
  void didUpdateWidget(GroupProfileMemberList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presenceListenable != widget.presenceListenable) {
      oldWidget.presenceListenable?.removeListener(_onPresenceChanged);
      widget.presenceListenable?.addListener(_onPresenceChanged);
    }
    if (!_sameMemberList(oldWidget.memberList, widget.memberList)) {
      _reconcileSelectionWithMemberList();
    }
    if (!_sameMemberList(oldWidget.memberList, widget.memberList) ||
        oldWidget.onMemberListLoaded != widget.onMemberListLoaded) {
      _schedulePresenceLoad();
    }
    // 首页未铺满时也尝试续页。
    if (!_sameMemberList(oldWidget.memberList, widget.memberList)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _onItemPositionsChanged();
        }
      });
    }
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onItemPositionsChanged);
    widget.presenceListenable?.removeListener(_onPresenceChanged);
    UserProfileLocalBridge.changeListenable?.removeListener(_onPresenceChanged);
    super.dispose();
  }

  void _onItemPositionsChanged() {
    if (widget.touchBottomCallBack == null) {
      return;
    }
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) {
      return;
    }
    final showCount = _getShowList(widget.memberList).length;
    if (showCount <= 0) {
      return;
    }
    var maxIndex = 0;
    for (final position in positions) {
      if (position.index > maxIndex) {
        maxIndex = position.index;
      }
    }
    if (maxIndex >= showCount - _nearBottomThreshold) {
      _triggerLoadMore();
    }
  }

  void _triggerLoadMore() {
    final cb = widget.touchBottomCallBack;
    if (cb == null) {
      return;
    }
    final now = DateTime.now();
    final last = _lastLoadMoreAt;
    if (last != null && now.difference(last) < _loadMoreCooldown) {
      return;
    }
    _lastLoadMoreAt = now;
    cb();
  }

  void _onScrollNotification(ScrollNotification notification) {
    final maxExtent = notification.metrics.maxScrollExtent;
    if (maxExtent <= 0) {
      return;
    }
    final progress = notification.metrics.pixels / maxExtent;
    if (progress >= 0.9) {
      _triggerLoadMore();
    }
  }

  void _onPresenceChanged() {
    if (mounted) setState(() {});
  }

  bool _isAtAllMember(String userId) => userId == GroupProfileMemberList.AT_ALL_USER_ID;

  void _schedulePresenceLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ids = widget.memberList
          .whereType<V2TimGroupMemberFullInfo>()
          .map((member) => member.userID.trim())
          .where((id) => id.isNotEmpty && !_isAtAllMember(id))
          .toList();
      if (ids.isEmpty) return;
      widget.onMemberListLoaded?.call(ids);
    });
  }

  String _getShowName(V2TimGroupMemberFullInfo? item) {
    return memberDisplayName(
      friendRemark: item?.friendRemark,
      nameCard: item?.nameCard,
      nickName: item?.nickName,
      userID: item?.userID,
    );
  }

  bool _isSelfMember(String userId) {
    final id = userId.trim();
    final self =
        serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID?.trim() ?? '';
    return id.isNotEmpty && self.isNotEmpty && id == self;
  }

  V2TimUserStatus? _getOnlineStatus(V2TimGroupMemberFullInfo memberInfo) {
    final userId = memberInfo.userID;
    if (userId.isEmpty) {
      return null;
    }
    if (_isSelfMember(userId)) {
      return V2TimUserStatus(userID: userId, statusType: 1);
    }
    for (final status in _friendShipModel.userStatusList) {
      if (status.userID == userId) {
        return status;
      }
    }
    return null;
  }

  bool _isMemberOnline(V2TimUserStatus? status, String userId) {
    return _isSelfMember(userId) || status?.statusType == 1;
  }

  String _getStatusLabel(bool imOnline, String userId) {
    final builder = widget.presenceLabelBuilder;
    if (builder != null) {
      return builder(userId, imOnline);
    }
    return imOnline ? TIM_t("在线") : TIM_t("离线");
  }

  int _roleSortRank(int? role) => GroupRolePolicy.memberSortRank(role);

  List<ISuspensionBeanImpl> _getShowList(List<V2TimGroupMemberFullInfo?> memberList) {
    final List<ISuspensionBeanImpl> showList = List.empty(growable: true);
    for (var i = 0; i < memberList.length; i++) {
      final item = memberList[i];
      final showName = _getShowName(item);
      if (GroupRolePolicy.isManagerRole(item?.role)) {
        showList.add(ISuspensionBeanImpl(memberInfo: item, tagIndex: "@"));
      } else {
        showList.add(
          ISuspensionBeanImpl(
            memberInfo: item,
            tagIndex: memberSuspensionIndexTag(showName),
          ),
        );
      }
    }

    // 「群主、管理员」分区置顶；区内：群主 → 管理员
    showList.sort((a, b) {
      final tagA = a.tagIndex;
      final tagB = b.tagIndex;
      if (tagA == "@" && tagB != "@") {
        return -1;
      }
      if (tagB == "@" && tagA != "@") {
        return 1;
      }
      if (tagA == "#" && tagB != "#") {
        return 1;
      }
      if (tagB == "#" && tagA != "#") {
        return -1;
      }
      if (tagA == "@" && tagB == "@") {
        final byRole = _roleSortRank(a.memberInfo?.role).compareTo(
          _roleSortRank(b.memberInfo?.role),
        );
        if (byRole != 0) {
          return byRole;
        }
        return _getShowName(a.memberInfo).compareTo(_getShowName(b.memberInfo));
      }
      final byTag = tagA.compareTo(tagB);
      if (byTag != 0) {
        return byTag;
      }
      return _getShowName(a.memberInfo).compareTo(_getShowName(b.memberInfo));
    });

    // add @everyone item
    if (widget.canAtAll) {
      final canAtGroupType = ["Work", "Public", "Meeting", "Community"];
      if (canAtGroupType.contains(widget.groupType)) {
        showList.insert(
            0,
            ISuspensionBeanImpl(
                memberInfo:
                    V2TimGroupMemberFullInfo(userID: GroupProfileMemberList.AT_ALL_USER_ID, nickName: TIM_t("所有人")),
                tagIndex: ""));
      }
    }

    return showList;
  }

  Widget? _buildRoleBadge(
    TUITheme theme,
    int? role, {
    required bool isDesktopScreen,
  }) {
    final badgeKey = GroupRolePolicy.roleBadgeKey(role);
    if (badgeKey == null) {
      return null;
    }
    final primary = theme.primaryColor ?? CommonColor.primaryColor;
    if (isDesktopScreen) {
      if (badgeKey == 'owner') {
        return Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            TIM_t("群主"),
            style: TextStyle(
              color: primary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        );
      }
      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9500).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          TIM_t("管理员"),
          style: const TextStyle(
            color: Color(0xFFB86E00),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      );
    }
    if (badgeKey == 'owner') {
      return Container(
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: primary,
          borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        ),
        child: Text(
          TIM_t("群主"),
          style: TextStyle(
            color: theme.white ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.infoColor ?? CommonColor.infoColor,
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
      ),
      child: Text(
        TIM_t("管理员"),
        style: TextStyle(
          color: theme.white ?? Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildListItem(BuildContext context, V2TimGroupMemberFullInfo memberInfo) {
    final theme = Provider.of<TUIThemeViewModel>(context).theme;
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor() == DeviceType.Desktop;
    final isGroupMember = memberInfo.role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
    final itemBackgroundColor =
        theme.conversationItemBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final avatarSize = isDesktopScreen ? 36.0 : 44.0;
    final titleFontSize = isDesktopScreen ? 14.0 : 16.0;
    final subtitleFontSize = isDesktopScreen ? 12.0 : 12.0;
    final horizontalPadding = isDesktopScreen ? 20.0 : 16.0;
    final verticalPadding = isDesktopScreen ? 8.0 : 8.0;
    return AnimatedBuilder(
      animation: Listenable.merge([
        _friendShipModel,
        if (widget.presenceListenable != null) widget.presenceListenable!,
      ]),
      builder: (context, _) {
        final onlineStatus = _getOnlineStatus(memberInfo);
        final userId = memberInfo.userID;
        final isAtAllMember = _isAtAllMember(userId);
        final imOnline = _isMemberOnline(onlineStatus, userId);
        final effectiveOnline = isAtAllMember
            ? false
            : (widget.presenceOnlineResolver?.call(userId, imOnline) ?? imOnline);
        final presenceLoading = !isAtAllMember &&
            (widget.presenceLoadingChecker?.call(userId, imOnline) ?? false);
        final statusLabel = isAtAllMember
            ? ''
            : (presenceLoading
                ? ''
                : _getStatusLabel(
                    widget.presenceLabelBuilder != null
                        ? imOnline
                        : effectiveOnline,
                    userId,
                  ));
        final avatarOnlineStatus = isAtAllMember
            ? null
            : (widget.presenceOnlineResolver != null
                ? V2TimUserStatus(
                    userID: userId,
                    statusType: effectiveOnline ? 1 : 0,
                  )
                : onlineStatus);
        final atSelectionLimit = widget.maxSelectNum != null &&
            _selectedUserIds.length >= widget.maxSelectNum! &&
            !_isSelected(memberInfo);
        final roleBadge = _buildRoleBadge(
          theme,
          memberInfo.role,
          isDesktopScreen: isDesktopScreen,
        );
        return Container(
            color: itemBackgroundColor,
            child: Slidable(
                endActionPane: widget.canSlideDelete && isGroupMember
                    ? ActionPane(motion: const DrawerMotion(), children: [
                        SlidableAction(
                          onPressed: (_) {
                            if (widget.removeMember != null) {
                              widget.removeMember!(memberInfo.userID);
                            }
                          },
                          flex: 1,
                          backgroundColor: theme.cautionColor ?? CommonColor.cautionColor,
                          autoClose: true,
                          label: TIM_t("删除"),
                        )
                      ])
                    : null,
                child: Column(children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (widget.canSelectMember)
                          Container(
                            margin: const EdgeInsets.only(right: 10),
                            child: CheckBoxButton(
                              disabled: atSelectionLimit,
                              onChanged: atSelectionLimit
                                  ? null
                                  : (isChecked) =>
                                      _setSelection(memberInfo, isChecked),
                              isChecked: _isSelected(memberInfo),
                            ),
                          ),
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: isDesktopScreen
                                  ? BorderRadius.circular(8)
                                  : BorderRadius.zero,
                              hoverColor: isDesktopScreen
                                  ? (theme.weakBackgroundColor ??
                                          const Color(0xFFF3F4F6))
                                      .withValues(alpha: 0.65)
                                  : null,
                              onTap: () {
                                if (widget.onTapMemberItem != null) {
                                  widget.onTapMemberItem!(memberInfo, null);
                                }
                                if (widget.canSelectMember &&
                                    (_isSelected(memberInfo) ||
                                        !atSelectionLimit)) {
                                  _toggleSelection(memberInfo);
                                }
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isDesktopScreen ? 4 : 0,
                                  vertical: isDesktopScreen ? 2 : 0,
                                ),
                                child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: avatarSize,
                                  height: avatarSize,
                                  child: Avatar(
                                    faceUrl: UserProfileLocalBridge.cachedAvatarUrl(
                                      memberInfo.userID,
                                      fallback: memberInfo.faceUrl,
                                    ),
                                    showName: _getShowName(memberInfo),
                                    type: 1,
                                    onlineStatus: avatarOnlineStatus,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                SizedBox(width: isDesktopScreen ? 10 : 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getShowName(memberInfo),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: titleFontSize,
                                          fontWeight: isDesktopScreen
                                              ? FontWeight.w500
                                              : FontWeight.w600,
                                          color: theme.darkTextColor,
                                          height: 1.25,
                                        ),
                                      ),
                                      if (presenceLoading ||
                                          statusLabel.isNotEmpty) ...[
                                        SizedBox(height: isDesktopScreen ? 2 : 3),
                                        if (presenceLoading)
                                          buildMemberPresenceSubtitleSkeleton(
                                            baseColor: theme.weakTextColor,
                                            lineHeight: subtitleFontSize * 1.1,
                                          )
                                        else
                                          Text(
                                            statusLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: subtitleFontSize,
                                              // 桌面端状态一律弱色；在线靠头像绿点区分。
                                              color: isDesktopScreen
                                                  ? (theme.weakTextColor ??
                                                      CommonColor.weakTextColor)
                                                  : (effectiveOnline
                                                      ? (theme.primaryColor ??
                                                          CommonColor
                                                              .primaryColor)
                                                      : theme.weakTextColor),
                                              height: 1.2,
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (roleBadge != null) roleBadge,
                              ],
                            ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isDesktopScreen)
                    Divider(
                      thickness: 1,
                      indent: 70,
                      endIndent: 0,
                      color: theme.weakDividerColor,
                      height: 0,
                    )
                ])));
      },
    );
  }

  static Widget getSusItem(BuildContext context, TUITheme theme, String tag, {double susHeight = 40}) {
    if (tag == '@') {
      tag = TIM_t("群主、管理员");
    }
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    return Container(
      height: isDesktopScreen ? 28 : susHeight,
      width: MediaQuery.of(context).size.width,
      padding: EdgeInsets.fromLTRB(
        isDesktopScreen ? 20 : 16,
        isDesktopScreen ? 8 : 6,
        isDesktopScreen ? 20 : 16,
        isDesktopScreen ? 2 : 6,
      ),
      color: isDesktopScreen
          ? (theme.wideBackgroundColor ?? Colors.white)
          : theme.weakBackgroundColor,
      alignment: Alignment.centerLeft,
      child: Text(
        tag,
        softWrap: true,
        style: TextStyle(
          fontSize: isDesktopScreen ? 11.0 : 13.0,
          fontWeight: FontWeight.w600,
          letterSpacing: isDesktopScreen ? 0.3 : 0,
          color: theme.weakTextColor?.withValues(alpha: 0.88),
        ),
      ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;

    final isDesktopScreen = TUIKitScreenUtils.getFormFactor() == DeviceType.Desktop;

    final showList = _getShowList(widget.memberList);
    return Container(
      color: isDesktopScreen
          ? (theme.wideBackgroundColor ?? Colors.white)
          : theme.weakBackgroundColor,
      child: SafeArea(
          child: Column(
        children: [
          widget.customTopArea != null ? widget.customTopArea! : Container(),
          Expanded(
              child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              _onScrollNotification(notification);
              return false;
            },
            child: (showList.isEmpty)
                ? (widget.emptyBuilder?.call(context) ??
                    Center(
                      child: Text(
                        TIM_t("暂无群成员"),
                        style: TextStyle(
                          color: theme.weakTextColor,
                          fontSize: isDesktopScreen ? 14 : 15,
                        ),
                      ),
                    ))
                : Container(
                    padding: isDesktopScreen
                        ? const EdgeInsets.only(bottom: 8)
                        : null,
                    child: AZListViewContainer(
                        memberList: showList,
                        isShowIndexBar: widget.isShowIndexBar,
                        itemPositionsListener: _itemPositionsListener,
                        susItemBuilder: (context, index) {
                          if (!widget.isShowIndexBar) {
                            return const SizedBox.shrink();
                          }
                          final model = showList[index];
                          return getSusItem(
                              context, theme, model.getSuspensionTag());
                        },
                        itemBuilder: (context, index) {
                          final memberInfo = showList[index].memberInfo as V2TimGroupMemberFullInfo;

                          return _buildListItem(context, memberInfo);
                        }),
                  ),
          ))
        ],
      )),
    );
  }
}
