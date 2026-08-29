part of 'tui_chat_separate_view_model.dart';

/// Mechanical extract of history load loops. Same library as the view model so
/// private helpers remain accessible without widening API surface.
class HistoryPaginationLoadRunner {
  HistoryPaginationLoadRunner(this.model, this.pagination);

  final TUIChatSeparateViewModel model;
  final HistoryPaginationController pagination;

  MessageHistoryBounds _returnedBounds(Iterable<V2TimMessage> messages) {
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

  MessageHistoryCursor? _requestedCursor({
    required LoadDirection direction,
    required String? lastMsgID,
    required int lastMsgSeq,
  }) {
    if (lastMsgID == null && lastMsgSeq <= 0) return null;
    return MessageHistoryCursor(
      direction: direction == LoadDirection.latest
          ? MessageHistoryCursorDirection.newer
          : MessageHistoryCursorDirection.older,
      lastMsgID: lastMsgID,
      lastMsgSeq: lastMsgSeq > 0 ? lastMsgSeq : null,
    );
  }

  Future<bool> loadChatRecord({
    HistoryMsgGetTypeEnum? getType,
    int lastMsgSeq = -1,
    required int count,
    String? lastMsgID,
    LoadDirection direction = LoadDirection.previous,
    bool forceReloadNewest = false,
  }) async {
    final requestKey = model._historyRequestKey(
      getType: getType,
      lastMsgSeq: lastMsgSeq,
      count: count,
      lastMsgID: lastMsgID,
      direction: direction,
    );
    // Re-arm haveMoreData if the empty-batch latch has expired (30s).
    if (direction == LoadDirection.previous &&
        !pagination.haveMoreData &&
        pagination.emptyBatchLatchExpired) {
      pagination.haveMoreData = true;
      pagination.lastEmptyBatchAt = null;
      ChatHistoryTrace.log(
        'load_chat_record_empty_batch_retry',
        conversationID: model.conversationID,
      );
    }
    if (pagination.historyLoadingKeys.contains(requestKey)) {
      ChatHistoryTrace.log(
        'load_chat_record_deduped',
        conversationID: model.conversationID,
        extras: <String, Object?>{
          'requestKey': requestKey,
          'direction': direction.name,
          'haveMoreData': pagination.haveMoreData,
        },
      );
      return direction == LoadDirection.latest
          ? pagination.haveMoreLatestData
          : pagination.haveMoreData;
    }
    final isPreviousPagination = (lastMsgID != null || lastMsgSeq > 0) &&
        direction == LoadDirection.previous;
    ChatHistoryTrace.log(
      'load_chat_record_start',
      conversationID: model.conversationID,
      extras: <String, Object?>{
        'direction': direction.name,
        'getType': getType?.name,
        'lastMsgID': lastMsgID,
        'lastMsgSeq': lastMsgSeq,
        'count': count,
        'forceReloadNewest': forceReloadNewest,
        'requestKey': requestKey,
        'isPaginated': isPreviousPagination,
        'haveMoreData': pagination.haveMoreData,
        'emptyBatchAt': pagination.lastEmptyBatchAt?.toIso8601String(),
        'position':
            model.globalModel.getMessageListPosition(model.conversationID).name,
        ...ChatHistoryTrace.windowSummary(
          _aliasAwareInMemoryList(model),
          prefix: 'memory',
        ),
      },
    );
    if (isPreviousPagination && pagination.previousPaginationInFlight) {
      ChatHistoryTrace.log(
        'load_chat_record_previous_in_flight',
        conversationID: model.conversationID,
        extras: <String, Object?>{
          'lastMsgID': lastMsgID,
          'lastMsgSeq': lastMsgSeq,
          'haveMoreData': pagination.haveMoreData,
        },
      );
      return pagination.haveMoreData;
    }
    pagination.historyLoadingKeys.add(requestKey);
    if (pagination.historyLoadingKeys.length == 1) {
      model._notify();
    }
    if (isPreviousPagination) {
      pagination.previousPaginationInFlight = true;
    }
    final windowGenAtStart = model._historyWindowGeneration;
    MessageReconciliationRequest? reconciliationRequest;
    var reconciliationCommitted = false;
    try {
      var previousListGrew = false;
      final isPaginatedLoad =
          !forceReloadNewest && (lastMsgID != null || lastMsgSeq > 0);
      if (direction == LoadDirection.latest &&
          SearchJumpLatestGate.shouldSkipLatestWhileReadingHistory(
            isReadingHistory:
                model.globalModel.isReadingHistory(model.conversationID),
            haveMoreLatestData: pagination.haveMoreLatestData,
            memoryWindowMissingNewer: model.globalModel
                .memoryWindowMissingNewer(model.conversationID),
            forceReloadNewest: forceReloadNewest,
          )) {
        ChatHistoryTrace.log(
          'load_chat_record_skip_latest_reading_history',
          conversationID: model.conversationID,
          extras: <String, Object?>{
            'lastMsgID': lastMsgID,
            'lastMsgSeq': lastMsgSeq,
            'haveMoreLatestData': pagination.haveMoreLatestData,
            'position': model.globalModel
                .getMessageListPosition(model.conversationID)
                .name,
          },
        );
        return pagination.haveMoreLatestData;
      }
      if (!forceReloadNewest && lastMsgID == null && lastMsgSeq <= 0) {
        final existing = _aliasAwareInMemoryList(model);
        if (existing.length >= count) {
          pagination.haveMoreData = true;
          return pagination.haveMoreData;
        }
      }
      bool tempHaveMoreData = pagination.haveMoreData;
      // latest 补拉只更新 latest 状态，不能污染 older 分页开关。
      if (direction == LoadDirection.latest) {
        pagination.haveMoreLatestData = false;
      } else {
        tempHaveMoreData = false;
      }

      // 上拉/带锚点分页必须保留请求发起时用户正在阅读的窗口。须走别名合并
      // （c2c_ / 裸 id），否则 baseline 为空会把整表 replace 成 SDK 短批次。
      final inMemoryAtRequest = _aliasAwareInMemoryList(model);
      final previousPaginationBaseline = isPaginatedLoad
          ? List<V2TimMessage>.of(inMemoryAtRequest)
          : const <V2TimMessage>[];
      if (isPaginatedLoad) {
        _logPreviousPaginationStage(
          model.conversationID,
          stage: 'request_start',
          extras: <String, Object?>{
            'direction': direction.name,
            'lastMsgID': lastMsgID,
            'lastMsgSeq': lastMsgSeq,
            'baselineCount': previousPaginationBaseline.length,
            'aliasMergedCount': inMemoryAtRequest.length,
            'position': model.globalModel
                .getMessageListPosition(model.conversationID)
                .name,
            'memorySuppressed': model.globalModel
                .isMemoryWindowSuppressed(model.conversationID),
          },
        );
      }

      // 调用MessageService获取聊天记录
      final HistoryMsgGetTypeEnum resolvedGetType = getType ??
          (direction == LoadDirection.previous
              ? HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG
              : HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_NEWER_MSG);
      final requestedHistorySource = resolvedGetType ==
                  HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG ||
              resolvedGetType == HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_NEWER_MSG
          ? MessageReconciliationSource.local
          : MessageReconciliationSource.cloud;
      final networkBeforeHistoryRequest =
          model.globalModel.messageReconciliationNetworkState;

      final String? historyUserID =
          model.conversationType == ConvType.c2c ? model.conversationID : null;
      final String? historyGroupID = model.conversationType == ConvType.group
          ? model.conversationID
          : null;
      final paginationAnchor = (lastMsgID != null || lastMsgSeq > 0)
          ? model._resolvePaginationAnchorInMemory(
              lastMsgID: lastMsgID,
              lastMsgSeq: lastMsgSeq,
            )
          : null;

      V2TimMessageListResult? response;
      if (getType == null &&
          isPreviousPagination &&
          pagination.archiveOlderActive &&
          !model.usesOfficialSdkHistory) {
        // 已进入归档分页：列表最老一条来自归档，SDK 无法据此翻页，直接走归档。
        // C2C / 群聊只走 IM 云端，不进自建归档。
        return await _loadArchiveOlderHistory(count: count);
      }
      reconciliationRequest = model.globalModel.beginHistoryReconciliation(
        conversationID: model.conversationID,
        requestedSource: requestedHistorySource,
        networkState: networkBeforeHistoryRequest,
      );
      final useOfficialCloudOnly = model.usesOfficialSdkHistory &&
          direction == LoadDirection.previous &&
          !forceReloadNewest;
      final useC2cOlderCursor =
          useOfficialCloudOnly && model.conversationType == ConvType.c2c;
      if (useOfficialCloudOnly || (getType == null && isPreviousPagination)) {
        var effectiveLastMsgID = lastMsgID;
        var effectiveLastMsgSeq = lastMsgSeq;
        var effectiveAnchor = paginationAnchor;
        final tipLikeId = effectiveLastMsgID != null &&
            (effectiveLastMsgID.startsWith('ce_') ||
                effectiveLastMsgID.startsWith('local_gt_') ||
                effectiveLastMsgID.startsWith('local_'));
        final tipAnchor = effectiveAnchor != null &&
            HistoryPaginationAnchor.isLocalInjectedMessage(effectiveAnchor);
        // 上拉绝不用本地 tip 当 SDK 锚点。
        if (tipLikeId || tipAnchor) {
          final repaired = HistoryPaginationAnchor.oldestSdkPaginationAnchor(
            inMemoryAtRequest,
          );
          ChatHistoryTrace.log(
            'load_chat_record_reject_tip_anchor',
            conversationID: model.conversationID,
            extras: <String, Object?>{
              'fromMsgID': effectiveLastMsgID,
              'toMsgID': repaired?.msgID ?? '',
              'toSeq': repaired?.seq ?? '',
            },
          );
          if (repaired != null) {
            effectiveLastMsgID = repaired.msgID;
            effectiveLastMsgSeq =
                int.tryParse(repaired.seq?.toString() ?? '') ?? -1;
            effectiveAnchor = repaired;
          } else if (!model.usesOfficialSdkHistory) {
            // tip-only：跳过 SDK，走归档（若仍被抑制则直接失败）。
            effectiveLastMsgID = null;
            effectiveLastMsgSeq = -1;
            effectiveAnchor = null;
            final archiveGrew = await _loadArchiveOlderHistory(count: count);
            return archiveGrew;
          }
        }
        // The SDK tail cursor is only valid for C2C. Group message seq is a
        // conversation-wide ordering key, so use the actual oldest group
        // message passed by the list; applying a C2C tail to a group can move
        // the cursor forward and return a page already in memory.
        if (useC2cOlderCursor && isPreviousPagination) {
          final official = HistoryPaginationAnchor.c2cOfficialOlderCursor(
            newestFirstWindow: inMemoryAtRequest,
            lastSdkPageTail: model._c2cSdkOlderPageTail,
          );
          if (official != null) {
            ChatHistoryTrace.log(
              'load_chat_record_c2c_official_cursor',
              conversationID: model.conversationID,
              extras: <String, Object?>{
                'fromMsgID': effectiveLastMsgID,
                'toMsgID': official.msgID ?? '',
              },
            );
            effectiveLastMsgID = official.msgID;
            effectiveLastMsgSeq = -1;
            effectiveAnchor = official;
          }
        } else if (effectiveAnchor != null &&
            !HistoryPaginationAnchor.canUseForSdkPagination(effectiveAnchor)) {
          final repaired = HistoryPaginationAnchor.oldestSdkPaginationAnchor(
            inMemoryAtRequest,
          );
          if (repaired != null) {
            ChatHistoryTrace.log(
              'load_chat_record_repair_anchor',
              conversationID: model.conversationID,
              extras: <String, Object?>{
                'fromMsgID': effectiveLastMsgID,
                'toMsgID': repaired.msgID,
                'toSeq': repaired.seq,
                'toTs': repaired.timestamp,
              },
            );
            effectiveLastMsgID = repaired.msgID;
            effectiveLastMsgSeq =
                int.tryParse(repaired.seq?.toString() ?? '') ?? -1;
            effectiveAnchor = repaired;
          }
        }

        final peekResult = useOfficialCloudOnly
            ? await MessageHistoryPeekLoader.loadOlderCloudOnlyResult(
                messageService: model._messageService,
                count: count,
                userID: historyUserID,
                groupID: historyGroupID,
                lastMsgID: effectiveLastMsgID,
                lastMsgSeq: effectiveLastMsgSeq,
                lastMsg: effectiveAnchor,
              )
            : await MessageHistoryPeekLoader.loadOlderLocalThenCloudResult(
                messageService: model._messageService,
                count: count,
                userID: historyUserID,
                groupID: historyGroupID,
                lastMsgID: effectiveLastMsgID,
                lastMsgSeq: effectiveLastMsgSeq,
                lastMsg: effectiveAnchor,
              );
        final mergedMessages = peekResult.messageList;
        if (mergedMessages.isEmpty) {
          final invalidAnchor = effectiveAnchor != null &&
              !HistoryPaginationAnchor.canUseForSdkPagination(effectiveAnchor);
          ChatHistoryTrace.log(
            'load_chat_record_empty_batch',
            conversationID: model.conversationID,
            extras: <String, Object?>{
              'lastMsgID': effectiveLastMsgID,
              'lastMsgSeq': effectiveLastMsgSeq,
              'count': count,
              'invalidAnchor': invalidAnchor,
            },
          );
          // SDK 已无更早消息，回退自建后端归档补拉冷历史（游标跳过 ce_*）。
          if (!model.usesOfficialSdkHistory) {
            final archiveGrew = await _loadArchiveOlderHistory(count: count);
            if (archiveGrew) {
              return true;
            }
          }
          // 本地注入消息不能作为 SDK 锚点；空批次在此场景下不代表云端无历史。
          if (!invalidAnchor) {
            // Do not permanently latch haveMoreData=false on an empty batch.
            // The empty result may be transient (SDK local DB not yet synced,
            // network hiccup). Record the timestamp and allow retry after
            // emptyBatchRetryWindow (30s). Only SDK isFinished=true sets
            // the permanent archiveOlderExhausted latch.
            pagination.haveMoreData = false;
            pagination.lastEmptyBatchAt = DateTime.now();
          }
          return false;
        }
        response = peekResult;
      } else {
        response =
            await model._messageService.getHistoryMessageListWithComplete(
          count: count,
          getType: resolvedGetType,
          userID: historyUserID,
          groupID: historyGroupID,
          lastMsgID: lastMsgID,
          lastMsgSeq: lastMsgSeq,
          lastMsg: paginationAnchor,
        );
        if (direction == LoadDirection.latest &&
            getType == null &&
            (response == null || response.messageList.isEmpty)) {
          final localLatestResponse =
              await model._messageService.getHistoryMessageListWithComplete(
            count: count,
            getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_NEWER_MSG,
            userID: historyUserID,
            groupID: historyGroupID,
            lastMsgID: lastMsgID,
            lastMsgSeq: lastMsgSeq,
            lastMsg: paginationAnchor,
          );
          if (localLatestResponse != null &&
              localLatestResponse.messageList.isNotEmpty) {
            response = localLatestResponse;
          } else {
            response ??= localLatestResponse;
          }
        }
      }

      if (response == null) {
        final provenance = MessageReconciliationProvenance.resolve(
          requestedSource: requestedHistorySource,
          beforeRequest: networkBeforeHistoryRequest,
          afterResponse: model.globalModel.messageReconciliationNetworkState,
        );
        ChatHistoryTrace.log(
          'history_response_provenance',
          conversationID: model.conversationID,
          extras: <String, Object?>{
            'direction': direction.name,
            'requestedSource': requestedHistorySource.name,
            'actualSource': provenance.actualSource.name,
            'networkState': provenance.networkState.name,
            'cloudProven': provenance.cloudResponseProven,
            'hasResponse': false,
          },
        );
        ChatHistoryTrace.log(
          'load_chat_record_response_empty',
          conversationID: model.conversationID,
          extras: <String, Object?>{
            'direction': direction.name,
            'lastMsgID': lastMsgID,
            'lastMsgSeq': lastMsgSeq,
            'isPaginated': isPaginatedLoad,
          },
        );
        return false;
      }
      final responseProvenance = MessageReconciliationProvenance.resolve(
        requestedSource: requestedHistorySource,
        beforeRequest: networkBeforeHistoryRequest,
        afterResponse: model.globalModel.messageReconciliationNetworkState,
      );
      ChatHistoryTrace.log(
        'history_response_provenance',
        conversationID: model.conversationID,
        extras: <String, Object?>{
          'direction': direction.name,
          'requestedSource': requestedHistorySource.name,
          'actualSource': responseProvenance.actualSource.name,
          'networkState': responseProvenance.networkState.name,
          'cloudProven': responseProvenance.cloudResponseProven,
          'hasResponse': true,
          'resultCount': response.messageList.length,
          'isFinished': response.isFinished,
          ...ChatHistoryTrace.windowSummary(
            response.messageList,
            prefix: 'response',
          ),
        },
      );
      final requestedCursor = _requestedCursor(
        direction: direction,
        lastMsgID: lastMsgID,
        lastMsgSeq: lastMsgSeq,
      );
      final returnedBounds = _returnedBounds(response.messageList);

      // around / 搜索整窗替换后：丢弃替换前发起的在途翻页，防止旧最新页 baseline 污染。
      if (windowGenAtStart != model._historyWindowGeneration) {
        ChatHistoryTrace.log(
          'load_chat_record_stale_after_window_replace',
          conversationID: model.conversationID,
          extras: <String, Object?>{
            'direction': direction.name,
            'lastMsgID': lastMsgID,
            'lastMsgSeq': lastMsgSeq,
            'windowGenAtStart': windowGenAtStart,
            'windowGenNow': model._historyWindowGeneration,
            'batchCount': response.messageList.length,
          },
        );
        return false;
      }

      // 运营公众号：云端历史可能为空，回退拉本地缓存。
      if (model.conversationType == ConvType.c2c &&
          model.conversationID.startsWith('@TOA#_') &&
          response.messageList.isEmpty &&
          resolvedGetType == HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG &&
          lastMsgID == null) {
        final localResponse =
            await model._messageService.getHistoryMessageListWithComplete(
          count: count,
          getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
          userID: model.conversationID,
          lastMsgID: lastMsgID,
          lastMsgSeq: lastMsgSeq,
        );
        if (localResponse != null && localResponse.messageList.isNotEmpty) {
          response = localResponse;
        }
      }

      // 根据加载方向更新是否还能继续加载更多消息
      if (direction == LoadDirection.latest) {
        pagination.haveMoreLatestData = !response.isFinished;
      } else {
        tempHaveMoreData = !response.isFinished;
      }

      // 根据 lastMsgID / lastMsgSeq 判断是否为分页加载。
      if (isPaginatedLoad) {
        List<V2TimMessage> messageList = response.messageList;
        List<V2TimMessage> newList = [];

        // Rebase on the newest in-memory list after the SDK request completes.
        final mergeBase = _aliasAwareInMemoryList(model);
        if (mergeBase.isEmpty && previousPaginationBaseline.isNotEmpty) {
          mergeBase.addAll(previousPaginationBaseline);
        }

        // 根据加载方向拼接消息列表
        if (direction == LoadDirection.latest) {
          messageList = messageList.reversed.toList();
          final canMerge = HistoryPaginationContinuity.canPrependNewerBatch(
            existingNewestFirst: mergeBase
                .map(
                  (m) => (
                    seq: int.tryParse(m.seq?.trim() ?? ''),
                    timestamp: m.timestamp,
                  ),
                )
                .toList(growable: false),
            incomingNewerNewestFirst: messageList
                .map(
                  (m) => (
                    seq: int.tryParse(m.seq?.trim() ?? ''),
                    timestamp: m.timestamp,
                  ),
                )
                .toList(growable: false),
          );
          if (!canMerge) {
            final existingNewestTs =
                mergeBase.isEmpty ? 0 : (mergeBase.first.timestamp ?? 0);
            final incomingOldestTs =
                messageList.isEmpty ? 0 : (messageList.last.timestamp ?? 0);
            ChatHistoryTrace.log(
              'load_latest_rejected_direction_error',
              conversationID: model.conversationID,
              extras: <String, Object?>{
                'mergeBaseCount': mergeBase.length,
                'incomingCount': messageList.length,
                'existingNewestTs': existingNewestTs,
                'incomingOldestTs': incomingOldestTs,
                'lastMsgID': lastMsgID,
                'lastMsgSeq': lastMsgSeq,
              },
            );
            // Direction error only (incoming is older than existing newest).
            // Keep prior window; leave tip-fill available for a later batch.
            pagination.haveMoreLatestData = true;
            model._notify();
            return false;
          }
          newList = _combineMessageList(messageList, mergeBase);
        } else {
          // previous 方向：信任 SDK lastMsg 游标，不做 seq 邻接检查。
          // dedupeMessages 处理 msgID 重叠。空洞由空洞检测处理（Phase 3）。
          newList = _combineMessageList(mergeBase, messageList);
        }
        if (direction == LoadDirection.previous) {
          final currentOldest =
              HistoryPaginationAnchor.oldestSdkPaginationAnchor(mergeBase);
          final hasStrictlyOlderMessage = currentOldest == null ||
              messageList.any(
                (message) =>
                    TUIChatGlobalModel.compareMessagesChronological(
                      message,
                      currentOldest,
                    ) <
                    0,
              );
          if (messageList.isNotEmpty && !hasStrictlyOlderMessage) {
            final mismatchBounds = _returnedBounds(messageList);
            ChatHistoryTrace.log(
              'load_previous_direction_mismatch',
              conversationID: model.conversationID,
              extras: <String, Object?>{
                'requestedLastMsgID': lastMsgID,
                'requestedLastMsgSeq': lastMsgSeq,
                'currentOldestMsgID': currentOldest.msgID,
                'currentOldestSeq': currentOldest.seq,
                'responseNewestMsgID': mismatchBounds.newestMsgID,
                'responseNewestSeq': mismatchBounds.newestSeq,
                'responseOldestMsgID': mismatchBounds.oldestMsgID,
                'responseOldestSeq': mismatchBounds.oldestSeq,
                'isFinished': response.isFinished,
              },
            );
            // Keep the cursor retryable. A direction-mismatched page is not
            // proof that history ended and must not consume the top reach.
            pagination.haveMoreData = !response.isFinished;
            tempHaveMoreData = pagination.haveMoreData;
            model._notify();
            return false;
          }
          _logPreviousPaginationStage(
            model.conversationID,
            stage: 'after_combine',
            extras: <String, Object?>{
              'mergeBaseCount': mergeBase.length,
              'rawBatchCount': messageList.length,
              'combinedCount': newList.length,
              'aliasMergedCountNow': _aliasAwareInMemoryList(model).length,
              'isFinished': response.isFinished,
            },
          );
        }

        // 处理新获取的消息列表后回调
        final List<V2TimMessage> msgList =
            await model.lifeCycle?.didGetHistoricalMessageList(newList) ??
                newList;
        if (direction == LoadDirection.previous &&
            msgList.length != newList.length) {
          _logPreviousPaginationStage(
            model.conversationID,
            stage: 'lifecycle_mutated',
            extras: <String, Object?>{
              'beforeLifecycle': newList.length,
              'afterLifecycle': msgList.length,
              'delta': msgList.length - newList.length,
            },
          );
        }
        // didGetHistoricalMessageList may itself await application work. Rebase
        // once more so messages received during that callback are not erased by
        // the replace-style atomic commit below.
        final afterLifecycleBase = _aliasAwareInMemoryList(model);
        final stableCommitBase = previousPaginationBaseline.isNotEmpty
            ? _mergeHistoryPage(
                existing: previousPaginationBaseline,
                fetched: afterLifecycleBase,
              )
            : afterLifecycleBase;
        final dedupedMsgList = _mergeHistoryPage(
          existing: stableCommitBase,
          fetched: msgList,
        );
        final commitBaseCount = stableCommitBase.length;
        if (isPaginatedLoad) {
          _logPreviousPaginationStage(
            model.conversationID,
            stage: 'pre_commit_merge',
            extras: <String, Object?>{
              'direction': direction.name,
              'baselineCount': previousPaginationBaseline.length,
              'afterLifecycleAliasCount': afterLifecycleBase.length,
              'stableCommitBaseCount': commitBaseCount,
              'dedupedCount': dedupedMsgList.length,
              'rawBatchCount': response.messageList.length,
              'grew': dedupedMsgList.length > commitBaseCount,
            },
          );
        }

        if (direction == LoadDirection.previous &&
            dedupedMsgList.length <= commitBaseCount) {
          ChatHistoryTrace.log(
            'load_chat_record_dedupe_no_growth',
            conversationID: model.conversationID,
            extras: <String, Object?>{
              'beforeCount': commitBaseCount,
              'afterCount': dedupedMsgList.length,
              'rawBatchCount': response.messageList.length,
              'isFinished': response.isFinished,
              'haveMoreData': pagination.haveMoreData,
              'lastMsgID': lastMsgID,
              'lastMsgSeq': lastMsgSeq,
            },
          );
          // SDK 无新增（多为到达漫游底部），回退自建后端归档补拉。
          if (!model.usesOfficialSdkHistory) {
            final archiveGrew = await _loadArchiveOlderHistory(count: count);
            if (archiveGrew) {
              return true;
            }
          }
          pagination.haveMoreData = !response.isFinished;
          tempHaveMoreData = pagination.haveMoreData;
          model._notify();
          // 列表未增长时不算成功加载，避免 UI 误判后停止重试。
          return false;
        }

        previousListGrew = dedupedMsgList.length > commitBaseCount;
        if (previousListGrew &&
            HistoryPaginationAnchor.oldestSdkPaginationAnchor(
                  dedupedMsgList,
                ) !=
                null) {
          pagination.suppressArchiveUntilSdkHistory = false;
        }

        var finalList = dedupedMsgList;
        if (direction == LoadDirection.previous && response.isFinished) {
          final archiveBatch = await _fetchArchiveOlderBatch(
            currentList: finalList,
            count: count,
          );
          if (archiveBatch != null && archiveBatch.messages.isNotEmpty) {
            final combined =
                _combineMessageList(finalList, archiveBatch.messages);
            final processed =
                await model.lifeCycle?.didGetHistoricalMessageList(combined) ??
                    combined;
            finalList = model._dedupeMessages(processed);
            pagination.archiveOlderActive = true;
            pagination.archiveOlderExhausted = !archiveBatch.hasMore;
            tempHaveMoreData = archiveBatch.hasMore;
          } else if (archiveBatch != null && !archiveBatch.hasMore) {
            pagination.archiveOlderExhausted = true;
          }
        }
        // Archive fetch/callbacks are asynchronous too. Perform the final
        // compare-and-merge immediately before committing the list.
        final latestBeforeCommit = _aliasAwareInMemoryList(model);
        final stableLatestBeforeCommit = previousPaginationBaseline.isNotEmpty
            ? _mergeHistoryPage(
                existing: previousPaginationBaseline,
                fetched: latestBeforeCommit,
              )
            : latestBeforeCommit;
        finalList = _mergeHistoryPage(
          existing: stableLatestBeforeCommit,
          fetched: finalList,
        );
        previousListGrew = finalList.length > stableLatestBeforeCommit.length;
        if (isPaginatedLoad) {
          _logPreviousPaginationStage(
            model.conversationID,
            stage: 'final_before_set_list',
            extras: <String, Object?>{
              'direction': direction.name,
              'baselineCount': previousPaginationBaseline.length,
              'latestAliasCount': latestBeforeCommit.length,
              'stableLatestCount': stableLatestBeforeCommit.length,
              'finalCount': finalList.length,
              'previousListGrew': previousListGrew,
              'applyMemoryWindow': direction != LoadDirection.previous,
              'isFinished': response.isFinished,
            },
          );
        }
        if (previousPaginationBaseline.isNotEmpty &&
            finalList.length < previousPaginationBaseline.length) {
          _logPreviousPaginationStage(
            model.conversationID,
            stage: 'commit_rejected_shrink',
            extras: <String, Object?>{
              'direction': direction.name,
              'baselineCount': previousPaginationBaseline.length,
              'finalCount': finalList.length,
              'lost': previousPaginationBaseline.length - finalList.length,
              'lastMsgID': lastMsgID,
              'lastMsgSeq': lastMsgSeq,
            },
          );
          if (direction == LoadDirection.latest) {
            pagination.haveMoreLatestData = !response.isFinished;
          } else {
            pagination.haveMoreData = tempHaveMoreData;
          }
          model._notify();
          return false;
        }

        // 已是完整合并列表，replace 避免再与 previous 拼接出重复项；SDK+归档一次写入防双 layout 跳滚。
        if (windowGenAtStart != model._historyWindowGeneration) {
          ChatHistoryTrace.log(
            'load_chat_record_stale_before_commit',
            conversationID: model.conversationID,
            extras: <String, Object?>{
              'direction': direction.name,
              'windowGenAtStart': windowGenAtStart,
              'windowGenNow': model._historyWindowGeneration,
              'finalCount': finalList.length,
            },
          );
          return false;
        }
        final reconciliationCommit =
            model.globalModel.completeHistoryReconciliation(
          request: reconciliationRequest,
          history: finalList,
          actualSource: responseProvenance.actualSource,
          networkState: responseProvenance.networkState,
          // 上翻提交先保留完整窗口，待 UI 完成视口补偿后再按锚点收束。
          // 旧契约要求此处明确区分 previous，搜索定位也因此不会丢目标行。
          applyMemoryWindow: direction != LoadDirection.previous,
          memoryWindowPreferLatest:
              direction == LoadDirection.latest || forceReloadNewest,
          historyCommitSource: direction.name,
          batchKind: direction == LoadDirection.latest
              ? MessageHistoryBatchKind.newerCatchUp
              : MessageHistoryBatchKind.olderPage,
          historyIsFinished: response.isFinished,
          clearEpoch: model.globalModel
                  .messageHistoryCoverageFor(model.conversationID)
                  ?.clearEpoch ??
              0,
          requestedCursor: requestedCursor,
          returnedBounds: returnedBounds,
          cloudResponseProven: responseProvenance.cloudResponseProven,
        );
        if (reconciliationCommit == null) {
          ChatHistoryTrace.log(
            'history_commit_rejected',
            conversationID: model.conversationID,
            extras: <String, Object?>{
              'direction': direction.name,
              'batchKind': MessageHistoryBatchKind.olderPage.name,
              'historyCount': finalList.length,
              'baselineCount': previousPaginationBaseline.length,
              'lastMsgID': lastMsgID,
              'lastMsgSeq': lastMsgSeq,
              'windowGeneration': windowGenAtStart,
              'windowGenerationNow': model._historyWindowGeneration,
            },
          );
          return false;
        }
        reconciliationCommitted = true;
        ChatHistoryTrace.log(
          'history_commit_applied',
          conversationID: model.conversationID,
          extras: <String, Object?>{
            'direction': direction.name,
            'batchKind': MessageHistoryBatchKind.olderPage.name,
            'historyCount': finalList.length,
            'baselineCount': previousPaginationBaseline.length,
            'rawCount': model.globalModel.rawMessageCount(model.conversationID),
            'lastMsgID': lastMsgID,
            'lastMsgSeq': lastMsgSeq,
          },
        );
        // 只有页面真正合并并写入权威列表后，才允许推进官方 SDK 分页游标。
        // 在途请求被窗口替换、去重无增长或提交失败时继续沿用原游标，避免跳页。
        if (useC2cOlderCursor &&
            direction == LoadDirection.previous &&
            previousListGrew) {
          model._rememberC2cSdkOlderPage(response.messageList);
        }
      } else {
        // 处理新获取的消息列表后回调
        List<V2TimMessage> receivedList = await model.lifeCycle
                ?.didGetHistoricalMessageList(response.messageList) ??
            response.messageList;
        model.globalModel.loadingMessage.remove(model.conversationID);

        if (model.conversationType == ConvType.c2c &&
            model.conversationID.startsWith('@TOA#_') &&
            receivedList.isEmpty) {
          final existing = _aliasAwareInMemoryList(model);
          if (existing.isNotEmpty) {
            model._notify();
            pagination.haveMoreData = tempHaveMoreData;
            return pagination.haveMoreData;
          }
        }

        if (receivedList.isEmpty) {
          final existing = _aliasAwareInMemoryList(model);
          if (existing.isNotEmpty) {
            model._notify();
            pagination.haveMoreData = tempHaveMoreData;
            return pagination.haveMoreData;
          }
        }

        // 首屏整表写入前合并拉取期间 upsert 进内存的新消息，避免竞态覆盖。
        final existingInMemory = _aliasAwareInMemoryList(model);
        // 强制回最新窗：丢弃旧窗，直接用最新一页，避免与裁残窗口 merge。
        final mergedList = ChatMainThreadPerf.measure(
          ChatMainThreadPerf.historyMergeMs,
          () => forceReloadNewest
              ? model._dedupeMessages(receivedList)
              : (existingInMemory.isNotEmpty
                  ? _combineMessageList(existingInMemory, receivedList)
                  : model._dedupeMessages(receivedList)),
          count: receivedList.length,
          source: direction.name,
          conversationType: model.conversationType?.name ?? 'none',
        );

        final reconciliationCommit =
            model.globalModel.completeHistoryReconciliation(
          request: reconciliationRequest,
          history: model.usesOfficialSdkHistory ? receivedList : mergedList,
          actualSource: responseProvenance.actualSource,
          networkState: responseProvenance.networkState,
          memoryWindowPreferLatest:
              direction == LoadDirection.latest || forceReloadNewest,
          historyCommitSource: direction.name,
          batchKind: MessageHistoryBatchKind.latestWindow,
          historyIsFinished: response.isFinished,
          clearEpoch: model.globalModel
                  .messageHistoryCoverageFor(model.conversationID)
                  ?.clearEpoch ??
              0,
          requestedCursor: requestedCursor,
          returnedBounds: returnedBounds,
          cloudResponseProven: responseProvenance.cloudResponseProven,
        );
        if (reconciliationCommit == null) {
          ChatHistoryTrace.log(
            'history_commit_rejected',
            conversationID: model.conversationID,
            extras: <String, Object?>{
              'direction': direction.name,
              'batchKind': MessageHistoryBatchKind.latestWindow.name,
              'historyCount': model.usesOfficialSdkHistory
                  ? receivedList.length
                  : mergedList.length,
              'existingCount': existingInMemory.length,
              'lastMsgID': lastMsgID,
              'lastMsgSeq': lastMsgSeq,
              'windowGeneration': windowGenAtStart,
              'windowGenerationNow': model._historyWindowGeneration,
            },
          );
          return false;
        }
        reconciliationCommitted = true;
        ChatHistoryTrace.log(
          'history_commit_applied',
          conversationID: model.conversationID,
          extras: <String, Object?>{
            'direction': direction.name,
            'batchKind': MessageHistoryBatchKind.latestWindow.name,
            'historyCount': model.usesOfficialSdkHistory
                ? receivedList.length
                : mergedList.length,
            'existingCount': existingInMemory.length,
            'rawCount': model.globalModel.rawMessageCount(model.conversationID),
            'lastMsgID': lastMsgID,
            'lastMsgSeq': lastMsgSeq,
          },
        );
        if (forceReloadNewest) {
          model.globalModel.clearMemoryWindowMissingNewer(model.conversationID);
          pagination.haveMoreLatestData = false;
          // 回最新窗是替换而非增长；仍视为成功，供 tongue/回底等待。
          previousListGrew = mergedList.isNotEmpty;
          pagination.haveMoreData = !response.isFinished;
          tempHaveMoreData = pagination.haveMoreData;
        }
        if (mergedList.isNotEmpty &&
            HistoryPaginationAnchor.oldestSdkPaginationAnchor(mergedList) !=
                null) {
          pagination.suppressArchiveUntilSdkHistory = false;
        }
        if (lastMsgID == null && lastMsgSeq <= 0 && mergedList.isNotEmpty) {
          // 首屏请求完成就放开渲染闸门；空结果不在此标记，避免离线登录同步未完成时误判。
          if (mergedList.length >= count || response.isFinished) {
            if (responseProvenance.proofKind ==
                MessageHistoryProofKind.serverContinuity) {
              model.globalModel
                  .markCloudInitialHistoryVerified(model.conversationID);
            } else {
              model.globalModel.markLocalInitialHistoryVisible(
                model.conversationID,
              );
            }
          }
        }
      }

      model._notify();

      unawaited(model._ensureGroupInfoLoaded());

      // 上翻历史时不批量拉已读回执，避免与分页争抢网络；新消息/首屏仍走原有逻辑。
      if (model._canUseReadReceipt &&
          response.messageList.isNotEmpty &&
          direction != LoadDirection.previous) {
        model._getMsgReadReceipt(response.messageList);
      }

      // 根据加载方向更新是否还能继续加载更多消息
      if (direction == LoadDirection.latest && !pagination.haveMoreLatestData) {
        model.globalModel.setMessageListPosition(
            model.conversationID, HistoryMessagePosition.bottom);
        model.globalModel.clearMemoryWindowMissingNewer(model.conversationID);
      }

      if (direction == LoadDirection.previous) {
        pagination.haveMoreData = tempHaveMoreData;
      }
      ChatHistoryTrace.log(
        'load_chat_record_done',
        conversationID: model.conversationID,
        extras: <String, Object?>{
          'direction': direction.name,
          'lastMsgID': lastMsgID,
          'lastMsgSeq': lastMsgSeq,
          'batchCount': response.messageList.length,
          'isFinished': response.isFinished,
          'haveMoreData': pagination.haveMoreData,
          'haveMoreLatestData': pagination.haveMoreLatestData,
          'memoryWindowMissingNewer':
              model.globalModel.memoryWindowMissingNewer(model.conversationID),
          'listLen': model.globalModel.rawMessageCount(model.conversationID),
          'previousListGrew': previousListGrew,
        },
      );
      if (direction == LoadDirection.previous) {
        // 有实际新增才视为 loaded=true，供 UI 做 scroll restore；
        // 不能仅用 pagination.haveMoreData（SDK isFinished 时 pagination.haveMoreData=false 但 batch 已写入）。
        return previousListGrew;
      }
      return pagination.haveMoreLatestData;
    } catch (e) {
      ChatHistoryTrace.log(
        'load_chat_record_error',
        conversationID: model.conversationID,
        extras: <String, Object?>{
          'direction': direction.name,
          'lastMsgID': lastMsgID,
          'lastMsgSeq': lastMsgSeq,
          'error': e.toString(),
        },
      );
      // ignore: avoid_print
      outputLogger.i('loadChatRecord error: $e');
      return false;
    } finally {
      final pendingReconciliation = reconciliationRequest;
      if (pendingReconciliation != null && !reconciliationCommitted) {
        model.globalModel.failHistoryReconciliation(
          request: pendingReconciliation,
          reason: 'history_request_not_committed',
        );
      }
      pagination.historyLoadingKeys.remove(requestKey);
      if (pagination.historyLoadingKeys.isEmpty) {
        model._notify();
      }
      if (isPreviousPagination) {
        pagination.previousPaginationInFlight = false;
      }
    }
  }

  /// 拉取归档一页（不写列表），供 SDK 漫游到底后与 SDK 批次一次 merge。
  Future<ArchiveHistoryResult?> _fetchArchiveOlderBatch({
    required List<V2TimMessage> currentList,
    required int count,
  }) async {
    if (!ArchiveHistoryProvider.isAvailable ||
        pagination.archiveOlderExhausted ||
        pagination.suppressArchiveUntilSdkHistory ||
        ArchiveHistoryProvider.shouldSkipArchiveFallback(
            model.conversationID)) {
      return null;
    }

    final oldest =
        HistoryPaginationAnchor.oldestArchiveCursorAnchor(currentList);
    final int? oldestTs = oldest?.timestamp;
    final int? oldestSeq = int.tryParse(oldest?.seq ?? '');

    ArchiveHistoryResult result;
    try {
      result = await ArchiveHistoryProvider.fetchOlder(
        ArchiveHistoryRequest(
          isGroup: model.conversationType == ConvType.group,
          conversationID: model.conversationID,
          loginUserID: model.selfModel.loginInfo?.userID,
          beforeTimeMs:
              (oldestTs != null && oldestTs > 0) ? oldestTs * 1000 : null,
          beforeSeq: oldestSeq,
          beforeMsgID: oldest?.msgID,
          count: count,
        ),
      );
    } catch (_) {
      return null;
    }

    final afterClear =
        await ArchiveHistoryProvider.filterMessagesAfterHistoryClear(
      conversationID: model.conversationID,
      messages: result.messages,
    );
    final filtered = <V2TimMessage>[];
    for (final m in afterClear) {
      if (oldest == null || _archiveMessageStrictlyOlder(m, oldest)) {
        filtered.add(m);
      }
    }
    if (filtered.isEmpty) {
      return ArchiveHistoryResult(messages: const [], hasMore: result.hasMore);
    }
    return ArchiveHistoryResult(messages: filtered, hasMore: result.hasMore);
  }

  /// IM SDK（本地 + 云端漫游）已无更早消息时，回退到自建后端归档补拉。
  ///
  /// 只保留比当前列表最老一条更早的消息，避免与实时/SDK 段重叠；拉到内容返回
  /// true 并按后端 hasMore 更新 [pagination.haveMoreData]，否则标记归档已到底。
  Future<bool> _loadArchiveOlderHistory({required int count}) async {
    if (model.usesOfficialSdkHistory) {
      return false;
    }
    if (!ArchiveHistoryProvider.isAvailable ||
        pagination.archiveOlderExhausted ||
        pagination.suppressArchiveUntilSdkHistory ||
        ArchiveHistoryProvider.shouldSkipArchiveFallback(
            model.conversationID)) {
      if (pagination.suppressArchiveUntilSdkHistory) {
        ChatHistoryTrace.log(
          'archive_older_suppressed',
          conversationID: model.conversationID,
          extras: const <String, Object?>{'reason': 'await_sdk_history'},
        );
        pagination.haveMoreData = false;
      }
      return false;
    }
    final bool isGroup = model.conversationType == ConvType.group;
    final current = _aliasAwareInMemoryList(model);
    // 跳过 ce_* 等本地注入；否则会用错误的旧时间戳跳档造成空洞。
    final V2TimMessage? oldest =
        HistoryPaginationAnchor.oldestArchiveCursorAnchor(current);
    final int? oldestTs = oldest?.timestamp;
    final int? oldestSeq = int.tryParse(oldest?.seq ?? '');
    ChatHistoryTrace.log(
      'archive_older_cursor',
      conversationID: model.conversationID,
      extras: <String, Object?>{
        'cursorMsgID': oldest?.msgID,
        'cursorTs': oldestTs,
        'cursorSeq': oldestSeq,
        'listLen': current.length,
        'listTailMsgID': current.isNotEmpty ? current.last.msgID : '',
      },
    );

    ArchiveHistoryResult result;
    try {
      result = await ArchiveHistoryProvider.fetchOlder(
        ArchiveHistoryRequest(
          isGroup: isGroup,
          conversationID: model.conversationID,
          loginUserID: model.selfModel.loginInfo?.userID,
          beforeTimeMs:
              (oldestTs != null && oldestTs > 0) ? oldestTs * 1000 : null,
          beforeSeq: oldestSeq,
          beforeMsgID: oldest?.msgID,
          count: count,
        ),
      );
    } catch (e) {
      ChatHistoryTrace.log(
        'archive_older_error',
        conversationID: model.conversationID,
        extras: <String, Object?>{'error': e.toString()},
      );
      return false;
    }

    // 清空聊天记录边界：分页补拉不允许把已清空的旧归档带回列表
    //（首屏 peek 路径有同样过滤，此处缺失会导致进页自动分页 3→62、
    // 随后 hydrate 又剥回 3 的「顶部转圈闪现 + 列表塌缩」循环）。
    final afterClear =
        await ArchiveHistoryProvider.filterMessagesAfterHistoryClear(
      conversationID: model.conversationID,
      messages: result.messages,
    );
    if (afterClear.length != result.messages.length) {
      ChatHistoryTrace.log(
        'archive_older_history_clear_filtered',
        conversationID: model.conversationID,
        extras: <String, Object?>{
          'rawBatchCount': result.messages.length,
          'keptCount': afterClear.length,
        },
      );
    }

    // 严格过滤：只保留比当前最老更早的，双保险防止与已展示区间重叠。
    final filtered = <V2TimMessage>[];
    for (final m in afterClear) {
      if (oldest == null || _archiveMessageStrictlyOlder(m, oldest)) {
        filtered.add(m);
      }
    }

    if (filtered.isEmpty) {
      pagination.archiveOlderExhausted = true;
      pagination.haveMoreData = false;
      ChatHistoryTrace.log(
        'archive_older_empty',
        conversationID: model.conversationID,
        extras: <String, Object?>{
          'rawBatchCount': result.messages.length,
          'hasMore': result.hasMore,
        },
      );
      model._notify();
      return false;
    }

    final existing = _aliasAwareInMemoryList(model);
    final beforeLen = existing.length;
    final combined = existing.isNotEmpty
        ? _combineMessageList(List<V2TimMessage>.from(existing), filtered)
        : model._dedupeMessages(filtered);
    final processed =
        await model.lifeCycle?.didGetHistoricalMessageList(combined) ??
            combined;
    final deduped = model._dedupeMessages(processed);
    if (deduped.length <= beforeLen) {
      ChatHistoryTrace.log(
        'archive_older_no_growth',
        conversationID: model.conversationID,
        extras: <String, Object?>{
          'beforeLen': beforeLen,
          'afterLen': deduped.length,
          'rawBatchCount': filtered.length,
          'hasMore': result.hasMore,
        },
      );
      if (!result.hasMore) {
        pagination.archiveOlderExhausted = true;
        pagination.haveMoreData = false;
      }
      model._notify();
      return false;
    }
    model.globalModel.setMessageList(
      model.conversationID,
      deduped,
      needResetNewMessageCount: false,
    );
    model.globalModel.markInitialHistoryLoaded(model.conversationID);
    pagination.haveMoreData = result.hasMore;
    pagination.archiveOlderExhausted = !result.hasMore;
    pagination.archiveOlderActive = true;
    model._notify();
    ChatHistoryTrace.log(
      'archive_older_done',
      conversationID: model.conversationID,
      extras: <String, Object?>{
        'batchCount': filtered.length,
        'hasMore': result.hasMore,
        'listLen': model.globalModel.rawMessageCount(model.conversationID),
      },
    );
    return true;
  }

  bool _archiveMessageStrictlyOlder(V2TimMessage m, V2TimMessage oldest) {
    final mSeq = int.tryParse(m.seq ?? '');
    final oSeq = int.tryParse(oldest.seq ?? '');
    if (mSeq != null && oSeq != null && mSeq > 0 && oSeq > 0) {
      return mSeq < oSeq;
    }
    final mt = m.timestamp ?? 0;
    final ot = oldest.timestamp ?? 0;
    return mt < ot;
  }

  // 拼接聊天记录
  List<V2TimMessage> _mergeHistoryPage({
    required List<V2TimMessage> existing,
    required List<V2TimMessage> fetched,
  }) {
    if (model.usesOfficialSdkHistory) {
      return TUIChatGlobalModel.mergeC2cOfficialOlderPage(
        existing: existing,
        fetched: fetched,
      );
    }
    return TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: existing,
      fetched: fetched,
    );
  }

  List<V2TimMessage> _combineMessageList(
      List<V2TimMessage> first, List<V2TimMessage> second) {
    return TUIChatGlobalModel.sortMessagesNewestFirst(
      model._dedupeMessages([...first, ...second]),
    );
  }

  /// 本地仍有未拉取的历史页时，跳过云端探测以减少一次 SDK 往返。
  bool _shouldUseLocalOlderHistoryOnly(V2TimMessageListResult? localResponse) {
    if (localResponse == null || localResponse.messageList.isEmpty) {
      return false;
    }
    return !localResponse.isFinished;
  }
}

List<V2TimMessage> _aliasAwareInMemoryList(TUIChatSeparateViewModel model) {
  return model.globalModel.mergedAliasMessageList(model.conversationID);
}

void _logPreviousPaginationStage(
  String conversationID, {
  required String stage,
  Map<String, Object?> extras = const <String, Object?>{},
}) {
  ChatHistoryTrace.log(
    'load_previous_$stage',
    conversationID: conversationID,
    extras: extras,
  );
  ChatJitterDiag.log(
    'history_pagination',
    conv: conversationID,
    extras: <String, Object?>{'stage': stage, ...extras},
  );
}
