import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_priority_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/outgoing_send_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/external_chat_entry_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

enum ExternalMessageSendState {
  succeeded,
  failed,
  outcomeUnknown,
  blocked,
}

class ExternalMessageSendResult {
  const ExternalMessageSendResult({
    required this.state,
    this.sdkCode,
    this.description = '',
  });

  final ExternalMessageSendState state;
  final int? sdkCode;
  final String description;

  bool get succeeded => state == ExternalMessageSendState.succeeded;

  /// True means the provider may already have accepted the message. Callers
  /// must wait for realtime/history adoption and must never create a new SDK
  /// message as an automatic retry.
  bool get mayHaveBeenSent =>
      state == ExternalMessageSendState.succeeded ||
      state == ExternalMessageSendState.outcomeUnknown;
}

/// Sends messages created outside an opened chat page.
///
/// Do not call the raw SDK sendMessage directly for user-visible share/forward
/// entries. Raw SDK sending can succeed without inserting the outgoing message
/// into UIKit's local message list, which makes the sender-side bubble disappear
/// until a later full history reload.
class ChatExternalMessageSender {
  ChatExternalMessageSender._();

  static String conversationId({
    required String receiverUserId,
    required String groupId,
  }) {
    final receiver = receiverUserId.trim();
    final group = groupId.trim();
    return ExternalChatEntryService.instance.resolveConversationId(
          userID: receiver,
          groupID: group,
        ) ??
        '';
  }

  static Future<bool> sendCreatedMessage({
    required V2TimMessage? messageInfo,
    required String receiverUserId,
    required String groupId,
    String reason = 'external_message_sent',
    bool isExcludedFromUnreadCount = false,
  }) async {
    final result = await sendCreatedMessageDetailed(
      messageInfo: messageInfo,
      receiverUserId: receiverUserId,
      groupId: groupId,
      reason: reason,
      isExcludedFromUnreadCount: isExcludedFromUnreadCount,
    );
    // Legacy bool callers cannot represent OutcomeUnknown. Treat it as
    // accepted/pending so UI and business retry loops do not create a second
    // SDK message. Detailed callers can render a pending state explicitly.
    return result.mayHaveBeenSent;
  }

  static Future<ExternalMessageSendResult> sendCreatedMessageDetailed({
    required V2TimMessage? messageInfo,
    required String receiverUserId,
    required String groupId,
    String reason = 'external_message_sent',
    bool isExcludedFromUnreadCount = false,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool onlineUserOnly = false,
    bool needReadReceipt = false,
    OfflinePushInfo? offlinePushInfo,
    String? cloudCustomData,
    String? localCustomData,
    bool recoverPreparedOutbox = false,
  }) async {
    var receiver = receiverUserId.trim();
    var group = groupId.trim();
    if (receiver.toLowerCase().startsWith('c2c_') && receiver.length > 4) {
      receiver = receiver.substring(4);
    }
    if (group.toLowerCase().startsWith('group_') && group.length > 6) {
      group = group.substring(6);
    }
    if (messageInfo == null || (receiver.isEmpty && group.isEmpty)) {
      return const ExternalMessageSendResult(
        state: ExternalMessageSendState.blocked,
        description: 'message or target is missing',
      );
    }

    final isGroup = group.isNotEmpty;
    final convType = isGroup ? ConvType.group : ConvType.c2c;
    final convId = isGroup ? group : receiver;
    final fullConversationId = conversationId(
      receiverUserId: receiver,
      groupId: group,
    );

    final identity = SessionIdentityService.instance.capture();
    ImCoordinatedSendResult? coordinated;
    try {
      // The GlobalModel path already owns the one durable Outbox through
      // ImOutgoingSendCoordinator. Do not create/finalize a second Outbox here.
      final sendRes =
          await serviceLocator<TUIChatGlobalModel>().sendMessageFromController(
        messageInfo: messageInfo,
        convType: convType,
        convID: convId,
        priority: priority,
        onlineUserOnly: onlineUserOnly,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount,
        needReadReceipt: needReadReceipt,
        offlinePushInfo: offlinePushInfo,
        cloudCustomData: cloudCustomData,
        localCustomData: localCustomData,
        recoverPreparedOutbox: recoverPreparedOutbox,
        onCoordinatedResult: (result) => coordinated = result,
      );
      final ok = sendRes?.code == 0;
      final dispatchDecision = coordinated?.dispatchDecision;
      if (coordinated?.outcomeUnknown == true ||
          dispatchDecision == ImOutboxDispatchDecision.outcomeUnknown) {
        return ExternalMessageSendResult(
          state: ExternalMessageSendState.outcomeUnknown,
          sdkCode: sendRes?.code,
          description: sendRes?.desc ?? 'outcome unknown',
        );
      }
      if (coordinated == null || coordinated?.usedOutbox != true) {
        return ExternalMessageSendResult(
          state: ExternalMessageSendState.blocked,
          sdkCode: sendRes?.code,
          description: sendRes?.desc ?? 'coordinated send unavailable',
        );
      }
      if (ok && SessionIdentityService.instance.isCurrent(identity)) {
        ConversationRefreshBus.instance.requestRefresh(
          reason: reason,
          conversationId:
              fullConversationId.isNotEmpty ? fullConversationId : null,
        );
        if (fullConversationId.isNotEmpty &&
            !ChatHistoryRefreshBus.skipsHistoryReload(reason)) {
          ChatHistoryRefreshBus.instance.requestRefresh(
            conversationId: fullConversationId,
            reason: reason,
          );
          // 与聊天页 messageDidSend 对齐：己方外发不走通知侧乐观 patch，需本地写预览。
          final sent = sendRes?.data ?? messageInfo;
          unawaited(
            ConversationSyncService.instance
                .patchConversationLastMessage(
                  conversationID: fullConversationId,
                  message: sent,
                )
                .catchError((_) {}),
          );
        }
      }
      return ExternalMessageSendResult(
        state: ok
            ? ExternalMessageSendState.succeeded
            : ExternalMessageSendState.failed,
        sdkCode: sendRes?.code,
        description: sendRes?.desc ?? '',
      );
    } catch (e) {
      debugPrint(
        'send external message failed errorType=${e.runtimeType}',
      );
      // If dispatch reached the Coordinator, an exception cannot prove that
      // Tencent rejected the message. Preserve OutcomeUnknown and let
      // realtime/history adoption settle it.
      return ExternalMessageSendResult(
        state: coordinated != null
            ? ExternalMessageSendState.outcomeUnknown
            : ExternalMessageSendState.blocked,
        description: '$e',
      );
    }
  }
}
