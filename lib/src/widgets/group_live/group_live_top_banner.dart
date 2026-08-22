import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';

/// Compact banner above the message list when a group has an active live slot.
class GroupLiveTopBanner extends StatelessWidget {
  const GroupLiveTopBanner({
    super.key,
    required this.session,
    required this.onTap,
    this.isDesignatedAnchor = false,
    this.anchorFaceUrl = '',
  });

  final GroupLiveSession session;
  final VoidCallback onTap;
  final bool isDesignatedAnchor;
  final String anchorFaceUrl;

  static const Color _cardBg = Color(0xFFF2F3F5);
  static const Color _titleInk = Color(0xFF1F2329);
  static const Color _buttonBorder = Color(0xFFE5E6EB);
  static const Color _avatarBorder = Color(0xFFE5E6EB);

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final title = session.roomName.trim().isNotEmpty
        ? session.roomName.trim()
        : i18n.t(
            zhHans: '群直播',
            zhHant: '群直播',
            en: 'Group Live',
            ja: 'グループ配信',
            ko: '그룹 라이브',
          );
    final action = i18n.t(
      zhHans: '进入直播间',
      zhHant: '進入直播間',
      en: 'Enter room',
      ja: '配信室へ',
      ko: '라이브 입장',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
            child: Row(
              children: [
                Image.asset(
                  'assets/live/live2.webp',
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _titleInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _AnchorLiveAvatar(
                  userId: session.anchorUserId,
                  groupId: session.groupId,
                  initialFaceUrl: anchorFaceUrl,
                ),
                const SizedBox(width: 8),
                _EnterLiveButton(label: action),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnchorLiveAvatar extends StatefulWidget {
  const _AnchorLiveAvatar({
    required this.userId,
    required this.groupId,
    this.initialFaceUrl = '',
  });

  final String userId;
  final String groupId;
  final String initialFaceUrl;

  @override
  State<_AnchorLiveAvatar> createState() => _AnchorLiveAvatarState();
}

class _AnchorLiveAvatarState extends State<_AnchorLiveAvatar> {
  static const double _avatarSize = 28;

  late String _faceUrl;
  late String _normalizedUserId;
  late String _normalizedGroupId;

  @override
  void initState() {
    super.initState();
    _normalizedUserId = ChatIdFormat.rawUserUid(widget.userId);
    _normalizedGroupId = ChatIdFormat.normalizeGroupId(widget.groupId);
    _faceUrl = _resolveFaceFromLocalHints();
    GroupMemberStore.instance.addListener(_onMemberStoreChanged);
    if (_needsNetworkResolve(_faceUrl)) {
      unawaited(_resolveFaceUrl());
    }
  }

  @override
  void didUpdateWidget(covariant _AnchorLiveAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextUserId = ChatIdFormat.rawUserUid(widget.userId);
    final nextGroupId = ChatIdFormat.normalizeGroupId(widget.groupId);
    final userChanged = nextUserId != _normalizedUserId;
    final groupChanged = nextGroupId != _normalizedGroupId;
    final hintChanged = oldWidget.initialFaceUrl != widget.initialFaceUrl;
    if (!userChanged && !groupChanged && !hintChanged) {
      return;
    }
    _normalizedUserId = nextUserId;
    _normalizedGroupId = nextGroupId;
    final nextFace = _resolveFaceFromLocalHints();
    if (nextFace != _faceUrl) {
      setState(() => _faceUrl = nextFace);
    }
    if (_needsNetworkResolve(_faceUrl)) {
      unawaited(_resolveFaceUrl());
    }
  }

  @override
  void dispose() {
    GroupMemberStore.instance.removeListener(_onMemberStoreChanged);
    super.dispose();
  }

  String _resolveFaceFromLocalHints() {
    final fromHint =
        UserAvatarHelper.usableAvatarOrEmpty(widget.initialFaceUrl);
    if (fromHint.isNotEmpty) {
      return fromHint;
    }
    return UserAvatarHelper.groupMemberFaceUrl(
      _normalizedGroupId,
      _normalizedUserId,
    );
  }

  bool _needsNetworkResolve(String faceUrl) {
    return UserAvatarHelper.usableAvatarOrEmpty(faceUrl).isEmpty &&
        _normalizedUserId.isNotEmpty;
  }

  void _onMemberStoreChanged() {
    final memberFace = UserAvatarHelper.groupMemberFaceUrl(
      _normalizedGroupId,
      _normalizedUserId,
    );
    if (memberFace.isEmpty || memberFace == _faceUrl) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _faceUrl = memberFace);
  }

  Future<void> _resolveFaceUrl() async {
    final id = _normalizedUserId;
    if (id.isEmpty) {
      return;
    }
    final resolved = await UserAvatarHelper.resolveChatPeerFaceUrl(
      peerUserId: id,
      messageFaceUrl: widget.initialFaceUrl,
      groupId: _normalizedGroupId,
    );
    final usable = UserAvatarHelper.usableAvatarOrEmpty(resolved);
    if (usable.isEmpty || !mounted || _normalizedUserId != id) {
      return;
    }
    if (usable == _faceUrl) {
      return;
    }
    setState(() => _faceUrl = usable);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: GroupLiveTopBanner._avatarBorder, width: 1),
      ),
      child: ClipOval(
        child: AppUserAvatar(
          faceUrl: _faceUrl,
          showName: _normalizedUserId,
          size: _avatarSize - 2,
          type: 1,
          preferRasterPlaceholder: true,
        ),
      ),
    );
  }
}

class _EnterLiveButton extends StatelessWidget {
  const _EnterLiveButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GroupLiveTopBanner._buttonBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: GroupLiveTopBanner._titleInk,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.05,
        ),
      ),
    );
  }
}
