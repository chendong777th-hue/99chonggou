import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_system_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_change_event_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_entity_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_feed_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_create_limit_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_live/group_live_index_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_refresh_bus.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/listener_model/tui_group_listener_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_change_event_metadata.dart';

/// TCP `group_changed` 与离线 Push 补推的统一处理。
class GroupSyncService {
  GroupSyncService._();

  static final GroupSyncService instance = GroupSyncService._();

  final ValueNotifier<GroupChangedNotice?> lastChanged =
      ValueNotifier<GroupChangedNotice?>(null);

  // ignore: avoid_print
  static void _log(String message) {
    // Verbose sync tracing disabled.
  }

  static const Set<String> _groupInfoActions = <String>{
    'group_notice_changed',
    'group_name_changed',
    'group_avatar_changed',
    'group_mute_all_changed',
    'group_join_option_changed',
    'join_application_pending',
    'join_application_handled',
    'group_system_notice',
    'group_privacy_changed',
    'member_added',
    'member_removed',
    'member_left',
    'member_role_changed',
    'member_muted',
    'member_profile_changed',
    'owner_changed',
    'group_dismissed',
  };

  static const Set<String> memberCountRefreshActions = <String>{
    'member_added',
    'member_removed',
    'member_left',
  };

  static const Set<String> _memberListReloadActions = <String>{
    'member_added',
    'member_removed',
    'member_left',
    'member_role_changed',
    'owner_changed',
    'group_mute_all_changed',
    'member_muted',
  };

  /// 仅这些 action 的 detail.seq 属于群 Entity 游标，勿与 inbox seq 混用。
  static const Set<String> _entityRealtimeSeqActions = <String>{
    'group_name_changed',
    'group_avatar_changed',
    'group_notice_changed',
  };

  /// 自建群无 IM GroupTips 时，需要本地注入灰字的操作。
  static const Set<String> _grayTipActions = <String>{
    'member_muted',
    'group_mute_all_changed',
    'member_role_changed',
    'group_name_changed',
    'group_avatar_changed',
    'group_notice_changed',
  };

  Future<void> handleRealtimeEvent(FriendRealtimeEvent event) async {
    if (event.event.trim() != 'group_changed') {
      return;
    }
    final groupId = event.groupId?.trim() ?? '';
    final action = event.action?.trim().toLowerCase() ?? '';
    if (groupId.isEmpty || action.isEmpty) {
      _log('skip invalid group_changed groupId=$groupId action=$action');
      return;
    }

    _log(
      'group_changed groupId=$groupId action=$action '
      'operator=${event.operatorUserId} members=${event.memberUserIds.length}',
    );

    if (action == 'group_live_changed') {
      unawaited(
        GroupLiveIndexSyncService.instance.applyGroupLiveChanged(event),
      );
      lastChanged.value = GroupChangedNotice(
        groupId: groupId,
        action: action,
        operatorUserId: event.operatorUserId,
        memberUserIds: _resolveMemberUserIds(event),
        notification: _readNoticeFromDetail(event.detail),
        pushTs: event.ts,
        changeEventId: event.changeEventId,
        occurredAtMs: event.resolvedOccurredAtMs,
        timelineRank: event.timelineRank ??
            GroupChangeEventMetadata.defaultTimelineRankForAction(action),
        detail: event.detail,
      );
      return;
    }

    final changed =
        await GroupMembershipSyncService.instance.applyGroupChanged(event);
    if (changed) {
      await GroupMembershipSyncService.instance
          .afterGroupChangedApplied(action);
    }

    final detailSeq = _readSeqFromDetail(event.detail);
    if (detailSeq > 0) {
      if (action == 'group_system_notice') {
        unawaited(
          GroupNoticeIncrementalSyncService.instance.noteRealtimeSeq(detailSeq),
        );
      } else if (_entityRealtimeSeqActions.contains(action)) {
        unawaited(
          GroupEntityIncrementalSyncService.instance.noteRealtimeSeq(detailSeq),
        );
      }
    }
    final memberStreamSeq = _readMemberStreamSeqFromDetail(event.detail);
    if (memberStreamSeq > 0 && memberCountRefreshActions.contains(action)) {
      unawaited(
        GroupMemberIncrementalSyncService.instance.noteRealtimeSeq(
          groupId: groupId,
          seq: memberStreamSeq,
        ),
      );
    }

    final notice = GroupChangedNotice(
      groupId: groupId,
      action: action,
      operatorUserId: event.operatorUserId,
      memberUserIds: _resolveMemberUserIds(event),
      notification: _readNoticeFromDetail(event.detail),
      pushTs: event.ts,
      changeEventId: event.changeEventId,
      occurredAtMs: event.resolvedOccurredAtMs,
      timelineRank: event.timelineRank ??
          GroupChangeEventMetadata.defaultTimelineRankForAction(action),
      detail: event.detail,
    );

    if (memberCountRefreshActions.contains(action)) {
      unawaited(
        GroupChangeEventSyncService.instance.syncForGroup(
          groupId,
          reason: 'tcp_$action',
        ),
      );
      // 先成员首屏 + total，再通知 UI，避免聊天头读到旧人数。
      await GroupMembershipSyncService.instance.syncMembersAfterMembershipChange(
        groupId,
        reason: 'tcp_$action',
      );
      unawaited(
        GroupMembershipSyncService.instance.refreshGroupDetail(groupId),
      );
      _notifyGroupProfileRefresh(
        groupId: groupId,
        action: action,
      );
      lastChanged.value = notice;
    } else if (action == 'group_notice_changed') {
      GroupNoticeFeedLog.log('tcp_group_notice_changed', extras: {
        'groupId': groupId,
        'hasNotification':
            (notice.notification?.trim().isNotEmpty ?? false),
        'pushTs': notice.pushTs,
        'note': 'marquee_only_not_inbox_entry',
      });
      _notifyGroupProfileRefresh(
        groupId: groupId,
        action: action,
      );
      await _prefetchGroupInfo(groupId, event: event);
      lastChanged.value = notice;
      GroupNoticeRefreshBus.instance.notifyRefresh(
        groupId,
        notification: notice.notification,
        pushTs: notice.pushTs,
      );
    } else {
      _notifyGroupProfileRefresh(
        groupId: groupId,
        action: action,
      );
      lastChanged.value = notice;
      if (_groupInfoActions.contains(action) &&
          !_shouldSkipPrefetch(event, action)) {
        await _prefetchGroupInfo(groupId, event: event);
      }
    }

    // 聊天灰字改由操作端 App Custom；TCP 仅资料同步。
    if (_grayTipActions.contains(action)) {
      // no-op: 不再 publish 本地 tip
    }

    if (action == 'group_dismissed') {
      GroupCreateLimitRefreshBus.instance.notifyRefresh();
    }

    if (action == 'member_left' ||
        action == 'member_removed' ||
        action == 'group_dismissed') {
      unawaited(
        GroupMembershipSyncService.instance.pruneStaleGroupConversations(
          reason: 'group_changed_$action',
        ),
      );
    }

    if (action == 'join_application_pending' ||
        action == 'join_application_handled') {
      unawaited(
        GroupJoinApplicationService.instance.refresh(
          force: true,
          syncMembership: false,
        ),
      );
    }

    if (action == 'group_system_notice') {
      final detail = _mergeGroupNoticeDetail(event.detail, groupId);
      final detailType = (detail?['type'] ?? detail?['noticeType'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      GroupNoticeFeedLog.log('tcp_group_system_notice', extras: {
        'groupId': groupId,
        'detailType': detailType,
        'noticeId':
            (detail?['noticeId'] ?? detail?['notice_id'] ?? '').toString(),
      });
      if (detailType == 'NOTICE_DELETED' || detailType == 'NOTICE_HIDDEN') {
        final noticeId = (detail?['noticeId'] ?? detail?['notice_id'] ?? '')
            .toString()
            .trim();
        if (noticeId.isNotEmpty) {
          unawaited(
            GroupSystemNoticeService.instance.removeNoticeById(noticeId),
          );
        } else {
          unawaited(
            GroupNoticeIncrementalSyncService.instance.sync(
              reason: 'tcp_group_system_notice_delete',
            ),
          );
        }
      } else {
        final noticeId = (detail?['noticeId'] ?? detail?['notice_id'] ?? '')
            .toString()
            .trim();
        GroupSystemNoticeService.instance.upsertFromDetail(detail);
        if (noticeId.isEmpty) {
          unawaited(
            GroupNoticeIncrementalSyncService.instance.sync(
              reason: 'tcp_group_system_notice',
            ),
          );
        }
      }
    }

    ConversationRefreshBus.instance.requestRefresh(
      reason: 'group_changed_$action',
      delay: const Duration(milliseconds: 300),
    );
  }

  /// 邀请入群、审批通过等本地操作后主动刷新群资料与成员数（不依赖 TCP 时延）。
  Future<void> notifyGroupMembersChanged(
    String groupId, {
    String action = 'member_added',
    List<String> memberUserIds = const [],
    String? operatorUserId,
    int? occurredAtMs,
    String? changeEventId,
    int? timelineRank,
  }) async {
    final normalizedGroupId = groupId.trim();
    final normalizedAction = action.trim().toLowerCase();
    if (normalizedGroupId.isEmpty || normalizedAction.isEmpty) {
      return;
    }
    _log(
      'notifyGroupMembersChanged groupId=$normalizedGroupId '
      'action=$normalizedAction members=${memberUserIds.length}',
    );
    await GroupMembershipSyncService.instance.syncMembersAfterMembershipChange(
      normalizedGroupId,
      reason: 'local_$normalizedAction',
    );
    unawaited(
      GroupMembershipSyncService.instance.refreshGroupDetail(normalizedGroupId),
    );
    _notifyGroupProfileRefresh(
      groupId: normalizedGroupId,
      action: normalizedAction,
    );
    final notice = GroupChangedNotice(
      groupId: normalizedGroupId,
      action: normalizedAction,
      operatorUserId: operatorUserId,
      memberUserIds: memberUserIds,
      pushTs: DateTime.now().millisecondsSinceEpoch,
      occurredAtMs: occurredAtMs,
      changeEventId: changeEventId,
      timelineRank: timelineRank ??
          GroupChangeEventMetadata.defaultTimelineRankForAction(
            normalizedAction,
          ),
    );
    unawaited(
      GroupChangeEventSyncService.instance.syncForGroup(
        normalizedGroupId,
        reason: 'local_$normalizedAction',
      ),
    );
    lastChanged.value = notice;
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'group_changed_$normalizedAction',
      delay: const Duration(milliseconds: 300),
    );
  }

  Future<void> handlePushGroupChanged(Map<String, dynamic> data) async {
    final normalized = GroupChangeEventMetadata.normalizePushPayload(data);
    final event = FriendRealtimeEvent.fromJson(<String, dynamic>{
      ...normalized,
      'event': normalized['event'] ?? 'group_changed',
      'type': 'event',
    });
    await handleRealtimeEvent(event);
  }

  Future<void> _prefetchGroupInfo(
    String groupId, {
    FriendRealtimeEvent? event,
  }) async {
    try {
      if (SelfHostedGroupBridge.enabled) {
        await GroupMembershipSyncService.instance.refreshGroupDetail(groupId);
        return;
      }
      final groupServices = serviceLocator<GroupServices>();
      await groupServices.getGroupsInfo(groupIDList: [groupId]);
    } catch (e) {
      _log('prefetch group info failed groupId=$groupId error=$e');
    }
  }

  bool _shouldSkipPrefetch(FriendRealtimeEvent event, String action) {
    if (action == 'group_dismissed') {
      return true;
    }
    // 禁言状态已由 TCP detail 写入本地；GET /group 不含 shutUpAllMember，prefetch 会覆盖。
    if (action == 'group_mute_all_changed' || action == 'member_muted') {
      return true;
    }
    if (action != 'member_left' && action != 'member_removed') {
      return false;
    }
    final owner =
        ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
    if (owner.isEmpty) {
      return false;
    }
    final detail = event.detail ?? const <String, dynamic>{};
    final fromDetail = detail['memberUserIds'] ?? detail['member_user_ids'];
    final ids = <String>{
      ...event.memberUserIds.map(ChatIdFormat.rawUserUid),
      if (fromDetail is List)
        ...fromDetail.map((e) => ChatIdFormat.rawUserUid(e?.toString() ?? '')),
    }.where((id) => id.isNotEmpty);
    return ids.contains(owner);
  }

  void _notifyGroupProfileRefresh({
    required String groupId,
    required String action,
  }) {
    try {
      final listenerModel = serviceLocator<TUIGroupListenerModel>();
      if (_memberListReloadActions.contains(action)) {
        listenerModel.requestProfileRefresh(
          NeedUpdate(groupId, UpdateType.memberListReload, null),
        );
      } else if (_groupInfoActions.contains(action)) {
        listenerModel.requestProfileRefresh(
          NeedUpdate(groupId, UpdateType.groupInfo, ''),
        );
      } else {
        return;
      }
    } catch (e) {
      _log('notify group profile refresh failed groupId=$groupId error=$e');
    }
  }

  List<String> _resolveMemberUserIds(FriendRealtimeEvent event) {
    final ids = <String>{
      ...event.memberUserIds.map(ChatIdFormat.rawUserUid),
    };
    final detail = event.detail;
    if (detail != null) {
      for (final key in const ['userId', 'user_id', 'memberId', 'member_id']) {
        final userId = ChatIdFormat.rawUserUid(detail[key]?.toString() ?? '');
        if (userId.isNotEmpty) {
          ids.add(userId);
        }
      }
    }
    return ids.where((id) => id.isNotEmpty).toList(growable: false);
  }

  /// 成员流 seq：只读 `seq` / `member_seq`，勿把 `groupSeq`（Entity）混入。
  int _readMemberStreamSeqFromDetail(Map<String, dynamic>? detail) {
    if (detail == null || detail.isEmpty) {
      return 0;
    }
    for (final key in const ['seq', 'member_seq', 'memberSeq']) {
      final raw = detail[key];
      if (raw is int && raw > 0) {
        return raw;
      }
      if (raw is num && raw.toInt() > 0) {
        return raw.toInt();
      }
      final parsed = int.tryParse(raw?.toString() ?? '') ?? 0;
      if (parsed > 0) {
        return parsed;
      }
    }
    return 0;
  }

  int _readSeqFromDetail(Map<String, dynamic>? detail) {
    if (detail == null || detail.isEmpty) {
      return 0;
    }
    for (final key in const ['seq', 'group_seq', 'groupSeq', 'entitySeq']) {
      final raw = detail[key];
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      final parsed = int.tryParse(raw?.toString() ?? '') ?? 0;
      if (parsed > 0) {
        return parsed;
      }
    }
    return 0;
  }

  String? _readNoticeFromDetail(Map<String, dynamic>? detail) {
    if (detail == null || detail.isEmpty) {
      return null;
    }
    for (final key in const [
      'notification',
      'notice',
      'content',
      'groupNotice',
      'newNotice',
      'text',
    ]) {
      final value = detail[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Map<String, dynamic>? _mergeGroupNoticeDetail(
    Map<String, dynamic>? detail,
    String groupId,
  ) {
    if (detail == null || detail.isEmpty) {
      if (groupId.isEmpty) {
        return null;
      }
      return <String, dynamic>{'groupId': groupId};
    }
    final merged = Map<String, dynamic>.from(detail);
    final existingGroupId = merged['groupId']?.toString().trim() ?? '';
    if (existingGroupId.isEmpty && groupId.isNotEmpty) {
      merged['groupId'] = groupId;
    }
    return merged;
  }
}

class GroupChangedNotice {
  const GroupChangedNotice({
    required this.groupId,
    required this.action,
    this.operatorUserId,
    this.memberUserIds = const [],
    this.notification,
    this.pushTs,
    this.changeEventId,
    this.occurredAtMs,
    this.timelineRank,
    this.detail,
  });

  final String groupId;
  final String action;
  final String? operatorUserId;
  final List<String> memberUserIds;
  final String? notification;
  final int? pushTs;
  final String? changeEventId;
  final int? occurredAtMs;
  final int? timelineRank;
  final Map<String, dynamic>? detail;
}
