import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_header_state_controller.dart';
import 'package:tencent_cloud_chat_demo/src/models/user_profile_record.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_face_url.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_mutual_utils.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_group_title_color.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/official_account_name_label.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/presence_subtitle.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

/// 聊天页 AppBar 标题（名称优先本地资料；头像由 Chat 统一解析）。
class ChatHeaderTitle extends StatefulWidget {
  final String? peerUserId;
  final String conversationID;
  final String? conversationFaceUrl;
  final String title;
  final ChatHeaderStateController? headerState;
  final ConvType convType;

  /// 群聊时用于超级大群红字/火焰；C2C 可空。
  final String? groupType;

  /// 为 null 时不可点（如认证号不允许进聊天设置）。
  final VoidCallback? onTap;
  final TUITheme theme;

  const ChatHeaderTitle({
    super.key,
    required this.peerUserId,
    required this.conversationID,
    required this.conversationFaceUrl,
    required this.title,
    this.headerState,
    required this.convType,
    this.groupType,
    this.onTap,
    required this.theme,
  });

  @override
  State<ChatHeaderTitle> createState() => _ChatHeaderTitleState();
}

class _ChatHeaderTitleState extends State<ChatHeaderTitle> {
  UserProfileRecord? _localProfile;
  String? _presenceScheduledUserId;

  @override
  void initState() {
    super.initState();
    PeerProfileRefreshBus.instance.revision.addListener(_onProfileRefresh);
    _loadLocalProfile();
    _schedulePresenceLoad();
  }

  @override
  void didUpdateWidget(covariant ChatHeaderTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peerUserId != widget.peerUserId ||
        oldWidget.convType != widget.convType) {
      _localProfile = null;
      _presenceScheduledUserId = null;
      _loadLocalProfile();
      _schedulePresenceLoad();
    }
  }

  @override
  void dispose() {
    PeerProfileRefreshBus.instance.revision.removeListener(_onProfileRefresh);
    super.dispose();
  }

  void _onProfileRefresh() {
    final id = widget.peerUserId?.trim() ?? '';
    if (id.isEmpty || !PeerProfileRefreshBus.instance.matches(id)) {
      return;
    }
    _loadLocalProfile();
  }

  Future<void> _loadLocalProfile() async {
    final id = widget.peerUserId?.trim() ?? '';
    if (id.isEmpty || widget.convType != ConvType.c2c) {
      return;
    }
    final record = await UserProfileLocalService.instance.read(id);
    if (!mounted) {
      return;
    }
    if (widget.peerUserId?.trim() != id || widget.convType != ConvType.c2c) {
      return;
    }
    setState(() => _localProfile = record);
  }

  void _schedulePresenceLoad() {
    final userId = widget.peerUserId?.trim() ?? '';
    if (widget.convType != ConvType.c2c || userId.isEmpty) {
      return;
    }
    if (_presenceScheduledUserId == userId) {
      return;
    }
    _presenceScheduledUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final id = widget.peerUserId?.trim() ?? '';
      if (id.isEmpty || id != userId) {
        return;
      }
      final localSetting = Provider.of<LocalSetting>(context, listen: false);
      if (!localSetting.isShowOnlineStatus) {
        return;
      }
      if (PlatformOfficialAccountService.showsVerifiedBadge(id)) {
        return;
      }
      final presence = Provider.of<PresenceProvider>(context, listen: false);
      presence.ensure([id]);
      presence.refresh([id], urgent: true);
    });
  }

  V2TimUserStatus? _statusFor(
    TUIFriendShipViewModel friendship,
    String userId,
  ) {
    if (widget.convType != ConvType.c2c || userId.isEmpty) {
      return null;
    }
    if (PlatformOfficialAccountService.showsVerifiedBadge(userId)) {
      return V2TimUserStatus(userID: userId, statusType: 1);
    }
    for (final status in friendship.userStatusList) {
      if (status.userID == userId) {
        return status;
      }
    }
    return null;
  }

  String _resolveShowName() {
    final userId = widget.peerUserId?.trim() ?? '';
    final title = _effectiveTitle();
    if (widget.convType != ConvType.c2c || userId.isEmpty) {
      final fallback = title.trim();
      return fallback.isNotEmpty ? fallback : 'Chat';
    }

    return FriendDisplayName.resolveLocalFirst(
      localProfile: _localProfile,
      userId: userId,
      conversationShowName: title,
    );
  }

  String _effectiveTitle() {
    final stateTitle = widget.headerState?.titleText?.trim() ?? '';
    return stateTitle.isNotEmpty ? stateTitle : widget.title;
  }

  String? _effectiveConversationFaceUrl() {
    return widget.headerState?.conversationFaceUrl ??
        widget.conversationFaceUrl;
  }

  Widget _buildHeaderName(String showName, String userId) {
    final fallbackColor = widget.theme.chatHeaderTitleTextColor ??
        widget.theme.appbarTextColor ??
        Colors.black;
    final style = TextStyle(
      inherit: false,
      color: conversationGroupTitleColor(
        fallback: fallbackColor,
        groupType: widget.groupType,
      ),
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.1,
      leadingDistribution: TextLeadingDistribution.even,
    );
    if (widget.convType == ConvType.group) {
      return buildGroupTitleWithOptionalFlame(
        name: showName,
        groupType: widget.groupType,
        flameSize: 16,
        style: style,
      );
    }
    return OfficialAccountNameLabelForUser(
      userId: userId,
      name: showName,
      maxLines: 1,
      badgeSize: 18,
      style: style,
    );
  }

  String _resolveFaceUrl(TUIFriendShipViewModel friendship) {
    final userId = widget.peerUserId?.trim() ?? '';
    final official = PlatformOfficialAccountService.resolveFaceUrl(
      userId: userId,
      conversationFaceUrl: _effectiveConversationFaceUrl(),
    );
    if (widget.convType == ConvType.group) {
      // Avatar only selects its group placeholder when faceUrl is empty.
      // Normalize whitespace, placeholder markers, and unusable relative values
      // here so an unset group avatar cannot become a blank network image.
      return UserAvatarHelper.usableAvatarOrEmpty(official);
    }
    if (widget.convType != ConvType.c2c || userId.isEmpty) {
      return official;
    }

    final fromFriendList = ConversationFaceUrl.resolve(
      userId: userId,
      conversationFaceUrl: _effectiveConversationFaceUrl(),
      friendList: friendship.friendList,
    );
    // Chat owns the resolved conversation avatar. Once it has a usable value,
    // do not let this child switch to a second async profile source.
    final stableImFace = fromFriendList.isNotEmpty
        ? fromFriendList
        : (_effectiveConversationFaceUrl() ?? '');
    if (UserAvatarHelper.usableAvatarOrEmpty(stableImFace).isNotEmpty) {
      return stableImFace;
    }
    return UserAvatarHelper.pickBestPreferBackend(
      imFaceUrl: stableImFace,
      backendAvatarUrl: _localProfile?.avatarUrl,
    );
  }

  String _presenceLabel(
    PresenceProvider presence,
    TUIFriendShipViewModel friendship,
    V2TimUserStatus? status,
    String userId, {
    required bool showOnlineStatus,
  }) {
    if (widget.convType != ConvType.c2c ||
        userId.isEmpty ||
        !showOnlineStatus) {
      return '';
    }
    if (PlatformOfficialAccountService.showsVerifiedBadge(userId)) {
      return TIM_t('在线');
    }
    final imOnline = status?.statusType == 1;
    return presence.chatHeaderLabelFor(
      userId: userId,
      imOnline: imOnline,
      isMutualFriend: friendCanMessage(friendship, userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.peerUserId?.trim() ?? '';
    final friendship = serviceLocator<TUIFriendShipViewModel>();

    return Consumer<LocalSetting>(
      builder: (context, localSetting, _) {
        return Consumer<PresenceProvider>(
          builder: (context, presence, child) {
            return AnimatedBuilder(
              animation: Listenable.merge([
                friendship,
                if (widget.headerState != null) widget.headerState!,
              ]),
              builder: (context, _) {
                final showOnlineStatus = localSetting.isShowOnlineStatus;
                final showName = _resolveShowName();
                final faceUrl = _resolveFaceUrl(friendship);
                final status = _statusFor(friendship, userId);
                final imOnline = status?.statusType == 1;
                final isMutualFriend = friendCanMessage(friendship, userId);
                final presenceStatus = showOnlineStatus
                    ? presence.resolveAvatarOnlineStatus(
                        userId,
                        status,
                        isMutualFriend: isMutualFriend,
                      )
                    : null;
                final presenceLabel = showOnlineStatus
                    ? _presenceLabel(
                        presence,
                        friendship,
                        status,
                        userId,
                        showOnlineStatus: showOnlineStatus,
                      )
                    : '';
                final canShowOnline = showOnlineStatus &&
                    presence.canViewPreciseLastActive(
                      userId,
                      isMutualFriend: isMutualFriend,
                    );
                final effectiveOnline = showOnlineStatus &&
                    presence.resolveOnline(userId: userId, imOnline: imOnline);
                final showPresenceRow = widget.convType == ConvType.c2c &&
                    userId.isNotEmpty &&
                    showOnlineStatus;
                final presenceLoading = showPresenceRow &&
                    presence.isLastSeenLoading(
                      userId: userId,
                      imOnline: imOnline,
                      forChatHeader: true,
                      isMutualFriend: isMutualFriend,
                    );
                final headerBody = Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: RepaintBoundary(
                          child: Avatar(
                            key: ValueKey(
                              widget.convType == ConvType.c2c
                                  ? 'chat_header_avatar_c2c_$userId'
                                  : 'chat_header_avatar_group_${widget.conversationID}',
                            ),
                            faceUrl: faceUrl,
                            showName: showName,
                            onlineStatus: presenceStatus,
                            type: widget.convType == ConvType.c2c ? 1 : 2,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderName(showName, userId),
                            if (showPresenceRow) ...[
                              const SizedBox(height: 2),
                              PresenceSubtitle(
                                label: presenceLabel,
                                loading: presenceLoading,
                                imOnline: canShowOnline && effectiveOnline,
                                fontSize: 12,
                                height: 1.1,
                                lineHeight: 13.2,
                                onlineColor: widget.theme.primaryColor ??
                                    const Color(0xFF1E90FF),
                                skeletonColor: widget.theme.weakTextColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
                if (widget.onTap == null) {
                  return headerBody;
                }
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: headerBody,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
