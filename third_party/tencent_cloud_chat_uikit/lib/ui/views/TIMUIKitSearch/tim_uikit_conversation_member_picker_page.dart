import 'dart:async';
import 'dart:math';

import 'package:azlistview_all_platforms/azlistview_all_platforms.dart';
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_input.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_search_not_support.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/az_list_view.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class TIMUIKitConversationMemberPickerPage extends StatefulWidget {
  const TIMUIKitConversationMemberPickerPage({
    super.key,
    required this.groupId,
    this.memberPresenceLabelBuilder,
    this.memberPresenceLoadingChecker,
    this.onMemberListLoaded,
    this.presenceListenable,
  });

  final String groupId;
  final MemberPresenceLabelBuilder? memberPresenceLabelBuilder;
  final MemberPresenceLoadingChecker? memberPresenceLoadingChecker;
  final void Function(List<String> userIds)? onMemberListLoaded;

  /// 业务侧在线状态刷新时触发列表重建（如 [ChangeNotifier]）。
  final Listenable? presenceListenable;

  @override
  State<TIMUIKitConversationMemberPickerPage> createState() =>
      _TIMUIKitConversationMemberPickerPageState();
}

class _TIMUIKitConversationMemberPickerPageState
    extends TIMUIKitState<TIMUIKitConversationMemberPickerPage> {
  static const _pageSize = 100;
  /// 与群资料页 drain 上限对齐；单页 100，约可覆盖万人级群。
  static const _maxPages = 100;

  final GroupServices _groupServices = serviceLocator<GroupServices>();
  final FriendshipServices _friendshipServices = serviceLocator<FriendshipServices>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<V2TimGroupMemberFullInfo> _allMembers = [];
  Map<String, V2TimUserStatus> _userStatusById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.presenceListenable?.addListener(_onPresenceChanged);
    _loadMembers();
  }

  @override
  void dispose() {
    widget.presenceListenable?.removeListener(_onPresenceChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onPresenceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<String> _memberUserIds(List<V2TimGroupMemberFullInfo> members) {
    return members
        .map((member) => member.userID?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _hydrateFromCache() async {
    if (!SelfHostedGroupBridge.enabled) {
      return;
    }
    final cached =
        await SelfHostedGroupBridge.loadCachedGroupMemberList(widget.groupId);
    if (!mounted || cached.isEmpty) {
      return;
    }
    final userIds = _memberUserIds(cached);
    setState(() {
      _allMembers = cached;
      _loading = false;
    });
    if (userIds.isNotEmpty) {
      widget.onMemberListLoaded?.call(userIds);
    }
  }

  Future<void> _loadMembers() async {
    try {
      await _hydrateFromCache();
      if (!mounted) {
        return;
      }

      final remoteOrdered = <V2TimGroupMemberFullInfo>[];
      final remoteSeen = <String>{};
      var nextSeq = '0';
      var pageCount = 0;
      var remoteLoaded = false;
      var drainCompleted = false;
      while (mounted && pageCount < _maxPages) {
        pageCount++;
        final res = await _groupServices.getGroupMemberList(
          groupID: widget.groupId,
          filter: GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ALL,
          nextSeq: nextSeq,
          count: _pageSize,
        );
        if (res.code != 0 || res.data == null) {
          break;
        }
        remoteLoaded = true;
        final page = res.data!.memberInfoList ?? const <V2TimGroupMemberFullInfo?>[];
        for (final raw in page) {
          if (raw == null) {
            continue;
          }
          final id = raw.userID?.trim() ?? '';
          if (id.isEmpty || remoteSeen.contains(id)) {
            continue;
          }
          remoteSeen.add(id);
          remoteOrdered.add(raw);
        }
        // 边翻页边刷新，避免大群要等全部页拉完才从「仅缓存前缀」变成完整名单。
        if (mounted) {
          setState(() {
            _allMembers =
                mergeGroupMembersPreferIncoming(_allMembers, remoteOrdered);
            _loading = false;
          });
        }
        final next = res.data!.nextSeq ?? '';
        if (next.isEmpty || next == '0') {
          drainCompleted = true;
          break;
        }
        nextSeq = next;
      }
      if (pageCount >= _maxPages && !drainCompleted) {
        debugPrint(
          'MemberPicker: pagination capped at $_maxPages pages for group ${widget.groupId}',
        );
      }
      if (!mounted) {
        return;
      }

      if (remoteLoaded) {
        // 完整翻完才用远端有序列表替换（去掉已退群的本地残留）；
        // 中途失败则保留「缓存 ∪ 已拉到的远端」，避免半截覆盖把名单截短。
        final nextMembers = drainCompleted
            ? List<V2TimGroupMemberFullInfo>.from(remoteOrdered)
            : mergeGroupMembersPreferIncoming(_allMembers, remoteOrdered);
        final userIds = _memberUserIds(nextMembers);
        final useAppPresence = widget.memberPresenceLabelBuilder != null;
        if (useAppPresence) {
          widget.onMemberListLoaded?.call(userIds);
        } else {
          await _loadUserStatus(userIds);
          if (!mounted) {
            return;
          }
          widget.onMemberListLoaded?.call(userIds);
        }

        if (mounted) {
          setState(() {
            _allMembers = nextMembers;
            _loading = false;
          });
        }

        if (useAppPresence && userIds.isNotEmpty) {
          unawaited(_refreshUserStatusInBackground(userIds));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshUserStatusInBackground(List<String> userIds) async {
    try {
      await _loadUserStatus(userIds);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _loadUserStatus(List<String> userIds) async {
    if (userIds.isEmpty) {
      return;
    }
    const chunkSize = 500;
    final merged = <String, V2TimUserStatus>{};
    for (var i = 0; i < userIds.length; i += chunkSize) {
      final chunk = userIds.sublist(i, min(i + chunkSize, userIds.length));
      final statuses = await _friendshipServices.getUserStatus(userIDList: chunk);
      for (final status in statuses) {
        final id = status.userID?.trim() ?? '';
        if (id.isNotEmpty) {
          merged[id] = status;
        }
      }
    }
    _userStatusById = merged;
  }

  bool _isImOnline(String userId) {
    return _userStatusById[userId]?.statusType == 1;
  }

  String? _presenceSubtitle(String userId) {
    final builder = widget.memberPresenceLabelBuilder;
    if (builder == null) {
      return _isImOnline(userId) ? TIM_t('在线') : TIM_t('离线');
    }
    return builder(userId, _isImOnline(userId));
  }

  bool get _isSearching => _searchController.text.trim().isNotEmpty;

  List<V2TimGroupMemberFullInfo> get _visibleMembers {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _allMembers;
    }
    return _allMembers.where((member) {
      return groupMemberMatchesKeyword(member, keyword);
    }).toList();
  }

  List<ISuspensionBeanImpl> _buildSuspensionShowList(
    List<V2TimGroupMemberFullInfo> members,
  ) {
    final showList = <ISuspensionBeanImpl>[];
    for (final item in members) {
      final showName = memberDisplayName(
        friendRemark: item.friendRemark,
        nameCard: item.nameCard,
        nickName: item.nickName,
        userID: item.userID,
      );
      if (item.role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER ||
          item.role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN) {
        showList.add(ISuspensionBeanImpl(memberInfo: item, tagIndex: '@'));
      } else {
        showList.add(
          ISuspensionBeanImpl(
            memberInfo: item,
            tagIndex: memberSuspensionIndexTag(showName),
          ),
        );
      }
    }
    SuspensionUtil.sortListBySuspensionTag(showList);
    return showList;
  }

  Widget _suspensionSectionHeader(TUITheme theme, String tag) {
    var label = tag;
    if (label == '@') {
      label = TIM_t('群主、管理员');
    }
    return Container(
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: theme.weakTextColor,
        ),
      ),
    );
  }

  Widget _buildMemberRow({
    required TUITheme theme,
    required V2TimGroupMemberFullInfo member,
    required String showName,
    required String userId,
  }) {
    final imOnline = _isImOnline(userId);
    final presenceLoading =
        widget.memberPresenceLoadingChecker?.call(userId, imOnline) ?? false;
    final subtitle = presenceLoading ? null : _presenceSubtitle(userId);
    final onlineStatus = _userStatusById[userId];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(member),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Avatar(
                  faceUrl: member.faceUrl ?? '',
                  showName: showName,
                  onlineStatus: onlineStatus,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      showName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.darkTextColor,
                      ),
                    ),
                    if (presenceLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: buildMemberPresenceSubtitleSkeleton(
                          baseColor: theme.weakTextColor,
                          lineHeight: 15,
                        ),
                      )
                    else if (subtitle != null && subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.weakTextColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberRowWithDivider({
    required TUITheme theme,
    required V2TimGroupMemberFullInfo member,
    required String showName,
    required String userId,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMemberRow(
          theme: theme,
          member: member,
          showName: showName,
          userId: userId,
        ),
        Divider(
          height: 0.5,
          thickness: 0.5,
          indent: 68,
          endIndent: 16,
          color: theme.weakDividerColor ?? theme.conversationItemBorderColor,
        ),
      ],
    );
  }

  Widget _buildFlatMemberList(
    TUITheme theme,
    List<V2TimGroupMemberFullInfo> members,
  ) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final showName = memberDisplayName(
          friendRemark: member.friendRemark,
          nameCard: member.nameCard,
          nickName: member.nickName,
          userID: member.userID,
        );
        final userId = member.userID?.trim() ?? '';
        return _buildMemberRowWithDivider(
          theme: theme,
          member: member,
          showName: showName,
          userId: userId,
        );
      },
    );
  }

  Widget _buildIndexedMemberList(
    TUITheme theme,
    List<V2TimGroupMemberFullInfo> members,
  ) {
    final showList = _buildSuspensionShowList(members);
    if (showList.isEmpty) {
      return Center(
        child: Text(
          TIM_t('暂无数据'),
          style: TextStyle(color: theme.weakTextColor),
        ),
      );
    }
    return AZListViewContainer(
      memberList: showList,
      isShowIndexBar: false,
      susItemBuilder: (context, index) {
        return const SizedBox.shrink();
      },
      itemBuilder: (context, index) {
        final member = showList[index].memberInfo as V2TimGroupMemberFullInfo;
        final showName = memberDisplayName(
          friendRemark: member.friendRemark,
          nameCard: member.nameCard,
          nickName: member.nickName,
          userID: member.userID,
        );
        final userId = member.userID?.trim() ?? '';
        return _buildMemberRowWithDivider(
          theme: theme,
          member: member,
          showName: showName,
          userId: userId,
        );
      },
    );
  }

  Widget _buildMemberListContent(
    TUITheme theme,
    List<V2TimGroupMemberFullInfo> members,
  ) {
    if (_isSearching) {
      return _buildFlatMemberList(theme, members);
    }
    return _buildIndexedMemberList(theme, members);
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    if (PlatformUtils().isWeb) {
      return TIMUIKitSearchNotSupport();
    }

    final theme = value.theme;
    final members = _visibleMembers;
    final listenable = widget.presenceListenable;

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
          TIM_t('选择群成员'),
          style: TextStyle(
            fontSize: 17,
            color: theme.chatHeaderTitleTextColor ?? theme.darkTextColor,
          ),
        ),
      ),
      body: Column(
        children: [
          TIMUIKitSearchInput(
            controller: _searchController,
            focusNode: _searchFocusNode,
            isAutoFocus: false,
            onChange: (_) => setState(() {}),
            prefixIcon: Icon(
              Icons.search,
              size: 16,
              color: theme.weakTextColor ?? hexToColor('979797'),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: theme.primaryColor,
                      strokeWidth: 2,
                    ),
                  )
                : members.isEmpty
                    ? Center(
                        child: Text(
                          TIM_t('暂无数据'),
                          style: TextStyle(color: theme.weakTextColor),
                        ),
                      )
                    : listenable == null
                        ? _buildMemberListContent(theme, members)
                        : AnimatedBuilder(
                            animation: listenable,
                            builder: (context, _) =>
                                _buildMemberListContent(theme, members),
                          ),
          ),
        ],
      ),
    );
  }
}
