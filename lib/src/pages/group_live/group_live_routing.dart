import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_authorize_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_push_info_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_room_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_info_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// Shared routing rules for group live (push-info permissions per API 4.7).
class GroupLiveRouting {
  GroupLiveRouting._();

  static String currentUserId() =>
      TIMUIKitCore.getInstance().loginInfo.userID.trim();

  /// Who may open the OBS / push-info screen (anchor, owner, admin).
  static bool canViewPushInfoScreen({
    required GroupLiveSession session,
    required String currentUserId,
    required int role,
  }) {
    final anchorId = session.anchorUserId.trim();
    final selfId = currentUserId.trim();
    final isAnchor = anchorId.isNotEmpty && anchorId == selfId;
    return isAnchor || GroupRolePolicy.isManagerRole(role);
  }

  /// push-info API: designated anchor, group owner, or group admin; status AUTHORIZED/LIVE.
  static bool canAccessPushInfo({
    required GroupLiveSession session,
    required String currentUserId,
    required int role,
  }) {
    final anchorId = session.anchorUserId.trim();
    final selfId = currentUserId.trim();
    final isAnchor = anchorId.isNotEmpty && anchorId == selfId;
    if (!isAnchor && !GroupRolePolicy.isManagerRole(role)) {
      return false;
    }
    return session.status == GroupLiveStatus.authorized || session.isLive;
  }

  static Future<void> routeAfterAuthorize(
    BuildContext context, {
    required GroupLiveSession session,
    required String groupId,
  }) async {
    if (!context.mounted) return;

    final role = await GroupInfoResolver.instance.myRole(groupId);
    final resolvedRole =
        role ?? GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
    if (!context.mounted) return;

    if (!canViewPushInfoScreen(
      session: session,
      currentUserId: currentUserId(),
      role: resolvedRole,
    )) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '预约成功',
        zhHant: '預約成功',
        en: 'Scheduled successfully',
        ja: '予約しました',
        ko: '예약 완료',
      ));
      Navigator.of(context).pop(session);
      return;
    }

    if (session.status == GroupLiveStatus.scheduled) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '预约成功，到点后将显示 OBS 推流地址',
        zhHant: '預約成功，到點後將顯示 OBS 推流地址',
        en: 'Scheduled. OBS URLs will appear at the start time.',
        ja: '予約しました。開始時刻になると配信URLが表示されます。',
        ko: '예약되었습니다. 시작 시간에 OBS 推流 주소가 표시됩니다.',
      ));
    }

    await Navigator.of(context).pushReplacement(
      AppMaterialPageRoute(
        builder: (_) => GroupLivePushInfoPage(
          liveSessionId: session.liveSessionId,
          initialSession: session,
          groupId: groupId,
        ),
      ),
    );
  }

  static Future<void> routeActiveSession(
    BuildContext context, {
    required GroupLiveSession session,
    required String groupId,
  }) async {
    final id = groupId.trim();
    if (id.isEmpty) return;

    final userId = currentUserId();
    final role = await GroupInfoResolver.instance.myRole(id);
    final resolvedRole =
        role ?? GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
    if (!context.mounted) return;

    if (session.status == GroupLiveStatus.scheduled) {
      if (canViewPushInfoScreen(
        session: session,
        currentUserId: userId,
        role: resolvedRole,
      )) {
        await GroupLivePushInfoPage.open(
          context,
          liveSessionId: session.liveSessionId,
          initialSession: session,
          groupId: id,
        );
        return;
      }
      return;
    }

    if (canAccessPushInfo(
      session: session,
      currentUserId: userId,
      role: resolvedRole,
    )) {
      await GroupLivePushInfoPage.open(
        context,
        liveSessionId: session.liveSessionId,
        initialSession: session,
        groupId: id,
      );
      return;
    }

    if (session.isLive) {
      await GroupLiveRoomPage.open(
        context,
        liveSessionId: session.liveSessionId,
        initialSession: session,
      );
    }
  }
}
