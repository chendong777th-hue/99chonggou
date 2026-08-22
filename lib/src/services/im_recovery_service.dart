import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_failed_message_retry_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_recovery_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_pending_recovery_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_connect_status_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/resume_foreground_policy.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

class ImRecoveryService {
  ImRecoveryService._();

  static final ImRecoveryService instance = ImRecoveryService._();

  Future<void>? _globalTask;
  DateTime? _lastGlobalRunAt;
  static const Duration _defaultGlobalMinInterval = Duration(seconds: 12);
  static const Duration _resumeGlobalMinInterval = Duration(seconds: 3);
  static const Duration _defaultHold = Duration(milliseconds: 600);

  Future<void> afterOnline({
    String reason = 'online',
    ResumeIntensity intensity = ResumeIntensity.full,
  }) {
    final now = DateTime.now();
    final last = _lastGlobalRunAt;
    final minInterval = reason == 'app_resumed'
        ? _resumeGlobalMinInterval
        : _defaultGlobalMinInterval;
    if (last != null && now.difference(last) < minInterval) {
      return _globalTask ?? Future<void>.value();
    }
    _lastGlobalRunAt = now;

    late final Future<void> trackedTask;
    trackedTask = _runGlobalRecovery(reason: reason, intensity: intensity)
        .whenComplete(() {
      if (identical(_globalTask, trackedTask)) {
        _globalTask = null;
      }
    });
    _globalTask = trackedTask;
    return trackedTask;
  }

  Future<void> afterChatOpened({
    required String conversationID,
    ConvType? conversationType,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) return;
    final convType = conversationType ?? _resolveConversationType(id);
    // 已发送失败的消息保持红色感叹号，由用户手动点重发；
    // 进会话不再自动 reSend（否则会反复变成发送中）。
    await ChatFailedMessageRetryService.instance.settleStuckSendingAsFailed(
      conversationID: MessageConversationId.normalizeComparableKey(id),
      conversationType: convType,
    );
    ConversationRefreshBus.instance.requestRefresh(reason: 'chat_recovery');
  }

  Future<void> refreshForegroundChatIfNeeded({
    String reason = 'app_resumed',
  }) async {
    try {
      final rawId = ActiveChatRegistry.instance.activeConversationId ?? '';
      if (rawId.isEmpty) {
        return;
      }
      final conversationId = _resolveForegroundConversationId(rawId);
      final conversationKey =
          MessageConversationId.normalizeComparableKey(rawId);
      final conversationType =
          ActiveChatRegistry.instance.activeConversationType ??
              _resolveConversationType(conversationId);

      if (!kIsWeb) {
        await ImConnectStatusService.waitForImLoggedIn(
          timeout: reason == 'app_resumed' || reason == 'connect_success'
              ? const Duration(seconds: 10)
              : const Duration(seconds: 6),
        );
      }

      final globalModel = serviceLocator<TUIChatGlobalModel>();
      final hasVisibleMessages =
          globalModel.rawMessageList(conversationKey)?.isNotEmpty == true ||
              globalModel.rawMessageList(rawId)?.isNotEmpty == true ||
              globalModel.rawMessageList(conversationId)?.isNotEmpty == true;
      final previewAhead = await _isPreviewAheadOfHistory(
        conversationId: conversationId,
        conversationKey: conversationKey,
        globalModel: globalModel,
      );
      final hasDeferredIncoming = globalModel.hasDeferredIncomingForResume(
            conversationKey,
          ) ||
          globalModel.hasDeferredIncomingForResume(rawId) ||
          globalModel.hasDeferredIncomingForResume(conversationId);
      if (ChatHistoryRecoveryCoordinator.instance.shouldSkipForegroundRecovery(
        conversationKey: conversationKey,
        hasVisibleMessages: hasVisibleMessages,
        previewAhead: previewAhead,
        reason: reason,
        hasDeferredIncoming: hasDeferredIncoming,
      )) {
        if (kDebugMode) {
          debugPrint(
            'refreshForegroundChatIfNeeded skipped reason=$reason conv=$conversationKey',
          );
        }
        return;
      }
      if (ChatHistoryRecoveryCoordinator.instance
          .shouldCoalesceForegroundRequest(
        conversationKey: conversationKey,
        reason: reason,
      )) {
        if (kDebugMode) {
          debugPrint(
            'refreshForegroundChatIfNeeded coalesced '
            'reason=$reason conv=$conversationKey',
          );
        }
        return;
      }

      await ChatHistoryRecoveryCoordinator.instance.runExclusive(
        conversationKey: conversationKey,
        reason: reason,
        priority: ChatHistoryRecoveryCoordinator.priorityForeground,
        task: () async {
          ChatHistoryRefreshBus.instance.requestRefresh(
            conversationId: conversationId,
            reason: reason,
          );
        },
      );

      ChatHistoryRecoveryCoordinator.instance.schedulePostOpenRetry(
        conversationKey: conversationKey,
        conversationID: conversationId,
        conversationType: conversationType,
        retry: afterChatOpened,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('refreshForegroundChatIfNeeded failed: $e');
      }
    }
  }

  Future<bool> _isPreviewAheadOfHistory({
    required String conversationId,
    required String conversationKey,
    required TUIChatGlobalModel globalModel,
  }) async {
    final clearedAt = await ConversationLocalStore.instance.historyClearedAtMs(
      conversationId,
    );
    V2TimMessage? preview;
    try {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getConversation(conversationID: conversationId);
      preview = res.data?.lastMessage;
    } catch (_) {}
    if (clearedAt > 0) {
      final previewMs = ConversationLocalStore.messageTimestampMs(preview);
      if (preview == null || previewMs <= clearedAt) {
        return false;
      }
    }
    final cached = globalModel.messageListMap[conversationKey] ??
        globalModel.messageListMap[conversationId] ??
        const <V2TimMessage>[];
    return ConversationPreviewHistorySync.isPreviewAheadOfCachedHistory(
      preview: preview,
      cached: cached,
    );
  }

  String _resolveForegroundConversationId(String rawId) {
    final trimmed = rawId.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('c2c_') || lower.startsWith('group_')) {
      return trimmed;
    }
    final convType = ActiveChatRegistry.instance.activeConversationType;
    if (convType == ConvType.group) {
      return 'group_$trimmed';
    }
    return 'c2c_$trimmed';
  }

  ConvType _resolveConversationType(String conversationId) {
    final lower = conversationId.trim().toLowerCase();
    if (lower.startsWith('group_')) {
      return ConvType.group;
    }
    return ConvType.c2c;
  }

  Future<void> _runGlobalRecovery({
    required String reason,
    ResumeIntensity intensity = ResumeIntensity.full,
  }) async {
    final holdDuration = reason == 'app_resumed'
        ? ResumeForegroundPolicy.conversationHoldDuration
        : _defaultHold;
    ConversationRefreshBus.instance.hold(
      duration: holdDuration,
      reason: reason,
    );

    if (!kIsWeb) {
      try {
        await TencentImSDKPlugin.v2TIMManager
            .getConversationManager()
            .getTotalUnreadMessageCount();
      } catch (e) {
        if (kDebugMode) debugPrint('refresh unread count failed: $e');
      }
    }

    final tasks = <Future<void>>[
      FriendRequestNoticeService.instance
          .refreshPendingCount(
        notifyUnseen: true,
      )
          .catchError((e) {
        if (kDebugMode) debugPrint('refresh friend request count failed: $e');
      }),
      // 不在恢复流程里自动重发 SEND_FAIL，避免进会话反复转圈。
      ChatFailedMessageRetryService.instance
          .settleStuckSendingAsFailed()
          .catchError((e) {
        if (kDebugMode) {
          debugPrint('settle stuck sending messages failed: $e');
        }
      }),
    ];
    final runHeavy =
        ResumeForegroundPolicy.shouldRunHeavySideEffects(intensity);
    if (!kIsWeb && runHeavy) {
      tasks.add(
        WalletPendingRecoveryService.instance
            .recover(reason: reason)
            .then<void>((_) {})
            .catchError((e) {
          if (kDebugMode) debugPrint('recover wallet pending failed: $e');
        }),
      );
    }
    await Future.wait<void>(tasks);

    if (reason == 'app_resumed' ||
        reason == 'connect_success' ||
        reason == 'im_reconnected') {
      try {
        await serviceLocator<TUIChatGlobalModel>()
            .prepareForegroundChatRecovery();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('prepareForegroundChatRecovery failed: $e');
        }
      }
      await refreshForegroundChatIfNeeded(reason: reason);
    }

    ConversationRefreshBus.instance.requestRefresh(reason: '${reason}_done');
  }
}
