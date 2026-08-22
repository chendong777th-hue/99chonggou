import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable_plus_plus/flutter_slidable_plus_plus.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/archived_conversation_entry_visibility.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_folder_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_sync_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_virtual_hydrate_policy.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_flicker_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_system_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_entry_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_live/group_live_index_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_feed_log.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_archived_entry_tile.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_feed_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_feed_rows.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_feed_ui.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_group_notice_entry_tile.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/group_notice_feed_listenable.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart'
    show GroupSystemNoticeItem;
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_conversation_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

class ConversationFeedBody extends StatefulWidget {
  const ConversationFeedBody({
    super.key,
    required this.isGroupTab,
    required this.previewCacheScopeKey,
    required this.archiveScope,
    required this.theme,
    required this.feedScrollController,
    required this.scrollPhysics,
    required this.controller,
    required this.getVisibleConversations,
    required this.getArchivedConversations,
    required this.conversationTimestampMs,
    required this.buildConversationRow,
    required this.onArchivedTap,
    required this.onGroupNoticeTap,
    required this.onGroupNoticePin,
    required this.onGroupNoticeToggleMute,
    required this.onGroupNoticeDelete,
    this.editingSelectionListenable,
    this.isEditingGetter,
    this.isGroupNoticeSelectedGetter,
    this.onGroupNoticeToggleSelect,
    this.onEnsureScopeHydrated,
    this.onScheduleFeedPageLoad,
    this.scopeHydrationFinished = true,
    this.folderFilterActive = false,
    this.folderEmptyMessage,
    this.feedBottomExhausted = false,
  });

  final bool isGroupTab;
  final String previewCacheScopeKey;
  final ConversationArchiveScope archiveScope;
  final TUITheme theme;
  final ScrollController feedScrollController;
  final ScrollPhysics scrollPhysics;
  final TIMUIKitConversationController controller;
  final List<V2TimConversation> Function() getVisibleConversations;
  final List<V2TimConversation> Function() getArchivedConversations;
  final int Function(V2TimConversation conversation) conversationTimestampMs;
  final Widget Function(V2TimConversation conversation) buildConversationRow;
  final VoidCallback onArchivedTap;
  final VoidCallback onGroupNoticeTap;
  final Future<void> Function() onGroupNoticePin;
  final Future<void> Function() onGroupNoticeToggleMute;
  final Future<void> Function() onGroupNoticeDelete;
  final Listenable? editingSelectionListenable;
  final bool Function()? isEditingGetter;
  final bool Function()? isGroupNoticeSelectedGetter;
  final VoidCallback? onGroupNoticeToggleSelect;
  final VoidCallback? onEnsureScopeHydrated;
  final VoidCallback? onScheduleFeedPageLoad;
  final bool scopeHydrationFinished;

  /// 选中具体分组时隐藏归档/群通知入口行。
  final bool folderFilterActive;
  final String? folderEmptyMessage;

  /// 触底已确认无更多（本地+SDK）。
  final bool feedBottomExhausted;

  @override
  State<ConversationFeedBody> createState() => _ConversationFeedBodyState();
}

class _ConversationFeedBodyState extends State<ConversationFeedBody> {
  /// 与会话行视觉高度大致对齐（按设备形态和字体缩放动态计算），用于置顶重排滚动补偿。
  double get _estimatedRowExtent => conversationFeedRowExtent(context);

  late final GroupNoticeFeedListenable _groupNoticeFeedListenable;
  late Listenable _structureFeedListenable;
  String _lastFeedOrderSnapshot = '';
  List<String> _lastVisibleIds = const <String>[];
  int _lastStructureRevision = -1;
  int _cachedGroupNoticeSignature = 0;
  List<ConversationFeedRow>? _cachedFeedRows;
  bool _cachedIncludeArchived = false;
  bool _cachedIncludeGroupNotice = false;
  bool _cachedGroupNoticePinned = false;
  Widget? _inactiveTabCachedChild;
  TUITheme? _inactiveTabCachedTheme;
  int? _inactiveTabCachedContentRevision;

  /// 虚拟列表：未置顶群通知的 inline 插入 typeIndex；`<0` 表示走 header/不展示。
  int _virtualNoticeInsertAt = -1;
  String? _virtualNoticeInsertKey;
  Future<int>? _virtualNoticeInsertFuture;
  bool _virtualSkeletonHydrateScheduled = false;
  int? _pendingVirtualSkeletonType;
  int? _pendingVirtualSkeletonCenter;
  bool _pendingVirtualSkeletonNearEnd = false;

  /// 已处理的 PeerProfile revision，避免同一次 Bus 在 builder 路径重复套用。
  int _lastHandledPeerProfileRevision = -1;

  @override
  void initState() {
    super.initState();
    _groupNoticeFeedListenable = GroupNoticeFeedListenable();
    _structureFeedListenable = _buildStructureFeedListenable();
    PeerProfileRefreshBus.instance.revision.addListener(_onPeerProfileRefresh);
  }

  @override
  void didUpdateWidget(covariant ConversationFeedBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 非活跃 Tab 整表缓存不得跨深浅主题复用。
    if (!identical(oldWidget.theme, widget.theme)) {
      _inactiveTabCachedChild = null;
      _inactiveTabCachedTheme = null;
      _inactiveTabCachedContentRevision = null;
    }
    if (oldWidget.archiveScope != widget.archiveScope ||
        oldWidget.isGroupTab != widget.isGroupTab) {
      _structureFeedListenable = _buildStructureFeedListenable();
    }
  }

  /// Archive / folder / group-notice / settings / live — not list content.
  Listenable _buildStructureFeedListenable() {
    final listenables = <Listenable>[
      archivedConversationIDsNotifierFor(widget.archiveScope),
      // 分组混显单聊+群聊时，另一侧归档变化也要刷新。
      archivedConversationIDsNotifierFor(
        widget.archiveScope == ConversationArchiveScope.group
            ? ConversationArchiveScope.c2c
            : ConversationArchiveScope.group,
      ),
      ArchivedConversationEntryVisibility.instance
          .notifierFor(widget.archiveScope),
      ConversationFolderStore.instance.foldersNotifier,
      _groupNoticeFeedListenable,
      GroupNoticeEntrySettingsService.instance,
      // joinedGroupsRevision 已由 Conversation._onJoinedGroupsRevision 处理；
      // 这里再监听会让同一次 revision 触发两次整棵 Feed 重建。
    ];
    if (widget.isGroupTab) {
      listenables.add(GroupLiveIndexStore.instance);
    }
    return Listenable.merge(listenables);
  }

  @override
  void dispose() {
    PeerProfileRefreshBus.instance.revision.removeListener(
      _onPeerProfileRefresh,
    );
    _groupNoticeFeedListenable.dispose();
    super.dispose();
  }

  void _scheduleVirtualSkeletonHydrate({
    required int convType,
    required int centerIndex,
    required bool nearEnd,
  }) {
    final isScrolling = widget.feedScrollController.hasClients &&
        widget.feedScrollController.position.isScrollingNotifier.value;
    if (!conversationVirtualSkeletonMayRequestHydrate(
      onlyOnScrollSettle:
          ConversationPerfFlags.virtualHydrateOnlyOnScrollSettle,
      isScrolling: isScrolling,
    )) {
      // Conversation owns the scroll listener and hydrates once at the final
      // viewport center when scrolling settles.
      return;
    }
    _pendingVirtualSkeletonType = convType;
    _pendingVirtualSkeletonCenter = centerIndex;
    _pendingVirtualSkeletonNearEnd = _pendingVirtualSkeletonNearEnd || nearEnd;
    if (_virtualSkeletonHydrateScheduled) {
      return;
    }
    _virtualSkeletonHydrateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _virtualSkeletonHydrateScheduled = false;
      if (!mounted) {
        return;
      }
      final stillScrolling = widget.feedScrollController.hasClients &&
          widget.feedScrollController.position.isScrollingNotifier.value;
      if (!conversationVirtualSkeletonMayRequestHydrate(
        onlyOnScrollSettle:
            ConversationPerfFlags.virtualHydrateOnlyOnScrollSettle,
        isScrolling: stillScrolling,
      )) {
        _pendingVirtualSkeletonType = null;
        _pendingVirtualSkeletonCenter = null;
        _pendingVirtualSkeletonNearEnd = false;
        return;
      }
      final type = _pendingVirtualSkeletonType;
      final center = _pendingVirtualSkeletonCenter;
      final shouldLoadMore = _pendingVirtualSkeletonNearEnd;
      _pendingVirtualSkeletonType = null;
      _pendingVirtualSkeletonCenter = null;
      _pendingVirtualSkeletonNearEnd = false;
      if (type != null && center != null) {
        unawaited(
          ConversationListNotifier.instance.ensureTypeIndexHydrated(
            convType: type,
            centerIndex: center,
          ),
        );
      }
      if (shouldLoadMore) {
        widget.onScheduleFeedPageLoad?.call();
      }
    });
  }

  /// 备注等资料变更：只点名同步一条 C2C，不订阅整表 DisplayNameStore。
  void _onPeerProfileRefresh() {
    final rev = PeerProfileRefreshBus.instance.revision.value;
    if (rev == _lastHandledPeerProfileRevision) {
      return;
    }
    _lastHandledPeerProfileRevision = rev;
    final uid = PeerProfileRefreshBus.instance.lastUserId?.trim() ?? '';
    if (uid.isEmpty) {
      return;
    }
    ConversationListNotifier.instance.applyPeerDisplayNameFromStore(
      uid,
      busRevision: rev,
    );
  }

  static bool _sameIdSequence(List<String> a, List<String> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  /// 置顶重排后的滚动策略：保持原 offset，不滚顶、不 +H。
  ///
  /// 旧 keep_viewport 每次 +72（日志 1450→1522）会把列表往上推一截；
  /// 行高也并非固定 72，估算补偿容易过推。重排后只钉住 offset。
  void _compensateScrollForPinReorder({
    required List<String> prevVisibleIds,
    required List<String> nextVisibleIds,
    required String orderSnapshot,
  }) {
    final hint = ConversationListNotifier.instance.takePinReorderScrollHint();
    if (hint == null) {
      return;
    }
    final id = hint.conversationID.trim();
    final scopeFrom = prevVisibleIds.indexOf(id);
    final scopeTo = nextVisibleIds.indexOf(id);
    final controller = widget.feedScrollController;
    if (!controller.hasClients) {
      ConversationPinFlickerLog.log(
        'pin_scroll_skip',
        conversationID: id,
        extras: <String, Object?>{
          'scope': widget.previewCacheScopeKey,
          'reason': 'no_clients',
          'globalFrom': hint.fromIndex,
          'globalTo': hint.toIndex,
          'scopeFrom': scopeFrom,
          'scopeTo': scopeTo,
        },
      );
      return;
    }

    final offsetBefore = controller.offset;
    final maxBefore = controller.position.maxScrollExtent;
    final viewportH = controller.position.viewportDimension;
    final firstVisible =
        (offsetBefore / _estimatedRowExtent).floor().clamp(0, 1 << 20);
    final viewportRows =
        (viewportH / _estimatedRowExtent).ceil().clamp(1, 1 << 20) + 1;
    final lastVisible = firstVisible + viewportRows;
    final fromOnScreen =
        scopeFrom >= 0 && scopeFrom >= firstVisible && scopeFrom < lastVisible;
    final toOnScreen =
        scopeTo >= 0 && scopeTo >= firstVisible && scopeTo < lastVisible;

    // 钉住当前 offset：不 correctBy(+H)，避免「往上推一点点」。
    // 若布局把 pixels 夹出原位，下一帧拉回（绝不能跳到 0）。
    final pinnedOffset = offsetBefore;
    if (controller.hasClients &&
        (controller.offset - pinnedOffset).abs() > 0.5) {
      controller.position.correctBy(pinnedOffset - controller.offset);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) {
        return;
      }
      final max = controller.position.maxScrollExtent;
      final target = pinnedOffset.clamp(0.0, max);
      if ((controller.offset - target).abs() > 1.0) {
        controller.jumpTo(target);
        ConversationPinFlickerLog.log(
          'pin_scroll_postframe',
          conversationID: id,
          extras: <String, Object?>{
            'scope': widget.previewCacheScopeKey,
            'offset': controller.offset.toStringAsFixed(1),
            'target': target.toStringAsFixed(1),
            'max': max.toStringAsFixed(1),
          },
        );
      }
    });

    ConversationPinFlickerLog.log(
      'pin_scroll_compensate',
      conversationID: id,
      extras: <String, Object?>{
        'scope': widget.previewCacheScopeKey,
        'mode': 'keep_offset',
        'fromOnScreen': fromOnScreen,
        'toOnScreen': toOnScreen,
        'viewportRows': viewportRows,
        'globalFrom': hint.fromIndex,
        'globalTo': hint.toIndex,
        'scopeFrom': scopeFrom,
        'scopeTo': scopeTo,
        'firstVisibleEst': firstVisible,
        'maxBefore': maxBefore.toStringAsFixed(1),
        'offsetBefore': offsetBefore.toStringAsFixed(1),
        'offsetAfter':
            controller.hasClients ? controller.offset.toStringAsFixed(1) : 'na',
        'deltaPx': '0.0',
        'isPinned': hint.isPinned,
        'order': orderSnapshot,
      },
    );
  }

  List<V2TimGroupApplication> _applications() {
    return GroupJoinApplicationService.instance.applications;
  }

  List<GroupSystemNoticeItem> _notices() {
    return List<GroupSystemNoticeItem>.from(
      GroupSystemNoticeService.instance.notices,
    )..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Widget build(BuildContext context) {
    ConversationPinFlickerLog.log(
      'feed_state_build',
      extras: <String, Object?>{
        'scope': widget.previewCacheScopeKey,
        'isGroupTab': widget.isGroupTab,
      },
    );
    // 外壳固定：列表数据变化时只重建 ListView 内容，避免整页闪白。
    // ClipRect：左右滑行内容不得画出会话列表区域（尤其 Web 侧栏布局）。
    // 单聊/群聊列表不提供下拉刷新（避免误触触发全量 sync）。
    // Outer: archive / folder / group-notice chrome. Inner: list content only.
    return ClipRect(
      child: SlidableAutoCloseBehavior(
        child: AnimatedBuilder(
          animation: _structureFeedListenable,
          builder: (context, _) {
            final applications = _applications();
            final notices = _notices();
            final settings = GroupNoticeEntrySettingsService.instance;
            final includeArchivedEntry = !widget.folderFilterActive &&
                ArchivedConversationEntryVisibility.instance
                    .shouldShow(widget.archiveScope);
            final includeGroupNoticeEntry =
                !widget.folderFilterActive && widget.isGroupTab;
            final noticeSignature = groupNoticeFeedSignature(
              applications: applications,
              notices: notices,
              includeGroupNoticeEntry: includeGroupNoticeEntry,
              groupNoticePinned: settings.isPinned,
              dismissWatermarkMs: settings.dismissWatermarkMs,
            );
            if (includeGroupNoticeEntry ||
                noticeSignature != _cachedGroupNoticeSignature) {
              GroupNoticeFeedLog.log('feed_structure', extras: {
                'scope': widget.previewCacheScopeKey,
                'isGroupTab': widget.isGroupTab,
                'include': includeGroupNoticeEntry,
                'sigChanged': noticeSignature != _cachedGroupNoticeSignature,
                'sig': noticeSignature,
                'prevSig': _cachedGroupNoticeSignature,
                'pinned': settings.isPinned,
                'dismissWm': settings.dismissWatermarkMs,
                'snap': GroupNoticeFeedLog.snapshot(
                  applications: applications,
                  notices: notices,
                  signature: noticeSignature,
                  unread: GroupNoticeUnreadService.instance.unreadCount,
                ),
              });
            }

            return AnimatedBuilder(
              animation: ConversationListNotifier.instance,
              builder: (context, _) {
                return _buildFeedForNotifier(
                  context: context,
                  applications: applications,
                  notices: notices,
                  settings: settings,
                  includeArchivedEntry: includeArchivedEntry,
                  includeGroupNoticeEntry: includeGroupNoticeEntry,
                  noticeSignature: noticeSignature,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeedForNotifier({
    required BuildContext context,
    required List<V2TimGroupApplication> applications,
    required List<GroupSystemNoticeItem> notices,
    required GroupNoticeEntrySettingsService settings,
    required bool includeArchivedEntry,
    required bool includeGroupNoticeEntry,
    required int noticeSignature,
  }) {
    // 非活跃且主题 identity / contentRevision 未变：复用整表缓存。
    // 变了才重建（C1-a 新鲜度）。主题 identity 变化时清空缓存（见 didUpdateWidget）。
    // 进首页路由转场时当前 Tab 也可能 TickerMode=false；
    // 缓存为空时仍要 build 一次，避免启动图结束后先空壳再灌列表。
    final tabActive = TickerMode.of(context);
    final contentRevision = ConversationListNotifier.instance.contentRevision;
    if (shouldReuseInactiveConversationFeed(
      tabActive: tabActive,
      hasCachedChild: _inactiveTabCachedChild != null,
      cachedThemeToken: _inactiveTabCachedTheme,
      currentThemeToken: widget.theme,
      cachedContentRevision: _inactiveTabCachedContentRevision,
      currentContentRevision: contentRevision,
    )) {
      return _inactiveTabCachedChild!;
    }
    if (!tabActive && _inactiveTabCachedChild == null) {
      ConversationPinFlickerLog.log(
        'feed_list_prime_while_inactive',
        extras: <String, Object?>{
          'scope': widget.previewCacheScopeKey,
        },
      );
    } else if (!tabActive) {
      ConversationPinFlickerLog.log(
        'feed_list_inactive_rebuild',
        extras: <String, Object?>{
          'scope': widget.previewCacheScopeKey,
          'contentRevision': contentRevision,
        },
      );
    }

    final structureRevision =
        ConversationListNotifier.instance.structureRevision;
    final useVirtual = ConversationPerfFlags.conversationVirtualListEnabled &&
        !widget.folderFilterActive;
    final emptyMessage = widget.folderEmptyMessage ??
        (widget.isGroupTab
            ? AppI18n.of(context).t(
                zhHans: '暂无群聊',
                zhHant: '暫無群聊',
                en: 'No groups yet',
                ja: 'グループはありません',
                ko: '그룹이 없습니다',
              )
            : AppI18n.of(context).t(
                zhHans: '暂无会话',
                zhHant: '暫無會話',
                en: 'No chats yet',
                ja: '会話はありません',
                ko: '대화가 없습니다',
              ));

    final skipVisible = conversationFeedCanSkipVisibleMaterialization(
      useVirtual: useVirtual,
      folderFilterActive: widget.folderFilterActive,
      structureRevision: structureRevision,
      lastStructureRevision: _lastStructureRevision,
      includeArchivedEntry: includeArchivedEntry,
      cachedIncludeArchived: _cachedIncludeArchived,
      includeGroupNoticeEntry: includeGroupNoticeEntry,
      cachedIncludeGroupNotice: _cachedIncludeGroupNotice,
      groupNoticePinned: settings.isPinned,
      cachedGroupNoticePinned: _cachedGroupNoticePinned,
      noticeSignature: noticeSignature,
      cachedGroupNoticeSignature: _cachedGroupNoticeSignature,
    );

    if (skipVisible) {
      if (!ConversationListNotifier.instance.hasLocalData &&
          !ConversationListSyncNotifier.instance.isSyncing &&
          !widget.scopeHydrationFinished) {
        widget.onEnsureScopeHydrated?.call();
      }
      final virtualTotal = ConversationListNotifier.instance.totalCountForType(
        widget.isGroupTab ? 2 : 1,
      );
      final built = virtualTotal <= 0
          ? ConversationFeedEmptyState(
              isGroupTab: widget.isGroupTab,
              businessEmptyBuilder: (context) => AppEmptyState(
                padding: const EdgeInsets.only(top: 80),
                message: emptyMessage,
              ),
            )
          : _buildVirtualFeedListView(
              includeArchivedEntry: includeArchivedEntry,
              includeGroupNoticeEntry: includeGroupNoticeEntry,
              settings: settings,
            );
      _inactiveTabCachedChild = built;
      _inactiveTabCachedTheme = widget.theme;
      _inactiveTabCachedContentRevision = contentRevision;
      return built;
    }

    final visibleConversations = widget.getVisibleConversations();
    if (visibleConversations.isEmpty &&
        !ConversationListSyncNotifier.instance.isSyncing &&
        !widget.scopeHydrationFinished) {
      widget.onEnsureScopeHydrated?.call();
    }
    final nextVisibleIds = visibleConversations
        .map((c) => c.conversationID.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final canPatchStructure = structureRevision == _lastStructureRevision &&
        _cachedFeedRows != null &&
        _sameIdSequence(_lastVisibleIds, nextVisibleIds) &&
        includeArchivedEntry == _cachedIncludeArchived &&
        includeGroupNoticeEntry == _cachedIncludeGroupNotice &&
        settings.isPinned == _cachedGroupNoticePinned &&
        noticeSignature == _cachedGroupNoticeSignature;
    final List<ConversationFeedRow> rows;
    if (canPatchStructure) {
      rows = patchConversationFeedRowsById(
        cached: _cachedFeedRows!,
        visible: visibleConversations,
        conversationTimestampMs: widget.conversationTimestampMs,
      );
    } else {
      rows = buildConversationFeedRows(
        conversations: visibleConversations,
        includeArchivedEntry: includeArchivedEntry,
        includeGroupNoticeEntry: includeGroupNoticeEntry,
        applications: applications,
        notices: notices,
        conversationTimestampMs: widget.conversationTimestampMs,
        groupNoticePinned: settings.isPinned,
        groupNoticeDismissWatermarkMs: settings.dismissWatermarkMs,
      );
    }
    _cachedFeedRows = rows;
    _lastStructureRevision = structureRevision;
    _cachedIncludeArchived = includeArchivedEntry;
    _cachedIncludeGroupNotice = includeGroupNoticeEntry;
    _cachedGroupNoticePinned = settings.isPinned;
    _cachedGroupNoticeSignature = noticeSignature;
    // 虚拟列表通过 typeIndex 定位子项，不需要构建整窗 ID→index map。
    // 该 map 仅供普通 ListView 的 findChildIndexCallback 使用。
    final rowIndexByConversationId = <String, int>{};
    if (!useVirtual) {
      for (var i = 0; i < rows.length; i++) {
        final id = rows[i].conversation?.conversationID;
        if (id != null && id.isNotEmpty) {
          rowIndexByConversationId[id] = i;
        }
      }
    }
    final order = ConversationPinFlickerLog.orderSnapshot(
      visibleConversations,
    );
    final prevVisibleIds = _lastVisibleIds;
    // 长列表勿 join 全量 ID 串：用长度+hash 判序变更即可。
    var idsHash = nextVisibleIds.length;
    for (final id in nextVisibleIds) {
      idsHash = Object.hash(idsHash, id);
    }
    final idsOrder = '${nextVisibleIds.length}:$idsHash';
    final orderChanged = idsOrder != _lastFeedOrderSnapshot;
    _lastFeedOrderSnapshot = idsOrder;
    _lastVisibleIds = nextVisibleIds;
    final scrollOffset = widget.feedScrollController.hasClients
        ? widget.feedScrollController.offset
        : -1.0;
    final firstVisibleEst = scrollOffset < 0
        ? -1
        : (scrollOffset / _estimatedRowExtent).floor();
    ConversationPinFlickerLog.log(
      'feed_list_rebuild',
      extras: <String, Object?>{
        'scope': widget.previewCacheScopeKey,
        'rows': rows.length,
        'visible': visibleConversations.length,
        'orderChanged': orderChanged,
        'tabActive': tabActive,
        'deferring': ConversationListNotifier.instance.isDeferringPinReorder,
        'scroll': scrollOffset < 0 ? 'na' : scrollOffset.toStringAsFixed(1),
        'firstVisibleEst': firstVisibleEst,
        'order': order,
      },
    );
    if (tabActive) {
      _compensateScrollForPinReorder(
        prevVisibleIds: prevVisibleIds,
        nextVisibleIds: nextVisibleIds,
        orderSnapshot: order,
      );
    }

    final virtualTotal = useVirtual
        ? ConversationListNotifier.instance.totalCountForType(
            widget.isGroupTab ? 2 : 1,
          )
        : 0;
    final built = (rows.isEmpty && virtualTotal <= 0)
        ? ConversationFeedEmptyState(
            isGroupTab: widget.isGroupTab,
            businessEmptyBuilder: (context) => AppEmptyState(
              padding: const EdgeInsets.only(top: 80),
              message: emptyMessage,
            ),
          )
        : (useVirtual && virtualTotal > 0)
            ? _buildVirtualFeedListView(
                includeArchivedEntry: includeArchivedEntry,
                includeGroupNoticeEntry: includeGroupNoticeEntry,
                settings: settings,
              )
            : _buildFeedListView(
                rows: rows,
                rowIndexByConversationId: rowIndexByConversationId,
                settings: settings,
              );
    _inactiveTabCachedChild = built;
    _inactiveTabCachedTheme = widget.theme;
    _inactiveTabCachedContentRevision = contentRevision;
    return built;
  }

  /// 真虚拟列表：可滚条数 = 库内类型总数 + 可选 inline 群通知槽；行按 typeIndex 水合。
  Widget _buildVirtualFeedListView({
    required bool includeArchivedEntry,
    required bool includeGroupNoticeEntry,
    required GroupNoticeEntrySettingsService settings,
  }) {
    final convType = widget.isGroupTab ? 2 : 1;
    final notifier = ConversationListNotifier.instance;
    final total = notifier.totalCountForType(convType).clamp(0, 1 << 20);
    final applications = GroupJoinApplicationService.instance.applications;
    final notices = GroupSystemNoticeService.instance.notices;
    final shouldShow = includeGroupNoticeEntry &&
        shouldShowGroupNoticeEntry(
          applications,
          notices,
          dismissWatermarkMs: settings.dismissWatermarkMs,
        );
    final showHeaderGroupNotice = shouldShow && settings.isPinned;
    final showInlineGroupNotice = shouldShow && !settings.isPinned;
    final noticeTs =
        shouldShow ? latestGroupNoticeTimestampMs(applications, notices) : 0;
    final noticeSignature = groupNoticeFeedSignature(
      applications: applications,
      notices: notices,
      includeGroupNoticeEntry: includeGroupNoticeEntry,
      groupNoticePinned: settings.isPinned,
      dismissWatermarkMs: settings.dismissWatermarkMs,
    );
    final headerCount =
        (includeArchivedEntry ? 1 : 0) + (showHeaderGroupNotice ? 1 : 0);
    final structureRevision = notifier.structureRevision;
    final insertFuture = showInlineGroupNotice
        ? _virtualNoticeInsertAtFuture(
            convType: convType,
            noticeTs: noticeTs,
            noticeSignature: noticeSignature,
            total: total,
            structureRevision: structureRevision,
          )
        : null;
    if (!showInlineGroupNotice) {
      _virtualNoticeInsertAt = -1;
      _virtualNoticeInsertKey = null;
      _virtualNoticeInsertFuture = null;
    }

    return FutureBuilder<int>(
      future: insertFuture,
      builder: (context, snapshot) {
        final noticeInsertAt = showInlineGroupNotice
            ? (snapshot.data ?? _virtualNoticeInsertAt).clamp(0, total)
            : -1;
        if (showInlineGroupNotice && snapshot.hasData) {
          _virtualNoticeInsertAt = snapshot.data!.clamp(0, total);
        }
        final showFooter = widget.feedBottomExhausted;
        final bodyExtra = showInlineGroupNotice ? 1 : 0;
        final itemCount =
            headerCount + total + bodyExtra + (showFooter ? 1 : 0);

        Widget buildNoticeTile() {
          final editing = widget.isEditingGetter?.call() ?? false;
          final selected = widget.isGroupNoticeSelectedGetter?.call() ?? false;
          return ConversationGroupNoticeEntryTile(
            key: const ValueKey<String>('feed_group_notice'),
            theme: widget.theme,
            controller: widget.controller,
            onTap: widget.onGroupNoticeTap,
            onPin: widget.onGroupNoticePin,
            onToggleMute: widget.onGroupNoticeToggleMute,
            onDelete: widget.onGroupNoticeDelete,
            isPinned: settings.isPinned,
            isMuted: settings.isMuted,
            isEditing: editing,
            isSelected: selected,
            onToggleSelect: widget.onGroupNoticeToggleSelect,
            wrapWithSlidable: !editing,
          );
        }

        Widget maybeAnimateNotice(Widget child) {
          final listenable = widget.editingSelectionListenable;
          if (listenable == null) {
            return child;
          }
          return AnimatedBuilder(
            animation: listenable,
            builder: (context, _) => buildNoticeTile(),
          );
        }

        return ListView.builder(
          key: PageStorageKey<String>(
            'conversation_feed_virtual_${widget.previewCacheScopeKey}',
          ),
          controller: widget.feedScrollController,
          physics: widget.scrollPhysics,
          addAutomaticKeepAlives: false,
          cacheExtent: ConversationPerfFlags.conversationFeedCacheExtent,
          itemCount: itemCount,
          itemExtent: _estimatedRowExtent,
          findChildIndexCallback: (Key key) {
            if (key is! ValueKey<String>) {
              return null;
            }
            final raw = key.value;
            if (raw.startsWith('vidx:')) {
              final idx = int.tryParse(raw.substring(5));
              if (idx == null || idx < 0 || idx >= total) {
                return null;
              }
              return virtualFeedListIndexForTypeIndex(
                typeIndex: idx,
                headerCount: headerCount,
                noticeInsertAt: noticeInsertAt,
              );
            }
            if (raw == 'feed_archived') {
              return includeArchivedEntry ? 0 : null;
            }
            if (raw == 'feed_group_notice') {
              if (showHeaderGroupNotice) {
                return includeArchivedEntry ? 1 : 0;
              }
              if (showInlineGroupNotice && noticeInsertAt >= 0) {
                return headerCount + noticeInsertAt;
              }
              return null;
            }
            final typeIndex = notifier.typeIndexOfConversationId(convType, raw);
            if (typeIndex == null) {
              return null;
            }
            return virtualFeedListIndexForTypeIndex(
              typeIndex: typeIndex,
              headerCount: headerCount,
              noticeInsertAt: noticeInsertAt,
            );
          },
          itemBuilder: (context, index) {
            if (index < headerCount) {
              if (includeArchivedEntry && index == 0) {
                return ConversationArchivedEntryTile(
                  key: const ValueKey<String>('feed_archived'),
                  theme: widget.theme,
                  archiveScope: widget.archiveScope,
                  getArchivedConversations: widget.getArchivedConversations,
                  onTap: widget.onArchivedTap,
                );
              }
              return maybeAnimateNotice(buildNoticeTile());
            }
            final bodyIndex = index - headerCount;
            final bodyLen = total + bodyExtra;
            if (bodyIndex >= bodyLen) {
              return Padding(
                key: const ValueKey<String>('feed_no_more'),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    AppI18n.of(context).t(
                      zhHans: '没有更多了',
                      zhHant: '沒有更多了',
                      en: 'No more',
                      ja: 'これ以上ありません',
                      ko: '더 이상 없음',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.theme.weakTextColor,
                    ),
                  ),
                ),
              );
            }
            if (virtualFeedBodyIndexIsGroupNotice(
              bodyIndex: bodyIndex,
              noticeInsertAt: noticeInsertAt,
            )) {
              return maybeAnimateNotice(buildNoticeTile());
            }
            final typeIndex = virtualFeedTypeIndexForBodyIndex(
              bodyIndex: bodyIndex,
              noticeInsertAt: noticeInsertAt,
              total: total,
            );
            if (typeIndex == null) {
              return SizedBox(
                key: ValueKey<String>('vidx_gap:$bodyIndex'),
                height: _estimatedRowExtent,
              );
            }

            final conversation =
                notifier.conversationAtTypeIndex(convType, typeIndex);
            if (conversation == null) {
              _scheduleVirtualSkeletonHydrate(
                convType: convType,
                centerIndex: typeIndex,
                nearEnd: typeIndex >= total - 8,
              );
              return KeyedSubtree(
                key: ValueKey<String>('vidx:$typeIndex'),
                child: buildConversationFeedRowSkeleton(
                  context,
                  widget.theme,
                  variance: typeIndex,
                  height: _estimatedRowExtent,
                ),
              );
            }
            return _ConversationFeedRowSlot(
              key: ValueKey(conversation.conversationID),
              conversation: conversation,
              themeToken: widget.theme,
              builder: widget.buildConversationRow,
            );
          },
        );
      },
    );
  }

  Future<int> _virtualNoticeInsertAtFuture({
    required int convType,
    required int noticeTs,
    required int noticeSignature,
    required int total,
    required int structureRevision,
  }) {
    final key =
        '$convType|$noticeTs|$noticeSignature|$total|$structureRevision';
    if (_virtualNoticeInsertKey == key && _virtualNoticeInsertFuture != null) {
      return _virtualNoticeInsertFuture!;
    }
    _virtualNoticeInsertKey = key;
    final future = () async {
      final exclude = ConversationPerfFlags.virtualListExcludeArchivedEnabled
          ? (convType == 2
              ? archivedConversationGroupIDsNotifier.value
              : archivedConversationC2cIDsNotifier.value)
          : null;
      final pinned =
          await ConversationLocalStore.instance.countPinnedByConvType(
        convType: convType,
        excludeConversationIds: exclude,
      );
      final newer = await ConversationLocalStore.instance
          .countNonPinnedNewerThanByConvType(
        convType: convType,
        thresholdActiveTimeMs: noticeTs,
        excludeConversationIds: exclude,
      );
      return computeGroupNoticeInsertTypeIndex(
        groupNoticePinned: false,
        total: total,
        pinnedCount: pinned,
        nonPinnedNewerThanNoticeCount: newer,
      );
    }();
    _virtualNoticeInsertFuture = future;
    return future;
  }

  Widget _buildFeedListView({
    required List<ConversationFeedRow> rows,
    required Map<String, int> rowIndexByConversationId,
    required GroupNoticeEntrySettingsService settings,
  }) {
    final showExhaustedFooter = widget.feedBottomExhausted;
    final extra = showExhaustedFooter ? 1 : 0;

    return ListView.builder(
      key: PageStorageKey<String>(
        'conversation_feed_${widget.previewCacheScopeKey}',
      ),
      controller: widget.feedScrollController,
      physics: widget.scrollPhysics,
      addAutomaticKeepAlives: false,
      cacheExtent: ConversationPerfFlags.conversationFeedCacheExtent,
      itemCount: rows.length + extra,
      findChildIndexCallback: (Key key) {
        if (key is! ValueKey<String>) {
          return null;
        }
        return rowIndexByConversationId[key.value];
      },
      itemBuilder: (context, index) {
        if (index >= rows.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                AppI18n.of(context).t(
                  zhHans: '没有更多了',
                  zhHant: '沒有更多了',
                  en: 'No more',
                  ja: 'これ以上ありません',
                  ko: '더 이상 없음',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: widget.theme.weakTextColor,
                ),
              ),
            ),
          );
        }
        final row = rows[index];
        if (row.kind == ConversationFeedRowKind.archived) {
          return ConversationArchivedEntryTile(
            theme: widget.theme,
            archiveScope: widget.archiveScope,
            getArchivedConversations: widget.getArchivedConversations,
            onTap: widget.onArchivedTap,
          );
        }
        if (row.kind == ConversationFeedRowKind.groupNotice) {
          final listenable = widget.editingSelectionListenable;
          Widget buildNoticeTile() {
            final editing = widget.isEditingGetter?.call() ?? false;
            final selected =
                widget.isGroupNoticeSelectedGetter?.call() ?? false;
            return ConversationGroupNoticeEntryTile(
              theme: widget.theme,
              controller: widget.controller,
              onTap: widget.onGroupNoticeTap,
              onPin: widget.onGroupNoticePin,
              onToggleMute: widget.onGroupNoticeToggleMute,
              onDelete: widget.onGroupNoticeDelete,
              isPinned: settings.isPinned,
              isMuted: settings.isMuted,
              isEditing: editing,
              isSelected: selected,
              onToggleSelect: widget.onGroupNoticeToggleSelect,
              wrapWithSlidable: !editing,
            );
          }

          if (listenable == null) {
            return buildNoticeTile();
          }
          return AnimatedBuilder(
            animation: listenable,
            builder: (context, _) => buildNoticeTile(),
          );
        }
        final conversation = row.conversation;
        if (conversation == null) {
          return const SizedBox.shrink();
        }
        return _ConversationFeedRowSlot(
          key: ValueKey(conversation.conversationID),
          conversation: conversation,
          themeToken: widget.theme,
          builder: widget.buildConversationRow,
        );
      },
    );
  }
}

/// 会话行槽位：数据指纹与主题令牌均未变时复用同一 child，避免 notifier 空刷打断左右滑。
/// 主题切换（[themeToken] 身份变化）必须失效缓存，否则可见行会残留旧背景色。
class _ConversationFeedRowSlot extends StatefulWidget {
  const _ConversationFeedRowSlot({
    super.key,
    required this.conversation,
    required this.themeToken,
    required this.builder,
  });

  final V2TimConversation conversation;
  final TUITheme themeToken;
  final Widget Function(V2TimConversation conversation) builder;

  @override
  State<_ConversationFeedRowSlot> createState() =>
      _ConversationFeedRowSlotState();
}

class _ConversationFeedRowSlotState extends State<_ConversationFeedRowSlot> {
  late String _fingerprint;
  late TUITheme _themeToken;
  late Widget Function(V2TimConversation conversation) _builder;
  late Widget _child;

  @override
  void initState() {
    super.initState();
    _fingerprint = ConversationListNotifier.conversationUiFingerprint(
      widget.conversation,
    );
    _themeToken = widget.themeToken;
    _builder = widget.builder;
    _child = RepaintBoundary(child: widget.builder(widget.conversation));
  }

  @override
  void didUpdateWidget(covariant _ConversationFeedRowSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextFingerprint = ConversationListNotifier.conversationUiFingerprint(
      widget.conversation,
    );
    final builderChanged = !identical(widget.builder, _builder);
    final needsRebuild = conversationFeedRowSlotNeedsRebuild(
      nextFingerprint: nextFingerprint,
      currentFingerprint: _fingerprint,
      nextThemeToken: widget.themeToken,
      currentThemeToken: _themeToken,
    );
    // 指纹与主题均未变则复用行；忽略 builder 引用变化（父页 setState 常导致 tear-off 重绑）。
    if (!needsRebuild) {
      if (builderChanged) {
        _builder = widget.builder;
      }
      return;
    }
    final oldPinned = oldWidget.conversation.isPinned == true;
    final newPinned = widget.conversation.isPinned == true;
    final themeChanged = !identical(widget.themeToken, _themeToken);
    ConversationPinFlickerLog.log(
      'feed_row_rebuild',
      conversationID: widget.conversation.conversationID,
      extras: <String, Object?>{
        'pinChanged': oldPinned != newPinned,
        'oldPinned': oldPinned,
        'newPinned': newPinned,
        'builderChanged': builderChanged,
        'themeChanged': themeChanged,
      },
    );
    _fingerprint = nextFingerprint;
    _themeToken = widget.themeToken;
    _builder = widget.builder;
    _child = RepaintBoundary(child: widget.builder(widget.conversation));
  }

  @override
  Widget build(BuildContext context) => _child;
}
