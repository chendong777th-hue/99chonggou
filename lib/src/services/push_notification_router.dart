import 'package:tencent_cloud_chat_demo/src/platform/route_handler.dart';
import 'package:tencent_cloud_chat_demo/src/services/external_chat_entry_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/incoming_call_push_handler.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_payload_normalizer.dart';
import 'package:tencent_cloud_chat_demo/src/utils/voip_push_payload.dart';
/// 系统 Push 点击统一路由（§9.1）。
class PushNotificationRouter {
  PushNotificationRouter._();

  static Future<void> handleTap({
    required Map<String, dynamic> rawData,
    required String source,
    required Future<void> Function({
      String? ext,
      String? conversationID,
      String? groupID,
      String? userID,
      required String source,
    }) openConversation,
  }) async {
    final data = PushPayloadNormalizer.normalize(rawData);
    final type = data['type']?.toString().trim().toLowerCase() ?? '';

    ExternalChatEntryService.instance.logFlow(
      'push_notification_tap',
      source: source,
      conversationID: PushPayloadNormalizer.resolveConversationId(data),
      extras: <String, Object?>{
        'type': type,
        'msgKey': data['msgKey']?.toString(),
        'inviteId': data['inviteId'] ?? data['inviteID'],
      },
    );

    switch (type) {
      case 'lk_call':
        _handleAvCallTap(data);
        return;
      case 'av_call':
      case 'rtc_call':
        // Legacy TRTC payloads — ignore for LiveKit answer path.
        IncomingCallPushHandler.instance.noteInviteHandled(
          VoipPushPayload.readInviteId(data),
        );
        return;
      case 'platform_wallet_notice':
        RouteHandler.openWallet(source: source);
        return;
      case 'announcement':
        RouteHandler.openHome(source: source);
        return;
      case 'register_welcome':
        await openConversation(
          source: source,
          conversationID: 'c2c_99Messenger',
        );
        return;
      case 'friend_request':
      case 'friend_request_rejected':
        RouteHandler.openNewContact();
        return;
      case 'friend_request_accepted':
      case 'friend_request_auto_accepted':
      case 'friend_added':
        final friendConv =
            PushPayloadNormalizer.resolveConversationId(data);
        if (friendConv != null && friendConv.isNotEmpty) {
          await openConversation(
            source: source,
            conversationID: friendConv,
          );
          return;
        }
        RouteHandler.openNewContact();
        return;
      case 'group_changed':
        if (_shouldOpenGroupNotices(data)) {
          await RouteHandler.openGroupNotices();
          return;
        }
        await openConversation(
          source: source,
          conversationID: PushPayloadNormalizer.resolveConversationId(data),
          groupID: data['groupId']?.toString() ??
              data['groupID']?.toString() ??
              data['group_id']?.toString(),
        );
        return;
      case 'im_chat':
      case 'chat_message':
        final conversationID =
            PushPayloadNormalizer.resolveConversationId(data);
        if (conversationID != null && conversationID.isNotEmpty) {
          await openConversation(
            source: source,
            conversationID: conversationID,
          );
          return;
        }
        break;
      default:
        break;
    }

    final conversationID =
        PushPayloadNormalizer.resolveConversationId(data);
    if (conversationID != null && conversationID.isNotEmpty) {
      await openConversation(
        source: source,
        conversationID: conversationID,
      );
      return;
    }

    RouteHandler.openHome(source: source);
  }

  static bool _shouldOpenGroupNotices(Map<String, dynamic> data) {
    final action = data['action']?.toString().trim().toLowerCase() ?? '';
    return action == 'join_application_pending' ||
        action == 'join_application_handled' ||
        action == 'group_system_notice';
  }

  static void _handleAvCallTap(Map<String, dynamic> data) {
    IncomingCallPushHandler.instance.noteInviteHandled(
      VoipPushPayload.readInviteId(data),
    );
    // LiveKit: CallKit answer/hangup is handled by LiveKitVoipBridge
    // (tuicall_kit channel → accept/reject REST + Room.connect).
  }

}
