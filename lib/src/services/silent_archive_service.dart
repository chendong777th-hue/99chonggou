import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/web_chat_open_policy.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/chat_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';

/// 归档补拉 merge 辅助（过滤与 SDK 重叠项）。首屏 defer 静默补档已移除，与移动端同步对齐。
class SilentArchiveService {
  SilentArchiveService._();

  static final SilentArchiveService instance = SilentArchiveService._();

  final Set<String> _inFlight = <String>{};
  final Set<String> _completedInitialKeys = <String>{};

  void scheduleInitialSupplement({
    required V2TimConversation conversation,
    required String conversationKey,
    required int sdkMessageCount,
    required int requestedCount,
    ChatLifeCycle? lifeCycle,
    V2TimMessage? lastMessageHint,
  }) {
    if (!WebChatOpenPolicy.shouldScheduleSilentInitialArchive(
      isInitialWindow: true,
      sdkMessageCount: sdkMessageCount,
      requestedCount: requestedCount,
    )) {
      return;
    }
    unawaited(
      _runInitialSupplement(
        conversation: conversation,
        conversationKey: conversationKey,
        requestedCount: requestedCount,
        lifeCycle: lifeCycle,
        lastMessageHint: lastMessageHint,
      ),
    );
  }

  void scheduleAfterBootstrapInject({
    required V2TimConversation conversation,
    required String conversationKey,
    required int injectedCount,
    required int requestedCount,
    ChatLifeCycle? lifeCycle,
  }) {
    scheduleInitialSupplement(
      conversation: conversation,
      conversationKey: conversationKey,
      sdkMessageCount: injectedCount,
      requestedCount: requestedCount,
      lifeCycle: lifeCycle,
      lastMessageHint: conversation.lastMessage,
    );
  }

  Future<void> _runInitialSupplement({
    required V2TimConversation conversation,
    required String conversationKey,
    required int requestedCount,
    ChatLifeCycle? lifeCycle,
    V2TimMessage? lastMessageHint,
  }) async {
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return;
    }
    final flightKey = 'initial:$key';
    if (_completedInitialKeys.contains(flightKey)) {
      return;
    }
    if (!_inFlight.add(flightKey)) {
      return;
    }
    try {
      if (!ArchiveHistoryProvider.isAvailable ||
          ArchiveHistoryProvider.shouldSkipArchiveFallback(key)) {
        return;
      }
      final globalModel = serviceLocator<TUIChatGlobalModel>();
      var existing = globalModel.messageListMap[key];
      final existingCount = existing?.length ?? 0;
      if (existingCount >= requestedCount) {
        return;
      }

      ChatHistoryTrace.log(
        'silent_archive_start',
        conversationID: key,
        extras: <String, Object?>{
          'existingCount': existingCount,
          'requestedCount': requestedCount,
        },
      );

      final isGroup = _isGroup(conversation);
      final rawConversationID = isGroup
          ? (conversation.groupID?.trim() ?? '')
          : (conversation.userID?.trim() ?? '');
      final storageId = isGroup
          ? ChatIdFormat.canonicalGroupStorageId(rawConversationID)
          : rawConversationID;
      if (storageId.isEmpty) {
        return;
      }

      final oldest =
          HistoryPaginationAnchor.oldestArchiveCursorAnchor(existing);
      final fetchCount = max(1, requestedCount - existingCount);

      final loginUserID = TIMUIKitCore.getInstance().loginInfo.userID.trim();
      ArchiveHistoryResult result;
      try {
        result = await ArchiveHistoryProvider.fetchOlder(
          ArchiveHistoryRequest(
            isGroup: isGroup,
            conversationID: storageId,
            loginUserID: loginUserID.isEmpty ? null : loginUserID,
            beforeTimeMs: oldest == null
                ? null
                : (((oldest.timestamp ?? 0) > 0)
                    ? (oldest.timestamp! * 1000)
                    : null),
            beforeSeq: int.tryParse(oldest?.seq ?? ''),
            beforeMsgID: oldest?.msgID,
            count: fetchCount,
          ),
        );
      } catch (e) {
        ChatHistoryTrace.log(
          'silent_archive_error',
          conversationID: key,
          extras: <String, Object?>{'error': e.toString()},
        );
        return;
      }

      var archiveMessages = result.messages;
      archiveMessages = filterArchiveSupplement(
        candidates: archiveMessages,
        existing: existing,
        oldestAnchor: oldest,
      );
      if (archiveMessages.isEmpty) {
        ChatHistoryTrace.log(
          'silent_archive_empty',
          conversationID: key,
          extras: <String, Object?>{'hasMore': result.hasMore},
        );
        if (!result.hasMore) {
          globalModel.markInitialHistoryMayHaveOlder(key, mayHaveOlder: false);
        }
        return;
      }

      final refTs = _referenceTimestampSec(
        existing: existing,
        lastMessageHint: lastMessageHint ?? conversation.lastMessage,
      );
      if (HistoryPaginationAnchor.isStaleArchiveDominatedWindow(
        archiveMessages,
        referenceTimestampSec: refTs,
      )) {
        ChatHistoryTrace.log(
          'silent_archive_reject_stale',
          conversationID: key,
          extras: <String, Object?>{
            'refTs': refTs ?? 0,
            'archiveCount': archiveMessages.length,
            ...ChatHistoryTrace.windowSummary(
              archiveMessages,
              prefix: 'arch',
            ),
          },
        );
        ArchiveHistoryProvider.markArchiveFallbackSkipped(key);
        return;
      }

      var processed =
          await lifeCycle?.didGetHistoricalMessageList(archiveMessages) ??
              archiveMessages;
      processed = TUIChatGlobalModel.dedupeMessages(processed);
      processed = await ArchiveHistoryProvider.filterMessagesAfterHistoryClear(
        conversationID: key,
        messages: processed,
      );
      if (processed.isEmpty) {
        return;
      }

      // 归档 HTTP 较慢：merge 前重新读当前窗，避免覆盖进页后新到的实时消息。
      existing = globalModel.messageListMap[key];
      processed = filterArchiveSupplement(
        candidates: processed,
        existing: existing,
        oldestAnchor: HistoryPaginationAnchor.oldestArchiveCursorAnchor(existing),
      );
      if (processed.isEmpty) {
        return;
      }

      var merged = TUIChatGlobalModel.mergeHistoricalWithInMemory(
        existing: existing,
        fetched: processed,
      );
      if (merged.length > requestedCount) {
        merged = merged.sublist(0, requestedCount);
      }

      merged = await _dropMessagesAtOrBeforeHistoryClear(
        conversation: conversation,
        conversationKey: key,
        messages: merged,
      );
      if (merged.isEmpty) {
        return;
      }

      globalModel.setMessageList(
        key,
        merged,
        needResetNewMessageCount: false,
        replace: true,
      );
      globalModel.markInitialHistoryLoaded(key);
      globalModel.markInitialHistoryMayHaveOlder(
        key,
        mayHaveOlder: result.hasMore || merged.length >= requestedCount,
      );

      ChatHistoryTrace.log(
        'silent_archive_done',
        conversationID: key,
        extras: <String, Object?>{
          'mergedCount': merged.length,
          'archiveAdded': processed.length,
          'hasMore': result.hasMore,
          ...ChatHistoryTrace.windowSummary(merged, prefix: 'final'),
        },
      );
      _completedInitialKeys.add(flightKey);
    } finally {
      _inFlight.remove(flightKey);
    }
  }

  static bool _isGroup(V2TimConversation conversation) {
    return conversation.type == 2 ||
        (conversation.groupID?.trim().isNotEmpty ?? false);
  }

  static bool _archiveMessageStrictlyOlder(
    V2TimMessage message,
    V2TimMessage before,
  ) {
    if (TUIChatGlobalModel.messagesCorrelateForDedup(message, before)) {
      return false;
    }
    final messageSeq = int.tryParse(message.seq ?? '');
    final beforeSeq = int.tryParse(before.seq ?? '');
    if (messageSeq != null &&
        beforeSeq != null &&
        messageSeq > 0 &&
        beforeSeq > 0) {
      return messageSeq < beforeSeq;
    }
    final messageTs = message.timestamp ?? 0;
    final beforeTs = before.timestamp ?? 0;
    return messageTs < beforeTs;
  }

  /// 去掉已在当前窗内的消息，以及不比锚点更旧的归档重叠段。
  static List<V2TimMessage> filterArchiveSupplement({
    required List<V2TimMessage> candidates,
    required List<V2TimMessage>? existing,
    required V2TimMessage? oldestAnchor,
  }) {
    if (candidates.isEmpty) {
      return const <V2TimMessage>[];
    }
    return candidates.where((message) {
      if (existing != null && existing.isNotEmpty) {
        for (final kept in existing) {
          if (TUIChatGlobalModel.messagesCorrelateForDedup(message, kept)) {
            return false;
          }
        }
      }
      if (oldestAnchor != null &&
          !_archiveMessageStrictlyOlder(message, oldestAnchor)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  static int? _referenceTimestampSec({
    required List<V2TimMessage>? existing,
    V2TimMessage? lastMessageHint,
  }) {
    if (existing != null && existing.isNotEmpty) {
      return existing.first.timestamp;
    }
    return lastMessageHint?.timestamp;
  }

  static Future<List<V2TimMessage>> _dropMessagesAtOrBeforeHistoryClear({
    required V2TimConversation conversation,
    required String conversationKey,
    required List<V2TimMessage> messages,
  }) async {
    if (messages.isEmpty) {
      return messages;
    }
    final clearedAt = await ConversationLocalStore.instance.historyClearedAtMs(
      conversationKey,
    );
    if (clearedAt <= 0) {
      return messages;
    }
    return messages
        .where(
          (message) =>
              ConversationLocalStore.messageTimestampMs(message) > clearedAt,
        )
        .toList(growable: false);
  }
}
