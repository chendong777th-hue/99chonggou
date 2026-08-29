import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_aggregate.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
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

  final Map<int, List<V2TimConversation>> _items =
      <int, List<V2TimConversation>>{
    ConversationType.V2TIM_C2C: <V2TimConversation>[],
    ConversationType.V2TIM_GROUP: <V2TimConversation>[],
  };
  final Map<int, String> _nextSeq = <int, String>{
    ConversationType.V2TIM_C2C: '0',
    ConversationType.V2TIM_GROUP: '0',
  };
  final Map<int, ConversationTypePageCursor?> _pageCursors =
      <int, ConversationTypePageCursor?>{
    ConversationType.V2TIM_C2C: null,
    ConversationType.V2TIM_GROUP: null,
  };
  // SQL rows consumed by pagination. This is separate from _items.length:
  // realtime patches may enter the UI window without advancing the page
  // frontier.
  final Map<int, int> _committedPageOffsets = <int, int>{
    ConversationType.V2TIM_C2C: 0,
    ConversationType.V2TIM_GROUP: 0,
  };
  final Map<int, bool> _finished = <int, bool>{
    ConversationType.V2TIM_C2C: false,
    ConversationType.V2TIM_GROUP: false,
  };
  final Map<int, Future<void>?> _loadInFlight = <int, Future<void>?>{};
  final Set<int> _resetRequested = <int>{};
  int _sessionGeneration = 0;
  bool _lastNotificationStructureChanged = true;

  bool get lastNotificationStructureChanged =>
      _lastNotificationStructureChanged;

  // SQLite and unread aggregation commit before this UI-only buffer is used.
  // Keep only each conversation's final projection while a Chat route is open.
  final Map<String, V2TimConversation> _deferredCommittedUpserts =
      <String, V2TimConversation>{};
  final Set<String> _deferredCommittedDeletes = <String>{};
  final Set<String> _deferredCommittedForceAdmitIds = <String>{};
  final Set<String> _deferredCommittedDraftIds = <String>{};
  final Set<String> _deferredCommittedLastMessageIds = <String>{};
  final Map<String, ConversationUiMove> _deferredCommittedMoves =
      <String, ConversationUiMove>{};
  bool _deferredCommittedStructureChanged = false;
  int _deferredCommittedGeneration = 0;

  bool _isCurrentSession(int generation, String ownerUserId) {
    return generation == _sessionGeneration &&
        ownerUserId == ConversationLocalStore.instance.resolvedOwnerUserId();
  }

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

  @visibleForTesting
  int get deferredCommittedProjectionCount =>
      _deferredCommittedUpserts.length + _deferredCommittedDeletes.length;

  ConversationTypePageCursor? pageCursorForType(int convType) =>
      _pageCursors[_normalizeType(convType)];

  String _projectionKey(String conversationID) {
    final raw = conversationID.trim();
    if (raw.isEmpty) return '';
    final normalized = MessageConversationId.normalizeComparableKey(raw);
    return normalized.isEmpty ? raw : normalized;
  }

  String _deferredProjectionKey(String conversationID, {int? convType}) {
    final raw = conversationID.trim();
    if (raw.isEmpty) return '';
    final type = convType ??
        (raw.startsWith('group_') || raw.startsWith('@TGS')
            ? ConversationType.V2TIM_GROUP
            : raw.startsWith('c2c_')
                ? ConversationType.V2TIM_C2C
                : 0);
    return '$type:${_projectionKey(raw)}';
  }

  void invalidateViewPages({required String conversationID, int? convType}) {
    final id = conversationID.trim();
    if (id.isEmpty) return;
    final types =
        convType == 1 || convType == 2 ? <int>[convType!] : const [1, 2];
    for (final type in types) {
      final list = _items[type];
      if (list == null) continue;
      final index = list.indexWhere((row) =>
          MessageConversationId.sameConversation(row.conversationID, id));
      if (index >= 0) {
        _pageCursors[type] = null;
      }
    }
  }

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
  Future<void> ensurePrimed(
      {int? convType, int count = defaultPageSize}) async {
    if (!ConversationPerfFlags.conversationListSdkPrimary) {
      return;
    }
    if (convType != null) {
      final type = _normalizeType(convType);
      final generation = _sessionGeneration;
      final owner = ConversationLocalStore.instance.resolvedOwnerUserId();
      if ((_items[type] ?? const []).isNotEmpty) {
        return;
      }
      if (_finished[type] == true) {
        // Cold-start may prime before the post-home SDK sync has mirrored
        // rows into SQLite. An empty page must not become a permanent
        // terminal state: retry once data appears in the committed view.
        if (owner.isEmpty) {
          return;
        }
        final total = await ConversationLocalStore.instance.countByConvType(
          convType: type,
          ownerUserId: owner,
        );
        if (!_isCurrentSession(generation, owner) || total <= 0) {
          return;
        }
        _finished[type] = false;
      }
      if (!_isCurrentSession(generation, owner)) {
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
    Set<String> explicitDraftIds = const <String>{},
    Set<String> explicitLastMessageIds = const <String>{},
    bool allowNew = true,
    bool preserveOrder = false,
    bool preserveStructureFields = false,
    bool notify = true,
  }) {
    if (incoming.isEmpty) {
      return;
    }
    final rowsByType = <int, List<V2TimConversation>>{};
    final forceAdmitKeys =
        forceAdmitIds.map(_projectionKey).where((id) => id.isNotEmpty).toSet();
    final explicitDraftKeys = explicitDraftIds
        .map(_projectionKey)
        .where((id) => id.isNotEmpty)
        .toSet();
    final explicitLastMessageKeys = explicitLastMessageIds
        .map(_projectionKey)
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final raw in incoming) {
      final id = raw.conversationID.trim();
      if (id.isEmpty) continue;
      ConversationLocalStore.decorateConversationForUi(raw);
      if (ConversationPinSyncService.instance.isHydrated) {
        raw.isPinned =
            ConversationPinSyncService.instance.isPinnedConversationId(id);
      }
      rowsByType
          .putIfAbsent(_typeOf(raw), () => <V2TimConversation>[])
          .add(raw);
    }

    var any = false;
    var structureChanged = false;
    for (final entry in rowsByType.entries) {
      final type = entry.key;
      final list = List<V2TimConversation>.from(
        _items[type] ?? const <V2TimConversation>[],
      );
      final indexById = <String, int>{};
      void rebuildIndex() {
        indexById.clear();
        for (var index = 0; index < list.length; index++) {
          final key = _projectionKey(list[index].conversationID);
          if (key.isNotEmpty) indexById[key] = index;
        }
      }

      rebuildIndex();
      var changed = false;
      for (final raw in entry.value) {
        final id = raw.conversationID.trim();
        final key = _projectionKey(id);
        var index = indexById[key] ?? -1;
        if (index < 0) {
          index = list.indexWhere(
            (row) => MessageConversationId.sameConversation(
              row.conversationID,
              id,
            ),
          );
          if (index >= 0) indexById[key] = index;
        }
        if (_isArchivedConversation(raw)) {
          if (index >= 0) {
            list.removeAt(index);
            rebuildIndex();
            changed = true;
            structureChanged = true;
          }
          continue;
        }
        if (index >= 0) {
          final existing = list[index];
          final merged = mergePatchRow(
            existing: existing,
            incoming: raw,
            useIncomingDraft: explicitDraftKeys.contains(key),
            useIncomingLastMessage: explicitLastMessageKeys.contains(key),
            preserveStructureFields: preserveStructureFields,
          );
          if (!preserveStructureFields &&
              (merged.isPinned != existing.isPinned ||
                  merged.orderkey != existing.orderkey)) {
            structureChanged = true;
          }
          list[index] = merged;
          changed = true;
          continue;
        }
        // 未在已加载窗：仅热会话（置顶/未读/比窗头更新）插入，避免冷会话撑爆内存。
        if (allowNew &&
            (forceAdmitKeys.contains(key) || _shouldAdmitHot(raw, list))) {
          list.add(raw);
          indexById[key] = list.length - 1;
          changed = true;
          structureChanged = true;
        }
      }
      if (!changed) continue;
      if (!preserveOrder && list.length > 1) {
        // One sort per type/batch. The previous per-row list clone plus
        // repeated sort was the dominant UI-isolate cost for 2k+ rows.
        list.sort(ConversationLocalStore.compareConversationsForUi);
      }
      _items[type] = list;
      any = true;
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
    _lastNotificationStructureChanged = structureChanged;
    if (notify) notifyListeners();
  }

  /// SDK listener / 置顶回写：合并 patch，禁止元数据-only 更新抹掉预览与未读。
  @visibleForTesting
  static V2TimConversation mergePatchRow({
    required V2TimConversation existing,
    required V2TimConversation incoming,
    bool useIncomingDraft = false,
    bool useIncomingLastMessage = false,
    bool preserveStructureFields = false,
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
    final preferredLast = useIncomingLastMessage
        ? incomingLast
        : ConversationLastMessagePrefer.preferLastMessage(
            existing: existing.lastMessage,
            incoming: incomingLast,
          );
    if (preferredLast != null) {
      preservePeerReadLastMessageState(
        existing: existing.lastMessage,
        incoming: incomingLast,
        preferred: preferredLast,
      );
    }
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
      draftText: useIncomingDraft
          ? incoming.draftText
          : (existing.draftText ?? incoming.draftText),
      draftTimestamp: useIncomingDraft
          ? incoming.draftTimestamp
          : (existing.draftTimestamp ?? incoming.draftTimestamp),
      isPinned: preserveStructureFields ? existing.isPinned : incoming.isPinned,
      orderkey: preserveStructureFields ? existing.orderkey : orderkey,
      groupType: incoming.groupType ?? existing.groupType,
      groupAtInfoList: incoming.groupAtInfoList ?? existing.groupAtInfoList,
    );
  }

  void applyDeleted(List<String> ids, {bool notify = true}) {
    if (ids.isEmpty) {
      return;
    }
    var any = false;
    for (final type in const [
      ConversationType.V2TIM_C2C,
      ConversationType.V2TIM_GROUP,
    ]) {
      for (final id in ids) {
        invalidateViewPages(conversationID: id, convType: type);
      }
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
        final tail = ConversationLocalStore.oldestPagingCursor(next);
        if (tail != null) {
          _pageCursors[type] = ConversationTypePageCursor(
            pinned: tail.isPinned == true,
            activeTime: ConversationLocalStore.pagingAnchorMs(tail),
            orderKey: tail.orderkey ?? 0,
            conversationID: tail.conversationID,
          );
        }
        any = true;
      }
    }
    if (any && notify) {
      _lastNotificationStructureChanged = true;
      notifyListeners();
    }
  }

  /// Applies one committed database view result. This is the sole UI entry
  /// point for a committed batch in SQLite-primary mode: row patches, deletes,
  /// cursor invalidation and unread aggregation are coalesced into one notify.
  void applyCommittedViewBatch(
    ConversationUiSnapshotBatch<V2TimConversation> batch, {
    Set<String> forceAdmitIds = const <String>{},
    Set<String> explicitDraftIds = const <String>{},
    Set<String> explicitLastMessageIds = const <String>{},
  }) {
    if (batch.isEmpty && batch.unreadDeltas.isEmpty) return;
    if (kDebugMode) {
      debugPrint(
        '[ConversationUnreadOpen] source=tab_store_batch '
        'rows=${batch.upsertedSnapshots.map((r) => '${r.conversationID}:${r.unreadCount ?? 0}').join(',')} '
        'deltas=${batch.unreadDeltas.map((d) => '${d.isGroup ? 'group' : 'c2c'}:${d.oldNotifiable}->${d.newNotifiable}').join(',')} '
        'active=${ActiveChatRegistry.instance.activeConversationId ?? ''}',
      );
    }
    final committedDraftIds = <String>{...explicitDraftIds};
    final committedLastMessageIds = <String>{...explicitLastMessageIds};
    for (final entry in batch.changedFieldMasks.entries) {
      if (entry.value.contains(ConversationMutationField.draft)) {
        committedDraftIds.add(entry.key);
      }
      if (entry.value.contains(ConversationMutationField.lastMessage)) {
        committedLastMessageIds.add(entry.key);
      }
    }
    if (!ConversationPerfFlags.deferTabStoreProjectionWhileActiveChat ||
        !ActiveChatRegistry.instance.hasOpenChat ||
        batch.isEmpty) {
      _applyCommittedViewBatchNow(
        batch,
        forceAdmitIds: forceAdmitIds,
        explicitDraftIds: committedDraftIds,
        explicitLastMessageIds: committedLastMessageIds,
      );
      return;
    }

    final immediateContentRows = <V2TimConversation>[];
    final deferredRows = <V2TimConversation>[];
    const contentFields = <ConversationMutationField>{
      ConversationMutationField.lastMessage,
      ConversationMutationField.unread,
      ConversationMutationField.draft,
      ConversationMutationField.name,
      ConversationMutationField.avatar,
      ConversationMutationField.mute,
    };
    const structureFields = <ConversationMutationField>{
      ConversationMutationField.pin,
      ConversationMutationField.order,
    };
    final changedFieldsFor = <String, Set<ConversationMutationField>>{
      for (final entry in batch.changedFieldMasks.entries)
        _projectionKey(entry.key): entry.value,
    };
    for (final row in batch.upsertedSnapshots) {
      final key = _projectionKey(row.conversationID);
      final fields =
          changedFieldsFor[key] ?? const <ConversationMutationField>{};
      final exists = typeIndexOf(_typeOf(row), row.conversationID) != null;
      final isActiveConversation = ActiveChatRegistry.instance
          .matchesOpenConversation(row.conversationID);
      final hasContentMask = fields.isNotEmpty &&
          fields.any(contentFields.contains) &&
          fields.every(
            (field) =>
                contentFields.contains(field) ||
                structureFields.contains(field),
          );
      final canProjectContent = !_isArchivedConversation(row) &&
          batch.deletedCanonicalIds.isEmpty &&
          ((exists && hasContentMask) || isActiveConversation);
      if (canProjectContent) {
        immediateContentRows.add(row);
      }
      final needsDeferredStructure = !canProjectContent ||
          fields.any(structureFields.contains) ||
          (batch.structureChanged && fields.isEmpty && !isActiveConversation);
      if (needsDeferredStructure) {
        deferredRows.add(row);
      }
    }
    final deferredDeletes = <String>[];
    final deferredMoves = <ConversationUiMove>[];
    deferredDeletes.addAll(batch.deletedCanonicalIds);
    deferredMoves.addAll(batch.moves);

    // Badges are a committed aggregate, not a conversation-list projection.
    // Apply them now even though their corresponding list rows are deferred.
    _applyUnreadDeltas(batch.unreadDeltas);

    final deferredForceAdmit = Set<String>.of(forceAdmitIds);
    if (immediateContentRows.isNotEmpty) {
      final immediateContentIds =
          immediateContentRows.map((row) => row.conversationID).toSet();
      _applyCommittedViewBatchNow(
        ConversationUiSnapshotBatch<V2TimConversation>(
          upsertedSnapshots: immediateContentRows,
          deletedCanonicalIds: const <String>[],
          structureChanged: false,
          changedFieldMasks: <String, Set<ConversationMutationField>>{
            for (final row in immediateContentRows)
              if (changedFieldsFor[_projectionKey(row.conversationID)]
                      ?.isNotEmpty ==
                  true)
                row.conversationID:
                    changedFieldsFor[_projectionKey(row.conversationID)]!
                        .where(contentFields.contains)
                        .toSet(),
          },
          commitGeneration: batch.commitGeneration,
          moves: const <ConversationUiMove>[],
          // The aggregate was committed immediately above. Passing the
          // original delta here would count the active row twice.
          unreadDeltas: const <ConversationUiUnreadDelta>[],
          unreadProjectionComplete: batch.unreadProjectionComplete,
        ),
        forceAdmitIds: const <String>{},
        explicitDraftIds:
            committedDraftIds.where(immediateContentIds.contains).toSet(),
        explicitLastMessageIds:
            committedLastMessageIds.where(immediateContentIds.contains).toSet(),
        preserveOrder: true,
        allowNew: true,
        preserveStructureFields: true,
      );
    }

    final hasDeferredProjection = deferredRows.isNotEmpty ||
        deferredDeletes.isNotEmpty ||
        deferredMoves.isNotEmpty;
    if (!hasDeferredProjection) return;
    _enqueueDeferredCommittedProjection(
      upserted: deferredRows,
      deletedIds: deferredDeletes,
      moves: deferredMoves,
      forceAdmitIds: deferredForceAdmit,
      structureChanged: batch.structureChanged,
      generation: batch.commitGeneration,
      explicitDraftIds: committedDraftIds,
      explicitLastMessageIds: committedLastMessageIds,
    );
  }

  void _enqueueDeferredCommittedProjection({
    required Iterable<V2TimConversation> upserted,
    required Iterable<String> deletedIds,
    required Iterable<ConversationUiMove> moves,
    required Set<String> forceAdmitIds,
    required bool structureChanged,
    required int generation,
    required Set<String> explicitDraftIds,
    required Set<String> explicitLastMessageIds,
  }) {
    for (final id in deletedIds) {
      final key = _deferredProjectionKey(id);
      if (key.isEmpty) continue;
      _deferredCommittedDeletes.add(id.trim());
      _deferredCommittedUpserts.remove(key);
      _deferredCommittedMoves.remove(key);
    }
    for (final row in upserted) {
      final key = _deferredProjectionKey(
        row.conversationID,
        convType: _typeOf(row),
      );
      if (key.isEmpty) continue;
      _deferredCommittedDeletes.removeWhere(
        (id) => _deferredProjectionKey(id) == key,
      );
      _deferredCommittedUpserts[key] = row;
      // A later snapshot supplies the final sort position. An earlier
      // explicit move uses positions from an obsolete window and must not be
      // replayed during the eventual flush.
      _deferredCommittedMoves.remove(key);
    }
    for (final move in moves) {
      final key = _deferredProjectionKey(
        move.conversationID,
        convType: _normalizeType(move.convType),
      );
      if (key.isEmpty ||
          _deferredCommittedUpserts.containsKey(key) ||
          _deferredCommittedDeletes.any(
            (id) => _deferredProjectionKey(id) == key,
          )) {
        continue;
      }
      _deferredCommittedMoves[key] = move;
    }
    _deferredCommittedForceAdmitIds.addAll(forceAdmitIds);
    _deferredCommittedDraftIds.addAll(explicitDraftIds);
    _deferredCommittedLastMessageIds.addAll(explicitLastMessageIds);
    _deferredCommittedStructureChanged =
        _deferredCommittedStructureChanged || structureChanged;
    if (generation > _deferredCommittedGeneration) {
      _deferredCommittedGeneration = generation;
    }
    ConversationPerfGateLog.log(
      'tab_store_projection_deferred_active_chat',
      extras: <String, Object?>{
        'upserted': _deferredCommittedUpserts.length,
        'deleted': _deferredCommittedDeletes.length,
        'moves': _deferredCommittedMoves.length,
        'generation': _deferredCommittedGeneration,
      },
    );
  }

  /// Flushes the durable committed view after Chat releases the foreground.
  /// The final row per conversation is applied once, so a burst of SDK events
  /// cannot trigger one list copy/sort per callback.
  void flushDeferredCommittedProjection({String reason = 'chat_leave'}) {
    if (_deferredCommittedUpserts.isEmpty &&
        _deferredCommittedDeletes.isEmpty &&
        _deferredCommittedMoves.isEmpty) {
      return;
    }
    final upserted = _deferredCommittedUpserts.values.toList(growable: false);
    final deleted = _deferredCommittedDeletes.toList(growable: false);
    final moves = _deferredCommittedMoves.values.toList(growable: false);
    final forceAdmit = Set<String>.of(_deferredCommittedForceAdmitIds);
    final explicitDraftIds = Set<String>.of(_deferredCommittedDraftIds);
    final explicitLastMessageIds =
        Set<String>.of(_deferredCommittedLastMessageIds);
    final structureChanged = _deferredCommittedStructureChanged;
    final generation = _deferredCommittedGeneration;
    _clearDeferredCommittedProjection();
    ConversationPerfGateLog.log(
      'tab_store_projection_flush',
      extras: <String, Object?>{
        'reason': reason,
        'upserted': upserted.length,
        'deleted': deleted.length,
        'moves': moves.length,
        'generation': generation,
      },
    );
    _applyCommittedViewBatchNow(
      ConversationUiSnapshotBatch<V2TimConversation>(
        upsertedSnapshots: upserted,
        deletedCanonicalIds: deleted,
        structureChanged: structureChanged,
        changedFieldMasks: const <String, Set<ConversationMutationField>>{},
        commitGeneration: generation,
        moves: moves,
      ),
      forceAdmitIds: forceAdmit,
      explicitDraftIds: explicitDraftIds,
      explicitLastMessageIds: explicitLastMessageIds,
    );
  }

  void _clearDeferredCommittedProjection() {
    _deferredCommittedUpserts.clear();
    _deferredCommittedDeletes.clear();
    _deferredCommittedForceAdmitIds.clear();
    _deferredCommittedDraftIds.clear();
    _deferredCommittedLastMessageIds.clear();
    _deferredCommittedMoves.clear();
    _deferredCommittedStructureChanged = false;
    _deferredCommittedGeneration = 0;
  }

  void _applyUnreadDeltas(Iterable<ConversationUiUnreadDelta> deltas) {
    final values = deltas.toList(growable: false);
    if (values.isEmpty) return;
    ConversationUnreadAggregate.instance.applyNotifiableDeltas(
      values
          .map((delta) => ConversationUnreadDelta(
                isGroup: delta.isGroup,
                oldNotifiable: delta.oldNotifiable,
                newNotifiable: delta.newNotifiable,
              ))
          .toList(growable: false),
    );
  }

  void _applyCommittedViewBatchNow(
    ConversationUiSnapshotBatch<V2TimConversation> batch, {
    Set<String> forceAdmitIds = const <String>{},
    Set<String> explicitDraftIds = const <String>{},
    Set<String> explicitLastMessageIds = const <String>{},
    bool preserveOrder = false,
    bool allowNew = true,
    bool preserveStructureFields = false,
  }) {
    if (batch.isEmpty && batch.unreadDeltas.isEmpty) return;
    final changedTypes = <int>{};
    final oldPositions = <String, int>{};
    for (final row in batch.upsertedSnapshots) {
      final type = _normalizeType(row.type ?? ConversationType.V2TIM_C2C);
      changedTypes.add(type);
      oldPositions[row.conversationID.trim()] =
          typeIndexOf(type, row.conversationID) ?? -1;
    }
    for (final id in batch.deletedCanonicalIds) {
      for (final type in const [
        ConversationType.V2TIM_C2C,
        ConversationType.V2TIM_GROUP
      ]) {
        invalidateViewPages(conversationID: id, convType: type);
      }
    }
    if (batch.upsertedSnapshots.isNotEmpty) {
      applyPatches(
        batch.upsertedSnapshots,
        reason: 'committed_view_batch',
        forceAdmitIds: forceAdmitIds,
        explicitDraftIds: explicitDraftIds,
        explicitLastMessageIds: explicitLastMessageIds,
        preserveOrder: preserveOrder,
        allowNew: allowNew,
        preserveStructureFields: preserveStructureFields,
        notify: false,
      );
    }
    final derivedMoves = <ConversationUiMove>[];
    for (final row in batch.upsertedSnapshots) {
      final type = _normalizeType(row.type ?? ConversationType.V2TIM_C2C);
      final oldIndex = oldPositions[row.conversationID.trim()] ?? -1;
      final newIndex = typeIndexOf(type, row.conversationID) ?? -1;
      if (oldIndex >= 0 && newIndex >= 0 && oldIndex != newIndex) {
        derivedMoves.add(ConversationUiMove(
          conversationID: row.conversationID,
          convType: type,
          oldIndex: oldIndex,
          newIndex: newIndex,
          reason: 'committed_batch',
        ));
      }
    }
    for (final move in batch.moves) {
      final list = _items[_normalizeType(move.convType)];
      if (list == null || list.isEmpty) continue;
      final from =
          list.indexWhere((row) => MessageConversationId.sameConversation(
                row.conversationID,
                move.conversationID,
              ));
      if (from < 0) continue;
      final row = list.removeAt(from);
      final target = move.newIndex.clamp(0, list.length);
      list.insert(target, row);
      _items[_normalizeType(move.convType)] = list;
    }
    if (batch.deletedCanonicalIds.isNotEmpty) {
      applyDeleted(batch.deletedCanonicalIds, notify: false);
    }
    if (batch.structureChanged) {
      for (final type in changedTypes) {
        _pageCursors[type] = null;
      }
      ConversationPerfGateLog.log(
        'conversation_view_move_batch',
        extras: <String, Object?>{
          'rows': batch.upsertedSnapshots.length,
          'deleted': batch.deletedCanonicalIds.length,
          'generation': batch.commitGeneration,
          'types': changedTypes.toList(growable: false),
        },
      );
    }
    final moves = <ConversationUiMove>[...batch.moves, ...derivedMoves];
    if (moves.isNotEmpty) {
      ConversationPerfGateLog.log(
        'conversation_view_precise_move',
        extras: <String, Object?>{
          'count': moves.length,
          'moves': moves
              .map((m) => <String, Object?>{
                    'id': m.conversationID,
                    'type': m.convType,
                    'from': m.oldIndex,
                    'to': m.newIndex,
                    'reason': m.reason,
                  })
              .toList(growable: false),
        },
      );
    }
    if (batch.unreadDeltas.isNotEmpty) {
      ConversationUnreadAggregate.instance.applyNotifiableDeltas(
        batch.unreadDeltas
            .map((d) => ConversationUnreadDelta(
                  isGroup: d.isGroup,
                  oldNotifiable: d.oldNotifiable,
                  newNotifiable: d.newNotifiable,
                ))
            .toList(growable: false),
      );
    }
    _lastNotificationStructureChanged = batch.structureChanged ||
        batch.deletedCanonicalIds.isNotEmpty ||
        batch.moves.isNotEmpty ||
        derivedMoves.isNotEmpty;
    notifyListeners();
  }

  /// 批量已读的即时 UI 投影。SDK primary 模式下列表行来自本 Store，
  /// 不能只更新 legacy ConversationListNotifier 的镜像。
  void zeroUnreadLocallyMany(Iterable<String> conversationIds) {
    final ids = conversationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) {
      return;
    }
    ConversationUnreadGuard.clearOptimisticUnreadMany(ids);
    var changed = false;
    final unreadDeltas = <ConversationUnreadDelta>[];
    final cleared = <String>[];
    for (final type in const [
      ConversationType.V2TIM_C2C,
      ConversationType.V2TIM_GROUP,
    ]) {
      final current = _items[type];
      if (current == null || current.isEmpty) {
        continue;
      }
      final next = List<V2TimConversation>.from(current);
      for (var i = 0; i < next.length; i++) {
        final row = next[i];
        final hit = ids.contains(row.conversationID.trim()) ||
            ids.any((id) =>
                MessageConversationId.sameConversation(id, row.conversationID));
        if (!hit || (row.unreadCount ?? 0) == 0) {
          continue;
        }
        final oldNotifiable =
            ConversationUnreadUtils.notifiableUnreadCount(row);
        if (oldNotifiable > 0) {
          unreadDeltas.add(
            ConversationUnreadDelta(
              isGroup: type == ConversationType.V2TIM_GROUP,
              oldNotifiable: oldNotifiable,
              newNotifiable: 0,
            ),
          );
        }
        cleared.add(row.conversationID.trim());
        row.unreadCount = 0;
        next[i] = row;
        changed = true;
      }
      if (changed) {
        _items[type] = next;
      }
    }
    if (unreadDeltas.isNotEmpty) {
      final aggregate = ConversationUnreadAggregate.instance;
      final beforeC2c = aggregate.c2cNotifiableUnreadSum;
      final beforeGroup = aggregate.groupNotifiableUnreadSum;
      aggregate.applyNotifiableDeltas(unreadDeltas);
      if (kDebugMode) {
        debugPrint(
          '[ConversationUnreadOpen] source=tab_store '
          'cleared=${cleared.join(",")} '
          'deltaC2c=${unreadDeltas.where((d) => !d.isGroup).fold<int>(0, (s, d) => s + d.delta)} '
          'deltaGroup=${unreadDeltas.where((d) => d.isGroup).fold<int>(0, (s, d) => s + d.delta)} '
          'aggregateBefore=$beforeC2c/$beforeGroup '
          'aggregateAfter=${aggregate.c2cNotifiableUnreadSum}/${aggregate.groupNotifiableUnreadSum}',
        );
      }
    }
    if (changed) {
      _lastNotificationStructureChanged = false;
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
      _lastNotificationStructureChanged = true;
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
    _sessionGeneration++;
    _resetRequested.clear();
    _clearDeferredCommittedProjection();
    _items[ConversationType.V2TIM_C2C] = <V2TimConversation>[];
    _items[ConversationType.V2TIM_GROUP] = <V2TimConversation>[];
    _nextSeq[ConversationType.V2TIM_C2C] = '0';
    _nextSeq[ConversationType.V2TIM_GROUP] = '0';
    _finished[ConversationType.V2TIM_C2C] = false;
    _finished[ConversationType.V2TIM_GROUP] = false;
    _pageCursors[ConversationType.V2TIM_C2C] = null;
    _pageCursors[ConversationType.V2TIM_GROUP] = null;
    _lastNotificationStructureChanged = true;
    _committedPageOffsets[ConversationType.V2TIM_C2C] = 0;
    _committedPageOffsets[ConversationType.V2TIM_GROUP] = 0;
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
    _committedPageOffsets[type] = _items[type]!.length;
    _nextSeq[type] = nextSeq;
    _finished[type] = finished;
    final tail = ConversationLocalStore.oldestPagingCursor(_items[type]!);
    _pageCursors[type] = tail == null
        ? null
        : ConversationTypePageCursor(
            pinned: tail.isPinned == true,
            activeTime: ConversationLocalStore.pagingAnchorMs(tail),
            orderKey: tail.orderkey ?? 0,
            conversationID: tail.conversationID,
          );
    _lastNotificationStructureChanged = true;
    notifyListeners();
  }

  Future<void> _load({
    required int type,
    required bool reset,
    required int count,
  }) async {
    final existing = _loadInFlight[type];
    if (existing != null) {
      if (reset) {
        _resetRequested.add(type);
      }
      await existing;
      if (reset && _resetRequested.remove(type)) {
        await _load(type: type, reset: true, count: count);
      }
      return;
    }
    final generation = _sessionGeneration;
    final task = _loadOnce(
      type: type,
      reset: reset,
      count: count,
      generation: generation,
    );
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
    required int generation,
  }) async {
    final pageCount = count > 0 ? count : defaultPageSize;
    final seq = reset ? '0' : (_nextSeq[type] ?? '0');
    if (!reset && (_finished[type] == true)) {
      return;
    }
    if (ConversationPerfFlags.tabStoreCommittedViewEnabled) {
      await _loadCommittedViewPage(
        type: type,
        reset: reset,
        count: pageCount,
        generation: generation,
      );
      return;
    }
    final fetched = await _fetch(
      convType: type,
      nextSeq: seq,
      count: pageCount,
    );
    if (generation != _sessionGeneration) {
      return;
    }
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
      if (ConversationPinSyncService.instance.isHydrated) {
        c.isPinned = ConversationPinSyncService.instance
            .isPinnedConversationId(c.conversationID);
      }
      if (_isArchivedConversation(c)) {
        continue;
      }
      page.add(c);
    }
    if (page.length > 1) {
      page.sort(ConversationLocalStore.compareConversationsForUi);
    }
    if (reset) {
      // A realtime patch may have landed while the SDK request was in
      // flight. Merge matching rows instead of replacing them wholesale.
      final current = _items[type] ?? const <V2TimConversation>[];
      final currentById = <String, V2TimConversation>{
        for (final item in current) item.conversationID.trim(): item,
      };
      _items[type] = <V2TimConversation>[
        for (final item in page)
          currentById[item.conversationID.trim()] == null
              ? item
              : mergePatchRow(
                  existing: currentById[item.conversationID.trim()]!,
                  incoming: item,
                ),
      ];
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
      final tail = ConversationLocalStore.oldestPagingCursor(_items[type]!);
      if (tail != null) {
        _pageCursors[type] = ConversationTypePageCursor(
          pinned: tail.isPinned == true,
          activeTime: ConversationLocalStore.pagingAnchorMs(tail),
          orderKey: tail.orderkey ?? 0,
          conversationID: tail.conversationID,
        );
      }
    }
    final finished = fetched.isFinished || page.isEmpty;
    _finished[type] = finished;
    final next = fetched.nextSeq.trim().isEmpty ? '0' : fetched.nextSeq.trim();
    if (finished || next == '0' || next == seq) {
      _finished[type] = true;
      _nextSeq[type] = '0';
      _pageCursors[type] = null;
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
    _lastNotificationStructureChanged = true;
    notifyListeners();
  }

  Future<void> _loadCommittedViewPage({
    required int type,
    required bool reset,
    required int count,
    required int generation,
  }) async {
    final store = ConversationLocalStore.instance;
    // During native cold-start the business owner can be restored a few
    // frames after the IM/UI stack.  An empty owner means the query was not
    // scoped to an account, not that this account has no conversations.
    // Leave the page frontier untouched so the next recovery pass retries.
    final owner = store.resolvedOwnerUserId();
    if (owner.isEmpty) {
      ConversationPerfGateLog.log(
        'tab_store_committed_page_skip',
        extras: <String, Object?>{
          'convType': type,
          'reset': reset,
          'reason': 'owner_unavailable',
          'source': 'sqlite_committed_view',
        },
      );
      return;
    }
    final excluded = type == ConversationType.V2TIM_GROUP
        ? archivedConversationGroupIDsNotifier.value
        : archivedConversationC2cIDsNotifier.value;
    final cursor = reset ? null : _pageCursors[type];
    final frontierOffset = reset ? 0 : (_committedPageOffsets[type] ?? 0);
    ConversationPerfGateLog.log(
      'tab_store_committed_page_start',
      extras: <String, Object?>{
        'convType': type,
        'reset': reset,
        'count': count,
        'cursor': cursor?.conversationID,
        'sessionGeneration': generation,
      },
    );
    var page = cursor == null
        ? await store.loadConvTypePage(
            convType: type,
            offset: 0,
            limit: count,
            ownerUserId: owner,
            excludeConversationIds: excluded,
          )
        : await store.loadConvTypePageAfterCursor(
            convType: type,
            cursor: cursor,
            limit: count,
            ownerUserId: owner,
            excludeConversationIds: excluded,
          );
    if (generation != _sessionGeneration) {
      ConversationPerfGateLog.log(
        'tab_store_committed_page_drop',
        extras: <String, Object?>{
          'convType': type,
          'reason': 'session_generation_mismatch',
          'requestGeneration': generation,
          'currentGeneration': _sessionGeneration,
          'page': page.length,
        },
      );
      return;
    }
    final current = reset
        ? const <V2TimConversation>[]
        : (_items[type] ?? const <V2TimConversation>[]);
    var merged = ConversationLocalStore.mergeConversationsForUi(
      current,
      page,
    );
    final queriedTail = ConversationLocalStore.oldestPagingCursor(page);
    final cursorDidNotAdvance = cursor != null &&
        queriedTail != null &&
        queriedTail.conversationID.trim() == cursor.conversationID.trim() &&
        ConversationLocalStore.pagingAnchorMs(queriedTail) ==
            cursor.activeTime &&
        (queriedTail.orderkey ?? 0) == cursor.orderKey &&
        (queriedTail.isPinned == true) == cursor.pinned;

    // A keyset cursor can become stale when realtime patches reorder rows
    // between the initial page and the next request. In that case the query
    // returns mostly already-loaded rows and the tail cursor does not move;
    // retry once from the committed page frontier so a virtual row cannot be
    // stuck as a skeleton forever or skip rows admitted by realtime patches.
    if (!reset && cursorDidNotAdvance && page.length >= count) {
      final fallbackOffset = frontierOffset;
      final fallbackPage = await store.loadConvTypePage(
        convType: type,
        offset: fallbackOffset,
        limit: count,
        ownerUserId: owner,
        excludeConversationIds: excluded,
      );
      if (fallbackPage.isNotEmpty) {
        if (!_isCurrentSession(generation, owner)) {
          ConversationPerfGateLog.log(
            'tab_store_committed_page_drop',
            extras: <String, Object?>{
              'convType': type,
              'reason': 'fallback_session_or_owner_mismatch',
              'requestGeneration': generation,
              'currentGeneration': _sessionGeneration,
              'page': fallbackPage.length,
            },
          );
          return;
        }
        page = fallbackPage;
        merged = ConversationLocalStore.mergeConversationsForUi(
          current,
          fallbackPage,
        );
        ConversationPerfGateLog.log(
          'tab_store_committed_page_fallback',
          extras: <String, Object?>{
            'convType': type,
            'reason': 'cursor_no_progress',
            'cursor': cursor.conversationID,
            'cursorDidNotAdvance': cursorDidNotAdvance,
            'offset': fallbackOffset,
            'page': fallbackPage.length,
            'loadedBefore': current.length,
            'frontierBefore': frontierOffset,
            'loadedAfter': merged.length,
          },
        );
      }
    }
    if (reset) {
      _committedPageOffsets[type] = page.length;
    } else if (page.isNotEmpty) {
      _committedPageOffsets[type] = frontierOffset + page.length;
    }
    _items[type] = merged;
    // Keep the keyset frontier tied to the fetched page. Realtime patches are
    // merged into the UI window, but must not move pagination backwards.
    final tail = ConversationLocalStore.oldestPagingCursor(
      page.isEmpty ? const <V2TimConversation>[] : page,
    );
    _pageCursors[type] = tail == null
        ? null
        : ConversationTypePageCursor(
            pinned: tail.isPinned == true,
            activeTime: ConversationLocalStore.pagingAnchorMs(tail),
            orderKey: tail.orderkey ?? 0,
            conversationID: tail.conversationID,
          );
    final total = await store.countByConvType(
      convType: type,
      ownerUserId: owner,
      excludeConversationIds: excluded,
    );
    if (!_isCurrentSession(generation, owner)) {
      ConversationPerfGateLog.log(
        'tab_store_committed_page_drop',
        extras: <String, Object?>{
          'convType': type,
          'reason': 'count_session_or_owner_mismatch',
          'requestGeneration': generation,
          'currentGeneration': _sessionGeneration,
          'total': total,
        },
      );
      return;
    }
    _finished[type] = page.isEmpty || (_items[type]?.length ?? 0) >= total;
    _nextSeq[type] = _finished[type] == true ? '0' : 'sqlite-keyset';
    final nextCursor = _pageCursors[type];
    ConversationPerfGateLog.log(
      'tab_store_committed_page',
      extras: <String, Object?>{
        'convType': type,
        'reset': reset,
        'page': page.length,
        'total': total,
        'loaded': _items[type]?.length ?? 0,
        'finished': _finished[type],
        'cursorBefore': cursor?.conversationID,
        'cursorAfter': nextCursor?.conversationID,
        'cursorAdvanced': cursor?.conversationID != nextCursor?.conversationID,
        'pageTail': tail?.conversationID,
        'source': 'sqlite_committed_view',
      },
    );
    _lastNotificationStructureChanged = true;
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
