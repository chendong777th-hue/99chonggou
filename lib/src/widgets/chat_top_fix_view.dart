import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_top_fix_state_controller.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_game/group_game_status_banner.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_live/group_live_inline_watch_banner.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_live/group_live_top_banner.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_notice_marquee.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class ChatTopFixView extends StatelessWidget {
  const ChatTopFixView({
    super.key,
    required this.controller,
    required this.onShowNotice,
    required this.onDismissNotice,
    this.onGroupLiveTap,
    this.onCloseGroupLiveWatch,
  });

  final ChatTopFixStateController controller;
  final ValueChanged<String> onShowNotice;
  final ValueChanged<String> onDismissNotice;
  final VoidCallback? onGroupLiveTap;
  final VoidCallback? onCloseGroupLiveWatch;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final gameBanner = controller.showGroupGameBanner
            ? GroupGameStatusBanner(
                doorCount: controller.doorCount,
                roundStatus: controller.roundStatus,
              )
            : const SizedBox.shrink();
        final liveSession = controller.groupLiveSession;
        final Widget liveBanner;
        if (liveSession != null && controller.watchingGroupLive) {
          liveBanner = GroupLiveInlineWatchBanner(
            key: ValueKey('watch_${liveSession.liveSessionId}'),
            session: liveSession,
            anchorFaceUrl: _resolveAnchorFaceUrl(liveSession),
            onClose: onCloseGroupLiveWatch ?? () {},
          );
        } else if (liveSession != null) {
          liveBanner = GroupLiveTopBanner(
            session: liveSession,
            isDesignatedAnchor: _isDesignatedAnchor(liveSession),
            anchorFaceUrl: _resolveAnchorFaceUrl(liveSession),
            onTap: onGroupLiveTap ?? () {},
          );
        } else {
          liveBanner = const SizedBox.shrink();
        }
        final noticeText = controller.noticeText.trim();
        if (noticeText.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [liveBanner, gameBanner],
          );
        }
        final dark = Theme.of(context).brightness == Brightness.dark;
        final marquee = GroupNoticeMarquee(
          text: noticeText,
          label: AppI18n.of(context).t(
            zhHans: '群公告：',
            zhHant: '群公告：',
            en: 'Group Notice: ',
            ja: 'グループのお知らせ：',
            ko: '그룹 공지: ',
          ),
          backgroundColor:
              dark ? const Color(0xFF1E3A5F) : const Color(0xFF5AABF0),
          textColor: Colors.white,
          onTap: () => onShowNotice(noticeText),
          onClose: () => onDismissNotice(noticeText),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [marquee, liveBanner, gameBanner],
        );
      },
    );
  }

  bool _isDesignatedAnchor(GroupLiveSession liveSession) {
    try {
      final currentUserId =
          TIMUIKitCore.getInstance().loginInfo.userID.trim();
      return currentUserId.isNotEmpty &&
          currentUserId == liveSession.anchorUserId.trim();
    } catch (_) {
      return false;
    }
  }

  String _resolveAnchorFaceUrl(GroupLiveSession liveSession) {
    final groupId = ChatIdFormat.normalizeGroupId(liveSession.groupId);
    final anchorId = liveSession.anchorUserId.trim();
    if (groupId.isEmpty || anchorId.isEmpty) {
      return '';
    }
    try {
      final member = GroupMemberStore.instance.memberOf(groupId, anchorId);
      final face = member?.faceUrl?.trim() ?? '';
      if (face.isNotEmpty) {
        return face;
      }
    } catch (_) {}
    return '';
  }
}
