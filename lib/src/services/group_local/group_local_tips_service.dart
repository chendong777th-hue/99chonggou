import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_change_event_metadata.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_local_tips_dedupe.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_profile_local_tip_preview.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_role_pending.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/local_message_overlay_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_tips_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_tips_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_tips_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// 自建群 REST/TCP 操作不会产生 IM GroupTips，本地注入并持久化群操作灰字提示。
class GroupLocalTipsService {
  GroupLocalTipsService._();

  static final GroupLocalTipsService instance = GroupLocalTipsService._();

  static const _prefsPrefix = 'group_local_tips_v1_';
  static const _anchorPrefix = 'group_create_anchor_v1_';
  static const _maxTipsPerGroup = 200;
  static const _dedupTtl = Duration(seconds: 30);

  /// 空会话（无真实 IM 消息）只允许注入「刚发生」的 tip，避免 membership
  /// 同步把一长串历史灰字铺进聊天页。
  static const _liveTipInjectMaxAge = Duration(minutes: 5);

  final Map<String, DateTime> _recentDedup = {};
  final Map<String, _MemberRemovalDedupEntry> _recentMemberRemoval = {};
  final Map<String, int> _groupCreateAnchorSec = {};
  final Set<String> _processedChangeEventIds = <String>{};

  /// 成员变动灰字已换轨 IM GroupTips；本地服务禁止再写这三类。
  static const Set<String> _deprecatedMemberTipActions = <String>{
    'member_added',
    'member_removed',
    'member_left',
  };

  static const Set<String> _tipActions = <String>{
    // 聊天灰字已改 App sendMessage（group_tip）；本地服务不再写入任何 tip。
  };

  Future<void> publishFromNotice(GroupChangedNotice notice) async {
    // 全量停写：聊天灰字改由 App sendMessage（group_tip）。
    return;
  }

  String _resolveTipAction(String action, Map<String, dynamic>? detail) {
    switch (action) {
      case 'member_muted':
        final muteUntil = _readInt(
          detail?['muteUntil'] ?? detail?['mute_until'],
        );
        final muteSeconds = _readInt(
          detail?['muteSeconds'] ?? detail?['mute_seconds'],
        );
        if (detail != null &&
            (detail.containsKey('muteUntil') ||
                detail.containsKey('mute_until') ||
                detail.containsKey('muteSeconds') ||
                detail.containsKey('mute_seconds'))) {
          return (muteUntil > 0 || muteSeconds > 0)
              ? 'member_muted'
              : 'member_unmuted';
        }
        return 'member_muted';
      case 'member_unmuted':
        return 'member_unmuted';
      case 'group_mute_all_changed':
        final isAllMuted = _readBool(
          detail?['shutUpAllMember'] ?? detail?['isAllMuted'],
        );
        return isAllMuted ? 'group_mute_all_on' : 'group_mute_all_off';
      case 'group_mute_all_on':
      case 'group_mute_all_off':
        return action;
      case 'member_role_changed':
        final role = _readInt(detail?['myRole'] ?? detail?['role']);
        if (role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN) {
          return 'member_set_admin';
        }
        if (role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER) {
          return 'member_cancel_admin';
        }
        return '';
      case 'member_set_admin':
      case 'member_cancel_admin':
        return action;
      case 'group_name_changed':
      case 'group_avatar_changed':
      case 'group_notice_changed':
        return action;
      default:
        return action;
    }
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }

  /// 建群自定义消息发送成功后登记锚点，并把早于锚点的本地邀请提示后移。
  Future<void> registerGroupCreateAnchor({
    required String groupId,
    required int timestampSec,
  }) async {
    if (!SelfHostedGroupBridge.enabled) {
      return;
    }
    final id = _normalizeGroupId(groupId);
    if (id.isEmpty || timestampSec <= 0) {
      return;
    }
    _groupCreateAnchorSec[id] = timestampSec;
    final scope = ContactSocialCacheStore.accountScope();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_anchorPrefix${scope}_$id', timestampSec);
    await _realignMemberTipsAfterGroupCreate(id, timestampSec);
  }

  Future<List<V2TimMessage>> mergeIntoHistoricalList({
    required String groupId,
    required List<V2TimMessage> messages,
  }) async {
    // 聊天灰字改由 App Custom（group_tip）进 IM 历史，不再 merge 本地 tip。
    return messages;
  }

  /// 丢掉比当前已加载真实历史更旧的 tip（上拉不应靠 tip 延伸）。
  List<V2TimMessage> _pruneTipsOlderThanRealWindow(
    List<V2TimMessage> messages,
    int oldestRealSec,
  ) {
    if (oldestRealSec <= 0) {
      return messages;
    }
    return messages.where((message) {
      if (!_isLocalGroupTipsMessage(message)) {
        return true;
      }
      final ts = message.timestamp ?? 0;
      return ts <= 0 || ts >= oldestRealSec;
    }).toList(growable: false);
  }

  /// 清空聊天记录后：删除本地持久化灰字，并从当前打开的会话列表移除。
  Future<void> clearHistoryForGroup(String groupId) async {
    final id = _normalizeGroupId(groupId);
    if (id.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final scope = ContactSocialCacheStore.accountScope();
    for (final storageId in _storageLookupIds(id)) {
      await prefs.remove('$_prefsPrefix${scope}_$storageId');
    }
    _removeTipsFromActiveChat(id, _isLocalGroupTipsMessage);
    LocalMessageOverlayStore.instance.clearConversation('group_$id');
  }

  Future<void> _publish({
    required String groupId,
    required String action,
    required String operatorUserId,
    required List<String> memberUserIds,
    int? occurredAtMs,
    String? changeEventId,
    int? timelineRank,
    Map<String, dynamic>? detail,
  }) async {
    if (!SelfHostedGroupBridge.enabled) {
      return;
    }
    final id = _normalizeGroupId(groupId);
    final operator = ChatIdFormat.rawUserUid(operatorUserId);
    final members = memberUserIds
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (id.isEmpty || !_tipActions.contains(action)) {
      return;
    }
    final normalizedChangeEventId = changeEventId?.trim() ?? '';
    if (normalizedChangeEventId.isNotEmpty) {
      if (_hasProcessedChangeEvent(normalizedChangeEventId)) {
        return;
      }
      final existingRecords = await _readRecords(id);
      if (existingRecords.any((item) => item.id == normalizedChangeEventId)) {
        _markChangeEventProcessed(normalizedChangeEventId);
        return;
      }
    }
    await _ensureGroupCreateAnchorLoaded(id);
    final allowsEmptyMembers = action == 'member_left' ||
        action == 'group_mute_all_on' ||
        action == 'group_mute_all_off' ||
        action == 'group_name_changed' ||
        action == 'group_avatar_changed' ||
        action == 'group_notice_changed';
    if (!allowsEmptyMembers && members.isEmpty) {
      return;
    }
    if (operator.isEmpty && action != 'member_left') {
      return;
    }

    final dedupKey = _dedupKey(
      groupId: id,
      action: action,
      operatorUserId: operator,
      memberUserIds: members,
    );
    if (_isRecentlyPublished(dedupKey)) {
      return;
    }

    if (action == 'member_added') {
      final semanticKey = memberAddedSemanticKey(id, members);
      if (_isRecentlyPublished(semanticKey)) {
        return;
      }
      final existingRecords = await _readRecords(id);
      final existing = _findActiveMemberAddedRecord(existingRecords, members);
      if (existing != null) {
        final incomingIsAdmin = await _resolveOperatorIsAdminExecutor(
          id,
          operator,
        );
        final existingIsAdmin = await _resolveOperatorIsAdminExecutor(
          id,
          existing.operatorUserId,
        );
        switch (decideMemberAddedDuplicate(
          existingOperatorIsAdmin: existingIsAdmin,
          incomingOperatorIsAdmin: incomingIsAdmin,
        )) {
          case MemberAddedDuplicateDecision.skipIncoming:
            _markPublished(dedupKey);
            _markPublished(semanticKey);
            return;
          case MemberAddedDuplicateDecision.replaceExisting:
            await _removeRecordAndTip(id, existing.id);
            break;
          case MemberAddedDuplicateDecision.publish:
            break;
        }
      }
      _markPublished(semanticKey);
    }

    if (action == 'member_removed') {
      // 同一脚踢人会从三路进来：本端即时注入（操作人=自己）、后端
      // change-event（操作人常是管理员执行账号）、实时推送。dedupKey 含
      // 操作人拦不住「阿伦踢出 + 管理员踢出」这种重复，这里按
      // 群+成员集合做语义去重：成员被踢后没有再次入群前，后到的同成员
      // 踢出 tip 视为同一事件，按操作人优先级决定去留。
      final semanticKey = memberRemovedSemanticKey(id, members);
      if (_isRecentlyPublished(semanticKey)) {
        return;
      }
      final existingRecords = await _readRecords(id);
      final existing = _findActiveMemberRemovedRecord(existingRecords, members);
      if (existing != null) {
        final incomingIsAdmin = await _resolveOperatorIsAdminExecutor(
          id,
          operator,
        );
        final existingIsAdmin = await _resolveOperatorIsAdminExecutor(
          id,
          existing.operatorUserId,
        );
        switch (decideMemberAddedDuplicate(
          existingOperatorIsAdmin: existingIsAdmin,
          incomingOperatorIsAdmin: incomingIsAdmin,
        )) {
          case MemberAddedDuplicateDecision.skipIncoming:
            _markPublished(dedupKey);
            _markPublished(semanticKey);
            return;
          case MemberAddedDuplicateDecision.replaceExisting:
            await _removeRecordAndTip(id, existing.id);
            break;
          case MemberAddedDuplicateDecision.publish:
            break;
        }
      }
      _markPublished(semanticKey);
    }

    if (isGroupProfileTipAction(action)) {
      // 自己改名：本端乐观 tip（操作人=自己）与 TCP（操作人常为管理员执行号）
      // 双写；按「群+动作+内容指纹」去重，避免短时间多次改名被误吞。
      final contentKey = groupProfileTipContentKey(
        action,
        detail,
        changeEventId: normalizedChangeEventId,
        occurredAtMs: occurredAtMs,
      );
      final semanticKey = groupProfileChangedSemanticKey(
        id,
        action,
        contentKey: contentKey,
      );
      if (_isRecentlyPublished(semanticKey)) {
        _markPublished(dedupKey);
        return;
      }
      final existingRecords = await _readRecords(id);
      final existing = _findLatestProfileRecord(
        existingRecords,
        action,
        contentKey: contentKey,
      );
      if (existing != null) {
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final ageSec = nowSec - existing.timestampSec;
        // 仅在短窗内与「同一次改名」的双写冲突；窗外视为新的改名事件。
        if (ageSec >= 0 && ageSec <= _dedupTtl.inSeconds) {
          final incomingIsAdmin =
              await _resolveProfileOperatorLooksLikeAdmin(id, operator);
          final existingIsAdmin = await _resolveProfileOperatorLooksLikeAdmin(
            id,
            existing.operatorUserId,
          );
          switch (decideMemberAddedDuplicate(
            existingOperatorIsAdmin: existingIsAdmin,
            incomingOperatorIsAdmin: incomingIsAdmin,
          )) {
            case MemberAddedDuplicateDecision.skipIncoming:
              _markPublished(dedupKey);
              _markPublished(semanticKey);
              return;
            case MemberAddedDuplicateDecision.replaceExisting:
              await _removeRecordAndTip(id, existing.id);
              break;
            case MemberAddedDuplicateDecision.publish:
              break;
          }
        }
      }
      _markPublished(semanticKey);
      _markPublished(dedupKey);

      final timestampSec = _resolveTipTimestampSec(
        groupId: id,
        occurredAtMs: occurredAtMs,
        action: action,
      );
      final resolvedTimelineRank = timelineRank ??
          GroupChangeEventMetadata.defaultTimelineRankForAction(action);
      final recordId = normalizedChangeEventId.isNotEmpty
          ? normalizedChangeEventId
          : 'local_gt_${id}_${timestampSec}_${_hashDedupKey(semanticKey)}';
      final record = GroupLocalTipsRecord(
        id: recordId,
        groupId: id,
        action: action,
        operatorUserId: operator,
        memberUserIds: members,
        timestampSec: timestampSec,
        timelineRank: resolvedTimelineRank,
        changeEventId:
            normalizedChangeEventId.isNotEmpty ? normalizedChangeEventId : null,
        contentKey: contentKey.isNotEmpty ? contentKey : null,
      );

      await _appendRecord(id, record);
      if (normalizedChangeEventId.isNotEmpty) {
        _markChangeEventProcessed(normalizedChangeEventId);
      }
      final message = await _recordToMessage(record);
      _insertIntoActiveChat(id, message);
      unawaited(syncVisibleTipsForGroup(id));
      return;
    }

    _markPublished(dedupKey);
    for (final memberId in members) {
      if (action == 'member_removed' || action == 'member_left') {
        _markMemberTip(
          groupId: id,
          memberId: memberId.isNotEmpty ? memberId : operator,
          action: action,
        );
      }
    }
    if (action == 'member_removed') {
      await _purgeQuitRecordsForMembers(id, members);
    }

    final timestampSec = _resolveTipTimestampSec(
      groupId: id,
      occurredAtMs: occurredAtMs,
      action: action,
    );
    final resolvedTimelineRank = timelineRank ??
        GroupChangeEventMetadata.defaultTimelineRankForAction(action);
    final recordId = normalizedChangeEventId.isNotEmpty
        ? normalizedChangeEventId
        : 'local_gt_${id}_${timestampSec}_${_hashDedupKey(dedupKey)}';
    final record = GroupLocalTipsRecord(
      id: recordId,
      groupId: id,
      action: action,
      operatorUserId: operator,
      memberUserIds: members,
      timestampSec: timestampSec,
      timelineRank: resolvedTimelineRank,
      changeEventId:
          normalizedChangeEventId.isNotEmpty ? normalizedChangeEventId : null,
    );

    await _appendRecord(id, record);
    if (normalizedChangeEventId.isNotEmpty) {
      _markChangeEventProcessed(normalizedChangeEventId);
    }
    final message = await _recordToMessage(record);
    _insertIntoActiveChat(id, message);
    unawaited(syncVisibleTipsForGroup(id));
  }

  Future<void> _appendRecord(
      String groupId, GroupLocalTipsRecord record) async {
    final existing = await _readRecords(groupId);
    final next = <GroupLocalTipsRecord>[
      ...existing.where((item) => item.id != record.id),
      record,
    ];
    if (next.length > _maxTipsPerGroup) {
      next.removeRange(0, next.length - _maxTipsPerGroup);
    }
    await _writeRecords(groupId, next);
    unawaited(_compactMemberAddedRecords(groupId));
    unawaited(_compactGroupProfileRecords(groupId));
  }

  Future<List<GroupLocalTipsRecord>> _readDedupedRecords(String groupId) async {
    final records = await _readRecords(groupId);
    final memberDeduped = await _dedupeStoredMemberAddedRecords(records);
    return _dedupeStoredGroupProfileRecords(memberDeduped);
  }

  Future<void> _compactMemberAddedRecords(String groupId) async {
    final raw = await _readRecords(groupId);
    final deduped = await _dedupeStoredMemberAddedRecords(raw);
    if (deduped.length == raw.length) {
      return;
    }
    await _writeRecords(groupId, deduped);
    final removedIds = raw.map((item) => item.id).toSet()
      ..removeAll(deduped.map((item) => item.id));
    if (removedIds.isEmpty) {
      return;
    }
    _removeTipsFromActiveChat(
      groupId,
      (message) {
        final tipId = _tipId(message);
        return tipId != null && removedIds.contains(tipId);
      },
    );
  }

  Future<void> _compactGroupProfileRecords(String groupId) async {
    final raw = await _readRecords(groupId);
    final deduped = await _dedupeStoredGroupProfileRecords(raw);
    if (deduped.length == raw.length) {
      return;
    }
    await _writeRecords(groupId, deduped);
    final removedIds = raw.map((item) => item.id).toSet()
      ..removeAll(deduped.map((item) => item.id));
    if (removedIds.isEmpty) {
      return;
    }
    _removeTipsFromActiveChat(
      groupId,
      (message) {
        final tipId = _tipId(message);
        return tipId != null && removedIds.contains(tipId);
      },
    );
  }

  Future<List<GroupLocalTipsRecord>> _readRecords(String groupId) async {
    final lookupIds = _storageLookupIds(groupId);
    final byId = <String, GroupLocalTipsRecord>{};
    for (final storageId in lookupIds) {
      for (final record in await _readRecordsRaw(storageId)) {
        // 成员变动 tip 已换轨 IM GroupTips：旧 prefs 记录不读、不 merge。
        if (_deprecatedMemberTipActions.contains(record.action)) {
          continue;
        }
        byId[record.id] = record;
      }
    }
    return byId.values.toList(growable: false);
  }

  Future<List<GroupLocalTipsRecord>> _readRecordsRaw(String storageId) async {
    final scope = ContactSocialCacheStore.accountScope();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefsPrefix${scope}_$storageId');
    if (raw == null || raw.isEmpty) {
      return const <GroupLocalTipsRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <GroupLocalTipsRecord>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => GroupLocalTipsRecord.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <GroupLocalTipsRecord>[];
    }
  }

  Future<V2TimMessage> _recordToMessage(GroupLocalTipsRecord record) async {
    final groupId = _normalizeGroupId(record.groupId);
    final tipsType = _tipsType(record.action);
    final memberIds = record.action == 'member_left'
        ? <String>[record.operatorUserId]
        : record.memberUserIds;
    final resolvedMembers = await _resolveMemberInfos(
      groupId: groupId,
      userIds: <String>[
        record.operatorUserId,
        ...memberIds,
      ],
    );
    final opMember = resolvedMembers[record.operatorUserId] ??
        V2TimGroupMemberInfo(userID: record.operatorUserId);
    final memberList = <V2TimGroupMemberInfo>[];
    if (record.action == 'member_left') {
      memberList.add(opMember);
    } else {
      for (final userId in record.memberUserIds) {
        memberList.add(
          resolvedMembers[userId] ?? V2TimGroupMemberInfo(userID: userId),
        );
      }
    }

    final groupTipsElem = V2TimGroupTipsElem(
      groupID: groupId,
      type: tipsType,
      opMember: opMember,
      memberList: memberList,
    );
    final message = V2TimMessage(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS,
      groupID: groupId,
      timestamp: record.timestampSec,
      isExcludedFromLastMessage: false,
      isExcludedFromUnreadCount: false,
      groupTipsElem: groupTipsElem,
    );
    groupTipsElem.setMessageInternal(message);
    groupTipsElem.setElemIndexInternal(0);
    message.elemList.add(groupTipsElem);
    message.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    message.id = record.id;
    message.msgID = record.id;
    final previewAbstract = _previewAbstractFromRecord(
      record,
      opMember,
      memberList,
    );
    message.localCustomData = jsonEncode(<String, dynamic>{
      'localGroupTips': true,
      'tipId': record.id,
      'groupId': groupId,
      'action': record.action,
      'previewAbstract': previewAbstract,
      if (record.timelineRank != null) 'timelineRank': record.timelineRank,
      if (record.changeEventId != null && record.changeEventId!.isNotEmpty)
        'changeEventId': record.changeEventId,
    });
    return message;
  }

  String _previewAbstractFromRecord(
    GroupLocalTipsRecord record,
    V2TimGroupMemberInfo opMember,
    List<V2TimGroupMemberInfo> memberList,
  ) {
    final opName = _memberDisplayName(opMember, normalizeAdmin: true);
    switch (record.action) {
      case 'member_added':
        final names = memberList.map(_memberDisplayName).join('、');
        if (memberList.length == 1 &&
            memberList.first.userID == opMember.userID) {
          return '$names加入群聊';
        }
        return '$opName邀请$names加入群组';
      case 'member_removed':
        final names = memberList.map(_memberDisplayName).join('、');
        return '$opName将$names踢出群组';
      case 'member_left':
        return '${_memberDisplayName(opMember)}退出群聊';
      case 'member_muted':
        final names = memberList.map(_memberDisplayName).join('、');
        return '$opName将$names禁言';
      case 'member_unmuted':
        final names = memberList.map(_memberDisplayName).join('、');
        return '$opName解除了$names的禁言';
      case 'group_mute_all_on':
        return '$opName开启了全员禁言';
      case 'group_mute_all_off':
        return '$opName关闭了全员禁言';
      case 'member_set_admin':
        final names = memberList.map(_memberDisplayName).join('、');
        return '$opName将$names设置为管理员';
      case 'member_cancel_admin':
        final names = memberList.map(_memberDisplayName).join('、');
        return '$opName将$names取消管理员';
      case 'group_name_changed':
      case 'group_avatar_changed':
      case 'group_notice_changed':
        return groupProfileLocalTipPreview(record.action, opName);
      default:
        return '群提示';
    }
  }

  String _memberDisplayName(
    V2TimGroupMemberInfo member, {
    bool normalizeAdmin = false,
  }) {
    final friendRemark = member.friendRemark?.trim() ?? '';
    if (friendRemark.isNotEmpty) {
      return friendRemark;
    }
    final nameCard = member.nameCard?.trim() ?? '';
    if (nameCard.isNotEmpty) {
      return _normalizeAdminDisplayName(nameCard,
          normalizeAdmin: normalizeAdmin);
    }
    final nickName = member.nickName?.trim() ?? '';
    if (nickName.isNotEmpty) {
      return _normalizeAdminDisplayName(nickName,
          normalizeAdmin: normalizeAdmin);
    }
    final userId = member.userID?.trim() ?? '';
    if (userId.isEmpty) {
      return '';
    }
    return _normalizeAdminDisplayName(userId, normalizeAdmin: normalizeAdmin);
  }

  String _normalizeAdminDisplayName(
    String name, {
    required bool normalizeAdmin,
  }) {
    if (!normalizeAdmin) {
      return name;
    }
    final lower = name.trim().toLowerCase();
    if (lower == 'administrator' || lower == 'admin') {
      return AppI18n.current.t(
        zhHans: '管理员',
        zhHant: '管理員',
        en: 'Admin',
        ja: '管理者',
        ko: '관리자',
      );
    }
    return name;
  }

  bool _memberHasDisplayName(V2TimGroupMemberInfo member) {
    final id = member.userID?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    final display = _memberDisplayName(member);
    return display.isNotEmpty && display != id;
  }

  Future<Map<String, V2TimGroupMemberInfo>> _resolveMemberInfos({
    required String groupId,
    required List<String> userIds,
  }) async {
    final wanted = userIds
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toSet();
    if (wanted.isEmpty) {
      return const <String, V2TimGroupMemberInfo>{};
    }

    final resolved = <String, V2TimGroupMemberInfo>{};
    for (final userId in wanted) {
      resolved[userId] = await _resolveMemberInfo(groupId, userId);
    }

    final missing = wanted.where((userId) {
      final member = resolved[userId];
      return member == null || !_memberHasDisplayName(member);
    }).toList(growable: false);
    if (missing.isEmpty) {
      return resolved;
    }

    try {
      final res = await TIMUIKitCore.getSDKInstance().getUsersInfo(
        userIDList: missing,
      );
      if (res.code == 0 && res.data != null) {
        for (final user in res.data!) {
          final userId = ChatIdFormat.rawUserUid(user.userID);
          final nick = user.nickName?.trim() ?? '';
          if (userId.isEmpty || nick.isEmpty) {
            continue;
          }
          final existing = resolved[userId];
          resolved[userId] = V2TimGroupMemberInfo(
            userID: userId,
            nickName: nick,
            nameCard: existing?.nameCard,
            friendRemark: existing?.friendRemark,
          );
        }
      }
    } catch (_) {}

    return resolved;
  }

  Future<void> _purgeQuitRecordsForMembers(
    String groupId,
    List<String> memberUserIds,
  ) async {
    final members = memberUserIds
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toSet();
    if (members.isEmpty) {
      return;
    }
    final records = await _readRecords(groupId);
    if (records.isEmpty) {
      return;
    }
    final removedTipIds = <String>{};
    final next = <GroupLocalTipsRecord>[];
    for (final record in records) {
      if (record.action != 'member_left') {
        next.add(record);
        continue;
      }
      final leaver = ChatIdFormat.rawUserUid(
        record.memberUserIds.isNotEmpty
            ? record.memberUserIds.first
            : record.operatorUserId,
      );
      if (members.contains(leaver)) {
        removedTipIds.add(record.id);
        continue;
      }
      next.add(record);
    }
    if (removedTipIds.isEmpty) {
      return;
    }
    await _writeRecords(groupId, next);
    _removeTipsFromActiveChat(
      groupId,
      (message) {
        final tipId = _tipId(message);
        return tipId != null && removedTipIds.contains(tipId);
      },
    );
  }

  Future<void> _writeRecords(
    String groupId,
    List<GroupLocalTipsRecord> records,
  ) async {
    final storageId = _normalizeGroupId(groupId);
    final scope = ContactSocialCacheStore.accountScope();
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsPrefix${scope}_$storageId';
    await prefs.setString(
      key,
      jsonEncode(records.map((item) => item.toJson()).toList()),
    );
  }

  /// 将已持久化的本地群灰字合并进当前打开中的聊天列表（旁观者补全历史）。
  Future<void> syncVisibleTipsForGroup(String groupId) async {
    final id = _normalizeGroupId(groupId);
    if (id.isEmpty) {
      return;
    }
    final records = await _readDedupedRecords(id);
    for (final record in records) {
      _insertIntoActiveChat(id, await _recordToMessage(record));
    }
  }

  List<String> _storageLookupIds(String groupId) {
    final out = <String>[];
    void add(String value) {
      final id = value.trim();
      if (id.isNotEmpty && !out.contains(id)) {
        out.add(id);
      }
    }

    add(_normalizeGroupId(groupId));
    for (final candidate in ChatIdFormat.groupIdLookupCandidates(groupId)) {
      add(ChatIdFormat.canonicalGroupStorageId(candidate));
      add(candidate);
    }
    return out;
  }

  Future<V2TimGroupMemberInfo> _resolveMemberInfo(
    String groupId,
    String userId,
  ) async {
    final normalized = ChatIdFormat.rawUserUid(userId);
    if (normalized.isEmpty) {
      return V2TimGroupMemberInfo(userID: userId);
    }

    final fromStore = await GroupMemberLocalStore.instance.readByUserIds(
      groupId: groupId,
      userIds: <String>[normalized],
    );
    if (fromStore.isNotEmpty) {
      final member = fromStore.first;
      return V2TimGroupMemberInfo(
        userID: member.userID,
        nickName: member.nickName,
        nameCard: member.nameCard,
        friendRemark: member.friendRemark,
      );
    }

    final fromMemory = GroupMemberStore.instance.memberOf(groupId, normalized);
    if (fromMemory != null) {
      return V2TimGroupMemberInfo(
        userID: normalized,
        nickName: fromMemory.nickName,
        nameCard: fromMemory.nameCard,
        friendRemark: fromMemory.friendRemark,
      );
    }

    try {
      final friendList =
          serviceLocator<TUIFriendShipViewModel>().friendList ?? const [];
      final friend = FriendDisplayName.findFriend(friendList, normalized);
      if (friend != null) {
        return V2TimGroupMemberInfo(
          userID: normalized,
          nickName: friend.userProfile?.nickName,
          friendRemark: friend.friendRemark,
        );
      }
    } catch (_) {}

    try {
      final profile = await UserProfileLocalService.instance.read(normalized);
      if (profile != null) {
        final remark = profile.friendRemark.trim();
        final nickname = profile.nickname.trim();
        if (remark.isNotEmpty || nickname.isNotEmpty) {
          return V2TimGroupMemberInfo(
            userID: normalized,
            nickName: nickname.isNotEmpty ? nickname : null,
            friendRemark: remark.isNotEmpty ? remark : null,
          );
        }
      }
    } catch (_) {}

    return V2TimGroupMemberInfo(userID: normalized);
  }

  int _tipsType(String action) {
    switch (action) {
      case 'member_added':
        return GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE;
      case 'member_removed':
        return GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_KICKED;
      case 'member_left':
        return GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_QUIT;
      case 'member_muted':
      case 'member_unmuted':
        return GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_MEMBER_INFO_CHANGE;
      case 'group_mute_all_on':
      case 'group_mute_all_off':
      case 'group_name_changed':
      case 'group_avatar_changed':
      case 'group_notice_changed':
        return GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_GROUP_INFO_CHANGE;
      case 'member_set_admin':
        return GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN;
      case 'member_cancel_admin':
        return GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN;
      default:
        return GroupTipsElemType.GROUP_TIPS_TYPE_INVALID;
    }
  }

  int _resolveTipTimestampSec({
    required String groupId,
    int? occurredAtMs,
    String? action,
  }) {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var candidate = nowSec;
    if (occurredAtMs != null && occurredAtMs > 0) {
      candidate = GroupChangeEventMetadata.normalizeEventTimestampSec(
        occurredAtMs,
      );
    } else {
      final latestVisible = _latestActiveChatMessageSec(groupId);
      if (latestVisible > candidate) {
        candidate = latestVisible;
      }
    }
    final anchor = _groupCreateAnchorSec[groupId] ?? 0;
    if (anchor > 0 &&
        action != null &&
        _deprecatedMemberTipActions.contains(action) &&
        candidate <= anchor) {
      candidate = anchor + 1;
    }
    // 禁止 tip 落到未来秒，避免一直钉在「最新」槽。
    if (candidate > nowSec) {
      candidate = nowSec;
    }
    return candidate;
  }

  int _messageTimestampSec(V2TimMessage message) {
    final ts = message.timestamp ?? 0;
    if (ts <= 0) {
      return 0;
    }
    if (ts >= 1000000000000) {
      return (ts / 1000).ceil();
    }
    return ts;
  }

  int _latestActiveChatMessageSec(String groupId) {
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    var latest = _groupCreateAnchorSec[groupId] ?? 0;
    for (final key in _messageListKeys(groupId)) {
      final list = globalModel.messageListMap[key];
      if (list == null || list.isEmpty) {
        continue;
      }
      for (final message in list) {
        if (_isLocalGroupTipsMessage(message)) {
          continue;
        }
        final sec = _messageTimestampSec(message);
        if (sec > latest) {
          latest = sec;
        }
      }
    }
    return latest;
  }

  bool _isLocalGroupTipsMessage(V2TimMessage message) {
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isEmpty) {
      return false;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map && decoded['localGroupTips'] == true;
    } catch (_) {
      return false;
    }
  }

  void _insertIntoActiveChat(String groupId, V2TimMessage message) {
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final tipId = _tipId(message);
    final tipTs = message.timestamp ?? 0;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ageSec = tipTs > 0 && tipTs <= nowSec + 60 ? nowSec - tipTs : 0;
    final isLiveTip = tipTs <= 0 || ageSec <= _liveTipInjectMaxAge.inSeconds;
    for (final key in _messageListKeys(groupId)) {
      final existing = List<V2TimMessage>.from(
        globalModel.messageListMap[key] ?? const <V2TimMessage>[],
      );
      var oldestRealSec = 0;
      var hasRealMessages = false;
      for (final item in existing) {
        if (_isLocalGroupTipsMessage(item)) {
          continue;
        }
        hasRealMessages = true;
        final ts = item.timestamp ?? 0;
        if (ts > 0 && (oldestRealSec == 0 || ts < oldestRealSec)) {
          oldestRealSec = ts;
        }
      }
      // 无真实消息时：历史 tip 只落库，不往聊天页灌；实时 tip 仍可显示。
      if (!hasRealMessages && !isLiveTip) {
        continue;
      }
      // 有真实消息时：不把比当前窗口更旧的 tip 插进列表（上拉不靠 tip）。
      if (hasRealMessages &&
          tipTs > 0 &&
          oldestRealSec > 0 &&
          tipTs < oldestRealSec) {
        continue;
      }
      if (tipId != null && existing.any((item) => _tipId(item) == tipId)) {
        continue;
      }
      LocalMessageOverlayStore.instance.upsert('group_$groupId', message);
    }
  }

  void _removeTipsFromActiveChat(
    String groupId,
    bool Function(V2TimMessage message) shouldRemove,
  ) {
    LocalMessageOverlayStore.instance.removeWhere(
      'group_${_normalizeGroupId(groupId)}',
      shouldRemove,
    );
  }

  List<V2TimMessage> _mergeMessageLists(
    List<V2TimMessage> base,
    List<V2TimMessage> localTips,
  ) {
    final existingTipIds = base.map(_tipId).whereType<String>().toSet();
    final existingMemberKeys = base
        .map(GroupTipsMessageHelper.memberAddedSemanticKey)
        .whereType<String>()
        .toSet();
    final toAdd = localTips.where((item) {
      final id = _tipId(item);
      if (id != null && existingTipIds.contains(id)) {
        return false;
      }
      final semanticKey = GroupTipsMessageHelper.memberAddedSemanticKey(item);
      if (semanticKey != null && existingMemberKeys.contains(semanticKey)) {
        return false;
      }
      return id != null;
    }).toList(growable: false);
    if (toAdd.isEmpty) {
      return base;
    }
    final merged = <V2TimMessage>[...base, ...toAdd];
    merged.sort(TUIChatGlobalModel.compareMessagesChronological);
    return merged.reversed.toList();
  }

  Future<void> _realignMemberTipsAfterGroupCreate(
    String groupId,
    int anchorSec,
  ) async {
    final records = await _readRecords(groupId);
    if (records.isEmpty) {
      return;
    }
    final toRealign = records
        .where(
          (record) =>
              record.action == 'member_added' &&
              record.timestampSec <= anchorSec,
        )
        .toList(growable: false)
      ..sort((left, right) => left.timestampSec.compareTo(right.timestampSec));
    if (toRealign.isEmpty) {
      return;
    }

    var offset = 1;
    final updatedById = <String, GroupLocalTipsRecord>{};
    for (final record in toRealign) {
      final nextTs = anchorSec + offset;
      offset++;
      final dedupKey = _dedupKey(
        groupId: groupId,
        action: record.action,
        operatorUserId: record.operatorUserId,
        memberUserIds: record.memberUserIds,
      );
      updatedById[record.id] = GroupLocalTipsRecord(
        id: 'local_gt_${groupId}_${nextTs}_${_hashDedupKey(dedupKey)}',
        groupId: groupId,
        action: record.action,
        operatorUserId: record.operatorUserId,
        memberUserIds: record.memberUserIds,
        timestampSec: nextTs,
        timelineRank: record.timelineRank,
        changeEventId: record.changeEventId,
        contentKey: record.contentKey,
      );
    }

    final nextRecords = records
        .map((record) => updatedById[record.id] ?? record)
        .toList(growable: false);
    await _writeRecords(groupId, nextRecords);

    final oldIds = toRealign.map((record) => record.id).toSet();
    _removeTipsFromActiveChat(
      groupId,
      (message) {
        final tipId = _tipId(message);
        return tipId != null && oldIds.contains(tipId);
      },
    );
    for (final record in updatedById.values) {
      final message = await _recordToMessage(record);
      _insertIntoActiveChat(groupId, message);
    }
  }

  Future<int?> _readPersistedGroupCreateAnchor(String groupId) async {
    final cached = _groupCreateAnchorSec[groupId];
    if (cached != null && cached > 0) {
      return cached;
    }
    final scope = ContactSocialCacheStore.accountScope();
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt('$_anchorPrefix${scope}_$groupId');
    if (value != null && value > 0) {
      _groupCreateAnchorSec[groupId] = value;
      return value;
    }
    return null;
  }

  Future<void> _ensureGroupCreateAnchorLoaded(String groupId) async {
    if (_groupCreateAnchorSec.containsKey(groupId)) {
      return;
    }
    await _readPersistedGroupCreateAnchor(groupId);
  }

  Iterable<String> _messageListKeys(String groupId) sync* {
    final raw = _normalizeGroupId(groupId);
    if (raw.isEmpty) {
      return;
    }
    yield raw;
    final prefixed = 'group_$raw';
    yield prefixed;
  }

  String? _tipId(V2TimMessage message) {
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['localGroupTips'] == true) {
          final tipId = decoded['tipId']?.toString().trim() ?? '';
          if (tipId.isNotEmpty) {
            return tipId;
          }
        }
      } catch (_) {}
    }
    return message.id?.trim();
  }

  String _normalizeGroupId(String groupId) {
    return ChatIdFormat.canonicalGroupStorageId(groupId);
  }

  bool _hasProcessedChangeEvent(String changeEventId) {
    final id = changeEventId.trim();
    if (id.isEmpty) {
      return false;
    }
    return _processedChangeEventIds.contains(id);
  }

  void _markChangeEventProcessed(String changeEventId) {
    final id = changeEventId.trim();
    if (id.isEmpty) {
      return;
    }
    _processedChangeEventIds.add(id);
    if (_processedChangeEventIds.length > 500) {
      _processedChangeEventIds.remove(_processedChangeEventIds.first);
    }
  }

  String _selfUserId() {
    return ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
  }

  String _dedupKey({
    required String groupId,
    required String action,
    required String operatorUserId,
    required List<String> memberUserIds,
  }) {
    final members = List<String>.from(memberUserIds)..sort();
    return '$groupId|$action|$operatorUserId|${members.join(',')}';
  }

  int _hashDedupKey(String key) {
    return key.hashCode & 0x7fffffff;
  }

  bool _isRecentlyPublished(String dedupKey) {
    final at = _recentDedup[dedupKey];
    if (at == null) {
      return false;
    }
    if (DateTime.now().difference(at) > _dedupTtl) {
      _recentDedup.remove(dedupKey);
      return false;
    }
    return true;
  }

  void _markPublished(String dedupKey) {
    _recentDedup[dedupKey] = DateTime.now();
  }

  String _memberTipKey(String groupId, String memberId) {
    return '${_normalizeGroupId(groupId)}|${ChatIdFormat.rawUserUid(memberId)}';
  }

  void _markMemberTip({
    required String groupId,
    required String memberId,
    required String action,
  }) {
    final normalizedMember = ChatIdFormat.rawUserUid(memberId);
    if (normalizedMember.isEmpty) {
      return;
    }
    final key = _memberTipKey(groupId, normalizedMember);
    final existing = _recentMemberRemoval[key];
    if (existing != null &&
        existing.action == 'member_left' &&
        action == 'member_removed') {
      _recentMemberRemoval[key] = _MemberRemovalDedupEntry(
        action: action,
        at: DateTime.now(),
      );
      return;
    }
    if (existing == null || action == 'member_removed') {
      _recentMemberRemoval[key] = _MemberRemovalDedupEntry(
        action: action,
        at: DateTime.now(),
      );
    }
  }

  Future<bool> _resolveOperatorIsAdminExecutor(
    String groupId,
    String operatorUserId,
  ) async {
    final operator = ChatIdFormat.rawUserUid(operatorUserId);
    if (operator.isEmpty) {
      return false;
    }
    final info = await _resolveMemberInfo(groupId, operator);
    final displayName = _memberDisplayName(info, normalizeAdmin: false);
    if (looksLikeAdminExecutorLabel(displayName)) {
      return true;
    }
    final fromStore = await GroupMemberLocalStore.instance.readByUserIds(
      groupId: groupId,
      userIds: <String>[operator],
    );
    if (fromStore.isNotEmpty) {
      final role = fromStore.first.role;
      if (role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN ||
          role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER) {
        return true;
      }
    }
    return false;
  }

  /// 资料变更 tip：只认展示名像「管理员」的执行号，避免群主自己改名被当成 admin。
  Future<bool> _resolveProfileOperatorLooksLikeAdmin(
    String groupId,
    String operatorUserId,
  ) async {
    final operator = ChatIdFormat.rawUserUid(operatorUserId);
    if (operator.isEmpty) {
      return false;
    }
    final info = await _resolveMemberInfo(groupId, operator);
    final displayName = _memberDisplayName(info, normalizeAdmin: false);
    return looksLikeAdminExecutorLabel(displayName);
  }

  GroupLocalTipsRecord? _findLatestProfileRecord(
    List<GroupLocalTipsRecord> records,
    String action, {
    String contentKey = '',
  }) {
    final normalized = action.trim().toLowerCase();
    final expectedContent = contentKey.trim();
    GroupLocalTipsRecord? latest;
    for (final record in records) {
      if (record.action != normalized) {
        continue;
      }
      final recordContent = record.contentKey?.trim() ?? '';
      if (expectedContent.isNotEmpty || recordContent.isNotEmpty) {
        if (recordContent != expectedContent) {
          continue;
        }
      }
      if (latest == null || record.timestampSec >= latest.timestampSec) {
        latest = record;
      }
    }
    return latest;
  }

  Future<List<GroupLocalTipsRecord>> _dedupeStoredGroupProfileRecords(
    List<GroupLocalTipsRecord> records,
  ) async {
    if (records.isEmpty) {
      return records;
    }
    final sorted = List<GroupLocalTipsRecord>.from(records)
      ..sort((left, right) => left.timestampSec.compareTo(right.timestampSec));
    final output = <GroupLocalTipsRecord>[];
    final activeByKey = <String, GroupLocalTipsRecord>{};

    for (final record in sorted) {
      if (!isGroupProfileTipAction(record.action)) {
        output.add(record);
        continue;
      }
      final key = groupProfileChangedSemanticKey(
        record.groupId,
        record.action,
        contentKey: record.contentKey ?? '',
      );
      final existing = activeByKey[key];
      if (existing == null) {
        activeByKey[key] = record;
        output.add(record);
        continue;
      }
      final ageSec = record.timestampSec - existing.timestampSec;
      // 窗外：视为另一次改名，两条都保留；更新 active 指向较新。
      if (ageSec < 0 || ageSec > _dedupTtl.inSeconds) {
        activeByKey[key] = record;
        output.add(record);
        continue;
      }
      final existingIsAdmin = await _resolveProfileOperatorLooksLikeAdmin(
        record.groupId,
        existing.operatorUserId,
      );
      final incomingIsAdmin = await _resolveProfileOperatorLooksLikeAdmin(
        record.groupId,
        record.operatorUserId,
      );
      switch (decideMemberAddedDuplicate(
        existingOperatorIsAdmin: existingIsAdmin,
        incomingOperatorIsAdmin: incomingIsAdmin,
      )) {
        case MemberAddedDuplicateDecision.skipIncoming:
          continue;
        case MemberAddedDuplicateDecision.replaceExisting:
        case MemberAddedDuplicateDecision.publish:
          activeByKey[key] = record;
          output.remove(existing);
          output.add(record);
          continue;
      }
    }
    return output;
  }

  GroupLocalTipsRecord? _findActiveMemberAddedRecord(
    List<GroupLocalTipsRecord> records,
    List<String> members,
  ) {
    final sorted = List<GroupLocalTipsRecord>.from(records)
      ..sort((left, right) => left.timestampSec.compareTo(right.timestampSec));
    GroupLocalTipsRecord? latestAdd;
    final memberSet = members
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toSet();
    if (memberSet.isEmpty) {
      return null;
    }
    for (final record in sorted) {
      if (record.action == 'member_removed' &&
          record.memberUserIds
              .map(ChatIdFormat.rawUserUid)
              .any(memberSet.contains) &&
          latestAdd != null &&
          record.timestampSec >= latestAdd.timestampSec) {
        latestAdd = null;
      }
      if (record.action == 'member_added' &&
          _sameMemberUserIds(record.memberUserIds, members)) {
        latestAdd = record;
      }
    }
    return latestAdd;
  }

  /// 同成员集合、且之后没有再次入群的最近一条 member_removed 记录；
  /// 存在即视为同一脚踢人的重复来源。
  GroupLocalTipsRecord? _findActiveMemberRemovedRecord(
    List<GroupLocalTipsRecord> records,
    List<String> members,
  ) {
    final sorted = List<GroupLocalTipsRecord>.from(records)
      ..sort((left, right) => left.timestampSec.compareTo(right.timestampSec));
    GroupLocalTipsRecord? latestRemove;
    final memberSet = members
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toSet();
    if (memberSet.isEmpty) {
      return null;
    }
    for (final record in sorted) {
      if (record.action == 'member_added' &&
          record.memberUserIds
              .map(ChatIdFormat.rawUserUid)
              .any(memberSet.contains) &&
          latestRemove != null &&
          record.timestampSec >= latestRemove.timestampSec) {
        // 被踢成员重新入群后再被踢，是新事件，不与旧记录去重。
        latestRemove = null;
      }
      if (record.action == 'member_removed' &&
          _sameMemberUserIds(record.memberUserIds, members)) {
        latestRemove = record;
      }
    }
    return latestRemove;
  }

  Future<List<GroupLocalTipsRecord>> _dedupeStoredMemberAddedRecords(
    List<GroupLocalTipsRecord> records,
  ) async {
    if (records.isEmpty) {
      return records;
    }
    final sorted = List<GroupLocalTipsRecord>.from(records)
      ..sort((left, right) => left.timestampSec.compareTo(right.timestampSec));
    final output = <GroupLocalTipsRecord>[];
    final activeAddsByKey = <String, GroupLocalTipsRecord>{};
    final activeRemovesByKey = <String, GroupLocalTipsRecord>{};

    for (final record in sorted) {
      if (record.action == 'member_removed') {
        final removed = record.memberUserIds
            .map(ChatIdFormat.rawUserUid)
            .where((item) => item.isNotEmpty)
            .toSet();
        activeAddsByKey.removeWhere(
          (_, added) => added.memberUserIds
              .map(ChatIdFormat.rawUserUid)
              .any(removed.contains),
        );
        // 同一脚踢人的多来源重复（本端注入/后端事件/推送）落库后按
        // 群+成员集合去重，操作人优先级同 member_added（真人 > 管理员）。
        final key = memberRemovedSemanticKey(
          record.groupId,
          record.memberUserIds,
        );
        final existing = activeRemovesByKey[key];
        if (existing == null) {
          activeRemovesByKey[key] = record;
          output.add(record);
          continue;
        }
        final existingIsAdmin = await _resolveOperatorIsAdminExecutor(
          record.groupId,
          existing.operatorUserId,
        );
        final incomingIsAdmin = await _resolveOperatorIsAdminExecutor(
          record.groupId,
          record.operatorUserId,
        );
        switch (decideMemberAddedDuplicate(
          existingOperatorIsAdmin: existingIsAdmin,
          incomingOperatorIsAdmin: incomingIsAdmin,
        )) {
          case MemberAddedDuplicateDecision.skipIncoming:
            continue;
          case MemberAddedDuplicateDecision.replaceExisting:
          case MemberAddedDuplicateDecision.publish:
            activeRemovesByKey[key] = record;
            output.remove(existing);
            output.add(record);
            continue;
        }
      }
      if (record.action != 'member_added') {
        output.add(record);
        continue;
      }

      // 成员重新入群：其后的踢出是新事件，结束这些成员的去重窗口。
      final added = record.memberUserIds
          .map(ChatIdFormat.rawUserUid)
          .where((item) => item.isNotEmpty)
          .toSet();
      activeRemovesByKey.removeWhere(
        (_, removedRecord) => removedRecord.memberUserIds
            .map(ChatIdFormat.rawUserUid)
            .any(added.contains),
      );

      final key = memberAddedSemanticKey(record.groupId, record.memberUserIds);
      final existing = activeAddsByKey[key];
      if (existing == null) {
        activeAddsByKey[key] = record;
        output.add(record);
        continue;
      }

      final existingIsAdmin = await _resolveOperatorIsAdminExecutor(
        record.groupId,
        existing.operatorUserId,
      );
      final incomingIsAdmin = await _resolveOperatorIsAdminExecutor(
        record.groupId,
        record.operatorUserId,
      );
      switch (decideMemberAddedDuplicate(
        existingOperatorIsAdmin: existingIsAdmin,
        incomingOperatorIsAdmin: incomingIsAdmin,
      )) {
        case MemberAddedDuplicateDecision.skipIncoming:
          continue;
        case MemberAddedDuplicateDecision.replaceExisting:
          activeAddsByKey[key] = record;
          output.remove(existing);
          output.add(record);
          continue;
        case MemberAddedDuplicateDecision.publish:
          activeAddsByKey[key] = record;
          output.add(record);
          continue;
      }
    }

    return output;
  }

  bool _sameMemberUserIds(List<String> left, List<String> right) {
    final normalizedLeft = left
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toList()
      ..sort();
    final normalizedRight = right
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toList()
      ..sort();
    if (normalizedLeft.length != normalizedRight.length) {
      return false;
    }
    for (var index = 0; index < normalizedLeft.length; index++) {
      if (normalizedLeft[index] != normalizedRight[index]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _removeRecordAndTip(String groupId, String recordId) async {
    final records = await _readRecords(groupId);
    final next = records.where((item) => item.id != recordId).toList();
    if (next.length == records.length) {
      return;
    }
    await _writeRecords(groupId, next);
    _removeTipsFromActiveChat(
      groupId,
      (message) {
        final tipId = _tipId(message);
        return tipId != null && tipId == recordId;
      },
    );
  }
}

class _MemberRemovalDedupEntry {
  const _MemberRemovalDedupEntry({
    required this.action,
    required this.at,
  });

  final String action;
  final DateTime at;
}

class GroupLocalTipsRecord {
  const GroupLocalTipsRecord({
    required this.id,
    required this.groupId,
    required this.action,
    required this.operatorUserId,
    required this.memberUserIds,
    required this.timestampSec,
    this.timelineRank,
    this.changeEventId,
    this.contentKey,
  });

  final String id;
  final String groupId;
  final String action;
  final String operatorUserId;
  final List<String> memberUserIds;
  final int timestampSec;
  final int? timelineRank;
  final String? changeEventId;
  final String? contentKey;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'groupId': groupId,
        'action': action,
        'operatorUserId': operatorUserId,
        'memberUserIds': memberUserIds,
        'timestampSec': timestampSec,
        if (timelineRank != null) 'timelineRank': timelineRank,
        if (changeEventId != null && changeEventId!.isNotEmpty)
          'changeEventId': changeEventId,
        if (contentKey != null && contentKey!.isNotEmpty)
          'contentKey': contentKey,
      };

  factory GroupLocalTipsRecord.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['memberUserIds'];
    final members = membersRaw is List
        ? membersRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    final recordId = json['id']?.toString() ?? '';
    var groupId = json['groupId']?.toString().trim() ?? '';
    if (groupId.isEmpty && recordId.startsWith('local_gt_')) {
      final rest = recordId.substring('local_gt_'.length);
      final splitAt = rest.indexOf('_');
      if (splitAt > 0) {
        groupId = rest.substring(0, splitAt);
      }
    }
    return GroupLocalTipsRecord(
      id: recordId,
      groupId: groupId,
      action: json['action']?.toString() ?? '',
      operatorUserId: json['operatorUserId']?.toString() ?? '',
      memberUserIds: members,
      timestampSec: (json['timestampSec'] as num?)?.toInt() ?? 0,
      timelineRank: (json['timelineRank'] as num?)?.toInt(),
      changeEventId: json['changeEventId']?.toString(),
      contentKey: json['contentKey']?.toString(),
    );
  }
}
