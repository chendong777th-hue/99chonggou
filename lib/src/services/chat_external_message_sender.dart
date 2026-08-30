import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/account_scoped_conversation_key.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/outgoing_external_send_helper.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/external_chat_entry_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

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
    var receiver = receiverUserId.trim();
    var group = groupId.trim();
    if (receiver.toLowerCase().startsWith('c2c_') && receiver.length > 4) {
      receiver = receiver.substring(4);
    }
    if (group.toLowerCase().startsWith('group_') && group.length > 6) {
      group = group.substring(6);
    }
    if (messageInfo == null || (receiver.isEmpty && group.isEmpty)) {
      return false;
    }

    final isGroup = group.isNotEmpty;
    final convType = isGroup ? ConvType.group : ConvType.c2c;
    final convId = isGroup ? group : receiver;
    final fullConversationId = conversationId(
      receiverUserId: receiver,
      groupId: group,
    );

    // 提前声明,catch 块才能访问 (finalize Outbox 必须)
    SessionIdentity identity = SessionIdentityService.instance.capture();
    ExternalOutboxRecordOutcome externalOutcome =
        const ExternalOutboxRecordOutcome(prepared: false, outcomeUnknown: false);
    try {
      // IM-08 P0-Critical 第二刀:外发前在 Outbox 主表写入 prepared/dispatchIntent/sending。
      // 这样失败重试/历史回写/认领都走同一条 Outbox 路径,不污染。
      identity = SessionIdentityService.instance.capture();
      externalOutcome = await OutgoingExternalSendHelper
          .recordOutboxEntryForExternal(
        message: messageInfo,
        sdkLocalId: messageInfo.id ?? '',
        ownerUserId: identity.ownerUserId,
        conversationType:
            convType == ConvType.group ? ImConversationType.group : ImConversationType.c2c,
        conversationId: fullConversationId.isNotEmpty ? fullConversationId : convId,
      );
      final sendRes = await serviceLocator<TUIChatGlobalModel>()
          .sendMessageFromController(
        messageInfo: messageInfo,
        convType: convType,
        convID: convId,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount,
      );
      final ok = sendRes?.code == 0;
      // IM-08 P0-Critical:UIKit 返回后,把 Outbox 主表最终态落地。
      if (identity.ownerUserId.isNotEmpty && externalOutcome.prepared) {
        await OutgoingExternalSendHelper.finalizeOutboxForExternal(
          ownerUserId: identity.ownerUserId,
          conversationId: fullConversationId.isNotEmpty
              ? fullConversationId
              : convId,
          sdkLocalId: messageInfo.id ?? '',
          serverMsgId: sendRes?.data?.msgID,
          resultCode: sendRes?.code ?? -1,
          outcomeUnknown: externalOutcome.outcomeUnknown,
        );
      }
      if (ok) {
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
      return ok;
    } catch (e) {
      // IM-08 P0-Critical: UIKit 异常路径必须 finalize Outbox,否则记录
      // 永远停在 sending 状态,ImRecoveryWorker 会反复认领。
      // 异常等同于无法证明 SDK 未调用,所以标 outcomeUnknown=true。
      if (identity.ownerUserId.isNotEmpty && externalOutcome.prepared) {
        try {
          await OutgoingExternalSendHelper.finalizeOutboxForExternal(
            ownerUserId: identity.ownerUserId,
            conversationId: fullConversationId.isNotEmpty
                ? fullConversationId
                : convId,
            sdkLocalId: messageInfo.id ?? '',
            serverMsgId: null,
            resultCode: -1,
            outcomeUnknown: true,
          );
        } catch (finalizeErr) {
          debugPrint('finalize outbox on exception failed: $finalizeErr');
        }
      }
      debugPrint('send external message failed: $e');
      return false;
    }
  }
}
