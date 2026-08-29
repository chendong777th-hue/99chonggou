import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/silent_archive_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/web_chat_open_policy.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/message_media_metadata_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_batch.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_coverage.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_history_peek_loader.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';

class ConversationPeekLoadResult {
  const ConversationPeekLoadResult({
    required this.messages,
    required this.hasMoreOlder,
    required this.isFinished,
    this.requestedCursor,
    this.returnedBounds = const MessageHistoryBounds.empty(),
    this.batchKind = MessageHistoryBatchKind.olderPage,
  });

  final List<V2TimMessage> messages;
  final bool hasMoreOlder;
  final bool isFinished;
  final MessageHistoryCursor? requestedCursor;
  final MessageHistoryBounds returnedBounds;
  final MessageHistoryBatchKind batchKind;

  /// Converts the legacy peek result into the typed history envelope used by
  /// reconciliation. Generation and clear epoch belong to the caller because
  /// they are allocated around the actual async request.
  MessageHistoryBatch<V2TimMessage> toBatch({
    required String conversationKey,
    required MessageReconciliationSource requestedSource,
    required MessageReconciliationSource actualSource,
    required int requestGeneration,
    required int clearEpoch,
    required bool cloudResponseProven,
    MessageHistoryBatchKind? batchKind,
    Iterable<V2TimMessage>? messages,
  }) {
    final effectiveMessages =
        messages?.toList(growable: false) ?? this.messages;
    return MessageHistoryBatch<V2TimMessage>(
      conversationKey: conversationKey,
      requestedSource: requestedSource,
      actualSource: actualSource,
      batchKind: batchKind ?? this.batchKind,
      requestGeneration: requestGeneration,
      clearEpoch: clearEpoch,
      requestedCursor: requestedCursor,
      returnedBounds: messages == null && !returnedBounds.isEmpty
          ? returnedBounds
          : _boundsForMessages(effectiveMessages),
      isFinished: isFinished,
      hasMoreOlder: hasMoreOlder,
      cloudHasMoreNewer: false,
      cloudResponseProven: cloudResponseProven,
      messages: effectiveMessages,
    );
  }

  static MessageHistoryBounds _boundsForMessages(
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
}

class ConversationPeekService {
  ConversationPeekService._();

  static const int peekMessageCount = 15;

  static final MessageService _messageService =
      serviceLocator<MessageService>();

  static bool canPeek(V2TimConversation conversation) {
    if ((conversation.userID ?? '').trim() == '10000') {
      return false;
    }
    return _isGroup(conversation)
        ? (conversation.groupID?.trim().isNotEmpty ?? false)
        : (conversation.userID?.trim().isNotEmpty ?? false);
  }

  static Future<ConversationPeekLoadResult> loadInitial(
    V2TimConversation conversation,
  ) {
    return _loadOlder(
      conversation: conversation,
      anchor: null,
      count: peekMessageCount,
    );
  }

  /// 进入聊天页首屏：C2C / 群聊只打 IM 云端最新一页。
  static Future<ConversationPeekLoadResult> loadForChatEntry(
    V2TimConversation conversation,
  ) {
    return _loadCloudOnlyForChatEntry(conversation);
  }

  /// C2C / 群聊进页只打 IM 云端最新一页，不和本地库/归档焊在一起。
  static Future<ConversationPeekLoadResult> _loadCloudOnlyForChatEntry(
    V2TimConversation conversation,
  ) async {
    if (!canPeek(conversation)) {
      return const ConversationPeekLoadResult(
        messages: <V2TimMessage>[],
        hasMoreOlder: false,
        isFinished: true,
      );
    }
    final isGroup = _isGroup(conversation);
    final userID = isGroup ? null : conversation.userID?.trim();
    final rawGroupID = conversation.groupID?.trim();
    final groupID = isGroup && rawGroupID != null && rawGroupID.isNotEmpty
        ? ChatIdFormat.canonicalGroupStorageId(rawGroupID)
        : null;
    final result = await MessageHistoryPeekLoader.loadOlderCloudOnlyResult(
      messageService: _messageService,
      count: HistoryMessageDartConstant.initialOpenFetchCount,
      userID: userID,
      groupID: groupID,
    );
    var messages = _dedupeMessages(result.messageList);
    messages = await _dropMessagesAtOrBeforeHistoryClear(
      conversation: conversation,
      messages: messages,
    );
    await MessageMediaMetadataStore.instance.hydrateMessages(messages);
    unawaited(
      MessageMediaMetadataStore.instance.persistFromMessages(messages),
    );
    return ConversationPeekLoadResult(
      messages: messages,
      hasMoreOlder:
          messages.length >= HistoryMessageDartConstant.initialOpenFetchCount ||
              !result.isFinished,
      isFinished: result.isFinished,
      batchKind: MessageHistoryBatchKind.latestWindow,
      requestedCursor: const MessageHistoryCursor(
        direction: MessageHistoryCursorDirection.latest,
      ),
      returnedBounds: ConversationPeekLoadResult._boundsForMessages(messages),
    );
  }

  /// 冷启动聊天首屏快路径：只读 IM SDK 本地库，不等待云端或归档。
  /// 查到的消息应立即上屏；完整窗口随后由 [loadForChatEntry] 异步校对。
  static Future<ConversationPeekLoadResult> loadLocalForChatEntry(
    V2TimConversation conversation,
  ) async {
    if (!canPeek(conversation)) {
      return const ConversationPeekLoadResult(
        messages: <V2TimMessage>[],
        hasMoreOlder: false,
        isFinished: true,
      );
    }
    final isGroup = _isGroup(conversation);
    final userID = isGroup ? null : conversation.userID?.trim();
    final rawGroupID = conversation.groupID?.trim();
    final groupID = isGroup && rawGroupID != null && rawGroupID.isNotEmpty
        ? ChatIdFormat.canonicalGroupStorageId(rawGroupID)
        : null;
    final result = await MessageHistoryPeekLoader.loadOlderLocalOnlyResult(
      messageService: _messageService,
      count: HistoryMessageDartConstant.initialOpenFetchCount,
      userID: userID,
      groupID: groupID,
    );
    var messages = _dedupeMessages(result.messageList);
    messages = await _dropMessagesAtOrBeforeHistoryClear(
      conversation: conversation,
      messages: messages,
    );
    await MessageMediaMetadataStore.instance.hydrateMessages(messages);
    unawaited(
      MessageMediaMetadataStore.instance.persistFromMessages(messages),
    );
    return ConversationPeekLoadResult(
      messages: messages,
      hasMoreOlder:
          messages.length >= HistoryMessageDartConstant.initialOpenFetchCount ||
              !result.isFinished,
      isFinished: result.isFinished,
      batchKind: MessageHistoryBatchKind.localSnapshot,
      requestedCursor: const MessageHistoryCursor(
        direction: MessageHistoryCursorDirection.latest,
      ),
      returnedBounds: ConversationPeekLoadResult._boundsForMessages(messages),
    );
  }

  static Future<ConversationPeekLoadResult> loadOlder({
    required V2TimConversation conversation,
    required V2TimMessage anchor,
  }) {
    return _loadOlder(
      conversation: conversation,
      anchor: anchor,
      count: peekMessageCount,
    );
  }

  static Future<ConversationPeekLoadResult> _loadOlder({
    required V2TimConversation conversation,
    required V2TimMessage? anchor,
    required int count,
  }) async {
    if (!canPeek(conversation)) {
      return const ConversationPeekLoadResult(
        messages: [],
        hasMoreOlder: false,
        isFinished: true,
      );
    }

    final isGroup = _isGroup(conversation);
    final userID = isGroup ? null : conversation.userID?.trim();
    // SDK / 归档一律裸群 ID（@TGS#…），禁止 group_ 前缀。
    final rawGroupID = conversation.groupID?.trim();
    final groupID = isGroup && rawGroupID != null && rawGroupID.isNotEmpty
        ? ChatIdFormat.canonicalGroupStorageId(rawGroupID)
        : null;
    final lastMsgID = anchor?.msgID;
    final lastMsgSeq = int.tryParse(anchor?.seq?.toString() ?? '') ?? -1;

    final peekConvKey = isGroup ? (groupID ?? '') : (userID ?? '');
    ChatHistoryTrace.log(
      'peek_load_start',
      conversationID: peekConvKey,
      extras: <String, Object?>{
        'rawGroupID': rawGroupID ?? '',
        'isGroup': isGroup,
        'count': count,
        'hasAnchor': anchor != null,
        'anchorId': anchor?.msgID ?? '',
        'anchorTs': anchor?.timestamp ?? 0,
      },
    );

    final peekResult =
        await MessageHistoryPeekLoader.loadOlderLocalThenCloudResult(
      messageService: _messageService,
      count: count,
      userID: userID,
      groupID: groupID,
      lastMsgID: lastMsgID,
      lastMsgSeq: lastMsgSeq,
    );
    final sdkMessages = peekResult.messageList;

    var merged = _dedupeMessages(sdkMessages);
    merged = await _dropMessagesAtOrBeforeHistoryClear(
      conversation: conversation,
      messages: merged,
    );
    final sdkPageFull = merged.length >= count;
    var archiveHasMore = false;
    var archiveFetched = 0;
    final sdkOnlyCount = merged.length;
    final archiveDeferred = anchor == null &&
        WebChatOpenPolicy.shouldScheduleSilentInitialArchive(
          isInitialWindow: true,
          sdkMessageCount: sdkOnlyCount,
          requestedCount: count,
        );

    final needsArchive = _shouldFetchArchiveFallback(
      anchor: anchor,
      sdkMessages: merged,
      requestedCount: count,
    );
    ChatHistoryTrace.log(
      'peek_sdk_window',
      conversationID: peekConvKey,
      extras: <String, Object?>{
        'sdkCount': merged.length,
        'sdkPageFull': sdkPageFull,
        'needsArchive': needsArchive,
        ...ChatHistoryTrace.windowSummary(merged, prefix: 'sdk'),
      },
    );
    if (needsArchive &&
        ArchiveHistoryProvider.isAvailable &&
        !ArchiveHistoryProvider.shouldSkipArchiveFallback(
          isGroup ? (groupID ?? '') : (userID ?? ''),
        )) {
      final beforeMessage =
          anchor ?? HistoryPaginationAnchor.oldestArchiveCursorAnchor(merged);
      final fetchCount = anchor == null && merged.length < count
          ? count - merged.length
          : count;
      ChatHistoryTrace.log(
        'peek_archive_fetch',
        conversationID: peekConvKey,
        extras: <String, Object?>{
          'fetchCount': fetchCount,
          'beforeId': beforeMessage?.msgID ?? '',
          'beforeTs': beforeMessage?.timestamp ?? 0,
          'beforeSeq': beforeMessage?.seq ?? '',
        },
      );
      final archiveResult = await _loadArchiveOlder(
        conversation: conversation,
        beforeMessage: beforeMessage,
        count: max(fetchCount, 1),
      );
      if (archiveResult != null) {
        archiveHasMore = archiveResult.hasMore;
        archiveFetched = archiveResult.messages.length;
        final archiveMessages = archiveResult.messages;
        // 首屏 SDK 为空时：若会话 lastMessage 明显新于归档最新一条，说明漫游未就绪、
        // 归档又不是「当前尾巴」——禁止用旧归档冒充首屏（否则会短暂/长期显示错误消息）。
        final rejectStaleInitial = anchor == null &&
            merged.isEmpty &&
            archiveMessages.isNotEmpty &&
            HistoryPaginationAnchor.isStaleArchiveDominatedWindow(
              archiveMessages,
              referenceTimestampSec: conversation.lastMessage?.timestamp,
            );
        if (rejectStaleInitial) {
          ChatHistoryTrace.log(
            'peek_archive_reject_stale_initial',
            conversationID: peekConvKey,
            extras: <String, Object?>{
              'lastMsgId': conversation.lastMessage?.msgID ?? '',
              'lastMsgTs': conversation.lastMessage?.timestamp ?? 0,
              'archiveFetched': archiveFetched,
              ...ChatHistoryTrace.windowSummary(
                archiveMessages,
                prefix: 'arch',
              ),
            },
          );
          archiveFetched = 0;
          archiveHasMore = true;
        } else if (archiveMessages.isNotEmpty) {
          final filteredArchive = SilentArchiveService.filterArchiveSupplement(
            candidates: archiveMessages,
            existing: merged,
            oldestAnchor: beforeMessage,
          );
          if (filteredArchive.isNotEmpty) {
            merged = _dedupeMessages([
              ...filteredArchive,
              ...merged,
            ]);
          }
          archiveFetched = filteredArchive.length;
        }
        if (!rejectStaleInitial && archiveFetched > 0) {
          ChatHistoryTrace.log(
            'peek_archive_result',
            conversationID: peekConvKey,
            extras: <String, Object?>{
              'archiveFetched': archiveFetched,
              'archiveHasMore': archiveHasMore,
              ...ChatHistoryTrace.windowSummary(
                archiveMessages,
                prefix: 'arch',
              ),
            },
          );
        }
      }
    }

    merged = await _dropMessagesAtOrBeforeHistoryClear(
      conversation: conversation,
      messages: merged,
    );

    if (anchor == null && merged.length > count) {
      merged = merged.sublist(merged.length - count);
    }

    var sorted = _sortChronologically(merged);
    sorted = GroupTipsMessageHelper.applyPostMergeFilters(sorted);
    await MessageMediaMetadataStore.instance.hydrateMessages(sorted);
    unawaited(
      MessageMediaMetadataStore.instance.persistFromMessages(sorted),
    );
    // 满窗口或归档声明还有更早 → 允许继续上拉（短会话不足一页则为 false）。
    final hasMoreOlder = archiveHasMore ||
        sorted.length >= count ||
        sdkPageFull ||
        archiveDeferred;
    ChatHistoryTrace.log(
      'peek_load_done',
      conversationID: peekConvKey,
      extras: <String, Object?>{
        'hasMoreOlder': hasMoreOlder,
        'archiveFetched': archiveFetched,
        'archiveDeferred': archiveDeferred,
        ...ChatHistoryTrace.windowSummary(sorted, prefix: 'final'),
      },
    );
    if (archiveDeferred) {
      SilentArchiveService.instance.scheduleInitialSupplement(
        conversation: conversation,
        conversationKey: peekConvKey,
        sdkMessageCount: sdkOnlyCount,
        requestedCount: count,
        lastMessageHint: conversation.lastMessage,
      );
    }
    return ConversationPeekLoadResult(
      messages: sorted,
      hasMoreOlder: hasMoreOlder,
      isFinished: !hasMoreOlder,
      batchKind: MessageHistoryBatchKind.olderPage,
      requestedCursor: MessageHistoryCursor(
        direction: MessageHistoryCursorDirection.older,
        lastMsgID: lastMsgID,
        lastMsgSeq: lastMsgSeq > 0 ? lastMsgSeq : null,
      ),
      returnedBounds: ConversationPeekLoadResult._boundsForMessages(sorted),
    );
  }

  static bool _shouldFetchArchiveFallback({
    required V2TimMessage? anchor,
    required List<V2TimMessage> sdkMessages,
    required int requestedCount,
  }) {
    if (sdkMessages.isEmpty) {
      return true;
    }
    if (anchor == null &&
        WebChatOpenPolicy.shouldDeferInitialArchive(
          isInitialWindow: true,
          sdkMessageCount: sdkMessages.length,
        )) {
      return false;
    }
    if (anchor == null && sdkMessages.length < requestedCount) {
      return true;
    }
    return false;
  }

  static Future<ArchiveHistoryResult?> _loadArchiveOlder({
    required V2TimConversation conversation,
    required V2TimMessage? beforeMessage,
    required int count,
  }) async {
    if (!ArchiveHistoryProvider.isAvailable || count <= 0) {
      return null;
    }

    final isGroup = _isGroup(conversation);
    final rawConversationID = isGroup
        ? (conversation.groupID?.trim() ?? '')
        : (conversation.userID?.trim() ?? '');
    final conversationID = isGroup
        ? ChatIdFormat.canonicalGroupStorageId(rawConversationID)
        : rawConversationID;
    if (conversationID.isEmpty) {
      return null;
    }

    final loginUserID = TIMUIKitCore.getInstance().loginInfo.userID.trim();
    final beforeTs = beforeMessage?.timestamp;
    final beforeSeq = int.tryParse(beforeMessage?.seq?.toString() ?? '');

    ArchiveHistoryResult result;
    try {
      result = await ArchiveHistoryProvider.fetchOlder(
        ArchiveHistoryRequest(
          isGroup: isGroup,
          conversationID: conversationID,
          loginUserID: loginUserID.isEmpty ? null : loginUserID,
          beforeTimeMs: beforeMessage == null
              ? null
              : ((beforeTs != null && beforeTs > 0) ? beforeTs * 1000 : null),
          beforeSeq: beforeSeq,
          beforeMsgID: beforeMessage?.msgID,
          count: count,
        ),
      );
    } catch (e) {
      debugPrint(
        '[ConversationPeek] archive fetch error conv=$conversationID err=$e',
      );
      return null;
    }

    if (result.messages.isEmpty) {
      return result;
    }

    final filtered = <V2TimMessage>[];
    for (final message in result.messages) {
      if (beforeMessage == null ||
          _archiveMessageStrictlyOlder(message, beforeMessage)) {
        filtered.add(message);
      }
    }
    return ArchiveHistoryResult(
      messages: filtered,
      hasMore: result.hasMore,
    );
  }

  static bool _archiveMessageStrictlyOlder(
    V2TimMessage message,
    V2TimMessage before,
  ) {
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

  static Future<List<V2TimMessage>> _dropMessagesAtOrBeforeHistoryClear({
    required V2TimConversation conversation,
    required List<V2TimMessage> messages,
  }) async {
    if (messages.isEmpty) {
      return messages;
    }
    final conversationID = conversation.conversationID.trim().isNotEmpty
        ? conversation.conversationID.trim()
        : (_isGroup(conversation)
            ? (conversation.groupID?.trim() ?? '')
            : (conversation.userID?.trim() ?? ''));
    if (conversationID.isEmpty) {
      return messages;
    }
    final clearedAt = await ConversationLocalStore.instance.historyClearedAtMs(
      conversationID,
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

  static V2TimMessage? _oldestMessage(List<V2TimMessage> messages) {
    return HistoryPaginationAnchor.oldestArchiveCursorAnchor(messages);
  }

  static bool _isGroup(V2TimConversation conversation) {
    return conversation.type == 2 ||
        (conversation.groupID?.trim().isNotEmpty ?? false);
  }

  static List<V2TimMessage> _dedupeMessages(List<V2TimMessage> messages) {
    if (messages.isEmpty) {
      return const [];
    }
    return TUIChatGlobalModel.dedupeMessages(messages);
  }

  static List<V2TimMessage> _sortChronologically(List<V2TimMessage> messages) {
    return TUIChatGlobalModel.sortMessagesChronologicallyAsc(messages);
  }
}
