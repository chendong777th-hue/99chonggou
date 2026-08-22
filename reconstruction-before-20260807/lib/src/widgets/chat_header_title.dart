import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
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
import 'package:tencent_cloud_chat_demo/src/widgets/official_account_name_label.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/presence_subtitle.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

/// 聊天页 AppBar 标题（备注/头像优先本地库；在线展示受本端「显示在线状态」与对方隐私设置约束）。
class ChatHeaderTitle extends StatefulWidget {
  final String? peerUserId;
  final String? conversationFaceUrl;
  final String title;
  final ConvType convType;
  /// 为 null 时不可点（如认证号不允许进聊天设置）。
  final VoidCallback? onTap;
  final TUITheme theme;

  const ChatHeaderTitle({
    super.key,
    required this.peerUserId,
    required this.conversationFaceUrl,
    required this.title,
    required this.convType,
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
    if (oldWidget.peerUserId != widget.peerUserId) {
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
    if (widget.convType != ConvType.c2c || userId.isEmpty) {
      final fallback = widget.title.trim();
      return fallback.isNotEmpty ? fallback : 'Chat';
    }

    return FriendDisplayName.resolveLocalFirst(
      localProfile: _localProfile,
      userId: userId,
      conversationShowName: widget.title,
    );
  }

  String _resolveFaceUrl(TUIFriendShipViewModel friendship) {
    final userId = widget.peerUserId?.trim() ?? '';
    final official = PlatformOfficialAccountService.resolveFaceUrl(
      userId: userId,
      conversationFaceUrl: widget.conversationFaceUrl,
    );
    if (widget.convType != ConvType.c2c || userId.isEmpty) {
      return official;
    }

    final fromFriendList = ConversationFaceUrl.resolve(
      userId: userId,
      conversationFaceUrl: widget.conversationFaceUrl,
      friendList: friendship.friendList,
    );
    return UserAvatarHelper.pickBestPreferBackend(
      imFaceUrl: fromFriendList.isNotEmpty ? fromFriendList : widget.conversationFaceUrl,
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
    if (widget.convType != ConvType.c2c || userId.isEmpty || !showOnlineStatus) {
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
              animation: friendship,
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
                    presence.resolveOnline(
                      userId: userId,
                      imOnline: imOnline,
                    );
                final showPresenceRow =
                    widget.convType == ConvType.c2c &&
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
                                  : 'chat_header_avatar_group_${widget.title}',
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
                            OfficialAccountNameLabelForUser(
                              userId: userId,
                              name: showName,
                              maxLines: 1,
                              badgeSize: 18,
                              style: TextStyle(
                                color: widget.theme.chatHeaderTitleTextColor ??
                                    widget.theme.appbarTextColor ??
                                    Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                            ),
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
