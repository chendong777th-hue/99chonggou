import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/android_performance_profile.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_open_perf_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_peek_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_bubble_dedupe.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_history_peer.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_coverage.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_batch.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_history_peek_loader.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_height_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

/// 预热模式：sync Top / 视口 LOCAL / 按下可打云。
enum ConversationWarmMode { syncTop, viewportLocal, press }

/// 重连后预热 + 视口停稳 LOCAL 预热 + 按下预热；内存暖窗 LRU 限容。
///
/// 视口通道不走归档 HTTP、不打 CLOUD；页内上拉分页仍用现有 loadChatRecord。
class ConversationHistoryWarmScheduler {
  ConversationHistoryWarmScheduler._();

  static final ConversationHistoryWarmScheduler instance =
      ConversationHistoryWarmScheduler._();

  /// 总开关：关则视口/按下不调度（sync Top 仍可用）。
  static bool viewportWarmEnabled = true;

  static const int sdkWarmLimit = 8;
  static const int memoryWarmLimit = 8;
  static const int memoryWarmCap = 24;
  static const int syncTopWarmCount =
      ConversationPerfFlags.historyWarmSyncTopFetchCount;
  static const int warmCount = HistoryMessageDartConstant.initialOpenFetchCount;
  static int get viewportWarmCount =>
      AndroidPerformanceProfile.instance.conversationViewportWarmCount;
  static const int viewportHardCap = 16;
  static const int viewportPad = 2;
  static const double estimatedRowExtent = 72;
  static int get maxConcurrency =>
      AndroidPerformanceProfile.instance.conversationWarmConcurrency;
  static int get viewportMaxConcurrency =>
      AndroidPerformanceProfile.instance.conversationWarmConcurrency;

  static bool get viewportWarmAllowed =>
      viewportWarmEnabled && viewportWarmCount > 0;

  /// 当前已打开的会话禁止再往内存灌窗（含进页转场 routeVisible=false）。
  /// 只按 conversationId 匹配，不因 hasOpenChat 跳过其它会话的预热。
  @visibleForTesting
  static bool shouldSkipMemoryFillForOpenChat({
    required String cacheKey,
    String? conversationID,
  }) {
    final registry = ActiveChatRegistry.instance;
    if (registry.matchesOpenConversation(cacheKey)) {
      return true;
    }
    final id = conversationID?.trim() ?? '';
    return id.isNotEmpty && registry.matchesOpenConversation(id);
  }

  static const Duration stagger = Duration(milliseconds: 200);
  static const Duration viewportStagger = Duration(milliseconds: 120);
  static const Duration globalCooldown = Duration(seconds: 60);
  static const Duration viewportLocalMissCooldown = Duration(seconds: 30);

  /// `_viewportLocalMissUntil` 硬顶，防长滑/长聊无限涨。
  static const int viewportLocalMissCap = 256;

  /// dispose 离聊后延迟释放该会话消息窗。
  static const Duration leaveChatMemoryGrace = Duration(seconds: 15);

  /// 孤儿 / 超容 messageListMap 对账淘汰总开关。
  static bool staleReconcileEnabled = true;

  static MessageHistoryBounds _historyBounds(
    Iterable<V2TimMessage> messages,
  ) {
    V2TimMessage? oldest;
    V2TimMessage? newest;
    for (final message in messages) {
      if ((message.msgID?.trim() ?? '').isEmpty) continue;
      if (oldest == null ||
          TUIChatGlobalModel.compareMessagesChronological(message, oldest) <
              0) {
        oldest = message;
      }
      if (newest == null ||
          TUIChatGlobalModel.compareMessagesChronological(message, newest) >
              0) {
        newest = message;
      }
    }
    return MessageHistoryBounds(
      oldestMsgID: oldest?.msgID,
      newestMsgID: newest?.msgID,
      oldestSeq: int.tryParse(oldest?.seq?.trim() ?? ''),
      newestSeq: int.tryParse(newest?.seq?.trim() ?? ''),
    );
  }

  MessageService get _messageService => serviceLocator<MessageService>();

  DateTime? _lastSyncScheduleAt;
  int _syncGeneration = 0;
  int _viewportGeneration = 0;
  Future<void>? _syncInFlight;
  Future<void>? _viewportInFlight;
  final Set<String> _warmingKeys = <String>{};
  final Map<String, Future<void>> _warmFutures = <String, Future<void>>{};
  bool _pausedForActiveChat = false;
  bool _pausedForFeedScroll = false;
  bool _pausedForMembershipSync = false;
  String? _pauseReason;
  bool _warmPassAbortedByPause = false;
  DateTime? _launchSuppressUntil;
  DateTime? _postLeaveSuppressUntil;
  int _cachedGroupCountForWarm = 0;
  DateTime? _cachedGroupCountAt;

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
    _warmFutures.clear();
    _pausedForActiveChat = false;
    _pausedForFeedScroll = false;
    _pausedForMembershipSync = false;
    _pauseReason = null;
    _warmPassAbortedByPause = false;
    _launchSuppressUntil = null;
    _postLeaveSuppressUntil = null;
    _cachedGroupCountForWarm = 0;
    _cachedGroupCountAt = null;
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

  bool get isPausedForFeedScroll => _pausedForFeedScroll;

  bool get isPausedForMembershipSync => _pausedForMembershipSync;

  bool get _isWarmPaused =>
      _pausedForActiveChat || _pausedForFeedScroll || _pausedForMembershipSync;

  /// 启动后一段时间内禁止 viewport warm（见 [ConversationPerfFlags.historyWarmSuppressAfterLaunch]）。
  void armLaunchWarmSuppress({Duration? duration}) {
    final d = duration ?? ConversationPerfFlags.historyWarmSuppressAfterLaunch;
    if (d <= Duration.zero) {
      _launchSuppressUntil = null;
      return;
    }
    _launchSuppressUntil = DateTime.now().add(d);
    ChatHistoryTrace.log(
      'history_warm_launch_suppress_armed',
      extras: <String, Object?>{'durationMs': d.inMilliseconds},
    );
  }

  /// 离开聊天后抑制 incomplete / viewport warm（见 [ConversationPerfFlags.postChatLeaveWarmSuppress]）。
  void armPostLeaveWarmSuppress({Duration? duration}) {
    final d = duration ?? ConversationPerfFlags.postChatLeaveWarmSuppress;
    if (d <= Duration.zero) {
      _postLeaveSuppressUntil = null;
      return;
    }
    _postLeaveSuppressUntil = DateTime.now().add(d);
    ConversationPerfGateLog.log(
      'history_warm_post_leave_suppress',
      extras: <String, Object?>{'durationMs': d.inMilliseconds},
    );
    ChatHistoryTrace.log(
      'history_warm_post_leave_suppress',
      extras: <String, Object?>{'durationMs': d.inMilliseconds},
    );
  }

  bool get _isPostLeaveWarmSuppressed {
    final until = _postLeaveSuppressUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// 群 membership syncFull 期间暂停 warm（与 feed scroll / active chat 可叠加）。
  void setPausedForMembershipSync(
    bool paused, {
    String reason = 'membership_sync',
  }) {
    if (paused) {
      if (_pausedForMembershipSync) {
        cancelViewportWarm(reason: reason);
        return;
      }
      _pausedForMembershipSync = true;
      if (_syncInFlight != null ||
          _viewportInFlight != null ||
          _warmingKeys.isNotEmpty) {
        _warmPassAbortedByPause = true;
      }
      _syncGeneration++;
      cancelViewportWarm(reason: reason);
      ChatHistoryTrace.log(
        'history_warm_membership_pause',
        extras: <String, Object?>{
          'reason': reason,
          'willContinue': _warmPassAbortedByPause,
        },
      );
      return;
    }
    if (!_pausedForMembershipSync) {
      return;
    }
    _pausedForMembershipSync = false;
    ChatHistoryTrace.log(
      'history_warm_membership_resume',
      extras: <String, Object?>{
        'reason': reason,
        'willContinue': _warmPassAbortedByPause &&
            !_pausedForActiveChat &&
            !_pausedForFeedScroll,
      },
    );
    if (_pausedForActiveChat || _pausedForFeedScroll) {
      return;
    }
    if (_warmPassAbortedByPause) {
      _warmPassAbortedByPause = false;
      // 不自动续跑：启动 suppress / 大账号策略下避免 syncFull 结束后立刻风暴。
    }
  }

  Future<bool> _isViewportWarmBlockedByPolicy() async {
    final until = _launchSuppressUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      ChatHistoryTrace.log(
        'history_warm_viewport_skip_launch_suppress',
        extras: <String, Object?>{
          'remainMs': until.difference(DateTime.now()).inMilliseconds,
        },
      );
      return true;
    }
    if (_isPostLeaveWarmSuppressed) {
      final postUntil = _postLeaveSuppressUntil;
      ChatHistoryTrace.log(
        'history_warm_viewport_skip_post_leave_suppress',
        extras: <String, Object?>{
          'remainMs': postUntil == null
              ? 0
              : postUntil.difference(DateTime.now()).inMilliseconds,
        },
      );
      return true;
    }
    if (!ConversationPerfFlags.historyWarmLargeAccountPressOnly) {
      return false;
    }
    final count = await _resolveGroupCountForWarmPolicy();
    if (count >= GroupLocalPerfFlags.largeAccountGroupThreshold) {
      ChatHistoryTrace.log(
        'history_warm_viewport_skip_large_account',
        extras: <String, Object?>{
          'groupCount': count,
          'threshold': GroupLocalPerfFlags.largeAccountGroupThreshold,
        },
      );
      return true;
    }
    return false;
  }

  Future<int> _resolveGroupCountForWarmPolicy() async {
    final cachedAt = _cachedGroupCountAt;
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(seconds: 30)) {
      return _cachedGroupCountForWarm;
    }
    try {
      final n = await GroupLocalStore.instance.countGroups();
      _cachedGroupCountForWarm = n;
      _cachedGroupCountAt = DateTime.now();
      return n;
    } catch (_) {
      return _cachedGroupCountForWarm;
    }
  }

  /// 会话列表手势滚动：暂停 sync/viewport warm，停稳后再续。
  /// 与 [pauseForActiveChat] 独立，可叠加；仍在聊天页内时不会误恢复。
  void setFeedScrolling(bool scrolling, {String reason = 'feed_scroll'}) {
    if (scrolling) {
      if (_pausedForFeedScroll) {
        cancelViewportWarm(reason: reason);
        return;
      }
      _pausedForFeedScroll = true;
      if (_syncInFlight != null ||
          _viewportInFlight != null ||
          _warmingKeys.isNotEmpty) {
        _warmPassAbortedByPause = true;
      }
      _syncGeneration++;
      cancelViewportWarm(reason: reason);
      ChatHistoryTrace.log(
        'history_warm_feed_scroll_pause',
        extras: <String, Object?>{
          'reason': reason,
          'willContinue': _warmPassAbortedByPause,
          'activeChatPaused': _pausedForActiveChat,
        },
      );
      return;
    }
    if (!_pausedForFeedScroll) {
      return;
    }
    _pausedForFeedScroll = false;
    ChatHistoryTrace.log(
      'history_warm_feed_scroll_resume',
      extras: <String, Object?>{
        'reason': reason,
        'activeChatPaused': _pausedForActiveChat,
        'willContinue': _warmPassAbortedByPause && !_pausedForActiveChat,
      },
    );
    if (_pausedForActiveChat || _pausedForMembershipSync) {
      return;
    }
    if (_warmPassAbortedByPause) {
      _warmPassAbortedByPause = false;
      _lastSyncScheduleAt = null;
      scheduleAfterConversationSync(reason: 'resume_after_feed_scroll');
    }
  }

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

  void resumeAfterActiveChat({
    String reason = 'chat_leave',
    bool deferIncompleteWarm = false,
  }) {
    if (!_pausedForActiveChat) {
      return;
    }
    _pausedForActiveChat = false;
    final pausedFor = _pauseReason;
    _pauseReason = null;
    final shouldContinue = _warmPassAbortedByPause;
    _warmPassAbortedByPause = false;
    final defer = deferIncompleteWarm ||
        ConversationPerfFlags.historyWarmDeferResumeAfterChatLeave;
    ChatHistoryTrace.log(
      'history_warm_resumed',
      extras: <String, Object?>{
        'reason': reason,
        'pausedFor': pausedFor ?? '',
        'continueWarm': shouldContinue,
        'deferIncomplete': defer,
      },
    );
    if (defer) {
      armPostLeaveWarmSuppress();
      // 不立刻续 incomplete；保留 aborted 语义到 suppress 结束后由停滑 / 下次 sync 触发。
      if (shouldContinue) {
        _warmPassAbortedByPause = true;
      }
    } else if (shouldContinue) {
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
    if (_isWarmPaused) {
      ChatHistoryTrace.log(
        'history_warm_skip_paused',
        extras: <String, Object?>{
          'reason': reason,
          'pausedFor':
              _pausedForFeedScroll ? 'feed_scroll' : (_pauseReason ?? ''),
        },
      );
      return _syncInFlight ?? Future<void>.value();
    }
    if (_isPostLeaveWarmSuppressed &&
        (reason == 'resume_incomplete_warm' || reason.startsWith('resume_'))) {
      ChatHistoryTrace.log(
        'history_warm_skip_post_leave_suppress',
        extras: <String, Object?>{'reason': reason},
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
    if (!viewportWarmAllowed) {
      return;
    }
    unawaited(runViewportWarm(visibleOrdered: visibleOrdered, reason: reason));
  }

  Future<void> runViewportWarm({
    required List<V2TimConversation> visibleOrdered,
    required String reason,
  }) async {
    if (!viewportWarmAllowed) {
      return;
    }
    if (await _isViewportWarmBlockedByPolicy()) {
      return;
    }
    if (_isWarmPaused) {
      ChatHistoryTrace.log(
        'history_warm_viewport_skip_paused',
        extras: <String, Object?>{
          'reason': reason,
          'pausedFor': _pausedForFeedScroll
              ? 'feed_scroll'
              : (_pausedForMembershipSync
                  ? 'membership_sync'
                  : (_pauseReason ?? '')),
        },
      );
      return;
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
    await _viewportInFlight;
  }

  /// 用户明确按下/点击的目标会话：只跑这一条 LOCAL-only warm。
  ///
  /// 给群聊列表使用，复用 viewport generation，因此滚动开始、进聊暂停、
  /// membership sync 暂停都会让这次任务失效。
  void scheduleTargetLocalWarm(
    V2TimConversation conversation, {
    required String reason,
  }) {
    if (!viewportWarmAllowed) {
      return;
    }
    unawaited(runTargetLocalWarm(conversation, reason: reason));
  }

  Future<void> runTargetLocalWarm(
    V2TimConversation conversation, {
    required String reason,
  }) async {
    if (!viewportWarmAllowed) {
      return;
    }
    if (await _isViewportWarmBlockedByPolicy()) {
      return;
    }
    if (_isWarmPaused) {
      ChatHistoryTrace.log(
        'history_warm_target_local_skip_paused',
        conversationID: conversation.conversationID,
        extras: <String, Object?>{
          'reason': reason,
          'pausedFor': _pausedForFeedScroll
              ? 'feed_scroll'
              : (_pausedForMembershipSync
                  ? 'membership_sync'
                  : (_pauseReason ?? '')),
        },
      );
      return;
    }

    final generation = ++_viewportGeneration;
    final task = (() async {
      ChatHistoryTrace.log(
        'history_warm_target_local_start',
        conversationID: conversation.conversationID,
        extras: <String, Object?>{
          'reason': reason,
          'generation': generation,
          'warmCount': viewportWarmCount,
        },
      );
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
            'ConversationHistoryWarmScheduler target local warm failed: '
            '$error\n$stack',
          );
        }
      } finally {
        ChatHistoryTrace.log(
          'history_warm_target_local_done',
          conversationID: conversation.conversationID,
          extras: <String, Object?>{
            'reason': reason,
            'generation': generation,
          },
        );
      }
    })();
    _viewportInFlight = task.whenComplete(() {
      if (identical(_viewportInFlight, task)) {
        _viewportInFlight = null;
      }
    });
    await _viewportInFlight;
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
        debugPrint(
          'ConversationHistoryWarmScheduler press warm failed: $error\n$stack',
        );
      }
    }
  }

  /// 进页前尽量灌满完整首屏暖窗，便于 `history_gate_content_ready_skip`。
  ///
  /// 有硬超时：不阻塞点击太久；超时后仍 push，由页内 hydrate 兜底。
  /// 与普通 press 不同：已 warm 但未满窗时仍会补拉到 [warmCount]。
  Future<bool> ensureCompleteOpenWindow({
    required V2TimConversation conversation,
    Duration timeout = const Duration(milliseconds: 220),
  }) async {
    final cacheKey = ConversationPreviewHistorySync.conversationMessageCacheKey(
      conversation,
    );
    if (cacheKey == null || cacheKey.isEmpty) {
      return false;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    if (ConversationPreviewHistorySync.isCompleteOpenHistoryWindow(
      globalModel: globalModel,
      conversationKey: cacheKey,
    )) {
      touchMemoryWarm(cacheKey);
      return true;
    }
    try {
      await Future<void>(() async {
        if (!viewportWarmEnabled) {
          return;
        }
        _viewportGeneration++;
        await _warmOne(
          conversation: conversation,
          fillMemory: true,
          mode: ConversationWarmMode.press,
          syncGeneration: _syncGeneration,
          viewportGeneration: _viewportGeneration,
          requireCompleteWindow: true,
        );
      }).timeout(timeout);
    } on TimeoutException {
      ChatOpenPerfLog.mark(
        'open_prewarm_timeout',
        conversationID: cacheKey,
        extras: <String, Object?>{
          'timeoutMs': timeout.inMilliseconds,
          'rawCount': globalModel.rawMessageCount(cacheKey),
        },
      );
    } catch (_) {}
    final complete = ConversationPreviewHistorySync.isCompleteOpenHistoryWindow(
      globalModel: globalModel,
      conversationKey: cacheKey,
    );
    if (complete) {
      touchMemoryWarm(cacheKey);
    }
    return complete;
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
        if (_isWarmPaused || generation != _syncGeneration) {
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
        if (_isWarmPaused || generation != _syncGeneration) {
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
        if (_isWarmPaused || generation != _viewportGeneration) {
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
        if (_isWarmPaused || generation != _viewportGeneration) {
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
    bool requireCompleteWindow = false,
  }) async {
    bool generationAlive() {
      if (_isWarmPaused) {
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

    final cacheKey = ConversationPreviewHistorySync.conversationMessageCacheKey(
      conversation,
    );
    if (cacheKey == null || cacheKey.isEmpty) {
      return;
    }

    if (mode == ConversationWarmMode.viewportLocal) {
      _pruneViewportLocalMissMap();
      final missUntil = _viewportLocalMissUntil[cacheKey];
      if (missUntil != null) {
        if (DateTime.now().isBefore(missUntil)) {
          ChatHistoryTrace.log(
            'history_warm_skip_local_miss_cooldown',
            conversationID: cacheKey,
          );
          return;
        }
        _viewportLocalMissUntil.remove(cacheKey);
      }
    }

    // Chat 打开期间：禁止非当前会话预热（pause 漏网的 schedule 入口兜底）。
    if (_pausedForActiveChat) {
      final activeId = ActiveChatRegistry.instance.activeConversationId;
      final isCurrent = activeId != null &&
          (MessageConversationId.sameConversation(activeId, cacheKey) ||
              MessageConversationId.sameConversation(
                activeId,
                conversation.conversationID,
              ));
      if (!isCurrent) {
        ChatHistoryTrace.log(
          'history_warm_skip_non_active_while_chat',
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

    if (shouldSkipMemoryFillForOpenChat(
      cacheKey: cacheKey,
      conversationID: conversation.conversationID,
    )) {
      ChatHistoryTrace.log(
        'history_warm_skip_active_chat',
        conversationID: cacheKey,
      );
      return;
    }

    while (!_warmingKeys.add(cacheKey)) {
      final pending = _warmFutures[cacheKey];
      if (pending != null) {
        await pending;
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
      if (!generationAlive()) {
        return;
      }
      if (requireCompleteWindow) {
        final global = serviceLocator<TUIChatGlobalModel>();
        if (ConversationPreviewHistorySync.isCompleteOpenHistoryWindow(
          globalModel: global,
          conversationKey: cacheKey,
        )) {
          touchMemoryWarm(cacheKey);
          return;
        }
        // 上一轮 press 可能只灌了薄窗；进页 ensure 继续抢锁补满。
        continue;
      }
      return;
    }
    final warmDone = Completer<void>();
    _warmFutures[cacheKey] = warmDone.future;
    try {
      final globalModel = serviceLocator<TUIChatGlobalModel>();
      final cached = globalModel.rawMessageList(cacheKey) ??
          globalModel.rawMessageList(conversation.conversationID);
      final preview = conversation.lastMessage;
      final countForMode = switch (mode) {
        ConversationWarmMode.syncTop => syncTopWarmCount,
        ConversationWarmMode.viewportLocal => viewportWarmCount,
        ConversationWarmMode.press => warmCount,
      };
      final alreadyComplete =
          ConversationPreviewHistorySync.isCompleteOpenHistoryWindow(
        globalModel: globalModel,
        conversationKey: cacheKey,
      );
      final alreadyWarmReady =
          ConversationPreviewHistorySync.isWarmWindowReadyForOpen(
        globalModel: globalModel,
        conversationKey: cacheKey,
        preview: preview,
      );
      final skipByCount = shouldSkipWarmFetch(
        cachedCount: cached?.length ?? 0,
        previewAhead:
            ConversationPreviewHistorySync.isPreviewAheadOfCachedHistory(
          preview: preview,
          cached: cached ?? const [],
        ),
        warmCount: countForMode,
      );
      // 进页 ensure：只在完整首屏已就绪时跳过；薄 LOCAL 暖窗必须补到 warmCount。
      final shouldSkip = requireCompleteWindow
          ? alreadyComplete
          : (alreadyWarmReady || skipByCount);
      if (shouldSkip) {
        ChatHistoryTrace.log(
          'history_warm_skip_already_warm',
          conversationID: cacheKey,
          extras: <String, Object?>{
            'cachedCount': cached?.length ?? 0,
            'fillMemory': fillMemory,
            'mode': mode.name,
            'requireCompleteWindow': requireCompleteWindow,
            'alreadyComplete': alreadyComplete,
          },
        );
        touchMemoryWarm(cacheKey);
        return;
      }

      final peer = ConversationHistoryPeer.resolve(conversation);
      if (peer == null || !peer.canFetch) {
        ChatHistoryTrace.log(
          'history_warm_skip_unresolved_peer',
          conversationID: cacheKey,
          extras: <String, Object?>{
            'type': conversation.type,
            'userID': conversation.userID,
            'groupID': conversation.groupID,
          },
        );
        return;
      }
      final userID = peer.isGroup ? null : peer.userID;
      final sdkGroupID = peer.isGroup ? peer.groupID : null;
      final officialAccount =
          (conversation.userID ?? '').trim().startsWith('@TOA#_');
      final isOfficialWarm = (peer.isGroup ||
              ((conversation.groupID?.trim().isEmpty ?? true) &&
                  ((conversation.userID?.trim().isNotEmpty ?? false) ||
                      conversation.type == 1))) &&
          !officialAccount;

      final localOnly = mode == ConversationWarmMode.viewportLocal ||
          (mode == ConversationWarmMode.syncTop &&
              !ConversationPerfFlags.historyWarmSyncTopCloudEnabled);
      // `localThenCloud` returns a merged SDK window without exposing which
      // rows came from the cloud. Treat only explicit local-only/cloud-only
      // modes as provenance claims; mixed warm data remains provisional.
      final requestedSource = localOnly || !isOfficialWarm
          ? MessageReconciliationSource.local
          : MessageReconciliationSource.cloud;
      final networkBefore = globalModel.messageReconciliationNetworkState;
      final reconciliationRequest = globalModel.beginHistoryReconciliation(
        conversationID: cacheKey,
        requestedSource: requestedSource,
        networkState: networkBefore,
      );
      final historyResult = localOnly
          ? await MessageHistoryPeekLoader.loadOlderLocalOnlyResult(
              messageService: _messageService,
              count: countForMode,
              userID: userID,
              groupID: sdkGroupID,
            )
          : isOfficialWarm
              ? await MessageHistoryPeekLoader.loadOlderCloudOnlyResult(
                  messageService: _messageService,
                  count: countForMode,
                  userID: userID,
                  groupID: sdkGroupID,
                )
              : await MessageHistoryPeekLoader.loadOlderLocalThenCloudResult(
                  messageService: _messageService,
                  count: countForMode,
                  userID: userID,
                  groupID: sdkGroupID,
                );
      final messages = historyResult.messageList;
      if (!generationAlive()) {
        globalModel.failHistoryReconciliation(
          request: reconciliationRequest,
          reason: 'history_warm_generation_stale',
        );
        return;
      }

      if (mode == ConversationWarmMode.viewportLocal && messages.isEmpty) {
        globalModel.failHistoryReconciliation(
          request: reconciliationRequest,
          reason: 'history_warm_local_empty',
        );
        _rememberViewportLocalMiss(cacheKey);
        ChatHistoryTrace.log(
          'history_warm_viewport_local_empty',
          conversationID: cacheKey,
        );
        return;
      }

      var filtered =
          await ArchiveHistoryProvider.filterMessagesAfterHistoryClear(
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
          'localOnly': localOnly,
          'isFinished': historyResult.isFinished,
        },
      );
      ChatOpenPerfLog.mark(
        'history_warm_fetched',
        conversationID: cacheKey,
        extras: <String, Object?>{
          'count': filtered.length,
          'fillMemory': fillMemory,
          'mode': mode.name,
          'localOnly': localOnly,
        },
      );

      if (!fillMemory || filtered.isEmpty) {
        globalModel.failHistoryReconciliation(
          request: reconciliationRequest,
          reason: filtered.isEmpty
              ? 'history_warm_empty'
              : 'history_warm_memory_fill_disabled',
        );
        return;
      }

      if (shouldSkipMemoryFillForOpenChat(
        cacheKey: cacheKey,
        conversationID: conversation.conversationID,
      )) {
        globalModel.failHistoryReconciliation(
          request: reconciliationRequest,
          reason: 'history_warm_open_chat_owned_by_page',
        );
        return;
      }

      final existing = globalModel.mergedAliasMessageList(cacheKey);
      if (isOfficialWarm &&
          HistoryPaginationAnchor.shouldRejectC2cPeekRestamp(
            existingCount: existing.length,
            incomingCount: filtered.length,
          )) {
        globalModel.failHistoryReconciliation(
          request: reconciliationRequest,
          reason: 'history_warm_c2c_restamp_rejected',
        );
        ChatHistoryTrace.log(
          'history_warm_skip_c2c_peek_restamp',
          conversationID: cacheKey,
          extras: <String, Object?>{
            'existingCount': existing.length,
            'fetchedCount': filtered.length,
          },
        );
        return;
      }
      // 视口 LOCAL 只有几条最新消息。peek-window merge 会丢掉更早的内存历史，
      // 进页就会先画出贴底的几条、上半空白，再被 hydrate 补回来。
      final merged = isOfficialWarm
          ? TUIChatGlobalModel.mergeC2cOfficialOlderPage(
              existing: existing,
              fetched: filtered,
            )
          : mode == ConversationWarmMode.viewportLocal
              ? TUIChatGlobalModel.mergeHistoricalWithInMemory(
                  existing: existing,
                  fetched: filtered,
                )
              : TUIChatGlobalModel.mergePeekWindowWithLiveMemory(
                  existing: existing,
                  fetched: filtered,
                );
      final networkAfter = globalModel.messageReconciliationNetworkState;
      final provenance = MessageReconciliationProvenance.resolve(
        requestedSource: requestedSource,
        beforeRequest: networkBefore,
        afterResponse: networkAfter,
      );
      final clearEpoch =
          await ArchiveHistoryProvider.historyClearedAtMs(cacheKey);
      final batchKind = localOnly || !isOfficialWarm
          ? MessageHistoryBatchKind.localSnapshot
          : MessageHistoryBatchKind.latestWindow;
      final batch = MessageHistoryBatch<V2TimMessage>(
        conversationKey: cacheKey,
        requestedSource: requestedSource,
        actualSource: provenance.actualSource,
        batchKind: batchKind,
        requestGeneration: reconciliationRequest.generation,
        clearEpoch: clearEpoch,
        isFinished: historyResult.isFinished,
        hasMoreOlder: !historyResult.isFinished,
        cloudHasMoreNewer: false,
        cloudResponseProven: provenance.cloudResponseProven,
        requestedCursor: const MessageHistoryCursor(
          direction: MessageHistoryCursorDirection.latest,
        ),
        returnedBounds: _historyBounds(merged),
        messages: isOfficialWarm
            ? TUIChatGlobalModel.dedupeMessages(merged)
            : CallBubbleDedupe.prepareOpenHistoryMessages(merged),
      );
      final commit = globalModel.completeHistoryBatch(
        request: reconciliationRequest,
        batch: batch,
        networkState: provenance.networkState,
        clearEpoch: clearEpoch,
        historyCommitSource: 'history_warm',
      );
      if (commit == null) {
        return;
      }
      ChatMessageHeightCache.instance.seedEstimatesForMessages(filtered);

      if (mode == ConversationWarmMode.viewportLocal) {
        // LOCAL-only is a provisional window unless we already had a full
        // validated first screen. Tiny peeks must not invalidate that.
        final wasLoaded = globalModel.hasInitialHistoryLoaded(cacheKey);
        final complete =
            merged.length >= HistoryMessageDartConstant.initialOpenFetchCount;
        if (!(wasLoaded && complete)) {
          globalModel.clearInitialHistoryLoaded(cacheKey);
          globalModel.markInitialHistoryMayHaveOlder(
            cacheKey,
            mayHaveOlder: true,
          );
        }
      } else {
        if (provenance.proofKind == MessageHistoryProofKind.serverContinuity) {
          globalModel.markCloudInitialHistoryVerified(cacheKey);
        } else {
          globalModel.markLocalInitialHistoryVisible(cacheKey);
        }
        final conversationID = conversation.conversationID.trim();
        if (conversationID.isNotEmpty && conversationID != cacheKey) {
          if (provenance.proofKind == MessageHistoryProofKind.serverContinuity) {
            globalModel.markCloudInitialHistoryVerified(conversationID);
          } else {
            globalModel.markLocalInitialHistoryVisible(conversationID);
          }
        }
        globalModel.markInitialHistoryMayHaveOlder(
          cacheKey,
          mayHaveOlder: !historyResult.isFinished,
        );
      }

      touchMemoryWarm(cacheKey);
      _evictMemoryWarmIfNeeded(globalModel);
    } finally {
      _warmingKeys.remove(cacheKey);
      if (!warmDone.isCompleted) {
        warmDone.complete();
      }
      _warmFutures.remove(cacheKey);
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
    final mapKeys = globalModel.messageListMap.keys.toList(growable: false);
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

  void _rememberViewportLocalMiss(String cacheKey) {
    _pruneViewportLocalMissMap();
    _viewportLocalMissUntil[cacheKey] = DateTime.now().add(
      viewportLocalMissCooldown,
    );
    while (_viewportLocalMissUntil.length > viewportLocalMissCap) {
      _viewportLocalMissUntil.remove(_viewportLocalMissUntil.keys.first);
    }
  }

  void _pruneViewportLocalMissMap() {
    if (_viewportLocalMissUntil.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final expired = <String>[];
    for (final entry in _viewportLocalMissUntil.entries) {
      if (!now.isBefore(entry.value)) {
        expired.add(entry.key);
      }
    }
    for (final key in expired) {
      _viewportLocalMissUntil.remove(key);
    }
    while (_viewportLocalMissUntil.length > viewportLocalMissCap) {
      _viewportLocalMissUntil.remove(_viewportLocalMissUntil.keys.first);
    }
  }

  @visibleForTesting
  int get viewportLocalMissMapSizeForTest => _viewportLocalMissUntil.length;

  @visibleForTesting
  void rememberViewportLocalMissForTest(String cacheKey) {
    _rememberViewportLocalMiss(cacheKey);
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
    final rawLast = ((scrollOffset + viewportHeight) / rowExtent).ceil() + pad;
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

  /// 从 feed 行里只挑离视口中线最近的一个会话。
  ///
  /// 群聊列表用它做停滑 LOCAL warm，避免像单聊一样批量扫视口导致 SDK/local
  /// 历史读取串行堆积。null 行代表归档入口、群通知等非会话行。
  @visibleForTesting
  static V2TimConversation? selectViewportCenterCandidate({
    required List<V2TimConversation?> rowConversations,
    required double scrollOffset,
    required double viewportHeight,
    double rowExtent = estimatedRowExtent,
  }) {
    if (rowConversations.isEmpty || viewportHeight <= 0 || rowExtent <= 0) {
      return null;
    }
    final maxIndex = rowConversations.length - 1;
    final centerOffset = scrollOffset + viewportHeight / 2;
    final centerIndex = (centerOffset / rowExtent).floor().clamp(0, maxIndex);
    for (var distance = 0; distance <= maxIndex; distance++) {
      final before = centerIndex - distance;
      if (before >= 0) {
        final conversation = rowConversations[before];
        if (conversation != null && conversation.conversationID.isNotEmpty) {
          return conversation;
        }
      }
      final after = centerIndex + distance;
      if (distance > 0 && after <= maxIndex) {
        final conversation = rowConversations[after];
        if (conversation != null && conversation.conversationID.isNotEmpty) {
          return conversation;
        }
      }
    }
    return null;
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
      final peer = ConversationHistoryPeer.resolve(conversation);
      final isGroup = peer?.isGroup ?? false;
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
    if (sdkLimit <= 0) {
      return const <V2TimConversation>[];
    }
    final rankedC2c = <V2TimConversation>[...unreadC2c, ...restC2c];
    final rankedGroups = <V2TimConversation>[...unreadGroups, ...restGroups];

    // Reserve two of the eight SDK slots for groups, while always dispatching
    // the selected C2C conversations first. Spare slots are filled by either
    // type, without increasing the existing total or concurrency limits.
    final maxReservedGroups = sdkLimit < 2 ? sdkLimit : 2;
    final reservedGroups = rankedGroups.length < maxReservedGroups
        ? rankedGroups.length
        : maxReservedGroups;
    final c2cLimit = sdkLimit - reservedGroups;
    final c2cCount = rankedC2c.length < c2cLimit ? rankedC2c.length : c2cLimit;
    final groupLimit = sdkLimit - c2cCount;
    final groupCount =
        rankedGroups.length < groupLimit ? rankedGroups.length : groupLimit;
    return <V2TimConversation>[
      ...rankedC2c.take(c2cCount),
      ...rankedGroups.take(groupCount),
    ];
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
