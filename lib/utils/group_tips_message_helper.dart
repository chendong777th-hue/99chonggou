import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tips_operator_live_cache.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tips_operator_patch_metadata.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tip_custom_message.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/red_packet_claim_notice_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_change_info_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_tips_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_report_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_report_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_tips_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_tips_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 群系统提示（GroupTips）消息识别与「本人操作」判定。
class GroupTipsMessageHelper {
  GroupTipsMessageHelper._();

  static bool isGroupTipsMessage(V2TimMessage message) {
    return message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS &&
        message.groupTipsElem != null;
  }

  static bool isGroupCreateCustomMessage(V2TimMessage message) {
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
      return false;
    }
    final raw = message.customElem?.data?.trim() ?? '';
    if (raw.isEmpty) {
      return false;
    }
    if (raw == 'group_create') {
      return true;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded['businessID']?.toString() == 'group_create';
      }
    } catch (_) {}
    return false;
  }

  static String? localGroupTipAction(V2TimMessage message) {
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['localGroupTips'] == true) {
        return decoded['action']?.toString();
      }
    } catch (_) {}
    return null;
  }

  /// 同秒多条提示时的展示顺序：建群 → 改资料 → 邀请 → 踢人/退群。
  static int timelineSortRank(V2TimMessage message) {
    if (isGroupCreateCustomMessage(message)) {
      return 10;
    }
    if (isGroupTipsMessage(message)) {
      final type = message.groupTipsElem?.type;
      if (type == GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_GROUP_INFO_CHANGE) {
        return 20;
      }
      if (type == GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE) {
        return 30;
      }
      if (type == GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_KICKED ||
          type == GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_QUIT) {
        return 40;
      }
    }
    final action = localGroupTipAction(message);
    switch (action) {
      case 'member_added':
        return 30;
      case 'member_removed':
      case 'member_left':
        return 40;
      default:
        break;
    }
    return 50;
  }

  static int compareTimeline(V2TimMessage left, V2TimMessage right) {
    final leftTs = left.timestamp ?? 0;
    final rightTs = right.timestamp ?? 0;
    if (leftTs != rightTs) {
      return rightTs.compareTo(leftTs);
    }
    return timelineSortRank(right).compareTo(timelineSortRank(left));
  }

  static bool isLocalGroupTips(V2TimMessage message) {
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

  static bool isRolePlaceholderNick(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed == '管理员' || trimmed == '管理員') {
      return true;
    }
    final lower = trimmed.toLowerCase();
    return lower == 'administrator' || lower == 'admin';
  }

  static String normalizeGroupOperatorDisplayName(String name) {
    if (isRolePlaceholderNick(name)) {
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

  static String? operatorPatchPreviewAbstract(V2TimMessage message) {
    final data =
        GroupTipsOperatorPatchMetadata.readMap(message.localCustomData);
    if (data == null || !GroupTipsOperatorPatchMetadata.isOperatorPatch(data)) {
      return null;
    }
    final preview = GroupTipsOperatorPatchMetadata.previewAbstract(data);
    if (preview == null || preview.isEmpty) {
      return null;
    }
    return normalizeGroupTipPreviewDisplay(preview);
  }

  static String? operatorPatchChangeEventId(V2TimMessage message) {
    final data =
        GroupTipsOperatorPatchMetadata.readMap(message.localCustomData);
    if (data == null) {
      return null;
    }
    return GroupTipsOperatorPatchMetadata.changeEventId(data);
  }

  static String? resolvedOperatorUserId(V2TimMessage message) {
    final data =
        GroupTipsOperatorPatchMetadata.readMap(message.localCustomData);
    if (data == null) {
      return null;
    }
    return GroupTipsOperatorPatchMetadata.resolvedOperatorUserId(data);
  }

  /// 已持久化补丁或内存 live cache 解析出的成员变动预览。
  static String? resolvedMemberTipPreview(V2TimMessage message) {
    final local = localPreviewAbstract(message);
    if (local != null && local.isNotEmpty) {
      return local;
    }
    return GroupTipsOperatorLiveCache.instance.previewForMessage(message);
  }

  /// 已持久化补丁或内存 live cache 解析出的真实操作者。
  static String? resolvedMemberTipOperatorUserId(V2TimMessage message) {
    final patched = resolvedOperatorUserId(message);
    if (patched != null && patched.isNotEmpty) {
      return patched;
    }
    return GroupTipsOperatorLiveCache.instance
        .operatorUserIdForMessage(message);
  }

  static bool isPendingAdministratorMemberTip(V2TimMessage message) {
    if (!isImAdministratorMemberTip(message)) {
      return false;
    }
    final resolved = resolvedMemberTipPreview(message);
    return resolved == null || resolved.isEmpty;
  }

  static bool isSuppressedAdministratorTip(V2TimMessage message) {
    final data =
        GroupTipsOperatorPatchMetadata.readMap(message.localCustomData);
    if (data == null) {
      return false;
    }
    return GroupTipsOperatorPatchMetadata.isSuppressed(data);
  }

  static bool isImAdministratorMemberTip(V2TimMessage message) {
    if (!isGroupTipsMessage(message) || isLocalGroupTips(message)) {
      return false;
    }
    final tips = message.groupTipsElem!;
    final action = actionForTipsType(tips.type);
    // 设/取消管理员走 _isImAdminRolePlaceholderTip，不进 pending/patch 语义。
    if (action == null ||
        action == 'member_set_admin' ||
        action == 'member_cancel_admin') {
      return false;
    }
    final opMember = tips.opMember;
    for (final value in [
      opMember.nameCard,
      opMember.nickName,
      opMember.userID,
    ]) {
      if (isRolePlaceholderNick(value)) {
        return true;
      }
    }
    return false;
  }

  static String? actionForTipsType(int? type) {
    switch (type) {
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE:
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_JOIN:
        return 'member_added';
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_KICKED:
        return 'member_removed';
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_QUIT:
        return 'member_left';
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN:
        return 'member_set_admin';
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN:
        return 'member_cancel_admin';
      default:
        return null;
    }
  }

  /// 已废弃的本地成员 tip（换轨 IM GroupTips 后不应再展示）。
  static bool isDeprecatedLocalMemberTip(V2TimMessage message) {
    if (!isLocalGroupTips(message)) {
      return false;
    }
    final action = localGroupTipAction(message);
    return action == 'member_added' ||
        action == 'member_removed' ||
        action == 'member_left' ||
        action == 'member_set_admin' ||
        action == 'member_cancel_admin';
  }

  /// 腾讯 IM 原生设/取消管理员 GroupTips（非本地假 tip、非 App Custom）。
  /// 展示只信 App→IMSDK 的 `group_tip` Custom。
  static bool isImNativeAdminRoleTip(V2TimMessage message) {
    if (!isGroupTipsMessage(message) || isLocalGroupTips(message)) {
      return false;
    }
    final type = message.groupTipsElem?.type;
    return type == GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN ||
        type == GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN;
  }

  static List<String> memberUserIdsFromTips(V2TimGroupTipsElem tips) {
    final action = actionForTipsType(tips.type);
    if (action == 'member_left') {
      final leaver = ChatIdFormat.rawUserUid(tips.opMember.userID);
      return leaver.isEmpty ? const <String>[] : <String>[leaver];
    }
    final members = <String>[];
    for (final member in tips.memberList ?? const []) {
      if (member == null) {
        continue;
      }
      final userId = ChatIdFormat.rawUserUid(member.userID);
      if (userId.isNotEmpty) {
        members.add(userId);
      }
    }
    return members;
  }

  static List<V2TimMessage> filterSuppressedAdministratorTips(
    List<V2TimMessage> messages,
  ) {
    return messages.where((message) {
      if (isSuppressedAdministratorTip(message)) {
        return false;
      }
      // 设/取消管理员：只展示 App→IMSDK Custom；藏 IM 原生与本地假 tip。
      if (isImNativeAdminRoleTip(message)) {
        return false;
      }
      if (isLocalGroupTips(message)) {
        final action = localGroupTipAction(message);
        if (action == 'member_set_admin' || action == 'member_cancel_admin') {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  /// 本地 tip 合并、操作者 patch 等路径的统一后置过滤。
  static List<V2TimMessage> applyPostMergeFilters(List<V2TimMessage> messages) {
    final withoutDeprecatedMemberLocal = messages
        .where((message) => !isDeprecatedLocalMemberTip(message))
        .toList(growable: false);
    return filterSuppressedGroupCreateDuplicates(
      filterSuppressedRedundantMemberTips(
        filterSdkTipsCoveredByGroupTipCustom(
          filterDuplicateRedPacketClaimNotices(
            filterSuppressedAdministratorTips(withoutDeprecatedMemberLocal),
          ),
        ),
      ),
    );
  }

  /// 同群已有 App `group_tip` Custom 时，隐藏同语义 SDK GroupTips，避免双份灰字。
  static List<V2TimMessage> filterSdkTipsCoveredByGroupTipCustom(
    List<V2TimMessage> messages,
  ) {
    final covered = <String>{};
    for (final message in messages) {
      if (!isGroupTipCustomMessage(message)) {
        continue;
      }
      final action = groupTipActionOf(message);
      if (action == null || action.isEmpty) {
        continue;
      }
      final groupId = _messageGroupId(message);
      if (groupId == null || groupId.isEmpty) {
        continue;
      }
      final members = groupTipMemberUserIds(
        parseGroupTipPayload(message.customElem) ?? const <String, dynamic>{},
      );
      for (final key in _groupTipCoverageKeys(groupId, action, members)) {
        covered.add(key);
      }
    }
    if (covered.isEmpty) {
      return messages;
    }
    return messages.where((message) {
      if (!isGroupTipsMessage(message) || isLocalGroupTips(message)) {
        return true;
      }
      final tips = message.groupTipsElem;
      if (tips == null) {
        return true;
      }
      final groupId = _messageGroupId(message);
      if (groupId == null || groupId.isEmpty) {
        return true;
      }
      final action =
          actionForTipsType(tips.type) ?? _actionForGenericTipsType(tips.type);
      if (action == null) {
        return true;
      }
      final keys = _groupTipCoverageKeys(
        groupId,
        action,
        memberUserIdsFromTips(tips),
      );
      for (final key in keys) {
        if (covered.contains(key)) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  static String? _actionForGenericTipsType(int? type) {
    switch (type) {
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_MEMBER_INFO_CHANGE:
        return 'member_info_change';
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_GROUP_INFO_CHANGE:
        return 'group_info_change';
      default:
        return null;
    }
  }

  static List<String> _groupTipCoverageKeys(
    String groupId,
    String action,
    List<String> memberUserIds,
  ) {
    final exact = _groupTipSemanticKey(groupId, action, memberUserIds);
    final keys = <String>[exact];
    if (action == 'member_muted' ||
        action == 'member_unmuted' ||
        action == 'member_info_change') {
      keys.add(
        _groupTipSemanticKey(groupId, 'member_info_change', memberUserIds),
      );
    }
    if (action == 'group_mute_all_on' ||
        action == 'group_mute_all_off' ||
        action == 'group_name_changed' ||
        action == 'group_avatar_changed' ||
        action == 'group_notice_changed' ||
        action == 'owner_changed' ||
        action == 'group_info_change') {
      keys.add(_groupTipSemanticKey(groupId, 'group_info_change', const []));
    }
    return keys;
  }

  static String _groupTipSemanticKey(
    String groupId,
    String action,
    List<String> memberUserIds,
  ) {
    final members = memberUserIds
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toList()
      ..sort();
    return '$groupId|$action|${members.join(',')}';
  }

  /// 同群同批成员的 `member_added` 语义键（SDK INVITE / JOIN / patch 后提示）。
  static String? memberAddedSemanticKey(V2TimMessage message) {
    final groupId = _messageGroupId(message);
    if (groupId == null || groupId.isEmpty) {
      return null;
    }
    // 本地成员 tip 已废弃，不再参与语义去重竞争。
    if (isLocalGroupTips(message)) {
      return null;
    }
    if (!isGroupTipsMessage(message)) {
      return null;
    }
    final tips = message.groupTipsElem;
    if (tips == null) {
      return null;
    }
    var action = actionForTipsType(tips.type);
    final patchData =
        GroupTipsOperatorPatchMetadata.readMap(message.localCustomData);
    if (patchData != null &&
        GroupTipsOperatorPatchMetadata.isOperatorPatch(patchData)) {
      action = patchData['action']?.toString() ?? action;
    }
    if (action != 'member_added') {
      return null;
    }
    return _memberTipSemanticKey(
      groupId,
      'member_added',
      memberUserIdsFromTips(tips),
    );
  }

  /// 同语义 `member_added` 只保留一条：patch 后 SDK > SDK INVITE/JOIN。
  static List<V2TimMessage> filterSuppressedRedundantMemberTips(
    List<V2TimMessage> messages,
  ) {
    if (messages.length < 2) {
      return messages;
    }
    final keyToWinner = <String, ({int index, int priority})>{};
    for (var index = 0; index < messages.length; index++) {
      final key = memberAddedSemanticKey(messages[index]);
      if (key == null) {
        continue;
      }
      final priority = _memberTipDisplayPriority(messages[index]);
      final current = keyToWinner[key];
      if (current == null || priority > current.priority) {
        keyToWinner[key] = (index: index, priority: priority);
      }
    }
    if (keyToWinner.isEmpty) {
      return messages;
    }
    final winnerIndices =
        keyToWinner.values.map((entry) => entry.index).toSet();
    final result = <V2TimMessage>[];
    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      final key = memberAddedSemanticKey(message);
      if (key == null || winnerIndices.contains(index)) {
        result.add(message);
      }
    }
    return result;
  }

  static int _memberTipDisplayPriority(V2TimMessage message) {
    if (_isOperatorPatchMemberAdded(message)) {
      return 4;
    }
    if (isGroupTipsMessage(message) && !isLocalGroupTips(message)) {
      if (resolvedMemberTipPreview(message) != null &&
          resolvedMemberTipPreview(message)!.isNotEmpty) {
        return 3;
      }
      if (actionForTipsType(message.groupTipsElem?.type) == 'member_added') {
        return 2;
      }
    }
    return 0;
  }

  /// 判断两条消息列表是否可视为展示等价（仅比 msgID + localCustomData）。
  ///
  /// 供 operator patch / 本地 tip 同步决定是否需要 `setMessageList`；不做 preview
  /// 解析，避免长列表在主 isolate 上批量 jsonDecode。
  static bool messageListsSharePatchState(
    List<V2TimMessage> before,
    List<V2TimMessage> after,
  ) {
    if (identical(before, after)) {
      return true;
    }
    if (before.length != after.length) {
      return false;
    }
    for (var index = 0; index < before.length; index++) {
      final left = before[index];
      final right = after[index];
      if (identical(left, right)) {
        continue;
      }
      if (left.msgID != right.msgID) {
        return false;
      }
      if ((left.localCustomData ?? '') != (right.localCustomData ?? '')) {
        return false;
      }
    }
    return true;
  }

  /// 同群已有「成员加入/建群」语义覆盖时，隐藏重复的 `group_create` custom。
  ///
  /// 覆盖来源：本地 member_added 灰字、SDK GroupTips INVITE、已 patch 的成员提示。
  /// 同群多条 `group_create` 仅保留列表中第一条，其余丢弃。
  static List<V2TimMessage> filterSuppressedGroupCreateDuplicates(
    List<V2TimMessage> messages,
  ) {
    final coveredGroups = _groupsWithCreateEventCoverage(messages);
    final keptGroupCreate = <String>{};
    final result = <V2TimMessage>[];
    for (final message in messages) {
      if (!isGroupCreateCustomMessage(message)) {
        result.add(message);
        continue;
      }
      final groupId = _messageGroupId(message);
      if (groupId == null || groupId.isEmpty) {
        result.add(message);
        continue;
      }
      if (coveredGroups.contains(groupId)) {
        continue;
      }
      if (keptGroupCreate.contains(groupId)) {
        continue;
      }
      keptGroupCreate.add(groupId);
      result.add(message);
    }
    return result;
  }

  /// 会话 lastMessage 为 `group_create` 且历史里已有等价建群/入群事件时，不再 merge。
  static bool isGroupCreateRedundantWithHistory(
    V2TimMessage preview,
    List<V2TimMessage> history,
  ) {
    if (!isGroupCreateCustomMessage(preview)) {
      return false;
    }
    final groupId = _messageGroupId(preview);
    if (groupId == null || groupId.isEmpty) {
      return false;
    }
    if (_groupsWithCreateEventCoverage(history).contains(groupId)) {
      return true;
    }
    for (final message in history) {
      if (!isGroupCreateCustomMessage(message)) {
        continue;
      }
      if (_messageGroupId(message) == groupId) {
        return true;
      }
    }
    return false;
  }

  /// 已有 SDK INVITE/JOIN 或 patch 后成员提示的群，视为建群事件已覆盖。
  static Set<String> _groupsWithCreateEventCoverage(
    List<V2TimMessage> messages,
  ) {
    final covered = <String>{};
    for (final message in messages) {
      final groupId = _messageGroupId(message);
      if (groupId == null || groupId.isEmpty) {
        continue;
      }
      if (isLocalGroupTips(message)) {
        continue;
      }
      if (isGroupTipsMessage(message)) {
        if (actionForTipsType(message.groupTipsElem?.type) == 'member_added' ||
            _isOperatorPatchMemberAdded(message)) {
          covered.add(groupId);
        }
      }
    }
    return covered;
  }

  static bool _isOperatorPatchMemberAdded(V2TimMessage message) {
    final data =
        GroupTipsOperatorPatchMetadata.readMap(message.localCustomData);
    if (data == null || !GroupTipsOperatorPatchMetadata.isOperatorPatch(data)) {
      return false;
    }
    return data['action']?.toString() == 'member_added';
  }

  static String? _messageGroupId(V2TimMessage message) {
    final raw =
        message.groupID?.trim() ?? message.groupTipsElem?.groupID.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    return ChatIdFormat.canonicalGroupStorageId(raw);
  }

  static String _memberTipSemanticKey(
    String groupId,
    String action,
    List<String> memberUserIds,
  ) {
    final members = memberUserIds
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toList()
      ..sort();
    return '${ChatIdFormat.canonicalGroupStorageId(groupId)}|$action|${members.join(',')}';
  }

  static String normalizeGroupTipPreviewDisplay(String preview) {
    final trimmed = preview.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final matched = RegExp(r'^(administrator|admin)', caseSensitive: false)
        .firstMatch(trimmed);
    if (matched == null) {
      return trimmed;
    }
    final placeholder = matched.group(0) ?? '';
    if (placeholder.isEmpty) {
      return trimmed;
    }
    return trimmed.replaceFirst(
      placeholder,
      normalizeGroupOperatorDisplayName(placeholder),
    );
  }

  static String? localPreviewAbstract(V2TimMessage message) {
    final patched = operatorPatchPreviewAbstract(message);
    if (patched != null && patched.isNotEmpty) {
      return patched;
    }
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['localGroupTips'] != true) {
        return null;
      }
      final preview = decoded['previewAbstract']?.toString().trim() ?? '';
      if (preview.isEmpty) {
        return null;
      }
      return normalizeGroupTipPreviewDisplay(preview);
    } catch (_) {
      return null;
    }
  }

  /// IM 同步覆盖本地库时，保留较新的自建群操作提示作为 lastMessage。
  static V2TimMessage? pickPreferredLastMessage({
    V2TimMessage? existing,
    V2TimMessage? incoming,
  }) {
    final existingOk =
        existing != null && !_shouldSkipAsConversationLastMessage(existing)
            ? existing
            : null;
    final incomingOk =
        incoming != null && !_shouldSkipAsConversationLastMessage(incoming)
            ? incoming
            : null;
    if (existingOk == null) {
      return incomingOk;
    }
    if (incomingOk == null) {
      return existingOk;
    }
    final existingTs = existingOk.timestamp ?? 0;
    final incomingTs = incomingOk.timestamp ?? 0;
    if (isLocalGroupTips(existingOk) && existingTs >= incomingTs) {
      return existingOk;
    }
    if (existingTs > incomingTs) {
      return existingOk;
    }
    if (incomingTs > existingTs) {
      return incomingOk;
    }
    if (isLocalGroupTips(existingOk)) {
      return existingOk;
    }
    // 同 timestamp：同 msgID 时优先终态 status（避免 SENDING 压住 SUCC）；
    // 撤回态必须压过未撤回，且不可被迟到 SUCC 打回。
    final existingId = existingOk.msgID?.trim() ?? '';
    final incomingId = incomingOk.msgID?.trim() ?? '';
    final existingSeq = int.tryParse(existingOk.seq?.trim() ?? '') ?? 0;
    final incomingSeq = int.tryParse(incomingOk.seq?.trim() ?? '') ?? 0;
    if (existingId != incomingId) {
      if (incomingOk.isSelf == true &&
          incomingOk.status == MessageStatus.V2TIM_MSG_STATUS_SENDING) {
        // 新发的本地消息尚无服务端 seq，但必须立即成为会话预览。
        return incomingOk;
      }
      if (existingSeq > 0 && incomingSeq > 0) {
        return incomingSeq > existingSeq ? incomingOk : existingOk;
      }
      if (incomingSeq > 0 && existingSeq <= 0) {
        return incomingOk;
      }
      if (existingSeq > 0 && incomingSeq <= 0) {
        return existingOk;
      }
      // 同秒且都没有服务端序号时无法证明 incoming 更新：保留当前预览，
      // 防止重连/SQLite/SDK 迟到回写把旧消息重新顶上来。
      return existingOk;
    }
    if (existingId.isNotEmpty &&
        incomingId.isNotEmpty &&
        existingId == incomingId) {
      final existingRevoked = isRevokedMessage(existingOk);
      final incomingRevoked = isRevokedMessage(incomingOk);
      if (incomingRevoked && !existingRevoked) {
        return incomingOk;
      }
      if (existingRevoked && !incomingRevoked) {
        return existingOk;
      }
      if (shouldPreferIncomingMessageStatus(
        existingStatus: existingOk.status,
        incomingStatus: incomingOk.status,
      )) {
        return incomingOk;
      }
      if (shouldPreferIncomingMessageStatus(
        existingStatus: incomingOk.status,
        incomingStatus: existingOk.status,
      )) {
        return existingOk;
      }
    }
    return incomingOk;
  }

  /// SENDING(0) < SEND_FAIL(1) < SEND_SUCC(2)；未知按中间档。
  @visibleForTesting
  static int messageStatusRank(int? status) {
    if (status == MessageStatus.V2TIM_MSG_STATUS_SENDING) {
      return 0;
    }
    if (status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL) {
      return 1;
    }
    if (status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC) {
      return 2;
    }
    return 1;
  }

  /// 入站 status 是否应覆盖现有（用于同 msgID 升级发送中箭头）。
  static bool shouldPreferIncomingMessageStatus({
    required int? existingStatus,
    required int? incomingStatus,
  }) {
    return messageStatusRank(incomingStatus) >
        messageStatusRank(existingStatus);
  }

  /// 同 msgID 预览是否应用入站消息（status 升级、撤回升级或已读标记变化）。
  static bool shouldUpgradeSameIdLastMessage({
    required V2TimMessage? existing,
    required V2TimMessage incoming,
  }) {
    if (existing == null) {
      return true;
    }
    final existingRevoked = isRevokedMessage(existing);
    final incomingRevoked = isRevokedMessage(incoming);
    if (incomingRevoked && !existingRevoked) {
      return true;
    }
    if (existingRevoked && !incomingRevoked) {
      return false;
    }
    if (shouldPreferIncomingMessageStatus(
      existingStatus: existing.status,
      incomingStatus: incoming.status,
    )) {
      return true;
    }
    final existingPeer = existing.isPeerRead == true;
    final incomingPeer = incoming.isPeerRead == true;
    return existingPeer != incomingPeer;
  }

  static bool _shouldSkipAsConversationLastMessage(V2TimMessage message) {
    if (isImNativeAdminRoleTip(message)) {
      return true;
    }
    if (isDeprecatedLocalMemberTip(message)) {
      return true;
    }
    return false;
  }

  static bool isSameUser(String? left, String? right) {
    final a = ChatIdFormat.rawUserUid(left);
    final b = ChatIdFormat.rawUserUid(right);
    return a.isNotEmpty && b.isNotEmpty && a == b;
  }

  /// 群管理类系统提示：不弹横幅、不增加未读（如改群资料、全员禁言、设/取消管理员）。
  static const Set<String> _silentGroupTipCustomActions = <String>{
    'member_set_admin',
    'member_cancel_admin',
    'group_name_changed',
    'group_avatar_changed',
    'group_notice_changed',
    'group_mute_all_on',
    'group_mute_all_off',
    'owner_changed',
    'group_apply_join_option_changed',
    'group_invite_join_option_changed',
    'group_qr_join_enabled',
    'group_qr_join_disabled',
    'group_alias_join_enabled',
    'group_alias_join_disabled',
    'group_privacy_enabled',
    'group_privacy_disabled',
  };

  static bool isSilentGroupTipMessage(V2TimMessage message) {
    if (isGroupTipCustomMessage(message)) {
      final action = groupTipActionOf(message);
      return action != null && _silentGroupTipCustomActions.contains(action);
    }
    if (!isGroupTipsMessage(message)) {
      return false;
    }
    final type = message.groupTipsElem?.type;
    if (type == GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN ||
        type == GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN) {
      return true;
    }
    if (type != GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_GROUP_INFO_CHANGE) {
      return false;
    }
    final changes = message.groupTipsElem?.groupChangeInfoList ?? [];
    for (final change in changes) {
      final changeType = change?.type;
      if (changeType ==
              GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_FACE_URL ||
          changeType == GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_NAME ||
          changeType ==
              GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_NOTIFICATION ||
          changeType ==
              GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_SHUT_UP_ALL) {
        return true;
      }
    }
    return false;
  }

  /// 不应计入会话未读：界面已隐藏的原生 GroupTips、静默 App tip、废弃本地成员 tip。
  /// （展示只信 App `group_tip` Custom；原生 tip 仍可能被 SDK 计入 unread。）
  static bool shouldSuppressConversationUnread(V2TimMessage message) {
    if (isSilentGroupTipMessage(message)) {
      return true;
    }
    if (isDeprecatedLocalMemberTip(message)) {
      return true;
    }
    // 全部原生 IM GroupTips（非本地假 tip）不涨未读。
    if (isGroupTipsMessage(message) && !isLocalGroupTips(message)) {
      return true;
    }
    return false;
  }

  /// 当前用户是群系统提示的操作者（邀请、踢人、改资料、建群等）。
  static bool isSelfOperated(V2TimMessage message, String? loginUserId) {
    final self = ChatIdFormat.rawUserUid(loginUserId);
    if (self.isEmpty) {
      return false;
    }
    if (isGroupTipCustomMessage(message)) {
      final map = parseGroupTipPayload(message.customElem);
      final opId = map?['opUserId']?.toString();
      return isSameUser(opId, self);
    }
    if (!isGroupTipsMessage(message)) {
      return false;
    }
    final opId = resolvedMemberTipOperatorUserId(message) ??
        message.groupTipsElem?.opMember.userID;
    return isSameUser(opId, self);
  }

  /// 当前用户出现在 INVITE / JOIN 的成员列表中（被拉进群或主动入群）。
  static bool isSelfInvitedOrJoined(V2TimMessage message, String? loginUserId) {
    final self = ChatIdFormat.rawUserUid(loginUserId);
    if (self.isEmpty || !isGroupTipsMessage(message)) {
      return false;
    }
    final tips = message.groupTipsElem;
    if (tips == null) {
      return false;
    }
    final type = tips.type;
    if (type != GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE &&
        type != GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_JOIN) {
      return false;
    }
    for (final member in tips.memberList ?? const []) {
      if (member == null) {
        continue;
      }
      if (isSameUser(member.userID, self)) {
        return true;
      }
    }
    return false;
  }

  static String? conversationId(V2TimMessage message) {
    final groupId =
        message.groupID?.trim() ?? message.groupTipsElem?.groupID.trim() ?? '';
    if (groupId.isEmpty) {
      return null;
    }
    return groupId.startsWith('group_') ? groupId : 'group_$groupId';
  }

  /// 通知/横幅等同步场景下的消息摘要（与会话列表 groupTips 文案对齐）。
  static String? messagePreviewAbstract(V2TimMessage message) {
    if (isDeprecatedLocalMemberTip(message)) {
      return null;
    }
    if (isImNativeAdminRoleTip(message)) {
      return null;
    }
    final resolved = resolvedMemberTipPreview(message);
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    if (isPendingAdministratorMemberTip(message)) {
      return '';
    }
    if (isGroupTipCustomMessage(message)) {
      final map = parseGroupTipPayload(message.customElem);
      if (map != null) {
        return groupTipDisplayText(map);
      }
    }
    if (isGroupTipsMessage(message)) {
      return _groupTipsSyncAbstract(
        message.groupTipsElem!,
        message: message,
      );
    }
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_REPORT &&
        message.groupReportElem != null) {
      return _groupReportSyncAbstract(message.groupReportElem!);
    }
    return null;
  }

  static String? _memberNick(V2TimGroupMemberInfo? member) {
    if (member == null) {
      return null;
    }
    for (final value in [
      member.friendRemark,
      member.nameCard,
      member.nickName,
      member.userID,
    ]) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty && !isRolePlaceholderNick(text)) {
        return text;
      }
    }
    return member.userID?.trim();
  }

  static String _groupChangeTypeSync(V2TimGroupChangeInfo info) {
    final type = info.type;
    final value = info.value?.trim() ?? '';
    switch (type) {
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_CUSTOM:
        return TIM_t('自定义字段');
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_FACE_URL:
        final label = TIM_t('群头像');
        if (value.startsWith('http://') || value.startsWith('https://')) {
          return TIM_t_para('{{option8}}为 ', '$label为 ')(option8: label);
        }
        return label;
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_INTRODUCTION:
        return TIM_t('群简介');
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_NAME:
        return TIM_t('群名称');
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_NOTIFICATION:
        return TIM_t('群公告');
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_OWNER:
        return TIM_t('群主');
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_SHUT_UP_ALL:
        return TIM_t('全员禁言状态');
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_RECEIVE_MESSAGE_OPT:
        return TIM_t('消息接收方式');
      default:
        return TIM_t('群资料信息');
    }
  }

  static String _groupTipsSyncAbstract(
    V2TimGroupTipsElem groupTipsElem, {
    V2TimMessage? message,
  }) {
    if (message != null) {
      final resolved = resolvedMemberTipPreview(message);
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
      if (isPendingAdministratorMemberTip(message)) {
        return '';
      }
    }
    final operationType = groupTipsElem.type;
    final operationMember = groupTipsElem.opMember;
    final memberList = groupTipsElem.memberList ?? const [];
    final opUserNickName = normalizeGroupOperatorDisplayName(
      _memberNick(operationMember) ?? '',
    );
    switch (operationType) {
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_GROUP_INFO_CHANGE:
        final groupChangeInfoList = groupTipsElem.groupChangeInfoList ?? [];
        var changedInfoString = '';
        var changedValue = false;
        for (final element in groupChangeInfoList) {
          if (element == null) {
            continue;
          }
          final newText = _groupChangeTypeSync(element);
          changedInfoString +=
              (changedInfoString.isEmpty ? '' : ' / ') + newText;
          changedValue = element.boolValue ?? false;
        }
        if (changedInfoString.isEmpty) {
          changedInfoString = TIM_t('群资料');
        }
        if (changedInfoString == TIM_t('全员禁言状态')) {
          changedInfoString = TIM_t('全员禁言');
          return changedValue == false
              ? TIM_t_para('{{option7}} 取消', '$opUserNickName 取消')(
                      option7: opUserNickName) +
                  changedInfoString
              : TIM_t_para('{{option7}} 开启', '$opUserNickName 开启')(
                      option7: opUserNickName) +
                  changedInfoString;
        }
        return TIM_t_para('{{option7}}修改', '$opUserNickName修改')(
                option7: opUserNickName) +
            changedInfoString;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_QUIT:
        return TIM_t_para('{{option6}}退出群聊', '$opUserNickName退出群聊')(
          option6: opUserNickName,
        );
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE:
        final invited = memberList
            .whereType<V2TimGroupMemberInfo>()
            .map(_memberNick)
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .join('、');
        return opUserNickName +
            TIM_t_para('邀请{{option5}}加入群组', '邀请$invited加入群组')(
              option5: invited,
            );
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_KICKED:
        final kicked = memberList
            .whereType<V2TimGroupMemberInfo>()
            .map(_memberNick)
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .join('、');
        return opUserNickName +
            TIM_t_para('将{{option4}}踢出群组', '将$kicked踢出群组')(option4: kicked);
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_JOIN:
        final joined = memberList
            .whereType<V2TimGroupMemberInfo>()
            .map(_memberNick)
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .join('、');
        return TIM_t_para('用户{{option3}}加入了群聊', '用户$joined加入了群聊')(
          option3: joined,
        );
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_MEMBER_INFO_CHANGE:
        return memberList.whereType<V2TimGroupMemberInfo>().map((member) {
          V2TimGroupMemberChangeInfo? changedMember;
          for (final item in groupTipsElem.memberChangeInfoList ?? const []) {
            if (item?.userID?.trim() == member.userID?.trim()) {
              changedMember = item;
              break;
            }
          }
          final isMute = (changedMember?.muteTime ?? 0) != 0;
          final option2 = _memberNick(member) ?? '';
          final action = isMute ? TIM_t('禁言') : TIM_t('解除禁言');
          return TIM_t_para('{{option2}} 被', '$option2 被')(option2: option2) +
              action;
        }).join('、');
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN:
        final adminMember = memberList
            .whereType<V2TimGroupMemberInfo>()
            .map(_memberNick)
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .join('、');
        return opUserNickName +
            TIM_t_para('将 {{option1}} 设置为管理员', '将 $adminMember 设置为管理员')(
              option1: adminMember,
            );
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN:
        final adminMember = memberList
            .whereType<V2TimGroupMemberInfo>()
            .map(_memberNick)
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .join('、');
        return opUserNickName +
            TIM_t_para('将 {{option1}} 取消管理员', '将 $adminMember 取消管理员')(
              option1: adminMember,
            );
      default:
        return TIM_t_para('系统消息 {{option2}}', '系统消息 $operationType')(
          option2: operationType.toString(),
        );
    }
  }

  static String _resolveReportOperatorName(V2TimGroupReportElem report) {
    for (final value in [
      report.opMemberInfo?.nameCard,
      report.opMemberInfo?.nickName,
      report.opUserInfo?.nickName,
      report.opUserID,
    ]) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty && !isRolePlaceholderNick(text)) {
        return normalizeGroupOperatorDisplayName(text);
      }
    }
    return report.opUserID?.trim() ?? '';
  }

  static String _groupReportSyncAbstract(V2TimGroupReportElem report) {
    final opName = _resolveReportOperatorName(report);
    final customData = report.customData?.trim() ?? '';
    switch (report.type) {
      case V2TimGroupReportElem.kTIMGroupReport_AddRequest:
        return opName.isEmpty
            ? TIM_t('[群系统通知] 收到加群申请')
            : TIM_t_para('{{option1}} 申请加入群组', '$opName 申请加入群组')(
                option1: opName,
              );
      case V2TimGroupReportElem.kTIMGroupReport_AddAccept:
        return TIM_t('你的加群申请已通过');
      case V2TimGroupReportElem.kTIMGroupReport_AddRefuse:
        return TIM_t('你的加群申请被拒绝');
      case V2TimGroupReportElem.kTIMGroupReport_BeKicked:
        return opName.isEmpty
            ? TIM_t('你已被移出群聊')
            : TIM_t_para('{{option1}} 将你移出群聊', '$opName 将你移出群聊')(
                option1: opName,
              );
      case V2TimGroupReportElem.kTIMGroupReport_Delete:
        return opName.isEmpty
            ? TIM_t('群聊已解散')
            : TIM_t_para('{{option1}} 解散了群聊', '$opName 解散了群聊')(
                option1: opName,
              );
      case V2TimGroupReportElem.kTIMGroupReport_Create:
        return TIM_t('群聊创建成功！');
      case V2TimGroupReportElem.kTIMGroupReport_Invite:
        return opName.isEmpty
            ? TIM_t('你已被邀请加入群聊')
            : TIM_t_para('{{option1}} 邀请你加入群聊', '$opName 邀请你加入群聊')(
                option1: opName,
              );
      case V2TimGroupReportElem.kTIMGroupReport_Quit:
        return TIM_t('你已退出群聊');
      case V2TimGroupReportElem.kTIMGroupReport_GrantAdmin:
        return TIM_t('你已被设置为管理员');
      case V2TimGroupReportElem.kTIMGroupReport_CancelAdmin:
        return TIM_t('你的管理员身份已被取消');
      case V2TimGroupReportElem.kTIMGroupReport_GroupRecycle:
        return TIM_t('群聊已被回收');
      case V2TimGroupReportElem.kTIMGroupReport_InviteReqToInvitee:
        return TIM_t('收到入群邀请');
      case V2TimGroupReportElem.kTIMGroupReport_InviteAccept:
        return TIM_t('你的入群邀请已被接受');
      case V2TimGroupReportElem.kTIMGroupReport_InviteRefuse:
        return TIM_t('你的入群邀请被拒绝');
      case V2TimGroupReportElem.kTIMGroupReport_UserDefine:
        if (customData.isNotEmpty) {
          return customData;
        }
        return TIM_t('[群系统通知]');
      case V2TimGroupReportElem.kTIMGroupReport_ShutUpMember:
        return TIM_t('你已被禁言');
      case V2TimGroupReportElem.kTIMGroupReport_BannedFromGroup:
        return TIM_t('你已被封禁');
      case V2TimGroupReportElem.kTIMGroupReport_UnbannedFromGroup:
        return TIM_t('你已被解封');
      case V2TimGroupReportElem.kTIMGroupReport_InviteReqToAdmin:
        return TIM_t('收到入群审批请求');
      default:
        return TIM_t('[群系统通知]');
    }
  }
}
