import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/outgoing_visible_probe.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_pin_hydrate_policy.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_preview_text_cache.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_tab_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_aggregate.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_virtual_hydrate_policy.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_flicker_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_unread_trace.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_host.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lock_profile_log.dart';
import 'package:tencent_cloud_chat_demo/src/utils/archive_conversation_lookup.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_unread_utils.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_c2c_show_name_prefer.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_last_message_prefer.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_last_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

/// append/prepend 滑动窗结果：供列表校正滚动偏移。
class ConversationWindowSlideResult {
  const ConversationWindowSlideResult({
    this.added = 0,
    this.trimmedFromStart = 0,
    this.trimmedFromEnd = 0,
  });

  final int added;
  final int trimmedFromStart;
  final int trimmedFromEnd;

  bool get changed => added > 0 || trimmedFromStart > 0 || trimmedFromEnd > 0;

  static const empty = ConversationWindowSlideResult();
}

/// 会话列表 UI 数据源：只从本地库读取，不直接绑定 SDK 内存列表。
class ConversationListNotifier extends ChangeNotifier {
  ConversationListNotifier._();

  static final ConversationListNotifier instance = ConversationListNotifier._();

  /// 置顶后先停顿再重排（短位移；兼侧滑收起）。
  static const Duration pinReorderDelay = Duration(milliseconds: 180);

  /// 会话列表滚动位置（由 Conversation 页注册），用于日志。
  double? Function()? listScrollOffsetProvider;

  /// 会话列表是否正在滚动（idle drain 暂停用）。
  bool Function()? isFeedScrolling;

  List<V2TimConversation> _conversations = const [];
  bool _storeHasAnyRow = false;
  int _structureRevision = 0;
  int _contentRevision = 0;

  /// 避免单聊/群聊两个 Feed 对同一 PeerProfile revision 重复 apply。
  int _lastPeerDisplayAppliedRevision = -1;

  Future<void>? _reloadInFlight;
  bool _reloadDirty = false;
  Future<void>? _uiPageLoadInFlight;

  /// 用户触底/近顶翻页扩展过 UI 列表：禁止 loadUiWindow 热快照整窗覆盖。
  bool _slidingWindowUserExpanded = false;

  /// 按类型记录已消费的库序 OFFSET（只增不减）。裁窗后不能再用窗内 typedCount 当 offset。
  final Map<int, int> _typeAppendConsumed = <int, int>{};

  /// 虚拟列表：库内该类型总数（可滚长度）。
  final Map<int, int> _typeTotalCount = <int, int>{1: 0, 2: 0};

  /// 虚拟列表：类型水合窗起始 offset 与连续页。
  final Map<int, int> _typeHydrateStart = <int, int>{1: 0, 2: 0};
  final Map<int, List<V2TimConversation>> _typeHydrate =
      <int, List<V2TimConversation>>{
    1: const <V2TimConversation>[],
    2: const <V2TimConversation>[],
  };
  final Map<int, Map<int, V2TimConversation>> _typeIndexSnapshotCache =
      <int, Map<int, V2TimConversation>>{
    1: <int, V2TimConversation>{},
    2: <int, V2TimConversation>{},
  };
  Future<void>? _hydrateInFlight;
  int _hydrateRequestSerial = 0;

  int _notifySuppressDepth = 0;
  bool _notifyPendingWhileSuppressed = false;
  Timer? _coalescedNotifyTimer;
  String? _coalescedNotifyReason;
  bool _uiNotifyPendingWhileScrolling = false;
  bool _uiNotifyPendingWhileActiveChat = false;
  Timer? _scrollUiNotifyMaxDeferTimer;
  Timer? _activeChatUiNotifyMaxDeferTimer;
  Timer? _deferredPinReorderTimer;
  String? _deferredPinConversationId;
  bool? _deferredPinTargetPinned;

  /// 本地免打扰 grace：conversationID → (recvOpt, untilMs)。
  final Map<String, ({int recvOpt, int untilMs})> _recvOptLocalGraceById =
      <String, ({int recvOpt, int untilMs})>{};
  Timer? _activeChatDirtyCatchUpTimer;
  bool _activeChatDirtyCatchUpInFlight = false;
  final Set<String> _activeChatDirtyIds = <String>{};
  ConversationPinReorderScrollHint? _pinReorderScrollHint;
  int _chatLeavePatchGeneration = 0;
  String? _lastChatLeavePatchedId;
  DateTime? _lastChatLeavePatchedAt;
  DateTime? _postChatLeaveQuietUntil;

  bool _tabStoreBridgeAttached = false;

  /// SDK-primary：把 TabStore 变更桥到本 Notifier（Feed 仍 listen 本对象）。
  void ensureTabStoreBridgeAttached() {
    if (_tabStoreBridgeAttached) {
      return;
    }
    _tabStoreBridgeAttached = true;
    ConversationTabStore.instance.addListener(_onTabStoreChanged);
  }

  void _onTabStoreChanged() {
    if (!ConversationPerfFlags.conversationListSdkPrimary) {
      return;
    }
    _adoptTabStoreIntoNotifierWindows();
    _bumpRevisionsForChange(orderOrMembershipChanged: true);
    ConversationPerfGateLog.log(
      'ui_source',
      extras: <String, Object?>{
        'source': 'sdk_store',
        'c2c': ConversationTabStore.instance.countForType(1),
        'group': ConversationTabStore.instance.countForType(2),
      },
    );
    _notifyIfAllowed(reason: 'tab_store');
  }

  void _adoptTabStoreIntoNotifierWindows() {
    final c2c = ConversationTabStore.instance.itemsForType(1);
    final group = ConversationTabStore.instance.itemsForType(2);
    final merged = ConversationLocalStore.mergeConversationsForUi(c2c, group);
    _clearTypeIndexSnapshotCache();
    _conversations = merged;
    _typeHydrate[1] = List<V2TimConversation>.from(c2c);
    _typeHydrate[2] = List<V2TimConversation>.from(group);
    _typeHydrateStart[1] = 0;
    _typeHydrateStart[2] = 0;
    _cacheTypeIndexPage(1, 0, c2c);
    _cacheTypeIndexPage(2, 0, group);
    _typeTotalCount[1] = ConversationTabStore.instance.finishedForType(1)
        ? c2c.length
        : (c2c.isEmpty ? 0 : c2c.length + ConversationTabStore.defaultPageSize);
    _typeTotalCount[2] = ConversationTabStore.instance.finishedForType(2)
        ? group.length
        : (group.isEmpty
            ? 0
            : group.length + ConversationTabStore.defaultPageSize);
    _storeHasAnyRow = merged.isNotEmpty;
    _slidingWindowUserExpanded = true;
  }

  List<V2TimConversation> get conversations =>
      List.unmodifiable(_conversations);

  /// 虚拟列表：该类型已水合窗的起始 offset。
  int hydratedStartOffsetForType(int convType) {
    if (convType != 1 && convType != 2) {
      return 0;
    }
    return _typeHydrateStart[convType] ?? 0;
  }

  /// 虚拟列表：该类型已水合窗内条数。
  int hydratedLengthForType(int convType) {
    if (convType != 1 && convType != 2) {
      return 0;
    }
    return (_typeHydrate[convType] ?? const <V2TimConversation>[]).length;
  }

  /// 虚拟列表：该类型已水合窗的结束 offset（不含）。
  int hydratedEndOffsetForType(int convType) {
    if (convType != 1 && convType != 2) {
      return 0;
    }
    final start = _typeHydrateStart[convType] ?? 0;
    final len = (_typeHydrate[convType] ?? const <V2TimConversation>[]).length;
    final consumed = _typeAppendConsumed[convType] ?? 0;
    final end = start + len;
    return end > consumed ? end : consumed;
  }

  /// Live hydrate page only — ignores [_typeIndexSnapshotCache].
  /// Chat-return skip checks must use this; cache hits at a distant index
  /// would skip jump-hydrate after snapshot seed reset start to 0.
  bool isTypeIndexLiveHydrated(int convType, int index) {
    if ((convType != 1 && convType != 2) || index < 0) {
      return false;
    }
    final start = _typeHydrateStart[convType] ?? 0;
    final page = _typeHydrate[convType] ?? const <V2TimConversation>[];
    final local = index - start;
    return local >= 0 && local < page.length;
  }

  int _typeIndexSnapshotCacheMaxPerType() {
    return (ConversationPerfFlags.virtualHydrateMaxPerType * 4)
        .clamp(240, 720)
        .toInt();
  }

  void _clearTypeIndexSnapshotCache() {
    for (final cache in _typeIndexSnapshotCache.values) {
      cache.clear();
    }
  }

  void _cacheTypeIndexConversation(
    int convType,
    int index,
    V2TimConversation conversation,
  ) {
    final cache = _typeIndexSnapshotCache[convType];
    if (cache == null) {
      return;
    }
    cache.remove(index);
    cache[index] = conversation;
    final maxEntries = _typeIndexSnapshotCacheMaxPerType();
    while (cache.length > maxEntries) {
      cache.remove(cache.keys.first);
    }
  }

  void _cacheTypeIndexPage(
    int convType,
    int start,
    List<V2TimConversation> page,
  ) {
    for (var i = 0; i < page.length; i++) {
      _cacheTypeIndexConversation(convType, start + i, page[i]);
    }
  }

  /// 虚拟列表：会话 id → 类型序 index；未在水合窗内返回 null。
  int? typeIndexOfConversationId(int convType, String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty || (convType != 1 && convType != 2)) {
      return null;
    }
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      ensureTabStoreBridgeAttached();
      return ConversationTabStore.instance.typeIndexOf(convType, id);
    }
    final start = _typeHydrateStart[convType] ?? 0;
    final page = _typeHydrate[convType] ?? const <V2TimConversation>[];
    for (var i = 0; i < page.length; i++) {
      final cid = page[i].conversationID.trim();
      if (cid == id) {
        return start + i;
      }
    }
    return null;
  }

  /// 虚拟列表：该类型在库内的总数（可滚 item 数上界）。
  int totalCountForType(int convType) {
    if (convType != 1 && convType != 2) {
      return 0;
    }
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      ensureTabStoreBridgeAttached();
      final store = ConversationTabStore.instance;
      final n = store.countForType(convType);
      if (n <= 0) {
        return 0;
      }
      if (store.finishedForType(convType)) {
        return n;
      }
      // 未拉完：多留一页余量，便于触底继续 loadMore。
      return n + ConversationTabStore.defaultPageSize;
    }
    return _typeTotalCount[convType] ?? 0;
  }

  /// 虚拟列表：取类型序 index 处已水合会话；未水合返回 null。
  V2TimConversation? conversationAtTypeIndex(int convType, int index) {
    if ((convType != 1 && convType != 2) || index < 0) {
      return null;
    }
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      ensureTabStoreBridgeAttached();
      return ConversationTabStore.instance.atTypeIndex(convType, index);
    }
    final start = _typeHydrateStart[convType] ?? 0;
    final page = _typeHydrate[convType] ?? const <V2TimConversation>[];
    final local = index - start;
    if (local < 0 || local >= page.length) {
      return _typeIndexSnapshotCache[convType]?[index];
    }
    return page[local];
  }

  /// 虚拟列表读 `_typeHydrate`：本地 pin/recvOpt/lastMessage 必须同步 patch，
  /// 否则只会改 `_conversations`，列表行仍显示旧值直到晚到的 hydrate_page。
  int? _patchTypeHydrateConversation(
    String conversationID, {
    required V2TimConversation Function(V2TimConversation current) update,
    bool reorder = false,
    String field = 'unknown',
  }) {
    // Phase4：sdkPrimary 时 UI 权威在 TabStore，停掉 hydrate 双写。
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      return null;
    }
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    // 按前缀只扫对应类型页，避免单聊补丁扫进群 hydrate（裸 id 仍双扫）。
    final typesToScan = MessageConversationId.looksLikeC2cConversationId(id)
        ? const <int>[1]
        : (MessageConversationId.looksLikeGroupConversationId(id)
            ? const <int>[2]
            : const <int>[1, 2]);
    for (final type in typesToScan) {
      final page = _typeHydrate[type];
      if (page == null || page.isEmpty) {
        continue;
      }
      final start = _typeHydrateStart[type] ?? 0;
      for (var i = 0; i < page.length; i++) {
        if (!MessageConversationId.sameConversation(
          page[i].conversationID,
          id,
        )) {
          continue;
        }
        final nextPage = List<V2TimConversation>.from(page);
        nextPage[i] = update(page[i]);
        if (reorder && nextPage.length > 1) {
          nextPage.sort(ConversationLocalStore.compareConversationsForUi);
        }
        _typeHydrate[type] = nextPage;
        if (reorder) {
          _clearTypeIndexSnapshotCache();
        }
        _cacheTypeIndexPage(type, start, nextPage);
        ConversationPerfGateLog.log(
          'type_hydrate_patched',
          extras: <String, Object?>{
            'convType': type,
            'conversationID': id,
            'field': field,
            'reordered': reorder,
          },
        );
        return type;
      }
    }
    return null;
  }

  /// apply_store 后：把已写入 next 的行同步进 hydrate（含 unread）。
  /// 返回是否真正改了 hydrate 内容。
  ///
  /// 取消归档等场景：行曾被 [_removeFromTypeHydrate] / purge 掉，
  /// 仅 patch 不会插入 → 虚拟列表 `conversationAtTypeIndex` 读不到，
  /// 返回会话列表会晚一拍或一直骨架。头窗（start==0）时直接插入。
  bool _syncTypeHydrateRowFromApplied({
    required V2TimConversation row,
    required bool reorder,
  }) {
    final id = row.conversationID.trim();
    if (id.isEmpty) {
      return false;
    }
    var changed = false;
    final patchedType = _patchTypeHydrateConversation(
      id,
      update: (current) {
        if (conversationUiFingerprint(current) ==
            conversationUiFingerprint(row)) {
          return current;
        }
        changed = true;
        return row;
      },
      reorder: reorder,
      field: 'apply_store',
    );
    if (patchedType != null) {
      return changed;
    }
    return _insertRowIntoTypeHydrateHeadWindow(row);
  }

  /// 仅在类型水合头窗（start==0）插入缺失行，避免非头窗错位。
  bool _insertRowIntoTypeHydrateHeadWindow(V2TimConversation row) {
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      return false;
    }
    if (!ConversationPerfFlags.conversationVirtualListEnabled) {
      return false;
    }
    final id = row.conversationID.trim();
    if (id.isEmpty) {
      return false;
    }
    final type = _isGroupConversation(row) ? 2 : 1;
    final start = _typeHydrateStart[type] ?? 0;
    if (start != 0) {
      return false;
    }
    final page = List<V2TimConversation>.from(
      _typeHydrate[type] ?? const <V2TimConversation>[],
    );
    if (page.any(
      (c) => MessageConversationId.sameConversation(c.conversationID, id),
    )) {
      return false;
    }
    page.add(row);
    if (page.length > 1) {
      page.sort(ConversationLocalStore.compareConversationsForUi);
    }
    _clearTypeIndexSnapshotCache();
    _typeHydrate[type] = page;
    _cacheTypeIndexPage(type, 0, page);
    ConversationPerfGateLog.log(
      'type_hydrate_inserted',
      extras: <String, Object?>{
        'convType': type,
        'conversationID': id,
        'pageLen': page.length,
      },
    );
    return true;
  }

  void _removeFromTypeHydrate(String conversationID) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    for (final type in const [1, 2]) {
      final page = _typeHydrate[type];
      if (page == null || page.isEmpty) {
        continue;
      }
      final next = page
          .where(
            (c) => !MessageConversationId.sameConversation(
              c.conversationID,
              id,
            ),
          )
          .toList();
      if (next.length != page.length) {
        _clearTypeIndexSnapshotCache();
        _typeHydrate[type] = next;
      }
    }
  }

  void _seedTypeHydrateFromConversations() {
    if (!ConversationPerfFlags.conversationVirtualListEnabled) {
      return;
    }
    _clearTypeIndexSnapshotCache();
    for (final type in const [1, 2]) {
      final preferGroups = type == 2;
      final typed = _conversations
          .where((c) => _isGroupConversation(c) == preferGroups)
          .toList(growable: false);
      _typeHydrate[type] = typed;
      _typeHydrateStart[type] = 0;
      _cacheTypeIndexPage(type, 0, typed);
      final total = _typeTotalCount[type] ?? 0;
      if (total < typed.length) {
        _typeTotalCount[type] = typed.length;
      }
    }
  }

  @visibleForTesting
  void setTypeHydrateForTest({
    required int convType,
    required List<V2TimConversation> page,
    int start = 0,
    int? total,
  }) {
    if (convType != 1 && convType != 2) {
      return;
    }
    _typeHydrate[convType] = List<V2TimConversation>.from(page);
    _typeHydrateStart[convType] = start;
    _cacheTypeIndexPage(convType, start, page);
    if (total != null) {
      _typeTotalCount[convType] = total;
    }
  }

  /// 主列表虚拟序要排除的归档原始 ID（按类型）。
  Set<String>? _excludeArchivedIdsForType(int convType) {
    if (!ConversationPerfFlags.virtualListExcludeArchivedEnabled) {
      return null;
    }
    if (convType == 2) {
      return archivedConversationGroupIDsNotifier.value;
    }
    if (convType == 1) {
      return archivedConversationC2cIDsNotifier.value;
    }
    return null;
  }

  bool _isArchivedForMainList(V2TimConversation conversation) {
    if (!ConversationPerfFlags.virtualListExcludeArchivedEnabled &&
        !ConversationPerfFlags.purgeUiOnArchiveChangeEnabled &&
        !ConversationPerfFlags.archiveChangeMainListSyncEnabled) {
      return false;
    }
    final id = conversation.conversationID.trim();
    if (id.isEmpty) {
      return false;
    }
    if (_isGroupConversation(conversation)) {
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

  /// 刷新单聊/群库内条数（可选排除归档）。
  Future<void> refreshTypeTotals() async {
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      ensureTabStoreBridgeAttached();
      ConversationTabStore.instance.purgeArchived(notify: false);
      final c2cStore = ConversationTabStore.instance.countForType(1);
      final groupStore = ConversationTabStore.instance.countForType(2);
      final c2c = ConversationTabStore.instance.finishedForType(1)
          ? c2cStore
          : (c2cStore == 0
              ? 0
              : c2cStore + ConversationTabStore.defaultPageSize);
      final group = ConversationTabStore.instance.finishedForType(2)
          ? groupStore
          : (groupStore == 0
              ? 0
              : groupStore + ConversationTabStore.defaultPageSize);
      final changed = (_typeTotalCount[1] ?? 0) != c2c ||
          (_typeTotalCount[2] ?? 0) != group;
      _typeTotalCount[1] = c2c;
      _typeTotalCount[2] = group;
      _adoptTabStoreIntoNotifierWindows();
      ConversationPerfGateLog.log(
        'virtual_total',
        extras: <String, Object?>{
          'c2c': c2c,
          'group': group,
          'ui_source': 'sdk_store',
          'changed': changed,
        },
      );
      _bumpRevisionsForChange(orderOrMembershipChanged: true);
      _notifyIfAllowed(reason: 'virtual_total');
      return;
    }
    final c2c = await ConversationLocalStore.instance.countByConvType(
      convType: 1,
      excludeConversationIds: _excludeArchivedIdsForType(1),
    );
    final group = await ConversationLocalStore.instance.countByConvType(
      convType: 2,
      excludeConversationIds: _excludeArchivedIdsForType(2),
    );
    final changed =
        (_typeTotalCount[1] ?? 0) != c2c || (_typeTotalCount[2] ?? 0) != group;
    _typeTotalCount[1] = c2c;
    _typeTotalCount[2] = group;
    if (changed) {
      ConversationPerfGateLog.log(
        'virtual_total',
        extras: <String, Object?>{'c2c': c2c, 'group': group},
      );
      _bumpRevisionsForChange(orderOrMembershipChanged: true);
      _notifyIfAllowed(reason: 'virtual_total');
    }
  }

  bool _archiveListenersAttached = false;
  Future<void>? _archiveSyncInFlight;
  final Set<String> _pendingArchiveRestoredIds = <String>{};
  final Set<String> _pendingArchiveRemovedIds = <String>{};

  /// 进程级只挂一次：避免双 Tab 各调一遍 purge 打爆 TEMP 并发。
  void ensureArchiveChangeListenersAttached() {
    ensureTabStoreBridgeAttached();
    if (_archiveListenersAttached) {
      return;
    }
    _archiveListenersAttached = true;
    archivedConversationC2cIDsNotifier.addListener(_onArchivedIdsChangedGlobal);
    archivedConversationGroupIDsNotifier
        .addListener(_onArchivedIdsChangedGlobal);
  }

  void _onArchivedIdsChangedGlobal() {
    unawaited(
      syncMainListAfterArchiveChange(reason: 'archived_ids_changed'),
    );
  }

  /// 归档/取消归档后同步主列表：purge + 恢复回灌 + totals。
  Future<void> syncMainListAfterArchiveChange({
    Iterable<String> restoredIds = const [],
    Iterable<String> removedIds = const [],
    String reason = 'archive_change',
  }) async {
    if (!ConversationPerfFlags.archiveChangeMainListSyncEnabled &&
        !ConversationPerfFlags.purgeUiOnArchiveChangeEnabled) {
      return;
    }
    for (final raw in restoredIds) {
      final id = raw.trim();
      if (id.isNotEmpty) {
        _pendingArchiveRestoredIds.add(id);
        // 恢复优先于移除 hint，避免同批冲突时误删。
        _pendingArchiveRemovedIds.remove(id);
      }
    }
    for (final raw in removedIds) {
      final id = raw.trim();
      if (id.isEmpty || _pendingArchiveRestoredIds.contains(id)) {
        continue;
      }
      _pendingArchiveRemovedIds.add(id);
    }
    if (ConversationPerfFlags.archiveChangeSyncSingleFlight &&
        _archiveSyncInFlight != null) {
      return _archiveSyncInFlight!;
    }
    final task = _runArchiveMainListSync(reason: reason);
    _archiveSyncInFlight = task;
    try {
      await task;
    } finally {
      if (identical(_archiveSyncInFlight, task)) {
        _archiveSyncInFlight = null;
      }
    }
    // 尾部合入：单飞结束瞬间又有 pending 时再踢一轮，避免 orphan。
    if (_pendingArchiveRestoredIds.isNotEmpty ||
        _pendingArchiveRemovedIds.isNotEmpty) {
      return syncMainListAfterArchiveChange(reason: '$reason:tail');
    }
  }

  Future<void> _runArchiveMainListSync({required String reason}) async {
    var loops = 0;
    do {
      loops++;
      final restored = _pendingArchiveRestoredIds.toList(growable: false);
      final removed = _pendingArchiveRemovedIds.toList(growable: false);
      _pendingArchiveRestoredIds.clear();
      _pendingArchiveRemovedIds.clear();

      if (ConversationPerfFlags.conversationListSdkPrimary) {
        ensureTabStoreBridgeAttached();
        ConversationTabStore.instance.purgeArchived();
        if (removed.isNotEmpty) {
          ConversationTabStore.instance.applyDeleted(removed);
        }
        var restoredApplied = 0;
        if (restored.isNotEmpty) {
          try {
            final rows =
                await ConversationLocalStore.instance.conversationsByIds(
              restored,
              caller: 'archive_restore_sdk',
            );
            final admit = rows
                .where((c) => !_isArchivedForMainList(c))
                .toList(growable: false);
            if (admit.isNotEmpty) {
              ConversationTabStore.instance.applyPatches(
                admit,
                reason: 'archive_restore',
              );
              restoredApplied = admit.length;
            }
          } catch (e, st) {
            debugPrint('archive restore sdk-primary failed: $e\n$st');
          }
        }
        await refreshTypeTotals();
        ConversationPerfGateLog.log(
          'archive_main_sync',
          extras: <String, Object?>{
            'reason': reason,
            'loop': loops,
            'sdkPrimary': true,
            'restoredReq': restored.length,
            'restoredApplied': restoredApplied,
            'removedHint': removed.length,
            'c2cTotal': _typeTotalCount[1],
            'groupTotal': _typeTotalCount[2],
            'ui_source': 'sdk_store',
          },
        );
        continue;
      }

      final before = _conversations.length;
      _purgeArchivedFromWindows();
      if (removed.isNotEmpty) {
        for (final id in removed) {
          _conversations.removeWhere(
            (c) => MessageConversationId.sameConversation(c.conversationID, id),
          );
          for (final type in const [1, 2]) {
            final page = _typeHydrate[type];
            if (page == null || page.isEmpty) {
              continue;
            }
            _typeHydrate[type] = page
                .where(
                  (c) => !MessageConversationId.sameConversation(
                    c.conversationID,
                    id,
                  ),
                )
                .toList();
          }
        }
      }
      final purgedWindow = before - _conversations.length;

      var restoredApplied = 0;
      if (restored.isNotEmpty) {
        try {
          final rows = await ConversationLocalStore.instance.conversationsByIds(
            restored,
            caller: 'archive_restore',
          );
          final admit = rows
              .where((c) => !_isArchivedForMainList(c))
              .toList(growable: false);
          if (admit.isNotEmpty) {
            final forceAdmitIds = <String>{
              for (final c in admit)
                if (c.conversationID.trim().isNotEmpty) c.conversationID.trim(),
            };
            await applyConversationsFromStore(
              upserted: admit,
              forceAdmitIds: forceAdmitIds,
            );
            restoredApplied = admit.length;
            // 非头窗时 insert 可能失败：强制头窗重水合，保证返回列表立刻可见。
            final types = <int>{
              for (final c in admit) _isGroupConversation(c) ? 2 : 1,
            };
            for (final type in types) {
              final page = _typeHydrate[type] ?? const <V2TimConversation>[];
              final inHead = (_typeHydrateStart[type] ?? 0) == 0 &&
                  page.any(
                    (c) => forceAdmitIds.any(
                      (id) => MessageConversationId.sameConversation(
                        c.conversationID,
                        id,
                      ),
                    ),
                  );
              if (!inHead) {
                unawaited(
                  ensureTypeIndexHydrated(
                    convType: type,
                    centerIndex: 0,
                    forceReload: true,
                  ),
                );
              }
            }
          }
        } catch (e, st) {
          debugPrint('archive restore apply failed: $e\n$st');
        }
      }

      await refreshTypeTotals();
      ConversationPerfGateLog.log(
        'archive_main_sync',
        extras: <String, Object?>{
          'reason': reason,
          'loop': loops,
          'purgedWindow': purgedWindow,
          'restoredReq': restored.length,
          'restoredApplied': restoredApplied,
          'removedHint': removed.length,
          'c2cTotal': _typeTotalCount[1],
          'groupTotal': _typeTotalCount[2],
        },
      );
      _notifyIfAllowed(reason: 'archive_main_sync');
    } while (_pendingArchiveRestoredIds.isNotEmpty ||
        _pendingArchiveRemovedIds.isNotEmpty);
  }

  void _purgeArchivedFromWindows() {
    final c2cLookup = buildArchiveLookupTokenSet(
      archivedConversationC2cIDsNotifier.value,
    );
    final groupLookup = buildArchiveLookupTokenSet(
      archivedConversationGroupIDsNotifier.value,
    );
    bool isArchived(V2TimConversation c) {
      final id = c.conversationID.trim();
      if (id.isEmpty) {
        return false;
      }
      if (_isGroupConversation(c)) {
        return conversationIdInArchivedLookup(groupLookup, id);
      }
      return conversationIdInArchivedLookup(c2cLookup, id);
    }

    // 归档未读立刻从底部导航扣掉：等 store refresh 会有防抖窗口。
    final unreadDeltas = <ConversationUnreadDelta>[];
    for (final conversation in _conversations) {
      if (!isArchived(conversation)) {
        continue;
      }
      // 旧贡献按「未归档」口径：用 notifiableUnreadCount（免打扰仍为 0）。
      final oldN = ConversationUnreadUtils.notifiableUnreadCount(conversation);
      if (oldN <= 0) {
        continue;
      }
      unreadDeltas.add(
        ConversationUnreadDelta(
          isGroup: _isGroupConversation(conversation),
          oldNotifiable: oldN,
          newNotifiable: 0,
        ),
      );
    }

    var purgedAny = false;
    final beforeWindowLen = _conversations.length;
    _conversations.removeWhere(isArchived);
    purgedAny = purgedAny || beforeWindowLen != _conversations.length;
    for (final type in const [1, 2]) {
      final page = _typeHydrate[type];
      if (page == null || page.isEmpty) {
        continue;
      }
      final next = page.where((c) => !isArchived(c)).toList();
      if (next.length != page.length) {
        purgedAny = true;
      }
      _typeHydrate[type] = next;
    }
    if (purgedAny) {
      _clearTypeIndexSnapshotCache();
    }
    if (unreadDeltas.isNotEmpty) {
      ConversationUnreadAggregate.instance.applyNotifiableDeltas(unreadDeltas);
    }
  }

  /// @Deprecated 请用 [syncMainListAfterArchiveChange]。
  Future<void> purgeArchivedFromUiWindow({String reason = 'archived_changed'}) {
    return syncMainListAfterArchiveChange(reason: reason);
  }

  @visibleForTesting
  bool get archiveSyncInFlightForTest => _archiveSyncInFlight != null;

  @visibleForTesting
  int get pendingArchiveRestoredCountForTest =>
      _pendingArchiveRestoredIds.length;

  @visibleForTesting
  int get pendingArchiveRemovedCountForTest => _pendingArchiveRemovedIds.length;

  /// 围绕类型序 centerIndex 水合一页（虚拟列表）。
  /// [forceReload]=true 时绕过 covered skip，用于置顶写库后校正全局序。
  Future<void> ensureTypeIndexHydrated({
    required int convType,
    required int centerIndex,
    bool forceReload = false,
    bool allowWindowJump = false,
    bool forceNotify = false,
  }) async {
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      ensureTabStoreBridgeAttached();
      await ConversationTabStore.instance.ensurePrimed(convType: convType);
      final store = ConversationTabStore.instance;
      final n = store.countForType(convType);
      if (!store.finishedForType(convType) &&
          (forceReload || centerIndex >= (n - 8).clamp(0, 1 << 30))) {
        await store.loadMore(convType: convType);
      }
      return;
    }
    if (!ConversationPerfFlags.conversationVirtualListEnabled) {
      return;
    }
    if (convType != 1 && convType != 2) {
      return;
    }
    final serial = ++_hydrateRequestSerial;
    final gate = Completer<void>();
    final previous = _hydrateInFlight;
    _hydrateInFlight = gate.future;
    try {
      if (previous != null) {
        await previous;
      }
      if (serial != _hydrateRequestSerial) {
        return;
      }
      await _ensureTypeIndexHydratedImpl(
        convType: convType,
        centerIndex: centerIndex,
        forceReload: forceReload,
        allowWindowJump: allowWindowJump,
        forceNotify: forceNotify,
      );
    } finally {
      if (identical(_hydrateInFlight, gate.future)) {
        _hydrateInFlight = null;
      }
      if (!gate.isCompleted) {
        gate.complete();
      }
    }
  }

  Future<void> _ensureTypeIndexHydratedImpl({
    required int convType,
    required int centerIndex,
    bool forceReload = false,
    bool allowWindowJump = false,
    bool forceNotify = false,
  }) async {
    final total = _typeTotalCount[convType] ?? 0;
    if (total <= 0) {
      // 总数未知时先刷一次；避免热路径每次 hydrate 都 count。
      await refreshTypeTotals();
    }
    final totalNow = _typeTotalCount[convType] ?? 0;
    if (totalNow <= 0) {
      return;
    }
    final radius = ConversationPerfFlags.virtualHydrateRadius;
    final maxPer = ConversationPerfFlags.virtualHydrateMaxPerType;
    final budget =
        maxPer > 0 ? maxPer : ConversationPerfFlags.uiAppendOlderMaxPerType;
    final curStart = _typeHydrateStart[convType] ?? 0;
    final cur = _typeHydrate[convType] ?? const <V2TimConversation>[];
    final curEnd = curStart + cur.length;

    // 禁止瞬移到库尾/库头：center 钳在当前水合邻域，否则 fling 会把窗打成几十条闪空。
    var center = centerIndex.clamp(0, totalNow > 0 ? totalNow - 1 : 0);
    if (cur.isNotEmpty && !allowWindowJump) {
      final minC = (curStart - radius).clamp(0, totalNow);
      final maxC = (curEnd + radius).clamp(0, totalNow);
      if (center < minC) {
        center = minC;
      } else if (center > maxC) {
        center = maxC;
      }
    }

    final start = (center - radius).clamp(0, totalNow);
    var limit = budget > 0 ? budget : radius * 2;
    if (start + limit > totalNow) {
      limit = totalNow - start;
    }
    if (limit <= 0) {
      return;
    }
    // 中心已在水合窗舒适区内则跳过（勿要求「理想新窗 ⊆ 旧窗」，
    // 否则 center+1 会使 start+1 永远越界、跟滚密刷掉帧）。
    final skipMargin = ConversationPerfFlags.virtualHydrateSkipMargin;
    if (!forceReload &&
        conversationVirtualHydrateCovered(
          center: center,
          curStart: curStart,
          curLength: cur.length,
          margin: skipMargin,
        )) {
      // 滚动中 cache-only 水合不会抬 expanded；停滑后若仍 skip，
      // 返回聊天会走 snapshot reload，把远端水合窗打回 0。
      if (conversationVirtualHydrateShouldNotifyOnCoveredSkip(
        forceNotify: forceNotify,
        slidingWindowUserExpanded: _slidingWindowUserExpanded,
        curStart: curStart,
        curIsNotEmpty: cur.isNotEmpty,
      )) {
        _bumpRevisionsForChange(orderOrMembershipChanged: false);
        _notifyIfAllowed(reason: 'hydrate_settle_covered');
      }
      return;
    }
    // 新窗与旧窗无交集且不相邻：拒绝（防 spacer/误索引整窗替换）。
    // 相邻页是正常连续滑动路径，不能当成 teleport，否则高速滑到水合窗边缘
    // 会永远补不上后续页，列表只剩 skeleton。
    if (cur.isNotEmpty && !allowWindowJump) {
      final newEnd = start + limit;
      final touchesOrOverlaps = newEnd >= curStart && start <= curEnd;
      if (!touchesOrOverlaps) {
        ConversationPerfGateLog.log(
          'hydrate_page_skip_teleport',
          extras: <String, Object?>{
            'convType': convType,
            'center': center,
            'start': start,
            'curStart': curStart,
            'curEnd': curEnd,
          },
        );
        return;
      }
    }
    final page = await ConversationLocalStore.instance.loadConvTypePage(
      convType: convType,
      offset: start,
      limit: limit,
      excludeConversationIds: _excludeArchivedIdsForType(convType),
    );
    _typeHydrateStart[convType] = start;
    _typeHydrate[convType] = page;
    _cacheTypeIndexPage(convType, start, page);
    final cacheOnlyWhileScrolling =
        _isFeedScrollingNow && !forceReload && !allowWindowJump;
    if (cacheOnlyWhileScrolling) {
      ConversationPerfGateLog.log(
        'hydrate_page_cache_only',
        extras: <String, Object?>{
          'convType': convType,
          'center': center,
          'start': start,
          'limit': page.length,
          'total': totalNow,
          'window': _conversations.length,
          'consumed': _typeAppendConsumed[convType],
        },
      );
      return;
    }
    // 禁止在此改写 consumed：consumed 只由 appendOlder 推进，否则会假耗尽。
    await _rebuildConversationsFromTypeHydrates();
    ConversationPerfGateLog.log(
      'hydrate_page',
      extras: <String, Object?>{
        'convType': convType,
        'center': center,
        'start': start,
        'limit': page.length,
        'total': totalNow,
        'window': _conversations.length,
        'consumed': _typeAppendConsumed[convType],
      },
    );
  }

  Future<void> _rebuildConversationsFromTypeHydrates() async {
    // Phase4：禁止 hydrate→整窗覆盖（sdkPrimary 由 TabStore adopt）。
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      return;
    }
    final c2c = _typeHydrate[1] ?? const <V2TimConversation>[];
    final group = _typeHydrate[2] ?? const <V2TimConversation>[];
    final merged = ConversationLocalStore.mergeConversationsForUi(c2c, group);
    if (merged.isEmpty) {
      return;
    }
    final withPins = await ConversationLocalStore.instance
        .ensurePinnedPresentInWindow(merged);
    withPins.sort(ConversationLocalStore.compareConversationsForUi);
    if (listsEqualForUi(_conversations, withPins) &&
        _sameConversationOrder(_conversations, withPins)) {
      return;
    }
    _conversations = withPins;
    _slidingWindowUserExpanded = true;
    _storeHasAnyRow = true;
    _bumpRevisionsForChange(orderOrMembershipChanged: true);
    _notifyIfAllowed(reason: 'hydrate_page');
  }

  /// 顺序或成员变化时递增（feed 结构重建信号）。
  int get structureRevision => _structureRevision;

  /// 字段 patch（未读/预览等）时递增；顺序不变也可涨。
  int get contentRevision => _contentRevision;

  bool get hasLocalData => _conversations.isNotEmpty || _storeHasAnyRow;

  void _bumpRevisionsForChange({required bool orderOrMembershipChanged}) {
    _contentRevision++;
    if (orderOrMembershipChanged) {
      _structureRevision++;
    }
  }

  bool get _isDeferringPinReorder => _deferredPinReorderTimer?.isActive == true;

  /// 置顶停顿重排窗口是否仍在进行（供 UI / 日志读取）。
  bool get isDeferringPinReorder => _isDeferringPinReorder;

  @visibleForTesting
  bool get reloadInFlightForTest => _reloadInFlight != null;

  /// 滑动窗 append/prepend 是否进行中（供 sync soft reload 避让）。
  bool get isUiPageLoadInFlight => _uiPageLoadInFlight != null;

  /// 用户是否已通过翻页扩展过当前 UI 列表（触底加载更多后为 true）。
  bool get slidingWindowUserExpanded => _slidingWindowUserExpanded;

  /// 视口锚点会话（保当前位置附近裁切用）。
  String? _viewportAnchorConversationId;

  String? get viewportAnchorConversationId => _viewportAnchorConversationId;

  /// 由会话列表滚动上报；空串清除。
  void updateViewportAnchor(String? conversationID) {
    final id = conversationID?.trim() ?? '';
    _viewportAnchorConversationId = id.isEmpty ? null : id;
  }

  @visibleForTesting
  static bool shouldBlockSnapshotWindowReload({
    required bool userExpanded,
    required bool scrolling,
    required bool pageLoadInFlight,
    required bool windowNonEmpty,
  }) {
    if (!windowNonEmpty) {
      return false;
    }
    // 只追加/历史滑动窗均适用：用户已扩展或滚动/翻页中，禁止热快照整窗覆盖。
    return userExpanded || scrolling || pageLoadInFlight;
  }

  bool get shouldBlockSnapshotWindowReloadNow {
    final scrolling = isFeedScrolling?.call() ?? false;
    return shouldBlockSnapshotWindowReload(
      userExpanded: _slidingWindowUserExpanded,
      scrolling: scrolling,
      pageLoadInFlight: isUiPageLoadInFlight,
      windowNonEmpty: _conversations.isNotEmpty,
    );
  }

  @visibleForTesting
  void markSlidingWindowUserExpandedForTest() {
    _slidingWindowUserExpanded = true;
  }

  @visibleForTesting
  int get notifySuppressDepthForTest => _notifySuppressDepth;

  @visibleForTesting
  bool get isDeferringPinReorderForTest => _isDeferringPinReorder;

  /// 置顶重排后由会话列表消费一次，用于滚动。
  ConversationPinReorderScrollHint? takePinReorderScrollHint() {
    final hint = _pinReorderScrollHint;
    _pinReorderScrollHint = null;
    return hint;
  }

  Future<void> reloadFromLocal() async {
    if (_reloadInFlight != null) {
      _reloadDirty = true;
      return _reloadInFlight!;
    }
    final task = _reloadFromLocalOnce();
    _reloadInFlight = task;
    try {
      await task;
    } finally {
      _reloadInFlight = null;
      if (_reloadDirty) {
        _reloadDirty = false;
        await reloadFromLocal();
      }
    }
  }

  /// loadUiWindow 撞上后台关库闸门时：等 resume/关库结束后再试一次。
  Future<List<V2TimConversation>> _loadUiWindowSoft() async {
    try {
      return await ConversationLocalStore.instance.loadUiWindow();
    } on SqfliteClosedForBackground {
      debugPrint(
        'ConversationListNotifier: loadUiWindow closed for background; '
        'waiting for open gate',
      );
      final allowed = await SqfliteLifecycleHost.waitUntilOpenAllowed();
      if (!allowed) {
        debugPrint(
          'ConversationListNotifier: loadUiWindow soft-skip '
          '(still closed after wait)',
        );
        return const <V2TimConversation>[];
      }
      try {
        return await ConversationLocalStore.instance.loadUiWindow();
      } on SqfliteClosedForBackground {
        debugPrint(
          'ConversationListNotifier: loadUiWindow soft-skip '
          '(still closed after retry)',
        );
        return const <V2TimConversation>[];
      }
    }
  }

  Future<void> _reloadFromLocalOnce() async {
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      ensureTabStoreBridgeAttached();
      await ConversationTabStore.instance.loadFirstPage(convType: 1);
      await ConversationTabStore.instance.loadFirstPage(convType: 2);
      await _reconcileLocalOnlyC2cAfterSdkReload();
      ConversationPerfGateLog.log(
        'ui_source',
        extras: <String, Object?>{'source': 'sdk_store', 'via': 'reload'},
      );
      return;
    }
    // 已扩展/滚动中：禁止热快照整窗覆盖，但必须合并刷新字段
    // （置顶/免打扰/预览/未读），否则列表会「假死」。
    if (shouldBlockSnapshotWindowReloadNow) {
      debugPrint(
        'ConversationListNotifier: reloadFromLocal merge-preserve '
        '(expanded=$_slidingWindowUserExpanded '
        'pageLoad=$isUiPageLoadInFlight)',
      );
      await _mergeReloadPreservingExpanded();
      return;
    }
    final list = await _loadUiWindowSoft();
    _storeHasAnyRow = list.isNotEmpty ||
        await ConversationLocalStore.instance.countRows() > 0;
    if (_isDeferringPinReorder) {
      ConversationPinFlickerLog.log(
        'reload_during_pin_defer',
        extras: <String, Object?>{
          'incomingCount': list.length,
          'orderBefore':
              ConversationPinFlickerLog.orderSnapshot(_conversations),
        },
      );
      _mergePreservingUiOrder(list);
      return;
    }
    if (listsEqualForUi(_conversations, list)) {
      if (ConversationPerfFlags.conversationVirtualListEnabled) {
        _seedHydratesFromConversations();
        await refreshTypeTotals();
      }
      return;
    }
    final orderChanged = !_sameConversationOrder(_conversations, list);
    ConversationPinFlickerLog.log(
      'reload_from_local',
      extras: <String, Object?>{
        'orderChanged': orderChanged,
        'orderBefore': ConversationPinFlickerLog.orderSnapshot(_conversations),
        'orderAfter': ConversationPinFlickerLog.orderSnapshot(list),
        'caller': ConversationPinFlickerLog.callerHint(),
      },
    );
    _conversations = list;
    if (ConversationPerfFlags.conversationVirtualListEnabled) {
      _seedHydratesFromConversations();
      await refreshTypeTotals();
    }
    _bumpRevisionsForChange(orderOrMembershipChanged: orderChanged);
    _notifyIfAllowed(reason: 'reload_from_local');
    ConversationUnreadAggregate.instance.scheduleRefresh(reason: 'reload');
  }

  /// SDK-primary 全量 reload 会 reset TabStore；IM 尚未建会话的 C2C 需从本地库补回。
  /// 仅补 UI 列表行，不调用 deleteConversation / clearHistory，不改动 IM 消息库与漫游。
  Future<void> _reconcileLocalOnlyC2cAfterSdkReload() async {
    if (!ConversationPerfFlags.conversationListSdkPrimary) {
      return;
    }
    try {
      final sdkC2c = ConversationTabStore.instance.itemsForType(1);
      final sdkIds = <String>{
        for (final c in sdkC2c)
          if (c.conversationID.trim().isNotEmpty) c.conversationID.trim(),
      };
      final localWindow = await _loadUiWindowSoft();
      final missing = <V2TimConversation>[];
      final forceAdmitIds = <String>{};
      for (final conversation in localWindow) {
        if (conversation.type != 1) {
          continue;
        }
        if (_isArchivedForMainList(conversation)) {
          continue;
        }
        final convId = conversation.conversationID.trim();
        if (convId.isEmpty) {
          continue;
        }
        if (ConversationLocalStore.instance
            .shouldSuppressConversationDeletionAfterHistoryClear(convId)) {
          continue;
        }
        final inSdk = sdkIds.any(
          (id) => MessageConversationId.sameConversation(id, convId),
        );
        if (inSdk) {
          continue;
        }
        missing.add(conversation);
        forceAdmitIds.add(convId);
      }
      if (missing.isEmpty) {
        return;
      }
      await applyConversationsFromStore(
        upserted: missing,
        forceAdmitIds: forceAdmitIds,
      );
    } catch (e, st) {
      debugPrint(
        'ConversationListNotifier: reconcile local C2C after SDK reload failed: $e\n$st',
      );
    }
  }

  void _seedHydratesFromConversations() {
    for (final type in const <int>[1, 2]) {
      final preferGroups = type == 2;
      final typed = _conversations
          .where((c) => _isGroupConversation(c) == preferGroups)
          .toList(growable: false);
      final curStart = _typeHydrateStart[type] ?? 0;
      final cur = _typeHydrate[type] ?? const <V2TimConversation>[];
      // 远端视口水合（下滑中间）禁止被热快照 seed 瞬移到 start=0，
      // 否则返回会话列表后中间行变 skeleton。
      if (curStart > 0 && cur.isNotEmpty) {
        _typeAppendConsumed[type] ??= typed.length;
        if ((_typeAppendConsumed[type] ?? 0) < typed.length) {
          _typeAppendConsumed[type] = typed.length;
        }
        continue;
      }
      _typeHydrateStart[type] = 0;
      _typeHydrate[type] = typed;
      _cacheTypeIndexPage(type, 0, typed);
      _typeAppendConsumed[type] ??= typed.length;
      if ((_typeAppendConsumed[type] ?? 0) < typed.length) {
        _typeAppendConsumed[type] = typed.length;
      }
    }
  }

  void _syncTypeHydrateFromWindow(int typeFilter) {
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      return;
    }
    if (!ConversationPerfFlags.conversationVirtualListEnabled) {
      return;
    }
    if (typeFilter != 1 && typeFilter != 2) {
      return;
    }
    final preferGroups = typeFilter == 2;
    final typed = _conversations
        .where((c) => _isGroupConversation(c) == preferGroups)
        .toList(growable: false);
    final consumed = _typeAppendConsumed[typeFilter] ?? typed.length;
    final start = (consumed - typed.length).clamp(0, 1 << 30);
    _typeHydrateStart[typeFilter] = start;
    _typeHydrate[typeFilter] = typed;
    _cacheTypeIndexPage(typeFilter, start, typed);
  }

  int _softCapMaxPerType() {
    if (ConversationPerfFlags.conversationVirtualListEnabled &&
        ConversationPerfFlags.virtualHydrateMaxPerType > 0) {
      return ConversationPerfFlags.virtualHydrateMaxPerType;
    }
    return ConversationPerfFlags.uiAppendOlderMaxPerType;
  }

  /// 下滑 append 才用的裁切阈值：软顶内不裁，超过紧急上限才裁到紧急上限。
  int _appendTrimCapPerType() {
    final soft = _softCapMaxPerType();
    if (soft <= 0) {
      return 0;
    }
    final emergency = ConversationPerfFlags.uiAppendOlderEmergencyMaxPerType;
    if (emergency <= 0) {
      return soft;
    }
    return emergency < soft ? soft : emergency;
  }

  /// 保留已追加列表长度与成员：热快照合并字段/热准入。
  /// **禁止**整窗 `conversationsByIds`（无条数上限下列表可很长，整窗读会卡死）。
  Future<void> _mergeReloadPreservingExpanded() async {
    if (_conversations.isEmpty) {
      final list = await _loadUiWindowSoft();
      if (list.isEmpty) {
        return;
      }
      _conversations = list;
      _storeHasAnyRow = true;
      _bumpRevisionsForChange(orderOrMembershipChanged: true);
      _notifyIfAllowed(reason: 'reload_from_local');
      ConversationUnreadAggregate.instance.scheduleRefresh(reason: 'reload');
      return;
    }
    final hot = await _loadUiWindowSoft();
    _storeHasAnyRow = hot.isNotEmpty || _storeHasAnyRow;
    if (_isDeferringPinReorder) {
      _mergePreservingUiOrder(hot);
      return;
    }
    if (hot.isEmpty) {
      return;
    }
    await applyConversationsFromStore(upserted: hot);
  }

  /// soft 辅助：按条数帽选取 ID。`maxIds<=0` 返回窗内全部 ID（外加 extra）。
  /// 生产 soft/merge **不应**再对超大窗调用整窗 ByIds。
  static List<String> selectSoftReloadConversationIds({
    required List<V2TimConversation> window,
    String? anchorId,
    List<String> extraIds = const <String>[],
    int? maxIds,
  }) {
    final cap = maxIds ?? ConversationPerfFlags.softReloadByIdsMax;
    final extras = extraIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (window.isEmpty) {
      return extras;
    }
    if (cap <= 0) {
      final all = <String>{
        ...window
            .map((c) => c.conversationID.trim())
            .where((id) => id.isNotEmpty),
        ...extras,
      };
      return all.toList(growable: false);
    }
    if (window.length <= cap) {
      final all = <String>{
        ...window
            .map((c) => c.conversationID.trim())
            .where((id) => id.isNotEmpty),
        ...extras,
      };
      return all.toList(growable: false);
    }

    SqfliteLockProfileLog.event(
      'conversationsByIds_capped',
      extras: <String, Object?>{
        'countBefore': window.length,
        'countAfter': cap,
        'anchor': anchorId ?? '-',
      },
    );

    final selected = <String>{};
    void addId(String raw) {
      final id = raw.trim();
      if (id.isNotEmpty) {
        selected.add(id);
      }
    }

    for (final extra in extras) {
      addId(extra);
    }
    final pinnedReserve = ConversationPerfFlags.uiSlidingWindowPinnedReserve;
    var pinnedAdded = 0;
    for (final conversation in window) {
      if (conversation.isPinned != true) {
        continue;
      }
      addId(conversation.conversationID);
      pinnedAdded++;
      if (pinnedAdded >= pinnedReserve) {
        break;
      }
    }

    var anchorIndex = -1;
    final anchor = anchorId?.trim() ?? '';
    if (anchor.isNotEmpty) {
      for (var i = 0; i < window.length; i++) {
        if (MessageConversationId.sameConversation(
          window[i].conversationID,
          anchor,
        )) {
          anchorIndex = i;
          break;
        }
      }
    }
    if (anchorIndex < 0) {
      anchorIndex = window.length ~/ 2;
    }

    var radius = 0;
    while (selected.length < cap &&
        (anchorIndex - radius >= 0 || anchorIndex + radius < window.length)) {
      if (anchorIndex - radius >= 0) {
        addId(window[anchorIndex - radius].conversationID);
      }
      if (selected.length >= cap) {
        break;
      }
      if (radius > 0 && anchorIndex + radius < window.length) {
        addId(window[anchorIndex + radius].conversationID);
      }
      radius++;
    }
    return selected.take(cap).toList(growable: false);
  }

  Future<ConversationWindowSlideResult> appendOlderFromLocal({
    int? convType,
  }) async {
    if (_uiPageLoadInFlight != null) {
      return ConversationWindowSlideResult.empty;
    }
    // 取消进行中的回顶 Phase2，避免与触底互踩。
    _hotHeadPhase2Generation++;
    final gate = Completer<void>();
    _uiPageLoadInFlight = gate.future;
    try {
      return await _appendOlderFromLocalImpl(convType: convType);
    } finally {
      _uiPageLoadInFlight = null;
      if (!gate.isCompleted) {
        gate.complete();
      }
    }
  }

  Future<ConversationWindowSlideResult> _appendOlderFromLocalImpl({
    int? convType,
  }) async {
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      ensureTabStoreBridgeAttached();
      final typeFilter = convType == 1 || convType == 2 ? convType! : null;
      if (typeFilter == null) {
        final before1 = ConversationTabStore.instance.countForType(1);
        final before2 = ConversationTabStore.instance.countForType(2);
        await ConversationTabStore.instance.loadMore(convType: 1);
        await ConversationTabStore.instance.loadMore(convType: 2);
        final added =
            (ConversationTabStore.instance.countForType(1) - before1) +
                (ConversationTabStore.instance.countForType(2) - before2);
        return added > 0
            ? ConversationWindowSlideResult(added: added)
            : ConversationWindowSlideResult.empty;
      }
      if (ConversationTabStore.instance.countForType(typeFilter) == 0 &&
          !ConversationTabStore.instance.finishedForType(typeFilter)) {
        await ConversationTabStore.instance.loadFirstPage(convType: typeFilter);
        final n = ConversationTabStore.instance.countForType(typeFilter);
        return n > 0
            ? ConversationWindowSlideResult(added: n)
            : ConversationWindowSlideResult.empty;
      }
      final before = ConversationTabStore.instance.countForType(typeFilter);
      await ConversationTabStore.instance.loadMore(convType: typeFilter);
      final added =
          ConversationTabStore.instance.countForType(typeFilter) - before;
      return added > 0
          ? ConversationWindowSlideResult(added: added)
          : ConversationWindowSlideResult.empty;
    }
    if (_conversations.isEmpty) {
      await reloadFromLocal();
      return ConversationWindowSlideResult.empty;
    }
    if (!ConversationPerfFlags.uiSlidingWindowActive &&
        ConversationPerfFlags.uiWindowHardCapEnabled &&
        _conversations.length >= ConversationPerfFlags.uiWindowHardCap) {
      return ConversationWindowSlideResult.empty;
    }
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    final typed = _conversations.where((conversation) {
      if (typeFilter == null) {
        return true;
      }
      return _isGroupConversation(conversation) == (typeFilter == 2);
    });
    final typedCount = typed.length;

    // 下滑扩窗：按库序 OFFSET 续页（OFFSET 用已消费游标，裁窗后不能回退）。
    // 超过软上限后滑动裁切，避免无上限涨到数千条卡死主线程（见 hang .ips）。
    if (ConversationPerfFlags.uiAppendOlderGrowsWindow && typeFilter != null) {
      final dbTypeCountRaw =
          await ConversationLocalStore.instance.countByConvType(
        convType: typeFilter,
        excludeConversationIds: _excludeArchivedIdsForType(typeFilter),
      );
      // 计数异常偏低时（锁/切换 owner）勿误判耗尽，至少不低于窗内已有类型数。
      final dbTypeCount =
          dbTypeCountRaw < typedCount ? typedCount : dbTypeCountRaw;
      final consumed = _typeAppendConsumed[typeFilter] ?? typedCount;
      if (dbTypeCount <= consumed && dbTypeCountRaw >= typedCount) {
        ConversationPerfGateLog.log(
          'append_older_empty',
          extras: <String, Object?>{
            'convType': typeFilter,
            'reason': 'local_type_exhausted',
            'typedCount': typedCount,
            'consumed': consumed,
            'dbTypeCount': dbTypeCount,
            'dbTypeCountRaw': dbTypeCountRaw,
            'window': _conversations.length,
          },
        );
        return ConversationWindowSlideResult.empty;
      }
      final older = await ConversationLocalStore.instance.loadConvTypePage(
        convType: typeFilter,
        offset: consumed,
        limit: ConversationPerfFlags.uiScrollPageSize,
        excludeConversationIds: _excludeArchivedIdsForType(typeFilter),
      );
      if (older.isEmpty) {
        ConversationPerfGateLog.log(
          'append_older_empty',
          extras: <String, Object?>{
            'convType': typeFilter,
            'reason': 'offset_empty',
            'typedCount': typedCount,
            'consumed': consumed,
            'dbTypeCount': dbTypeCount,
            'window': _conversations.length,
          },
        );
        return ConversationWindowSlideResult.empty;
      }
      _typeAppendConsumed[typeFilter] = consumed + older.length;
      final next = List<V2TimConversation>.from(_conversations);
      final existing = next.map((c) => c.conversationID).toSet();
      var added = 0;
      for (final conversation in older) {
        final id = conversation.conversationID.trim();
        if (id.isEmpty || existing.contains(id)) {
          continue;
        }
        next.add(conversation);
        existing.add(id);
        added++;
      }
      if (added == 0) {
        ConversationPerfGateLog.log(
          'append_older_dup',
          extras: <String, Object?>{
            'convType': typeFilter,
            'fetched': older.length,
            'typedCount': typedCount,
            'consumed': _typeAppendConsumed[typeFilter],
            'dbTypeCount': dbTypeCount,
            'window': _conversations.length,
          },
        );
        return ConversationWindowSlideResult.empty;
      }
      next.sort(ConversationLocalStore.compareConversationsForUi);
      _slidingWindowUserExpanded = true;
      final softCap = _softCapMaxPerType();
      final appendCap = _appendTrimCapPerType();
      var trimmed = next;
      var trimmedFromStart = 0;
      var trimmedFromEnd = 0;
      final preferCount = next
          .where((c) => _isGroupConversation(c) == (typeFilter == 2))
          .length;
      // 真虚拟列表：可滚长度由 totalCount 决定，append 禁止头裁换窗（否则又变整批替换）。
      // 水合缓存体积由 ensureTypeIndexHydrated 的 budget 约束。
      final skipTrimForVirtual =
          ConversationPerfFlags.conversationVirtualListEnabled;
      if (!skipTrimForVirtual && appendCap > 0 && preferCount > appendCap) {
        final slide = _trimCappingPreferredType(
          next,
          preferConvType: typeFilter,
          maxPerType: appendCap,
        );
        trimmed = slide.list;
        trimmedFromStart = slide.trimmedFromStart;
        trimmedFromEnd = slide.trimmedFromEnd;
      }
      // 同步类型水合窗：虚拟模式下以本次窗为水合缓存，start 用 consumed-长度。
      if (skipTrimForVirtual) {
        final typedOnly = trimmed
            .where((c) => _isGroupConversation(c) == (typeFilter == 2))
            .toList(growable: false);
        final consumedNow = _typeAppendConsumed[typeFilter] ?? typedOnly.length;
        final start = (consumedNow - typedOnly.length).clamp(0, 1 << 30);
        _typeHydrateStart[typeFilter] = start;
        _typeHydrate[typeFilter] = typedOnly;
        _cacheTypeIndexPage(typeFilter, start, typedOnly);
        // 内存保护：水合超过 softCap 时只保留尾部（旧端），不改 total/itemCount。
        if (softCap > 0 && typedOnly.length > softCap) {
          final keep = typedOnly.sublist(typedOnly.length - softCap);
          _typeHydrate[typeFilter] = keep;
          _typeHydrateStart[typeFilter] =
              (consumedNow - keep.length).clamp(0, 1 << 30);
          _cacheTypeIndexPage(
            typeFilter,
            _typeHydrateStart[typeFilter] ?? 0,
            keep,
          );
          trimmed = [
            ...trimmed
                .where((c) => _isGroupConversation(c) != (typeFilter == 2)),
            ...keep,
          ]..sort(ConversationLocalStore.compareConversationsForUi);
        }
      }
      final beforeWindow = _conversations;
      _conversations = trimmed;
      final pinRestored = await _restorePinnedIntoWindowIfMissing();
      if (!pinRestored &&
          listsEqualForUi(beforeWindow, _conversations) &&
          _sameConversationOrder(beforeWindow, _conversations)) {
        return ConversationWindowSlideResult.empty;
      }
      _syncTypeHydrateFromWindow(typeFilter);
      if (ConversationPerfFlags.conversationVirtualListEnabled) {
        final dbCount = dbTypeCount;
        if ((_typeTotalCount[typeFilter] ?? 0) < dbCount) {
          _typeTotalCount[typeFilter] = dbCount;
        }
      }
      _bumpRevisionsForChange(orderOrMembershipChanged: true);
      _notifyIfAllowed(reason: 'append_older');
      ConversationUnreadAggregate.instance.scheduleRefresh(reason: 'append');
      ConversationPerfGateLog.log(
        'append_older_ok',
        extras: <String, Object?>{
          'convType': typeFilter,
          'added': added,
          'window': _conversations.length,
          'trimStart': trimmedFromStart,
          'trimEnd': trimmedFromEnd,
          'grows': trimmedFromStart == 0 && trimmedFromEnd == 0,
          'via': 'type_offset',
          'typedCount': trimmed
              .where((c) => _isGroupConversation(c) == (typeFilter == 2))
              .length,
          'consumed': _typeAppendConsumed[typeFilter],
          'dbTypeCount': dbTypeCount,
          'maxPerType': softCap,
          'appendCap': appendCap,
          'virtualTotal': _typeTotalCount[typeFilter],
          'pinned': _conversations.where(_isPinnedConversation).length,
        },
      );
      return ConversationWindowSlideResult(
        added: added,
        trimmedFromStart: trimmedFromStart,
        trimmedFromEnd: trimmedFromEnd,
      );
    }

    // 必须用库序最旧边（含置顶），不能用 UI 列表末项：置顶旧会话在顶部时，
    // UI 末项时间偏新会把窗内旧行再次查回来 → append_older_dup。
    var cursor = ConversationLocalStore.oldestPagingCursor(typed);
    if (cursor == null) {
      // 滑动窗下禁止因缺 type cursor 整窗打回快照。
      if (ConversationPerfFlags.uiSlidingWindowActive) {
        return ConversationWindowSlideResult.empty;
      }
      await reloadFromLocal();
      return ConversationWindowSlideResult.empty;
    }
    var older = await ConversationLocalStore.instance.loadOlderPage(
      beforeActiveTime: ConversationLocalStore.pagingAnchorMs(cursor),
      beforeConversationId: cursor.conversationID,
      limit: ConversationPerfFlags.uiScrollPageSize,
      convType: typeFilter,
    );
    var usedOffsetFallback = false;
    // 游标与库列漂移时（lastMessage≠active_time）会空翻，但库里其实还有未进窗行。
    if (older.isEmpty && typeFilter != null) {
      final dbTypeCount = await ConversationLocalStore.instance.countByConvType(
        convType: typeFilter,
        excludeConversationIds: _excludeArchivedIdsForType(typeFilter),
      );
      if (dbTypeCount > typedCount) {
        older = await ConversationLocalStore.instance.loadConvTypePage(
          convType: typeFilter,
          offset: typedCount,
          limit: ConversationPerfFlags.uiScrollPageSize,
          excludeConversationIds: _excludeArchivedIdsForType(typeFilter),
        );
        usedOffsetFallback = older.isNotEmpty;
        ConversationPerfGateLog.log(
          'append_older_offset_fallback',
          extras: <String, Object?>{
            'convType': typeFilter,
            'cursor': cursor.conversationID,
            'anchor': ConversationLocalStore.pagingAnchorMs(cursor),
            'typedCount': typedCount,
            'dbTypeCount': dbTypeCount,
            'fetched': older.length,
            'window': _conversations.length,
          },
        );
      }
    }
    if (older.isEmpty) {
      ConversationPerfGateLog.log(
        'append_older_empty',
        extras: <String, Object?>{
          'convType': typeFilter,
          'cursor': cursor.conversationID,
          'anchor': ConversationLocalStore.pagingAnchorMs(cursor),
          'typedCount': typedCount,
          'window': _conversations.length,
        },
      );
      return ConversationWindowSlideResult.empty;
    }
    final next = List<V2TimConversation>.from(_conversations);
    final existing = next.map((c) => c.conversationID).toSet();
    var added = 0;
    void absorb(List<V2TimConversation> page) {
      for (final conversation in page) {
        final id = conversation.conversationID.trim();
        if (id.isEmpty || existing.contains(id)) {
          continue;
        }
        next.add(conversation);
        existing.add(id);
        added++;
      }
    }

    absorb(older);
    // 仍全是窗内重复：越过该重复页再试一次，避免同几条空转刷屏。
    if (added == 0 && older.isNotEmpty && !usedOffsetFallback) {
      final advance = ConversationLocalStore.oldestPagingCursor(older);
      if (advance != null) {
        cursor = advance;
        older = await ConversationLocalStore.instance.loadOlderPage(
          beforeActiveTime: ConversationLocalStore.pagingAnchorMs(cursor),
          beforeConversationId: cursor.conversationID,
          limit: ConversationPerfFlags.uiScrollPageSize,
          convType: typeFilter,
        );
        if (older.isNotEmpty) {
          absorb(older);
        }
      }
    }
    // 游标页全重复时再用类型 OFFSET 兜底。
    if (added == 0 && typeFilter != null) {
      final dbTypeCount = await ConversationLocalStore.instance.countByConvType(
        convType: typeFilter,
        excludeConversationIds: _excludeArchivedIdsForType(typeFilter),
      );
      if (dbTypeCount > typedCount) {
        older = await ConversationLocalStore.instance.loadConvTypePage(
          convType: typeFilter,
          offset: typedCount,
          limit: ConversationPerfFlags.uiScrollPageSize,
          excludeConversationIds: _excludeArchivedIdsForType(typeFilter),
        );
        ConversationPerfGateLog.log(
          'append_older_offset_fallback',
          extras: <String, Object?>{
            'convType': typeFilter,
            'phase': 'after_dup',
            'typedCount': typedCount,
            'dbTypeCount': dbTypeCount,
            'fetched': older.length,
            'window': _conversations.length,
          },
        );
        absorb(older);
      }
    }
    if (added == 0) {
      ConversationPerfGateLog.log(
        'append_older_dup',
        extras: <String, Object?>{
          'convType': typeFilter,
          'fetched': older.length,
          'cursor': cursor.conversationID,
          'anchor': ConversationLocalStore.pagingAnchorMs(cursor),
          'window': _conversations.length,
        },
      );
      return ConversationWindowSlideResult.empty;
    }
    next.sort(ConversationLocalStore.compareConversationsForUi);
    // 先标记已扩展，避免未扩展热窗的类型地板裁掉刚 append 的更旧页。
    _slidingWindowUserExpanded = true;
    late final List<V2TimConversation> trimmed;
    var trimmedFromStart = 0;
    var trimmedFromEnd = 0;
    if (ConversationPerfFlags.uiAppendOlderGrowsWindow) {
      // 下滑只增不裁：显示数量随翻页增长，不再卡在 budget=120。
      trimmed = next;
    } else {
      final slide = _applySlidingOrHardTrim(
        next,
        preferConvType: typeFilter,
        trimFromStart: true,
        directionalPaging: true,
      );
      trimmed = slide.list;
      trimmedFromStart = slide.trimmedFromStart;
      trimmedFromEnd = slide.trimmedFromEnd;
    }
    if (listsEqualForUi(_conversations, trimmed) &&
        _sameConversationOrder(_conversations, trimmed)) {
      ConversationPerfGateLog.log(
        'append_older_noop',
        extras: <String, Object?>{
          'convType': typeFilter,
          'added': added,
          'window': _conversations.length,
        },
      );
      return ConversationWindowSlideResult.empty;
    }
    _conversations = trimmed;
    _bumpRevisionsForChange(orderOrMembershipChanged: true);
    _notifyIfAllowed(reason: 'append_older');
    ConversationUnreadAggregate.instance.scheduleRefresh(reason: 'append');
    ConversationPerfGateLog.log(
      'append_older_ok',
      extras: <String, Object?>{
        'convType': typeFilter,
        'added': added,
        'window': _conversations.length,
        'trimStart': trimmedFromStart,
        'trimEnd': trimmedFromEnd,
        'grows': ConversationPerfFlags.uiAppendOlderGrowsWindow,
      },
    );
    return ConversationWindowSlideResult(
      added: added,
      trimmedFromStart: trimmedFromStart,
      trimmedFromEnd: trimmedFromEnd,
    );
  }

  Future<ConversationWindowSlideResult> prependNewerFromLocal({
    int? convType,
    bool slideToHotPrefix = false,
  }) async {
    if (_uiPageLoadInFlight != null) {
      return ConversationWindowSlideResult.empty;
    }
    final gate = Completer<void>();
    _uiPageLoadInFlight = gate.future;
    try {
      return await _prependNewerFromLocalImpl(
        convType: convType,
        slideToHotPrefix: slideToHotPrefix,
      );
    } finally {
      _uiPageLoadInFlight = null;
      if (!gate.isCompleted) {
        gate.complete();
      }
    }
  }

  Future<ConversationWindowSlideResult> _prependNewerFromLocalImpl({
    int? convType,
    bool slideToHotPrefix = false,
  }) async {
    if (_conversations.isEmpty) {
      await reloadFromLocal();
      return ConversationWindowSlideResult.empty;
    }
    // 置顶始终补齐；整窗滑回热前缀仅「回到顶部」显式触发，避免上拉时闪跳。
    final pinRestored = await _restorePinnedIntoWindowIfMissing();
    var hotRestored = false;
    if (slideToHotPrefix) {
      hotRestored = await _restoreHotHeadIntoWindow(convType: convType);
    }
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    final typed = _conversations.where((conversation) {
      if (typeFilter == null) {
        return true;
      }
      return _isGroupConversation(conversation) == (typeFilter == 2);
    });
    final cursor = ConversationLocalStore.newestPagingCursor(typed);
    if (cursor == null) {
      return (pinRestored || hotRestored)
          ? const ConversationWindowSlideResult(added: 1)
          : ConversationWindowSlideResult.empty;
    }
    final newer = await ConversationLocalStore.instance.loadNewerPage(
      afterActiveTime: ConversationLocalStore.pagingAnchorMs(cursor),
      afterConversationId: cursor.conversationID,
      limit: ConversationPerfFlags.uiScrollPageSize,
      convType: typeFilter,
    );
    if (newer.isEmpty) {
      return (pinRestored || hotRestored)
          ? const ConversationWindowSlideResult(added: 1)
          : ConversationWindowSlideResult.empty;
    }
    final next = List<V2TimConversation>.from(_conversations);
    final existing = next.map((c) => c.conversationID).toSet();
    var added = 0;
    for (final conversation in newer) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty || existing.contains(id)) {
        continue;
      }
      next.add(conversation);
      existing.add(id);
      added++;
    }
    if (added == 0) {
      return (pinRestored || hotRestored)
          ? const ConversationWindowSlideResult(added: 1)
          : ConversationWindowSlideResult.empty;
    }
    next.sort(ConversationLocalStore.compareConversationsForUi);
    _slidingWindowUserExpanded = true;
    late final List<V2TimConversation> trimmed;
    var trimmedFromStart = 0;
    var trimmedFromEnd = 0;
    if (ConversationPerfFlags.uiAppendOlderGrowsWindow && typeFilter != null) {
      // 方案 C：超软顶时按视口连续切片；上拉贴热端裁旧尾。
      final maxPerType = ConversationPerfFlags.uiAppendOlderMaxPerType;
      final preferCount = next
          .where((c) => _isGroupConversation(c) == (typeFilter == 2))
          .length;
      if (maxPerType > 0 && preferCount > maxPerType) {
        final slide = _trimCappingPreferredType(
          next,
          preferConvType: typeFilter,
          maxPerType: maxPerType,
          preferOlderEnd: false,
        );
        trimmed = slide.list;
        trimmedFromStart = slide.trimmedFromStart;
        trimmedFromEnd = slide.trimmedFromEnd;
      } else {
        trimmed = next;
      }
    } else {
      final slide = _applySlidingOrHardTrim(
        next,
        preferConvType: typeFilter,
        trimFromStart: false,
        directionalPaging: true,
      );
      trimmed = slide.list;
      trimmedFromStart = slide.trimmedFromStart;
      trimmedFromEnd = slide.trimmedFromEnd;
    }
    if (listsEqualForUi(_conversations, trimmed) &&
        _sameConversationOrder(_conversations, trimmed)) {
      return (pinRestored || hotRestored)
          ? const ConversationWindowSlideResult(added: 1)
          : ConversationWindowSlideResult.empty;
    }
    _conversations = trimmed;
    await _restorePinnedIntoWindowIfMissing();
    _bumpRevisionsForChange(orderOrMembershipChanged: true);
    _notifyIfAllowed(reason: 'prepend_newer');
    ConversationUnreadAggregate.instance.scheduleRefresh(reason: 'prepend');
    ConversationPerfGateLog.log(
      'prepend_newer_ok',
      extras: <String, Object?>{
        'convType': typeFilter,
        'added': added,
        'window': _conversations.length,
        'trimStart': trimmedFromStart,
        'trimEnd': trimmedFromEnd,
        'pinRestored': pinRestored,
        'hotRestored': hotRestored,
        'slideToHot': slideToHotPrefix,
        'pinned': _conversations.where(_isPinnedConversation).length,
      },
    );
    return ConversationWindowSlideResult(
      added: added,
      trimmedFromStart: trimmedFromStart,
      trimmedFromEnd: trimmedFromEnd,
    );
  }

  /// 「回到顶部」：将该类型滑窗重置为库序热前缀并重置游标。
  Future<bool> slideToHotPrefix({int? convType}) {
    return _restoreHotHeadIntoWindow(convType: convType);
  }

  int _hotHeadPhase2Generation = 0;

  /// 方案 C：回顶时把该类型滑窗重置为库序连续前缀，并重置 consumed，
  /// 再下滑才能从热头之后连续加载（不会跳到很旧的已消费游标）。
  /// 两阶段开启时：先热头 reserve，再后台补满 soft-cap。
  Future<bool> _restoreHotHeadIntoWindow({int? convType}) async {
    final typeFilter = convType == 1 || convType == 2 ? convType : null;
    if (typeFilter == null) {
      return false;
    }
    final maxPerType = _softCapMaxPerType();
    final hotReserve = ConversationPerfFlags.uiAppendOlderHotHeadReserve;
    final fullLimit = maxPerType > 0
        ? maxPerType
        : (hotReserve > 0
            ? hotReserve
            : ConversationPerfFlags.uiScrollPageSize);
    if (fullLimit <= 0) {
      return false;
    }

    final twoPhase = ConversationPerfFlags.restoreHotHeadTwoPhaseEnabled &&
        hotReserve > 0 &&
        hotReserve < fullLimit;
    final phase1Limit = twoPhase ? hotReserve : fullLimit;

    final phase1 = await _applyHotHeadPrefix(
      typeFilter: typeFilter,
      prefixLimit: phase1Limit,
      maxPerType: maxPerType,
      phase: twoPhase ? 1 : 0,
    );

    if (twoPhase) {
      final gen = ++_hotHeadPhase2Generation;
      unawaited(
        _restoreHotHeadPhase2(
          typeFilter: typeFilter,
          prefixLimit: fullLimit,
          maxPerType: maxPerType,
          generation: gen,
        ),
      );
    }
    return phase1;
  }

  Future<void> _restoreHotHeadPhase2({
    required int typeFilter,
    required int prefixLimit,
    required int maxPerType,
    required int generation,
  }) async {
    // 让出一帧，保证 Phase1 notify / jumpTo(0) 先落地。
    await Future<void>.delayed(Duration.zero);
    if (generation != _hotHeadPhase2Generation) {
      return;
    }
    if (_uiPageLoadInFlight != null) {
      return;
    }
    final hotReserve = ConversationPerfFlags.uiAppendOlderHotHeadReserve;
    final consumed = _typeAppendConsumed[typeFilter] ?? 0;
    // 用户已触底越过 Phase1：取消补齐，避免整窗覆盖刚加载的旧页。
    if (hotReserve > 0 && consumed > hotReserve) {
      ConversationPerfGateLog.log(
        'restore_hot_head_phase2_skip',
        extras: <String, Object?>{
          'convType': typeFilter,
          'consumed': consumed,
          'hotReserve': hotReserve,
        },
      );
      return;
    }
    await _applyHotHeadPrefix(
      typeFilter: typeFilter,
      prefixLimit: prefixLimit,
      maxPerType: maxPerType,
      phase: 2,
    );
  }

  Future<bool> _applyHotHeadPrefix({
    required int typeFilter,
    required int prefixLimit,
    required int maxPerType,
    required int phase,
  }) async {
    if (prefixLimit <= 0) {
      return false;
    }
    final prefix = await ConversationLocalStore.instance.loadConvTypePage(
      convType: typeFilter,
      offset: 0,
      limit: prefixLimit,
      excludeConversationIds: _excludeArchivedIdsForType(typeFilter),
    );
    if (prefix.isEmpty) {
      return false;
    }

    final preferGroups = typeFilter == 2;
    final opposite = <V2TimConversation>[];
    for (final conversation in _conversations) {
      if (_isGroupConversation(conversation) != preferGroups) {
        opposite.add(conversation);
      }
    }
    final oppositeFloor = preferGroups
        ? ConversationPerfFlags.uiSnapshotC2cLimit
        : ConversationPerfFlags.uiSnapshotGroupLimit;
    final keptOpposite = oppositeFloor > 0 && opposite.length > oppositeFloor
        ? _capTypeListAroundViewport(
            opposite,
            maxPerType: oppositeFloor,
            preferOlderEnd: false,
            anchorId: _viewportAnchorConversationId,
          )
        : opposite;

    final next = <V2TimConversation>[...keptOpposite, ...prefix];
    next.sort(ConversationLocalStore.compareConversationsForUi);
    final withPins =
        await ConversationLocalStore.instance.ensurePinnedPresentInWindow(next);
    withPins.sort(ConversationLocalStore.compareConversationsForUi);

    final preferCount =
        withPins.where((c) => _isGroupConversation(c) == preferGroups).length;
    final trimmed = (maxPerType > 0 && preferCount > maxPerType)
        ? _trimCappingPreferredType(
            withPins,
            preferConvType: typeFilter,
            maxPerType: maxPerType,
            preferOlderEnd: false,
          ).list
        : withPins;

    final typedAfter =
        trimmed.where((c) => _isGroupConversation(c) == preferGroups).length;
    // 游标对齐到当前连续前缀末尾，后续触底从「热头之后」接着加载。
    _typeAppendConsumed[typeFilter] = typedAfter;

    if (listsEqualForUi(_conversations, trimmed) &&
        _sameConversationOrder(_conversations, trimmed)) {
      ConversationPerfGateLog.log(
        'restore_hot_head_noop',
        extras: <String, Object?>{
          'convType': typeFilter,
          'consumed': typedAfter,
          'window': _conversations.length,
          'phase': phase,
        },
      );
      return false;
    }
    _conversations = trimmed;
    _slidingWindowUserExpanded = true;
    _bumpRevisionsForChange(orderOrMembershipChanged: true);
    _notifyIfAllowed(
      reason: phase == 2 ? 'restore_hot_head_phase2' : 'restore_hot_head',
    );
    ConversationPerfGateLog.log(
      phase == 2 ? 'restore_hot_head_phase2' : 'restore_hot_head',
      extras: <String, Object?>{
        'convType': typeFilter,
        'prefix': prefix.length,
        'typed': typedAfter,
        'consumed': _typeAppendConsumed[typeFilter],
        'window': _conversations.length,
        'pinned': _conversations.where(_isPinnedConversation).length,
        'phase': phase,
      },
    );
    return true;
  }

  /// 把缺失的置顶会话补回当前窗（触底软裁曾误裁置顶时用）。
  Future<bool> _restorePinnedIntoWindowIfMissing() async {
    final before = _conversations.length;
    final beforePinned = _conversations.where(_isPinnedConversation).length;
    final withPins = await ConversationLocalStore.instance
        .ensurePinnedPresentInWindow(_conversations);
    final afterPinned = withPins.where(_isPinnedConversation).length;
    if (withPins.length == before &&
        afterPinned == beforePinned &&
        listsEqualForUi(_conversations, withPins)) {
      return false;
    }
    withPins.sort(ConversationLocalStore.compareConversationsForUi);
    _conversations = withPins;
    _bumpRevisionsForChange(orderOrMembershipChanged: true);
    _notifyIfAllowed(reason: 'restore_pinned');
    ConversationPerfGateLog.log(
      'restore_pinned',
      extras: <String, Object?>{
        'before': before,
        'after': _conversations.length,
        'pinned': _conversations.where(_isPinnedConversation).length,
      },
    );
    return true;
  }

  /// 双向滑动窗：超预算时保锚点附近 + 置顶；硬顶关闭时不拒收 append。
  /// [directionalPaging]=true 时触底保尾/触顶保头，并保住对侧类型地板。
  ({
    List<V2TimConversation> list,
    int trimmedFromStart,
    int trimmedFromEnd,
  }) _applySlidingOrHardTrim(
    List<V2TimConversation> sorted, {
    int? preferConvType,
    required bool trimFromStart,
    bool directionalPaging = false,
    int? budgetOverride,
  }) {
    final budget =
        budgetOverride ?? ConversationPerfFlags.uiSlidingWindowBudget;
    if (!ConversationPerfFlags.uiSlidingWindowActive &&
        budgetOverride == null) {
      final afterHard = _trimWindowKeepingHot(sorted);
      return (
        list: afterHard,
        trimmedFromStart: 0,
        trimmedFromEnd: 0,
      );
    }
    if (budget <= 0 || sorted.length <= budget) {
      return (
        list: List<V2TimConversation>.from(sorted),
        trimmedFromStart: 0,
        trimmedFromEnd: 0,
      );
    }
    if (directionalPaging && trimFromStart) {
      return _trimPreferringOlderEnd(
        sorted,
        budget: budget,
        preferConvType: preferConvType,
      );
    }
    if (directionalPaging && !trimFromStart) {
      return _trimPreferringNewerStart(
        sorted,
        budget: budget,
        preferConvType: preferConvType,
      );
    }
    final afterHot = _trimWindowKeepingHot(sorted);
    return trimAroundViewportAnchor(
      afterHot,
      anchorId: _viewportAnchorConversationId,
      budget: budget,
      pinnedReserve: ConversationPerfFlags.uiSlidingWindowPinnedReserve,
    );
  }

  /// 只裁当前翻页类型到 [maxPerType]，对侧类型保留；**置顶全留**。
  /// 方案 C：非置顶按视口锚点取**连续**切片（±N），不拆热头+旧尾造成断层。
  ({
    List<V2TimConversation> list,
    int trimmedFromStart,
    int trimmedFromEnd,
  }) _trimCappingPreferredType(
    List<V2TimConversation> sorted, {
    required int preferConvType,
    required int maxPerType,
    bool preferOlderEnd = true,
  }) {
    final preferGroups = preferConvType == 2;
    final preferred = <V2TimConversation>[];
    final opposite = <V2TimConversation>[];
    for (final conversation in sorted) {
      if (_isGroupConversation(conversation) == preferGroups) {
        preferred.add(conversation);
      } else {
        opposite.add(conversation);
      }
    }

    final keptPreferred = _capTypeListAroundViewport(
      preferred,
      maxPerType: maxPerType,
      preferOlderEnd: preferOlderEnd,
      anchorId: _viewportAnchorConversationId,
    );
    final trimmedPreferred =
        (preferred.length - keptPreferred.length).clamp(0, preferred.length);

    // 对侧：保留热端地板，保证另一 tab 不空。
    var keptOpposite = _capTypeListAroundViewport(
      opposite,
      maxPerType: maxPerType,
      preferOlderEnd: false,
      anchorId: _viewportAnchorConversationId,
    );
    final oppositeFloor = preferGroups
        ? ConversationPerfFlags.uiSnapshotC2cLimit
        : ConversationPerfFlags.uiSnapshotGroupLimit;
    if (oppositeFloor > 0 &&
        keptOpposite.length < oppositeFloor &&
        opposite.length >= oppositeFloor) {
      keptOpposite = _capTypeListAroundViewport(
        opposite,
        maxPerType: oppositeFloor,
        preferOlderEnd: false,
        anchorId: _viewportAnchorConversationId,
      );
    }

    final out = <V2TimConversation>[...keptOpposite, ...keptPreferred];
    out.sort(ConversationLocalStore.compareConversationsForUi);
    return (
      list: out,
      trimmedFromStart: trimmedPreferred,
      trimmedFromEnd: 0,
    );
  }

  /// 类型内软裁：全部置顶 + 非置顶在锚点附近的连续片段。
  List<V2TimConversation> _capTypeListAroundViewport(
    List<V2TimConversation> items, {
    required int maxPerType,
    required bool preferOlderEnd,
    String? anchorId,
  }) {
    if (maxPerType <= 0 || items.length <= maxPerType) {
      return List<V2TimConversation>.from(items);
    }
    final pins = <V2TimConversation>[];
    final rest = <V2TimConversation>[];
    for (final conversation in items) {
      if (_isPinnedConversation(conversation)) {
        pins.add(conversation);
      } else {
        rest.add(conversation);
      }
    }
    if (pins.length >= maxPerType) {
      return pins;
    }
    final room = maxPerType - pins.length;
    if (rest.length <= room) {
      return <V2TimConversation>[...pins, ...rest];
    }

    var anchorIndex = preferOlderEnd ? rest.length - 1 : 0;
    final anchor = anchorId?.trim() ?? '';
    if (anchor.isNotEmpty) {
      for (var i = 0; i < rest.length; i++) {
        if (MessageConversationId.sameConversation(
          rest[i].conversationID,
          anchor,
        )) {
          anchorIndex = i;
          break;
        }
      }
    }

    // 连续窗：尽量以锚点为中心；贴边时贴齐该边，保证视口附近无上下滑不断档。
    var start = anchorIndex - (room ~/ 2);
    if (start < 0) {
      start = 0;
    }
    if (start + room > rest.length) {
      start = rest.length - room;
    }
    // 触底翻页且锚点靠近旧端：优先贴旧端，避免中心切片把刚加载的旧页裁掉。
    if (preferOlderEnd && anchorIndex >= rest.length - (room ~/ 4)) {
      start = rest.length - room;
    }
    // 近顶且锚点靠近热端：优先贴热端。
    if (!preferOlderEnd && anchorIndex <= (room ~/ 4)) {
      start = 0;
    }
    return <V2TimConversation>[
      ...pins,
      ...rest.sublist(start, start + room),
    ];
  }

  static bool _isPinnedConversation(V2TimConversation conversation) {
    return conversation.isPinned == true ||
        ConversationPinSyncService.instance
            .isPinnedConversationId(conversation.conversationID);
  }

  /// 触底加载更旧：先保住对侧类型热地板 + 置顶，再从列表尾部（更旧）填满预算。
  ({
    List<V2TimConversation> list,
    int trimmedFromStart,
    int trimmedFromEnd,
  }) _trimPreferringOlderEnd(
    List<V2TimConversation> sorted, {
    required int budget,
    int? preferConvType,
  }) {
    final out = <V2TimConversation>[];
    final taken = <String>{};
    void take(V2TimConversation conversation) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty || taken.contains(id) || out.length >= budget) {
        return;
      }
      out.add(conversation);
      taken.add(id);
    }

    final pinLimit = ConversationPerfFlags.uiSlidingWindowPinnedReserve;
    var pinnedTaken = 0;
    for (final conversation in sorted) {
      if (conversation.isPinned != true) {
        continue;
      }
      take(conversation);
      pinnedTaken++;
      if (pinnedTaken >= pinLimit) {
        break;
      }
    }

    if (preferConvType == 1 || preferConvType == 2) {
      final pagingGroups = preferConvType == 2;
      final oppositeFloor = pagingGroups
          ? ConversationPerfFlags.uiSnapshotC2cLimit
          : ConversationPerfFlags.uiSnapshotGroupLimit;
      var oppositeTaken = 0;
      for (final conversation in sorted) {
        if (_isGroupConversation(conversation) == pagingGroups) {
          continue;
        }
        take(conversation);
        oppositeTaken++;
        if (oppositeTaken >= oppositeFloor) {
          break;
        }
      }
    }

    for (var i = sorted.length - 1; i >= 0 && out.length < budget; i--) {
      take(sorted[i]);
    }
    out.sort(ConversationLocalStore.compareConversationsForUi);
    final trimmedFromStart =
        (sorted.length - out.length).clamp(0, sorted.length);
    return (
      list: out,
      trimmedFromStart: trimmedFromStart,
      trimmedFromEnd: 0,
    );
  }

  /// 触顶加载更新：先保住对侧类型热地板 + 置顶，再从列表头部（更新）填满预算。
  ({
    List<V2TimConversation> list,
    int trimmedFromStart,
    int trimmedFromEnd,
  }) _trimPreferringNewerStart(
    List<V2TimConversation> sorted, {
    required int budget,
    int? preferConvType,
  }) {
    final out = <V2TimConversation>[];
    final taken = <String>{};
    void take(V2TimConversation conversation) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty || taken.contains(id) || out.length >= budget) {
        return;
      }
      out.add(conversation);
      taken.add(id);
    }

    final pinLimit = ConversationPerfFlags.uiSlidingWindowPinnedReserve;
    var pinnedTaken = 0;
    for (final conversation in sorted) {
      if (conversation.isPinned != true) {
        continue;
      }
      take(conversation);
      pinnedTaken++;
      if (pinnedTaken >= pinLimit) {
        break;
      }
    }

    if (preferConvType == 1 || preferConvType == 2) {
      final pagingGroups = preferConvType == 2;
      final oppositeFloor = pagingGroups
          ? ConversationPerfFlags.uiSnapshotC2cLimit
          : ConversationPerfFlags.uiSnapshotGroupLimit;
      var oppositeTaken = 0;
      for (final conversation in sorted) {
        if (_isGroupConversation(conversation) == pagingGroups) {
          continue;
        }
        take(conversation);
        oppositeTaken++;
        if (oppositeTaken >= oppositeFloor) {
          break;
        }
      }
    }

    for (var i = 0; i < sorted.length && out.length < budget; i++) {
      take(sorted[i]);
    }
    out.sort(ConversationLocalStore.compareConversationsForUi);
    final trimmedFromEnd = (sorted.length - out.length).clamp(0, sorted.length);
    return (
      list: out,
      trimmedFromStart: 0,
      trimmedFromEnd: trimmedFromEnd,
    );
  }

  /// 按视口锚点邻域裁切；[budget]<=0 时不裁。
  /// 用于 patch/热更新；翻页请走 [_trimPreferringOlderEnd]/[_trimPreferringNewerStart]。
  @visibleForTesting
  static ({
    List<V2TimConversation> list,
    int trimmedFromStart,
    int trimmedFromEnd,
  }) trimAroundViewportAnchor(
    List<V2TimConversation> sorted, {
    String? anchorId,
    int? budget,
    int? pinnedReserve,
  }) {
    final cap = budget ?? ConversationPerfFlags.uiSlidingWindowBudget;
    if (cap <= 0 || sorted.length <= cap) {
      return (
        list: List<V2TimConversation>.from(sorted),
        trimmedFromStart: 0,
        trimmedFromEnd: 0,
      );
    }

    var anchorIndex = -1;
    final anchor = anchorId?.trim() ?? '';
    if (anchor.isNotEmpty) {
      for (var i = 0; i < sorted.length; i++) {
        if (MessageConversationId.sameConversation(
          sorted[i].conversationID,
          anchor,
        )) {
          anchorIndex = i;
          break;
        }
      }
    }
    if (anchorIndex < 0) {
      anchorIndex = sorted.length ~/ 2;
    }

    final half = cap ~/ 2;
    var start = anchorIndex - half;
    if (start < 0) {
      start = 0;
    }
    var end = start + cap;
    if (end > sorted.length) {
      end = sorted.length;
      start = end - cap;
      if (start < 0) {
        start = 0;
      }
    }

    final kept = <String>{};
    final out = <V2TimConversation>[];
    void take(V2TimConversation conversation) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty || kept.contains(id)) {
        return;
      }
      if (out.length >= cap) {
        return;
      }
      out.add(conversation);
      kept.add(id);
    }

    final pinLimit =
        pinnedReserve ?? ConversationPerfFlags.uiSlidingWindowPinnedReserve;
    var pinnedTaken = 0;
    for (final conversation in sorted) {
      if (conversation.isPinned != true) {
        continue;
      }
      take(conversation);
      pinnedTaken++;
      if (pinnedTaken >= pinLimit) {
        break;
      }
    }
    // 未读热会话有限保留，禁止占满预算（大账号群几乎全未读）。
    final unreadReserve = ConversationPerfFlags.uiSlidingWindowUnreadReserve;
    if (unreadReserve > 0) {
      var unreadTaken = 0;
      for (final conversation in sorted) {
        if ((conversation.unreadCount ?? 0) <= 0) {
          continue;
        }
        take(conversation);
        unreadTaken++;
        if (unreadTaken >= unreadReserve || out.length >= cap) {
          break;
        }
      }
    }
    for (var i = start; i < end; i++) {
      take(sorted[i]);
    }
    // 预算未满：向锚点两侧继续扩。
    var radius = 0;
    while (out.length < cap &&
        (anchorIndex - radius >= 0 || anchorIndex + radius < sorted.length)) {
      if (anchorIndex - radius >= 0) {
        take(sorted[anchorIndex - radius]);
      }
      if (out.length >= cap) {
        break;
      }
      if (radius > 0 && anchorIndex + radius < sorted.length) {
        take(sorted[anchorIndex + radius]);
      }
      radius++;
    }

    out.sort(ConversationLocalStore.compareConversationsForUi);
    return (
      list: out,
      trimmedFromStart: start,
      trimmedFromEnd: sorted.length - end,
    );
  }

  /// 置顶/取消置顶：静默改 pin 状态 → 短延迟（侧滑收起）→ **一次**重排通知。
  ///
  /// 参考视频：侧滑收回后，项在视口内上移、邻居下移填空；不先刷灰再瞬移（那会造成双闪）。
  /// 视口不主动滚顶；重排后由 feed 按 hint 做 keepViewport 补偿。
  void applyPinnedWithDeferredReorder({
    required String conversationID,
    required bool isPinned,
    V2TimConversation? snapshot,
    Duration reorderDelay = pinReorderDelay,
    double? listScrollOffset,
    bool forceDeferred = false,
  }) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }

    // 二次调用（写库回写）且 pin+序已对齐：跳过再次 deferred，避免二次 structure bump。
    final alignedIdx = _conversations.indexWhere(
      (c) => MessageConversationId.sameConversation(c.conversationID, id),
    );
    if (alignedIdx >= 0) {
      final aligned = _conversations[alignedIdx];
      final pinMatches = (aligned.isPinned == true) == isPinned;
      final sortedProbe = List<V2TimConversation>.from(_conversations)
        ..sort(ConversationLocalStore.compareConversationsForUi);
      if (shouldSkipPinnedDeferredReorder(
        currentPinnedMatchesTarget: pinMatches,
        orderAlreadySorted: _sameConversationOrder(_conversations, sortedProbe),
      )) {
        ConversationPinFlickerLog.log(
          'pin_defer_skip_aligned',
          conversationID: id,
          extras: <String, Object?>{'isPinned': isPinned},
        );
        _patchTypeHydrateConversation(
          id,
          update: (_) => aligned,
          reorder: false,
          field: 'isPinned',
        );
        return;
      }
    }

    final next = List<V2TimConversation>.from(_conversations);
    final idx = next.indexWhere(
      (c) => MessageConversationId.sameConversation(c.conversationID, id),
    );
    var pinValueChanged = false;
    if (idx >= 0) {
      final current = next[idx];
      pinValueChanged = (current.isPinned == true) != isPinned;
      var orderKey = current.orderkey;
      if (!isPinned) {
        final active = ConversationLocalStore.activeTimeMs(current);
        if (active > 0) {
          orderKey = active;
        }
      }
      next[idx] = _cloneConversationWithPin(
        current,
        isPinned: isPinned,
        orderkey: orderKey,
      );
    } else if (snapshot != null) {
      final created = _cloneConversationWithPin(
        snapshot,
        isPinned: isPinned,
      );
      ConversationLocalStore.decorateConversationForUi(created);
      next.add(created);
      pinValueChanged = true;
    } else {
      ConversationPinFlickerLog.log(
        'pin_defer_miss_no_row',
        conversationID: id,
        extras: <String, Object?>{'isPinned': isPinned},
      );
      return;
    }

    _conversations = next;
    _deferredPinConversationId = id;
    _deferredPinTargetPinned = isPinned;

    // 虚拟列表读 hydrate：静默阶段也要先写入 pin 字段，避免只改 _conversations。
    V2TimConversation? pinnedRow;
    for (final c in next) {
      if (MessageConversationId.sameConversation(c.conversationID, id)) {
        pinnedRow = c;
        break;
      }
    }
    if (pinnedRow != null) {
      _patchTypeHydrateConversation(
        id,
        update: (_) => pinnedRow!,
        reorder: false,
        field: 'isPinned',
      );
      if (ConversationPerfFlags.conversationListSdkPrimary) {
        ConversationTabStore.instance.applyPatches(
          [pinnedRow],
          reason: 'pin_local',
        );
      }
    }

    final useDeferred =
        forceDeferred || ConversationPerfFlags.pinDeferredReorderEnabled;
    final effectiveDelay = useDeferred ? reorderDelay : Duration.zero;

    final preview = List<V2TimConversation>.from(_conversations)
      ..sort(ConversationLocalStore.compareConversationsForUi);
    final toIndex = ConversationPinFlickerLog.indexOfConversation(preview, id);
    final scroll = listScrollOffset ?? listScrollOffsetProvider?.call();
    ConversationPinFlickerLog.log(
      useDeferred
          ? (pinValueChanged ? 'pin_phase_silent' : 'pin_phase_silent_same')
          : 'pin_phase_immediate',
      conversationID: id,
      extras: <String, Object?>{
        'isPinned': isPinned,
        'fromIndex': idx,
        'toIndex': toIndex,
        'scroll': scroll?.toStringAsFixed(1) ?? 'na',
        'mode': useDeferred ? 'silent_then_reorder_once' : 'immediate_reorder',
        'pinValueChanged': pinValueChanged,
        'delayMs': effectiveDelay.inMilliseconds,
        'order': ConversationPinFlickerLog.orderSnapshot(_conversations),
      },
    );

    if (!useDeferred || effectiveDelay <= Duration.zero) {
      _flushDeferredPinReorder();
      return;
    }
    // 静默写入：本阶段不 notify，避免「先灰底闪一下再瞬移」双帧闪烁。
    _scheduleDeferredPinReorder(effectiveDelay);
  }

  void _scheduleDeferredPinReorder(Duration reorderDelay) {
    _deferredPinReorderTimer?.cancel();
    final delay = reorderDelay <= Duration.zero ? Duration.zero : reorderDelay;
    ConversationPinFlickerLog.log(
      'pin_reorder_scheduled',
      extras: <String, Object?>{'delayMs': delay.inMilliseconds},
    );
    _deferredPinReorderTimer = Timer(delay, _flushDeferredPinReorder);
  }

  void _flushDeferredPinReorder() {
    _deferredPinReorderTimer = null;
    final movedId = (_deferredPinConversationId ?? '').trim();
    final targetPinned = _deferredPinTargetPinned;
    _deferredPinConversationId = null;
    _deferredPinTargetPinned = null;

    final fromIndex = movedId.isEmpty
        ? -1
        : ConversationPinFlickerLog.indexOfConversation(
            _conversations, movedId);
    final before = ConversationPinFlickerLog.orderSnapshot(_conversations);
    final sorted = List<V2TimConversation>.from(_conversations)
      ..sort(ConversationLocalStore.compareConversationsForUi);
    final toIndex = movedId.isEmpty
        ? -1
        : ConversationPinFlickerLog.indexOfConversation(sorted, movedId);

    if (_sameConversationOrder(_conversations, sorted)) {
      if (!listsEqualForUi(_conversations, sorted)) {
        _conversations = sorted;
      }
      // 顺序不变也要让 hydrate 上的图钉/底色与内存一致。
      if (movedId.isNotEmpty) {
        V2TimConversation? row;
        for (final c in _conversations) {
          if (MessageConversationId.sameConversation(
              c.conversationID, movedId)) {
            row = c;
            break;
          }
        }
        if (row != null) {
          _patchTypeHydrateConversation(
            movedId,
            update: (_) => row!,
            reorder: true,
            field: 'isPinned',
          );
        }
      }
      ConversationPinFlickerLog.log(
        'pin_phase_reorder_style_only',
        conversationID: movedId,
        extras: <String, Object?>{
          'order': before,
          'fromIndex': fromIndex,
          'toIndex': toIndex,
          'targetPinned': targetPinned,
        },
      );
      // 静默阶段未 notify：顺序未变也要刷一次底色/图钉。
      _bumpRevisionsForChange(orderOrMembershipChanged: false);
      _notifyIfAllowed(reason: 'pin_phase_reorder_style_only');
      return;
    }
    final after = ConversationPinFlickerLog.orderSnapshot(sorted);
    if (movedId.isNotEmpty &&
        fromIndex >= 0 &&
        toIndex >= 0 &&
        fromIndex != toIndex) {
      _pinReorderScrollHint = ConversationPinReorderScrollHint(
        conversationID: movedId,
        fromIndex: fromIndex,
        toIndex: toIndex,
        isPinned: targetPinned == true,
        scrollMode: ConversationPinScrollMode.keepViewport,
      );
    } else {
      _pinReorderScrollHint = null;
    }
    ConversationPinFlickerLog.log(
      'pin_phase_reorder',
      conversationID: movedId,
      extras: <String, Object?>{
        'orderBefore': before,
        'orderAfter': after,
        'fromIndex': fromIndex,
        'toIndex': toIndex,
        'delta':
            (fromIndex >= 0 && toIndex >= 0) ? (toIndex - fromIndex) : null,
        'targetPinned': targetPinned,
        'scrollMode': ConversationPinScrollMode.keepViewport.name,
        'scrollHint': _pinReorderScrollHint != null,
      },
    );
    _conversations = sorted;
    if (movedId.isNotEmpty) {
      V2TimConversation? row;
      for (final c in sorted) {
        if (MessageConversationId.sameConversation(c.conversationID, movedId)) {
          row = c;
          break;
        }
      }
      if (row != null) {
        _patchTypeHydrateConversation(
          movedId,
          update: (_) => row!,
          reorder: true,
          field: 'isPinned',
        );
      }
    }
    _bumpRevisionsForChange(orderOrMembershipChanged: true);
    _notifyIfAllowed(reason: 'pin_phase_reorder');
  }

  /// 置顶停顿窗口内：合并字段但保持当前 UI 顺序，避免 SDK 回写抢先重排。
  void _mergePreservingUiOrder(List<V2TimConversation> incoming) {
    if (incoming.isEmpty && _conversations.isEmpty) {
      return;
    }
    final byId = <String, V2TimConversation>{};
    for (final item in incoming) {
      final id = item.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      byId[id] = item;
    }
    final next = <V2TimConversation>[];
    final seen = <String>{};
    var changed = false;
    for (final existing in _conversations) {
      final id = existing.conversationID.trim();
      final match = byId[id];
      if (match == null) {
        next.add(existing);
        seen.add(id);
        continue;
      }
      seen.add(id);
      ConversationLocalStore.decorateConversationForUi(match);
      match.conversationID = existing.conversationID;
      match.isPinned =
          ConversationPinSyncService.instance.isPinnedConversationId(id);
      _applyRecvOptLocalGraceIfNeeded(match);
      if (conversationUiFingerprint(existing) !=
          conversationUiFingerprint(match)) {
        changed = true;
        next.add(match);
      } else {
        next.add(existing);
      }
    }
    for (final item in incoming) {
      final id = item.conversationID.trim();
      if (id.isEmpty || seen.contains(id)) {
        continue;
      }
      ConversationLocalStore.decorateConversationForUi(item);
      item.isPinned =
          ConversationPinSyncService.instance.isPinnedConversationId(id);
      next.add(item);
      changed = true;
    }
    if (!changed && next.length == _conversations.length) {
      ConversationPinFlickerLog.log(
        'merge_preserve_order_noop',
        extras: <String, Object?>{
          'order': ConversationPinFlickerLog.orderSnapshot(_conversations),
        },
      );
      return;
    }
    ConversationPinFlickerLog.log(
      'merge_preserve_order_notify',
      extras: <String, Object?>{
        'changed': changed,
        'order': ConversationPinFlickerLog.orderSnapshot(next),
      },
    );
    final orderChanged = !_sameConversationOrder(_conversations, next);
    _conversations = next;
    _bumpRevisionsForChange(orderOrMembershipChanged: orderChanged);
    _notifyIfAllowed(reason: 'merge_preserve_order');
  }

  Future<void> applyWindowPatchesIfNeeded({
    required List<V2TimConversation> upserted,
    List<String> deletedIds = const [],
  }) {
    return applyConversationsFromStore(
      upserted: upserted,
      deletedIds: deletedIds,
    );
  }

  Future<void> applyConversationsFromStore({
    required List<V2TimConversation> upserted,
    List<String> deletedIds = const [],

    /// 取消归档等：即使不满足热准入/地板，也必须进主列表窗。
    Set<String> forceAdmitIds = const <String>{},
  }) async {
    if (upserted.isEmpty && deletedIds.isEmpty) {
      return;
    }
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      ensureTabStoreBridgeAttached();
      if (upserted.isNotEmpty) {
        ConversationTabStore.instance.applyPatches(
          upserted,
          reason: 'apply_store',
          forceAdmitIds: forceAdmitIds,
        );
      }
      if (deletedIds.isNotEmpty) {
        ConversationTabStore.instance.applyDeleted(deletedIds);
      }
      // TabStore listener 已刷 UI；legacy hydrate 路径跳过。
      return;
    }

    final deletedSet =
        deletedIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final archivedC2c = archivedConversationC2cIDsNotifier.value;
    final archivedGroup = archivedConversationGroupIDsNotifier.value;
    final unreadDeltas = <ConversationUnreadDelta>[];
    var needsOutOfWindowUnreadRefresh = false;

    int notifiableOf(V2TimConversation conversation) {
      return ConversationUnreadUtils.notifiableUnreadForAggregate(
        conversation,
        archivedC2c: archivedC2c,
        archivedGroup: archivedGroup,
      );
    }

    var next = List<V2TimConversation>.from(_conversations);
    final upsertIds = upserted
        .map((e) => e.conversationID.trim())
        .where((e) => e.isNotEmpty)
        .take(6)
        .join(',');

    if (deletedSet.isNotEmpty) {
      if (_hasOpenChatNow || _uiNotifyPendingWhileActiveChat) {
        _activeChatDirtyIds.addAll(deletedSet);
      }
      for (final existing in _conversations) {
        final hit = deletedSet.any(
          (deletedId) => MessageConversationId.sameConversation(
            existing.conversationID,
            deletedId,
          ),
        );
        if (!hit) {
          continue;
        }
        final oldN = notifiableOf(existing);
        if (oldN > 0) {
          unreadDeltas.add(
            ConversationUnreadDelta(
              isGroup: ConversationUnreadUtils.isGroupConversation(existing),
              oldNotifiable: oldN,
              newNotifiable: 0,
            ),
          );
        }
      }
      next.removeWhere(
        (c) => deletedSet.any(
          (deletedId) => MessageConversationId.sameConversation(
            c.conversationID,
            deletedId,
          ),
        ),
      );
    }

    for (final incoming in upserted) {
      final id = incoming.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      if (_isArchivedForMainList(incoming)) {
        // 已归档：禁止灌进主列表窗；若已在窗内则剔除。
        next.removeWhere(
          (c) => MessageConversationId.sameConversation(c.conversationID, id),
        );
        if (_hasOpenChatNow || _uiNotifyPendingWhileActiveChat) {
          _activeChatDirtyIds.add(id);
        }
        continue;
      }
      if (_hasOpenChatNow || _uiNotifyPendingWhileActiveChat) {
        _activeChatDirtyIds.add(id);
      }
      ConversationLocalStore.decorateConversationForUi(incoming);
      incoming.isPinned =
          ConversationPinSyncService.instance.isPinnedConversationId(id);
      _applyRecvOptLocalGraceIfNeeded(incoming);
      final idx = next.indexWhere(
        (c) => MessageConversationId.sameConversation(c.conversationID, id),
      );
      if (idx >= 0) {
        final existing = next[idx];
        final oldN = notifiableOf(existing);
        final existingUnread = existing.unreadCount ?? 0;
        incoming.unreadCount = ConversationUnreadGuard.resolveForListApply(
          conversationId: id,
          existingUnread: existingUnread,
          incoming: incoming,
          existingLastMessage: existing.lastMessage,
        );
        incoming.conversationID = existing.conversationID;
        incoming.lastMessage = ConversationLastMessagePrefer.preferLastMessage(
          existing: existing.lastMessage,
          incoming: incoming.lastMessage,
        );
        if (id.startsWith('c2c_') ||
            (incoming.userID?.trim().isNotEmpty ?? false)) {
          incoming.showName =
              ConversationC2cShowNamePrefer.preferForConversationIds(
            conversationID: id,
            userID: incoming.userID ?? existing.userID,
            existingShowName: existing.showName,
            incomingShowName: incoming.showName,
            readStore: DisplayNameStore.instance.c2c,
          );
        }
        final strongLast = incoming.lastMessage;
        if (strongLast != null) {
          _putStrongPreviewCache(id, strongLast);
        }
        final newN = notifiableOf(incoming);
        if (oldN != newN) {
          unreadDeltas.add(
            ConversationUnreadDelta(
              isGroup: ConversationUnreadUtils.isGroupConversation(incoming),
              oldNotifiable: oldN,
              newNotifiable: newN,
            ),
          );
        }
        if (conversationUiFingerprint(existing) !=
            conversationUiFingerprint(incoming)) {
          next[idx] = incoming;
        }
      } else if (forceAdmitIds.any(
            (forced) => MessageConversationId.sameConversation(forced, id),
          ) ||
          _shouldAdmitToUiWindow(incoming, next)) {
        incoming.unreadCount = ConversationUnreadGuard.resolveForListApply(
          conversationId: id,
          existingUnread: 0,
          incoming: incoming,
        );
        final newN = notifiableOf(incoming);
        if (newN > 0) {
          unreadDeltas.add(
            ConversationUnreadDelta(
              isGroup: ConversationUnreadUtils.isGroupConversation(incoming),
              oldNotifiable: 0,
              newNotifiable: newN,
            ),
          );
        }
        next.add(incoming);
      } else {
        // 未进 UI 窗但库已变：角标可能变，走 bulk 全量对账。
        needsOutOfWindowUnreadRefresh = true;
      }
      _storeHasAnyRow = true;
    }

    // 置顶停顿期间不重排，等定时器统一排序。
    final deferring = _isDeferringPinReorder;
    if (!deferring) {
      next.sort(ConversationLocalStore.compareConversationsForUi);
      // 用户已下滑扩窗：禁止 patch 把列表裁回 budget，否则显示数量又变回 120。
      final skipSlideTrim = _slidingWindowUserExpanded &&
          ConversationPerfFlags.uiAppendOlderGrowsWindow;
      if (!skipSlideTrim) {
        next = _applySlidingOrHardTrim(
          next,
          preferConvType: null,
          trimFromStart: true,
        ).list;
      }
    }

    // 虚拟列表读 hydrate：无论 _conversations 是否 noop，都要把 unread 等灌进窗。
    final orderChanged = !_sameConversationOrder(_conversations, next);
    var hydrateDirty = false;
    if (deletedSet.isNotEmpty) {
      for (final deletedId in deletedSet) {
        _removeFromTypeHydrate(deletedId);
        hydrateDirty = true;
      }
    }
    for (final incoming in upserted) {
      final id = incoming.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      V2TimConversation? row;
      for (final c in next) {
        if (MessageConversationId.sameConversation(c.conversationID, id)) {
          row = c;
          break;
        }
      }
      if (row == null) {
        _removeFromTypeHydrate(id);
        continue;
      }
      // 未读 alone 不重排；顺序变化时窗内重排。
      if (_syncTypeHydrateRowFromApplied(
        row: row,
        reorder: orderChanged && !deferring,
      )) {
        hydrateDirty = true;
      }
    }

    if (listsEqualForUi(_conversations, next) &&
        _sameConversationOrder(_conversations, next)) {
      if (ConversationPinFlickerLog.enabled &&
          (deferring || upsertIds.isNotEmpty)) {
        ConversationPinFlickerLog.log(
          'apply_store_noop',
          extras: <String, Object?>{
            'deferring': deferring,
            'upsertIds': upsertIds,
            'deleted': deletedSet.length,
            'hydrateDirty': hydrateDirty,
          },
        );
      }
      if (hydrateDirty) {
        _bumpRevisionsForChange(orderOrMembershipChanged: orderChanged);
        _notifyIfAllowed(
          reason: deferring ? 'apply_store_defer' : 'apply_store',
        );
      }
      // UI noop：指纹已含未读；不 schedule 全量聚合。
      if (unreadDeltas.isNotEmpty) {
        ConversationUnreadAggregate.instance
            .applyNotifiableDeltas(unreadDeltas);
      }
      if (needsOutOfWindowUnreadRefresh) {
        ConversationUnreadAggregate.instance.scheduleRefresh(
          reason: 'apply_out_of_window',
        );
      }
      return;
    }
    ConversationPinFlickerLog.log(
      'apply_store_notify',
      extras: <String, Object?>{
        'deferring': deferring,
        'orderChanged': orderChanged,
        'upsertIds': upsertIds,
        'deleted': deletedSet.length,
        'orderBefore': ConversationPinFlickerLog.orderSnapshot(_conversations),
        'orderAfter': ConversationPinFlickerLog.orderSnapshot(next),
        'caller': ConversationPinFlickerLog.callerHint(),
      },
    );
    _conversations = next;
    _bumpRevisionsForChange(orderOrMembershipChanged: orderChanged);
    _notifyIfAllowed(reason: deferring ? 'apply_store_defer' : 'apply_store');
    if (unreadDeltas.isNotEmpty) {
      ConversationUnreadAggregate.instance.applyNotifiableDeltas(unreadDeltas);
    }
    if (needsOutOfWindowUnreadRefresh) {
      ConversationUnreadAggregate.instance.scheduleRefresh(
        reason: 'apply_out_of_window',
      );
    }
  }

  static bool _sameConversationOrder(
    List<V2TimConversation> a,
    List<V2TimConversation> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!MessageConversationId.sameConversation(
        a[i].conversationID,
        b[i].conversationID,
      )) {
        return false;
      }
    }
    return true;
  }

  static V2TimConversation _cloneConversationWithPin(
    V2TimConversation source, {
    required bool isPinned,
    int? orderkey,
  }) {
    final cloned = V2TimConversation(
      conversationID: source.conversationID,
      type: source.type,
      userID: source.userID,
      groupID: source.groupID,
      showName: source.showName,
      faceUrl: source.faceUrl,
      recvOpt: source.recvOpt,
      unreadCount: source.unreadCount ?? 0,
      lastMessage: source.lastMessage,
      draftText: source.draftText,
      draftTimestamp: source.draftTimestamp,
      isPinned: isPinned,
      orderkey: orderkey ?? source.orderkey,
      groupType: source.groupType,
      groupAtInfoList: source.groupAtInfoList,
      c2cReadTimestamp: source.c2cReadTimestamp,
      groupReadSequence: source.groupReadSequence,
    );
    // Keep read cursors for first-unread / @ jump even if constructor omits.
    cloned.c2cReadTimestamp = source.c2cReadTimestamp;
    cloned.groupReadSequence = source.groupReadSequence;
    return cloned;
  }

  void beginSuppressNotify() {
    _notifySuppressDepth++;
  }

  void endSuppressNotify() {
    if (_notifySuppressDepth > 0) {
      _notifySuppressDepth--;
    }
    if (_notifySuppressDepth == 0 && _notifyPendingWhileSuppressed) {
      _notifyPendingWhileSuppressed = false;
      _scheduleCoalescedNotify('end_suppress');
    }
  }

  /// 合并短时高频 notify（进首页后 apply_store / drain 风暴），减轻 pop 卡顿。
  void _scheduleCoalescedNotify(String reason) {
    _coalescedNotifyReason = reason;
    _coalescedNotifyTimer?.cancel();
    final delay = (reason == 'append_older' ||
            reason == 'prepend_newer' ||
            reason == 'restore_hot_head_phase2')
        ? ConversationPerfFlags.appendUiNotifyCoalesceDelay
        : const Duration(milliseconds: 48);
    _coalescedNotifyTimer = Timer(
      delay <= Duration.zero ? const Duration(milliseconds: 48) : delay,
      () {
        _coalescedNotifyTimer = null;
        final flushReason = _coalescedNotifyReason ?? reason;
        _coalescedNotifyReason = null;
        _emitUiNotifyOrDefer(reason: flushReason, coalesced: true);
      },
    );
  }

  bool get _isFeedScrollingNow => isFeedScrolling?.call() ?? false;

  bool get _hasOpenChatNow => ActiveChatRegistry.instance.hasOpenChat;

  void _armScrollUiNotifyMaxDefer() {
    if (_scrollUiNotifyMaxDeferTimer?.isActive == true) {
      return;
    }
    _scrollUiNotifyMaxDeferTimer = Timer(
      ConversationPerfFlags.feedScrollUiNotifyMaxDefer,
      () {
        _scrollUiNotifyMaxDeferTimer = null;
        flushDeferredUiNotifyIfNeeded(reason: 'scroll_max_defer');
      },
    );
  }

  void _armActiveChatUiNotifyMaxDefer() {
    if (_activeChatUiNotifyMaxDeferTimer?.isActive == true) {
      return;
    }
    final maxDefer = ConversationPerfFlags.activeChatUiNotifyMaxDefer;
    if (maxDefer <= Duration.zero) {
      return;
    }
    _activeChatUiNotifyMaxDeferTimer = Timer(maxDefer, () {
      _activeChatUiNotifyMaxDeferTimer = null;
      if (ConversationPerfFlags.activeChatMaxDeferFullFlushEnabled) {
        flushDeferredUiNotifyIfNeeded(reason: 'active_chat_max_defer');
        return;
      }
      // 默认：聊中到期不整表 flush，只保留 pending + 脏集。
      ConversationPerfGateLog.log(
        'active_chat_max_defer_skip_full_flush',
        extras: <String, Object?>{
          'dirty': _activeChatDirtyIds.length,
          'pending': _uiNotifyPendingWhileActiveChat ? 1 : 0,
        },
      );
    });
  }

  /// 离开聊天后的短静默窗：folder_unread 等应 defer。
  bool get isPostChatLeaveQuiet {
    final until = _postChatLeaveQuietUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// 静默窗剩余时间；不在窗内返回 [Duration.zero]。
  Duration get postChatLeaveQuietRemaining {
    final until = _postChatLeaveQuietUntil;
    if (until == null) {
      return Duration.zero;
    }
    final remain = until.difference(DateTime.now());
    return remain.isNegative ? Duration.zero : remain;
  }

  /// 离开聊天：清 defer、patch 刚离开会话，并把进聊期间挂起的 Feed notify 刷出去。
  Future<bool> patchConversationAfterChatLeave(
    String leftConversationId, {
    String reason = 'chat_leave',
  }) async {
    final leftId = leftConversationId.trim();
    final now = DateTime.now();
    if (ConversationPerfFlags.chatLeaveFlushDedupeEnabled &&
        leftId.isNotEmpty &&
        _lastChatLeavePatchedId == leftId &&
        _lastChatLeavePatchedAt != null &&
        now.difference(_lastChatLeavePatchedAt!) < const Duration(seconds: 2)) {
      ConversationPerfGateLog.log(
        'chat_leave_flush_skipped_dedupe',
        extras: <String, Object?>{'leftId': leftId, 'reason': reason},
      );
      return false;
    }
    _chatLeavePatchGeneration++;
    _lastChatLeavePatchedId = leftId.isEmpty ? null : leftId;
    _lastChatLeavePatchedAt = now;
    _postChatLeaveQuietUntil = now.add(
      ConversationPerfFlags.postChatLeaveCatchUpDelay >
              const Duration(milliseconds: 400)
          ? ConversationPerfFlags.postChatLeaveCatchUpDelay
          : const Duration(milliseconds: 1200),
    );

    final hadPendingNotify =
        _uiNotifyPendingWhileScrolling || _uiNotifyPendingWhileActiveChat;

    _scrollUiNotifyMaxDeferTimer?.cancel();
    _scrollUiNotifyMaxDeferTimer = null;
    _activeChatUiNotifyMaxDeferTimer?.cancel();
    _activeChatUiNotifyMaxDeferTimer = null;
    _uiNotifyPendingWhileActiveChat = false;

    if (!ConversationPerfFlags.chatLeavePatchLeftOnlyEnabled) {
      flushDeferredUiNotifyIfNeeded(reason: reason);
      return true;
    }

    ConversationPerfGateLog.log(
      'chat_leave_patch_left',
      extras: <String, Object?>{
        'leftId': leftId,
        'reason': reason,
        'dirty': _activeChatDirtyIds.length,
        'generation': _chatLeavePatchGeneration,
      },
    );

    if (leftId.isNotEmpty) {
      _activeChatDirtyIds.removeWhere(
        (id) => MessageConversationId.sameConversation(id, leftId),
      );
      // 优先窗内内存（进聊期间通常已 apply）；缺壳再读库。
      V2TimConversation? local;
      for (final c in _conversations) {
        if (MessageConversationId.sameConversation(c.conversationID, leftId)) {
          local = c;
          break;
        }
      }
      if (local == null) {
        try {
          local =
              await ConversationLocalStore.instance.conversationById(leftId);
        } catch (e, st) {
          debugPrint(
            'patchConversationAfterChatLeave store read failed: $e\n$st',
          );
        }
      }
      if (local != null) {
        try {
          await applyConversationsFromStore(upserted: [local]);
        } catch (e, st) {
          debugPrint('patchConversationAfterChatLeave apply failed: $e\n$st');
        }
      } else {
        // 窗内无壳时仍合并一次 notify，避免 pending 永久饿死。
        _scheduleCoalescedNotify('chat_leave_left_miss');
      }
    }

    ConversationUnreadAggregate.instance.scheduleRefresh(
      reason: 'chat_leave_left_only',
    );
    _flushPendingUiNotifyAfterChatLeave(
      reason: reason,
      hadPendingNotify: hadPendingNotify,
    );
    scheduleActiveChatDirtyCatchUp();
    return true;
  }

  /// 进聊期间新会话已写入内存窗，但 Feed notify 被 defer。
  /// 只 patch 刚离开会话时 apply 常为 noop，必须把挂起的 notify 刷出去。
  void _flushPendingUiNotifyAfterChatLeave({
    required String reason,
    required bool hadPendingNotify,
  }) {
    _coalescedNotifyTimer?.cancel();
    _coalescedNotifyTimer = null;
    _coalescedNotifyReason = null;
    _uiNotifyPendingWhileScrolling = false;
    _uiNotifyPendingWhileActiveChat = false;
    if (hadPendingNotify) {
      _bumpRevisionsForChange(orderOrMembershipChanged: true);
    }
    ConversationPerfGateLog.log(
      'chat_leave_flush_pending_notify',
      extras: <String, Object?>{
        'reason': reason,
        'hadPending': hadPendingNotify ? 1 : 0,
        'count': _conversations.length,
      },
    );
    ConversationPerfGateLog.markRealtimeUiNotify(
      reason: 'chat_leave_flush_pending_notify',
    );
    notifyListeners();
  }

  void scheduleActiveChatDirtyCatchUp({bool forceNow = false}) {
    if (!ConversationPerfFlags.activeChatDirtyCatchUpEnabled) {
      _activeChatDirtyIds.clear();
      return;
    }
    if (_activeChatDirtyIds.isEmpty) {
      return;
    }
    _activeChatDirtyCatchUpTimer?.cancel();
    final delay = forceNow
        ? Duration.zero
        : ConversationPerfFlags.postChatLeaveCatchUpDelay;
    _activeChatDirtyCatchUpTimer = Timer(delay, () {
      _activeChatDirtyCatchUpTimer = null;
      unawaited(_runActiveChatDirtyCatchUp());
    });
  }

  Future<void> _runActiveChatDirtyCatchUp() async {
    if (_activeChatDirtyCatchUpInFlight) {
      return;
    }
    if (_activeChatDirtyIds.isEmpty) {
      return;
    }
    if (_hasOpenChatNow) {
      return;
    }
    if (_isFeedScrollingNow) {
      scheduleActiveChatDirtyCatchUp();
      return;
    }

    _activeChatDirtyCatchUpInFlight = true;
    final dirty = _activeChatDirtyIds.toList(growable: false);
    _activeChatDirtyIds.clear();
    final batchSize = ConversationPerfFlags.activeChatDirtyCatchUpBatchSize > 0
        ? ConversationPerfFlags.activeChatDirtyCatchUpBatchSize
        : 20;
    ConversationPerfGateLog.log(
      'chat_leave_catch_up_begin',
      extras: <String, Object?>{
        'dirtyCount': dirty.length,
        'batchSize': batchSize,
      },
    );
    beginSuppressNotify();
    var batches = 0;
    try {
      for (var offset = 0; offset < dirty.length; offset += batchSize) {
        if (_hasOpenChatNow) {
          _activeChatDirtyIds.addAll(dirty.skip(offset));
          break;
        }
        if (_isFeedScrollingNow) {
          _activeChatDirtyIds.addAll(dirty.skip(offset));
          scheduleActiveChatDirtyCatchUp();
          break;
        }
        final end = offset + batchSize > dirty.length
            ? dirty.length
            : offset + batchSize;
        final chunk = dirty.sublist(offset, end);
        batches++;
        final rows = await ConversationLocalStore.instance.conversationsByIds(
          chunk,
          caller: 'active_chat_dirty_catch_up',
        );
        if (rows.isNotEmpty) {
          await applyConversationsFromStore(upserted: rows);
        }
        if (end < dirty.length) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    } catch (e, st) {
      debugPrint('activeChatDirtyCatchUp failed: $e\n$st');
    } finally {
      endSuppressNotify();
      _activeChatDirtyCatchUpInFlight = false;
      ConversationPerfGateLog.log(
        'chat_leave_catch_up_end',
        extras: <String, Object?>{
          'dirtyCount': dirty.length,
          'batches': batches,
          'remaining': _activeChatDirtyIds.length,
        },
      );
    }
  }

  /// 停滑 / 离聊 / maxDefer 到期时刷出挂起的 UI notify。
  void flushDeferredUiNotifyIfNeeded({String reason = 'scroll_end'}) {
    final isChatLeave = reason.startsWith('chat_leave');
    if (isChatLeave && ConversationPerfFlags.chatLeavePatchLeftOnlyEnabled) {
      // leave 应走 [patchConversationAfterChatLeave]；误入则只清 pending。
      _activeChatUiNotifyMaxDeferTimer?.cancel();
      _activeChatUiNotifyMaxDeferTimer = null;
      _uiNotifyPendingWhileActiveChat = false;
      ConversationPerfGateLog.log(
        'ui_notify_flush_redirect_leave',
        extras: <String, Object?>{'reason': reason},
      );
      return;
    }

    _scrollUiNotifyMaxDeferTimer?.cancel();
    _scrollUiNotifyMaxDeferTimer = null;
    _activeChatUiNotifyMaxDeferTimer?.cancel();
    _activeChatUiNotifyMaxDeferTimer = null;
    final pending =
        _uiNotifyPendingWhileScrolling || _uiNotifyPendingWhileActiveChat;
    if (!pending) {
      return;
    }
    _uiNotifyPendingWhileScrolling = false;
    _uiNotifyPendingWhileActiveChat = false;
    ConversationPinFlickerLog.log(
      'ui_notify',
      extras: <String, Object?>{
        'reason': reason,
        'coalesced': false,
        'flushedScrollDefer': true,
        'deferring': _isDeferringPinReorder,
        'count': _conversations.length,
        'order': ConversationPinFlickerLog.orderSnapshot(_conversations),
      },
    );
    ConversationPerfGateLog.log(
      'ui_notify_flush',
      extras: <String, Object?>{'reason': reason},
    );
    ConversationPerfGateLog.markRealtimeUiNotify(reason: reason);
    notifyListeners();
    if (reason == 'scroll_end' &&
        ConversationPerfFlags.activeChatDirtyCatchUpEnabled &&
        _activeChatDirtyIds.isNotEmpty &&
        !_hasOpenChatNow) {
      scheduleActiveChatDirtyCatchUp(forceNow: true);
    }
  }

  void _emitUiNotifyOrDefer({
    required String reason,
    bool coalesced = false,
  }) {
    if (ConversationPerfFlags.deferUiNotifyWhileFeedScrolling &&
        _isFeedScrollingNow) {
      _uiNotifyPendingWhileScrolling = true;
      _armScrollUiNotifyMaxDefer();
      ConversationPinFlickerLog.log(
        'ui_notify_deferred_scroll',
        extras: <String, Object?>{
          'reason': reason,
          'coalesced': coalesced,
        },
      );
      return;
    }
    if (ConversationPerfFlags.deferUiNotifyWhileActiveChat && _hasOpenChatNow) {
      _uiNotifyPendingWhileActiveChat = true;
      _armActiveChatUiNotifyMaxDefer();
      ConversationPinFlickerLog.log(
        'ui_notify_deferred_active_chat',
        extras: <String, Object?>{
          'reason': reason,
          'coalesced': coalesced,
        },
      );
      ConversationPerfGateLog.log(
        'ui_notify_deferred_active_chat',
        extras: <String, Object?>{'reason': reason},
      );
      return;
    }
    ConversationPinFlickerLog.log(
      'ui_notify',
      extras: <String, Object?>{
        'reason': reason,
        'coalesced': coalesced,
        'deferring': _isDeferringPinReorder,
        'count': _conversations.length,
        'order': ConversationPinFlickerLog.orderSnapshot(_conversations),
      },
    );
    ConversationPerfGateLog.markRealtimeUiNotify(reason: reason);
    notifyListeners();
  }

  void _notifyIfAllowed({String reason = 'unknown'}) {
    if (_notifySuppressDepth > 0) {
      _notifyPendingWhileSuppressed = true;
      ConversationPinFlickerLog.log(
        'ui_notify_suppressed',
        extras: <String, Object?>{
          'reason': reason,
          'depth': _notifySuppressDepth,
        },
      );
      return;
    }
    // 置顶重排需要即时反馈；其余写库路径合并到下一帧附近。
    if (reason == 'apply_store' ||
        reason == 'apply_store_defer' ||
        reason == 'reload_from_local' ||
        reason == 'end_suppress') {
      _scheduleCoalescedNotify(reason);
      return;
    }
    // 触底/近顶翻页：短窗合并 structure notify，压连滑风暴。
    if (ConversationPerfFlags.appendUiNotifyCoalesceEnabled &&
        (reason == 'append_older' ||
            reason == 'prepend_newer' ||
            reason == 'restore_hot_head_phase2')) {
      _scheduleCoalescedNotify(reason);
      return;
    }
    // hydrate / last_message 等也走 defer 出口，避免 Chat 页刷离屏 Feed。
    _emitUiNotifyOrDefer(reason: reason, coalesced: false);
  }

  void clearSession() {
    if (_tabStoreBridgeAttached) {
      ConversationTabStore.instance.removeListener(_onTabStoreChanged);
      _tabStoreBridgeAttached = false;
    }
    ConversationTabStore.instance.clear();
    _deferredPinReorderTimer?.cancel();
    _deferredPinReorderTimer = null;
    _coalescedNotifyTimer?.cancel();
    _coalescedNotifyTimer = null;
    _coalescedNotifyReason = null;
    _scrollUiNotifyMaxDeferTimer?.cancel();
    _scrollUiNotifyMaxDeferTimer = null;
    _activeChatUiNotifyMaxDeferTimer?.cancel();
    _activeChatUiNotifyMaxDeferTimer = null;
    _activeChatDirtyCatchUpTimer?.cancel();
    _activeChatDirtyCatchUpTimer = null;
    _activeChatDirtyCatchUpInFlight = false;
    _activeChatDirtyIds.clear();
    _chatLeavePatchGeneration = 0;
    _lastChatLeavePatchedId = null;
    _lastChatLeavePatchedAt = null;
    _postChatLeaveQuietUntil = null;
    _uiNotifyPendingWhileScrolling = false;
    _uiNotifyPendingWhileActiveChat = false;
    _deferredPinConversationId = null;
    _deferredPinTargetPinned = null;
    _pinReorderScrollHint = null;
    listScrollOffsetProvider = null;
    isFeedScrolling = null;
    _storeHasAnyRow = false;
    _slidingWindowUserExpanded = false;
    _typeAppendConsumed.clear();
    _typeTotalCount[1] = 0;
    _typeTotalCount[2] = 0;
    _typeHydrateStart[1] = 0;
    _typeHydrateStart[2] = 0;
    _typeHydrate[1] = const <V2TimConversation>[];
    _typeHydrate[2] = const <V2TimConversation>[];
    _clearTypeIndexSnapshotCache();
    _hydrateRequestSerial++;
    _viewportAnchorConversationId = null;
    _hotHeadPhase2Generation++;
    ConversationUnreadAggregate.instance.clearSession();
    _structureRevision = 0;
    _contentRevision = 0;
    _lastPeerDisplayAppliedRevision = -1;
    _pendingArchiveRestoredIds.clear();
    _pendingArchiveRemovedIds.clear();
    _archiveSyncInFlight = null;
    if (_conversations.isEmpty) {
      return;
    }
    _conversations = const [];
    notifyListeners();
  }

  void zeroUnreadLocally(String conversationID) {
    final id = conversationID.trim();
    if (id.isEmpty || _conversations.isEmpty) {
      ConversationUnreadTrace.log(
        'zero_unread_skip',
        conversationID: id,
        extras: <String, Object?>{'reason': 'empty_list_or_id'},
      );
      return;
    }
    var changed = false;
    var unreadBefore = 0;
    final next = List<V2TimConversation>.from(_conversations);
    for (var i = 0; i < next.length; i++) {
      if (!MessageConversationId.sameConversation(next[i].conversationID, id)) {
        continue;
      }
      if ((next[i].unreadCount ?? 0) == 0) {
        continue;
      }
      unreadBefore = next[i].unreadCount ?? 0;
      next[i].unreadCount = 0;
      changed = true;
    }
    if (!changed) {
      ConversationUnreadTrace.log(
        'zero_unread_skip',
        conversationID: id,
        extras: <String, Object?>{'reason': 'already_zero'},
      );
      return;
    }
    _conversations = next;
    _patchTypeHydrateConversation(
      id,
      update: (current) {
        if ((current.unreadCount ?? 0) == 0) {
          return current;
        }
        current.unreadCount = 0;
        return current;
      },
      field: 'zero_unread',
    );
    _bumpRevisionsForChange(orderOrMembershipChanged: false);
    _notifyIfAllowed();
    ConversationUnreadTrace.log(
      'zero_unread_applied',
      conversationID: id,
      unreadBefore: unreadBefore,
      unreadAfter: 0,
    );
    ConversationUnreadAggregate.instance.scheduleRefresh(reason: 'zero_unread');
  }

  /// 批量清零内存未读：单次 notify + 单次聚合刷新。
  void zeroUnreadLocallyMany(
    Iterable<String> conversationIds, {
    bool forceAggregateRefresh = false,
  }) {
    final idSet =
        conversationIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (idSet.isEmpty) {
      if (forceAggregateRefresh) {
        ConversationUnreadAggregate.instance.scheduleRefresh(
          reason: 'zero_unread_many_empty',
        );
      }
      return;
    }
    var changed = false;
    if (_conversations.isNotEmpty) {
      final next = List<V2TimConversation>.from(_conversations);
      for (var i = 0; i < next.length; i++) {
        final id = next[i].conversationID.trim();
        if (id.isEmpty) {
          continue;
        }
        final hit = idSet.contains(id) ||
            idSet.any(
              (token) => MessageConversationId.sameConversation(token, id),
            );
        if (!hit || (next[i].unreadCount ?? 0) == 0) {
          continue;
        }
        next[i].unreadCount = 0;
        changed = true;
        _patchTypeHydrateConversation(
          id,
          update: (current) {
            if ((current.unreadCount ?? 0) == 0) {
              return current;
            }
            current.unreadCount = 0;
            return current;
          },
          field: 'zero_unread_many',
        );
      }
      if (changed) {
        _conversations = next;
        _bumpRevisionsForChange(orderOrMembershipChanged: false);
        _notifyIfAllowed();
      }
    }
    if (changed || forceAggregateRefresh) {
      ConversationUnreadAggregate.instance.scheduleRefresh(
        reason: 'zero_unread_many',
      );
    }
  }

  /// 清空聊天记录后立即去掉列表预览（不等待 SQLite/SDK）。
  void clearLastMessageLocally(String conversationID) {
    final id = conversationID.trim();
    if (id.isEmpty || _conversations.isEmpty) {
      return;
    }
    var changed = false;
    final next = List<V2TimConversation>.from(_conversations);
    for (var i = 0; i < next.length; i++) {
      if (!MessageConversationId.sameConversation(next[i].conversationID, id)) {
        continue;
      }
      if (next[i].lastMessage == null) {
        continue;
      }
      final sortAnchorMs = ConversationLocalStore.displayTimestampMs(next[i]);
      next[i].lastMessage = null;
      if (sortAnchorMs > 0) {
        next[i].orderkey = sortAnchorMs;
      }
      changed = true;
    }
    if (!changed) {
      return;
    }
    _conversations = next;
    _bumpRevisionsForChange(orderOrMembershipChanged: false);
    _notifyIfAllowed();
  }

  /// 内存会话窗内按 lastMessage msgID/clientId 查找（撤回补偿：Store 可能滞后）。
  V2TimConversation? findConversationByLastMessageId(String msgID) {
    final target = msgID.trim();
    if (target.isEmpty) {
      return null;
    }
    for (final conversation in _conversations) {
      final last = conversation.lastMessage;
      if (last != null && lastMessageMatchesRevokeTarget(last, target)) {
        return conversation;
      }
    }
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      for (final type in const [1, 2]) {
        for (final conversation
            in ConversationTabStore.instance.itemsForType(type)) {
          final last = conversation.lastMessage;
          if (last != null && lastMessageMatchesRevokeTarget(last, target)) {
            return conversation;
          }
        }
      }
    }
    return null;
  }

  /// True if [index] must move under [ConversationLocalStore.compareConversationsForUi].
  /// Assumes [list] was sorted before the in-place field update at [index].
  @visibleForTesting
  static bool conversationNeedsUiReorderAfterPatch(
    List<V2TimConversation> list,
    int index,
  ) {
    if (index < 0 || index >= list.length) {
      return false;
    }
    final current = list[index];
    if (index > 0) {
      final prev = list[index - 1];
      // current belongs before prev → move toward head
      if (ConversationLocalStore.compareConversationsForUi(current, prev) < 0) {
        return true;
      }
    }
    if (index + 1 < list.length) {
      final next = list[index + 1];
      // current belongs after next → move toward tail
      if (ConversationLocalStore.compareConversationsForUi(current, next) > 0) {
        return true;
      }
    }
    return false;
  }

  /// 发送成功后立即刷新列表预览（不依赖 SDK onConversationChanged 落库）。
  /// 同 msgID 时允许 status 终态升级（SENDING→SUCC），避免发送中箭头卡住。
  ///
  /// [bumpUnread]：入站消息乐观 patch 时与预览同帧 +1 未读（SDK 未读滞后时避免角标晚到）。
  void applyLastMessageLocally({
    required String conversationID,
    required V2TimMessage message,
    bool bumpUnread = false,
  }) {
    final id = conversationID.trim();
    if (id.isEmpty || _conversations.isEmpty) {
      OutgoingVisibleProbe.log(
        'preview_apply_skip',
        conversationID: id,
        message: message,
        extras: <String, Object?>{
          'reason': id.isEmpty ? 'empty_id' : 'empty_list',
        },
      );
      return;
    }
    var changed = false;
    var patchedIndex = -1;
    V2TimMessage? applied;
    ConversationUnreadDelta? unreadDelta;
    final next = List<V2TimConversation>.from(_conversations);
    for (var i = 0; i < next.length; i++) {
      if (!MessageConversationId.sameConversation(next[i].conversationID, id)) {
        continue;
      }
      final rowBefore = next[i];
      final existing = rowBefore.lastMessage;
      final beforeRevokeFp = revokedLastMessageFingerprint(existing);
      final preferred = ConversationLastMessagePrefer.preferLastMessage(
        existing: existing,
        incoming: message,
      );
      if (preferred == null) {
        break;
      }
      final afterRevokeFp = revokedLastMessageFingerprint(preferred);
      // 禁降级保留 existing：不刷列表。
      // 调用方常先原地打撤回旗再传入同一引用，此时前后指纹已相同，
      // 仍必须写预览缓存并通知，否则会话行继续显示原文。
      if (existing != null &&
          identical(preferred, existing) &&
          beforeRevokeFp == afterRevokeFp &&
          !isRevokedMessage(message)) {
        break;
      }
      final oldNotifiable = _notifiableUnreadForRow(rowBefore);
      next[i].lastMessage = preferred;
      final ts = preferred.timestamp ?? 0;
      if (ts > 0) {
        next[i].orderkey = ts;
      }
      if (bumpUnread &&
          ConversationUnreadGuard.lastMessageAdvanced(
            before: existing,
            after: preferred,
          ) &&
          ConversationUnreadGuard.shouldOptimisticBumpUnread(
            conversationId: id,
            message: message,
          )) {
        next[i].unreadCount = (next[i].unreadCount ?? 0) + 1;
        final newNotifiable = _notifiableUnreadForRow(next[i]);
        if (oldNotifiable != newNotifiable) {
          unreadDelta = ConversationUnreadDelta(
            isGroup: ConversationUnreadUtils.isGroupConversation(next[i]),
            oldNotifiable: oldNotifiable,
            newNotifiable: newNotifiable,
          );
        }
      }
      applied = preferred;
      changed = true;
      patchedIndex = i;
      _putStrongPreviewCache(id, preferred);
      break;
    }
    if (!changed || applied == null || patchedIndex < 0) {
      OutgoingVisibleProbe.log(
        'preview_apply_noop',
        conversationID: id,
        message: message,
      );
      return;
    }
    OutgoingVisibleProbe.log(
      'preview_apply_ok',
      conversationID: id,
      message: applied,
    );
    final needsReorder =
        conversationNeedsUiReorderAfterPatch(next, patchedIndex);
    if (needsReorder) {
      next.sort(ConversationLocalStore.compareConversationsForUi);
    }
    _conversations = next;
    final appliedMessage = applied;
    final patchedUnread = unreadDelta != null
        ? next
            .firstWhere(
              (c) => MessageConversationId.sameConversation(c.conversationID, id),
            )
            .unreadCount
        : null;
    _patchTypeHydrateConversation(
      id,
      update: (current) {
        final cloned = _cloneConversationWithPin(
          current,
          isPinned: current.isPinned == true,
          orderkey: (appliedMessage.timestamp ?? 0) > 0
              ? appliedMessage.timestamp
              : current.orderkey,
        );
        cloned.lastMessage = appliedMessage;
        if (patchedUnread != null) {
          cloned.unreadCount = patchedUnread;
        }
        return cloned;
      },
      reorder: needsReorder,
      field: patchedUnread != null ? 'lastMessage+unread' : 'lastMessage',
    );
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      V2TimConversation? row;
      for (final c in _conversations) {
        if (MessageConversationId.sameConversation(c.conversationID, id)) {
          row = c;
          break;
        }
      }
      if (row != null) {
        ConversationTabStore.instance.applyPatches(
          [row],
          reason: 'last_message_local',
        );
      }
    }
    if (unreadDelta != null) {
      ConversationUnreadAggregate.instance
          .applyNotifiableDeltas(<ConversationUnreadDelta>[unreadDelta]);
    }
    _bumpRevisionsForChange(orderOrMembershipChanged: needsReorder);
    _notifyIfAllowed(reason: 'last_message_local');
  }

  int _notifiableUnreadForRow(V2TimConversation conversation) {
    return ConversationUnreadUtils.notifiableUnreadForAggregate(
      conversation,
      archivedC2c: archivedConversationC2cIDsNotifier.value,
      archivedGroup: archivedConversationGroupIDsNotifier.value,
    );
  }

  void _putStrongPreviewCache(String conversationID, V2TimMessage message) {
    if (!ConversationLastMessagePrefer.isStrongLastMessage(message)) {
      return;
    }
    final messageKey = conversationPreviewCacheMessageKey(message);
    final preview = strongConversationPreviewTextForCache(message);
    if (preview != null && preview.isNotEmpty) {
      ConversationPreviewTextCache.instance.putStrong(
        conversationID,
        preview,
        messageKey: messageKey,
      );
    }
  }

  @visibleForTesting
  void setConversationsForTest(List<V2TimConversation> conversations) {
    _conversations = List<V2TimConversation>.from(conversations);
    _structureRevision = 0;
    _contentRevision = 0;
    _lastPeerDisplayAppliedRevision = -1;
    _recvOptLocalGraceById.clear();
    _seedTypeHydrateFromConversations();
    notifyListeners();
  }

  @visibleForTesting
  void seedHydratesFromConversationsForTest() {
    _seedHydratesFromConversations();
  }

  @visibleForTesting
  bool get uiNotifyPendingWhileScrollingForTest =>
      _uiNotifyPendingWhileScrolling;

  @visibleForTesting
  void scheduleCoalescedNotifyForTest(String reason) {
    _scheduleCoalescedNotify(reason);
  }

  @visibleForTesting
  void notifyIfAllowedForTest(String reason) {
    _notifyIfAllowed(reason: reason);
  }

  @visibleForTesting
  static bool listsEqualForUi(
    List<V2TimConversation> a,
    List<V2TimConversation> b,
  ) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (conversationUiFingerprint(a[i]) != conversationUiFingerprint(b[i])) {
        return false;
      }
    }
    return true;
  }

  bool shouldAdmitToUiWindow(
    V2TimConversation incoming, {
    List<V2TimConversation>? current,
  }) {
    return _shouldAdmitToUiWindow(incoming, current ?? _conversations);
  }

  bool _shouldAdmitToUiWindow(
    V2TimConversation incoming,
    List<V2TimConversation> current,
  ) {
    // 热准入：置顶 / 未读。与硬顶解耦——无硬顶时也不再「一律准入」，
    // 避免 drain/apply 把 UI 窗灌到上千（完整列表靠 append_older）。
    if (incoming.isPinned == true) {
      return true;
    }
    if ((incoming.unreadCount ?? 0) > 0) {
      return true;
    }
    // 热准入：比窗头更热时才跳过类型地板（避免冷会话刷爆）。
    if (current.isNotEmpty) {
      final incomingActive = ConversationLocalStore.activeTimeMs(incoming);
      final headActive = ConversationLocalStore.activeTimeMs(current.first);
      if (incomingActive > headActive) {
        return true;
      }
    }
    // 应急：无硬顶且允许冷会话扩窗时恢复旧行为。
    if (!ConversationPerfFlags.uiWindowHardCapEnabled &&
        ConversationPerfFlags.sdkSyncAdmitColdConversations) {
      return true;
    }
    // 类型地板：无硬顶时也填到 snapshot 限量，避免登录后冷会话永远不进窗。
    final incomingIsGroup =
        ConversationUnreadUtils.isGroupConversation(incoming);
    final typeCount = current
        .where(
          (c) =>
              ConversationUnreadUtils.isGroupConversation(c) == incomingIsGroup,
        )
        .length;
    final typeFloor = incomingIsGroup
        ? ConversationPerfFlags.uiSnapshotGroupLimit
        : ConversationPerfFlags.uiSnapshotC2cLimit;
    if (typeCount < typeFloor) {
      return true;
    }
    if (!ConversationPerfFlags.uiWindowHardCapEnabled) {
      return false;
    }
    // 以下仅硬顶开启：长度/尾部活跃度。
    if (current.length < ConversationPerfFlags.uiWindowHardCap) {
      return true;
    }
    if (current.isEmpty) {
      return true;
    }
    final incomingActive = ConversationLocalStore.activeTimeMs(incoming);
    final tailActive = ConversationLocalStore.activeTimeMs(current.last);
    return incomingActive >= tailActive;
  }

  List<V2TimConversation> _trimWindowKeepingHot(
    List<V2TimConversation> sorted,
  ) {
    if (ConversationPerfFlags.uiWindowHardCapEnabled) {
      return ConversationLocalStore.trimUiWindowWithTypeFloors(sorted);
    }
    // 未扩展热窗：硬顶虽关，仍用滑动预算作有效硬顶并保单聊/群地板，
    // 避免大量未读群 patch 把 UI 窗挤成「几乎全是群」、单聊闪现后消失。
    // 用户已触底/触顶扩展后不再强行地板裁，以免冲掉 appendOlder 历史页。
    if (!_slidingWindowUserExpanded &&
        ConversationPerfFlags.uiSlidingWindowActive &&
        ConversationPerfFlags.uiSlidingWindowBudget > 0) {
      return ConversationLocalStore.trimUiWindowWithTypeFloors(
        sorted,
        hardCap: ConversationPerfFlags.uiSlidingWindowBudget,
      );
    }
    return List<V2TimConversation>.from(sorted);
  }

  static bool _isGroupConversation(V2TimConversation conversation) {
    return ConversationUnreadUtils.isGroupConversation(conversation);
  }

  /// 会话行 UI 指纹：未变时可跳过行重建，避免空刷打断手势。
  /// 有活跃时间时忽略 orderkey 抖动（SDK 回写常改 orderkey 但不改视觉序）。
  /// 必须含 lastMessage.status，否则 SENDING→SUCC 同 msgID 会被判等跳过。
  /// C2C 追加 DisplayNameStore 片段：备注写入 Store 后即使 showName 未变也能失效行缓存。
  static String conversationUiFingerprint(V2TimConversation conversation) {
    final lastMessage = conversation.lastMessage;
    final lastMsgId = lastMessage?.msgID?.trim() ?? '';
    final lastPeerRead = lastMessage?.isPeerRead == true ? '1' : '0';
    final lastStatus = '${lastMessage?.status ?? -1}';
    final activeMs = ConversationLocalStore.activeTimeMs(conversation);
    final orderKey = activeMs > 0 ? 0 : (conversation.orderkey ?? 0);
    return [
      conversation.conversationID,
      '${conversation.unreadCount ?? 0}',
      '${conversation.isPinned == true}',
      '${conversation.recvOpt ?? 0}',
      '$orderKey',
      '$activeMs',
      lastMsgId,
      lastStatus,
      lastPeerRead,
      revokedLastMessageFingerprint(lastMessage),
      _lastMessagePreviewFingerprint(lastMessage),
      conversation.showName?.trim() ?? '',
      conversation.faceUrl?.trim() ?? '',
      conversation.draftText?.trim() ?? '',
      c2cDisplayNameStoreFragment(conversation),
    ].join('|');
  }

  /// 会话列表行会缓存 child；同一 msgID 的编辑、群 tip 补全或 CUSTOM
  /// payload 更新不能只靠 ID/status 判断，否则会持续显示旧预览。
  ///
  /// 只读取列表摘要所需的轻量字段，避免热路径序列化整条消息 JSON。
  static String _lastMessagePreviewFingerprint(V2TimMessage? message) {
    if (message == null) {
      return '';
    }
    final groupTips = message.groupTipsElem;
    return Object.hash(
      message.elemType,
      message.textElem?.text?.trim() ?? '',
      message.customElem?.data?.trim() ?? '',
      message.customElem?.desc?.trim() ?? '',
      message.faceElem?.data?.trim() ?? '',
      message.sender?.trim() ?? '',
      message.nickName?.trim() ?? '',
      message.nameCard?.trim() ?? '',
      groupTips?.type,
      groupTips?.groupID.trim() ?? '',
      groupTips?.opMember.userID?.trim() ?? '',
      groupTips?.memberList
              ?.map((member) => member?.userID?.trim() ?? '')
              .join(',') ??
          '',
      message.revokeReason?.trim() ?? '',
    ).toString();
  }

  /// 仅 C2C 读取 DisplayNameStore（O(1) Map），群会话返回空串。
  @visibleForTesting
  static String c2cDisplayNameStoreFragment(V2TimConversation conversation) {
    if (conversation.type == 2 ||
        (conversation.groupID?.trim().isNotEmpty ?? false)) {
      return '';
    }
    final fromUser = conversation.userID?.trim() ?? '';
    final fromConv = conversation.conversationID.trim();
    final raw = fromUser.isNotEmpty
        ? fromUser
        : (fromConv.startsWith('c2c_') ? fromConv.substring(4) : fromConv);
    final userId = ChatIdFormat.rawUserUid(raw);
    if (userId.isEmpty) {
      return '';
    }
    return DisplayNameStore.instance.c2c(userId)?.trim() ?? '';
  }

  /// 好友备注等写入 DisplayNameStore 后，点名同步会话行并通知列表（轻量，单会话）。
  ///
  /// [busRevision] 用于单聊/群聊双 Feed 去重；同 revision 只处理一次。
  void applyPeerDisplayNameFromStore(
    String userId, {
    int? busRevision,
  }) {
    if (busRevision != null) {
      if (busRevision == _lastPeerDisplayAppliedRevision) {
        return;
      }
      _lastPeerDisplayAppliedRevision = busRevision;
    }
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return;
    }
    final name = DisplayNameStore.instance.c2c(id)?.trim() ?? '';
    if (name.isEmpty) {
      return;
    }
    final before = _contentRevision;
    applyShowNameLocally(conversationID: 'c2c_$id', showName: name);
    // showName 未变时仍 bump：行指纹含 Store，且 resolveC2C 优先 Store。
    if (_contentRevision == before) {
      _bumpRevisionsForChange(orderOrMembershipChanged: false);
      _notifyIfAllowed(reason: 'peer_display_name_store');
    }
  }

  /// 内存改 recvOpt（免打扰）并通知列表行刷新。
  void applyRecvOptLocally({
    required String conversationID,
    required int recvOpt,
    V2TimConversation? snapshot,
  }) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    _noteRecvOptLocalGrace(conversationId: id, recvOpt: recvOpt);
    final next = List<V2TimConversation>.from(_conversations);
    var changed = false;
    var found = false;
    for (var i = 0; i < next.length; i++) {
      if (!MessageConversationId.sameConversation(next[i].conversationID, id)) {
        continue;
      }
      found = true;
      if ((next[i].recvOpt ?? 0) == recvOpt) {
        break;
      }
      next[i] = _cloneConversationWithRecvOpt(next[i], recvOpt: recvOpt);
      changed = true;
      break;
    }
    if (!found && snapshot != null) {
      final created = _cloneConversationWithRecvOpt(
        snapshot,
        recvOpt: recvOpt,
      );
      ConversationLocalStore.decorateConversationForUi(created);
      if (_shouldAdmitToUiWindow(created, next)) {
        next.add(created);
        changed = true;
      }
    }

    var hydrateValueChanged = false;
    final hydrateType = _patchTypeHydrateConversation(
      id,
      update: (current) {
        if ((current.recvOpt ?? 0) == recvOpt) {
          return current;
        }
        hydrateValueChanged = true;
        return _cloneConversationWithRecvOpt(current, recvOpt: recvOpt);
      },
      reorder: false,
      field: 'recvOpt',
    );
    if (hydrateType != null) {
      if (changed) {
        _conversations = next;
      }
      if (ConversationPerfFlags.conversationListSdkPrimary &&
          (changed || hydrateValueChanged)) {
        V2TimConversation? row;
        for (final c in _conversations) {
          if (MessageConversationId.sameConversation(c.conversationID, id)) {
            row = c;
            break;
          }
        }
        if (row != null) {
          ConversationTabStore.instance.applyPatches(
            [row],
            reason: 'recv_opt_local',
          );
        }
      }
      _bumpRevisionsForChange(orderOrMembershipChanged: false);
      _notifyIfAllowed(
        reason: (changed || hydrateValueChanged)
            ? 'recv_opt_local'
            : 'recv_opt_local_same',
      );
      return;
    }

    if (!changed) {
      if (found) {
        _bumpRevisionsForChange(orderOrMembershipChanged: false);
        _notifyIfAllowed(reason: 'recv_opt_local_same');
      }
      return;
    }
    _conversations = next;
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      V2TimConversation? row;
      for (final c in next) {
        if (MessageConversationId.sameConversation(c.conversationID, id)) {
          row = c;
          break;
        }
      }
      if (row != null) {
        ConversationTabStore.instance.applyPatches(
          [row],
          reason: 'recv_opt_local',
        );
      }
    }
    _bumpRevisionsForChange(orderOrMembershipChanged: false);
    _notifyIfAllowed(reason: 'recv_opt_local');
  }

  void _noteRecvOptLocalGrace({
    required String conversationId,
    required int recvOpt,
  }) {
    final grace = ConversationPerfFlags.recvOptLocalGrace;
    if (grace <= Duration.zero) {
      return;
    }
    final until = DateTime.now().millisecondsSinceEpoch + grace.inMilliseconds;
    _recvOptLocalGraceById[conversationId.trim()] = (
      recvOpt: recvOpt,
      untilMs: until,
    );
  }

  void _applyRecvOptLocalGraceIfNeeded(V2TimConversation conversation) {
    final id = conversation.conversationID.trim();
    if (id.isEmpty || _recvOptLocalGraceById.isEmpty) {
      return;
    }
    MapEntry<String, ({int recvOpt, int untilMs})>? hit;
    for (final entry in _recvOptLocalGraceById.entries) {
      if (MessageConversationId.sameConversation(entry.key, id)) {
        hit = entry;
        break;
      }
    }
    if (hit == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now > hit.value.untilMs) {
      _recvOptLocalGraceById.remove(hit.key);
      return;
    }
    conversation.recvOpt = hit.value.recvOpt;
  }

  /// 本地改会话展示名（备注/昵称）并通知列表行刷新。
  ///
  /// 虚拟列表读 `_typeHydrate`：必须同步 patch，否则行指纹不变更仍显示旧名。
  void applyShowNameLocally({
    required String conversationID,
    required String showName,
  }) {
    applyC2cShowNamesBatch(<String, String>{
      conversationID.trim(): showName.trim(),
    });
  }

  /// 批量写入 C2C 展示名（key 为 conversationID 或可被 [MessageConversationId] 匹配的 id）。
  ///
  /// 一次 bump/notify，避免好友全量 seed 时 N 次刷新风暴。
  void applyC2cShowNamesBatch(Map<String, String> conversationIdToShowName) {
    if (conversationIdToShowName.isEmpty) {
      return;
    }
    final normalized = <String, String>{};
    conversationIdToShowName.forEach((rawId, rawName) {
      final id = rawId.trim();
      final name = rawName.trim();
      if (id.isEmpty || name.isEmpty) {
        return;
      }
      normalized[id] = name;
    });
    if (normalized.isEmpty) {
      return;
    }

    final next = List<V2TimConversation>.from(_conversations);
    var listChanged = false;
    for (var i = 0; i < next.length; i++) {
      final cid = next[i].conversationID;
      String? name;
      for (final entry in normalized.entries) {
        if (MessageConversationId.sameConversation(cid, entry.key)) {
          name = entry.value;
          break;
        }
      }
      if (name == null) {
        continue;
      }
      if ((next[i].showName?.trim() ?? '') == name) {
        continue;
      }
      next[i] = _cloneConversationWithShowName(next[i], showName: name);
      listChanged = true;
    }

    var hydrateChanged = false;
    for (final entry in normalized.entries) {
      _patchTypeHydrateConversation(
        entry.key,
        update: (current) {
          if ((current.showName?.trim() ?? '') == entry.value) {
            return current;
          }
          hydrateChanged = true;
          return _cloneConversationWithShowName(
            current,
            showName: entry.value,
          );
        },
        reorder: false,
        field: 'showName',
      );
    }

    if (!listChanged && !hydrateChanged) {
      // Store 已变但 showName 相同：仍 bump，使行指纹含 DisplayNameStore 片段失效。
      _bumpRevisionsForChange(orderOrMembershipChanged: false);
      _notifyIfAllowed(reason: 'c2c_show_name_batch_store');
      return;
    }

    if (listChanged) {
      _conversations = next;
      if (ConversationPerfFlags.conversationListSdkPrimary) {
        final patchedRows = <V2TimConversation>[];
        for (final c in next) {
          for (final entry in normalized.entries) {
            if (MessageConversationId.sameConversation(
              c.conversationID,
              entry.key,
            )) {
              patchedRows.add(c);
              break;
            }
          }
        }
        if (patchedRows.isNotEmpty) {
          ConversationTabStore.instance.applyPatches(
            patchedRows,
            reason: 'c2c_show_name_batch',
          );
        }
      }
    }
    _bumpRevisionsForChange(orderOrMembershipChanged: false);
    _notifyIfAllowed(reason: 'c2c_show_name_batch');
  }

  /// 本地改群/会话头像并通知列表行刷新（虚拟列表须同步 patch hydrate）。
  void applyFaceUrlLocally({
    required String conversationID,
    required String faceUrl,
  }) {
    final id = conversationID.trim();
    final url = faceUrl.trim();
    if (id.isEmpty || url.isEmpty) {
      return;
    }
    final next = List<V2TimConversation>.from(_conversations);
    var changed = false;
    for (var i = 0; i < next.length; i++) {
      if (!MessageConversationId.sameConversation(next[i].conversationID, id)) {
        continue;
      }
      if ((next[i].faceUrl?.trim() ?? '') == url) {
        break;
      }
      next[i] = _cloneConversationWithFaceUrl(next[i], faceUrl: url);
      changed = true;
      break;
    }

    var hydrateValueChanged = false;
    final hydrateType = _patchTypeHydrateConversation(
      id,
      update: (current) {
        if ((current.faceUrl?.trim() ?? '') == url) {
          return current;
        }
        hydrateValueChanged = true;
        return _cloneConversationWithFaceUrl(current, faceUrl: url);
      },
      reorder: false,
      field: 'faceUrl',
    );

    void patchTabStoreIfNeeded(List<V2TimConversation> source) {
      if (!ConversationPerfFlags.conversationListSdkPrimary) {
        return;
      }
      V2TimConversation? row;
      for (final c in source) {
        if (MessageConversationId.sameConversation(c.conversationID, id)) {
          row = c;
          break;
        }
      }
      if (row != null) {
        ConversationTabStore.instance.applyPatches(
          [row],
          reason: 'face_url_local',
        );
      }
    }

    if (hydrateType != null) {
      if (changed) {
        _conversations = next;
      }
      if (changed || hydrateValueChanged) {
        patchTabStoreIfNeeded(_conversations);
        _bumpRevisionsForChange(orderOrMembershipChanged: false);
        _notifyIfAllowed(reason: 'face_url_local');
      }
      return;
    }

    if (!changed) {
      return;
    }
    _conversations = next;
    patchTabStoreIfNeeded(next);
    _bumpRevisionsForChange(orderOrMembershipChanged: false);
    _notifyIfAllowed(reason: 'face_url_local');
  }

  V2TimConversation _cloneConversationWithRecvOpt(
    V2TimConversation source, {
    required int recvOpt,
  }) {
    final cloned = _cloneConversationWithPin(
      source,
      isPinned: source.isPinned == true,
      orderkey: source.orderkey,
    );
    cloned.recvOpt = recvOpt;
    return cloned;
  }

  V2TimConversation _cloneConversationWithShowName(
    V2TimConversation source, {
    required String showName,
  }) {
    final cloned = _cloneConversationWithPin(
      source,
      isPinned: source.isPinned == true,
      orderkey: source.orderkey,
    );
    cloned.showName = showName;
    return cloned;
  }

  V2TimConversation _cloneConversationWithFaceUrl(
    V2TimConversation source, {
    required String faceUrl,
  }) {
    final cloned = _cloneConversationWithPin(
      source,
      isPinned: source.isPinned == true,
      orderkey: source.orderkey,
    );
    cloned.faceUrl = faceUrl;
    return cloned;
  }
}
