import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart'
    show GroupSystemNoticeItem, GroupSystemNoticeType;
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';

class ConversationGroupNoticePresenter {
  ConversationGroupNoticePresenter({
    required this.context,
    required this.groupNameResolver,
  });

  final BuildContext context;
  final String Function(String groupId) groupNameResolver;

  int unreadCount(
    List<V2TimGroupApplication> applications,
    List<GroupSystemNoticeItem> notices,
  ) {
    return computeGroupNoticeUnreadCount(
      applications: applications,
      notices: notices,
      readWatermarkMs: GroupNoticeUnreadService.instance.readWatermarkMs,
    );
  }

  String title(
    List<V2TimGroupApplication> applications,
    List<GroupSystemNoticeItem> notices,
  ) {
    return AppI18n.of(context).t(
      zhHans: '群通知',
      zhHant: '群組通知',
      en: 'Group Notices',
      ja: 'グループ通知',
      ko: '그룹 알림',
    );
  }

  String previewSubtitle(
    List<V2TimGroupApplication> applications,
    List<GroupSystemNoticeItem> notices,
  ) {
    if (_isLatestApplicationNotice(applications, notices)) {
      return _applicationPreviewSubtitle(applications);
    }
    if (notices.isEmpty) {
      return '';
    }
    return _systemNoticePreviewSubtitle(notices.first);
  }

  String previewTime(
    List<V2TimGroupApplication> applications,
    List<GroupSystemNoticeItem> notices,
  ) {
    final latestTimestamp = _isLatestApplicationNotice(applications, notices)
        ? _normalizeTimestampToSeconds(applications.firstOrNull?.addTime)
        : _normalizeTimestampToSeconds(notices.firstOrNull?.timestamp);
    if (latestTimestamp == 0) {
      return '';
    }
    return TimeAgo().getTimeStringForChat(latestTimestamp) ?? '';
  }

  bool _isLatestApplicationNotice(
    List<V2TimGroupApplication> applications,
    List<GroupSystemNoticeItem> notices,
  ) {
    if (applications.isEmpty) {
      return false;
    }
    if (notices.isEmpty) {
      return true;
    }
    final latestApplicationMs =
        _normalizeTimestampToMilliseconds(applications.first.addTime);
    final latestNoticeMs =
        _normalizeTimestampToMilliseconds(notices.first.timestamp);
    return latestApplicationMs >= latestNoticeMs;
  }

  String _applicationPreviewSubtitle(List<V2TimGroupApplication> applications) {
    if (applications.isEmpty) {
      return '';
    }
    final latest = applications.first;
    final applicantLabel = GroupJoinApplicationService.instance
        .resolveDisplayName(
      userId: latest.fromUser,
      apiNickName: latest.fromUserNickName,
    );
    final displayApplicant = applicantLabel.isNotEmpty
        ? applicantLabel
        : AppI18n.of(context).t(
            zhHans: '有人',
            zhHant: '有人',
            en: 'Someone',
            ja: '誰か',
            ko: '누군가',
          );
    final groupName = groupNameResolver(latest.groupID);
    final target = latest.toUser?.trim() ?? '';
    final targetName = target.isNotEmpty
        ? GroupJoinApplicationService.instance.resolveDisplayName(userId: target)
        : '';
    switch (latest.type) {
      case 0:
        return AppI18n.of(context).format(
          zhHans: '{option1} 申请加入 {option2}',
          zhHant: '{option1} 申請加入 {option2}',
          en: '{option1} requested to join {option2}',
          ja: '{option1}が{option2}への参加を申請',
          ko: '{option1}님이 {option2} 참가를 요청함',
          vars: {'option1': displayApplicant, 'option2': groupName},
        );
      case 1:
      case 2:
        if (targetName.isNotEmpty) {
          return AppI18n.of(context).format(
            zhHans: '{option1} 邀请 {option2} 加入群聊',
            zhHant: '{option1} 邀請 {option2} 加入群聊',
            en: '{option1} invited {option2} to the group',
            ja: '{option1}が{option2}をグループに招待',
            ko: '{option1}님이 {option2}님을 그룹에 초대',
            vars: {'option1': displayApplicant, 'option2': targetName},
          );
        }
        return AppI18n.of(context).format(
          zhHans: '{option1} 邀请成员加入群聊',
          zhHant: '{option1} 邀請成員加入群聊',
          en: '{option1} invited members to the group',
          ja: '{option1}がメンバーをグループに招待',
          ko: '{option1}님이 멤버를 그룹에 초대',
          vars: {'option1': displayApplicant},
        );
      default:
        return AppI18n.of(context).format(
          zhHans: '{option1} 发起入群申请',
          zhHant: '{option1} 發起入群申請',
          en: '{option1} requested to join the group',
          ja: '{option1}がグループ参加を申請',
          ko: '{option1}님이 그룹 가입을 요청',
          vars: {'option1': displayApplicant},
        );
    }
  }

  String _systemNoticePreviewSubtitle(GroupSystemNoticeItem notice) {
    switch (notice.type) {
      case GroupSystemNoticeType.grantAdministrator:
        return AppI18n.of(context).format(
          zhHans: '{option1} 将 {option2} 设为管理员',
          zhHant: '{option1} 將 {option2} 設為管理員',
          en: '{option1} made {option2} an admin',
          ja: '{option1}が{option2}を管理者に設定',
          ko: '{option1}님이 {option2}님을 관리자로 지정',
          vars: {
            'option1': notice.operatorName,
            'option2': notice.targetName,
          },
        );
      case GroupSystemNoticeType.revokeAdministrator:
        return AppI18n.of(context).format(
          zhHans: '{option1} 取消了 {option2} 的管理员身份',
          zhHant: '{option1} 取消了 {option2} 的管理員身份',
          en: '{option1} removed {option2} as admin',
          ja: '{option1}が{option2}の管理者を解除',
          ko: '{option1}님이 {option2}님의 관리자를 해제',
          vars: {
            'option1': notice.operatorName,
            'option2': notice.targetName,
          },
        );
      case GroupSystemNoticeType.transferOwner:
        if (notice.operatorName.isEmpty &&
            notice.targetName ==
                AppI18n.of(context).t(
                  zhHans: '你',
                  zhHant: '你',
                  en: 'You',
                  ja: 'あなた',
                  ko: '나',
                )) {
          return AppI18n.of(context).t(
            zhHans: '群主已转让给你',
            zhHant: '群主已轉讓給你',
            en: 'Group ownership transferred to you',
            ja: 'グループオーナーがあなたに譲渡されました',
            ko: '그룹장이 당신에게 양도되었습니다',
          );
        }
        return AppI18n.of(context).format(
          zhHans: '{option1} 转让群主给 {option2}',
          zhHant: '{option1} 轉讓群主給 {option2}',
          en: '{option1} transferred ownership to {option2}',
          ja: '{option1}が{option2}にオーナーを譲渡',
          ko: '{option1}님이 {option2}님에게 그룹장 양도',
          vars: {
            'option1': notice.operatorName,
            'option2': notice.targetName,
          },
        );
    }
  }

  int _normalizeTimestampToMilliseconds(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return 0;
    }
    return timestamp < 1000000000000 ? timestamp * 1000 : timestamp;
  }

  int _normalizeTimestampToSeconds(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return 0;
    }
    return timestamp >= 1000000000000 ? timestamp ~/ 1000 : timestamp;
  }
}
