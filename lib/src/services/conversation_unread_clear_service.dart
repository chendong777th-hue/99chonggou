import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_unread_trace.dart';
import 'package:tencent_cloud_chat_demo/src/services/web_read_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

enum SdkUnreadCleanTrigger { open, chatVisible, leave }

/// 编辑态「全部已读 / 选中已读」模式。
enum MarkReadEditMode { selected, scopeAll, archivedAll }

/// 与会话列表 Tab 对齐的清未读 scope（避免 ClearService 依赖 UI 文件）。
enum MarkReadListScope { all, c2c, group }

/// [ConversationUnreadClearService.markReadForEditAction] 结果。
class MarkReadEditResult {
  const MarkReadEditResult({
    required this.conversationCount,
    required this.unreadSumBefore,
    required this.sdkPath,
    required this.durationMs,
  });

  final int conversationCount;
  final int unreadSumBefore;
  final String sdkPath; // type | queue | none
  final int durationMs;

  bool get isEmpty => conversationCount <= 0;
}

/// 多选全选且类型单一时，走 SDK `"c2c"` / `"group"` 一次清类型未读。
class TypeBulkCleanDecision {
  const TypeBulkCleanDecision({required this.isGroup});

  final bool isGroup;
}

/// 会话未读清零：进聊天、离开聊天共用，含 SDK 重试。
class ConversationUnreadClearService {
  ConversationUnreadClearService._();

  static const openSdkRetryDelays = <Duration>[
    Duration.zero,
    Duration(milliseconds: 300),
    Duration(milliseconds: 800),
  ];

  static const leaveSdkRetryDelays = <Duration>[
    Duration.zero,
    Duration(milliseconds: 600),
    Duration(milliseconds: 1500),
  ];

  static const sdkCleanTypeC2c = 'c2c';
  static const sdkCleanTypeGroup = 'group';

  static const _sdkCleanMinInterval = Duration(seconds: 5);
  static const _frequencyBlockBackoff = Duration(seconds: 12);
  static const _leaveSkipAfterSuccess = Duration(seconds: 3);
  static const int _sdkFrequencyBlockCode = -10113;
  static const Duration _defaultQueuedSdkCleanInterval =
      Duration(milliseconds: 400);

  /// 未读合计达到该阈值时，UI 应二次确认。
  static const int confirmUnreadSumThreshold = 200;

  /// 归档等逐条 SDK 入队上限，避免万级排队。
  static const int sdkQueueCap = 500;

  static final Map<String, Future<void>> _sdkCleanInFlight =
      <String, Future<void>>{};
  static final Map<String, DateTime> _frequencyBlockUntil =
      <String, DateTime>{};
  static final Map<String, DateTime> _lastSuccessfulSdkClean =
      <String, DateTime>{};
  static final Set<String> _leaveFinalizedSessionIds = <String>{};

  static Future<void> _queueTail = Future<void>.value();
  static DateTime? _lastQueuedSdkCleanAt;

  @visibleForTesting
  static Future<V2TimCallback> Function(String conversationID)?
      sdkCleanOverride;

  @visibleForTesting
  static Duration queuedSdkCleanInterval = _defaultQueuedSdkCleanInterval;

  @visibleForTesting
  static void resetCoordinatorStateForTesting() {
    _sdkCleanInFlight.clear();
    _frequencyBlockUntil.clear();
    _lastSuccessfulSdkClean.clear();
    _leaveFinalizedSessionIds.clear();
    sdkCleanOverride = null;
    _queueTail = Future<void>.value();
    _lastQueuedSdkCleanAt = null;
    queuedSdkCleanInterval = _defaultQueuedSdkCleanInterval;
  }

  /// 与会话列表 scope 判定一致：群会话 type==2 或 groupID 非空。
  static bool isGroupConversation(V2TimConversation conversation) {
    final groupID = conversation.groupID?.trim() ?? '';
    return conversation.type == 2 || groupID.isNotEmpty;
  }

  /// 可见列表全部勾选且类型单一 → bulk；否则 null（走逐条限速）。
  static TypeBulkCleanDecision? shouldUseTypeBulkClean({
    required List<V2TimConversation> visible,
    required Set<String> selectedIds,
  }) {
    if (visible.isEmpty) {
      return null;
    }
    for (final conversation in visible) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty || !selectedIds.contains(id)) {
        return null;
      }
    }
    bool? isGroup;
    for (final conversation in visible) {
      final group = isGroupConversation(conversation);
      if (isGroup == null) {
        isGroup = group;
      } else if (isGroup != group) {
        return null;
      }
    }
    if (isGroup == null) {
      return null;
    }
    return TypeBulkCleanDecision(isGroup: isGroup);
  }

  static MarkReadLocalScope _toStoreScope(MarkReadListScope scope) {
    switch (scope) {
      case MarkReadListScope.all:
        return MarkReadLocalScope.all;
      case MarkReadListScope.c2c:
        return MarkReadLocalScope.c2c;
      case MarkReadListScope.group:
        return MarkReadLocalScope.group;
    }
  }

  /// 确认框预估：不写库。
  static Future<MarkReadBatchResult> previewMarkReadForEditAction({
    required MarkReadEditMode mode,
    required MarkReadListScope listScope,
    Set<String> selectedIds = const <String>{},
    Set<String> archivedIds = const <String>{},
  }) {
    switch (mode) {
      case MarkReadEditMode.selected:
        return ConversationLocalStore.instance.previewUnreadForMarkRead(
          conversationIds: selectedIds,
        );
      case MarkReadEditMode.archivedAll:
        return ConversationLocalStore.instance.previewUnreadForMarkRead(
          conversationIds: archivedIds,
          scope: listScope == MarkReadListScope.all
              ? null
              : _toStoreScope(listScope),
        );
      case MarkReadEditMode.scopeAll:
        return ConversationLocalStore.instance.previewUnreadForMarkRead(
          scope: _toStoreScope(listScope),
          excludeConversationIds: archivedIds,
        );
    }
  }

  /// 编辑态统一入口：批量本地清未读 + 按策略清 SDK。
  static Future<MarkReadEditResult> markReadForEditAction({
    required MarkReadEditMode mode,
    required MarkReadListScope listScope,
    Set<String> selectedIds = const <String>{},
    Set<String> archivedIds = const <String>{},
    void Function(String conversationID)? markViewModelReadLocally,
  }) async {
    final started = DateTime.now();
    late final MarkReadBatchResult local;
    switch (mode) {
      case MarkReadEditMode.selected:
        local = await ConversationLocalStore.instance
            .markConversationsReadLocallyBatch(selectedIds);
        break;
      case MarkReadEditMode.archivedAll:
        local = await ConversationLocalStore.instance
            .markConversationsReadLocallyBatch(
          archivedIds,
          scope: listScope == MarkReadListScope.all
              ? null
              : _toStoreScope(listScope),
        );
        break;
      case MarkReadEditMode.scopeAll:
        local = await ConversationLocalStore.instance.markAllUnreadReadLocally(
          scope: _toStoreScope(listScope),
          excludeConversationIds: archivedIds,
        );
        break;
    }

    ConversationListNotifier.instance.zeroUnreadLocallyMany(
      local.clearedIds,
      forceAggregateRefresh: true,
    );
    for (final id in local.clearedIds) {
      markViewModelReadLocally?.call(id);
    }

    var sdkPath = 'none';
    if (local.clearedIds.isNotEmpty) {
      if (mode == MarkReadEditMode.selected ||
          mode == MarkReadEditMode.archivedAll) {
        sdkPath = 'queue';
        final queueIds = local.clearedIds.length > sdkQueueCap
            ? local.clearedIds.take(sdkQueueCap)
            : local.clearedIds;
        for (final id in queueIds) {
          unawaited(enqueueSdkUnreadClean(id, hadUnread: true));
        }
      } else {
        // scopeAll：按 Tab 走类型 bulk（真·全部），禁止误用「可见全选」旧判定。
        sdkPath = 'type';
        switch (listScope) {
          case MarkReadListScope.c2c:
            unawaited(
              cleanSdkUnreadForType(
                isGroup: false,
                markViewModelReadLocally: markViewModelReadLocally,
                markLocalAllOnSuccess: false,
              ),
            );
            break;
          case MarkReadListScope.group:
            unawaited(
              cleanSdkUnreadForType(
                isGroup: true,
                markViewModelReadLocally: markViewModelReadLocally,
                markLocalAllOnSuccess: false,
              ),
            );
            break;
          case MarkReadListScope.all:
            unawaited(() async {
              await cleanSdkUnreadForType(
                isGroup: false,
                markViewModelReadLocally: markViewModelReadLocally,
                markLocalAllOnSuccess: false,
              );
              await cleanSdkUnreadForType(
                isGroup: true,
                markViewModelReadLocally: markViewModelReadLocally,
                markLocalAllOnSuccess: false,
              );
            }());
            break;
        }
      }
    }

    final durationMs = DateTime.now().difference(started).inMilliseconds;
    MarkSelectedReadLog.log('mark_read_edit_done', {
      'mode': mode.name,
      'listScope': listScope.name,
      'localCleared': local.conversationCount,
      'unreadSum': local.unreadSumBefore,
      'sdkPath': sdkPath,
      'durationMs': durationMs,
      'clearedIds': MarkSelectedReadLog.summarizeIds(local.clearedIds),
    });
    return MarkReadEditResult(
      conversationCount: local.conversationCount,
      unreadSumBefore: local.unreadSumBefore,
      sdkPath: sdkPath,
      durationMs: durationMs,
    );
  }

  /// 新开聊天会话时调用，允许该会话在离开时执行一次 finalize。
  static void beginConversationChatSession(String conversationID) {
    final id = conversationID.trim();
    if (id.isNotEmpty) {
      _leaveFinalizedSessionIds.remove(id);
    }
  }

  /// 离开聊天的唯一写库入口（幂等）：未读清零、已读锚点、本地持久化、可选 SDK 清未读。
  static Future<void> finalizeConversationLeaveOnce({
    required String conversationID,
    String? lastMessageId,
    int entryUnreadCount = 0,
    void Function(String conversationID)? markViewModelReadLocally,
    bool scheduleSdkUnreadCleanOnLeave = true,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    if (!_leaveFinalizedSessionIds.add(id)) {
      ConversationUnreadTrace.log(
        'finalize_leave_skip',
        conversationID: id,
        extras: <String, Object?>{'reason': 'already_finalized'},
      );
      return;
    }
    ConversationUnreadTrace.log(
      'finalize_leave_start',
      conversationID: id,
      extras: <String, Object?>{'entryUnreadCount': entryUnreadCount},
    );
    ConversationListNotifier.instance.zeroUnreadLocally(id);
    ConversationLocalStore.instance.recordReadClearedAnchor(
      id,
      lastMessageId: lastMessageId,
    );
    await ConversationSyncService.instance.markConversationReadLocally(id);
    markViewModelReadLocally?.call(id);
    if (scheduleSdkUnreadCleanOnLeave) {
      unawaited(
        scheduleSdkUnreadClean(
          conversationID: id,
          trigger: SdkUnreadCleanTrigger.leave,
          hadUnread: entryUnreadCount > 0,
        ),
      );
    }
    ConversationUnreadTrace.log(
      'finalize_leave_done',
      conversationID: id,
      unreadAfter: 0,
    );
  }

  /// 进聊天前快速清零未读：同步更新内存与 ViewModel，持久化后台执行，不阻塞导航。
  static void clearLocalForOpenFast({
    required V2TimConversation conversation,
    void Function(String conversationID)? markViewModelReadLocally,
  }) {
    final conversationID = conversation.conversationID.trim();
    if (conversationID.isEmpty) {
      return;
    }
    final unreadBefore = conversation.unreadCount ?? 0;
    beginConversationChatSession(conversationID);
    ConversationListNotifier.instance.zeroUnreadLocally(conversationID);
    conversation.unreadCount = 0;
    ConversationLocalStore.instance.recordReadClearedAnchor(
      conversationID,
      lastMessageId: conversation.lastMessage?.msgID,
    );
    markViewModelReadLocally?.call(conversationID);
    ConversationUnreadTrace.log(
      'clear_local_open_fast',
      conversationID: conversationID,
      unreadBefore: unreadBefore,
      unreadAfter: 0,
    );
    unawaited(
      ConversationSyncService.instance.markConversationReadLocally(
        conversationID,
        forceImmediateUi: true,
      ),
    );
  }

  /// 进聊天前清零未读：仅写本地已读锚点，不阻塞导航等待 SDK。
  static Future<void> clearLocalForOpen({
    required V2TimConversation conversation,
    void Function(String conversationID)? markViewModelReadLocally,
  }) async {
    final conversationID = conversation.conversationID.trim();
    if (conversationID.isEmpty) {
      return;
    }
    ConversationListNotifier.instance.zeroUnreadLocally(conversationID);
    conversation.unreadCount = 0;
    ConversationLocalStore.instance.recordReadClearedAnchor(
      conversationID,
      lastMessageId: conversation.lastMessage?.msgID,
    );
    await ConversationSyncService.instance.markConversationReadLocally(
      conversationID,
      forceImmediateUi: true,
    );
    markViewModelReadLocally?.call(conversationID);
  }

  /// 进聊天后异步清 SDK 未读。
  static Future<void> clearSdkUnreadAsync({
    required String conversationID,
    bool hadUnread = true,
  }) {
    return scheduleSdkUnreadClean(
      conversationID: conversationID,
      trigger: SdkUnreadCleanTrigger.open,
      hadUnread: hadUnread,
    );
  }

  /// 多选全选：一次清理全部单聊或全部群聊 SDK 未读；成功后本地同类型一并清零。
  static Future<void> cleanSdkUnreadForType({
    required bool isGroup,
    void Function(String conversationID)? markViewModelReadLocally,
    bool markLocalAllOnSuccess = true,
  }) async {
    final typeId = isGroup ? sdkCleanTypeGroup : sdkCleanTypeC2c;
    MarkSelectedReadLog.log('sdk_type_clean_begin', {
      'typeId': typeId,
      'isGroup': isGroup,
      'isWeb': kIsWeb,
      'markLocalAllOnSuccess': markLocalAllOnSuccess,
    });
    if (kIsWeb) {
      ConversationUnreadTrace.log(
        'sdk_clean_type_skip',
        conversationID: typeId,
        extras: <String, Object?>{'reason': 'web'},
      );
      MarkSelectedReadLog.log('sdk_type_clean_skip_web', {'typeId': typeId});
      return;
    }
    ConversationUnreadTrace.log(
      'sdk_clean_type_start',
      conversationID: typeId,
      extras: <String, Object?>{'isGroup': isGroup},
    );
    final lastCode = await _cleanSdkWithRetry(
      typeId,
      delays: openSdkRetryDelays,
      breakOnSuccess: true,
    );
    if (lastCode == 0) {
      _lastSuccessfulSdkClean[typeId] = DateTime.now();
      if (markLocalAllOnSuccess) {
        MarkSelectedReadLog.log('sdk_type_clean_ok_mark_local_all', {
          'typeId': typeId,
          'isGroup': isGroup,
        });
        await markAllLocalConversationsReadByType(
          isGroup: isGroup,
          markViewModelReadLocally: markViewModelReadLocally,
        );
      } else {
        MarkSelectedReadLog.log('sdk_type_clean_ok_skip_local', {
          'typeId': typeId,
          'isGroup': isGroup,
        });
      }
    } else {
      MarkSelectedReadLog.log('sdk_type_clean_failed', {
        'typeId': typeId,
        'sdkCode': lastCode,
        'isGroup': isGroup,
      });
    }
    ConversationUnreadTrace.log(
      'sdk_clean_type_done',
      conversationID: typeId,
      extras: <String, Object?>{'sdkCode': lastCode, 'isGroup': isGroup},
    );
    MarkSelectedReadLog.log('sdk_type_clean_end', {
      'typeId': typeId,
      'sdkCode': lastCode,
      'isGroup': isGroup,
    });
  }

  /// Bulk 成功后：本地同类型会话全部写已读（含归档/不可见）。
  static Future<void> markAllLocalConversationsReadByType({
    required bool isGroup,
    void Function(String conversationID)? markViewModelReadLocally,
  }) async {
    final result = await ConversationLocalStore.instance.markAllUnreadReadLocally(
      scope: isGroup ? MarkReadLocalScope.group : MarkReadLocalScope.c2c,
    );
    ConversationListNotifier.instance.zeroUnreadLocallyMany(
      result.clearedIds,
      forceAggregateRefresh: true,
    );
    for (final id in result.clearedIds) {
      markViewModelReadLocally?.call(id);
    }
    MarkSelectedReadLog.log('mark_all_local_by_type_batch', {
      'isGroup': isGroup,
      'cleared': result.conversationCount,
      'unreadSum': result.unreadSumBefore,
    });
  }

  /// 多选非全选：跨会话串行清 SDK 未读，间隔限速，撞频控则等到 block 结束再继续。
  static Future<void> enqueueSdkUnreadClean(
    String conversationID, {
    bool hadUnread = true,
  }) {
    final id = conversationID.trim();
    if (id.isEmpty || !hadUnread) {
      MarkSelectedReadLog.log('queue_skip', {
        'conv': id,
        'hadUnread': hadUnread,
        'reason': id.isEmpty ? 'empty_id' : 'no_unread',
      });
      return Future<void>.value();
    }
    if (kIsWeb) {
      MarkSelectedReadLog.log('queue_skip', {
        'conv': id,
        'reason': 'web',
      });
      return Future<void>.value();
    }
    MarkSelectedReadLog.log('queue_enqueue', {
      'conv': id,
      'intervalMs': queuedSdkCleanInterval.inMilliseconds,
    });
    final previous = _queueTail;
    final task = previous.then((_) => _runQueuedSdkUnreadClean(id));
    _queueTail = task.catchError((Object _) {});
    return task;
  }

  static Future<void> _runQueuedSdkUnreadClean(String conversationID) async {
    final lastAt = _lastQueuedSdkCleanAt;
    if (lastAt != null) {
      final elapsed = DateTime.now().difference(lastAt);
      final wait = queuedSdkCleanInterval - elapsed;
      if (wait > Duration.zero) {
        MarkSelectedReadLog.log('queue_rate_wait', {
          'conv': conversationID,
          'waitMs': wait.inMilliseconds,
        });
        await Future<void>.delayed(wait);
      }
    }

    final blockUntil = _frequencyBlockUntil[conversationID];
    if (blockUntil != null) {
      final remaining = blockUntil.difference(DateTime.now());
      if (remaining > Duration.zero) {
        ConversationUnreadTrace.log(
          'sdk_clean_queue_wait_frequency_block',
          conversationID: conversationID,
          extras: <String, Object?>{'waitMs': remaining.inMilliseconds},
        );
        MarkSelectedReadLog.log('queue_freq_block_wait', {
          'conv': conversationID,
          'waitMs': remaining.inMilliseconds,
        });
        await Future<void>.delayed(remaining);
      }
    }

    MarkSelectedReadLog.log('queue_run_sdk_clean', {'conv': conversationID});
    _lastQueuedSdkCleanAt = DateTime.now();
    await scheduleSdkUnreadClean(
      conversationID: conversationID,
      trigger: SdkUnreadCleanTrigger.open,
      hadUnread: true,
    );
    MarkSelectedReadLog.log('queue_run_sdk_clean_done', {
      'conv': conversationID,
    });
  }

  /// 协调同一会话的 SDK 清未读：去重、频控退避、leave 兜底。
  static Future<void> scheduleSdkUnreadClean({
    required String conversationID,
    required SdkUnreadCleanTrigger trigger,
    bool hadUnread = true,
  }) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return Future<void>.value();
    }
    if (kIsWeb) {
      return Future<void>.value();
    }
    if (!hadUnread && !_lastSuccessfulSdkClean.containsKey(id)) {
      ConversationUnreadTrace.log(
        'sdk_clean_skip',
        conversationID: id,
        extras: <String, Object?>{
          'trigger': trigger.name,
          'reason': 'no_had_unread'
        },
      );
      return Future<void>.value();
    }

    final now = DateTime.now();
    final blockUntil = _frequencyBlockUntil[id];
    if (blockUntil != null && now.isBefore(blockUntil)) {
      final inFlight = _sdkCleanInFlight[id];
      if (inFlight != null) {
        ConversationUnreadTrace.log(
          'sdk_clean_join_inflight',
          conversationID: id,
          extras: <String, Object?>{
            'trigger': trigger.name,
            'reason': 'frequency_block'
          },
        );
        return inFlight;
      }
      ConversationUnreadTrace.log(
        'sdk_clean_skip',
        conversationID: id,
        extras: <String, Object?>{
          'trigger': trigger.name,
          'reason': 'frequency_block'
        },
      );
      return Future<void>.value();
    }

    final inFlight = _sdkCleanInFlight[id];
    if (inFlight != null) {
      ConversationUnreadTrace.log(
        'sdk_clean_join_inflight',
        conversationID: id,
        extras: <String, Object?>{'trigger': trigger.name},
      );
      return inFlight;
    }

    if (trigger == SdkUnreadCleanTrigger.leave) {
      final lastSuccess = _lastSuccessfulSdkClean[id];
      if (lastSuccess != null &&
          now.difference(lastSuccess) < _leaveSkipAfterSuccess) {
        ConversationUnreadTrace.log(
          'sdk_clean_skip',
          conversationID: id,
          extras: <String, Object?>{
            'trigger': trigger.name,
            'reason': 'recent_success',
          },
        );
        return Future<void>.value();
      }
    }

    if (trigger == SdkUnreadCleanTrigger.chatVisible) {
      final lastSuccess = _lastSuccessfulSdkClean[id];
      if (lastSuccess != null &&
          now.difference(lastSuccess) < _sdkCleanMinInterval) {
        ConversationUnreadTrace.log(
          'sdk_clean_skip',
          conversationID: id,
          extras: <String, Object?>{
            'trigger': trigger.name,
            'reason': 'min_interval',
          },
        );
        return Future<void>.value();
      }
    }

    ConversationUnreadTrace.log(
      'sdk_clean_start',
      conversationID: id,
      extras: <String, Object?>{
        'trigger': trigger.name,
        'hadUnread': hadUnread
      },
    );

    final delays = trigger == SdkUnreadCleanTrigger.leave
        ? leaveSdkRetryDelays
        : openSdkRetryDelays;
    final task = _runSdkClean(
      id,
      delays: delays,
      // SDK success is authoritative for the current unread state. Retrying a
      // successful leave clean can incorrectly consume messages that arrive
      // after the user has left and also multiplies group read reports.
      breakOnSuccess: true,
    );
    _sdkCleanInFlight[id] = task;
    return task.whenComplete(() {
      if (identical(_sdkCleanInFlight[id], task)) {
        _sdkCleanInFlight.remove(id);
      }
    });
  }

  static Future<void> _runSdkClean(
    String conversationID, {
    required List<Duration> delays,
    required bool breakOnSuccess,
  }) async {
    final lastCode = await _cleanSdkWithRetry(
      conversationID,
      delays: delays,
      breakOnSuccess: breakOnSuccess,
    );
    if (lastCode == 0) {
      _lastSuccessfulSdkClean[conversationID] = DateTime.now();
    }
    ConversationUnreadTrace.log(
      'sdk_clean_done',
      conversationID: conversationID,
      extras: <String, Object?>{'sdkCode': lastCode},
    );
  }

  /// 兼容旧调用：本地 + SDK 同步清未读。
  static Future<void> clearForOpen({
    required V2TimConversation conversation,
    void Function(String conversationID)? markViewModelReadLocally,
  }) async {
    final unreadCount = conversation.unreadCount ?? 0;
    await clearLocalForOpen(
      conversation: conversation,
      markViewModelReadLocally: markViewModelReadLocally,
    );
    if (unreadCount <= 0) {
      return;
    }
    if (kIsWeb) {
      await WebReadService.instance.markConversationRead(conversation);
      return;
    }
    await scheduleSdkUnreadClean(
      conversationID: conversation.conversationID,
      trigger: SdkUnreadCleanTrigger.open,
      hadUnread: true,
    );
  }

  /// 离开聊天：仅刷新本地已读锚点，不触发 SDK 清未读。
  static Future<void> clearLocalOnLeave({
    required String conversationID,
    void Function(String conversationID)? markViewModelReadLocally,
  }) async {
    await finalizeConversationLeaveOnce(
      conversationID: conversationID,
      markViewModelReadLocally: markViewModelReadLocally,
      scheduleSdkUnreadCleanOnLeave: false,
    );
  }

  static Future<int> _cleanSdkWithRetry(
    String conversationID, {
    required List<Duration> delays,
    required bool breakOnSuccess,
  }) async {
    var lastCode = 1;
    var attempt = 0;
    for (final delay in delays) {
      attempt++;
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      try {
        MarkSelectedReadLog.log('sdk_clean_attempt', {
          'conv': conversationID,
          'attempt': attempt,
          'delayMs': delay.inMilliseconds,
        });
        final result = await _invokeSdkClean(conversationID);
        lastCode = result.code;
        MarkSelectedReadLog.log('sdk_clean_attempt_result', {
          'conv': conversationID,
          'attempt': attempt,
          'sdkCode': result.code,
          'sdkDesc': result.desc,
        });
        if (result.code == _sdkFrequencyBlockCode) {
          _frequencyBlockUntil[conversationID] =
              DateTime.now().add(_frequencyBlockBackoff);
          ConversationUnreadTrace.log(
            'sdk_clean_frequency_block',
            conversationID: conversationID,
            extras: <String, Object?>{
              'sdkCode': result.code,
              'sdkDesc': result.desc
            },
          );
          MarkSelectedReadLog.log('sdk_clean_freq_block', {
            'conv': conversationID,
            'backoffSec': _frequencyBlockBackoff.inSeconds,
            'sdkDesc': result.desc,
          });
          break;
        }
        if (shouldStopSdkRetry(
          breakOnSuccess: breakOnSuccess,
          resultCode: result.code,
        )) {
          break;
        }
      } catch (e) {
        debugPrint('cleanConversationUnread failed: $conversationID $e');
        MarkSelectedReadLog.log('sdk_clean_attempt_exception', {
          'conv': conversationID,
          'attempt': attempt,
          'error': '$e',
        });
      }
    }
    return lastCode;
  }

  static Future<V2TimCallback> _invokeSdkClean(String conversationID) {
    final override = sdkCleanOverride;
    if (override != null) {
      return override(conversationID);
    }
    if (conversationID.startsWith('group_') && conversationID.length > 6) {
      return serviceLocator<MessageService>().markGroupMessageAsRead(
        groupID: conversationID.substring(6),
      );
    }
    return TencentImSDKPlugin.v2TIMManager
        .getConversationManager()
        .cleanConversationUnreadMessageCount(
          conversationID: conversationID,
          cleanTimestamp: 0,
          cleanSequence: 0,
        );
  }

  @visibleForTesting
  static bool shouldStopSdkRetry({
    required bool breakOnSuccess,
    required int resultCode,
  }) {
    return breakOnSuccess && resultCode == 0;
  }
}
