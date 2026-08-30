import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/mobile_async_commit_guard.dart';

/// Serializes chat history recovery and post-open retry work per conversation.
class ChatHistoryRecoveryCoordinator {
  ChatHistoryRecoveryCoordinator._();

  static final ChatHistoryRecoveryCoordinator instance =
      ChatHistoryRecoveryCoordinator._();

  static const Duration _skipRecoveryWindow = Duration(seconds: 30);
  static const Duration _foregroundRequestCoalesceWindow = Duration(seconds: 2);
  static const Duration _defaultPostOpenRetryDelay =
      Duration(milliseconds: 800);

  static const int priorityInitial = 0;
  static const int priorityUser = 1;
  static const int priorityForeground = 2;
  static const int priorityBackground = 3;

  final Map<String, _ConversationRecoveryState> _states =
      <String, _ConversationRecoveryState>{};
  final Map<String, Future<void>> _exclusiveTasks = <String, Future<void>>{};
  final Map<String, int> _activePriorityByKey = <String, int>{};
  final MobileAsyncCommitGuard _commitGuard = MobileAsyncCommitGuard();
  int _lifecycleEpoch = 0;

  /// Invalidates delayed recovery callbacks during logout/page teardown.
  void invalidateLifecycle() {
    _lifecycleEpoch++;
    _commitGuard.advancePage();
    for (final state in _states.values) {
      state.pendingTask = null;
      state.pendingToken = null;
    }
  }

  void beginInitialLoad(String conversationKey) {
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return;
    }
    final state = _states.putIfAbsent(key, _ConversationRecoveryState.new);
    state.initialLoadInFlight = true;
    state.initialLoadComplete = false;
  }

  void markInitialLoadComplete(String conversationKey) {
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return;
    }
    final state = _states.putIfAbsent(key, _ConversationRecoveryState.new);
    state.initialLoadInFlight = false;
    state.initialLoadComplete = true;
    for (final completer in state.initialLoadWaiters) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    state.initialLoadWaiters.clear();
  }

  Future<void> waitForInitialLoadComplete(String conversationKey) async {
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return;
    }
    final state = _states.putIfAbsent(key, _ConversationRecoveryState.new);
    if (state.initialLoadComplete || !state.initialLoadInFlight) {
      return;
    }
    final completer = Completer<void>();
    state.initialLoadWaiters.add(completer);
    return completer.future;
  }

  void recordSuccessfulRecovery(String conversationKey) {
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return;
    }
    final state = _states.putIfAbsent(key, _ConversationRecoveryState.new);
    state.lastSuccessfulRecoveryAt = DateTime.now();
  }

  bool shouldSkipForegroundRecovery({
    required String conversationKey,
    required bool hasVisibleMessages,
    required bool previewAhead,
    required String reason,
    bool hasDeferredIncoming = false,
  }) {
    if (!hasVisibleMessages) {
      return false;
    }
    final normalizedReason = reason.trim();
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return false;
    }
    if (hasDeferredIncoming) {
      return false;
    }
    final last = _states[key]?.lastSuccessfulRecoveryAt;
    if (last == null ||
        DateTime.now().difference(last) >= _skipRecoveryWindow) {
      return false;
    }
    if (normalizedReason ==
        ConversationPreviewHistorySync.previewAheadOnOpenReason) {
      return true;
    }
    if (previewAhead) {
      return false;
    }
    if (normalizedReason == 'im_reconnected' ||
        normalizedReason == 'web_im_reconnected') {
      // 真实断线重连后的补拉不可跳过。
      return false;
    }
    if (normalizedReason != 'sync_server_finish' &&
        normalizedReason != 'connect_success' &&
        normalizedReason != 'app_resumed') {
      return false;
    }
    return true;
  }

  /// 合并同一次亮屏产生的 app_resumed / connect_success / im_reconnected。
  ///
  /// 这些信号来自不同监听器，可能在数百毫秒内同时到达；只允许第一个
  /// 请求进入 ChatHistoryRefreshBus，避免同一会话串行补拉两三遍。
  bool shouldCoalesceForegroundRequest({
    required String conversationKey,
    required String reason,
  }) {
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return true;
    }
    final normalizedReason = reason.trim();
    if (normalizedReason != 'app_resumed' &&
        normalizedReason != 'connect_success' &&
        normalizedReason != 'im_reconnected') {
      return false;
    }
    // IM_RECONNECT 仍然走 coalesce 窗口:同一个 unlock 事件可能在几百毫秒内
    // 触发 app_resumed + im_reconnected 两个信号,合并第二次避免重复拉历史。
    // 超过窗口 (foregroundRequestCoalesceWindow) 后,im_reconnected 会再次
    // 通过,作为权威恢复路径处理真正的断线重连。
    final state = _states.putIfAbsent(key, _ConversationRecoveryState.new);
    final now = DateTime.now();
    final last = state.lastForegroundRequestAt;
    if (last != null &&
        now.difference(last) < _foregroundRequestCoalesceWindow) {
      return true;
    }
    state.lastForegroundRequestAt = now;
    return false;
  }

  /// Lower [priority] values are more important. Drop incoming work when a
  /// higher-priority task is already active for the same conversation.
  bool shouldDropForPriority({
    required String conversationKey,
    required int priority,
  }) {
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return true;
    }
    final active = _activePriorityByKey[key];
    if (active == null) {
      return false;
    }
    return priority > active;
  }

  Future<void> runExclusive({
    required String conversationKey,
    required String reason,
    required int priority,
    required Future<void> Function() task,
  }) async {
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return;
    }
    final commitToken = _commitGuard.begin('history-recovery', key: key);
    final lifecycleEpoch = _lifecycleEpoch;

    if (shouldDropForPriority(conversationKey: key, priority: priority)) {
      return;
    }

    if (priority > priorityInitial) {
      await waitForInitialLoadComplete(key);
      if (lifecycleEpoch != _lifecycleEpoch) {
        return;
      }
      if (shouldDropForPriority(conversationKey: key, priority: priority)) {
        return;
      }
    }

    final previous = _exclusiveTasks[key];
    final state = _states.putIfAbsent(key, _ConversationRecoveryState.new);
    if (previous != null) {
      if (shouldDropForPriority(conversationKey: key, priority: priority)) {
        return;
      }
      if (lifecycleEpoch != _lifecycleEpoch) {
        return;
      }
      if (!_commitGuard.canCommit(commitToken)) {
        return;
      }
      // While one recovery is active, retain only the newest accepted trigger.
      // Every waiter shares the same drain future, so the active request is
      // followed by at most one latest request instead of N queued refreshes.
      state.pendingTask = task;
      state.pendingPriority = priority;
      state.pendingReason = reason;
      state.pendingToken = commitToken;
      await previous;
      if (!_commitGuard.canCommit(commitToken)) {
        return;
      }
      return;
    }

    final completion = Completer<void>();
    _exclusiveTasks[key] = completion.future;
    _activePriorityByKey[key] = priority;
    unawaited(() async {
      var nextTask = task;
      var nextPriority = priority;
      var nextToken = commitToken;
      try {
        while (true) {
          if (lifecycleEpoch != _lifecycleEpoch && nextToken == commitToken) {
            break;
          }
          await nextTask();
          final pending = state.pendingTask;
          if (pending == null) {
            break;
          }
          nextTask = pending;
          nextPriority = state.pendingPriority ?? nextPriority;
          state.pendingTask = null;
          state.pendingPriority = null;
          state.pendingReason = null;
          final pendingToken = state.pendingToken;
          state.pendingToken = null;
          if (pendingToken == null || !_commitGuard.canCommit(pendingToken)) {
            break;
          }
          nextToken = pendingToken;
          _activePriorityByKey[key] = nextPriority;
        }
        completion.complete();
      } catch (error, stackTrace) {
        completion.completeError(error, stackTrace);
      } finally {
        _exclusiveTasks.remove(key);
        _activePriorityByKey.remove(key);
        state.pendingTask = null;
        state.pendingPriority = null;
        state.pendingReason = null;
        state.pendingToken = null;
      }
    }());
    await completion.future;
  }

  void schedulePostOpenRetry({
    required String conversationKey,
    required String conversationID,
    required ConvType conversationType,
    Duration delay = _defaultPostOpenRetryDelay,
    required Future<void> Function({
      required String conversationID,
      ConvType? conversationType,
    }) retry,
  }) {
    final key = conversationKey.trim();
    final id = conversationID.trim();
    if (key.isEmpty || id.isEmpty) {
      return;
    }
    final state = _states.putIfAbsent(key, _ConversationRecoveryState.new);
    if (state.postOpenRetryScheduled) {
      return;
    }
    state.postOpenRetryScheduled = true;
    unawaited(() async {
      try {
        await waitForInitialLoadComplete(key);
        if (shouldDropForPriority(
          conversationKey: key,
          priority: priorityBackground,
        )) {
          return;
        }
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
        if (shouldDropForPriority(
          conversationKey: key,
          priority: priorityBackground,
        )) {
          return;
        }
        await runExclusive(
          conversationKey: key,
          reason: 'post_open_retry',
          priority: priorityBackground,
          task: () => retry(
            conversationID: id,
            conversationType: conversationType,
          ),
        );
      } finally {
        state.postOpenRetryScheduled = false;
      }
    }());
  }

  @visibleForTesting
  void resetForTest() {
    _states.clear();
    _exclusiveTasks.clear();
    _activePriorityByKey.clear();
    _lifecycleEpoch = 0;
    _commitGuard.reset();
  }
}

class _ConversationRecoveryState {
  bool initialLoadInFlight = false;
  bool initialLoadComplete = false;
  bool postOpenRetryScheduled = false;
  DateTime? lastSuccessfulRecoveryAt;
  DateTime? lastForegroundRequestAt;
  Future<void> Function()? pendingTask;
  int? pendingPriority;
  String? pendingReason;
  MobileAsyncCommitToken? pendingToken;
  final List<Completer<void>> initialLoadWaiters = <Completer<void>>[];
}
