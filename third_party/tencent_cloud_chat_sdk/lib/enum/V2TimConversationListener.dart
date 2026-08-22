// void 	onSyncServerStart ()

// void 	onSyncServerFinish ()

// void 	onSyncServerFailed ()

// void 	onNewConversation (List< V2TIMConversation > conversationList)

// ignore_for_file: file_names, prefer_function_declarations_over_variables

// void 	onConversationChanged (List< V2TIMConversation > conversationList)
//
//
import 'package:tencent_cloud_chat_sdk/enum/callbacks.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation_filter.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_filter.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

class V2TimConversationListener {
  VoidCallback onSyncServerStart = () {};
  VoidCallback onSyncServerFinish = () {};
  VoidCallback onSyncServerFailed = () {};
  OnNewConversation onNewConversation = (
    List<V2TimConversation> conversationList,
  ) {};
  OnConversationChangedCallback onConversationChanged = (
    List<V2TimConversation> conversationList,
  ) {};
  OnTotalUnreadMessageCountChanged onTotalUnreadMessageCountChanged = (
    int totalUnreadCount,
  ) {};
  OnConversationGroupCreated onConversationGroupCreated =
      (String groupName, List<V2TimConversation> conversationList) {};
  OnConversationGroupDeleted onConversationGroupDeleted = (String groupName) {};
  OnConversationGroupNameChanged onConversationGroupNameChanged =
      (String oldName, String newName) {};
  OnConversationsAddedToGroup onConversationsAddedToGroup =
      (String groupName, List<V2TimConversation> conversationList) {};
  OnConversationsDeletedFromGroup onConversationsDeletedFromGroup =
      (String groupName, List<V2TimConversation> conversationList) {};
  OnConversationDeleted onConversationDeleted =
      (List<String> conversationIDList) {};
  OnUnreadMessageCountChangedByFilter onUnreadMessageCountChangedByFilter =
      (V2TimConversationFilter filter, int totalUnreadCount) {};
  V2TimConversationListener({
    VoidCallback? onSyncServerStart,
    VoidCallback? onSyncServerFinish,
    VoidCallback? onSyncServerFailed,
    OnNewConversation? onNewConversation,
    OnConversationChangedCallback? onConversationChanged,
    OnTotalUnreadMessageCountChanged? onTotalUnreadMessageCountChanged,
    OnConversationGroupCreated? onConversationGroupCreated,
    OnConversationGroupDeleted? onConversationGroupDeleted,
    OnConversationGroupNameChanged? onConversationGroupNameChanged,
    OnConversationsAddedToGroup? onConversationsAddedToGroup,
    OnConversationsDeletedFromGroup? onConversationsDeletedFromGroup,
    OnConversationDeleted? onConversationDeleted,
    OnUnreadMessageCountChangedByFilter? onUnreadMessageCountChangedByFilter,
  }) {
    if (onUnreadMessageCountChangedByFilter != null) {
      this.onUnreadMessageCountChangedByFilter =
          onUnreadMessageCountChangedByFilter;
    }
    if (onConversationDeleted != null) {
      this.onConversationDeleted = onConversationDeleted;
    }
    if (onSyncServerStart != null) {
      this.onSyncServerStart = onSyncServerStart;
    }
    if (onSyncServerFinish != null) {
      this.onSyncServerFinish = onSyncServerFinish;
    }
    if (onSyncServerFailed != null) {
      this.onSyncServerFailed = onSyncServerFailed;
    }
    if (onNewConversation != null) {
      this.onNewConversation = onNewConversation;
    }
    if (onConversationChanged != null) {
      this.onConversationChanged = onConversationChanged;
    }
    if (onTotalUnreadMessageCountChanged != null) {
      this.onTotalUnreadMessageCountChanged = onTotalUnreadMessageCountChanged;
    }
    if (onConversationGroupCreated != null) {
      this.onConversationGroupCreated = onConversationGroupCreated;
    }
    if (onConversationGroupDeleted != null) {
      this.onConversationGroupDeleted = onConversationGroupDeleted;
    }
    if (onConversationGroupNameChanged != null) {
      this.onConversationGroupNameChanged = onConversationGroupNameChanged;
    }
    if (onConversationsAddedToGroup != null) {
      this.onConversationsAddedToGroup = onConversationsAddedToGroup;
    }
    if (onConversationsDeletedFromGroup != null) {
      this.onConversationsDeletedFromGroup = onConversationsDeletedFromGroup;
    }
  }
}
