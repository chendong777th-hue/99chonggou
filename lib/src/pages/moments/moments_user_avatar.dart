import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';

/// 朋友圈用户头像：本地资料真源优先，缺省再回补 IM。
class MomentsUserAvatar extends StatefulWidget {
  const MomentsUserAvatar({
    super.key,
    required this.user,
    this.size = 32,
  });

  final MomentUserSnapshot user;
  final double size;

  @override
  State<MomentsUserAvatar> createState() => _MomentsUserAvatarState();
}

class _MomentsUserAvatarState extends State<MomentsUserAvatar> {
  @override
  void initState() {
    super.initState();
    PeerProfileRefreshBus.instance.revision.addListener(_onProfileRefresh);
    _prefetchIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MomentsUserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.avatarUrl != widget.user.avatarUrl) {
      _prefetchIfNeeded();
    }
  }

  @override
  void dispose() {
    PeerProfileRefreshBus.instance.revision.removeListener(_onProfileRefresh);
    super.dispose();
  }

  void _onProfileRefresh() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _prefetchIfNeeded() {
    final live = UserDisplayProfile.avatarOfSnapshot(widget.user);
    if (UserAvatarHelper.usableAvatarOrEmpty(live).isNotEmpty) {
      return;
    }
    final id = widget.user.id.trim();
    if (id.isEmpty) {
      return;
    }
    unawaited(_resolveFaceUrl(id));
  }

  Future<void> _resolveFaceUrl(String id) async {
    final resolved = await UserAvatarHelper.resolveChatPeerFaceUrl(
      peerUserId: id,
      messageFaceUrl: widget.user.avatarUrl,
      preferLiveProfile: true,
    );
    if (!mounted || widget.user.id.trim() != id) {
      return;
    }
    if (UserAvatarHelper.usableAvatarOrEmpty(resolved).isEmpty) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppUserAvatar(
      faceUrl: UserDisplayProfile.avatarOfSnapshot(widget.user),
      showName: UserDisplayProfile.nameOfSnapshot(widget.user),
      size: widget.size,
    );
  }
}
