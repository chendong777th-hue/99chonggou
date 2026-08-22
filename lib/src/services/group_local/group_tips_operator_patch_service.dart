import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_change_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_change_event_metadata.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tips_operator_live_cache.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tips_operator_patch_metadata.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tips_preview_builder.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// TCP / change-events tip patch 已弃用。
/// 聊天灰字由 App `group_tip` Custom；本服务仅保留 clearHistory / decorate 过滤空壳。
class GroupTipsOperatorPatchService {
  GroupTipsOperatorPatchService._();

  static final GroupTipsOperatorPatchService instance =
      GroupTipsOperatorPatchService._();

  static const _prefsPrefix = 'group_tips_operator_patch_v1_';
  static const _maxRecordsPerGroup = 200;
  static const _matchWindowSec = 120;

  static const Set<String> _memberActions = <String>{
    'member_added',
    'member_removed',
    'member_left',
  };

  final Set<String> _processedChangeEventIds = <String>{};
  final Map<String, Timer> _retryTimers = <String, Timer>{};

  Future<void> applyFromNotice(GroupChangedNotice notice) async {
    // 聊天灰字已改 App sendMessage；TCP tip patch 完全弃用（不写 prefs、不改消息列表）。
    return;
  }

  Future<void> applyFromChangeEvent(GroupChangeEvent event) async {
    // 同上：change-events 不再驱动 tip patch。
    return;
  }

  Future<void> applyPatchesForVisibleGroup(String groupId) async {
    // 同上：打开群聊不再回放 tip patch。
    return;
  }

  /// 清空聊天记录后：删除本地操作者补丁，避免回放时重新注入灰字。
  Future<void> clearHistoryForGroup(String groupId) async {
    final id = _normalizeGroupId(groupId);
    if (id.isEmpty) {
      return;
    }
    final keys = _retryTimers.keys
        .where((key) => key.startsWith('$id|') || key.contains('|$id|'))
        .toList(growable: false);
    for (final key in keys) {
      _retryTimers.remove(key)?.cancel();
    }
    final scope = ContactSocialCacheStore.accountScope();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefsPrefix${scope}_$id');
    GroupTipsOperatorLiveCache.instance.clearGroup(id);
  }

  /// 会话列表等场景：仅从本地记录预热 live cache，不触发 IM 补丁。
  Future<void> warmLiveCacheForGroup(String groupId) async {
    // tip patch 弃用后不再从 prefs 预热 live cache。
    return;
  }

  Future<List<V2TimMessage>> decorateMessageList({
    required String groupId,
    required List<V2TimMessage> messages,
  }) async {
    if (!SelfHostedGroupBridge.enabled || messages.isEmpty) {
      return messages;
    }
    // 不再 merge 本地 tip / 应用 operator patch，只做展示侧过滤。
    return GroupTipsMessageHelper.applyPostMergeFilters(messages);
  }

  Future<void> _applyRecord(
    _OperatorPatchRecord record, {
    required String reason,
  }) async {
    final changeEventId = record.changeEventId.trim();
    final alreadyHandled = changeEventId.isNotEmpty &&
        _hasProcessedChangeEvent(changeEventId);
    final resolved = _withResolvedOperator(record);
    final groupId = _normalizeGroupId(resolved.groupId);
    if (groupId.isEmpty || !_memberActions.contains(resolved.action)) {
      return;
    }
    final operator = ChatIdFormat.rawUserUid(resolved.operatorUserId);
    if (operator.isEmpty && resolved.action != 'member_left') {
      return;
    }

    await _persistRecord(groupId, resolved);

    final preview = await GroupTipsPreviewBuilder.build(
      groupId: groupId,
      action: resolved.action,
      operatorUserId: operator.isNotEmpty
          ? operator
          : (resolved.memberUserIds.isNotEmpty
              ? resolved.memberUserIds.first
              : ''),
      memberUserIds: resolved.memberUserIds,
    );

    _upsertLiveEntry(resolved, preview);

    final patched = await _patchVisibleMessages(
      groupId: groupId,
      record: resolved,
      previewAbstract: preview,
    );
    if (changeEventId.isNotEmpty) {
      _markChangeEventProcessed(changeEventId);
    }
    if (patched || alreadyHandled) {
      return;
    }

    _scheduleRetry(
      groupId: groupId,
      record: resolved,
      previewAbstract: preview,
      reason: reason,
    );
  }

  void _upsertLiveEntry(
    _OperatorPatchRecord record,
    String previewAbstract,
  ) {
    final preview = previewAbstract.trim();
    if (preview.isEmpty) {
      return;
    }
    GroupTipsOperatorLiveCache.instance.upsert(
      GroupTipsOperatorLiveEntry(
        changeEventId: record.changeEventId,
        groupId: record.groupId,
        action: record.action,
        operatorUserId: ChatIdFormat.rawUserUid(record.operatorUserId),
        memberUserIds: record.memberUserIds,
        occurredAtSec: record.occurredAtSec,
        previewAbstract: preview,
        imMsgSeq: record.imMsgSeq,
      ),
    );
  }

  _OperatorPatchRecord _withResolvedOperator(_OperatorPatchRecord record) {
    var operator = ChatIdFormat.rawUserUid(record.operatorUserId);
    if (operator.isEmpty && record.action != 'member_left') {
      operator = ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
    }
    if (operator == record.operatorUserId) {
      return record;
    }
    return _OperatorPatchRecord(
      changeEventId: record.changeEventId,
      groupId: record.groupId,
      action: record.action,
      operatorUserId: operator,
      memberUserIds: record.memberUserIds,
      occurredAtMs: record.occurredAtMs,
      timelineRank: record.timelineRank,
      imMsgSeq: record.imMsgSeq,
    );
  }

  Future<bool> _patchVisibleMessages({
    required String groupId,
    required _OperatorPatchRecord record,
    required String previewAbstract,
  }) async {
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    var patchedAny = false;
    for (final key in _messageListKeys(groupId)) {
      final current = globalModel.messageListMap[key];
      if (current == null || current.isEmpty) {
        continue;
      }
      final next = await _patchMessageList(
        List<V2TimMessage>.from(current),
        record,
        previewAbstract: previewAbstract,
      );
      final filtered = GroupTipsMessageHelper.applyPostMergeFilters(next);
      if (!GroupTipsMessageHelper.messageListsSharePatchState(
        current,
        filtered,
      )) {
        globalModel.setMessageList(
          key,
          filtered,
          needResetNewMessageCount: false,
          replace: true,
        );
        patchedAny = true;
      }
    }
    return patchedAny;
  }

  Future<void> _decorateVisibleMessageList(String groupId) async {
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    for (final key in _messageListKeys(groupId)) {
      final current = globalModel.messageListMap[key];
      if (current == null || current.isEmpty) {
        continue;
      }
      // 无真实消息时不 decorate，避免 mergeIntoHistoricalList 把 tip 铺满空会话。
      final hasRealMessages = current.any((message) {
        final raw = message.localCustomData?.trim() ?? '';
        if (raw.contains('"localGroupTips"')) {
          return false;
        }
        final msgID = message.msgID?.trim() ?? '';
        if (msgID.startsWith('ce_') ||
            msgID.startsWith('local_gt_') ||
            msgID.startsWith('local_')) {
          return false;
        }
        return true;
      });
      if (!hasRealMessages) {
        continue;
      }
      final decorated = await decorateMessageList(
        groupId: groupId,
        messages: List<V2TimMessage>.from(current.reversed),
      );
      final newestFirst =
          TUIChatGlobalModel.sortMessagesNewestFirst(decorated);
      if (GroupTipsMessageHelper.messageListsSharePatchState(
        current,
        newestFirst,
      )) {
        continue;
      }
      globalModel.setMessageList(
        key,
        newestFirst,
        needResetNewMessageCount: false,
        replace: true,
      );
    }
  }

  Future<List<V2TimMessage>> _patchMessageList(
    List<V2TimMessage> messages,
    _OperatorPatchRecord record, {
    String? previewAbstract,
    bool persistCache = true,
  }) async {
    final preview = previewAbstract ??
        await GroupTipsPreviewBuilder.build(
          groupId: record.groupId,
          action: record.action,
          operatorUserId: record.operatorUserId,
          memberUserIds: record.memberUserIds,
        );
    final operator = ChatIdFormat.rawUserUid(record.operatorUserId);
    var patchedAny = false;
    final next = messages.map((message) {
      if (!_matchesImAdministratorTip(message, record)) {
        return message;
      }
      patchedAny = true;
      return _copyMessageWithPatch(
        message,
        record: record,
        operatorUserId: operator,
        previewAbstract: preview,
      );
    }).toList(growable: false);

    if (!patchedAny) {
      return messages;
    }
    if (persistCache) {
      await _persistRecord(record.groupId, record);
    }
    return next;
  }

  bool _matchesImAdministratorTip(
    V2TimMessage message,
    _OperatorPatchRecord record,
  ) {
    if (!GroupTipsMessageHelper.isGroupTipsMessage(message)) {
      return false;
    }
    if (GroupTipsMessageHelper.isLocalGroupTips(message)) {
      return false;
    }
    if (GroupTipsMessageHelper.isSuppressedAdministratorTip(message)) {
      return false;
    }
    final existingPatchId =
        GroupTipsMessageHelper.operatorPatchChangeEventId(message);
    if (existingPatchId != null &&
        existingPatchId == record.changeEventId &&
        record.changeEventId.isNotEmpty) {
      return true;
    }
    if (!GroupTipsMessageHelper.isImAdministratorMemberTip(message)) {
      return false;
    }
    final tips = message.groupTipsElem!;
    final action = GroupTipsMessageHelper.actionForTipsType(tips.type);
    if (action != record.action) {
      return false;
    }
    final tipMembers = GroupTipsMessageHelper.memberUserIdsFromTips(tips);
    if (!_sameMemberSet(tipMembers, record.memberUserIds)) {
      return false;
    }
    if (record.imMsgSeq != null && record.imMsgSeq! > 0) {
      final seq = _messageSeq(message);
      if (seq != null && seq == record.imMsgSeq) {
        return true;
      }
    }
    final tipSec = _messageTimestampSec(message);
    final eventSec = record.occurredAtSec;
    if (tipSec <= 0 || eventSec <= 0) {
      return true;
    }
    return (tipSec - eventSec).abs() <= _matchWindowSec;
  }

  V2TimMessage _copyMessageWithPatch(
    V2TimMessage message, {
    required _OperatorPatchRecord record,
    required String operatorUserId,
    required String previewAbstract,
  }) {
    final patched = V2TimMessage.fromJson(message.toJson());
    patched.localCustomData = GroupTipsOperatorPatchMetadata.mergePatch(
      existingRaw: message.localCustomData,
      changeEventId: record.changeEventId,
      resolvedOperatorUserId: operatorUserId,
      previewAbstract: previewAbstract,
      action: record.action,
      timelineRank: record.timelineRank,
    );
    return patched;
  }

  void _scheduleRetry({
    required String groupId,
    required _OperatorPatchRecord record,
    required String previewAbstract,
    required String reason,
  }) {
    final key = record.changeEventId.isNotEmpty
        ? record.changeEventId
        : '${record.groupId}|${record.action}|${record.memberUserIds.join(',')}';
    _retryTimers.remove(key)?.cancel();
    var attempts = 0;
    void schedule() {
      _retryTimers[key] = Timer(const Duration(milliseconds: 600), () async {
        attempts++;
        final patched = await _patchVisibleMessages(
          groupId: groupId,
          record: record,
          previewAbstract: previewAbstract,
        );
        if (patched) {
          _retryTimers.remove(key)?.cancel();
          return;
        }
        if (attempts < 4) {
          schedule();
          return;
        }
        _retryTimers.remove(key)?.cancel();
        // v2.1：禁止 fallback 本地假 tip；仅依赖 IM GroupTips。
      });
    }

    schedule();
  }

  Future<void> _persistRecord(
    String groupId,
    _OperatorPatchRecord record,
  ) async {
    final id = _normalizeGroupId(groupId);
    final existing = await _readRecords(id);
    final next = <_OperatorPatchRecord>[
      ...existing.where((item) => item.changeEventId != record.changeEventId),
      record,
    ];
    if (next.length > _maxRecordsPerGroup) {
      next.removeRange(0, next.length - _maxRecordsPerGroup);
    }
    final scope = ContactSocialCacheStore.accountScope();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefsPrefix${scope}_$id',
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<_OperatorPatchRecord>> _readRecords(String groupId) async {
    final scope = ContactSocialCacheStore.accountScope();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefsPrefix${scope}_$groupId');
    if (raw == null || raw.isEmpty) {
      return const <_OperatorPatchRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <_OperatorPatchRecord>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => _OperatorPatchRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.changeEventId.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <_OperatorPatchRecord>[];
    }
  }

  bool _hasProcessedChangeEvent(String changeEventId) {
    return _processedChangeEventIds.contains(changeEventId.trim());
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

  bool _sameMemberSet(List<String> left, List<String> right) {
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

  /// 补丁是否改变列表：只比 msgID + localCustomData。
  ///
  /// 切勿调用 [GroupTipsMessageHelper.messagePreviewAbstract]——它会对每条
  /// 消息做 jsonDecode / tip 文案解析，长列表会在主 isolate 卡死数秒
  /// （见 UIKit-runloop hang：GroupTipsOperatorPatchService._sameTipPatches）。
  int? _messageSeq(V2TimMessage message) {
    return int.tryParse(message.seq?.toString() ?? '');
  }

  int _messageTimestampSec(V2TimMessage message) {
    final ts = message.timestamp ?? 0;
    if (ts <= 0) {
      return 0;
    }
    if (ts >= 1000000000000) {
      return ts ~/ 1000;
    }
    return ts;
  }

  Iterable<String> _messageListKeys(String groupId) sync* {
    final raw = _normalizeGroupId(groupId);
    if (raw.isEmpty) {
      return;
    }
    yield raw;
    yield 'group_$raw';
  }

  String _normalizeGroupId(String groupId) {
    return ChatIdFormat.canonicalGroupStorageId(groupId);
  }
}

class _OperatorPatchRecord {
  const _OperatorPatchRecord({
    required this.changeEventId,
    required this.groupId,
    required this.action,
    required this.operatorUserId,
    required this.memberUserIds,
    required this.occurredAtMs,
    this.timelineRank,
    this.imMsgSeq,
  });

  final String changeEventId;
  final String groupId;
  final String action;
  final String operatorUserId;
  final List<String> memberUserIds;
  final int occurredAtMs;
  final int? timelineRank;
  final int? imMsgSeq;

  int get occurredAtSec =>
      GroupChangeEventMetadata.normalizeEventTimestampSec(occurredAtMs);

  factory _OperatorPatchRecord.fromNotice(GroupChangedNotice notice) {
    var operatorUserId = ChatIdFormat.rawUserUid(notice.operatorUserId ?? '');
    final action = notice.action.trim().toLowerCase();
    if (operatorUserId.isEmpty && action != 'member_left') {
      operatorUserId =
          ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
    }
    return _OperatorPatchRecord(
      changeEventId: notice.changeEventId?.trim() ?? '',
      groupId: notice.groupId,
      action: action,
      operatorUserId: operatorUserId,
      memberUserIds: notice.memberUserIds
          .map(ChatIdFormat.rawUserUid)
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      occurredAtMs: notice.occurredAtMs ?? notice.pushTs ?? 0,
      timelineRank: notice.timelineRank,
    );
  }

  factory _OperatorPatchRecord.fromChangeEvent(GroupChangeEvent event) {
    final imMsgSeq = _readInt(
      event.detail['imMsgSeq'] ?? event.detail['im_msg_seq'],
    );
    return _OperatorPatchRecord(
      changeEventId: event.changeEventId,
      groupId: event.groupId,
      action: event.action,
      operatorUserId: event.operatorUserId,
      memberUserIds: event.memberUserIds,
      occurredAtMs: event.occurredAt,
      timelineRank: event.timelineRank,
      imMsgSeq: imMsgSeq,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'changeEventId': changeEventId,
        'groupId': groupId,
        'action': action,
        'operatorUserId': operatorUserId,
        'memberUserIds': memberUserIds,
        'occurredAtMs': occurredAtMs,
        if (timelineRank != null) 'timelineRank': timelineRank,
        if (imMsgSeq != null) 'imMsgSeq': imMsgSeq,
      };

  factory _OperatorPatchRecord.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['memberUserIds'];
    final members = membersRaw is List
        ? membersRaw.map((e) => ChatIdFormat.rawUserUid(e.toString())).toList()
        : const <String>[];
    return _OperatorPatchRecord(
      changeEventId: json['changeEventId']?.toString() ?? '',
      groupId: ChatIdFormat.canonicalGroupStorageId(
        json['groupId']?.toString() ?? '',
      ),
      action: json['action']?.toString().trim().toLowerCase() ?? '',
      operatorUserId:
          ChatIdFormat.rawUserUid(json['operatorUserId']?.toString() ?? ''),
      memberUserIds: members,
      occurredAtMs: (json['occurredAtMs'] as num?)?.toInt() ?? 0,
      timelineRank: (json['timelineRank'] as num?)?.toInt(),
      imMsgSeq: (json['imMsgSeq'] as num?)?.toInt(),
    );
  }
}

/// 判断两条消息列表的 tip 补丁状态是否一致（仅比 msgID + localCustomData）。
///
/// 供 [GroupTipsOperatorPatchService] 决定是否需要 `setMessageList`；刻意不做
/// preview 解析，避免长列表在主 isolate 上批量 jsonDecode。
bool groupTipsMessageListsSharePatchState(
  List<V2TimMessage> before,
  List<V2TimMessage> after,
) =>
    GroupTipsMessageHelper.messageListsSharePatchState(before, after);

int? _readInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString().trim());
}
