import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/chat_cards/wallet_message_card.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/group_live_message.dart';

class GroupLiveMessageCard extends StatelessWidget {
  const GroupLiveMessageCard({
    super.key,
    required this.payload,
    this.onTap,
  });

  final GroupLiveImPayload payload;
  final VoidCallback? onTap;

  static const Color _scheduledColor = Color(0xFF1677FF);
  static const Color _liveColor = Color(0xFFE53935);
  static const Color _endedColor = Color(0xFF78909C);

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final roomName = payload.roomName.trim().isNotEmpty
        ? payload.roomName.trim()
        : i18n.t(
            zhHans: '群直播',
            zhHant: '群直播',
            en: 'Group Live',
            ja: 'グループ配信',
            ko: '그룹 라이브',
          );
    final statusLine = _statusLine(context);
    final footer = _footerLine(context);
    final color = _cardColor();

    return WalletMessageCard(
      title: roomName,
      subTitle: statusLine,
      color: color,
      footer: footer,
      footerColor: Colors.white.withValues(alpha: 0.92),
      onTap: onTap,
    );
  }

  Color _cardColor() {
    if (payload.businessId == GroupLiveMessageIds.started ||
        payload.status == GroupLiveStatus.live) {
      return _liveColor;
    }
    if (payload.businessId == GroupLiveMessageIds.ended ||
        payload.status == GroupLiveStatus.ended ||
        payload.status == GroupLiveStatus.banned) {
      return _endedColor;
    }
    return _scheduledColor;
  }

  String _statusLine(BuildContext context) {
    final i18n = AppI18n.of(context);
    switch (payload.businessId) {
      case GroupLiveMessageIds.started:
      case GroupLiveMessageIds.ready when payload.status == GroupLiveStatus.live:
        return i18n.t(
          zhHans: '直播中',
          zhHant: '直播中',
          en: 'Live now',
          ja: '配信中',
          ko: '라이브 중',
        );
      case GroupLiveMessageIds.ready:
        return i18n.t(
          zhHans: '已到开播时间，等待 OBS 推流',
          zhHant: '已到開播時間，等待 OBS 推流',
          en: 'Scheduled time reached — waiting for OBS push',
          ja: '配信時刻になりました。OBS から配信してください。',
          ko: '방송 시간이 되었습니다. OBS 推流를 기다리는 중입니다.',
        );
      case GroupLiveMessageIds.ended:
        return _endedText(context);
      case GroupLiveMessageIds.scheduleUpdated:
        return i18n.t(
          zhHans: '直播预约已更新',
          zhHant: '直播預約已更新',
          en: 'Live schedule updated',
          ja: '配信予約が更新されました',
          ko: '라이브 예약이 업데이트되었습니다',
        );
      case GroupLiveMessageIds.scheduled:
      default:
        final when = payload.scheduledStartAt;
        if (when != null) {
          final local = when.toLocal();
          final text = DateFormat('MM-dd HH:mm').format(local);
          return i18n.t(
            zhHans: '预约开播 · $text',
            zhHant: '預約開播 · $text',
            en: 'Scheduled · $text',
            ja: '予約 · $text',
            ko: '예약 · $text',
          );
        }
        return i18n.t(
          zhHans: '已预约群直播',
          zhHant: '已預約群直播',
          en: 'Group live scheduled',
          ja: 'グループ配信を予約しました',
          ko: '그룹 라이브가 예약되었습니다',
        );
    }
  }

  String _footerLine(BuildContext context) {
    final i18n = AppI18n.of(context);
    if (payload.businessId == GroupLiveMessageIds.started ||
        payload.status == GroupLiveStatus.live) {
      return i18n.t(
        zhHans: '点击进入直播间',
        zhHant: '點擊進入直播間',
        en: 'Tap to enter live room',
        ja: 'タップして視聴',
        ko: '탭하여 시청',
      );
    }
    if (payload.businessId == GroupLiveMessageIds.ready) {
      return i18n.t(
        zhHans: '指定主播请获取推流地址',
        zhHant: '指定主播請取得推流地址',
        en: 'Designated anchor: fetch push info',
        ja: '指定アンカーは配信URLを取得',
        ko: '지정 앵커: 推流 주소 받기',
      );
    }
    if (payload.businessId == GroupLiveMessageIds.ended) {
      return i18n.t(
        zhHans: '直播已结束',
        zhHant: '直播已結束',
        en: 'Live ended',
        ja: '配信終了',
        ko: '라이브 종료',
      );
    }
    return i18n.t(
      zhHans: '群直播',
      zhHant: '群直播',
      en: 'Group Live',
      ja: 'グループ配信',
      ko: '그룹 라이브',
    );
  }

  String _endedText(BuildContext context) {
    final i18n = AppI18n.of(context);
    switch (payload.endReason) {
      case GroupLiveEndReason.revoked:
        return i18n.t(
          zhHans: '预约已撤销',
          zhHant: '預約已撤銷',
          en: 'Schedule revoked',
          ja: '予約が取り消されました',
          ko: '예약이 취소되었습니다',
        );
      case GroupLiveEndReason.scheduleExpired:
        return i18n.t(
          zhHans: '超时未推流，预约已过期',
          zhHant: '超時未推流，預約已過期',
          en: 'Expired — no OBS push in time',
          ja: '期限内に配信がなく失効しました',
          ko: '推流 없이 만료되었습니다',
        );
      case GroupLiveEndReason.adminBan:
        return i18n.t(
          zhHans: '直播已被平台禁播',
          zhHant: '直播已被平台禁播',
          en: 'Banned by platform',
          ja: 'プラットフォームにより停止',
          ko: '플랫폼에 의해 중단됨',
        );
      default:
        return i18n.t(
          zhHans: '直播已结束',
          zhHant: '直播已結束',
          en: 'Live ended',
          ja: '配信終了',
          ko: '라이브 종료',
        );
    }
  }
}
