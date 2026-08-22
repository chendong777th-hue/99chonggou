import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_open_perf_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_peek_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_bubble_dedupe.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_history_peek_loader.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_height_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

/// 预热模式：sync Top / 视口 LOCAL / 按下可打云。
enum ConversationWarmMode {
  syncTop,
  viewportLocal,
  press,
}

/// 重连后预热 + 视口停稳 LOCAL 预热 + 按下预热；内存暖窗 LRU 限容。
///
/// 视口通道不走归档 HTTP、不打 CLOUD；页内上拉分页仍用现有 loadChatRecord。
class ConversationHistoryWarmScheduler {
  ConversationHistoryWarmScheduler._();

  static final ConversationHistoryWarmScheduler instance =
      ConversationHistoryWarmScheduler._();

  /// 总开关：关则视口/按下不调度（sync Top 仍可用）。
  static bool viewportWarmEnabled = true;

  static const int sdkWarmLimit = 24;
  static const int memoryWarmLimit = 24;
  static const int memoryWarmCap = 24;
  static const int warmCount = HistoryMessageDartConstant.initialOpenFetchCount;
  static const int viewportWarmCount = 12;
  static const int viewportHardCap = 16;
  static const int viewportPad = 2;
  static const double estimatedRowExtent = 72;
  static const int maxConcurrency = 3;
  static const int viewportMaxConcurrency = 2;
  static const Duration stagger = Duration(milliseconds: 200);
  static const Duration viewportStagger = Duration(milliseconds: 120);
  static const Duration globalCooldown = Duration(seconds: 60);
  static const Duration viewportLocalMissCooldown = Duration(seconds: 30);

  /// dispose 离聊后延迟释放该会话消息窗。
  static const Duration leaveChatMemoryGrace = Duration(seconds: 15);

  /// 孤儿 / 超容 messageListMap 对账淘汰总开关。
  static bool staleReconcileEnabled = true;

  MessageService get _messageService => serviceLocator<MessageService>();

  DateTime? _lastSyncScheduleAt;
  int _syncGeneration = 0;
  int _viewportGeneration = 0;
  Future<void>? _syncInFlight;
  Future<void>? _viewportInFlight;
  final Set<String> _warmingKeys = <String>{};
  bool _pausedForActiveChat = false;
  String? _pauseReason;
  bool _warmPassAbortedByPause = false;

  /// LRU：最近 touch 的在末尾；超 [memoryWarmCap] 淘汰最旧非活跃。
  final LinkedHashMap<String, bool> _memoryLru = LinkedHashMap<String, bool>();
  final Map<String, DateTime> _viewportLocalMissUntil = <String, DateTime>{};
  final Map<String, Timer> _leaveReleaseTimers = <String, Timer>{};

  @visibleForTesting
  void resetForTest() {
    _lastSyncScheduleAt = null;
    _syncGeneration++;
    _viewportGeneration++;
    _syncInFlight = null;
    _viewportInFlight = null;
    _warmingKeys.clear();
    _pausedForActiveChat = false;
    _pauseReason = null;
    _warmPassAbortedByPause = false;
    _memoryLru.clear();
    _viewportLocalMissUntil.clear();
    for (final timer in _leaveReleaseTimers.values) {
      timer.cancel();
    }
    _leaveReleaseTimers.clear();
    viewportWarmEnabled = true;
    staleReconcileEnabled = true;
  }

  bool get isPausedForActiveChat => _pausedForActiveChat;

  void pauseForActiveChat({String reason = 'chat_open'}) {
    if (_pausedForActiveChat) {
      return;
    }
    _pausedForActiveChat = true;
    _pauseReason = reason;
    if (_syncInFlight != null ||
        _viewportInFlight != null ||
        _warmingKeys.isNotEmpty) {
      _warmPassAbortedByPause = true;
    }
    _syncGeneration++;
    _viewportGeneration++;
    ChatHistoryTrace.log(
      'history_warm_paused',
      extras: <String, Object?>{
        'reason': reason,
        'willContinue': _warmPassAbortedByPause,
      },
    );
  }

  void resumeAfterActiveChat({String reason = 'chat_leave'}) {
    if (!_pausedForActiveChat) {
      return;
    }
    _pausedForActiveChat = false;
    final pausedFor = _pauseReason;
    _pauseReason = null;
    final shouldContinue = _warmPassAbortedByPause;
    _warmPassAbortedByPause = false;
    ChatHistoryTrace.log(
      'history_warm_resumed',
      extras: <String, Object?>{
        'reason': reason,
        'pausedFor': pausedFor ?? '',
        'continueWarm': shouldContinue,
      },
    );
    if (shouldContinue) {
      _lastSyncScheduleAt = null;
      scheduleAfterConversationSync(reason: 'resume_incomplete_warm');
    }
    try {
      final globalModel = serviceLocator<TUIChatGlobalModel>();
      _evictMemoryWarmIfNeeded(globalModel);
    } catch (_) {
      // locator 未就绪时跳过对账。
    }
  }

  /// 滚动开始：作废未跑完的视口预热。
  void cancelViewportWarm({String reason = 'scroll'}) {
    _viewportGeneration++;
    ChatHistoryTrace.log(
      'history_warm_viewport_cancel',
      extras: <String, Object?>{'reason': reason},
    );
  }

  void scheduleAfterConversationSync({required String reason}) {
    unawaited(runAfterConversationSync(reason: reason));
  }

  Future<void> runAfterConversationSync({required String reason}) {
    if (_pausedForActiveChat) {
      ChatHistoryTrace.log(
        'history_warm_skip_paused',
        extras: <String, Object?>{
          'reason': reason,
          'pausedFor': _pauseReason ?? '',
        },
      );
      return _syncInFlight ?? Future<void>.value();
    }
    final now = DateTime.now();
    final last = _lastSyncScheduleAt;
    if (last != null && now.difference(last) < globalCooldown) {
      ChatHistoryTrace.log(
        'history_warm_skip_cooldown',
        extras: <String, Object?>{
          'reason': reason,
          'cooldownSec': globalCooldown.inSeconds,
        },
      );
      return _syncInFlight ?? Future<void>.value();
    }
    _lastSyncScheduleAt = now;
    final generation = ++_syncGeneration;
    final task = _runSyncWarmPass(reason: reason, generation: generation);
    _syncInFlight = task.whenComplete(() {
      if (identical(_syncInFlight, task)) {
        _syncInFlight = null;
      }
    });
    return _syncInFlight!;
  }

  /// 列表停稳后：对可见行做 LOCAL-only 预热（不受 sync 60s cooldown 影响）。
  void scheduleViewportWarm({
    required List<V2TimConversation> visibleOrdered,
    required String reason,
  }) {
    if (!viewportWarmEnabled) {
      return;
    }
    unawaited(
      runViewportWarm(visibleOrdered: visibleOrdered, reason: reason),
    );
  }

  Future<void> runViewportWarm({
    required List<V2TimConversation> visibleOrdered,
    required String reason,
  }) {
    if (!viewportWarmEnabled) {
      return Future<void>.value();
    }
    if (_pausedForActiveChat) {
      ChatHistoryTrace.log(
        'history_warm_viewport_skip_paused',
        extras: <String, Object?>{
          'reason': reason,
          'pausedFor': _pauseReason ?? '',
        },
      );
      return _viewportInFlight ?? Future<void>.value();
    }
    final generation = ++_viewportGeneration;
    final ranked = visibleOrdered.length <= viewportHardCap
        ? List<V2TimConversation>.from(visibleOrdered)
        : visibleOrdered.sublist(0, viewportHardCap);
    final task = _runViewportWarmPass(
      reason: reason,
      generation: generation,
      ranked: ranked,
    );
    _viewportInFlight = task.whenComplete(() {
      if (identical(_viewportInFlight, task)) {
        _viewportInFlight = null;
      }
    });
    return _viewportInFlight!;
  }

  /// 按下会话行：允许 LOCAL→CLOUD，与进聊 peek 去重。
  void schedulePressWarm(V2TimConversation conversation) {
    if (!viewportWarmEnabled) {
      return;
    }
    unawaited(runPressWarm(conversation));
  }

  Future<void> runPressWarm(V2TimConversation conversation) async {
    if (!viewportWarmEnabled || _pausedForActiveChat) {
      return;
    }
    // 按下优先：取消仍排队的视口任务，避免抢 SDK。
    _viewportGeneration++;
    try {
      await _warmOne(
        conversation: conversation,
        fillMemory: true,
        mode: ConversationWarmMode.press,
        syncGeneration: _syncGeneration,
        viewportGeneration: _viewportGeneration,
      );
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('ConversationHistoryWarmScheduler press warm failed: $error\n$stack');
      }
    }
  }

  /// 进聊打开时 touch LRU，避免刚开的会话被淘汰。
  void touchMemoryWarm(String cacheKey) {
    final key = cacheKey.trim();
    if (key.isEmpty) {
      return;
    }
    _memoryLru.remove(key);
    _memoryLru[key] = true;
  }

  Future<void> _runSyncWarmPass({
    required String reason,
    required int generation,
  }) async {
    final all = ConversationListNotifier.instance.conversations;
    final archived = archivedConversationIDsNotifier.value;
    final loginUserId = ContactSocialCacheStore.safeLoginUserId();
    final membership = GroupMembershipSyncService.instance;

    final ranked = selectWarmCandidates(
      conversations: all,
      archivedIDs: archived,
      loginUserId: loginUserId,
      shouldShowConversation: membership.shouldShowConversation,
      sdkLimit: sdkWarmLimit,
    );

    ChatHistoryTrace.log(
      'history_warm_start',
      extras: <String, Object?>{
        'reason': reason,
        'generation': generation,
        'mode': ConversationWarmMode.syncTop.name,
        'sourceCount': all.length,
        'selectedCount': ranked.length,
        'sdkLimit': sdkWarmLimit,
        'memoryLimit': memoryWarmLimit,
        'warmCount': warmCount,
      },
    );

    if (ranked.isEmpty) {
      return;
    }

    var nextIndex = 0;
    Future<void> worker() async {
      while (true) {
        if (_pausedForActiveChat || generation != _syncGeneration) {
          return;
        }
        final index = nextIndex++;
        if (index >= ranked.length) {
          return;
        }
        final conversation = ranked[index];
        final fillMemory = index < memoryWarmLimit;
        try {
          await _warmOne(
            conversation: conversation,
            fillMemory: fillMemory,
            mode: ConversationWarmMode.syncTop,
            syncGeneration: generation,
            viewportGeneration: _viewportGeneration,
          );
        } catch (error, stack) {
          if (kDebugMode) {
            debugPrint(
              'ConversationHistoryWarmScheduler warm failed: $error\n$stack',
            );
          }
          ChatHistoryTrace.log(
            'history_warm_error',
            conversationID:
                ConversationPreviewHistorySync.conversationMessageCacheKey(
                      conversation,
                    ) ??
                    conversation.conversationID,
            extras: <String, Object?>{
              'error': error.toString(),
              'fillMemory': fillMemory,
              'mode': ConversationWarmMode.syncTop.name,
            },
          );
        }
        if (_pausedForActiveChat || generation != _syncGeneration) {
          return;
        }
        if (index + 1 < ranked.length) {
          await Future<void>.delayed(stagger);
        }
      }
    }

    final workers = List<Future<void>>.generate(
      maxConcurrency.clamp(1, ranked.length),
      (_) => worker(),
    );
    await Future.wait(workers);

    ChatHistoryTrace.log(
      'history_warm_done',
      extras: <String, Object?>{
        'reason': reason,
        'generation': generation,
        'selectedCount': ranked.length,
        'mode': ConversationWarmMode.syncTop.name,
      },
    );
  }

  Future<void> _runViewportWarmPass({
    required String reason,
    required int generation,
    required List<V2TimConversation> ranked,
  }) async {
    ChatHistoryTrace.log(
      'history_warm_viewport_start',
      extras: <String, Object?>{
        'reason': reason,
        'generation': generation,
        'selectedCount': ranked.length,
        'warmCount': viewportWarmCount,
      },
    );
    ChatOpenPerfLog.mark(
      'history_warm_viewport_start',
      extras: <String, Object?>{
        'reason': reason,
        'selectedCount': ranked.length,
      },
    );

    if (ranked.isEmpty) {
      return;
    }

    var nextIndex = 0;
    Future<void> worker() async {
      while (true) {
        if (_pausedForActiveChat || generation != _viewportGeneration) {
          return;
        }
        final index = nextIndex++;
        if (index >= ranked.length) {
          return;
        }
        final conversation = ranked[index];
        try {
          await _warmOne(
            conversation: conversation,
            fillMemory: true,
            mode: ConversationWarmMode.viewportLocal,
            syncGeneration: _syncGeneration,
            viewportGeneration: generation,
          );
        } catch (error, stack) {
          if (kDebugMode) {
            debugPrint(
              'ConversationHistoryWarmScheduler viewport warm failed: $error\n$stack',
            );
          }
        }
        if (_pausedForActiveChat || generation != _viewportGeneration) {
          return;
        }
        if (index + 1 < ranked.length) {
          await Future<void>.delayed(viewportStagger);
        }
      }
    }

    final workers = List<Future<void>>.generate(
      viewportMaxConcurrency.clamp(1, ranked.length),
      (_) => worker(),
    );
    await Future.wait(workers);

    ChatHistoryTrace.log(
      'history_warm_viewport_done',
      extras: <String, Object?>{
        'reason': reason,
        'generation': generation,
        'selectedCount': ranked.length,
      },
    );
  }

  Future<void> _warmOne({
    required V2TimConversation conversation,
    required bool fillMemory,
    required ConversationWarmMode mode,
    required int syncGeneration,
    required int viewportGeneration,
  }) async {
    bool generationAlive() {
      if (_pausedForActiveChat) {
        return false;
      }
      switch (mode) {
        case ConversationWarmMode.syncTop:
          return syncGeneration == _syncGeneration;
        case ConversationWarmMode.viewportLocal:
          return viewportGeneration == _viewportGeneration;
        case ConversationWarmMode.press:
          return true;
      }
    }

    if (!generationAlive()) {
      return;
    }
    if (!ConversationPeekService.canPeek(conversation)) {
      return;
    }

    final cacheKey =
        ConversationPreviewHistorySync.conversationMessageCacheKey(conversation);
    if (cacheKey == null || cacheKey.isEmpty) {
      return;
    }

    if (mode == ConversationWarmMode.viewportLocal) {
      final missUntil = _viewportLocalMissUntil[cacheKey];
      if (missUntil != null && DateTime.now().isBefore(missUntil)) {
        ChatHistoryTrace.log(
          'history_warm_skip_local_miss_cooldown',
          conversationID: cacheKey,
        );
        return;
      }
    }

    if (ArchiveHistoryProvider.isInHistoryClearGrace(cacheKey) ||
        ArchiveHistoryProvider.isInHistoryClearGrace(
          conversation.conversationID,
        )) {
      ChatHistoryTrace.log(
        'history_warm_skip_clear_grace',
        conversationID: cacheKey,
      );
      return;
    }

    if (ActiveChatRegistry.instance.isActiveChat(cacheKey) ||
        ActiveChatRegistry.instance.isActiveChat(conversation.conversationID)) {
      ChatHistoryTrace.log(
        'history_warm_skip_active_chat',
        conversationID: cacheKey,
      );
      return;
    }

    if (!_warmingKeys.add(cacheKey)) {
      return;
    }
    try {
      final globalModel = serviceLocator<TUIChatGlobalModel>();
      final cached = globalModel.rawMessageList(cacheKey) ??
          globalModel.rawMessageList(conversation.conversationID);
      final preview = conversation.lastMessage;
      final countForMode = mode == ConversationWarmMode.viewportLocal
          ? viewportWarmCount
          : warmCount;
      if (ConversationPreviewHistorySync.isWarmWindowReadyForOpen(
            globalModel: globalModel,
            conversationKey: cacheKey,
            preview: preview,
          ) ||
          shouldSkipWarmFetch(
            cachedCount: cached?.length ?? 0,
            previewAhead:
                ConversationPreviewHistorySync.isPreviewAheadOfCachedHistory(
              preview: preview,
              cached: cached ?? const [],
            ),
            warmCount: countForMode,
          )) {
        ChatHistoryTrace.log(
          'history_warm_skip_already_warm',
          conversationID: cacheKey,
          extras: <String, Object?>{
            'cachedCount': cached?.length ?? 0,
            'fillMemory': fillMemory,
            'mode': mode.name,
          },
        );
        touchMemoryWarm(cacheKey);
        return;
      }

      final isGroup = conversation.type == 2 ||
          (conversation.groupID?.trim().isNotEmpty ?? false) ||
          conversation.conversationID.trim().toLowerCase().startsWith('group_');
      final userID = isGroup ? null : conversation.userID?.trim();
      final rawGroupID = conversation.groupID?.trim();
      String? sdkGroupID;
      if (isGroup) {
        if (rawGroupID != null && rawGroupID.isNotEmpty) {
          sdkGroupID = ChatIdFormat.canonicalGroupStorageId(rawGroupID);
        } else {
          sdkGroupID = ChatIdFormat.canonicalGroupStorageId(
            conversation.conversationID,
          );
        }
        if (sdkGroupID.isEmpty) {
          sdkGroupID = null;
        }
      }

      final messages = mode == ConversationWarmMode.viewportLocal
          ? await MessageHistoryPeekLoader.loadOlderLocalOnly(
              messageService: _messageService,
              count: countForMode,
              userID: userID,
              groupID: sdkGroupID,
            )
          : await MessageHistoryPeekLoader.loadOlderLocalThenCloud(
              messageService: _messageService,
              count: countForMode,
              userID: userID,
              groupID: sdkGroupID,
            );
      if (!generationAlive()) {
        return;
      }

      if (mode == ConversationWarmMode.viewportLocal && messages.isEmpty) {
        _viewportLocalMissUntil[cacheKey] =
            DateTime.now().add(viewportLocalMissCooldown);
        ChatHistoryTrace.log(
          'history_warm_viewport_local_empty',
          conversationID: cacheKey,
        );
        return;
      }

      var filtered = await ArchiveHistoryProvider.filterMessagesAfterHistoryClear(
        conversationID: cacheKey,
        messages: messages,
      );
      filtered = TUIChatGlobalModel.dedupeMessages(filtered);

      ChatHistoryTrace.log(
        'history_warm_fetched',
        conversationID: cacheKey,
        extras: <String, Object?>{
          'count': filtered.length,
          'fillMemory': fillMemory,
          'warmCount': countForMode,
          'mode': mode.name,
        },
      );
      ChatOpenPerfLog.mark(
        'history_warm_fetched',
        conversationID: cacheKey,
        extras: <String, Object?>{
          'count': filtered.length,
          'fillMemory': fillMemory,
          'mode': mode.name,
        },
      );

      if (!fillMemory || filtered.isEmpty) {
        return;
      }

      if (ActiveChatRegistry.instance.isActiveChat(cacheKey)) {
        return;
      }

      final existing = globalModel.rawMessageList(cacheKey) ??
          globalModel.messageListMap[cacheKey];
      final merged = TUIChatGlobalModel.mergePeekWindowWithLiveMemory(
        existing: existing,
        fetched: filtered,
      );
      globalModel.setMessageList(
        cacheKey,
        CallBubbleDedupe.prepareOpenHistoryMessages(merged),
        needResetNewMessageCount: false,
        replace: true,
      );
      ChatMessageHeightCache.instance.seedEstimatesForMessages(filtered);

      globalModel.markInitialHistoryLoaded(cacheKey);
      final conversationID = conversation.conversationID.trim();
      if (conversationID.isNotEmpty && conversationID != cacheKey) {
        globalModel.markInitialHistoryLoaded(conversationID);
      }
      globalModel.markInitialHistoryMayHaveOlder(
        cacheKey,
        mayHaveOlder: filtered.length >= countForMode,
      );

      touchMemoryWarm(cacheKey);
      _evictMemoryWarmIfNeeded(globalModel);
    } finally {
      _warmingKeys.remove(cacheKey);
    }
  }

  void _evictMemoryWarmIfNeeded(TUIChatGlobalModel globalModel) {
    while (_memoryLru.length > memoryWarmCap) {
      final oldest = _memoryLru.keys.isEmpty ? null : _memoryLru.keys.first;
      if (oldest == null) {
        break;
      }
      if (ActiveChatRegistry.instance.isActiveChat(oldest)) {
        // 活跃会话挪到末尾，避免死循环卡死。
        _memoryLru.remove(oldest);
        _memoryLru[oldest] = true;
        if (_memoryLru.length <= memoryWarmCap) {
          break;
        }
        // 若几乎全是活跃（极端），停止淘汰。
        final allActive = _memoryLru.keys.every(
          ActiveChatRegistry.instance.isActiveChat,
        );
        if (allActive) {
          break;
        }
        continue;
      }
      _memoryLru.remove(oldest);
      globalModel.removeMessageList(oldest);
      ChatHistoryTrace.log(
        'history_warm_lru_evict',
        conversationID: oldest,
        extras: <String, Object?>{
          'remaining': _memoryLru.length,
          'cap': memoryWarmCap,
        },
      );
    }
    reconcileStaleMessageMemory(globalModel);
  }

  /// 保留 active + LRU 内最近 [memoryWarmCap]；淘汰 map 中其余孤儿窗。
  void reconcileStaleMessageMemory(TUIChatGlobalModel globalModel) {
    if (!staleReconcileEnabled) {
      return;
    }
    final keep = <String>{};
    final lruNewestFirst = _memoryLru.keys.toList(growable: false).reversed;
    var keptLru = 0;
    for (final key in lruNewestFirst) {
      if (keptLru >= memoryWarmCap) {
        break;
      }
      keep.add(key);
      keptLru++;
    }
    final mapKeys =
        globalModel.messageListMap.keys.toList(growable: false);
    for (final key in mapKeys) {
      if (ActiveChatRegistry.instance.isActiveChat(key)) {
        keep.add(key);
      }
    }

    var removed = 0;
    for (final key in mapKeys) {
      if (_isKeyKept(key, keep)) {
        continue;
      }
      if (!globalModel.messageListMap.containsKey(key)) {
        continue;
      }
      globalModel.removeMessageList(key);
      _removeLruAliases(key);
      removed++;
    }
    ChatHistoryTrace.log(
      'history_warm_stale_reconcile',
      extras: <String, Object?>{
        'kept': keep.length,
        'removed': removed,
        'mapSizeAfter': globalModel.messageListMap.length,
        'lruSize': _memoryLru.length,
      },
    );
  }

  /// dispose 离聊后 grace 到期再释放；重新 enter 则跳过。
  void scheduleReleaseAfterChatLeave(String conversationID) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    _leaveReleaseTimers.remove(id)?.cancel();
    _leaveReleaseTimers[id] = Timer(leaveChatMemoryGrace, () {
      _leaveReleaseTimers.remove(id);
      if (ActiveChatRegistry.instance.isActiveChat(id)) {
        ChatHistoryTrace.log(
          'history_warm_leave_release',
          conversationID: id,
          extras: <String, Object?>{'released': false, 'skipped_active': true},
        );
        return;
      }
      TUIChatGlobalModel? globalModel;
      try {
        globalModel = serviceLocator<TUIChatGlobalModel>();
      } catch (_) {
        return;
      }
      globalModel.removeMessageList(id);
      _removeLruAliases(id);
      ChatHistoryTrace.log(
        'history_warm_leave_release',
        conversationID: id,
        extras: <String, Object?>{'released': true, 'skipped_active': false},
      );
      reconcileStaleMessageMemory(globalModel);
    });
  }

  bool _isKeyKept(String mapKey, Set<String> keep) {
    if (keep.contains(mapKey)) {
      return true;
    }
    for (final kept in keep) {
      if (MessageConversationId.sameConversation(mapKey, kept)) {
        return true;
      }
    }
    return false;
  }

  void _removeLruAliases(String conversationID) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    final toRemove = _memoryLru.keys
        .where((key) => MessageConversationId.sameConversation(key, id))
        .toList(growable: false);
    for (final key in toRemove) {
      _memoryLru.remove(key);
    }
  }

  /// 从 feed 行（null=非会话行）按滚动偏移选取可见会话。
  @visibleForTesting
  static List<V2TimConversation> selectViewportCandidates({
    required List<V2TimConversation?> rowConversations,
    required double scrollOffset,
    required double viewportHeight,
    double rowExtent = estimatedRowExtent,
    int pad = viewportPad,
    int hardCap = viewportHardCap,
  }) {
    if (rowConversations.isEmpty || viewportHeight <= 0 || rowExtent <= 0) {
      return const <V2TimConversation>[];
    }
    final maxIndex = rowConversations.length - 1;
    final rawFirst = (scrollOffset / rowExtent).floor() - pad;
    final rawLast =
        ((scrollOffset + viewportHeight) / rowExtent).ceil() + pad;
    final first = rawFirst.clamp(0, maxIndex);
    final last = rawLast.clamp(0, maxIndex);
    final out = <V2TimConversation>[];
    final seen = <String>{};
    for (var i = first; i <= last; i++) {
      final conversation = rowConversations[i];
      if (conversation == null) {
        continue;
      }
      final id = conversation.conversationID.trim();
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      out.add(conversation);
      if (out.length >= hardCap) {
        break;
      }
    }
    return out;
  }

  @visibleForTesting
  static List<V2TimConversation> selectWarmCandidates({
    required List<V2TimConversation> conversations,
    required Set<String> archivedIDs,
    required String loginUserId,
    required bool Function(V2TimConversation) shouldShowConversation,
    int sdkLimit = sdkWarmLimit,
  }) {
    final filtered = <V2TimConversation>[];
    for (final conversation in conversations) {
      if (!_isVisibleWarmCandidate(
        conversation,
        archivedIDs: archivedIDs,
        loginUserId: loginUserId,
        shouldShowConversation: shouldShowConversation,
      )) {
        continue;
      }
      if (!ConversationPeekService.canPeek(conversation)) {
        continue;
      }
      filtered.add(conversation);
    }

    final unreadGroups = <V2TimConversation>[];
    final unreadC2c = <V2TimConversation>[];
    final restGroups = <V2TimConversation>[];
    final restC2c = <V2TimConversation>[];
    for (final conversation in filtered) {
      final isGroup = conversation.type == 2 ||
          (conversation.groupID?.trim().isNotEmpty ?? false) ||
          conversation.conversationID.trim().toLowerCase().startsWith('group_');
      final unread = (conversation.unreadCount ?? 0) > 0;
      if (unread) {
        if (isGroup) {
          unreadGroups.add(conversation);
        } else {
          unreadC2c.add(conversation);
        }
      } else if (isGroup) {
        restGroups.add(conversation);
      } else {
        restC2c.add(conversation);
      }
    }
    final ranked = <V2TimConversation>[
      ...unreadGroups,
      ...unreadC2c,
      ...restGroups,
      ...restC2c,
    ];
    if (ranked.length <= sdkLimit) {
      return ranked;
    }
    return ranked.sublist(0, sdkLimit);
  }

  static bool _isVisibleWarmCandidate(
    V2TimConversation conversation, {
    required Set<String> archivedIDs,
    required String loginUserId,
    required bool Function(V2TimConversation) shouldShowConversation,
  }) {
    if ((conversation.userID ?? '').trim() == '10000') {
      return false;
    }
    if (MessageConversationId.isSelfC2CConversation(
      conversation.conversationID,
      loginUserId,
    )) {
      return false;
    }
    if (PlatformOfficialAccountService.shouldHideConversation(conversation)) {
      return false;
    }
    if (_isArchived(conversation.conversationID, archivedIDs)) {
      return false;
    }
    if (!shouldShowConversation(conversation)) {
      return false;
    }
    return true;
  }

  static bool _isArchived(String conversationID, Set<String> archivedIDs) {
    final id = conversationID.trim();
    if (id.isEmpty || archivedIDs.isEmpty) {
      return false;
    }
    if (archivedIDs.contains(id)) {
      return true;
    }
    for (final archivedId in archivedIDs) {
      if (MessageConversationId.sameConversation(archivedId, id)) {
        return true;
      }
    }
    return false;
  }

  @visibleForTesting
  static bool shouldSkipWarmFetch({
    required int cachedCount,
    required bool previewAhead,
    required int warmCount,
  }) {
    if (cachedCount < warmCount) {
      return false;
    }
    return !previewAhead;
  }

  @visibleForTesting
  LinkedHashMap<String, bool> get memoryLruForTest => _memoryLru;

  @visibleForTesting
  void evictMemoryWarmForTest(TUIChatGlobalModel globalModel) {
    _evictMemoryWarmIfNeeded(globalModel);
  }
}
