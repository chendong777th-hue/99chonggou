import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_aggregate.dart';
import 'package:tencent_cloud_chat_demo/src/utils/archive_conversation_lookup.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_unread_utils.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_c2c_show_name_prefer.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_last_message_prefer.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_sdk/enum/conversation_type.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation_filter.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_filter.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

/// 腾讯方案 Phase1/3：按 Tab 持有「已从 SDK 分页加载」的会话窗口（内存 Store）。
///
/// 真相源 = IM SDK 本地会话库；本 Store 不持久化。杀进程后重新 [ensurePrimed]。
/// Phase3：主列表窗口排除本地归档 id 集合；分组成员过滤仍在 UI 层（selected folder）。
class ConversationTabStore extends ChangeNotifier {
  ConversationTabStore._();

  static final ConversationTabStore instance = ConversationTabStore._();

  static const int defaultPageSize = 50;

  final Map<int, List<V2TimConversation>> _items = <int, List<V2TimConversation>>{
    ConversationType.V2TIM_C2C: <V2TimConversation>[],
    ConversationType.V2TIM_GROUP: <V2TimConversation>[],
  };
  final Map<int, String> _nextSeq = <int, String>{
    ConversationType.V2TIM_C2C: '0',
    ConversationType.V2TIM_GROUP: '0',
  };
  final Map<int, bool> _finished = <int, bool>{
    ConversationType.V2TIM_C2C: false,
    ConversationType.V2TIM_GROUP: false,
  };
  final Map<int, Future<void>?> _loadInFlight = <int, Future<void>?>{};

  /// 单测注入分页。
  @visibleForTesting
  static Future<
          ({
            List<V2TimConversation> conversationList,
            String nextSeq,
            bool isFinished,
            int code,
            String desc,
          })>
      Function({
    required int convType,
    required String nextSeq,
    required int count,
  })? debugFetchOverride;

  List<V2TimConversation> itemsForType(int convType) {
    final type = _normalizeType(convType);
    return List<V2TimConversation>.unmodifiable(
      _items[type] ?? const <V2TimConversation>[],
    );
  }

  int countForType(int convType) =>
      (_items[_normalizeType(convType)] ?? const <V2TimConversation>[]).length;

  bool finishedForType(int convType) =>
      _finished[_normalizeType(convType)] ?? false;

  String nextSeqForType(int convType) =>
      _nextSeq[_normalizeType(convType)] ?? '0';

  V2TimConversation? atTypeIndex(int convType, int index) {
    final list = _items[_normalizeType(convType)];
    if (list == null || index < 0 || index >= list.length) {
      return null;
    }
    return list[index];
  }

  int? typeIndexOf(int convType, String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return null;
    }
    final list = _items[_normalizeType(convType)];
    if (list == null) {
      return null;
    }
    for (var i = 0; i < list.length; i++) {
      if (MessageConversationId.sameConversation(list[i].conversationID, id)) {
        return i;
      }
    }
    return null;
  }

  /// 冷启 / Tab 首次：拉第一页（reset）。
  Future<void> ensurePrimed({int? convType, int count = defaultPageSize}) async {
    if (!ConversationPerfFlags.conversationListSdkPrimary) {
      return;
    }
    if (convType != null) {
      final type = _normalizeType(convType);
      if ((_items[type] ?? const []).isNotEmpty ||
          (_finished[type] == true)) {
        return;
      }
      await loadFirstPage(convType: type, count: count);
      return;
    }
    await Future.wait<void>([
      ensurePrimed(convType: ConversationType.V2TIM_C2C, count: count),
      ensurePrimed(convType: ConversationType.V2TIM_GROUP, count: count),
    ]);
  }

  Future<void> loadFirstPage({
    required int convType,
    int count = defaultPageSize,
  }) {
    final type = _normalizeType(convType);
    return _load(type: type, reset: true, count: count);
  }

  Future<void> loadMore({
    required int convType,
    int count = defaultPageSize,
  }) {
    final type = _normalizeType(convType);
    if (_finished[type] == true) {
      return Future<void>.value();
    }
    return _load(type: type, reset: false, count: count);
  }

  /// Listener / 发送预览：只改已加载窗内行；热消息可插入头部。
  void applyPatches(
    List<V2TimConversation> incoming, {
    String reason = 'patch',
    Set<String> forceAdmitIds = const <String>{},
  }) {
    if (incoming.isEmpty) {
      return;
    }
    var any = false;
    final dirtyTypes = <int>{};
    for (final raw in incoming) {
      final id = raw.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      ConversationLocalStore.decorateConversationForUi(raw);
      raw.isPinned =
          ConversationPinSyncService.instance.isPinnedConversationId(id);
      final type = _typeOf(raw);
      final list = List<V2TimConversation>.from(
        _items[type] ?? const <V2TimConversation>[],
      );
      final idx = list.indexWhere(
        (c) => MessageConversationId.sameConversation(c.conversationID, id),
      );
      if (_isArchivedConversation(raw)) {
        if (idx >= 0) {
          list.removeAt(idx);
          _items[type] = list;
          dirtyTypes.add(type);
          any = true;
        }
        continue;
      }
      if (idx >= 0) {
        final merged = mergePatchRow(existing: list[idx], incoming: raw);
        list[idx] = merged;
        _items[type] = list;
        dirtyTypes.add(type);
        any = true;
        continue;
      }
      // 未在已加载窗：仅热会话（置顶/未读/比窗头更新）插入，避免冷会话撑爆内存。
      final forceAdmit = forceAdmitIds.any(
        (forced) => MessageConversationId.sameConversation(forced, id),
      );
      if (forceAdmit || _shouldAdmitHot(raw, list)) {
        list.add(raw);
        _items[type] = list;
        dirtyTypes.add(type);
        any = true;
      }
    }
    for (final type in dirtyTypes) {
      final list = _items[type];
      if (list == null || list.length <= 1) {
        continue;
      }
      list.sort(ConversationLocalStore.compareConversationsForUi);
      _items[type] = list;
    }
    if (!any) {
      return;
    }
    ConversationPerfGateLog.log(
      'tab_store_patch',
      extras: <String, Object?>{
        'reason': reason,
        'count': incoming.length,
        'c2c': countForType(ConversationType.V2TIM_C2C),
        'group': countForType(ConversationType.V2TIM_GROUP),
        'ui_source': 'sdk_store',
      },
    );
    notifyListeners();
  }

  /// SDK listener / 置顶回写：合并 patch，禁止元数据-only 更新抹掉预览与未读。
  @visibleForTesting
  static V2TimConversation mergePatchRow({
    required V2TimConversation existing,
    required V2TimConversation incoming,
  }) {
    final id = existing.conversationID.trim();
    final existingUnread = existing.unreadCount ?? 0;
    var resolvedUnread = ConversationUnreadGuard.resolveForListApply(
      conversationId: id,
      existingUnread: existingUnread,
      incoming: incoming,
      existingLastMessage: existing.lastMessage,
    );
    // 置顶等变更常触发 onConversationChanged，但 payload 不带 lastMessage、unread=0。
    if (resolvedUnread == 0 &&
        existingUnread > 0 &&
        incoming.lastMessage == null) {
      resolvedUnread = existingUnread;
    }

    var incomingLast = incoming.lastMessage;
    if (!MessageConversationId.messageBelongsToConversation(
      incomingLast,
      id,
    )) {
      incomingLast = null;
    }
    final preferredLast = ConversationLastMessagePrefer.preferLastMessage(
      existing: existing.lastMessage,
      incoming: incomingLast,
    );
    final existingActive = ConversationLocalStore.activeTimeMs(existing);
    final incomingActive = ConversationLocalStore.activeTimeMs(incoming);
    final orderkey = incomingActive >= existingActive
        ? (incoming.orderkey ?? incomingActive)
        : (existing.orderkey ?? existingActive);

    var showName = incoming.showName?.trim().isNotEmpty == true
        ? incoming.showName!.trim()
        : (existing.showName?.trim() ?? '');
    if (id.startsWith('c2c_') ||
        (incoming.userID?.trim().isNotEmpty ?? false)) {
      showName = ConversationC2cShowNamePrefer.preferForConversationIds(
        conversationID: id,
        userID: incoming.userID ?? existing.userID,
        existingShowName: existing.showName,
        incomingShowName: incoming.showName,
        readStore: DisplayNameStore.instance.c2c,
      );
    }

    return V2TimConversation(
      conversationID: existing.conversationID,
      type: incoming.type ?? existing.type,
      userID: incoming.userID ?? existing.userID,
      groupID: incoming.groupID ?? existing.groupID,
      showName: showName,
      faceUrl: (incoming.faceUrl?.trim().isNotEmpty == true)
          ? incoming.faceUrl
          : existing.faceUrl,
      recvOpt: incoming.recvOpt ?? existing.recvOpt,
      unreadCount: resolvedUnread,
      lastMessage: preferredLast,
      draftText: existing.draftText ?? incoming.draftText,
      draftTimestamp: existing.draftTimestamp ?? incoming.draftTimestamp,
      isPinned: incoming.isPinned,
      orderkey: orderkey,
      groupType: incoming.groupType ?? existing.groupType,
      groupAtInfoList: incoming.groupAtInfoList ?? existing.groupAtInfoList,
    );
  }

  void applyDeleted(List<String> ids) {
    if (ids.isEmpty) {
      return;
    }
    var any = false;
    for (final type in const [
      ConversationType.V2TIM_C2C,
      ConversationType.V2TIM_GROUP,
    ]) {
      final list = _items[type];
      if (list == null || list.isEmpty) {
        continue;
      }
      final next = list
          .where(
            (c) => !ids.any(
              (id) => MessageConversationId.sameConversation(
                c.conversationID,
                id,
              ),
            ),
          )
          .toList();
      if (next.length != list.length) {
        _items[type] = next;
        any = true;
      }
    }
    if (any) {
      notifyListeners();
    }
  }

  /// Phase3：按本地归档 id 集合从已加载窗 purge（主列表不得双显）。
  void purgeArchived({bool notify = true}) {
    if (!ConversationPerfFlags.virtualListExcludeArchivedEnabled) {
      return;
    }
    final c2cLookup = buildArchiveLookupTokenSet(
      archivedConversationC2cIDsNotifier.value,
    );
    final groupLookup = buildArchiveLookupTokenSet(
      archivedConversationGroupIDsNotifier.value,
    );
    final unreadDeltas = <ConversationUnreadDelta>[];
    var any = false;
    for (final type in const [
      ConversationType.V2TIM_C2C,
      ConversationType.V2TIM_GROUP,
    ]) {
      final list = _items[type];
      if (list == null || list.isEmpty) {
        continue;
      }
      final lookup =
          type == ConversationType.V2TIM_GROUP ? groupLookup : c2cLookup;
      final next = <V2TimConversation>[];
      for (final c in list) {
        if (conversationIdInArchivedLookup(lookup, c.conversationID)) {
          final oldN = ConversationUnreadUtils.notifiableUnreadCount(c);
          if (oldN > 0) {
            unreadDeltas.add(
              ConversationUnreadDelta(
                isGroup: type == ConversationType.V2TIM_GROUP,
                oldNotifiable: oldN,
                newNotifiable: 0,
              ),
            );
          }
          any = true;
          continue;
        }
        next.add(c);
      }
      if (next.length != list.length) {
        _items[type] = next;
        any = true;
      }
    }
    if (unreadDeltas.isNotEmpty) {
      ConversationUnreadAggregate.instance.applyNotifiableDeltas(unreadDeltas);
    }
    if (any && notify) {
      ConversationPerfGateLog.log(
        'tab_store_purge_archived',
        extras: <String, Object?>{
          'c2c': countForType(ConversationType.V2TIM_C2C),
          'group': countForType(ConversationType.V2TIM_GROUP),
          'ui_source': 'sdk_store',
        },
      );
      notifyListeners();
    }
  }

  void clear() {
    _items[ConversationType.V2TIM_C2C] = <V2TimConversation>[];
    _items[ConversationType.V2TIM_GROUP] = <V2TimConversation>[];
    _nextSeq[ConversationType.V2TIM_C2C] = '0';
    _nextSeq[ConversationType.V2TIM_GROUP] = '0';
    _finished[ConversationType.V2TIM_C2C] = false;
    _finished[ConversationType.V2TIM_GROUP] = false;
    notifyListeners();
  }

  @visibleForTesting
  void setItemsForTest({
    required int convType,
    required List<V2TimConversation> items,
    String nextSeq = '0',
    bool finished = false,
  }) {
    final type = _normalizeType(convType);
    _items[type] = List<V2TimConversation>.from(items);
    _nextSeq[type] = nextSeq;
    _finished[type] = finished;
    notifyListeners();
  }

  Future<void> _load({
    required int type,
    required bool reset,
    required int count,
  }) async {
    final existing = _loadInFlight[type];
    if (existing != null) {
      return existing;
    }
    final task = _loadOnce(type: type, reset: reset, count: count);
    _loadInFlight[type] = task;
    try {
      await task;
    } finally {
      if (identical(_loadInFlight[type], task)) {
        _loadInFlight[type] = null;
      }
    }
  }

  Future<void> _loadOnce({
    required int type,
    required bool reset,
    required int count,
  }) async {
    final pageCount = count > 0 ? count : defaultPageSize;
    final seq = reset ? '0' : (_nextSeq[type] ?? '0');
    if (!reset && (_finished[type] == true)) {
      return;
    }
    final fetched = await _fetch(
      convType: type,
      nextSeq: seq,
      count: pageCount,
    );
    if (fetched.code != 0) {
      ConversationPerfGateLog.log(
        'tab_store_fetch_fail',
        extras: <String, Object?>{
          'convType': type,
          'code': fetched.code,
          'desc': fetched.desc,
          'ui_source': 'sdk_store',
        },
      );
      return;
    }
    final page = <V2TimConversation>[];
    for (final c in fetched.conversationList) {
      ConversationLocalStore.decorateConversationForUi(c);
      c.isPinned = ConversationPinSyncService.instance
          .isPinnedConversationId(c.conversationID);
      if (_isArchivedConversation(c)) {
        continue;
      }
      page.add(c);
    }
    if (page.length > 1) {
      page.sort(ConversationLocalStore.compareConversationsForUi);
    }
    if (reset) {
      _items[type] = List<V2TimConversation>.from(page);
    } else {
      final current = _items[type] ?? const <V2TimConversation>[];
      final seen = <String>{
        for (final c in current) c.conversationID.trim(),
      };
      final filteredPage = <V2TimConversation>[];
      for (final c in page) {
        final id = c.conversationID.trim();
        if (id.isEmpty || seen.contains(id)) {
          continue;
        }
        // 宽松去重（社群多形态）。
        var dup = false;
        for (final existingId in seen) {
          if (MessageConversationId.sameConversation(existingId, id)) {
            dup = true;
            break;
          }
        }
        if (dup) {
          continue;
        }
        seen.add(id);
        filteredPage.add(c);
      }
      _items[type] = ConversationLocalStore.mergeConversationsForUi(
        current,
        filteredPage,
      );
    }
    final finished = fetched.isFinished || page.isEmpty;
    _finished[type] = finished;
    final next = fetched.nextSeq.trim().isEmpty ? '0' : fetched.nextSeq.trim();
    if (finished || next == '0' || next == seq) {
      _finished[type] = true;
      _nextSeq[type] = '0';
    } else {
      _nextSeq[type] = next;
    }
    ConversationPerfGateLog.log(
      'tab_store_page',
      extras: <String, Object?>{
        'convType': type,
        'reset': reset,
        'page': page.length,
        'total': countForType(type),
        'finished': _finished[type],
        'nextSeq': _nextSeq[type],
        'ui_source': 'sdk_store',
      },
    );
    notifyListeners();
  }

  Future<
      ({
        List<V2TimConversation> conversationList,
        String nextSeq,
        bool isFinished,
        int code,
        String desc,
      })> _fetch({
    required int convType,
    required String nextSeq,
    required int count,
  }) async {
    final override = debugFetchOverride;
    if (override != null) {
      return override(
        convType: convType,
        nextSeq: nextSeq,
        count: count,
      );
    }
    final seqInt = int.tryParse(nextSeq.trim()) ?? 0;
    final res = await TencentImSDKPlugin.v2TIMManager
        .getConversationManager()
        .getConversationListByFilter(
          filter: V2TimConversationFilter(conversationType: convType),
          nextSeq: seqInt,
          count: count,
        );
    final data = res.data;
    final list = <V2TimConversation>[];
    for (final item in data?.conversationList ?? const <V2TimConversation?>[]) {
      if (item != null) {
        list.add(item);
      }
    }
    return (
      conversationList: list,
      nextSeq: data?.nextSeq?.toString() ?? '0',
      isFinished: data?.isFinished == true,
      code: res.code,
      desc: res.desc,
    );
  }

  bool _isArchivedConversation(V2TimConversation conversation) {
    if (!ConversationPerfFlags.virtualListExcludeArchivedEnabled) {
      return false;
    }
    final id = conversation.conversationID.trim();
    if (id.isEmpty) {
      return false;
    }
    if (_typeOf(conversation) == ConversationType.V2TIM_GROUP) {
      return conversationIdInArchivedLookup(
        buildArchiveLookupTokenSet(archivedConversationGroupIDsNotifier.value),
        id,
      );
    }
    return conversationIdInArchivedLookup(
      buildArchiveLookupTokenSet(archivedConversationC2cIDsNotifier.value),
      id,
    );
  }

  bool _shouldAdmitHot(
    V2TimConversation incoming,
    List<V2TimConversation> current,
  ) {
    if (incoming.isPinned == true) {
      return true;
    }
    if ((incoming.unreadCount ?? 0) > 0) {
      return true;
    }
    if (current.isEmpty) {
      return true;
    }
    final incomingActive = ConversationLocalStore.activeTimeMs(incoming);
    final headActive = ConversationLocalStore.activeTimeMs(current.first);
    return incomingActive > headActive;
  }

  int _typeOf(V2TimConversation c) {
    if (c.type == ConversationType.V2TIM_GROUP ||
        (c.groupID?.trim().isNotEmpty == true)) {
      return ConversationType.V2TIM_GROUP;
    }
    return ConversationType.V2TIM_C2C;
  }

  int _normalizeType(int convType) {
    return convType == ConversationType.V2TIM_GROUP
        ? ConversationType.V2TIM_GROUP
        : ConversationType.V2TIM_C2C;
  }
}
