import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/constants/group_governance_limits.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_change_event_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_entity_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_bootstrap.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_leave_diag_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_governance_trace.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_history_warm_scheduler.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_tip_custom_sender.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_role_pending.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_self_involvement.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/my_group_list_controller.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lock_profile_log.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_conversation_visibility.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tip_custom_message.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/utils/group_display_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_demo/utils/object_url_normalize.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/listener_model/tui_group_listener_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
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
  Future<void>? _syncInFlight;
  bool _syncInFlightRefresh = false;
  int _syncGeneration = 0;
  final Set<String> _explicitlyRemovedGroupKeys = <String>{};
  final Map<String, int> _snapshotMissingCounts = <String, int>{};
  static const int _snapshotMissingConfirmations = 3;
  final Set<String> _activeConversationEvidenceKeys = <String>{};

  @visibleForTesting
  static bool shouldRetainGroupFromSnapshotSafety({
    required bool explicitlyRemoved,
    required int consecutiveMissingSnapshots,
  }) {
    return !explicitlyRemoved &&
        consecutiveMissingSnapshots < _snapshotMissingConfirmations;
  }

  bool _groupListSyncedOnce = false;
  final Map<String, Future<void>> _groupMemberRefreshInFlight = {};
  final Map<String, Future<void>> _membershipSnapshotInFlight = {};
  final Map<String, int> _membershipSnapshotCooldownUntilMs = <String, int>{};
  final Map<String, Future<V2TimValueCallback<V2TimGroupMemberInfoResult>>>
      _groupMemberPageInFlight = {};
  DateTime? _lastTcpAuthSyncAt;
  final Set<String> _inboundDisplayTipKeys = <String>{};
  DateTime? _lastMeGroupsNetworkAt;
  Timer? _tcpAuthSyncFullTimer;
  int _tcpAuthSyncFullGeneration = 0;
  Timer? _deferredSyncFullTimer;
  String? _deferredSyncFullReason;
  bool _deferredSyncFullRefresh = false;
  Timer? _revisionCoalesceTimer;
  bool _revisionCoalesceScheduled = false;
  Timer? _idleReconcileTimer;
  int _idleReconcileGeneration = 0;
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
      hasActiveConversationEvidence: (groupId) {
        final key = GroupLocalStore.groupEquivalenceKey(groupId);
        return key.isNotEmpty &&
            _activeConversationEvidenceKeys.contains(key) &&
            !_explicitlyRemovedGroupKeys.contains(key);
      },
    );
  }

  /// 用户已从 SDK 会话列表成功打开该群，说明它至少在本次会话中有效。
  ///
  /// `/me/groups` 首次快照可能受缓存或分页影响暂时缺群；在明确退群、被踢或
  /// 解散事件到达前，不能因此在返回列表时把刚打开的会话过滤掉。
  void noteActiveGroupConversation(V2TimConversation conversation) {
    if (!isGroupConversation(conversation)) {
      return;
    }
    final groupId = resolveGroupIdFromConversation(
      conversationId: conversation.conversationID,
      groupId: conversation.groupID,
    );
    final key = GroupLocalStore.groupEquivalenceKey(groupId);
    if (key.isEmpty || _explicitlyRemovedGroupKeys.contains(key)) {
      return;
    }
    _activeConversationEvidenceKeys.add(key);
    unawaited(refreshGroupDetail(groupId));
  }

  void _bumpJoinedGroupsRevision() {
    final coalesce = ConversationPerfFlags.joinedGroupsRevisionCoalesce;
    if (coalesce <= Duration.zero) {
      joinedGroupsRevision.value++;
      return;
    }
    _revisionCoalesceScheduled = true;
    _revisionCoalesceTimer?.cancel();
    _revisionCoalesceTimer = Timer(coalesce, () {
      _revisionCoalesceTimer = null;
      if (!_revisionCoalesceScheduled) {
        return;
      }
      _revisionCoalesceScheduled = false;
      joinedGroupsRevision.value++;
    });
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
        extras: <String, Object?>{'reason': 'tcp_auth_cooldown'},
      );
      unawaited(GroupNoticeBootstrap.refreshFromNetwork());
      // 全量跳过时仍用游标补群名/头像/成员流，避免杀进程后展示陈旧。
      unawaited(
        GroupEntityIncrementalSyncService.instance.sync(
          reason: 'tcp_auth_ok_cooldown',
        ),
      );
      unawaited(
        GroupMemberIncrementalSyncService.instance.syncAllJoined(
          reason: 'tcp_auth_ok_cooldown',
        ),
      );
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
          extras: <String, Object?>{'reason': 'owner_changed'},
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
    // 其它 UIKit 桥接仍要全量；「我的群聊」分页/骨架走 MyGroupListController，勿改此路径。
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
    final byId = <String, MeGroupRecord>{};
    for (final groupId in ids) {
      final cached = await GroupLocalStore.instance.read(
        groupId: groupId,
        ownerUserId: owner,
      );
      if (cached != null) {
        byId[groupId] = cached;
        continue;
      }
      // 会话误用 @TGS#_@TGS#m2… 时，按 displayAlias 找回 @TGS#_mc… 真源。
      final resolvedIm = await GroupLocalStore.instance.resolveImGroupId(
        groupId,
        ownerUserId: owner,
      );
      if (resolvedIm.isNotEmpty) {
        final byResolved = await GroupLocalStore.instance.read(
          groupId: resolvedIm,
          ownerUserId: owner,
        );
        if (byResolved != null) {
          byId[groupId] = byResolved;
        }
      }
    }
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
      // REST 多形态候选（短码 / @TGS# / 完整社群 ID）；优先本地 /me/groups 记录。
      final preferred = await _resolveApiGroupIdForMembers(groupID);
      final page = await MeGroupApi.instance.fetchGroupMembersPage(
        groupId: preferred.isNotEmpty ? preferred : groupID,
        limit: limit,
        offset: offset,
        // 首屏空列表时强制后端从 IM 同步一页，避免本地空缓存假空。
        refresh: offset <= 0,
      );
      if (offset <= 0 && page.items.isEmpty) {
        debugPrint(
          'GroupMembership: REST members empty, fallback IM SDK groupId=$groupID',
        );
        final imFallback = await _loadGroupMemberPageFromImSdk(
          groupID: groupID,
          count: limit,
          nextSeq: '0',
        );
        if (imFallback != null) {
          return imFallback;
        }
      }
      final nextOffset = offset + page.items.length;
      // 满页默认还有下一页；仅当服务端给出明确 total 且已达/超过时停止。
      // 禁止依赖「total 缺省=本页条数」——那会让满页永远 hasMore=false。
      final hasMore = page.items.length >= limit &&
          (page.total <= 0 || nextOffset < page.total);
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
      debugPrint('GroupMembership: REST members error, fallback IM SDK: $e');
      final imFallback = await _loadGroupMemberPageFromImSdk(
        groupID: groupID,
        count: limit,
        nextSeq: offset <= 0 ? '0' : offset.toString(),
      );
      if (imFallback != null) {
        return imFallback;
      }
      return V2TimValueCallback(
        code: -1,
        desc: e.toString(),
        data: V2TimGroupMemberInfoResult(
          nextSeq: '0',
          memberInfoList: const [],
        ),
      );
    }
  }

  /// 国内腾讯云 IM：社群成员列表走 SDK `getGroupMemberList`。
  /// 群 ID 须与控制台一致（常见 `@TGS#_mc…`，或默认 `@TGS#_@TGS#…`）。
  Future<V2TimValueCallback<V2TimGroupMemberInfoResult>?>
      _loadGroupMemberPageFromImSdk({
    required String groupID,
    required int count,
    required String nextSeq,
  }) async {
    final candidates = ChatIdFormat.imGroupIdCandidates(groupID);
    for (final imGroupId in candidates) {
      try {
        final res = await TencentImSDKPlugin.v2TIMManager
            .getGroupManager()
            .getGroupMemberList(
              groupID: imGroupId,
              filter: GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ALL,
              nextSeq: nextSeq,
              count: count.clamp(1, 100),
            );
        final members = res.data?.memberInfoList ?? const [];
        if (res.code == 0 && members.isNotEmpty) {
          debugPrint(
            'GroupMembership: IM members ok id=$imGroupId count=${members.length}',
          );
          return res;
        }
        if (res.code != 0) {
          debugPrint(
            'GroupMembership: IM members fail id=$imGroupId code=${res.code} desc=${res.desc}',
          );
        }
      } catch (e) {
        debugPrint(
            'GroupMembership: IM members exception id=$imGroupId err=$e');
      }
    }
    return null;
  }

  /// 解析拉成员列表用的后端群 ID。
  Future<String> _resolveApiGroupIdForMembers(String groupID) async {
    final trimmed = groupID.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    try {
      final record = await GroupLocalStore.instance.read(groupId: trimmed);
      if (record != null) {
        // REST 优先真实 groupId；displayAlias 仅作回退（勿把别名当成唯一真源）。
        final fromGroupId = ChatIdFormat.apiGroupId(record.groupId);
        if (fromGroupId.isNotEmpty) {
          return fromGroupId;
        }
        final fromAlias = ChatIdFormat.apiGroupId(record.displayAlias);
        if (fromAlias.isNotEmpty) {
          return fromAlias;
        }
      }
    } catch (_) {
      // 本地缺失时退回入参。
    }
    final fromInput = ChatIdFormat.apiGroupId(trimmed);
    return fromInput.isNotEmpty ? fromInput : trimmed;
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

  Future<V2TimCallback> updateGroupInfo({required V2TimGroupInfo info}) async {
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
        groupId: groupId,
        avatarUrl: info.faceUrl!.trim(),
      );
      unawaited(
        GroupTipCustomSender.instance.send(
          groupId: groupId,
          action: 'group_avatar_changed',
          detail: <String, dynamic>{'avatarUrl': info.faceUrl!.trim()},
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
        final name = (info.groupName ?? updated.groupName).trim();
        if (name.isNotEmpty) {
          await publishGroupConversationDisplay(
            groupId: groupId,
            groupName: name,
          );
        }
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
          groupId: groupId,
          avatarUrl: info.faceUrl!.trim(),
        );
        unawaited(
          GroupTipCustomSender.instance.send(
            groupId: groupId,
            action: 'group_avatar_changed',
            detail: <String, dynamic>{'avatarUrl': info.faceUrl!.trim()},
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

    // 先发 tip（读本地成员公开名），再删库；tip 成败都不阻塞删人。
    try {
      await GroupTipCustomSender.instance.send(
        groupId: id,
        action: 'member_removed',
        memberUserIds: removedUserIds,
      );
    } catch (_) {}
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
        final nextCount = (current.memberCount - removedUserIds.length).clamp(
          0,
          current.memberCount,
        );
        await _patchGroupFields(
          owner: owner,
          groupId: id,
          memberCount: nextCount,
        );
      }
    }
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
        await _patchGroupFields(owner: owner, groupId: groupId, myRole: role);
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
        detail: <String, dynamic>{'role': role, 'myRole': role},
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
  Future<void> syncFull({String reason = 'manual', bool refresh = false}) {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return Future<void>.value();
    }
    final active = _syncInFlight;
    if (active != null) {
      if (refresh && !_syncInFlightRefresh) {
        return active.then((_) => syncFull(reason: reason, refresh: true));
      }
      return active;
    }
    // 手势滚动中推迟非 refresh 全量同步，避免与列表抢主线程。
    if (!refresh &&
        GroupLocalPerfFlags.deferSyncFullWhileFeedScrolling &&
        (ConversationListNotifier.instance.isFeedScrolling?.call() ?? false)) {
      _scheduleDeferredSyncFull(reason: reason, refresh: refresh);
      return Future<void>.value();
    }
    // resume quiet 内推迟非 refresh，错开会话首屏 loadUiWindow。
    if (!refresh &&
        GroupLocalPerfFlags.deferSyncFullWhileResumeQuiet &&
        ConversationSyncService.instance.isInResumeQuietWindow) {
      _scheduleDeferredSyncFullAfterResumeQuiet(
        reason: reason,
        refresh: refresh,
      );
      return Future<void>.value();
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
      return Future<void>.value();
    }

    final generation = _syncGeneration;
    late final Future<void> task;
    _syncInFlightRefresh = refresh;
    task = _runSyncFull(
      owner: owner,
      generation: generation,
      reason: reason,
      refresh: refresh,
    ).whenComplete(() {
      if (identical(_syncInFlight, task)) {
        _syncInFlight = null;
        _syncInFlightRefresh = false;
      }
    });
    _syncInFlight = task;
    return task;
  }

  void _scheduleDeferredSyncFullAfterResumeQuiet({
    required String reason,
    required bool refresh,
  }) {
    _deferredSyncFullReason = reason;
    _deferredSyncFullRefresh = _deferredSyncFullRefresh || refresh;
    _deferredSyncFullTimer?.cancel();
    final settle = _resumeQuietSyncFullSettle(reason: reason);
    _deferredSyncFullTimer = Timer(
      settle,
      () {
        _deferredSyncFullTimer = null;
        final pendingReason = _deferredSyncFullReason ?? reason;
        final pendingRefresh = _deferredSyncFullRefresh;
        _deferredSyncFullReason = null;
        _deferredSyncFullRefresh = false;
        if (ConversationSyncService.instance.isInResumeQuietWindow) {
          _scheduleDeferredSyncFullAfterResumeQuiet(
            reason: pendingReason,
            refresh: pendingRefresh,
          );
          return;
        }
        if (ConversationListNotifier.instance.isFeedScrolling?.call() ??
            false) {
          _scheduleDeferredSyncFull(
            reason: pendingReason,
            refresh: pendingRefresh,
          );
          return;
        }
        unawaited(
          syncFull(
            reason: '${pendingReason}_after_quiet',
            refresh: pendingRefresh,
          ),
        );
      },
    );
    _log(
      'syncFull deferred reason=$reason resume_quiet=true settleMs='
      '${settle.inMilliseconds}',
    );
    SqfliteLockProfileLog.event(
      'syncFull_defer_quiet',
      extras: <String, Object?>{
        'reason': reason,
        'settleMs': settle.inMilliseconds,
      },
    );
  }

  Duration _resumeQuietSyncFullSettle({required String reason}) {
    final base = GroupLocalPerfFlags.syncFullAfterResumeQuietSettle;
    final postHome = GroupLocalPerfFlags.postHomeSyncFullMinDelayAfterQuiet;
    if (_isPostHomeOrTcpAuthReason(reason) && postHome > base) {
      return postHome;
    }
    return base;
  }

  static bool _isPostHomeOrTcpAuthReason(String reason) {
    return reason.contains('native_post_home') ||
        reason.contains('tcp_auth_ok');
  }

  static bool _isSkipNetworkEligibleReason(String reason) {
    return _isPostHomeOrTcpAuthReason(reason);
  }

  void _scheduleDeferredSyncFull({
    required String reason,
    required bool refresh,
  }) {
    _deferredSyncFullReason = reason;
    _deferredSyncFullRefresh = _deferredSyncFullRefresh || refresh;
    _deferredSyncFullTimer?.cancel();
    _deferredSyncFullTimer = Timer(
      GroupLocalPerfFlags.syncFullAfterScrollSettle,
      () {
        _deferredSyncFullTimer = null;
        final pendingReason = _deferredSyncFullReason ?? reason;
        final pendingRefresh = _deferredSyncFullRefresh;
        _deferredSyncFullReason = null;
        _deferredSyncFullRefresh = false;
        if (ConversationListNotifier.instance.isFeedScrolling?.call() ??
            false) {
          _scheduleDeferredSyncFull(
            reason: pendingReason,
            refresh: pendingRefresh,
          );
          return;
        }
        unawaited(
          syncFull(
              reason: '${pendingReason}_after_scroll', refresh: pendingRefresh),
        );
      },
    );
    _log('syncFull deferred reason=$reason scrolling=true');
    SqfliteLockProfileLog.event(
      'syncFull_defer_scroll',
      extras: <String, Object?>{'reason': reason},
    );
  }

  Future<void> _runSyncFull({
    required String owner,
    required int generation,
    required String reason,
    required bool refresh,
  }) async {
    final pauseWarm = GroupLocalPerfFlags.syncFullExclusiveWithHistoryWarm;
    if (pauseWarm) {
      ConversationHistoryWarmScheduler.instance.setPausedForMembershipSync(
        true,
        reason: 'sync_full_$reason',
      );
    }
    try {
      _log('syncFull start reason=$reason refresh=$refresh');
      SqfliteLockProfileLog.event(
        'syncFull_start',
        extras: <String, Object?>{'reason': reason, 'refresh': refresh},
      );

      final localCount = await GroupLocalStore.instance.countGroups(
        ownerUserId: owner,
      );
      if (await _shouldSkipNetworkSyncFull(
        owner: owner,
        reason: reason,
        refresh: refresh,
        localCount: localCount,
      )) {
        _groupListSyncedOnce = true;
        _log(
          'syncFull skip network reason=$reason localCount=$localCount',
        );
        SqfliteLockProfileLog.event(
          'syncFull_skip',
          extras: <String, Object?>{
            'reason': reason,
            'cause': 'local_complete',
            'localCount': localCount,
          },
        );
        scheduleIdleReconcile(reason: 'after_skip_$reason');
        return;
      }

      final existing = await GroupLocalStore.instance.readAll(
        ownerUserId: owner,
        caller: 'syncFull',
      );
      final existingById = {for (final item in existing) item.groupId: item};
      List<MeGroupRecord> records;
      try {
        records = await MeGroupApi.instance.fetchMyGroupsFromNetwork(
          refresh: refresh,
          preserveIsAllMutedFrom: existingById,
          shouldContinueAfterPage: () async {
            if (!_isCurrentSync(owner, generation)) {
              return false;
            }
            final pageYield = GroupLocalPerfFlags.meGroupsPageYield;
            if (pageYield > Duration.zero) {
              await Future<void>.delayed(pageYield);
            }
            if (!_isCurrentSync(owner, generation)) {
              return false;
            }
            if (!refresh &&
                GroupLocalPerfFlags.deferSyncFullWhileFeedScrolling &&
                (ConversationListNotifier.instance.isFeedScrolling?.call() ??
                    false)) {
              return false;
            }
            return true;
          },
        );
      } on MeGroupsFetchAborted {
        if (!_isCurrentSync(owner, generation)) {
          return;
        }
        _log('syncFull aborted mid-fetch reason=$reason scrolling=true');
        SqfliteLockProfileLog.event(
          'syncFull_abort_scroll',
          extras: <String, Object?>{'reason': reason},
        );
        _scheduleDeferredSyncFull(reason: reason, refresh: refresh);
        return;
      }
      if (!_isCurrentSync(owner, generation)) {
        return;
      }
      _lastMeGroupsNetworkAt = DateTime.now();
      final joinedIds = records
          .map((item) => item.groupId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      final removedGroupIds = removedGroupIdsByEquivalence(
        existingIds: existing.map((item) => item.groupId),
        joinedIds: joinedIds,
      );
      final incomingKeys = records
          .map((record) => GroupLocalStore.groupEquivalenceKey(record.groupId))
          .where((key) => key.isNotEmpty)
          .toSet();
      for (final key in incomingKeys) {
        _snapshotMissingCounts.remove(key);
      }
      for (final groupId in removedGroupIds) {
        final key = GroupLocalStore.groupEquivalenceKey(groupId);
        if (key.isNotEmpty) {
          _snapshotMissingCounts[key] = (_snapshotMissingCounts[key] ?? 0) + 1;
        }
      }
      // 群快照缺失不是退群证据：网络缓存/分页漏页时必须保留本地成员关系，
      // 否则 shouldShowConversation 会把 SDK 后续返回的真实会话继续隐藏。
      // 明确退群、被踢、解散事件仍会走各自的 delete 路径。
      final safeRecords = GroupLocalStore.dedupeGroupRecords(
        <MeGroupRecord>[...existing, ...records],
      ).where((record) {
        final key = GroupLocalStore.groupEquivalenceKey(record.groupId);
        return shouldRetainGroupFromSnapshotSafety(
          explicitlyRemoved: _explicitlyRemovedGroupKeys.contains(key),
          consecutiveMissingSnapshots: _snapshotMissingCounts[key] ?? 0,
        );
      }).toList(growable: false);
      await GroupLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: safeRecords,
        // 同一次 syncFull 内复用上方 readAll，避免二次全表过 Channel。
        existingSnapshot: existing,
      );
      if (!_isCurrentSync(owner, generation)) {
        await _reapplyExplicitRemovalTombstones(owner);
        return;
      }
      await GroupLocalStore.instance.writeFullSyncMeta(
        ownerUserId: owner,
        // 记录服务端本轮真实数量。只要仍有待确认缺失项，本地数与 meta
        // 不一致，后续 syncFull 就不会被“本地完整”优化永久跳过。
        count: records.length,
      );
      _groupListSyncedOnce = true;
      _bumpJoinedGroupsRevision();
      // /me/groups 快照差异只能更新可见性，不能作为删除 SDK 会话的证据。
      // 分页缺页、缓存或短暂网络异常都可能让真实群暂时不在 records 中。
      for (final groupId in removedGroupIds) {
        if (!_isCurrentSync(owner, generation)) {
          return;
        }
        await _purgeGroupConversation(
          groupId,
          explicitMembershipEvent: false,
          reason: 'sync_full_snapshot_missing',
        );
      }
      if (!_isCurrentSync(owner, generation)) {
        return;
      }
      await pruneStaleGroupConversations(reason: 'sync_full_$reason');
      if (!_isCurrentSync(owner, generation)) {
        return;
      }
      // 全量成员对齐后冲刷「先到会话、后到成员」挂起项。
      unawaited(
        ConversationSyncService.instance.onLocalGroupMembershipExpanded(),
      );
      // 用 REST 群名盖掉会话列表里误显示的完整 IM ID。
      unawaited(
        ConversationSyncService.instance.applyGroupDisplayNames(safeRecords),
      );
      _log(
        'syncFull done count=${records.length} removed=${removedGroupIds.length}',
      );
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
      unawaited(
        GroupEntityIncrementalSyncService.instance.sync(
          reason: 'after_full_$reason',
        ),
      );
      unawaited(
        GroupNoticeIncrementalSyncService.instance.sync(
          reason: 'after_full_$reason',
        ),
      );
      unawaited(
        GroupMemberIncrementalSyncService.instance.syncAllJoined(
          reason: 'after_full_$reason',
        ),
      );
      _lastTcpAuthSyncAt = DateTime.now();
      scheduleIdleReconcile(reason: 'after_full_$reason');
    } catch (e) {
      _log('syncFull failed: $e');
      SqfliteLockProfileLog.event(
        'syncFull_fail',
        extras: <String, Object?>{'reason': reason, 'error': '$e'},
      );
      rethrow;
    } finally {
      if (pauseWarm) {
        ConversationHistoryWarmScheduler.instance.setPausedForMembershipSync(
          false,
          reason: 'sync_full_done_$reason',
        );
      }
    }
  }

  Future<bool> _shouldSkipNetworkSyncFull({
    required String owner,
    required String reason,
    required bool refresh,
    required int localCount,
  }) async {
    if (!GroupLocalPerfFlags.skipNetworkSyncFullWhenLocalComplete) {
      return false;
    }
    final meta = await GroupLocalStore.instance.readFullSyncMeta(
      ownerUserId: owner,
    );
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    return shouldSkipNetworkSyncFullDecision(
      refresh: refresh,
      reason: reason,
      localCount: localCount,
      groupListSyncedOnce: _groupListSyncedOnce,
      metaAtMs: meta.atMs,
      metaCount: meta.count,
      nowMs: nowMs,
    );
  }

  /// 纯决策：供单测与 [_shouldSkipNetworkSyncFull] 共用。
  @visibleForTesting
  static bool shouldSkipNetworkSyncFullDecision({
    required bool refresh,
    required String reason,
    required int localCount,
    required bool groupListSyncedOnce,
    required int metaAtMs,
    required int metaCount,
    required int nowMs,
    bool flagEnabled = GroupLocalPerfFlags.skipNetworkSyncFullWhenLocalComplete,
    int localCompleteMinCount = GroupLocalPerfFlags.localCompleteMinCount,
    int maxAgeMs = -1,
  }) {
    if (!flagEnabled) {
      return false;
    }
    if (refresh) {
      return false;
    }
    if (!_isSkipNetworkEligibleReason(reason)) {
      return false;
    }
    if (localCount < localCompleteMinCount) {
      return false;
    }
    if (groupListSyncedOnce) {
      return true;
    }
    if (metaAtMs <= 0 || metaCount <= 0) {
      return false;
    }
    if (metaCount != localCount) {
      return false;
    }
    final ageCap = maxAgeMs >= 0
        ? maxAgeMs
        : GroupLocalPerfFlags.fullSyncMaxAge.inMilliseconds;
    final ageMs = nowMs - metaAtMs;
    if (ageMs < 0 || ageMs > ageCap) {
      return false;
    }
    return true;
  }

  /// 空闲轻量对账：先比 `/me/groups` total 与本地 count，不匹配再全量。
  void scheduleIdleReconcile({String reason = 'idle'}) {
    if (!GroupLocalPerfFlags.idleReconcileEnabled) {
      return;
    }
    _idleReconcileTimer?.cancel();
    final generation = ++_idleReconcileGeneration;
    _idleReconcileTimer = Timer(GroupLocalPerfFlags.idleReconcileDelay, () {
      _idleReconcileTimer = null;
      unawaited(_runIdleReconcile(generation: generation, reason: reason));
    });
    _log(
      'idle_reconcile scheduled reason=$reason delayMs='
      '${GroupLocalPerfFlags.idleReconcileDelay.inMilliseconds}',
    );
  }

  Future<void> _runIdleReconcile({
    required int generation,
    required String reason,
  }) async {
    if (generation != _idleReconcileGeneration) {
      return;
    }
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return;
    }
    if (ConversationListNotifier.instance.isFeedScrolling?.call() ?? false) {
      _idleReconcileTimer?.cancel();
      _idleReconcileTimer = Timer(
        GroupLocalPerfFlags.syncFullAfterScrollSettle,
        () {
          unawaited(
            _runIdleReconcile(generation: generation, reason: reason),
          );
        },
      );
      return;
    }
    if (ConversationSyncService.instance.isInResumeQuietWindow) {
      scheduleIdleReconcile(reason: '${reason}_quiet');
      return;
    }
    try {
      final localCount = await GroupLocalStore.instance.countGroups(
        ownerUserId: owner,
      );
      final page = await MeGroupApi.instance.fetchMyGroupsPage(
        limit: 100,
        offset: 0,
        refresh: false,
      );
      if (generation != _idleReconcileGeneration || _ownerUserId() != owner) {
        return;
      }
      final remoteTotal = page.total > 0 ? page.total : page.items.length;
      if (remoteTotal == localCount) {
        await GroupLocalStore.instance.writeFullSyncMeta(
          ownerUserId: owner,
          count: localCount,
        );
        _groupListSyncedOnce = true;
        _log(
          'idle_reconcile ok reason=$reason total=$remoteTotal',
        );
        SqfliteLockProfileLog.event(
          'idle_reconcile_ok',
          extras: <String, Object?>{
            'reason': reason,
            'total': remoteTotal,
          },
        );
        return;
      }
      _log(
        'idle_reconcile mismatch reason=$reason local=$localCount '
        'remote=$remoteTotal',
      );
      SqfliteLockProfileLog.event(
        'idle_reconcile_total_mismatch',
        extras: <String, Object?>{
          'reason': reason,
          'local': localCount,
          'remote': remoteTotal,
        },
      );
      await syncFull(reason: 'idle_reconcile', refresh: false);
    } catch (e) {
      _log('idle_reconcile failed: $e');
      SqfliteLockProfileLog.event(
        'idle_reconcile_fail',
        extras: <String, Object?>{'reason': reason, 'error': '$e'},
      );
    }
  }

  bool _isCurrentSync(String owner, int generation) {
    return generation == _syncGeneration && _ownerUserId() == owner;
  }

  void _markExplicitGroupRemoval(String groupId) {
    final key = GroupLocalStore.groupEquivalenceKey(groupId);
    if (key.isNotEmpty) {
      _explicitlyRemovedGroupKeys.add(key);
      _activeConversationEvidenceKeys.remove(key);
      _snapshotMissingCounts.remove(key);
    }
    _syncGeneration++;
  }

  void _clearExplicitGroupRemoval(String groupId) {
    final key = GroupLocalStore.groupEquivalenceKey(groupId);
    if (key.isNotEmpty) {
      _explicitlyRemovedGroupKeys.remove(key);
      _snapshotMissingCounts.remove(key);
    }
  }

  Future<void> _reapplyExplicitRemovalTombstones(String owner) async {
    if (owner.isEmpty || _explicitlyRemovedGroupKeys.isEmpty) {
      return;
    }
    final rows = await GroupLocalStore.instance.readAll(ownerUserId: owner);
    for (final row in rows) {
      final key = GroupLocalStore.groupEquivalenceKey(row.groupId);
      if (_explicitlyRemovedGroupKeys.contains(key)) {
        await GroupLocalStore.instance.delete(
          ownerUserId: owner,
          groupId: row.groupId,
        );
      }
    }
  }

  /// 入站 `group_tip`（改名/换头）→ 只写群 Entity + 双写展示，非全量。
  Future<void> applyInboundGroupDisplayFromMessage(
    V2TimMessage message,
  ) async {
    final map = parseGroupTipPayload(message.customElem);
    if (map == null) {
      return;
    }
    final action = map['action']?.toString().trim().toLowerCase() ?? '';
    if (!isGroupDisplayTipAction(action)) {
      return;
    }
    final groupId = ChatIdFormat.normalizeGroupId(message.groupID ?? '');
    if (groupId.isEmpty || isForbiddenGroupStorageId(groupId)) {
      return;
    }
    final clientMsgId = map['clientMsgId']?.toString().trim() ?? '';
    final msgId = message.msgID?.trim() ?? '';
    final dedupeKey =
        msgId.isNotEmpty ? 'msg:$msgId' : 'tip:$groupId|$action|$clientMsgId';
    if (!_inboundDisplayTipKeys.add(dedupeKey)) {
      return;
    }
    try {
      final fields = extractGroupTipDisplayFields(map);
      final name = fields.groupName;
      final avatar = fields.avatarUrl;
      if (action == 'group_name_changed' && name.isEmpty) {
        // tip 缺名：强制拉单群详情，避免会话列表长期挂旧名。
        await refreshGroupDetail(groupId, refresh: true);
        return;
      }
      if (action == 'group_avatar_changed' && avatar.isEmpty) {
        await refreshGroupDetail(groupId, refresh: true);
        return;
      }
      if (name.isNotEmpty) {
        await applyOptimisticGroupName(groupId: groupId, groupName: name);
      }
      if (avatar.isNotEmpty) {
        await upsertGroupAvatar(groupId: groupId, avatarUrl: avatar);
      }
    } catch (e) {
      _log(
          'applyInboundGroupDisplayFromMessage failed groupId=$groupId error=$e');
    } finally {
      _inboundDisplayTipKeys.remove(dedupeKey);
    }
  }

  /// 入站拉人/踢人/退群 tip（App Custom 或 IM 原生 GroupTips）→ 成员首屏 + 刷聊天头。
  /// 与 TCP 路径共用 `syncMembersAfterMembershipChange` 单飞，避免双拉。
  Future<void> applyInboundMembershipTipFromMessage(
    V2TimMessage message,
  ) async {
    String action = '';
    List<String> memberUserIds = const <String>[];
    final map = parseGroupTipPayload(message.customElem);
    if (map != null) {
      action = map['action']?.toString().trim().toLowerCase() ?? '';
      final detail = map['detail'];
      if (detail is Map) {
        final raw = detail['memberUserIds'] ?? detail['member_user_ids'];
        if (raw is List) {
          memberUserIds = raw
              .map((e) => ChatIdFormat.rawUserUid(e?.toString() ?? ''))
              .where((id) => id.isNotEmpty)
              .toList(growable: false);
        }
      }
    } else {
      action = GroupTipsMessageHelper.actionForTipsType(
            message.groupTipsElem?.type,
          ) ??
          '';
      final tipMembers = message.groupTipsElem?.memberList;
      if (tipMembers != null && tipMembers.isNotEmpty) {
        memberUserIds = tipMembers
            .map((m) => ChatIdFormat.rawUserUid(m?.userID ?? ''))
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
      }
    }
    if (!isGroupMembershipTipAction(action)) {
      return;
    }
    final groupId = ChatIdFormat.normalizeGroupId(message.groupID ?? '');
    if (groupId.isEmpty || isForbiddenGroupStorageId(groupId)) {
      return;
    }
    final clientMsgId = map?['clientMsgId']?.toString().trim() ?? '';
    final msgId = message.msgID?.trim() ?? '';
    final dedupeKey = msgId.isNotEmpty
        ? 'membership_msg:$msgId'
        : 'membership_tip:$groupId|$action|$clientMsgId';
    if (!_inboundDisplayTipKeys.add(dedupeKey)) {
      return;
    }
    try {
      await syncMembersAfterMembershipChange(
        groupId,
        reason: 'tip_$action',
      );
      // 不走 notifyGroupMembersChanged（会再 sync 一次）；只推 lastChanged 刷头。
      notifyMembershipChatHeader(
        groupId,
        action: action,
        memberUserIds: memberUserIds,
      );
    } catch (e) {
      _log(
        'applyInboundMembershipTipFromMessage failed groupId=$groupId '
        'action=$action error=$e',
      );
    } finally {
      _inboundDisplayTipKeys.remove(dedupeKey);
    }
  }

  /// 成员人数/名单变更后通知打开中的群聊头刷新（写 [GroupSyncService.lastChanged]）。
  void notifyMembershipChatHeader(
    String groupId, {
    String action = 'member_added',
    List<String> memberUserIds = const <String>[],
  }) {
    final id = ChatIdFormat.normalizeGroupId(groupId);
    if (id.isEmpty) {
      return;
    }
    GroupSyncService.instance.lastChanged.value = GroupChangedNotice(
      groupId: id,
      action: action,
      memberUserIds: memberUserIds,
      pushTs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 增量/TCP 写回权威人数（不打全量详情）。
  Future<void> patchMemberCountForSync({
    required String groupId,
    required int memberCount,
  }) async {
    final owner = _ownerUserId();
    final id = ChatIdFormat.normalizeGroupId(groupId);
    if (owner.isEmpty || id.isEmpty || memberCount < 0) {
      return;
    }
    await _patchGroupFields(
      owner: owner,
      groupId: id,
      memberCount: memberCount,
    );
  }

  Future<void> refreshGroupDetail(
    String groupId, {
    bool refresh = false,
  }) async {
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
        await GroupLocalStore.instance.upsert(
          ownerUserId: owner,
          record: detail,
        );
        final prevName = current?.groupName.trim() ?? '';
        final prevAvatar = current?.avatarUrl.trim() ?? '';
        final nextName = detail.groupName.trim();
        final nextAvatar = detail.avatarUrl.trim();
        final nameChanged = nextName.isNotEmpty && nextName != prevName;
        final avatarChanged = nextAvatar.isNotEmpty && nextAvatar != prevAvatar;
        if (nameChanged || avatarChanged) {
          await publishGroupConversationDisplay(
            groupId: id,
            groupName: nameChanged ? nextName : null,
            avatarUrl: avatarChanged ? nextAvatar : null,
          );
        }
      }
    } catch (e) {
      _log('refreshGroupDetail failed groupId=$id error=$e');
    }
  }

  /// 拉人/踢人/退群后：成员首屏 + total 写回，供聊天头人数与成员列表实时对齐。
  ///
  /// 不依赖 TCP detail 是否带齐 memberUserIds / memberCount。
  /// 邀请本地增量后短窗内同群 member_added 族 reason 会 cooldown 跳过，避免双拉。
  Future<void> syncMembersAfterMembershipChange(
    String groupId, {
    String reason = 'manual',
  }) {
    final owner = _ownerUserId();
    final id = ChatIdFormat.normalizeGroupId(groupId);
    if (owner.isEmpty || id.isEmpty) {
      return Future<void>.value();
    }
    if (_shouldSkipMembershipSnapshotForCooldown(id, reason)) {
      SqfliteLockProfileLog.event(
        'membership_snapshot_cooldown_skip',
        extras: <String, Object?>{'groupId': id, 'reason': reason},
      );
      return Future<void>.value();
    }
    final key = '$owner|$id';
    final active = _membershipSnapshotInFlight[key];
    if (active != null) {
      SqfliteLockProfileLog.event(
        'membership_snapshot_coalesced',
        extras: <String, Object?>{'groupId': id, 'reason': reason},
      );
      return active;
    }
    late final Future<void> tracked;
    tracked = _syncMembersAfterMembershipChangeImpl(
      owner: owner,
      groupId: id,
      reason: reason,
    ).whenComplete(() {
      if (identical(_membershipSnapshotInFlight[key], tracked)) {
        _membershipSnapshotInFlight.remove(key);
      }
    });
    _membershipSnapshotInFlight[key] = tracked;
    return tracked;
  }

  /// 邀请成功热路径：只 upsert 新成员壳 + 本地人数 +N，禁止整页 refresh 快照。
  Future<void> applyMembersAddedLocally({
    required String groupId,
    required List<String> addedUserIds,
    int? memberCountOverride,
  }) async {
    final owner = _ownerUserId();
    final id = ChatIdFormat.normalizeGroupId(groupId);
    final normalized = addedUserIds
        .map(ChatIdFormat.rawUserUid)
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (owner.isEmpty || id.isEmpty || normalized.isEmpty) {
      return;
    }

    final existing = await GroupMemberLocalStore.instance.readRecordsByUserIds(
      groupId: id,
      userIds: normalized,
      ownerUserId: owner,
    );
    final existingIds = existing.map((e) => e.userId).toSet();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final shells = <GroupMemberRecord>[];
    Map<String, V2TimFriendInfo>? friendById;
    try {
      final friendship = serviceLocator<TUIFriendShipViewModel>();
      friendById = <String, V2TimFriendInfo>{
        for (final f in friendship.friendList ?? const <V2TimFriendInfo>[])
          if (ChatIdFormat.rawUserUid(f.userID).isNotEmpty)
            ChatIdFormat.rawUserUid(f.userID): f,
      };
    } catch (_) {
      friendById = null;
    }

    for (final uid in normalized) {
      if (existingIds.contains(uid)) {
        continue;
      }
      final friend = friendById?[uid];
      final profile = friend?.userProfile;
      final nick = (profile?.nickName ?? '').trim();
      final face = (profile?.faceUrl ?? '').trim();
      final remark = (friend?.friendRemark ?? '').trim();
      shells.add(
        GroupMemberRecord(
          userId: uid,
          nickname: nick,
          avatarUrl: face,
          friendRemark: remark,
          nameCard: '',
          role: 200,
          joinedAt: nowMs,
          isSelf: false,
          joinChannel: 'invite',
        ),
      );
    }

    if (shells.isNotEmpty) {
      await GroupMemberLocalStore.instance.upsertMany(
        ownerUserId: owner,
        groupId: id,
        records: shells,
      );
      final v2 = shells.map(_toV2TimMember).toList(growable: false);
      GroupMemberStore.instance.putMembers(id, v2);
    }

    final newlyAdded = shells.length;
    final current = await GroupLocalStore.instance.read(
      groupId: id,
      ownerUserId: owner,
    );
    final nextCount =
        memberCountOverride ?? ((current?.memberCount ?? 0) + newlyAdded);
    if (memberCountOverride != null || newlyAdded > 0) {
      await _patchGroupFields(
        owner: owner,
        groupId: id,
        memberCount: nextCount < 0 ? 0 : nextCount,
      );
    }

    markMembershipSyncCooldown(id);
    if (shells.isNotEmpty) {
      try {
        final listenerModel = serviceLocator<TUIGroupListenerModel>();
        listenerModel.requestProfileRefresh(
          NeedUpdate(
            id,
            UpdateType.memberEnter,
            shells
                .map(
                  (s) => V2TimGroupMemberInfo(
                    userID: s.userId,
                    nickName: s.nickname,
                    faceUrl: s.avatarUrl,
                    friendRemark: s.friendRemark,
                  ),
                )
                .toList(growable: false),
          ),
        );
      } catch (_) {
        notifyProfileRefresh(id, memberList: false);
      }
    } else {
      notifyProfileRefresh(id, memberList: false);
    }
    _log(
      'applyMembersAddedLocally groupId=$id added=${normalized.length} '
      'shells=${shells.length} memberCount=$nextCount',
    );
  }

  void markMembershipSyncCooldown(String groupId) {
    final id = ChatIdFormat.normalizeGroupId(groupId);
    if (id.isEmpty) {
      return;
    }
    _membershipSnapshotCooldownUntilMs[id] =
        DateTime.now().millisecondsSinceEpoch +
            GroupGovernanceLimits.membershipSyncCooldown.inMilliseconds;
  }

  @visibleForTesting
  static bool shouldSkipMembershipSnapshotForCooldownDecision({
    required int nowMs,
    required int cooldownUntilMs,
    required String reason,
  }) {
    if (nowMs >= cooldownUntilMs) {
      return false;
    }
    return _isMembershipAddedReasonFamily(reason);
  }

  bool _shouldSkipMembershipSnapshotForCooldown(String groupId, String reason) {
    final until = _membershipSnapshotCooldownUntilMs[groupId] ?? 0;
    return shouldSkipMembershipSnapshotForCooldownDecision(
      nowMs: DateTime.now().millisecondsSinceEpoch,
      cooldownUntilMs: until,
      reason: reason,
    );
  }

  static bool _isMembershipAddedReasonFamily(String reason) {
    final r = reason.trim().toLowerCase();
    if (r.isEmpty) {
      return false;
    }
    return r.contains('member_added') ||
        r.contains('invite_members') ||
        r.contains('invite');
  }

  Future<void> _syncMembersAfterMembershipChangeImpl({
    required String owner,
    required String groupId,
    required String reason,
  }) async {
    try {
      final preferred = await _resolveApiGroupIdForMembers(groupId);
      const limit = 100;
      final page = await MeGroupApi.instance.fetchGroupMembersPage(
        groupId: preferred.isNotEmpty ? preferred : groupId,
        limit: limit,
        offset: 0,
        refresh: true,
      );
      final nextOffset = page.items.length;
      final hasMore = page.items.length >= limit &&
          (page.total <= 0 || nextOffset < page.total);
      if (!hasMore) {
        await GroupMemberLocalStore.instance.replaceSnapshot(
          ownerUserId: owner,
          groupId: groupId,
          records: page.items,
        );
      } else {
        await GroupMemberLocalStore.instance.replacePage(
          ownerUserId: owner,
          groupId: groupId,
          offset: 0,
          records: page.items,
        );
      }
      if (page.total >= 0) {
        await _patchGroupFields(
          owner: owner,
          groupId: groupId,
          memberCount: page.total,
        );
      }
      notifyProfileRefresh(groupId, memberList: true);
      if (_isMembershipAddedReasonFamily(reason)) {
        markMembershipSyncCooldown(groupId);
      }
      _log(
        'syncMembersAfterMembershipChange ok groupId=$groupId '
        'reason=$reason total=${page.total} page=${page.items.length} '
        'hasMore=$hasMore',
      );
    } catch (e) {
      _log(
        'syncMembersAfterMembershipChange failed groupId=$groupId '
        'reason=$reason error=$e',
      );
    }
  }

  final Map<String, Future<bool>> _admitFromImInFlight =
      <String, Future<bool>>{};

  /// IM 已推送群会话/入群 tip，但本地成员库尚未写入时：先写入乐观成员壳上屏，
  /// 再拉详情校验；网络失败时保留壳（与杀进程重开一致，依赖后续 syncFull）。
  Future<bool> admitGroupMembershipFromImHint({
    required String groupId,
    String groupName = '',
    String avatarUrl = '',
  }) async {
    final owner = _ownerUserId();
    final id = ChatIdFormat.normalizeGroupId(groupId);
    if (owner.isEmpty || id.isEmpty) {
      return false;
    }
    if (isForbiddenGroupStorageId(id)) {
      _log('admit_reject_forbidden_id groupId=$id');
      GroupLeaveDiagLog.log(
        'admit_reject_forbidden_id',
        groupId: id,
      );
      SqfliteLockProfileLog.event(
        'admit_reject_forbidden_id',
        extras: <String, Object?>{'groupId': id},
      );
      return false;
    }
    final active = _admitFromImInFlight[id];
    if (active != null) {
      return active;
    }
    final task = _admitGroupMembershipFromImHintImpl(
      owner: owner,
      groupId: id,
      groupName: groupName,
      avatarUrl: avatarUrl,
    );
    _admitFromImInFlight[id] = task;
    try {
      return await task;
    } finally {
      if (identical(_admitFromImInFlight[id], task)) {
        _admitFromImInFlight.remove(id);
      }
    }
  }

  Future<bool> _admitGroupMembershipFromImHintImpl({
    required String owner,
    required String groupId,
    required String groupName,
    required String avatarUrl,
  }) async {
    if (isJoinedGroup(groupId)) {
      unawaited(
        ConversationSyncService.instance.onLocalGroupMembershipExpanded(
          groupId: groupId,
        ),
      );
      return true;
    }
    await _upsertOptimisticJoinedShell(
      ownerUserId: owner,
      groupId: groupId,
      groupName: groupName,
      avatarUrl: avatarUrl,
    );
    _bumpJoinedGroupsRevision();
    unawaited(
      ConversationSyncService.instance.onLocalGroupMembershipExpanded(
        groupId: groupId,
      ),
    );
    try {
      final current = await GroupLocalStore.instance.read(
        groupId: groupId,
        ownerUserId: owner,
      );
      final detail = await MeGroupApi.instance.fetchGroupDetail(
        groupId,
        refresh: true,
        preserveIsAllMutedFrom: current,
      );
      if (detail != null && detail.groupId.isNotEmpty) {
        await GroupLocalStore.instance.upsert(
          ownerUserId: owner,
          record: detail,
        );
        _bumpJoinedGroupsRevision();
        unawaited(
          ConversationSyncService.instance.onLocalGroupMembershipExpanded(
            groupId: groupId,
          ),
        );
        return true;
      }
      // 明确无资料：撤销乐观壳，避免幽灵群常驻。
      await GroupLocalStore.instance.delete(
        ownerUserId: owner,
        groupId: groupId,
      );
      _bumpJoinedGroupsRevision();
      return false;
    } catch (e) {
      _log(
          'admitGroupMembershipFromImHint verify failed groupId=$groupId error=$e');
      // 网络失败保留乐观壳，等待后续 syncFull / TCP 对齐。
      return true;
    }
  }

  Future<void> _upsertOptimisticJoinedShell({
    required String ownerUserId,
    required String groupId,
    required String groupName,
    required String avatarUrl,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final name = groupName.trim();
    final face = normalizeObjectUrl(avatarUrl.trim());
    await GroupLocalStore.instance.upsert(
      ownerUserId: ownerUserId,
      record: MeGroupRecord(
        groupId: groupId,
        groupType: 'Work',
        groupName: name,
        displayAlias: '',
        avatarUrl: face,
        notice: '',
        memberCount: 0,
        myRole: GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER,
        myNameCard: '',
        joinedAt: now,
        updatedAt: now,
      ),
    );
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
    final detailUserId =
        detail['userId']?.toString() ?? detail['user_id']?.toString();
    final selfRemoved = _isSelfRemovedFromGroupEvent(
      action: action,
      owner: owner,
      memberIds: memberIds,
      event: event,
    );
    final selfAdded = isSelfAddedToGroupMembershipEvent(
      action: action,
      ownerUserId: owner,
      memberUserIds: memberIds,
      detailUserId: detailUserId,
    );

    switch (action) {
      case 'group_dismissed':
        _markExplicitGroupRemoval(groupId);
        await GroupLocalStore.instance.delete(
          ownerUserId: owner,
          groupId: groupId,
        );
        await GroupMemberLocalStore.instance.clearGroup(
          ownerUserId: owner,
          groupId: groupId,
        );
        _bumpJoinedGroupsRevision();
        await _purgeGroupConversation(
          groupId,
          explicitMembershipEvent: true,
          reason: 'group_dismissed_event',
        );
        return true;
      case 'member_left':
      case 'member_removed':
        if (selfRemoved) {
          _markExplicitGroupRemoval(groupId);
          await GroupLocalStore.instance.delete(
            ownerUserId: owner,
            groupId: groupId,
          );
          await GroupMemberLocalStore.instance.clearGroup(
            ownerUserId: owner,
            groupId: groupId,
          );
          _bumpJoinedGroupsRevision();
          await _purgeGroupConversation(
            groupId,
            explicitMembershipEvent: true,
            reason: 'self_removed_event',
          );
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
        if (selfAdded) {
          _clearExplicitGroupRemoval(groupId);
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
          // IM 会话常早于成员库：补拉会话 + 冲刷挂起项，避免列表要杀进程才出现。
          unawaited(
            ConversationSyncService.instance.onLocalGroupMembershipExpanded(
              groupId: groupId,
            ),
          );
        } else {
          await _patchGroupFields(
            owner: owner,
            groupId: groupId,
            memberCount: _readInt(detail['memberCount']),
            incrementIfMissing: memberIds.length,
          );
          // TCP 常漏带被邀请人 ID：若 IM 已挂起该群会话，仍走入群恢复。
          if (!isJoinedGroup(groupId)) {
            unawaited(
              ConversationSyncService.instance
                  .recoverPendingGroupMembershipIfNeeded(groupId: groupId),
            );
          }
        }
        return true;
      case 'group_name_changed':
        final changedName = detail['groupName']?.toString().trim() ?? '';
        if (changedName.isEmpty) {
          await refreshGroupDetail(groupId, refresh: true);
        } else {
          await _patchGroupFields(
            owner: owner,
            groupId: groupId,
            groupName: changedName,
            updatedAt: _readInt(detail['updatedAt']),
          );
        }
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
        final changedAvatar = _readGroupAvatarUrl(detail);
        if (changedAvatar.isEmpty) {
          await refreshGroupDetail(groupId, refresh: true);
        } else {
          await upsertGroupAvatar(
            groupId: groupId,
            avatarUrl: changedAvatar,
          );
        }
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
        final userId = ChatIdFormat.rawUserUid(
          detail['userId']?.toString() ?? '',
        );
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
            transform: (current) =>
                current.copyWith(muteUntil: muteUntil > 0 ? muteUntil : 0),
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
    if (normalized == 'member_added') {
      unawaited(
        ConversationSyncService.instance
            .flushPendingGroupConversationsAfterMembershipChange(),
      );
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
    _markExplicitGroupRemoval(id);
    GroupMemberRolePending.instance.clearGroup(id);
    await GroupLocalStore.instance.delete(ownerUserId: owner, groupId: id);
    await GroupMemberLocalStore.instance.clearGroup(
      ownerUserId: owner,
      groupId: id,
    );
    _bumpJoinedGroupsRevision();
    await refreshUIKitGroupList();
    await _purgeGroupConversation(
      id,
      explicitMembershipEvent: true,
      reason: 'local_self_removed_success',
    );
    GroupLeaveDiagLog.log(
      'local_cleanup_done',
      groupId: id,
      extras: <String, Object?>{'ownerUserId': owner},
    );
  }

  /// 从 IM SDK 与本地会话库移除群会话，并通知消息列表刷新。
  @visibleForTesting
  static bool shouldDestructivelyPurgeGroupConversation({
    required bool explicitMembershipEvent,
  }) {
    return explicitMembershipEvent;
  }

  Future<void> _purgeGroupConversation(
    String groupId, {
    required bool explicitMembershipEvent,
    required String reason,
  }) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return;
    }
    if (!shouldDestructivelyPurgeGroupConversation(
      explicitMembershipEvent: explicitMembershipEvent,
    )) {
      // 普通列表差异只让 shouldShowConversation 暂时过滤；保留 SDK 与
      // SQLite 会话，待后续完整群列表/成员事件恢复，绝不清消息历史。
      GroupLeaveDiagLog.log(
        'purge_conversation_suppressed_unverified',
        groupId: id,
        extras: <String, Object?>{'reason': reason},
      );
      SqfliteLockProfileLog.event(
        'purge_conversation_suppressed_unverified',
        extras: <String, Object?>{'groupId': id, 'reason': reason},
      );
      return;
    }
    // 禁止把 c2c_ 当群清历史/删会话（会误伤真单聊）。
    if (isForbiddenGroupStorageId(id)) {
      _log('purge_reject_forbidden_id groupId=$id');
      GroupLeaveDiagLog.log(
        'purge_reject_forbidden_id',
        groupId: id,
        extras: const <String, Object?>{'path': 'purge'},
      );
      SqfliteLockProfileLog.event(
        'purge_reject_forbidden_id',
        extras: <String, Object?>{'groupId': id, 'path': 'purge'},
      );
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
    if (isForbiddenGroupStorageId(id)) {
      _log('purge_reject_forbidden_id groupId=$id path=clear');
      GroupLeaveDiagLog.log(
        'purge_reject_forbidden_id',
        groupId: id,
        extras: const <String, Object?>{'path': 'clear'},
      );
      SqfliteLockProfileLog.event(
        'purge_reject_forbidden_id',
        extras: <String, Object?>{'groupId': id, 'path': 'clear'},
      );
      return;
    }
    GroupLeaveDiagLog.log('clear_history_start', groupId: id);

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
    final conversations = await ConversationLocalStore.instance
        .listGroupConversationIds(ownerUserId: owner);
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
      await _purgeGroupConversation(
        groupId,
        explicitMembershipEvent: false,
        reason: 'membership_snapshot_prune:$reason',
      );
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
        .where(
          (id) =>
              id.isNotEmpty &&
              !joinedKeys.contains(GroupLocalStore.groupEquivalenceKey(id)),
        )
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
    _deferredSyncFullTimer?.cancel();
    _deferredSyncFullTimer = null;
    _deferredSyncFullReason = null;
    _deferredSyncFullRefresh = false;
    _tcpAuthSyncFullTimer = null;
    _revisionCoalesceTimer?.cancel();
    _revisionCoalesceTimer = null;
    _revisionCoalesceScheduled = false;
    _tcpAuthSyncFullGeneration++;
    _syncGeneration++;
    _explicitlyRemovedGroupKeys.clear();
    _activeConversationEvidenceKeys.clear();
    _snapshotMissingCounts.clear();
    _syncInFlight = null;
    _syncInFlightRefresh = false;
    _groupListSyncedOnce = false;
    _lastMeGroupsNetworkAt = null;
    _lastTcpAuthSyncAt = null;
    _groupMemberRefreshInFlight.clear();
    _membershipSnapshotInFlight.clear();
    _groupMemberPageInFlight.clear();
    await GroupLocalStore.instance.clearSession();
    await GroupMemberLocalStore.instance.clearSession();
    MyGroupListController.instance.clearSession();
    joinedGroupsRevision.value++;
  }

  @visibleForTesting
  void bumpJoinedGroupsRevisionForTest() => _bumpJoinedGroupsRevision();

  @visibleForTesting
  void flushJoinedGroupsRevisionCoalesceForTest() {
    _revisionCoalesceTimer?.cancel();
    _revisionCoalesceTimer = null;
    if (_revisionCoalesceScheduled) {
      _revisionCoalesceScheduled = false;
      joinedGroupsRevision.value++;
    }
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
      final needFreshDisplay = (groupName?.trim().isNotEmpty ?? false) ||
          (avatarUrl?.trim().isNotEmpty ?? false);
      await refreshGroupDetail(groupId, refresh: needFreshDisplay);
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
    final patchedName = groupName?.trim() ?? '';
    final patchedAvatar = avatarUrl?.trim() ?? '';
    if (patchedName.isNotEmpty || patchedAvatar.isNotEmpty) {
      await publishGroupConversationDisplay(
        groupId: groupId,
        groupName: patchedName.isNotEmpty ? patchedName : null,
        avatarUrl: patchedAvatar.isNotEmpty ? patchedAvatar : null,
      );
    }
  }

  /// 群名/头像写入群资料库后，双写会话列表内存与本地库（展示仍以群库为准）。
  Future<void> publishGroupConversationDisplay({
    required String groupId,
    String? groupName,
    String? avatarUrl,
  }) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return;
    }
    final cached = GroupLocalStore.instance.readCached(groupId: id);
    var name = (groupName ?? cached?.groupName ?? '').trim();
    if (name.isNotEmpty &&
        GroupDisplayResolver.looksLikeGroupIdLabel(name, groupId: id)) {
      name = '';
    }
    var face =
        normalizeObjectUrl((avatarUrl ?? cached?.avatarUrl ?? '').trim());
    if (name.isEmpty && face.isEmpty) {
      return;
    }

    final conversationId = id.startsWith('group_') ? id : 'group_$id';
    final canonical = ChatIdFormat.canonicalGroupStorageId(id);
    if (name.isNotEmpty) {
      DisplayNameStore.instance.setGroup(id, name);
      if (canonical.isNotEmpty && canonical != id) {
        DisplayNameStore.instance.setGroup(canonical, name);
      }
      try {
        serviceLocator<TUIConversationViewModel>()
            .updateGroupShowName(id, name);
      } catch (e) {
        _log('publishGroupConversationDisplay updateGroupShowName failed: $e');
      }
      try {
        serviceLocator<TUIFriendShipViewModel>().updateGroupNameLocal(id, name);
      } catch (e) {
        _log('publishGroupConversationDisplay updateGroupNameLocal failed: $e');
      }
    }
    if (face.isNotEmpty) {
      try {
        serviceLocator<TUIConversationViewModel>().updateGroupFaceUrl(id, face);
      } catch (e) {
        _log('publishGroupConversationDisplay updateGroupFaceUrl failed: $e');
      }
    }

    V2TimConversation? match;
    for (final item in ConversationListNotifier.instance.conversations) {
      final gid = item.groupID?.trim() ?? '';
      if (MessageConversationId.sameConversation(
            item.conversationID,
            conversationId,
          ) ||
          (gid.isNotEmpty && ChatIdFormat.groupIdsEquivalent(gid, id))) {
        match = item;
        break;
      }
    }
    if (match == null) {
      final candidates = <String>{
        conversationId,
        id,
        if (!id.startsWith('group_')) 'group_$id',
        if (canonical.isNotEmpty) canonical,
        if (canonical.isNotEmpty && !canonical.startsWith('group_'))
          'group_$canonical',
      };
      for (final candidate in candidates) {
        try {
          final row = await ConversationLocalStore.instance.conversationById(
            candidate,
          );
          if (row != null) {
            match = row;
            break;
          }
        } catch (_) {}
      }
    }

    final realConversationId =
        (match?.conversationID.trim().isNotEmpty ?? false)
            ? match!.conversationID.trim()
            : conversationId;
    if (name.isNotEmpty) {
      ConversationListNotifier.instance.applyShowNameLocally(
        conversationID: realConversationId,
        showName: name,
      );
      if (realConversationId != conversationId) {
        ConversationListNotifier.instance.applyShowNameLocally(
          conversationID: conversationId,
          showName: name,
        );
      }
    }
    if (face.isNotEmpty) {
      ConversationListNotifier.instance.applyFaceUrlLocally(
        conversationID: realConversationId,
        faceUrl: face,
      );
    }

    if (match != null) {
      if (name.isNotEmpty) {
        match.showName = name;
      }
      if (face.isNotEmpty) {
        match.faceUrl = face;
      }
      try {
        await ConversationLocalStore.instance.upsertBatch(
          conversations: <V2TimConversation>[match],
        );
      } catch (e) {
        _log('publishGroupConversationDisplay upsertBatch failed: $e');
      }
    }

    if (name.isNotEmpty) {
      try {
        serviceLocator<TUISearchViewModel>().patchGroupShowNameLocally(
          groupId: id,
          showName: name,
        );
      } catch (e) {
        _log('publishGroupConversationDisplay patchSearch failed: $e');
      }
    }

    ConversationRefreshBus.instance.requestRefresh(
      reason: 'group_display_updated',
      conversationId: realConversationId,
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
      'groupFaceUrl',
      'group_face_url',
      'faceUrl',
      'face_url',
      'thumbUrl',
      'thumb_url',
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
