import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_open_perf_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_peek_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_bubble_dedupe.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/chat_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/outgoing_visible_probe.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';

/// 用与会话预览相同的方式，为聊天页首屏灌入历史消息。
class ChatHistoryPeekBootstrap {
  ChatHistoryPeekBootstrap._();

  static const List<Duration> defaultRetryDelays = <Duration>[
    Duration.zero,
    Duration(milliseconds: 350),
    Duration(milliseconds: 900),
    Duration(milliseconds: 1800),
    Duration(milliseconds: 3000),
  ];

  /// 本地-only 首屏是否仍可能有更早历史（含云端未漫游部分）。
  ///
  /// [localReportedHasMoreOlder] 来自 SDK 本地 isFinished 取反，不能单独采信：
  /// 本机只有 tip/最新一条且本地扫完时也会是 false，但云端可能还有一整窗。
  static bool localFirstImpliesMayHaveOlder({
    required int localCount,
    required bool localReportedHasMoreOlder,
    int fetchCount = HistoryMessageDartConstant.initialOpenFetchCount,
  }) {
    if (localCount <= 0) {
      return localReportedHasMoreOlder;
    }
    if (localCount < fetchCount) {
      return true;
    }
    return localReportedHasMoreOlder;
  }

  /// 内存空窗或未满首屏的薄窗：应先读本地库并尽早 signal，避免干等 CLOUD
  /// 导致 AbsorbPointer 门一直关着（能返回、列表滑不动）。
  static bool shouldAttemptLocalFirstBeforeCloud({
    required int memoryCount,
    required bool completeOpenWindow,
    int fetchCount = HistoryMessageDartConstant.initialOpenFetchCount,
  }) {
    if (completeOpenWindow) {
      return false;
    }
    if (memoryCount <= 0) {
      return true;
    }
    return memoryCount < fetchCount;
  }

  /// 本地拉取是否应替换当前内存窗（空窗，或本地不少于内存条数）。
  static bool shouldReplaceMemoryWithLocalFirst({
    required int memoryCount,
    required int localCount,
  }) {
    if (localCount <= 0) {
      return false;
    }
    if (memoryCount <= 0) {
      return true;
    }
    return localCount >= memoryCount;
  }

  static final Map<String, Future<bool>> _inFlightByKey =
      <String, Future<bool>>{};

  /// 会话 tip 是自己发出且不在即将上屏的列表里时，拼到 newest 端。
  /// 不按时间戳丢弃：tip 不在列表即应可见。
  @visibleForTesting
  static List<V2TimMessage> spliceSelfLastMessageIfMissing({
    required V2TimMessage? last,
    required List<V2TimMessage> messages,
  }) {
    if (last == null || last.isSelf != true) {
      return messages;
    }
    if (ConversationPreviewHistorySync.isMessageVisibleInList(last, messages)) {
      return messages;
    }
    return TUIChatGlobalModel.sortMessagesNewestFirst(
      TUIChatGlobalModel.dedupeMessages(<V2TimMessage>[last, ...messages]),
    );
  }

  static bool _isC2cConversation(V2TimConversation conversation) {
    return (conversation.groupID?.trim().isEmpty ?? true) &&
        ((conversation.userID?.trim().isNotEmpty ?? false) ||
            conversation.type == 1);
  }

  static bool _usesOfficialSdkHistory(V2TimConversation conversation) {
    if (_isC2cConversation(conversation)) {
      final userID = conversation.userID?.trim() ?? '';
      return !userID.startsWith('@TOA#_');
    }
    return (conversation.groupID?.trim().isNotEmpty ?? false) ||
        conversation.type == 2;
  }

  static void clearSession() {
    _inFlightByKey.clear();
  }

  static Future<bool> apply({
    required V2TimConversation conversation,
    required TUIChatGlobalModel globalModel,
    ChatLifeCycle? lifeCycle,
    List<Duration>? retryDelays,
    void Function()? onFirstWindowCommitted,
  }) async {
    final key = ConversationPreviewHistorySync.conversationMessageCacheKey(
      conversation,
    );
    if (key == null || key.isEmpty) {
      return false;
    }

    final inFlight = _inFlightByKey[key];
    if (inFlight != null) {
      return inFlight;
    }

    final task = _applyImpl(
      conversation: conversation,
      globalModel: globalModel,
      lifeCycle: lifeCycle,
      retryDelays: retryDelays,
      key: key,
      onFirstWindowCommitted: onFirstWindowCommitted,
    );
    _inFlightByKey[key] = task;
    try {
      return await task;
    } finally {
      if (identical(_inFlightByKey[key], task)) {
        _inFlightByKey.remove(key);
      }
    }
  }

  static Future<bool> _applyImpl({
    required V2TimConversation conversation,
    required TUIChatGlobalModel globalModel,
    ChatLifeCycle? lifeCycle,
    List<Duration>? retryDelays,
    required String key,
    void Function()? onFirstWindowCommitted,
  }) async {
    var firstWindowSignaled = false;
    void signalFirstWindow() {
      if (firstWindowSignaled) {
        return;
      }
      firstWindowSignaled = true;
      onFirstWindowCommitted?.call();
    }
    if (!ConversationPeekService.canPeek(conversation)) {
      ChatHistoryTrace.log('bootstrap_skip_cannot_peek', conversationID: key);
      return false;
    }

    final beforeWarm = globalModel.messageListMap[key];
    ChatHistoryTrace.log(
      'bootstrap_start',
      conversationID: key,
      extras: <String, Object?>{
        'rawConvID': conversation.conversationID,
        'groupID': conversation.groupID ?? '',
        'warmLoaded': globalModel.hasInitialHistoryLoaded(key),
        ...ChatHistoryTrace.windowSummary(beforeWarm, prefix: 'warm'),
      },
    );

    final existingAtStart = globalModel.mergedAliasMessageList(key);
    if (_usesOfficialSdkHistory(conversation) &&
        HistoryPaginationAnchor.shouldRejectC2cPeekRestamp(
          existingCount: existingAtStart.length,
          incomingCount: HistoryMessageDartConstant.initialOpenFetchCount,
        )) {
      OutgoingVisibleProbe.log(
        'bootstrap_skip_c2c_filled_sdk',
        conversationID: key,
        extras: <String, Object?>{'existingCount': existingAtStart.length},
      );
      signalFirstWindow();
      return true;
    }

    // 重连预热 / 冷开并行 peek 已灌窗且 tip 对齐：跳过再打 LOCAL→CLOUD→归档。
    if (ConversationPreviewHistorySync.canSkipOpenRebootstrap(
      globalModel: globalModel,
      conversationKey: key,
      preview: conversation.lastMessage,
    )) {
      OutgoingVisibleProbe.log(
        'bootstrap_warm_skip',
        conversationID: key,
        extras: OutgoingVisibleProbe.trackedInList(beforeWarm),
      );
      ChatHistoryTrace.log(
        'bootstrap_skip_already_warm',
        conversationID: key,
        extras: ChatHistoryTrace.windowSummary(beforeWarm, prefix: 'warm'),
      );
      ChatOpenPerfLog.mark(
        'page_bootstrap_warm_skip',
        conversationID: key,
        extras: <String, Object?>{'warmCount': beforeWarm?.length ?? 0},
      );
      signalFirstWindow();
      return true;
    }

    // 清空宽限期内且内存已有消息：过滤水位前旧消息后直接展示。
    // 内存仍为空时不在这里 return，继续单次 peek，以免漏掉清空后的新消息。
    if (ArchiveHistoryProvider.isInHistoryClearGrace(key) &&
        globalModel.hasInitialHistoryLoaded(key) &&
        globalModel.rawMessageCount(key) > 0) {
      final existing =
          globalModel.messageListMap[key] ?? const <V2TimMessage>[];
      final kept = await ArchiveHistoryProvider.filterMessagesAfterHistoryClear(
        conversationID: key,
        messages: existing,
      );
      globalModel.setMessageList(
        key,
        spliceSelfLastMessageIfMissing(
          last: conversation.lastMessage,
          messages: kept,
        ),
        needResetNewMessageCount: false,
        replace: true,
      );
      ChatHistoryTrace.log(
        'bootstrap_keep_clear_grace',
        conversationID: key,
        extras: ChatHistoryTrace.windowSummary(kept, prefix: 'kept'),
      );
      signalFirstWindow();
      return true;
    }

    // 曾清空过 / 宽限期内空列表：只拉一轮并过滤水位前消息，缩短空会话进页等待。
    final clearedAt = await ArchiveHistoryProvider.historyClearedAtMs(key);
    final inClearGrace = ArchiveHistoryProvider.isInHistoryClearGrace(key);
    final clearPendingAtStart = ArchiveHistoryProvider.isHistoryClearPending(
      key,
    );

    bool positionAllowsCommit() {
      return globalModel.getMessageListPosition(key) ==
              HistoryMessagePosition.bottom &&
          globalModel.getSearchJumpStatus(key) == SearchJumpStatus.idle;
    }

    Future<bool> canCommitInitialWindow() async {
      if (!positionAllowsCommit()) {
        ChatHistoryTrace.log(
          'bootstrap_abort_history_position',
          conversationID: key,
        );
        return false;
      }
      final currentClearedAt = await ArchiveHistoryProvider.historyClearedAtMs(
        key,
      );
      final currentClearPending = ArchiveHistoryProvider.isHistoryClearPending(
        key,
      );
      if (currentClearedAt != clearedAt ||
          currentClearPending != clearPendingAtStart) {
        ChatHistoryTrace.log(
          'bootstrap_abort_history_clear_changed',
          conversationID: key,
          extras: <String, Object?>{
            'clearedAtBefore': clearedAt,
            'clearedAtNow': currentClearedAt,
            'pendingBefore': clearPendingAtStart,
            'pendingNow': currentClearPending,
          },
        );
        return false;
      }
      return true;
    }

    // 冷启动 / 薄窗：先只读本地并尽快提交，让聊天树可交互；
    // 后面的 LOCAL→CLOUD→归档仅负责补齐校对。
    // 薄窗若跳过本步，会干等云端 → AbsorbPointer 门长期不关（能返回不能滑）。
    final memoryCountBeforeLocal = globalModel.rawMessageCount(key);
    final completeBeforeLocal =
        ConversationPreviewHistorySync.isCompleteOpenHistoryWindow(
      globalModel: globalModel,
      conversationKey: key,
    );
    final isC2cEntry = _usesOfficialSdkHistory(conversation);
    if (!isC2cEntry &&
        shouldAttemptLocalFirstBeforeCloud(
          memoryCount: memoryCountBeforeLocal,
          completeOpenWindow: completeBeforeLocal,
        ) &&
        positionAllowsCommit()) {
      final local = await ConversationPeekService.loadLocalForChatEntry(
        conversation,
      );
      var localMessages = List<V2TimMessage>.from(local.messages);
      if (localMessages.isNotEmpty &&
          lifeCycle?.didGetHistoricalMessageList != null) {
        localMessages =
            await lifeCycle!.didGetHistoricalMessageList(localMessages);
      }
      if (localMessages.isNotEmpty &&
          shouldReplaceMemoryWithLocalFirst(
            memoryCount: globalModel.rawMessageCount(key),
            localCount: localMessages.length,
          ) &&
          await canCommitInitialWindow()) {
        OutgoingVisibleProbe.log(
          'bootstrap_local_first',
          conversationID: key,
          extras: <String, Object?>{
            'memoryCountBefore': memoryCountBeforeLocal,
            'localCount': localMessages.length,
            'willReplace': true,
            'lastMessage': conversation.lastMessage == null
                ? ''
                : OutgoingVisibleProbe.brief(conversation.lastMessage!),
            'memoryTracked': OutgoingVisibleProbe.trackedInList(
              globalModel.rawMessageList(key),
            ).toString(),
            'localTracked':
                OutgoingVisibleProbe.trackedInList(localMessages).toString(),
          },
        );
        globalModel.setMessageList(
          key,
          spliceSelfLastMessageIfMissing(
            last: conversation.lastMessage,
            messages: CallBubbleDedupe.prepareOpenHistoryMessages(localMessages),
          ),
          needResetNewMessageCount: false,
          replace: true,
        );
        // 本地窗已可上屏：标 loaded，避免列表一直当冷壳 bootstrapping。
        // 后面的 LOCAL→CLOUD 仍会在本任务里校对补齐。
        globalModel.markInitialHistoryLoaded(key);
        // 本地 isFinished 只表示本机库扫完，不等于云端没有更早历史。
        // 不满首屏窗口时必须保持 mayHaveOlder，否则会把 1 条当「完整短会话」
        // 提前揭开，云端补数时再整表蹦出。
        globalModel.markInitialHistoryMayHaveOlder(
          key,
          mayHaveOlder: localFirstImpliesMayHaveOlder(
            localCount: localMessages.length,
            localReportedHasMoreOlder: local.hasMoreOlder,
          ),
        );
        globalModel.setMessageListPosition(
          key,
          HistoryMessagePosition.bottom,
          notify: true,
        );
        ChatOpenPerfLog.mark(
          'page_bootstrap_local_first',
          conversationID: key,
          extras: <String, Object?>{
            'localCount': localMessages.length,
            'localHasMoreOlder': local.hasMoreOlder,
            'memoryCountBefore': memoryCountBeforeLocal,
          },
        );
        // 有本地最新消息就立刻揭开首屏（贴底）；云端在同任务后续静默合并，
        // 反转列表 + bottom 锚点让旧消息向上长、最新一条不跳。
        signalFirstWindow();
      }
    }

    final delays = (clearedAt > 0 || inClearGrace)
        ? const <Duration>[Duration.zero]
        : (retryDelays ?? defaultRetryDelays);
    for (var index = 0; index < delays.length; index++) {
      final delay = delays[index];
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      if (!positionAllowsCommit()) {
        ChatHistoryTrace.log(
          'bootstrap_abort_history_position',
          conversationID: key,
        );
        return false;
      }

      final result = await ConversationPeekService.loadForChatEntry(
        conversation,
      );
      if (!positionAllowsCommit()) {
        ChatHistoryTrace.log(
          'bootstrap_abort_history_position',
          conversationID: key,
        );
        return false;
      }
      if (result.messages.isEmpty) {
        // SDK/归档本轮为空：保留已有 peek 暖窗，禁止用空结果抹掉。
        if (globalModel.hasInitialHistoryLoaded(key) &&
            globalModel.rawMessageCount(key) > 0) {
          ChatHistoryTrace.log(
            'bootstrap_empty_keep_warm',
            conversationID: key,
            extras: <String, Object?>{
              'retry': index,
              ...ChatHistoryTrace.windowSummary(
                globalModel.messageListMap[key],
                prefix: 'warm',
              ),
            },
          );
          return true;
        }
        ChatHistoryTrace.log(
          'bootstrap_empty_retry',
          conversationID: key,
          extras: <String, Object?>{'retry': index},
        );
        continue;
      }

      var messages = List<V2TimMessage>.from(result.messages);
      if (lifeCycle?.didGetHistoricalMessageList != null) {
        messages = await lifeCycle!.didGetHistoricalMessageList(messages);
      }
      if (clearedAt > 0 || ArchiveHistoryProvider.isInHistoryClearGrace(key)) {
        messages = await ArchiveHistoryProvider.filterMessagesAfterHistoryClear(
          conversationID: key,
          messages: messages,
        );
      }
      if (!await canCommitInitialWindow()) {
        return false;
      }
      if (messages.isEmpty) {
        continue;
      }

      final existing = globalModel.mergedAliasMessageList(key);
      final warmTs = existing.isEmpty
          ? 0
          : (existing
              .map((m) => m.timestamp ?? 0)
              .fold<int>(0, (a, b) => a > b ? a : b));
      final fetchedTs = messages
          .map((m) => m.timestamp ?? 0)
          .fold<int>(0, (a, b) => a > b ? a : b);
      // 拉到的首屏几乎全是旧归档，且比暖窗 tip/更新消息更旧：禁止灌入。
      if (HistoryPaginationAnchor.isStaleArchiveDominatedWindow(
        messages,
        referenceTimestampSec:
            warmTs > 0 ? warmTs : conversation.lastMessage?.timestamp,
      )) {
        ChatHistoryTrace.log(
          'bootstrap_skip_stale_archive',
          conversationID: key,
          extras: <String, Object?>{
            'retry': index,
            'warmNewestTs': warmTs,
            'fetchedNewestTs': fetchedTs,
            ...ChatHistoryTrace.windowSummary(messages, prefix: 'fetched'),
          },
        );
        if (globalModel.hasInitialHistoryLoaded(key) &&
            globalModel.rawMessageCount(key) > 0) {
          return true;
        }
        continue;
      }
      OutgoingVisibleProbe.log(
        'bootstrap_replace',
        conversationID: key,
        extras: <String, Object?>{
          'retry': index,
          'existingCount': existing.length,
          'fetchedCount': messages.length,
          'lastMessage': conversation.lastMessage == null
              ? ''
              : OutgoingVisibleProbe.brief(conversation.lastMessage!),
          'existingTracked':
              OutgoingVisibleProbe.trackedInList(existing).toString(),
          'fetchedTracked':
              OutgoingVisibleProbe.trackedInList(messages).toString(),
        },
      );
      ChatHistoryTrace.log(
        'bootstrap_replace',
        conversationID: key,
        extras: <String, Object?>{
          'retry': index,
          'hasMoreOlder': result.hasMoreOlder,
          'warmNewestTs': warmTs,
          'fetchedNewestTs': fetchedTs,
          'fetchedOlderThanWarm':
              warmTs > 0 && fetchedTs > 0 && fetchedTs < warmTs,
          ...ChatHistoryTrace.windowSummary(existing, prefix: 'before'),
          ...ChatHistoryTrace.windowSummary(messages, prefix: 'fetched'),
        },
      );

      final completeWindow =
          messages.length >= HistoryMessageDartConstant.initialOpenFetchCount;
      final exhaustedOlder = !result.hasMoreOlder;
      // 聊天首屏必须保留已经加载的历史。预加载结果可能只是 SDK 漫游尚未
      // 同步完成的部分窗口，不能像会话预览一样整表替换。
      // 已补到超过首屏的窗，禁止再用 20 条 peek 冲掉更早 IM。
      final preserveFilled = isC2cEntry
          ? HistoryPaginationAnchor.shouldRejectC2cPeekRestamp(
              existingCount: existing.length,
              incomingCount: messages.length,
            )
          : HistoryPaginationAnchor.shouldPreserveFilledHistoryOverPeek(
              existingCount: existing.length,
              fetchedCount: messages.length,
            );
      if (preserveFilled) {
        OutgoingVisibleProbe.log(
          'bootstrap_preserve_filled_over_peek',
          conversationID: key,
          extras: <String, Object?>{
            'existingCount': existing.length,
            'fetchedCount': messages.length,
          },
        );
      }
      final merged = isC2cEntry
          ? TUIChatGlobalModel.mergeC2cOfficialOlderPage(
              existing: existing,
              fetched: messages,
            )
          : existing.isNotEmpty && !preserveFilled
              ? TUIChatGlobalModel.mergePeekWindowWithLiveMemory(
                  existing: existing,
                  fetched: messages,
                )
              : TUIChatGlobalModel.mergeHistoricalWithInMemory(
                  existing: existing,
                  fetched: messages,
                );
      // 贴底静默合并：已有本地 tip 时不要因 notify 位置抖动触发二次 pin。
      final hadLocalFirst = existing.isNotEmpty;
      globalModel.setMessageList(
        key,
        spliceSelfLastMessageIfMissing(
          last: conversation.lastMessage,
          messages: isC2cEntry
              ? TUIChatGlobalModel.dedupeMessages(merged)
              : CallBubbleDedupe.prepareOpenHistoryMessages(merged),
        ),
        needResetNewMessageCount: false,
        replace: true,
      );
      globalModel.markInitialHistoryLoaded(key);
      globalModel.markInitialHistoryMayHaveOlder(
        key,
        // 满窗口通常仍有更早消息；SDK 明确无更早时再关掉探测。
        mayHaveOlder: !exhaustedOlder,
      );
      globalModel.setMessageListPosition(
        key,
        HistoryMessagePosition.bottom,
        notify: completeWindow && !hadLocalFirst,
      );
      OutgoingVisibleProbe.log(
        'bootstrap_done',
        conversationID: key,
        extras: OutgoingVisibleProbe.trackedInList(
          globalModel.messageListMap[key],
        ),
      );
      ChatHistoryTrace.log(
        'bootstrap_done',
        conversationID: key,
        extras: ChatHistoryTrace.windowSummary(
          globalModel.messageListMap[key],
          prefix: 'after',
        ),
      );
      signalFirstWindow();
      return true;
    }
    if (!await canCommitInitialWindow()) {
      return false;
    }
    // 清空后 / 确实无历史：标记 empty-loaded，避免上层一直转圈。
    if (clearedAt > 0 || inClearGrace) {
      globalModel.markInitialHistoryLoaded(key);
      globalModel.markInitialHistoryMayHaveOlder(key, mayHaveOlder: false);
    }
    ChatHistoryTrace.log(
      'bootstrap_miss',
      conversationID: key,
      extras: <String, Object?>{
        'clearedAt': clearedAt,
        'inClearGrace': inClearGrace,
      },
    );
    return false;
  }
}
