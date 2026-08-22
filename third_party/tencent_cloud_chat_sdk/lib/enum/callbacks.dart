import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation_filter.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_filter.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_reaction_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_reaction_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_official_account_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_official_account_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_receive_message_opt_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_receive_message_opt_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_download_progress.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_download_progress.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_extension.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_extension.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';

typedef VoidCallback = void Function();
typedef ErrorCallback = void Function(int code, String error);
typedef V2TimUserFullInfoCallback = void Function(V2TimUserFullInfo info);
typedef OnTotalUnreadMessageCountChanged = void Function(int totalUnreadCount);
typedef OnUserStatusChanged = void Function(
    List<V2TimUserStatus> userStatusList);
typedef OnLog = void Function(int logLevel, String logContent);
typedef OnRecvC2CTextMessageCallback = void Function(
  String msgID,
  V2TimUserInfo userInfo,
  String text,
);
typedef OnRecvMessageExtensionsChanged = void Function(
  String msgID,
  List<V2TimMessageExtension> extensions,
);
typedef OnRecvMessageExtensionsDeleted = void Function(
  String msgID,
  List<String> extensionKeys,
);
typedef OnMessageDownloadProgressCallback = void Function(
  V2TimMessageDownloadProgress messageProgress,
);
typedef OnRecvC2CCustomMessageCallback = void Function(
  String msgID,
  V2TimUserInfo sender,
  String customData,
);
typedef OnRecvGroupTextMessageCallback = void Function(
  String msgID,
  String groupID,
  V2TimGroupMemberInfo sender,
  String text,
);

typedef OnRecvGroupCustomMessageCallback = void Function(
  String msgID,
  String groupID,
  V2TimGroupMemberInfo sender,
  String customData,
);
typedef OnMemberEnterCallback = void Function(
  String groupID,
  List<V2TimGroupMemberInfo> memberList,
);
// void 	onMemberEnter (String groupID, List< V2TIMGroupMemberInfo > memberList)
typedef OnMemberLeaveCallback = void Function(
  String groupID,
  V2TimGroupMemberInfo member,
);
// void 	onMemberLeave (String groupID, V2TIMGroupMemberInfo member)
typedef OnMemberInvitedCallback = void Function(
  String groupID,
  V2TimGroupMemberInfo opUser,
  List<V2TimGroupMemberInfo> memberList,
);
// void 	onMemberInvited (String groupID, V2TIMGroupMemberInfo opUser, List< V2TIMGroupMemberInfo > memberList)
typedef OnMemberKickedCallback = void Function(
  String groupID,
  V2TimGroupMemberInfo opUser,
  List<V2TimGroupMemberInfo> memberList,
);
// void 	onMemberKicked (String groupID, V2TIMGroupMemberInfo opUser, List< V2TIMGroupMemberInfo > memberList)
typedef OnMemberInfoChangedCallback = void Function(
  String groupID,
  List<V2TimGroupMemberChangeInfo> v2TIMGroupMemberChangeInfoList,
);
// void 	onMemberInfoChanged (String groupID, List< V2TIMGroupMemberChangeInfo > v2TIMGroupMemberChangeInfoList)
typedef OnGroupCreatedCallback = void Function(
  String groupID,
);
// void 	onGroupCreated (String groupID)
typedef OnGroupDismissedCallback = void Function(
  String groupID,
  V2TimGroupMemberInfo opUser,
);
// void 	onGroupDismissed (String groupID, V2TIMGroupMemberInfo opUser)
typedef OnGroupRecycledCallback = void Function(
  String groupID,
  V2TimGroupMemberInfo opUser,
);
// void 	onGroupRecycled (String groupID, V2TIMGroupMemberInfo opUser)
typedef OnGroupInfoChangedCallback = void Function(
  String groupID,
  List<V2TimGroupChangeInfo> changeInfos,
);
// void 	onGroupInfoChanged (String groupID, List< V2TIMGroupChangeInfo > changeInfos)
typedef OnReceiveJoinApplicationCallback = void Function(
  String groupID,
  V2TimGroupMemberInfo member,
  String opReason,
);
// void 	onReceiveJoinApplication (String groupID, V2TIMGroupMemberInfo member, String opReason)
typedef OnApplicationProcessedCallback = void Function(
  String groupID,
  V2TimGroupMemberInfo opUser,
  bool isAgreeJoin,
  String opReason,
);
// void 	onApplicationProcessed (String groupID, V2TIMGroupMemberInfo opUser, boolean isAgreeJoin, String opReason)
typedef OnGrantAdministratorCallback = void Function(
  String groupID,
  V2TimGroupMemberInfo opUser,
  List<V2TimGroupMemberInfo> memberList,
);
// void 	onGrantAdministrator (String groupID, V2TIMGroupMemberInfo opUser, List< V2TIMGroupMemberInfo > memberList)
typedef OnRevokeAdministratorCallback = void Function(
  String groupID,
  V2TimGroupMemberInfo opUser,
  List<V2TimGroupMemberInfo> memberList,
);
// void 	onRevokeAdministrator (String groupID, V2TIMGroupMemberInfo opUser, List< V2TIMGroupMemberInfo > memberList)
typedef OnQuitFromGroupCallback = void Function(
  String groupID,
);
// void 	onQuitFromGroup (String groupID)
typedef OnReceiveRESTCustomDataCallback = void Function(
  String groupID,
  String customData,
);
// void 	onReceiveRESTCustomData (String groupID, byte[] customData)
typedef OnGroupAttributeChangedCallback = void Function(
  String groupID,
  Map<String, String> groupAttributeMap,
);
// void 	onGroupAttributeChanged (String groupID, Map< String, String > groupAttributeMap)
typedef OnRecvNewMessageCallback = void Function(
  V2TimMessage msg,
);

// void 	onGroupAttributeChanged (String groupID, Map< String, String > groupAttributeMap)
typedef OnRecvMessageModified = void Function(
  V2TimMessage msg,
);

// void 	onRecvNewMessage (V2TIMMessage msg)
typedef OnRecvC2CReadReceiptCallback = void Function(
  List<V2TimMessageReceipt> receiptList,
);
// void 	onRecvC2CReadReceipt (List< V2TIMMessageReceipt > receiptList)
typedef OnRecvMessageRevokedCallback = void Function(
  String msgID,
);
// void 	onRecvMessageRevoked (String msgID)
//
typedef OnFriendApplicationListAddedCallback = void Function(
  List<V2TimFriendApplication> applicationList,
);
// void 	onFriendApplicationListAdded (List< V2TIMFriendApplication > applicationList)
typedef OnFriendApplicationListDeletedCallback = void Function(
  List<String> userIDList,
);
// void 	onFriendApplicationListDeleted (List< String > userIDList)
typedef OnFriendApplicationListReadCallback = void Function();
// void 	onFriendApplicationListRead ()
typedef OnFriendListAddedCallback = void Function(List<V2TimFriendInfo> users);
// void 	onFriendListAdded (List< V2TIMFriendInfo > users)
typedef OnFriendListDeletedCallback = void Function(List<String> userList);
// void 	onFriendListDeleted (List< String > userList)
typedef OnBlackListAddCallback = void Function(List<V2TimFriendInfo> infoList);
// void 	onBlackListAdd (List< V2TIMFriendInfo > infoList)
typedef OnBlackListDeletedCallback = void Function(List<String> userList);
// void 	onBlackListDeleted (List< String > userList)
typedef OnFriendInfoChangedCallback = void Function(
  List<V2TimFriendInfo> infoList,
);

typedef OnFriendGroupCreatedCallback = void Function (
  String groupName, List<V2TimFriendInfo> friendInfoList
);
typedef OnFriendGroupDeletedCallback = void Function (
  List<String> groupNameList
);
typedef OnFriendGroupNameChangedCallback = void Function (
  String oldGroupName, String newGroupName
);
typedef OnFriendsAddedToGroupCallback = void Function (
  String groupName, List<V2TimFriendInfo> friendInfoList
);
typedef OnFriendsDeletedFromGroupCallback = void Function (
  String groupName, List<String> friendIDList
);

typedef OnOfficialAccountSubscribed = void Function(
    V2TimOfficialAccountInfo officialAccountInfo);
typedef OnOfficialAccountUnsubscribed = void Function(String officialAccountID);
typedef OnOfficialAccountDeleted = void Function(String officialAccountID);
typedef OnOfficialAccountInfoChanged = void Function(
    V2TimOfficialAccountInfo officialAccountInfo);
typedef OnMyFollowingListChanged = void Function(
    List<V2TimUserFullInfo> userInfoList, bool isAdd);
typedef OnMyFollowersListChanged = void Function(
    List<V2TimUserFullInfo> userInfoList, bool isAdd);
typedef OnMutualFollowersListChanged = void Function(
    List<V2TimUserFullInfo> userInfoList, bool isAdd);

// void 	onFriendInfoChanged (List< V2TIMFriendInfo > infoList)
typedef OnConversationChangedCallback = void Function(
  List<V2TimConversation> conversationList,
);
// void 	onNewConversation (List< V2TIMConversation > conversationList)
typedef OnNewConversation = void Function(
  List<V2TimConversation> conversationList,
);

// void 	onConversationChanged (List< V2TIMConversation > conversationList)
typedef OnReceiveNewInvitationCallback = void Function(
  String inviteID,
  String inviter,
  String groupID,
  List<String> inviteeList,
  String data,
);
// void 	onReceiveNewInvitation (String inviteID, String inviter, String groupID, List< String > inviteeList, String data)
typedef OnInviteeAcceptedCallback = void Function(
  String inviteID,
  String invitee,
  String data,
);
// void 	onInviteeAccepted (String inviteID, String invitee, String data)
typedef OnInviteeRejectedCallback = void Function(
  String inviteID,
  String invitee,
  String data,
);

typedef OnUiKitEventEmit = void Function(Map<String, dynamic> data);
// void 	onInviteeRejected (String inviteID, String invitee, String data)

typedef OnInvitationCancelledCallback = void Function(
  String inviteID,
  String inviter,
  String data,
);
// void 	onInvitationCancelled (String inviteID, String inviter, String data)

typedef OnInvitationTimeoutCallback = void Function(
  String inviteID,
  List<String> inviteeList,
);
// void 	onInvitationTimeout (String inviteID, List< String > inviteeList)

typedef OnInvitationModifiedCallback = void Function(
  String inviteID,
  String data,
);
// void   OnInvitationModifiedCallback (String inviteID, String data)

//
typedef OnSendMessageProgressCallback = void Function(
  V2TimMessage message,
  int progress,
);
typedef OnGroupMessagePinned = void Function(String groupID,
    V2TimMessage message, bool isPinned, V2TimGroupMemberInfo opUser);

typedef OnRecvMessageReadReceipts = void Function(
  List<V2TimMessageReceipt> receiptList,
);
typedef OnConversationGroupCreated = void Function(
    String groupName, List<V2TimConversation> conversationList);

typedef OnConversationGroupDeleted = void Function(String groupName);

typedef OnConversationGroupNameChanged = void Function(
    String oldName, String newName);

typedef OnConversationsAddedToGroup = void Function(
    String groupName, List<V2TimConversation> conversationList);

typedef OnConversationsDeletedFromGroup = void Function(
    String groupName, List<V2TimConversation> conversationList);

typedef OnTopicCreated = void Function(String groupID, String topicID);

typedef OnTopicDeleted = void Function(
    String groupID, List<String> topicIDList);

typedef OnTopicInfoChanged = void Function(
    String groupID, V2TimTopicInfo topicInfo);

typedef OnGroupCounterChanged = void Function(
  String groupID,
  String key,
  int newValue,
);

typedef OnUserInfoChanged = void Function(List<V2TimUserFullInfo> userInfoList);

typedef OnAllReceiveMessageOptChanged = void Function(
    V2TimReceiveMessageOptInfo receiveMessageOptInfo);

typedef OnExperimentalNotify = void Function(String key, dynamic param);

typedef OnAllGroupMembersMuted = void Function(String groupID, bool isMute);

typedef OnMemberMarkChanged = void Function(
    String groupID, List<String> memberIDList, int markType, bool enableMark);

typedef OnRecvMessageReactionsChanged = void Function(
    List<V2TIMMessageReactionChangeInfo> changeInfos);

typedef OnRecvMessageRevoked = void Function(
    String msgID, V2TimUserFullInfo operateUser, String reason);

typedef OnConversationDeleted = void Function(List<String> conversationIDList);

typedef OnUnreadMessageCountChangedByFilter = void Function(
    V2TimConversationFilter filter, int totalUnreadCount);

class UIKitEvent {
  final String type;
  final Map<String, dynamic> detail;
  UIKitEvent({
    required this.type,
    required this.detail,
  });
}

class PluginEvent {
  final String type;
  final Map<String, dynamic> detail;
  final String pluginName;
  PluginEvent({
    required this.type,
    required this.detail,
    required this.pluginName,
  });
}

typedef OnUIKitEventEmited = void Function(UIKitEvent event);

typedef OnPluginEventEmited = void Function(PluginEvent event);

// community
typedef OnCreateTopic = void Function(String groupID, String topicID);

typedef OnDeleteTopic = void Function(String groupID, List<String> topicIDList);

typedef OnChangeTopicInfo = void Function(
    String groupID, V2TimTopicInfo topicInfo);

typedef OnReceiveTopicRESTCustomData = void Function(
    String topicID, String customData);

typedef OnCreatePermissionGroup = void Function(
    String groupID, V2TimPermissionGroupInfo permissionGroupInfo);

typedef OnDeletePermissionGroup = void Function(
    String groupID, List<String> permissionGroupIDList);

typedef OnChangePermissionGroupInfo = void Function(
    String groupID, V2TimPermissionGroupInfo permissionGroupInfo);

typedef OnAddMembersToPermissionGroup = void Function(
    String groupID, String permissionGroupID, List<String> memberIDList);

typedef OnRemoveMembersFromPermissionGroup = void Function(
    String groupID, String permissionGroupID, List<String> memberIDList);

typedef OnAddTopicPermission = void Function(
  String groupID, String permissionGroupID, Map<String, int> topicPermissionMap);

typedef OnDeleteTopicPermission = void Function(
    String groupID, String permissionGroupID, List<String> topicIDList);

typedef OnModifyTopicPermission = void Function(
  String groupID, String permissionGroupID, Map<String, int> topicPermissionMap);
