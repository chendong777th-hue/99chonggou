import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_live/group_live_index_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// Overlap onto avatar bottom; lower value = badge sits closer to avatar edge.
const double kGroupLiveConversationBadgeBottomInset = 0;

/// Wraps a conversation-list avatar and shows live status overlapping its bottom.
class GroupLiveConversationListAvatarWrap extends StatelessWidget {
  const GroupLiveConversationListAvatarWrap({
    super.key,
    required this.groupId,
    required this.child,
  });

  final String groupId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final normalized = ChatIdFormat.normalizeGroupId(groupId);
    if (normalized.isEmpty) {
      return child;
    }
    return AnimatedBuilder(
      animation: GroupLiveIndexStore.instance,
      builder: (context, _) {
        final liveItem = GroupLiveIndexStore.instance.itemForGroup(normalized);
        if (liveItem == null) {
          return child;
        }
        // 只钉 bottom，不锁 left/right：角标可用固有宽度水平居中并略超出头像，
        // 避免在 44 宽槽里把「直播中/有直播」挤成两行（大字号/英日文更明显）。
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            child,
            Positioned(
              bottom: kGroupLiveConversationBadgeBottomInset,
              child: GroupLiveConversationBadge(status: liveItem.status),
            ),
          ],
        );
      },
    );
  }
}

/// Compact live-state chip shown on the group conversation list row.
class GroupLiveConversationBadge extends StatelessWidget {
  const GroupLiveConversationBadge({
    super.key,
    required this.status,
    this.compact = true,
  });

  final GroupLiveStatus status;
  final bool compact;

  static const Color _liveRed = Color(0xFFFF4B4B);

  @override
  Widget build(BuildContext context) {
    final label = _label(AppI18n.of(context));
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    final bgColor = _badgeBackgroundColor(status);
    // 角标尺寸与会话列表统一：不受系统「更大字体」影响，避免机型间换行不一致。
    return MediaQuery.withNoTextScaling(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 7,
          vertical: compact ? 1 : 2,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          overflow: TextOverflow.visible,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w400,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  static Color _badgeBackgroundColor(GroupLiveStatus status) {
    switch (status) {
      case GroupLiveStatus.live:
        return _liveRed;
      case GroupLiveStatus.authorized:
        return const Color(0xFFFF6B35);
      case GroupLiveStatus.scheduled:
        return const Color(0xFF1677FF);
      default:
        return _liveRed;
    }
  }

  String _label(AppI18n i18n) {
    switch (status) {
      case GroupLiveStatus.live:
        return i18n.t(
          zhHans: '直播中',
          zhHant: '直播中',
          en: 'Live',
          ja: '配信中',
          ko: '라이브',
        );
      case GroupLiveStatus.authorized:
        return i18n.t(
          zhHans: '有直播',
          zhHant: '有直播',
          en: 'Live soon',
          ja: '配信予定',
          ko: '라이브 예정',
        );
      case GroupLiveStatus.scheduled:
        return i18n.t(
          zhHans: '待开播',
          zhHant: '待開播',
          en: 'Scheduled',
          ja: '開始待ち',
          ko: '시작 예정',
        );
      default:
        return '';
    }
  }
}
