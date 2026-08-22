import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/constants/group_governance_limits.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_change_event_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_bootstrap.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_leave_diag_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_governance_trace.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_tip_custom_sender.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_role_pending.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_self_involvement.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lock_profile_log.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_conversation_visibility.dart';
import 'package:tencent_cloud_chat_demo/utils/object_url_normalize.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/listener_model/tui_group_listener_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';

/// HTTP 全量 + TCP `group_changed` 增量，统一写入群本地库。
class GroupMembershipSyncService {
  GroupMembershipSyncService._();

  static final GroupMembershipSyncService instance =
      GroupMembershipSyncService._();

  bool _installed = false;
  bool _syncInFlight = false;
  bool _groupListSyncedOnce = false;
  String? _pendingSyncReason;
  final Map<String, Future<void>> _groupMemberRefreshInFlight = {};
  final Map<
      String,
      Future<V2TimValueCallback<V2TimGroupMemberInfoResult>>>
      _groupMemberPageInFlight = {};
  DateTime? _lastTcpAuthSyncAt;
  DateTime? _lastMeGroupsNetworkAt;
  Timer? _tcpAuthSyncFullTimer;
  int _tcpAuthSyncFullGeneration = 0;
  static const Duration _tcpAuthSyncCooldown = Duration(minutes: 10);

  /// 对齐服务端 `/me/groups` 约 10s 短缓存：非 refresh 短时重复拉直接跳过。
  static const Duration _meGroupsNetworkCooldown = Duration(seconds: 10);

  /// 已加群集合变更时递增，供消息列表重建过滤。
  final ValueNotifier<int> joinedGroupsRevision = ValueNotifier<int>(0);

  bool get hasSyncedGroupListOnce => _groupListSyncedOnce;

  bool isJoinedGroup(String groupId) {
    final id = ChatIdFormat.normalizeGroupId(groupId);
    if (id.isEmpty) {
      return false;
    }
    return GroupLocalStore.instance.readCached(groupId: id) != null;
  }

  bool shouldShowConversation(V2TimConversation conversation) {
    return shouldShowConversationForMembership(
      conversation: conversation,
      groupListSyncedOnce: _groupListSyncedOnce,
      isJoinedGroup: isJoinedGroup,
    );
  }

  void _bumpJoinedGroupsRevision() {
    joinedGroupsRevision.value++;
  }

  // ignore: avoid_print
  static void _log(String message) {
    // Verbose sync tracing disabled.
  }

  void install() {
    if (_installed) {
      return;
    }
    _installed = true;
    GroupMemberRolePending.instance.onReconcileDue = (groupId) {
      unawaited(_reconcilePendingMemberRoles(groupId));
    };
    final previous = FriendRealtimeService.instance.onAuthOk;
    FriendRealtimeService.instance.onAuthOk = () {
      previous?.call();
      unawaited(_onTcpAuthOk());
    };
  }

  Future<void> _onTcpAuthOk() async {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return;
    }
    final last = _lastTcpAuthSyncAt;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _tcpAuthSyncCooldown) {
      _log('tcp_auth_ok skip syncFull, cooldown');
      SqfliteLockProfileLog.event(
        'syncFull_skip',
        extras: <String, Object?>{
          'reason': 'tcp_auth_cooldown',
        },
      );
      unawaited(GroupNoticeBootstrap.refreshFromNetwork());
      return;
    }
    _lastTcpAuthSyncAt = now;
    unawaited(GroupNoticeBootstrap.refreshFromNetwork());
    if (!GroupLocalPerfFlags.tcpAuthSyncFullDelayEnabled ||
        GroupLocalPerfFlags.tcpAuthSyncFullDelay <= Duration.zero) {
      await syncFull(reason: 'tcp_auth_ok');
      return;
    }
    _tcpAuthSyncFullTimer?.cancel();
    final generation = ++_tcpAuthSyncFullGeneration;
    final expectedOwner = owner;
    _log(
      'tcp_auth_ok schedule syncFull delayMs='
      '${GroupLocalPerfFlags.tcpAuthSyncFullDelay.inMilliseconds}',
    );
    SqfliteLockProfileLog.event(
      'syncFull_schedule',
      extras: <String, Object?>{
        'reason': 'tcp_auth_ok',
        'delayMs': GroupLocalPerfFlags.tcpAuthSyncFullDelay.inMilliseconds,
      },
    );
    _tcpAuthSyncFullTimer = Timer(GroupLocalPerfFlags.tcpAuthSyncFullDelay, () {
      _tcpAuthSyncFullTimer = null;
      if (generation != _tcpAuthSyncFullGeneration) {
        return;
      }
      if (_ownerUserId() != expectedOwner) {
        _log('tcp_auth_ok delayed syncFull skipped owner_changed');
        SqfliteLockProfileLog.event(
          'syncFull_skip',
          extras: <String, Object?>{
            'reason': 'owner_changed',
          },
        );
        return;
      }
      unawaited(syncFull(reason: 'tcp_auth_ok'));
    });
  }

  String _ownerUserId() {
    return ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
  }

  Future<List<V2TimGroupInfo>> loadJoinedGroupsForUIKit() async {
    final owner = _ownerUserId();
    final local = await GroupLocalStore.instance.loadAsV2TimGroupInfos(
      ownerUserId: owner,
    );
    if (local.isNotEmpty) {
      return local;
    }
    await syncFull(reason: 'ui_empty_local');
    return GroupLocalStore.instance.loadAsV2TimGroupInfos(ownerUserId: owner);
  }

  Future<List<V2TimGroupInfoResult>> loadGroupsInfoForUIKit(
    List<String> groupIDList,
  ) async {
    final owner = _ownerUserId();
    final ids =
        groupIDList.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) {
      return const <V2TimGroupInfoResult>[];
    }
    final cached = await GroupLocalStore.instance.readAll(ownerUserId: owner);
    final byId = {for (final item in cached) item.groupId: item};
    final missing = ids.where((id) => !byId.containsKey(id)).toList();
    for (final groupId in missing) {
      try {
        final detail = await MeGroupApi.instance.fetchGroupDetail(groupId);
        if (detail != null) {
          await GroupLocalStore.instance.upsert(
            ownerUserId: owner,
            record: detail,
          );
          byId[groupId] = detail;
        }
      } catch (e) {
        _log('fetchGroupDetail failed groupId=$groupId error=$e');
      }
    }
    return ids.map((id) {
      final record = byId[id];
      if (record != null) {
        return record.toV2TimGroupInfoResult();
      }
      return V2TimGroupInfoResult(
        resultCode: -1,
        resultMessage: 'GROUP_NOT_FOUND',
        groupInfo: null,
      );
    }).toList(growable: false);
  }

  Future<V2TimValueCallback<V2TimGroupMemberInfoResult>> loadGroupMemberPage({
    required String groupID,
    required int count,
    required String nextSeq,
  }) async {
    final owner = _ownerUserId();
    final offset = _parseOffset(nextSeq);
    final limit = count.clamp(1, 100);
    final groupKey =
        ChatIdFormat.groupEquivalenceToken(groupID) ?? groupID.trim();
    final key = '$owner|$groupKey|$offset|$limit';
    final active = _groupMemberPageInFlight[key];
    if (active != null) {
      SqfliteLockProfileLog.event(
        'groupMemberPage_coalesced',
        extras: <String, Object?>{
          'groupId': groupID,
          'offset': offset,
          'limit': limit,
        },
      );
      return active;
    }
    late final Future<V2TimValueCallback<V2TimGroupMemberInfoResult>> tracked;
    tracked = _loadGroupMemberPageImpl(
      owner: owner,
      groupID: groupID,
      offset: offset,
      limit: limit,
    ).whenComplete(() {
      if (identical(_groupMemberPageInFlight[key], tracked)) {
        _groupMemberPageInFlight.remove(key);
      }
    });
    _groupMemberPageInFlight[key] = tracked;
    return tracked;
  }

  Future<V2TimValueCallback<V2TimGroupMemberInfoResult>>
      _loadGroupMemberPageImpl({
    required String owner,
    required String groupID,
    required int offset,
    required int limit,
  }) async {
    try {
      final page = await MeGroupApi.instance.fetchGroupMembersPage(
        groupId: groupID,
        limit: limit,
        offset: offset,
      );
      final nextOffset = offset + page.items.length;
      // 未满一页说明已到末页；勿仅凭 stale total 继续翻页，否则踢人后会重复追加成员。
      final hasMore = page.items.length >= limit && nextOffset < page.total;
      if (offset <= 0 && !hasMore) {
        await GroupMemberLocalStore.instance.replaceSnapshot(
          ownerUserId: owner,
          groupId: groupID,
          records: page.items,
        );
      } else {
        await GroupMemberLocalStore.instance.replacePage(
          ownerUserId: owner,
          groupId: groupID,
          offset: offset,
          records: page.items,
        );
      }
      final members = page.items.map(_toV2TimMember).toList(growable: false);
      return V2TimValueCallback(
        code: 0,
        desc: 'ok',
        data: V2TimGroupMemberInfoResult(
          nextSeq: hasMore ? nextOffset.toString() : '0',
          memberInfoList: members,
        ),
      );
    } catch (e) {
      _log('loadGroupMemberPage failed groupId=$groupID error=$e');
      return V2TimValueCallback(
        code: -1,
        desc: e.toString(),
        data:
            V2TimGroupMemberInfoResult(nextSeq: '0', memberInfoList: const []),
      );
    }
  }

  Future<V2TimValueCallback<List<V2TimGroupMemberFullInfo>>>
      loadGroupMembersInfo({
    required String groupID,
    required List<String> memberList,
  }) async {
    final owner = _ownerUserId();
    final requestedUserIds = memberList
        .map(ChatIdFormat.rawUserUid)
        .where((userId) => userId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final cached = await GroupMemberLocalStore.instance.readByUserIds(
      groupId: groupID,
      userIds: requestedUserIds,
      ownerUserId: owner,
    );
    if (cached.length == requestedUserIds.length) {
      return V2TimValueCallback(code: 0, desc: 'ok', data: cached);
    }
    try {
      await _runGroupMemberRefreshSingleFlight(
        ownerUserId: owner,
        groupId: groupID,
        refresh: () async {
          final page = await MeGroupApi.instance.fetchGroupMembersPage(
            groupId: groupID,
            limit: 100,
            offset: 0,
            refresh: true,
          );
          // This endpoint returns only the first page. It is not an authoritative
          // full-member snapshot, so retain cached later pages and merge the
          // newly fetched records instead of clearing the whole group cache.
          await GroupMemberLocalStore.instance.upsertMany(
            ownerUserId: owner,
            groupId: groupID,
            records: page.items,
          );
        },
      );
      final resolved = await GroupMemberLocalStore.instance.readByUserIds(
        groupId: groupID,
        userIds: requestedUserIds,
        ownerUserId: owner,
      );
      return V2TimValueCallback(code: 0, desc: 'ok', data: resolved);
    } catch (e) {
      return V2TimValueCallback(code: -1, desc: e.toString(), data: cached);
    }
  }

  Future<void> _runGroupMemberRefreshSingleFlight({
    required String ownerUserId,
    required String groupId,
    required Future<void> Function() refresh,
  }) {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    final group = groupId.trim();
    if (owner.isEmpty || group.isEmpty) {
      return Future<void>.sync(refresh);
    }
    final key = '$owner|$group';
    final active = _groupMemberRefreshInFlight[key];
    if (active != null) {
      SqfliteLockProfileLog.event(
        'groupMemberRefresh_coalesced',
        extras: <String, Object?>{'groupId': group},
      );
      return active;
    }
    late final Future<void> tracked;
    tracked = Future<void>.sync(refresh).whenComplete(() {
      if (identical(_groupMemberRefreshInFlight[key], tracked)) {
        _groupMemberRefreshInFlight.remove(key);
      }
    });
    _groupMemberRefreshInFlight[key] = tracked;
    return tracked;
  }

  @visibleForTesting
  Future<void> runGroupMemberRefreshSingleFlightForTest({
    required String ownerUserId,
    required String groupId,
    required Future<void> Function() refresh,
  }) {
    return _runGroupMemberRefreshSingleFlight(
      ownerUserId: ownerUserId,
      groupId: groupId,
      refresh: refresh,
    );
  }

  Future<V2TimCallback> updateGroupInfo({
    required V2TimGroupInfo info,
  }) async {
    final groupId = info.groupID.trim();
    if (groupId.isEmpty) {
      return MeGroupApi.failureCallback('INVALID_INPUT');
    }
    final hasName = info.groupName != null;
    final hasNotice = info.notification != null;
    final hasAvatar = info.faceUrl != null && info.faceUrl!.trim().isNotEmpty;
    final hasMuteAll = info.isAllMuted != null;
    if (!hasName && !hasNotice && !hasAvatar && !hasMuteAll) {
      return MeGroupApi.successCallback();
    }
    if (hasMuteAll && !hasName && !hasNotice && !hasAvatar) {
      final res = await MeGroupApi.instance.muteAllMembers(
        groupId: groupId,
        shutUpAllMember: info.isAllMuted!,
      );
      if (res.code != 0) {
        return res;
      }
      await _patchGroupFields(
        owner: _ownerUserId(),
        groupId: groupId,
        isAllMuted: info.isAllMuted,
      );
      notifyProfileRefresh(groupId, memberList: true);
      unawaited(
        GroupTipCustomSender.instance.send(
          groupId: groupId,
          action: info.isAllMuted! ? 'group_mute_all_on' : 'group_mute_all_off',
          detail: <String, dynamic>{
            'shutUpAllMember': info.isAllMuted,
            'isAllMuted': info.isAllMuted,
          },
        ),
      );
      return MeGroupApi.successCallback();
    }
    if (hasAvatar && !hasName && !hasNotice && !hasMuteAll) {
      await applyOptimisticAvatar(
          groupId: groupId, avatarUrl: info.faceUrl!.trim());
      unawaited(
        GroupTipCustomSender.instance.send(
          groupId: groupId,
          action: 'group_avatar_changed',
          detail: <String, dynamic>{
            'avatarUrl': info.faceUrl!.trim(),
          },
        ),
      );
      return MeGroupApi.successCallback();
    }
    try {
      var updated = await MeGroupApi.instance.updateGroup(
        groupId: groupId,
        groupName: hasName ? info.groupName : null,
        notice: hasNotice ? info.notification : null,
      );
      // REST 应返回 noticeUpdatedBy；若缺省则用当前操作者兜底。
      if (hasNotice && updated.noticeUpdatedBy.trim().isEmpty) {
        final selfId = _ownerUserId();
        if (selfId.isNotEmpty) {
          updated = updated.copyWith(noticeUpdatedBy: selfId);
        }
      }
      await GroupLocalStore.instance.upsert(
        ownerUserId: _ownerUserId(),
        record: updated,
      );
      if (hasName) {
        unawaited(
          GroupTipCustomSender.instance.send(
            groupId: groupId,
            action: 'group_name_changed',
            detail: <String, dynamic>{
              if (info.groupName != null) 'groupName': info.groupName,
            },
          ),
        );
      }
      if (hasNotice) {
        unawaited(
          GroupTipCustomSender.instance.send(
            groupId: groupId,
            action: 'group_notice_changed',
            detail: <String, dynamic>{
              if (info.notification != null) 'notice': info.notification,
            },
          ),
        );
      }
      if (hasAvatar) {
        await applyOptimisticAvatar(
            groupId: groupId, avatarUrl: info.faceUrl!.trim());
        unawaited(
          GroupTipCustomSender.instance.send(
            groupId: groupId,
            action: 'group_avatar_changed',
            detail: <String, dynamic>{
              'avatarUrl': info.faceUrl!.trim(),
            },
          ),
        );
      }
      if (hasMuteAll) {
        final muteRes = await MeGroupApi.instance.muteAllMembers(
          groupId: groupId,
          shutUpAllMember: info.isAllMuted!,
        );
        if (muteRes.code != 0) {
          return muteRes;
        }
        await _patchGroupFields(
          owner: _ownerUserId(),
          groupId: groupId,
          isAllMuted: info.isAllMuted,
        );
        unawaited(
          GroupTipCustomSender.instance.send(
            groupId: groupId,
            action:
                info.isAllMuted! ? 'group_mute_all_on' : 'group_mute_all_off',
            detail: <String, dynamic>{
              'shutUpAllMember': info.isAllMuted,
              'isAllMuted': info.isAllMuted,
            },
          ),
        );
      }
      if (hasMuteAll) {
        notifyProfileRefresh(groupId, memberList: true);
      }
      return MeGroupApi.successCallback();
    } catch (e) {
      return MeGroupApi.failureCallback(e.toString());
    }
  }

  Future<V2TimCallback> updateMyNameCard({
    required String groupId,
    required String userId,
    required String nameCard,
  }) async {
    final selfId = _ownerUserId();
    if (selfId.isEmpty || userId.trim() != selfId) {
      return MeGroupApi.failureCallback('NOT_SELF');
    }
    try {
      final updated = await MeGroupApi.instance.updateMyNameCard(
        groupId: groupId,
        nameCard: nameCard,
      );
      await applyOptimisticMyNameCard(groupId: groupId, nameCard: nameCard);
      if (updated.groupId.isNotEmpty) {
        await GroupLocalStore.instance.upsert(
          ownerUserId: selfId,
          record: updated,
        );
      }
      await GroupMemberLocalStore.instance.patchUser(
        ownerUserId: selfId,
        groupId: groupId,
        userId: selfId,
        transform: (current) =>
            current.copyWith(nameCard: nameCard, isSelf: true),
      );
      return MeGroupApi.successCallback();
    } catch (e) {
      return MeGroupApi.failureCallback(e.toString());
    }
  }

  Future<void> upsertCreatedGroup(MeGroupRecord record) async {
    final owner = _ownerUserId();
    if (owner.isEmpty || record.groupId.isEmpty) {
      return;
    }
    await GroupLocalStore.instance.upsert(ownerUserId: owner, record: record);
    await refreshUIKitGroupList();
  }

  Future<V2TimCallback> leaveGroup(String groupId) async {
    GroupLeaveDiagLog.log(
      'service_leave_start',
      groupId: groupId,
      extras: const <String, Object?>{'route': 'rest'},
    );
    final id = groupId.trim();
    final self = _ownerUserId();
    // 先发 tip 再 leave，保证操作端仍在群内可发 Custom。
    if (id.isNotEmpty && self.isNotEmpty) {
      await GroupTipCustomSender.instance.send(
        groupId: id,
        action: 'member_left',
        memberUserIds: <String>[self],
      );
    }
    return MeGroupApi.instance.leaveGroup(groupId);
  }

  Future<V2TimCallback> dismissGroup(String groupId) {
    GroupLeaveDiagLog.log(
      'service_dismiss_start',
      groupId: groupId,
      extras: const <String, Object?>{'route': 'rest'},
    );
    return MeGroupApi.instance.dismissGroup(groupId);
  }

  Future<V2TimCallback> kickGroupMember({
    required String groupID,
    required List<String> memberList,
  }) async {
    final id = groupID.trim();
    final owner = _ownerUserId();
    final normalized = memberList
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (id.isEmpty || normalized.isEmpty) {
      return MeGroupApi.failureCallback('INVALID_INPUT');
    }

    final removedUserIds = <String>[];
    int? latestMemberCount;
    String? firstFailureCode;

    for (var offset = 0; offset < normalized.length; offset += 100) {
      final end =
          offset + 100 > normalized.length ? normalized.length : offset + 100;
      final chunk = normalized.sublist(offset, end);
      final response = await MeGroupApi.instance.kickMembers(
        groupId: id,
        userIds: chunk,
      );
      if (!response.hasRemoved &&
          response.topLevelCode != null &&
          response.topLevelCode!.isNotEmpty &&
          response.topLevelCode != 'ok') {
        return MeGroupApi.failureCallback(response.topLevelCode!);
      }
      removedUserIds.addAll(response.removedUserIds);
      latestMemberCount = response.memberCount ?? latestMemberCount;
      for (final item in response.results) {
        if (item.status == GroupKickMemberStatus.failed) {
          firstFailureCode ??= item.code?.trim();
        }
      }
    }

    if (removedUserIds.isEmpty) {
      return MeGroupApi.failureCallback(firstFailureCode ?? 'KICK_FAILED');
    }

    await GroupMemberLocalStore.instance.deleteUsers(
      ownerUserId: owner,
      groupId: id,
      userIds: removedUserIds,
    );
    if (latestMemberCount != null && latestMemberCount >= 0) {
      await _patchGroupFields(
        owner: owner,
        groupId: id,
        memberCount: latestMemberCount,
      );
    } else {
      final current = await GroupLocalStore.instance.read(
        groupId: id,
        ownerUserId: owner,
      );
      if (current != null) {
        final nextCount = (current.memberCount - removedUserIds.length)
            .clamp(0, current.memberCount);
        await _patchGroupFields(
          owner: owner,
          groupId: id,
          memberCount: nextCount,
        );
      }
    }
    unawaited(
      GroupTipCustomSender.instance.send(
        groupId: id,
        action: 'member_removed',
        memberUserIds: removedUserIds,
      ),
    );
    unawaited(
      GroupSyncService.instance.notifyGroupMembersChanged(
        id,
        action: 'member_removed',
        memberUserIds: removedUserIds,
      ),
    );
    unawaited(
      GroupChangeEventSyncService.instance.syncForGroup(
        id,
        reason: 'kick_members',
      ),
    );
    if (removedUserIds.length < normalized.length) {
      return V2TimCallback(code: 0, desc: 'PARTIAL_SUCCESS');
    }
    return MeGroupApi.successCallback();
  }

  Future<V2TimCallback> setGroupMemberRole({
    required String groupID,
    required String userID,
    required int role,
  }) {
    return setGroupMemberRoles(
      groupID: groupID,
      userIDs: <String>[userID],
      role: role,
    );
  }

  Future<V2TimCallback> setGroupMemberRoles({
    required String groupID,
    required List<String> userIDs,
    required int role,
  }) async {
    final groupId = groupID.trim();
    final owner = _ownerUserId();
    final seen = <String>{};
    final memberIds = <String>[];
    for (final raw in userIDs) {
      final uid = ChatIdFormat.rawUserUid(raw);
      if (uid.isEmpty || !seen.add(uid)) {
        continue;
      }
      memberIds.add(uid);
    }
    if (groupId.isEmpty || memberIds.isEmpty) {
      return MeGroupApi.failureCallback('INVALID_INPUT');
    }
    if (role != GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN &&
        role != GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER) {
      return MeGroupApi.failureCallback('INVALID_INPUT');
    }

    if (role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN) {
      final locals = await GroupMemberLocalStore.instance.readAll(
        groupId: groupId,
        ownerUserId: owner,
      );
      final adminCount = locals
          .where(
            (item) =>
                item.role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN,
          )
          .length;
      final alreadyAdmin = locals
          .where(
            (item) =>
                memberIds.contains(item.userId) &&
                item.role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN,
          )
          .length;
      final newAdmins = memberIds.length - alreadyAdmin;
      if (adminCount + newAdmins > GroupGovernanceLimits.maxAdminCount) {
        return MeGroupApi.failureCallback('ADMIN_LIMIT');
      }
    }

    final response = await MeGroupApi.instance.setMemberRoles(
      groupId: groupId,
      role: role,
      userIds: memberIds,
    );
    if (response.topLevelCode != null &&
        response.topLevelCode!.isNotEmpty &&
        response.topLevelCode != 'ok' &&
        !response.hasAccepted) {
      return MeGroupApi.failureCallback(response.topLevelCode!);
    }
    final accepted = response.acceptedUserIds;
    if (accepted.isEmpty) {
      final firstCode =
          response.results.map((item) => item.code?.trim()).firstWhere(
                (code) => code != null && code.isNotEmpty,
                orElse: () => null,
              );
      return MeGroupApi.failureCallback(firstCode ?? 'INVALID_RESPONSE');
    }

    final previousByUser = <String, int>{};
    final locals = await GroupMemberLocalStore.instance.readAll(
      groupId: groupId,
      ownerUserId: owner,
    );
    for (final item in locals) {
      previousByUser[item.userId] = item.role;
    }

    for (final memberId in accepted) {
      final previous = previousByUser[memberId] ??
          GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
      GroupMemberRolePending.instance.register(
        groupId: groupId,
        userId: memberId,
        expectedRole: role,
        previousRole: previous,
        operatorUserId: owner,
      );
      await GroupMemberLocalStore.instance.patchUser(
        ownerUserId: owner,
        groupId: groupId,
        userId: memberId,
        transform: (current) => current.copyWith(role: role),
      );
      if (memberId == owner) {
        await _patchGroupFields(
          owner: owner,
          groupId: groupId,
          myRole: role,
        );
      }
    }

    notifyProfileRefresh(groupId, memberList: true);

    final tipAction = role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN
        ? 'member_set_admin'
        : 'member_cancel_admin';
    unawaited(
      GroupTipCustomSender.instance.send(
        groupId: groupId,
        action: tipAction,
        memberUserIds: accepted,
        detail: <String, dynamic>{
          'role': role,
          'myRole': role,
        },
      ),
    );
    return MeGroupApi.successCallback();
  }

  Future<void> _reconcilePendingMemberRoles(String groupId) async {
    final id = groupId.trim();
    final owner = _ownerUserId();
    final expired = GroupMemberRolePending.instance.takeExpiredForGroup(id);
    if (id.isEmpty || owner.isEmpty || expired.isEmpty) {
      return;
    }
    try {
      final page = await MeGroupApi.instance.fetchGroupMembersPage(
        groupId: id,
        limit: 100,
        offset: 0,
        refresh: true,
      );
      await GroupMemberLocalStore.instance.upsertMany(
        ownerUserId: owner,
        groupId: id,
        records: page.items,
      );
      final byUser = <String, int>{
        for (final item in page.items) item.userId: item.role,
      };
      for (final entry in expired) {
        final serverRole = byUser[entry.userId];
        if (serverRole == null || serverRole <= 0) {
          continue;
        }
        await GroupMemberLocalStore.instance.patchUser(
          ownerUserId: owner,
          groupId: id,
          userId: entry.userId,
          transform: (current) => current.copyWith(role: serverRole),
        );
        if (entry.userId == owner) {
          await _patchGroupFields(
            owner: owner,
            groupId: id,
            myRole: serverRole,
          );
        }
      }
      notifyProfileRefresh(id, memberList: true);
    } catch (e) {
      _log('reconcilePendingMemberRoles failed groupId=$id error=$e');
    }
  }

  Future<V2TimCallback> transferGroupOwner({
    required String groupID,
    required String userID,
  }) async {
    final groupId = groupID.trim();
    final newOwnerId = ChatIdFormat.rawUserUid(userID);
    final owner = _ownerUserId();
    GroupGovernanceTrace.log(
      'transfer_owner_service_start',
      extras: <String, Object?>{
        'groupId': groupId,
        'oldOwnerUserId': owner,
        'newOwnerUserId': newOwnerId,
      },
    );
    if (groupId.isEmpty || newOwnerId.isEmpty) {
      GroupGovernanceTrace.log(
        'transfer_owner_service_invalid_input',
        extras: <String, Object?>{
          'groupId': groupId,
          'oldOwnerUserId': owner,
          'newOwnerUserId': newOwnerId,
        },
      );
      return MeGroupApi.failureCallback('INVALID_INPUT');
    }
    if (owner.isEmpty) {
      GroupGovernanceTrace.log(
        'transfer_owner_service_auth_not_ready',
        extras: <String, Object?>{
          'groupId': groupId,
          'newOwnerUserId': newOwnerId,
        },
      );
      return MeGroupApi.failureCallback('AUTH_NOT_READY');
    }
    final res = await MeGroupApi.instance.transferOwner(
      groupId: groupId,
      newOwnerUserId: newOwnerId,
    );
    if (res.code != 0) {
      GroupGovernanceTrace.log(
        'transfer_owner_service_failed',
        extras: <String, Object?>{
          'groupId': groupId,
          'oldOwnerUserId': owner,
          'newOwnerUserId': newOwnerId,
          'code': res.code,
          'desc': res.desc,
        },
      );
      return res;
    }
    if (newOwnerId == owner) {
      await _patchGroupFields(
        owner: owner,
        groupId: groupId,
        ownerUserId: newOwnerId,
        myRole: GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER,
      );
    } else {
      await _patchGroupFields(
        owner: owner,
        groupId: groupId,
        ownerUserId: newOwnerId,
        myRole: GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER,
      );
    }
    await GroupMemberLocalStore.instance.patchUser(
      ownerUserId: owner,
      groupId: groupId,
      userId: owner,
      transform: (current) => current.copyWith(
        role: newOwnerId == owner
            ? GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER
            : GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER,
      ),
    );
    await GroupMemberLocalStore.instance.patchUser(
      ownerUserId: owner,
      groupId: groupId,
      userId: newOwnerId,
      transform: (current) => current.copyWith(
        role: GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER,
      ),
    );
    notifyProfileRefresh(groupId, memberList: true);
    await refreshUIKitGroupList();
    GroupGovernanceTrace.log(
      'transfer_owner_service_success',
      extras: <String, Object?>{
        'groupId': groupId,
        'oldOwnerUserId': owner,
        'newOwnerUserId': newOwnerId,
      },
    );
    unawaited(
      GroupTipCustomSender.instance.send(
        groupId: groupId,
        action: 'owner_changed',
        memberUserIds: <String>[newOwnerId],
        detail: <String, dynamic>{
          'ownerUserId': newOwnerId,
          'previousOwnerUserId': owner,
        },
      ),
    );
    return res;
  }

  Future<V2TimCallback> muteGroupMember({
    required String groupID,
    required String userID,
    required int seconds,
  }) async {
    final groupId = groupID.trim();
    final memberId = ChatIdFormat.rawUserUid(userID);
    final owner = _ownerUserId();
    if (groupId.isEmpty || memberId.isEmpty) {
      return MeGroupApi.failureCallback('INVALID_INPUT');
    }
    final res = await MeGroupApi.instance.muteMember(
      groupId: groupId,
      userId: memberId,
      muteSeconds: seconds,
    );
    if (res.code != 0) {
      return res;
    }
    final muteUntil = seconds > 0
        ? DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + seconds
        : 0;
    await GroupMemberLocalStore.instance.patchUser(
      ownerUserId: owner,
      groupId: groupId,
      userId: memberId,
      transform: (current) => current.copyWith(muteUntil: muteUntil),
    );
    _patchMemoryMemberMuteUntil(
      groupId: groupId,
      userId: memberId,
      muteUntil: muteUntil,
    );
    notifyProfileRefresh(groupId, memberList: true);
    unawaited(
      GroupTipCustomSender.instance.send(
        groupId: groupId,
        action: seconds > 0 ? 'member_muted' : 'member_unmuted',
        memberUserIds: <String>[memberId],
        detail: <String, dynamic>{
          'userId': memberId,
          'muteUntil': muteUntil,
          'muteSeconds': seconds,
        },
      ),
    );
    return res;
  }

  /// [refresh] 仅建群失败 recovery 等显式场景传 true；会话列表 / 常规同步必须 false。
  Future<void> syncFull(
      {String reason = 'manual', bool refresh = false}) async {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return;
    }
    if (_syncInFlight) {
      _pendingSyncReason = reason;
      return;
    }
    // 服务端约 10s 短缓存；非 refresh 时短时间重复拉无意义。
    if (!refresh &&
        _groupListSyncedOnce &&
        _lastMeGroupsNetworkAt != null &&
        DateTime.now().difference(_lastMeGroupsNetworkAt!) <
            _meGroupsNetworkCooldown) {
      _log('syncFull skip reason=$reason cooldown=10s');
      SqfliteLockProfileLog.event(
        'syncFull_skip',
        extras: <String, Object?>{
          'reason': reason,
          'cause': 'network_cooldown',
        },
      );
      return;
    }
    _syncInFlight = true;
    try {
      _log('syncFull start reason=$reason refresh=$refresh');
      SqfliteLockProfileLog.event(
        'syncFull_start',
        extras: <String, Object?>{
          'reason': reason,
          'refresh': refresh,
        },
      );
      final existing = await GroupLocalStore.instance.readAll(
        ownerUserId: owner,
        caller: 'syncFull',
      );
      final existingById = {for (final item in existing) item.groupId: item};
      final records = await MeGroupApi.instance.fetchMyGroupsFromNetwork(
        refresh: refresh,
        preserveIsAllMutedFrom: existingById,
      );
      _lastMeGroupsNetworkAt = DateTime.now();
      final joinedIds = records
          .map((item) => item.groupId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      final removedGroupIds = removedGroupIdsByEquivalence(
        existingIds: existing.map((item) => item.groupId),
        joinedIds: joinedIds,
      );
      await GroupLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: records,
        // 同一次 syncFull 内复用上方 readAll，避免二次全表过 Channel。
        existingSnapshot: existing,
      );
      _groupListSyncedOnce = true;
      _bumpJoinedGroupsRevision();
      for (final groupId in removedGroupIds) {
        await _purgeGroupConversation(groupId);
      }
      await pruneStaleGroupConversations(reason: 'sync_full_$reason');
      _log(
          'syncFull done count=${records.length} removed=${removedGroupIds.length}');
      SqfliteLockProfileLog.event(
        'syncFull_done',
        extras: <String, Object?>{
          'reason': reason,
          'count': records.length,
          'removed': removedGroupIds.length,
        },
      );
      unawaited(
        GroupChangeEventSyncService.instance.syncMyEvents(
          reason: 'sync_full_$reason',
        ),
      );
      _lastTcpAuthSyncAt = DateTime.now();
    } catch (e) {
      _log('syncFull failed: $e');
      SqfliteLockProfileLog.event(
        'syncFull_fail',
        extras: <String, Object?>{
          'reason': reason,
          'error': '$e',
        },
      );
      rethrow;
    } finally {
      _syncInFlight = false;
      final pending = _pendingSyncReason;
      _pendingSyncReason = null;
      if (pending != null) {
        unawaited(syncFull(reason: pending, refresh: refresh));
      }
    }
  }

  Future<void> refreshGroupDetail(String groupId,
      {bool refresh = false}) async {
    final owner = _ownerUserId();
    final id = groupId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    try {
      final current = await GroupLocalStore.instance.read(
        groupId: id,
        ownerUserId: owner,
      );
      final detail = await MeGroupApi.instance.fetchGroupDetail(
        id,
        refresh: refresh,
        preserveIsAllMutedFrom: current,
      );
      if (detail != null) {
        await GroupLocalStore.instance
            .upsert(ownerUserId: owner, record: detail);
      }
    } catch (e) {
      _log('refreshGroupDetail failed groupId=$id error=$e');
    }
  }

  Future<bool> applyGroupChanged(FriendRealtimeEvent event) async {
    if (event.event.trim() != 'group_changed') {
      return false;
    }
    final groupId = event.groupId?.trim() ?? '';
    final action = event.action?.trim().toLowerCase() ?? '';
    if (groupId.isEmpty || action.isEmpty) {
      return false;
    }
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return false;
    }
    final detail = event.detail ?? const <String, dynamic>{};
    final memberIds = _memberIds(event, detail);
    final selfInvolved = _isSelfRemovedFromGroupEvent(
      action: action,
      owner: owner,
      memberIds: memberIds,
      event: event,
    );

    switch (action) {
      case 'group_dismissed':
        await GroupLocalStore.instance
            .delete(ownerUserId: owner, groupId: groupId);
        await GroupMemberLocalStore.instance.clearGroup(
          ownerUserId: owner,
          groupId: groupId,
        );
        _bumpJoinedGroupsRevision();
        await _purgeGroupConversation(groupId);
        return true;
      case 'member_left':
      case 'member_removed':
        if (selfInvolved) {
          await GroupLocalStore.instance
              .delete(ownerUserId: owner, groupId: groupId);
          await GroupMemberLocalStore.instance.clearGroup(
            ownerUserId: owner,
            groupId: groupId,
          );
          _bumpJoinedGroupsRevision();
          await _purgeGroupConversation(groupId);
        } else {
          await GroupMemberLocalStore.instance.deleteUsers(
            ownerUserId: owner,
            groupId: groupId,
            userIds: memberIds,
          );
          await _patchGroupFields(
            owner: owner,
            groupId: groupId,
            memberCount: _readInt(detail['memberCount']),
          );
        }
        return true;
      case 'member_added':
        if (selfInvolved) {
          if (_detailLooksLikeGroupProfile(detail)) {
            final record = MeGroupRecord.fromJson(detail);
            if (record.groupId.isNotEmpty) {
              await GroupLocalStore.instance.upsert(
                ownerUserId: owner,
                record: record,
              );
              _bumpJoinedGroupsRevision();
            }
          } else {
            await refreshGroupDetail(groupId, refresh: true);
            _bumpJoinedGroupsRevision();
          }
        } else {
          await _patchGroupFields(
            owner: owner,
            groupId: groupId,
            memberCount: _readInt(detail['memberCount']),
            incrementIfMissing: memberIds.length,
          );
        }
        return true;
      case 'group_name_changed':
        await _patchGroupFields(
          owner: owner,
          groupId: groupId,
          groupName: detail['groupName']?.toString(),
          updatedAt: _readInt(detail['updatedAt']),
        );
        return true;
      case 'group_notice_changed':
        final noticeUpdatedBy = ChatIdFormat.rawUserUid(
          detail['noticeUpdatedBy']?.toString() ??
              detail['notice_updated_by']?.toString() ??
              event.operatorUserId ??
              '',
        );
        final noticeUpdatedAt = _readInt(
          detail['noticeUpdatedAt'] ?? detail['notice_updated_at'],
        );
        final updatedAt = _readInt(detail['updatedAt']);
        await _patchGroupFields(
          owner: owner,
          groupId: groupId,
          notice: detail['notice']?.toString(),
          noticeUpdatedAt: noticeUpdatedAt > 0 ? noticeUpdatedAt : null,
          noticeUpdatedBy: noticeUpdatedBy.isNotEmpty ? noticeUpdatedBy : null,
          updatedAt: updatedAt > 0 ? updatedAt : null,
        );
        return true;
      case 'group_avatar_changed':
        await upsertGroupAvatar(
          groupId: groupId,
          avatarUrl: _readGroupAvatarUrl(detail),
        );
        return true;
      case 'member_profile_changed':
        final userId = ChatIdFormat.rawUserUid(
          detail['userId']?.toString() ?? memberIds.firstOrNull ?? '',
        );
        final nameCard = detail['nameCard']?.toString();
        if (userId.isEmpty) {
          return false;
        }
        if (userId == owner && nameCard != null) {
          await applyOptimisticMyNameCard(groupId: groupId, nameCard: nameCard);
        }
        if (nameCard != null) {
          await GroupMemberLocalStore.instance.patchUser(
            ownerUserId: owner,
            groupId: groupId,
            userId: userId,
            transform: (current) => current.copyWith(nameCard: nameCard),
          );
        }
        return true;
      case 'member_role_changed':
        final userId =
            ChatIdFormat.rawUserUid(detail['userId']?.toString() ?? '');
        final role = _readInt(detail['myRole'] ?? detail['role']);
        if (userId.isNotEmpty && role > 0) {
          GroupMemberRolePending.instance.acknowledgeTcp(
            groupId: groupId,
            userId: userId,
            role: role,
          );
        }
        if (userId == owner && role > 0) {
          await _patchGroupFields(owner: owner, groupId: groupId, myRole: role);
        }
        if (userId.isNotEmpty && role > 0) {
          await GroupMemberLocalStore.instance.patchUser(
            ownerUserId: owner,
            groupId: groupId,
            userId: userId,
            transform: (current) => current.copyWith(role: role),
          );
        }
        notifyProfileRefresh(groupId, memberList: true);
        return true;
      case 'owner_changed':
        await _patchGroupFields(
          owner: owner,
          groupId: groupId,
          ownerUserId: detail['ownerUserId']?.toString(),
          updatedAt: _readInt(detail['updatedAt']),
        );
        return true;
      case 'group_mute_all_changed':
        final isAllMuted = _readBool(
          detail['shutUpAllMember'] ?? detail['isAllMuted'],
        );
        await _patchGroupFields(
          owner: owner,
          groupId: groupId,
          isAllMuted: isAllMuted,
        );
        return true;
      case 'member_muted':
        final userId = ChatIdFormat.rawUserUid(
          detail['userId']?.toString() ?? memberIds.firstOrNull ?? '',
        );
        final muteUntil = _readInt(detail['muteUntil']);
        if (userId.isNotEmpty) {
          await GroupMemberLocalStore.instance.patchUser(
            ownerUserId: owner,
            groupId: groupId,
            userId: userId,
            transform: (current) => current.copyWith(
              muteUntil: muteUntil > 0 ? muteUntil : 0,
            ),
          );
          _patchMemoryMemberMuteUntil(
            groupId: groupId,
            userId: userId,
            muteUntil: muteUntil > 0 ? muteUntil : 0,
          );
        }
        return true;
      default:
        return false;
    }
  }

  Future<void> afterGroupChangedApplied(String action) async {
    final normalized = action.trim().toLowerCase();
    const membershipActions = <String>{
      'member_added',
      'member_removed',
      'member_left',
      'group_dismissed',
      'group_name_changed',
      'group_avatar_changed',
    };
    if (membershipActions.contains(normalized)) {
      await refreshUIKitGroupList();
    }
  }

  Future<void> upsertGroupAvatar({
    required String groupId,
    required String avatarUrl,
  }) async {
    final id = groupId.trim();
    final normalized = normalizeObjectUrl(avatarUrl.trim());
    if (id.isEmpty || normalized.isEmpty) {
      return;
    }
    await _patchGroupFields(
      owner: _ownerUserId(),
      groupId: id,
      avatarUrl: normalized,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      serviceLocator<TUIConversationViewModel>().updateGroupFaceUrl(
        id,
        normalized,
      );
    } catch (e) {
      _log('upsertGroupAvatar updateGroupFaceUrl failed groupId=$id error=$e');
    }
    notifyProfileRefresh(id);
    await refreshUIKitGroupList();
  }

  Future<void> applyOptimisticAvatar({
    required String groupId,
    required String avatarUrl,
  }) async {
    await upsertGroupAvatar(groupId: groupId, avatarUrl: avatarUrl);
  }

  Future<void> applyOptimisticMyNameCard({
    required String groupId,
    required String nameCard,
  }) async {
    await _patchGroupFields(
      owner: _ownerUserId(),
      groupId: groupId,
      myNameCard: nameCard,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> applyOptimisticGroupName({
    required String groupId,
    required String groupName,
  }) async {
    await _patchGroupFields(
      owner: _ownerUserId(),
      groupId: groupId,
      groupName: groupName,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> applyOptimisticNotice({
    required String groupId,
    required String notice,
  }) async {
    final selfId = _ownerUserId();
    await _patchGroupFields(
      owner: selfId,
      groupId: groupId,
      notice: notice,
      noticeUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      noticeUpdatedBy: selfId.isNotEmpty ? selfId : null,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> refreshUIKitGroupList() async {
    try {
      await serviceLocator<TUIFriendShipViewModel>().loadGroupListData();
    } catch (e) {
      _log('refreshUIKitGroupList failed: $e');
    }
  }

  /// 本端主动退群/解散成功后，立即从本地库移除并刷新群列表 UI。
  Future<void> onSelfRemovedFromGroup(String groupId) async {
    final owner = _ownerUserId();
    final id = groupId.trim();
    GroupLeaveDiagLog.log(
      'local_cleanup_start',
      groupId: id,
      extras: <String, Object?>{'ownerUserId': owner},
    );
    if (owner.isEmpty || id.isEmpty) {
      GroupLeaveDiagLog.log(
        'local_cleanup_skip',
        groupId: id,
        extras: <String, Object?>{'ownerUserId': owner},
      );
      return;
    }
    GroupMemberRolePending.instance.clearGroup(id);
    await GroupLocalStore.instance.delete(ownerUserId: owner, groupId: id);
    await GroupMemberLocalStore.instance.clearGroup(
      ownerUserId: owner,
      groupId: id,
    );
    _bumpJoinedGroupsRevision();
    await refreshUIKitGroupList();
    await _purgeGroupConversation(id);
    GroupLeaveDiagLog.log(
      'local_cleanup_done',
      groupId: id,
      extras: <String, Object?>{'ownerUserId': owner},
    );
  }

  /// 从 IM SDK 与本地会话库移除群会话，并通知消息列表刷新。
  Future<void> _purgeGroupConversation(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return;
    }
    await _clearGroupChatHistory(id);
    final conversationId = 'group_$id';
    // 清历史路径会故意「保壳」；退群/幽灵清理必须强制删掉会话行。
    ArchiveHistoryProvider.clearHistoryClearPending(id);
    ArchiveHistoryProvider.clearHistoryClearPending(conversationId);
    try {
      await serviceLocator<ConversationService>().deleteConversation(
        conversationID: conversationId,
      );
    } catch (e) {
      _log('purgeGroupConversation sdk delete failed groupId=$id error=$e');
      GroupLeaveDiagLog.log(
        'purge_conversation_sdk_fail',
        groupId: id,
        extras: <String, Object?>{'error': e.toString()},
      );
    }
    try {
      await ConversationSyncService.instance.onViewModelConversationsDeleted(
        <String>[conversationId],
        force: true,
      );
    } catch (e) {
      _log('purgeGroupConversation local delete failed groupId=$id error=$e');
      GroupLeaveDiagLog.log(
        'purge_conversation_local_fail',
        groupId: id,
        extras: <String, Object?>{'error': e.toString()},
      );
    }
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'group_self_removed',
      conversationId: conversationId,
      delay: const Duration(milliseconds: 200),
    );
  }

  /// 退群/被踢后清空本端 IM 记录、归档兜底与内存消息列表。
  Future<void> _clearGroupChatHistory(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return;
    }
    GroupLeaveDiagLog.log(
      'clear_history_start',
      groupId: id,
    );

    final globalModel = serviceLocator<TUIChatGlobalModel>();
    for (final key in <String>{id, 'group_$id'}) {
      globalModel.clearLocalHistoryAsEmptyLoaded(key);
    }

    ArchiveHistoryProvider.markHistoryClearPending(id);
    try {
      if (kIsWeb) {
        await ArchiveHistoryProvider.completeHistoryClear(
          isGroup: true,
          conversationID: id,
        );
        GroupLeaveDiagLog.log(
          'clear_history_done',
          groupId: id,
          extras: const <String, Object?>{'route': 'web_archive_only'},
        );
        return;
      }

      final result = await serviceLocator<MessageService>()
          .clearGroupHistoryMessage(groupID: id);
      if (result.code == 0) {
        await ArchiveHistoryProvider.completeHistoryClear(
          isGroup: true,
          conversationID: id,
        );
        GroupLeaveDiagLog.log('clear_history_done', groupId: id);
        return;
      }

      ArchiveHistoryProvider.clearHistoryClearPending(id);
      GroupLeaveDiagLog.log(
        'clear_history_sdk_fail',
        groupId: id,
        extras: <String, Object?>{'code': result.code, 'desc': result.desc},
      );
    } catch (e) {
      ArchiveHistoryProvider.clearHistoryClearPending(id);
      _log('clearGroupChatHistory failed groupId=$id error=$e');
      GroupLeaveDiagLog.log(
        'clear_history_fail',
        groupId: id,
        extras: <String, Object?>{'error': e.toString()},
      );
    }
  }

  /// 已退群但 IM 会话仍残留在列表时，按本地群成员表对齐剔除。
  Future<void> pruneStaleGroupConversations({String reason = 'manual'}) async {
    if (!SelfHostedGroupBridge.governanceEnabled) {
      return;
    }
    final owner = _ownerUserId();
    if (owner.isEmpty || !_groupListSyncedOnce) {
      return;
    }
    final joinedIds =
        (await GroupLocalStore.instance.readAll(ownerUserId: owner))
            .map((group) => group.groupId.trim())
            .where((id) => id.isNotEmpty)
            .toSet();
    final conversations =
        await ConversationLocalStore.instance.listGroupConversationIds(
      ownerUserId: owner,
    );
    final conversationGroupIds = <String>[];
    for (final conversationId in conversations) {
      if (!conversationId.startsWith('group_')) {
        continue;
      }
      final groupId = conversationId.substring(6);
      if (groupId.isNotEmpty) {
        conversationGroupIds.add(groupId);
      }
    }
    final staleGroupIds = removedGroupIdsByEquivalence(
      existingIds: conversationGroupIds,
      joinedIds: joinedIds,
    );
    if (staleGroupIds.isEmpty) {
      return;
    }
    _log(
      'pruneStaleGroupConversations reason=$reason count=${staleGroupIds.length}',
    );
    for (final groupId in staleGroupIds) {
      await _purgeGroupConversation(groupId);
    }
  }

  @visibleForTesting
  static List<String> removedGroupIdsByEquivalence({
    required Iterable<String> existingIds,
    required Iterable<String> joinedIds,
  }) {
    final joinedKeys = joinedIds
        .map(GroupLocalStore.groupEquivalenceKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    return existingIds
        .map((id) => id.trim())
        .where((id) =>
            id.isNotEmpty &&
            !joinedKeys.contains(GroupLocalStore.groupEquivalenceKey(id)))
        .toList(growable: false);
  }

  bool _isSelfRemovedFromGroupEvent({
    required String action,
    required String owner,
    required List<String> memberIds,
    required FriendRealtimeEvent event,
  }) {
    final detail = event.detail ?? const <String, dynamic>{};
    return isSelfRemovedFromGroupMembershipEvent(
      action: action,
      ownerUserId: owner,
      memberUserIds: memberIds,
      fromUserId: event.fromUserId,
      detailUserId:
          detail['userId']?.toString() ?? detail['user_id']?.toString(),
    );
  }

  Future<void> clearSession() async {
    _tcpAuthSyncFullTimer?.cancel();
    _tcpAuthSyncFullTimer = null;
    _tcpAuthSyncFullGeneration++;
    _groupListSyncedOnce = false;
    _lastMeGroupsNetworkAt = null;
    _lastTcpAuthSyncAt = null;
    _groupMemberRefreshInFlight.clear();
    await GroupLocalStore.instance.clearSession();
    await GroupMemberLocalStore.instance.clearSession();
    _bumpJoinedGroupsRevision();
  }

  Future<List<String>> adminSelfHostedGroupIds() async {
    final owner = _ownerUserId();
    final groups = await GroupLocalStore.instance.readAll(ownerUserId: owner);
    return groups
        .where((group) {
          if (!GroupJoinApi.isSelfHostedJoinGroupType(group.groupType)) {
            return false;
          }
          return GroupRolePolicy.isManagerRole(group.myRole);
        })
        .map((group) => group.groupId)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> adminGroupIds() async {
    final owner = _ownerUserId();
    final groups = await GroupLocalStore.instance.readAll(ownerUserId: owner);
    return groups
        .where((group) {
          return GroupRolePolicy.isManagerRole(group.myRole);
        })
        .map((group) => group.groupId)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _patchGroupFields({
    required String owner,
    required String groupId,
    String? groupName,
    String? displayAlias,
    String? avatarUrl,
    String? notice,
    int? memberCount,
    int? myRole,
    String? myNameCard,
    int? updatedAt,
    String? ownerUserId,
    int? noticeUpdatedAt,
    String? noticeUpdatedBy,
    bool? isAllMuted,
    int incrementIfMissing = 0,
  }) async {
    final current = await GroupLocalStore.instance.read(
      groupId: groupId,
      ownerUserId: owner,
    );
    if (current == null) {
      if (incrementIfMissing > 0) {
        return;
      }
      await refreshGroupDetail(groupId);
      return;
    }
    var nextCount = current.memberCount;
    if (memberCount != null) {
      nextCount = memberCount;
    } else if (incrementIfMissing > 0) {
      nextCount = current.memberCount + incrementIfMissing;
    }
    await GroupLocalStore.instance.upsert(
      ownerUserId: owner,
      record: current.copyWith(
        groupName: groupName ?? current.groupName,
        displayAlias: displayAlias != null
            ? ChatIdFormat.displayGroupAlias(
                displayAlias,
                groupIdFallback: groupId,
              )
            : current.displayAlias,
        avatarUrl: avatarUrl ?? current.avatarUrl,
        notice: notice ?? current.notice,
        memberCount: nextCount,
        myRole: myRole ?? current.myRole,
        myNameCard: myNameCard ?? current.myNameCard,
        updatedAt: updatedAt ?? current.updatedAt,
        ownerUserId: ownerUserId ?? current.ownerUserId,
        noticeUpdatedAt: noticeUpdatedAt ?? current.noticeUpdatedAt,
        noticeUpdatedBy: noticeUpdatedBy ?? current.noticeUpdatedBy,
        isAllMuted: isAllMuted ?? current.isAllMuted,
      ),
    );
  }

  bool _detailLooksLikeGroupProfile(Map<String, dynamic> detail) {
    final groupName = detail['groupName']?.toString().trim() ?? '';
    final groupType = detail['groupType']?.toString().trim() ?? '';
    return groupName.isNotEmpty && groupType.isNotEmpty;
  }

  List<String> _memberIds(
    FriendRealtimeEvent event,
    Map<String, dynamic> detail,
  ) {
    final fromDetail = detail['memberUserIds'] ?? detail['member_user_ids'];
    if (fromDetail is List) {
      return fromDetail
          .map((e) => ChatIdFormat.rawUserUid(e?.toString() ?? ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return event.memberUserIds
        .map(ChatIdFormat.rawUserUid)
        .where((e) => e.isNotEmpty)
        .toList();
  }

  int _parseOffset(String nextSeq) {
    final normalized = nextSeq.trim();
    if (normalized.isEmpty || normalized == '0') {
      return 0;
    }
    return int.tryParse(normalized) ?? 0;
  }

  bool _readBool(dynamic value) => MeGroupRecord.parseBoolLikeIM(value);

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _readGroupAvatarUrl(Map<String, dynamic> detail) {
    for (final key in const [
      'avatarUrl',
      'avatar_url',
      'thumbUrl',
      'thumb_url'
    ]) {
      final value = detail[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  V2TimGroupMemberFullInfo _toV2TimMember(GroupMemberRecord record) {
    return V2TimGroupMemberFullInfo(
      userID: record.userId,
      role: record.role,
      joinTime: record.joinedAt > 0 ? record.joinedAt ~/ 1000 : null,
      nickName: record.nickname,
      nameCard: record.nameCard,
      friendRemark: record.friendRemark,
      faceUrl: record.avatarUrl,
      muteUntil: record.muteUntil > 0 ? record.muteUntil : null,
    );
  }

  void _patchMemoryMemberMuteUntil({
    required String groupId,
    required String userId,
    required int muteUntil,
  }) {
    final current = GroupMemberStore.instance.memberOf(groupId, userId);
    if (current == null) {
      return;
    }
    GroupMemberStore.instance.putMember(
      groupId,
      V2TimGroupMemberFullInfo(
        userID: current.userID,
        role: current.role,
        nickName: current.nickName,
        nameCard: current.nameCard,
        friendRemark: current.friendRemark,
        faceUrl: current.faceUrl,
        joinTime: current.joinTime,
        muteUntil: muteUntil,
        customInfo: current.customInfo,
      ),
    );
  }

  void notifyProfileRefresh(String groupId, {bool memberList = false}) {
    try {
      final listenerModel = serviceLocator<TUIGroupListenerModel>();
      listenerModel.requestProfileRefresh(
        NeedUpdate(
          groupId,
          memberList ? UpdateType.memberListReload : UpdateType.groupInfo,
          '',
        ),
      );
    } catch (_) {}
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
