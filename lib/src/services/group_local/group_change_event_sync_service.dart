import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_change_event_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_change_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 登录 / 开群 / TCP 资料同步后，通过 REST change-events 对齐 cursor 并触发 IM 历史补拉。
/// 聊天灰字由 App Custom；本服务不写 tip prefs、不 patch 消息列表。
class GroupChangeEventSyncService {
  GroupChangeEventSyncService._();

  static final GroupChangeEventSyncService instance =
      GroupChangeEventSyncService._();

  static const _groupCursorPrefix = 'group_change_event_since_';
  static const _myCursorPrefix = 'group_change_event_my_since_';
  static const _memberActions = <String>[
    'member_added',
    'member_removed',
    'member_left',
  ];
  static const _matchWindowSec = 120;

  static void _log(String message) {
    // Verbose sync tracing disabled.
  }

  String _ownerUserId() {
    return ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
  }

  String _groupCursorKey(String ownerUserId, String groupId) {
    return '$_groupCursorPrefix${ownerUserId}_$groupId';
  }

  String _myCursorKey(String ownerUserId) => '$_myCursorPrefix$ownerUserId';

  Future<int> _readGroupCursor(String ownerUserId, String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_groupCursorKey(ownerUserId, groupId)) ?? 0;
  }

  Future<void> _writeGroupCursor(
    String ownerUserId,
    String groupId,
    int since,
  ) async {
    if (since <= 0) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_groupCursorKey(ownerUserId, groupId), since);
  }

  Future<void> _mergeGroupCursor(
    String ownerUserId,
    String groupId,
    int occurredAt,
  ) async {
    if (occurredAt <= 0) {
      return;
    }
    final current = await _readGroupCursor(ownerUserId, groupId);
    if (occurredAt > current) {
      await _writeGroupCursor(ownerUserId, groupId, occurredAt);
    }
  }

  Future<int> _readMyCursor(String ownerUserId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_myCursorKey(ownerUserId)) ?? 0;
  }

  Future<void> _writeMyCursor(String ownerUserId, int since) async {
    if (since <= 0) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_myCursorKey(ownerUserId), since);
  }

  /// 清空聊天记录后推进 cursor，避免旧 change-events 再被当成新事件回放。
  Future<void> markHistoryCleared(String groupId) async {
    final owner = _ownerUserId();
    final id = ChatIdFormat.canonicalGroupStorageId(groupId);
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _mergeGroupCursor(owner, id, nowMs);
  }

  void _requestImHistoryRefresh(String groupId, {String? reason}) {
    final conversationId = MessageConversationId.resolve(groupID: groupId);
    if (conversationId == null || conversationId.isEmpty) {
      return;
    }
    ChatHistoryRefreshBus.instance.requestRefresh(
      conversationId: conversationId,
      reason: reason ?? 'group_change_event_sync',
      delay: const Duration(milliseconds: 300),
    );
  }

  /// 打开群聊 / 成员变动 TCP 后，按群补拉 change-events。
  Future<void> syncForGroup(
    String groupId, {
    String reason = 'manual',
  }) async {
    if (!SelfHostedGroupBridge.enabled) {
      return;
    }
    final owner = _ownerUserId();
    final id = ChatIdFormat.canonicalGroupStorageId(groupId);
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    var since = await _readGroupCursor(owner, id);
    final requestSince = since;
    final fetchedEvents = <GroupChangeEvent>[];
    var pageNextSince = since;
    try {
      while (true) {
        final page = await GroupChangeEventApi.instance.fetchGroupEvents(
          groupId: id,
          since: since,
          actions: _memberActions,
        );
        if (page.items.isEmpty) {
          pageNextSince = page.nextSince > 0 ? page.nextSince : since;
          break;
        }
        fetchedEvents.addAll(page.items);
        since = page.nextSince;
        pageNextSince = page.nextSince;
        if (!page.hasMore) {
          break;
        }
      }
    } catch (e) {
      _log('syncForGroup failed groupId=$id reason=$reason error=$e');
      return;
    }

    // tip patch 已弃用：不再 applyFromChangeEvent / applyPatchesForVisibleGroup。

    final needsHistoryRefresh = _needsImHistoryRefresh(id, fetchedEvents);
    if (needsHistoryRefresh) {
      _log('syncForGroup refresh groupId=$id reason=$reason since=$pageNextSince');
      _requestImHistoryRefresh(id, reason: reason);
    }

    // v2.1：IM 补拉请求发出后再持久化 cursor，避免失败丢页。
    if (pageNextSince > requestSince) {
      await _writeGroupCursor(owner, id, pageNextSince);
    }
  }

  /// 登录 / syncFull 后批量补拉当前用户所有群的变动。
  Future<void> syncMyEvents({String reason = 'bootstrap'}) async {
    if (!SelfHostedGroupBridge.enabled) {
      return;
    }
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return;
    }
    var since = await _readMyCursor(owner);
    final requestSince = since;
    final refreshedGroups = <String>{};
    final fetchedEvents = <GroupChangeEvent>[];
    var pageNextSince = since;
    try {
      while (true) {
        final page = await GroupChangeEventApi.instance.fetchMyEvents(
          since: since,
          actions: _memberActions,
        );
        if (page.items.isEmpty) {
          pageNextSince = page.nextSince > 0 ? page.nextSince : since;
          break;
        }
        fetchedEvents.addAll(page.items);
        since = page.nextSince;
        pageNextSince = page.nextSince;
        for (final event in page.items) {
          final groupId = ChatIdFormat.canonicalGroupStorageId(event.groupId);
          if (groupId.isEmpty) {
            continue;
          }
          refreshedGroups.add(groupId);
        }
        if (!page.hasMore) {
          break;
        }
      }
    } catch (e) {
      _log('syncMyEvents failed reason=$reason error=$e');
      return;
    }

    // tip patch 已弃用：不再 applyFromChangeEvent。

    if (refreshedGroups.isEmpty) {
      if (pageNextSince > requestSince) {
        await _writeMyCursor(owner, pageNextSince);
      }
      return;
    }

    _log(
      'syncMyEvents refresh count=${refreshedGroups.length} reason=$reason',
    );
    for (final groupId in refreshedGroups) {
      final groupEvents = fetchedEvents
          .where(
            (event) =>
                ChatIdFormat.canonicalGroupStorageId(event.groupId) == groupId,
          )
          .toList(growable: false);
      if (_needsImHistoryRefresh(groupId, groupEvents)) {
        _requestImHistoryRefresh(groupId, reason: reason);
      }
    }

    if (pageNextSince > requestSince) {
      await _writeMyCursor(owner, pageNextSince);
    }
    for (final event in fetchedEvents) {
      final groupId = ChatIdFormat.canonicalGroupStorageId(event.groupId);
      if (groupId.isEmpty) {
        continue;
      }
      await _mergeGroupCursor(owner, groupId, event.occurredAt);
    }
  }

  bool _needsImHistoryRefresh(
    String groupId,
    List<GroupChangeEvent> events,
  ) {
    if (events.isEmpty) {
      return false;
    }
    final messages = _visibleMessages(groupId);
    for (final event in events) {
      if (!_hasMatchingGroupTip(messages, event)) {
        return true;
      }
    }
    return false;
  }

  List<V2TimMessage> _visibleMessages(String groupId) {
    try {
      final globalModel = serviceLocator<TUIChatGlobalModel>();
      final keys = <String>{
        'group_$groupId',
        groupId,
      };
      final out = <V2TimMessage>[];
      for (final key in keys) {
        final list = globalModel.messageListMap[key];
        if (list == null || list.isEmpty) {
          continue;
        }
        out.addAll(list);
      }
      return out;
    } catch (_) {
      return const <V2TimMessage>[];
    }
  }

  bool _hasMatchingGroupTip(
    List<V2TimMessage> messages,
    GroupChangeEvent event,
  ) {
    final expectedAction = event.action.trim().toLowerCase();
    if (expectedAction.isEmpty) {
      return false;
    }
    final seq = event.imMsgSeq;
    final eventSec = event.occurredAt > 0
        ? (event.occurredAt >= 1000000000000
            ? event.occurredAt ~/ 1000
            : event.occurredAt)
        : (event.imMsgTime ?? 0);
    for (final message in messages) {
      if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS) {
        continue;
      }
      if (GroupTipsMessageHelper.isLocalGroupTips(message)) {
        continue;
      }
      final tipAction = GroupTipsMessageHelper.actionForTipsType(
        message.groupTipsElem?.type,
      );
      if (tipAction != expectedAction) {
        continue;
      }
      if (seq != null && seq > 0) {
        final messageSeq = int.tryParse(message.seq?.trim() ?? '');
        if (messageSeq != null && messageSeq == seq) {
          return true;
        }
      }
      if (eventSec <= 0) {
        return true;
      }
      final tipSec = message.timestamp ?? 0;
      final normalizedTipSec = tipSec >= 1000000000000 ? tipSec ~/ 1000 : tipSec;
      if (normalizedTipSec > 0 &&
          (normalizedTipSec - eventSec).abs() <= _matchWindowSec) {
        return true;
      }
    }
    return false;
  }
}
