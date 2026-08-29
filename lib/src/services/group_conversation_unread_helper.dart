import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_aggregate.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 建群等场景下，SDK 系统提示会误增未读；主动清零会话未读。
class GroupConversationUnreadHelper {
  GroupConversationUnreadHelper._();

  /// 隐藏/静默 tip 被 SDK 计入未读时，本地扣回 1（不整会话清零，避免误伤真实未读）。
  static Future<void> absorbOneUnreadBump(String conversationID) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    try {
      final existing =
          await ConversationLocalStore.instance.conversationById(id);
      if (existing == null) {
        return;
      }
      final unread = existing.unreadCount ?? 0;
      if (unread <= 0) {
        return;
      }
      await ConversationSyncService.instance.applyConversationUnreadLocally(
        conversationID: id,
        unreadCount: unread - 1,
        snapshot: existing,
      );
      ConversationUnreadAggregate.instance.scheduleRefresh(
        reason: 'absorb_tip_unread',
      );
    } catch (e) {
      debugPrint('absorb group tip unread bump failed: $e');
    }
  }

  static Future<void> clearConversationUnread(
    String conversationID, {
    V2TimConversation? conversation,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    if (conversation != null) {
      conversation.unreadCount = 0;
    }
    try {
      await ConversationSyncService.instance.markConversationReadLocally(id);
    } catch (e) {
      debugPrint('mark group conversation read locally failed: $e');
    }
    try {
      serviceLocator<TUIConversationViewModel>()
          .markConversationReadLocally(id);
    } catch (_) {}
    try {
      final groupID = id.startsWith('group_') ? id.substring(6) : id;
      await serviceLocator<MessageService>().markGroupMessageAsRead(
        groupID: groupID,
      );
    } catch (e) {
      debugPrint('clear group conversation unread failed: $e');
    }
  }

  /// 系统群提示可能晚于首屏到达，补几次清零即可。
  static void scheduleClearAfterGroupCreate(
    String conversationID, {
    V2TimConversation? conversation,
  }) {
    scheduleClearRepeatedly(conversationID, conversation: conversation);
  }

  /// 本人操作的群系统提示（邀请/踢人等）到达后，SDK 可能误增未读，延迟补清。
  static void scheduleClearForSelfOperatedGroupTips(
    String conversationID, {
    V2TimConversation? conversation,
  }) {
    scheduleClearRepeatedly(conversationID, conversation: conversation);
  }

  static void scheduleClearRepeatedly(
    String conversationID, {
    V2TimConversation? conversation,
  }) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    unawaited(clearConversationUnread(id, conversation: conversation));
    for (final delay in const [
      Duration(milliseconds: 600),
      Duration(milliseconds: 1500),
      Duration(milliseconds: 3000),
    ]) {
      Future<void>.delayed(delay, () {
        unawaited(clearConversationUnread(id));
      });
    }
  }
}
