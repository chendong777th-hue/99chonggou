import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';

/// When C2C send permission becomes blocked, reconcile in-flight self messages.
class C2cBlockedOutgoingMessageSync {
  C2cBlockedOutgoingMessageSync._();

  static const int blockedCode = 20011;
  static const String relationBlockedReason = 'relation_blocked';

  /// Returns a failed clone when [message] is an in-flight self message.
  static V2TimMessage? reconcileInFlightMessage(V2TimMessage message) {
    if (message.isSelf != true) {
      return null;
    }
    if (message.status != MessageStatus.V2TIM_MSG_STATUS_SENDING) {
      return null;
    }
    V2TimMessage updated;
    try {
      final map = Map<String, dynamic>.from(message.toJson());
      map['message_status'] = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
      updated = V2TimMessage.fromJson(map);
    } catch (_) {
      updated = message;
      updated.status = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
    }
    ErrorMessageConverter.attachSendFailCode(updated, blockedCode);
    return updated;
  }

  static bool shouldMarkInFlight({required String reason}) {
    return reason == relationBlockedReason;
  }

  static void markInFlightAsFriendBlocked({
    required String conversationID,
    required TUIChatGlobalModel globalModel,
    String reason = '',
  }) {
    if (!shouldMarkInFlight(reason: reason)) {
      return;
    }
    final convID = conversationID.trim();
    if (convID.isEmpty) {
      return;
    }
    final list = globalModel.messageListMap[convID];
    if (list == null || list.isEmpty) {
      return;
    }

    for (final msg in list) {
      final reconciled = reconcileInFlightMessage(msg);
      if (reconciled == null) {
        continue;
      }
      final clientId = msg.id?.trim().isNotEmpty == true
          ? msg.id!.trim()
          : (msg.msgID?.trim() ?? '');
      if (clientId.isEmpty) {
        continue;
      }
      globalModel.applyOutgoingSendResult(
        V2TimValueCallback<V2TimMessage>(
          code: blockedCode,
          desc: 'friend relation blocked',
          data: reconciled,
        ),
        convID,
        clientId,
        ConvType.c2c,
        null,
        null,
      );
    }
  }
}
