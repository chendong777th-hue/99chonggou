import 'dart:async';
import 'dart:math' as math;

import 'package:azlistview_all_platforms/azlistview_all_platforms.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/az_list_view.dart';

import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/starred_friend_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_list_pressable.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/friend_request_unread_badge.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_notice_unread_badge.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/presence_subtitle.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_mutual_utils.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';

class ContactListWithPresence extends StatefulWidget {
  final void Function(V2TimFriendInfo item)? onTapItem;
  final void Function(V2TimFriendInfo item)? onLongPressItem;
  final List<TopListItem>? topList;
  final Widget? Function(TopListItem item)? topListItemBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final bool isShowOnlineStatus;
  final bool Function(V2TimFriendInfo item)? filterItem;
  final bool showContactCount;

  const ContactListWithPresence({
    Key? key,
    this.onTapItem,
    this.onLongPressItem,
    this.topList,
    this.topListItemBuilder,
    this.emptyBuilder,
    this.isShowOnlineStatus = true,
    this.filterItem,
    this.showContactCount = false,
  }) : super(key: key);

  @override
  State<ContactListWithPresence> createState() =>
      _ContactListWithPresenceState();
}

class _ContactListWithPresenceState extends State<ContactListWithPresence> {
  final TUIFriendShipViewModel _friendShipModel =
      serviceLocator<TUIFriendShipViewModel>();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  static const int _presenceBufferRows = 12;
  static const int _firstScreenPrefetch = 28;
  static const Duration _presenceDebounce = Duration(milliseconds: 200);

  Timer? _presenceDebounceTimer;
  String? _lastPresenceEnsureKey;
  List<ISuspensionBeanImpl>? _cachedShowList;
  String? _cachedShowListKey;
  List<ISuspensionBeanImpl> _effectiveList = const [];

  static const double _mobileContactItemMinHeight = 56;
  static const double _desktopContactItemMinHeight = 64;
  static const double _mobileAvatarSize = 40;
  static const double _desktopAvatarSize = 48;
  static const double _mobileAvatarTextGap = 12;
  static const double _desktopAvatarTextGap = 10;
  static const double _mobileRowVerticalPadding = 4;
  static const double _desktopRowVerticalPadding = 6;
  static const double _nameStatusGap = 2;
  static const double _textBlockNudgeUp = 2;

  bool _useDesktopListMetrics(BuildContext context) =>
      kIsWeb ||
      TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

  double _avatarSize({required bool isDesktop}) =>
      isDesktop ? _desktopAvatarSize : _mobileAvatarSize;

  double _avatarTextGap({required bool isDesktop}) =>
      isDesktop ? _desktopAvatarTextGap : _mobileAvatarTextGap;

  double _rowVerticalPadding({required bool isDesktop}) =>
      isDesktop ? _desktopRowVerticalPadding : _mobileRowVerticalPadding;

  double _itemMinHeight({required bool isDesktop}) => isDesktop
      ? _desktopContactItemMinHeight
      : _mobileContactItemMinHeight;

  double _dividerInset({required bool isDesktop}) =>
      _avatarSize(isDesktop: isDesktop) + _avatarTextGap(isDesktop: isDesktop);

  @override
  void initState() {
    super.initState();
    PeerProfileRefreshBus.instance.revision.addListener(_onPeerProfileRefresh);
    _itemPositionsListener.itemPositions.addListener(_onItemPositionsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Joins home-tab enter via FriendRequestNoticeService single-flight.
      unawaited(
        FriendRequestNoticeService.instance.enterContactDataSource(
          reason: 'contact_list_widget',
        ),
      );
      unawaited(StarredFriendProvider.shared.refresh(force: false));
      final presence = Provider.of<PresenceProvider>(context, listen: false);
      unawaited(presence.hydrateFromLocalCache());
      _prefetchFirstScreenPresence();
    });
  }

  @override
  void dispose() {
    _presenceDebounceTimer?.cancel();
    PeerProfileRefreshBus.instance.revision
        .removeListener(_onPeerProfileRefresh);
    _itemPositionsListener.itemPositions.removeListener(_onItemPositionsChanged);
    super.dispose();
  }

  void _onPeerProfileRefresh() {
    if (!mounted) return;
    // 昵称变化会改变通讯录首字母分组，必须同时失效排序缓存。
    _cachedShowList = null;
    _cachedShowListKey = null;
    setState(() {});
  }

  void _onItemPositionsChanged() {
    if (!widget.isShowOnlineStatus) {
      return;
    }
    _presenceDebounceTimer?.cancel();
    _presenceDebounceTimer = Timer(_presenceDebounce, () {
      if (!mounted) {
        return;
      }
      _ensureVisiblePresence();
    });
  }

  void _prefetchFirstScreenPresence() {
    if (!widget.isShowOnlineStatus) {
      return;
    }
    final ids = _friendIdsFromEffectiveRange(
      start: 0,
      endExclusive: _firstScreenPrefetch,
    );
    _ensurePresenceIds(ids);
  }

  void _ensureVisiblePresence() {
    if (!widget.isShowOnlineStatus || _effectiveList.isEmpty) {
      return;
    }
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) {
      _prefetchFirstScreenPresence();
      return;
    }
    var minIndex = positions.first.index;
    var maxIndex = positions.first.index;
    for (final position in positions) {
      if (position.itemTrailingEdge <= 0 || position.itemLeadingEdge >= 1) {
        continue;
      }
      minIndex = math.min(minIndex, position.index);
      maxIndex = math.max(maxIndex, position.index);
    }
    final start = math.max(0, minIndex - _presenceBufferRows);
    final end = math.min(
      _effectiveList.length,
      maxIndex + _presenceBufferRows + 1,
    );
    _ensurePresenceIds(_friendIdsFromEffectiveRange(start: start, endExclusive: end));
  }

  List<String> _friendIdsFromEffectiveRange({
    required int start,
    required int endExclusive,
  }) {
    if (_effectiveList.isEmpty) {
      return const [];
    }
    final lo = start.clamp(0, _effectiveList.length);
    final hi = endExclusive.clamp(0, _effectiveList.length);
    if (lo >= hi) {
      return const [];
    }
    final ids = <String>[];
    for (var i = lo; i < hi; i++) {
      final info = _effectiveList[i].memberInfo;
      if (info is V2TimFriendInfo) {
        final id = info.userID.trim();
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    }
    return ids;
  }

  void _ensurePresenceIds(List<String> userIds) {
    if (!widget.isShowOnlineStatus || userIds.isEmpty || !mounted) {
      return;
    }
    final key = userIds.length <= 3
        ? userIds.join('|')
        : '${userIds.length}:${userIds.first}:${userIds.last}:${userIds[userIds.length ~/ 2]}';
    if (_lastPresenceEnsureKey == key) {
      return;
    }
    _lastPresenceEnsureKey = key;
    final presence = Provider.of<PresenceProvider>(context, listen: false);
    presence.ensure(userIds);
  }

  String _showName(V2TimFriendInfo item) {
    return UserDisplayProfile.nameOfFriend(item);
  }

  String _faceUrl(V2TimFriendInfo item) {
    return UserDisplayProfile.avatarOfFriend(item);
  }

  String _structureCacheKey(
    List<V2TimFriendInfo> friends,
    StarredFriendProvider starred,
  ) {
    // 好友 id 序列 + 星标集合：结构未变则复用已排序 showList。
    final friendPart =
        friends.isEmpty ? '0' : friends.map((e) => e.userID).join(',');
    final starredIds = starred.starredIds.toList()..sort();
    final starredPart = starredIds.join(',');
    final topLen = widget.topList?.length ?? 0;
    final filterOn = widget.filterItem != null ? '1' : '0';
    return '$friendPart|$starredPart|$topLen|$filterOn|${widget.showContactCount}';
  }

  List<ISuspensionBeanImpl> _buildShowList(
    List<V2TimFriendInfo> list,
    StarredFriendProvider starred,
  ) {
    final starredFriends = <V2TimFriendInfo>[];
    final others = <V2TimFriendInfo>[];
    for (final item in list) {
      if (starred.isStarred(item.userID)) {
        starredFriends.add(item);
      } else {
        others.add(item);
      }
    }
    starredFriends.sort((a, b) {
      final ta = starred.starredAtOf(a.userID);
      final tb = starred.starredAtOf(b.userID);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    final out = <ISuspensionBeanImpl>[];
    for (final item in starredFriends) {
      out.add(ISuspensionBeanImpl(memberInfo: item, tagIndex: '★'));
    }
    final otherBeans = <ISuspensionBeanImpl>[];
    for (final item in others) {
      final showName = _showName(item);
      otherBeans.add(
        ISuspensionBeanImpl(
          memberInfo: item,
          tagIndex: memberSuspensionIndexTag(showName),
        ),
      );
    }
    SuspensionUtil.sortListBySuspensionTag(otherBeans);
    out.addAll(otherBeans);
    return out;
  }

  List<ISuspensionBeanImpl> _cachedOrBuildShowList(
    List<V2TimFriendInfo> friends,
    StarredFriendProvider starred,
  ) {
    final key = _structureCacheKey(friends, starred);
    if (_cachedShowList != null && _cachedShowListKey == key) {
      return List<ISuspensionBeanImpl>.from(_cachedShowList!);
    }
    final built = _buildShowList(friends, starred);
    if (widget.topList != null && widget.topList!.isNotEmpty) {
      final tops = widget.topList!
          .map((e) => ISuspensionBeanImpl(memberInfo: e, tagIndex: '@'))
          .toList();
      built.insertAll(0, tops);
    }
    _cachedShowList = built;
    _cachedShowListKey = key;
    _lastPresenceEnsureKey = null;
    return List<ISuspensionBeanImpl>.from(built);
  }

  V2TimUserStatus? _statusOf(String userId) {
    if (!widget.isShowOnlineStatus) return null;
    final list = _friendShipModel.userStatusList;
    for (final s in list) {
      if (s.userID == userId) return s;
    }
    return null;
  }

  Widget _buildTopItem(TopListItem info) {
    final isDesktop = _useDesktopListMetrics(context);
    final custom = widget.topListItemBuilder?.call(info);
    if (custom != null) return custom;
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final itemBackgroundColor = theme.weakBackgroundColor ?? Colors.white;
    final avatarSize = _avatarSize(isDesktop: isDesktop);
    final avatarTextGap = _avatarTextGap(isDesktop: isDesktop);
    final rowPad = _rowVerticalPadding(isDesktop: isDesktop);
    final dividerInset = _dividerInset(isDesktop: isDesktop);
    return AppListPressable(
      color: itemBackgroundColor,
      onTap: info.onTap,
      child: Container(
        constraints:
            BoxConstraints(minHeight: _itemMinHeight(isDesktop: isDesktop)),
        padding: EdgeInsets.only(top: rowPad, left: 16),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                right: 16,
                bottom: rowPad,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: avatarSize,
                    width: avatarSize,
                    margin: EdgeInsets.only(right: avatarTextGap),
                    child: info.icon,
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(info.name,
                            style: TextStyle(
                              color: theme.darkTextColor ?? Colors.black,
                              fontSize: isDesktop ? 13 : 15,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                            )),
                        if (info.id == "newContact")
                          const FriendRequestUnreadBadge(
                            width: 18,
                            height: 18,
                          ),
                        if (info.id == "groupNotice")
                          const GroupNoticeUnreadBadge(
                            width: 18,
                            height: 18,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: dividerInset),
              child: Container(
                height: 0.6,
                color: theme.weakDividerColor ?? CommonColor.weakDividerColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(
    TUITheme theme,
    V2TimFriendInfo item,
    PresenceProvider presence,
    StarredFriendProvider starred,
  ) {
    final isDesktop = _useDesktopListMetrics(context);
    final showName = _showName(item);
    final faceUrl = _faceUrl(item);
    final isMutualFriend = friendCanMessage(_friendShipModel, item.userID);
    final isStarred = starred.isStarred(item.userID);
    final itemBackgroundColor = theme.weakBackgroundColor ?? Colors.white;
    final avatarSize = _avatarSize(isDesktop: isDesktop);
    final avatarTextGap = _avatarTextGap(isDesktop: isDesktop);
    final rowPad = _rowVerticalPadding(isDesktop: isDesktop);
    final dividerInset = _dividerInset(isDesktop: isDesktop);

    return AppListPressable(
      color: itemBackgroundColor,
      onTap: () => widget.onTapItem?.call(item),
      onLongPress: () => widget.onLongPressItem?.call(item),
      child: Container(
        constraints: BoxConstraints(
          minHeight: _itemMinHeight(isDesktop: isDesktop),
        ),
        padding: EdgeInsets.only(top: rowPad, left: 16),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                right: 16,
                bottom: rowPad,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: avatarSize,
                    width: avatarSize,
                    margin: EdgeInsets.only(right: avatarTextGap),
                    child: widget.isShowOnlineStatus
                        ? _ContactPresenceAvatar(
                            presence: presence,
                            userId: item.userID,
                            faceUrl: faceUrl,
                            showName: showName,
                            imStatus: _statusOf(item.userID),
                            isMutualFriend: isMutualFriend,
                          )
                        : Avatar(
                            faceUrl: faceUrl,
                            showName: showName,
                          ),
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -_textBlockNudgeUp),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.darkTextColor ?? Colors.black,
                              fontSize: isDesktop ? 13 : 16,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                          if (widget.isShowOnlineStatus) ...[
                            const SizedBox(height: _nameStatusGap),
                            _ContactPresenceSubtitle(
                              presence: presence,
                              userId: item.userID,
                              imStatus: _statusOf(item.userID),
                              isMutualFriend: isMutualFriend,
                              isDesktop: isDesktop,
                              weakTextColor: theme.weakTextColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (isStarred)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.star,
                        size: 18,
                        color: Color(0xFFF4B400),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: dividerInset),
              child: Container(
                height: 0.6,
                color: theme.weakDividerColor ?? CommonColor.weakDividerColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        StarredFriendProvider.shared,
        _friendShipModel,
      ]),
      builder: (context, _) {
        final starred = StarredFriendProvider.shared;
        return MultiProvider(
          providers: [ChangeNotifierProvider.value(value: _friendShipModel)],
          builder: (context, _) {
            final model = Provider.of<TUIFriendShipViewModel>(context);
            final presence =
                Provider.of<PresenceProvider>(context, listen: false);
            final theme = Provider.of<DefaultThemeData>(context).theme;
            final allFriends = (model.friendList ?? const <V2TimFriendInfo>[])
                .where(
                  (item) => !PlatformOfficialAccountService
                      .shouldHideFromContactAndPickers(item.userID),
                )
                .toList();
            final friends = widget.filterItem == null
                ? allFriends
                : allFriends.where(widget.filterItem!).toList();

            final showList = _cachedOrBuildShowList(friends, starred);

            if (friends.isEmpty) {
              _effectiveList = showList;
              return Column(
                children: [
                  ...showList.map((e) {
                    final info = e.memberInfo;
                    if (info is TopListItem) return _buildTopItem(info);
                    return const SizedBox.shrink();
                  }),
                  Expanded(
                    child: widget.emptyBuilder != null
                        ? widget.emptyBuilder!(context)
                        : Center(child: Text(TIM_t("无联系人"))),
                  ),
                ],
              );
            }

            final isDesktop = _useDesktopListMetrics(context);
            final effectiveList = widget.showContactCount
                ? [
                    ...showList,
                    ISuspensionBeanImpl(
                      memberInfo: '__contact_count_footer__',
                      tagIndex: '',
                    ),
                  ]
                : showList;
            _effectiveList = effectiveList;

            return AZListViewContainer(
              memberList: effectiveList,
              itemPositionsListener: _itemPositionsListener,
              itemBuilder: (context, index) {
                final info = effectiveList[index].memberInfo;
                if (info is String && info == '__contact_count_footer__') {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Center(
                      child: Text(
                        TIM_t_para(
                            "{{option1}}位联系人", "${friends.length}位联系人")(
                          option1: friends.length.toString(),
                        ),
                        style: TextStyle(
                          color: theme.weakTextColor ?? hexToColor("999999"),
                          fontSize: isDesktop ? 12 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }
                if (info is TopListItem) return _buildTopItem(info);
                return _buildContactItem(
                  theme,
                  info as V2TimFriendInfo,
                  presence,
                  starred,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 行内头像在线点：仅随 Presence 刷新，不触发通讯录整表重建。
class _ContactPresenceAvatar extends StatelessWidget {
  const _ContactPresenceAvatar({
    required this.presence,
    required this.userId,
    required this.faceUrl,
    required this.showName,
    required this.imStatus,
    required this.isMutualFriend,
  });

  final PresenceProvider presence;
  final String userId;
  final String faceUrl;
  final String showName;
  final V2TimUserStatus? imStatus;
  final bool isMutualFriend;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: presence,
      builder: (context, _) {
        final onlineStatus = presence.resolveAvatarOnlineStatus(
          userId,
          imStatus,
          isMutualFriend: isMutualFriend,
        );
        return Avatar(
          onlineStatus: onlineStatus,
          faceUrl: faceUrl,
          showName: showName,
        );
      },
    );
  }
}

/// 行内在线文案：仅随 Presence 刷新。
class _ContactPresenceSubtitle extends StatelessWidget {
  const _ContactPresenceSubtitle({
    required this.presence,
    required this.userId,
    required this.imStatus,
    required this.isMutualFriend,
    required this.isDesktop,
    required this.weakTextColor,
  });

  final PresenceProvider presence;
  final String userId;
  final V2TimUserStatus? imStatus;
  final bool isMutualFriend;
  final bool isDesktop;
  final Color? weakTextColor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: presence,
      builder: (context, _) {
        final imOnline = presence.resolveOnline(
          userId: userId,
          imOnline: imStatus?.statusType == 1,
        );
        final loading = presence.isLastSeenLoading(
          userId: userId,
          imOnline: imOnline,
          isMutualFriend: isMutualFriend,
        );
        final label = loading
            ? ''
            : presence.listLabelFor(
                userId: userId,
                imOnline: imOnline,
                isMutualFriend: isMutualFriend,
              );
        return PresenceSubtitle(
          label: label,
          loading: loading,
          imOnline: false,
          fontSize: isDesktop ? 11 : 13,
          height: 1.15,
          offlineColor: weakTextColor ?? hexToColor("999999"),
          skeletonColor: weakTextColor,
        );
      },
    );
  }
}
