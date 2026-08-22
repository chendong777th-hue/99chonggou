import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_live_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_authorize_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_push_info_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_room_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_routing.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_info_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/group_live_message.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// Routes for group live flows from chat cards / top banner / more menu.
class GroupLiveNavigator {
  GroupLiveNavigator._();

  static Future<void> openFromPayload(
    BuildContext context, {
    required GroupLiveImPayload payload,
    GroupLiveSession? sessionHint,
  }) async {
    final sessionId = payload.liveSessionId.trim();
    if (sessionId.isEmpty) return;

    final session = sessionHint ??
        GroupLiveSession(
          liveSessionId: sessionId,
          groupId: payload.groupId,
          roomName: payload.roomName,
          anchorUserId: payload.anchorUserId,
          status: payload.status,
          scheduledStartAt: payload.scheduledStartAt,
        );

    if (payload.businessId == GroupLiveMessageIds.ended) {
      return;
    }

    if (payload.businessId == GroupLiveMessageIds.started ||
        payload.status == GroupLiveStatus.live) {
      final liveSession = GroupLiveSession(
        liveSessionId: session.liveSessionId,
        groupId: session.groupId,
        roomName: session.roomName,
        anchorUserId: session.anchorUserId,
        status: GroupLiveStatus.live,
        scheduledStartAt: session.scheduledStartAt,
        expireAt: session.expireAt,
        startedAt: session.startedAt,
        endedAt: session.endedAt,
        endReason: session.endReason,
      );
      final userId = GroupLiveRouting.currentUserId();
      final role = session.groupId.trim().isEmpty
          ? null
          : await GroupInfoResolver.instance.myRole(session.groupId);
      if (!context.mounted) return;
      if (role != null &&
          GroupLiveRouting.canAccessPushInfo(
            session: liveSession,
            currentUserId: userId,
            role: role,
          )) {
        await GroupLivePushInfoPage.open(
          context,
          liveSessionId: sessionId,
          initialSession: liveSession,
          groupId: session.groupId,
        );
        return;
      }
      await GroupLiveRoomPage.open(
        context,
        liveSessionId: sessionId,
        initialSession: sessionHint ?? liveSession,
      );
      return;
    }

    if (payload.businessId == GroupLiveMessageIds.ready ||
        payload.status == GroupLiveStatus.authorized) {
      await GroupLiveRouting.routeActiveSession(
        context,
        session: session,
        groupId: session.groupId,
      );
      return;
    }

    await GroupLiveRouting.routeActiveSession(
      context,
      session: session,
      groupId: session.groupId,
    );
  }

  static Future<void> openFromSession(
    BuildContext context, {
    required GroupLiveSession session,
  }) async {
    await GroupLiveRouting.routeActiveSession(
      context,
      session: session,
      groupId: session.groupId.trim(),
    );
  }

  static Future<void> openOwnerSchedule(BuildContext context, String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) return;

    try {
      final snapshot = await GroupLiveApi.instance.current(groupId: id);
      final session = snapshot.active ? snapshot.session : null;
      if (session != null && session.status.isActiveSlot) {
        await GroupLiveRouting.routeActiveSession(
          context,
          session: session,
          groupId: id,
        );
        return;
      }
    } catch (_) {
      // Fall through to fresh schedule when current is unavailable.
    }

    return GroupLiveAuthorizePage.openSchedule(context, groupId: id);
  }
}
