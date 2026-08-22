import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimGroupListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSignalingListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSimpleMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimCommunityListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimFriendshipListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/user_status_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation_filter.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_filter.dart';
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
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_reaction_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_reaction_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk_example/utils/log_manager.dart';
import 'utils.dart';

/// 全局监听器管理类，用于初始化和管理所有监听器
class ListenerManager {
  // 单例实现
  static final ListenerManager _instance = ListenerManager._internal();
  factory ListenerManager() => _instance;
  ListenerManager._internal();

  // 各种监听器
  late V2TimSDKListener _sdkListener;
  late V2TimSimpleMsgListener _simpleMsgListener;
  late V2TimAdvancedMsgListener _advancedMsgListener;
  late V2TimGroupListener _groupListener;
  late V2TimConversationListener _conversationListener;
  late V2TimCommunityListener _communityListener;
  late V2TimFriendshipListener _friendshipListener;
  late V2TimSignalingListener _signalingListener;

  // 是否已初始化
  bool _isInitialized = false;

  // 日志管理器
  final LogManager _logManager = LogManager();

  // 初始化所有监听器
  void initialize() {
    if (_isInitialized) return;

    _initSDKListener();
    _initSimpleMsgListener();
    _initAdvancedMsgListener();
    _initGroupListener();
    _initConversationListener();
    _initCommunityListener();
    _initFriendshipListener();
    _initSignalingListener();

    _isInitialized = true;
  }

  // 初始化SDK监听器
  void _initSDKListener() {
    _sdkListener = V2TimSDKListener(
      onConnecting: () {
        _logManager.updateNetStatusLog('onConnecting');
      },
      onConnectSuccess: () {
        _logManager.updateNetStatusLog('onConnectSuccess');
      },
      onConnectFailed: (code, error) {
        _logManager.updateNetStatusLog('onConnectFailed code = $code, desc = $error');
      },
      onKickedOffline: () {
        _logManager.updateNetStatusLog('onKickOffline');
      },
      onUserSigExpired: () {
        _logManager.updateNetStatusLog('onUserSigExpired');
      },
      onSelfInfoUpdated: (info) {
        _logManager.updateNetStatusLog('onSelfInfoUpdated:\n${info.toLogString()}');
      },
      onUserInfoChanged: (List<V2TimUserFullInfo> userInfoList) {
        for (var userInfo in userInfoList) {
          _logManager.updateNetStatusLog('onUserInfoChanged, ${userInfo.toLogString()}');
        }
      },
      onUserStatusChanged: (userStatusList) {
        for (var userStatus in userStatusList) {
          var statusType = 'unknown';
          switch (userStatus.statusType) {
            case UserStatusType.V2TIM_USER_STATUS_ONLINE:
              statusType = 'online';
              break;
            case UserStatusType.V2TIM_USER_STATUS_OFFLINE:
              statusType = 'offline';
              break;
            case UserStatusType.V2TIM_USER_STATUS_UNLOGINED:
              statusType = 'unlogined';
              break;
            default:
              break;
          }
          _logManager.updateNetStatusLog('onUserStatusChanged, userID:${userStatus.userID}|statusType:$statusType|customStatus:${userStatus.customStatus}');
        }
      },
    );
  }

  // 初始化简单消息监听器
  void _initSimpleMsgListener() {
    _simpleMsgListener = V2TimSimpleMsgListener(
      onRecvC2CTextMessage: (msgID, sender, text) {
        _logManager.updateSimpleMsgLog('onRecvC2CTextMessage: $msgID from ${sender.userID}, content: $text');
      },
      onRecvC2CCustomMessage: (msgID, sender, customData) {
        _logManager.updateSimpleMsgLog('onRecvC2CCustomMessage: $msgID from ${sender.userID}');
      },
      onRecvGroupTextMessage: (msgID, groupID, sender, text) {
        _logManager.updateSimpleMsgLog('onRecvGroupTextMessage: $msgID from $groupID, sender: ${sender.userID}, content: $text');
      },
      onRecvGroupCustomMessage: (msgID, groupID, sender, customData) {
        _logManager.updateSimpleMsgLog('onRecvGroupCustomMessage: $msgID from $groupID, sender: ${sender.userID}');
      },
    );
  }

  // 初始化高级消息监听器
  void _initAdvancedMsgListener() {
    _advancedMsgListener = V2TimAdvancedMsgListener(
      onRecvNewMessage: (V2TimMessage message) {
        _logManager.updateAdvMsgLog('onRecvNewMessage: ${message.msgID}|${Utils.getMessageContent(message)}');
      },
      onSendMessageProgress: (V2TimMessage message, int progress) {
        _logManager.updateAdvMsgLog('onSendMessageProgress, msgID: ${message.msgID}, progress: $progress');
      },
      onRecvMessageReadReceipts: (List<V2TimMessageReceipt> receiptList) {
        String receiptString = '';
        for (var receipt in receiptList) {
          receiptString += '${receipt.toLogString()}\n';
        }
        _logManager.updateAdvMsgLog('onRecvMessageReadReceipts: $receiptString');
      },
      onRecvC2CReadReceipt: (List<V2TimMessageReceipt> receiptList) {
        String receiptString = '';
        for (var receipt in receiptList) {
          receiptString += '${receipt.toLogString()}\n';
        }
        _logManager.updateAdvMsgLog('onRecvC2CReadReceipt: $receiptString');
      },
      onRecvMessageRevoked: (String msgID) {
        _logManager.updateAdvMsgLog('onRecvMessageRevoked: $msgID');
      },
      onRecvMessageModified: (V2TimMessage msg) {
        _logManager.updateAdvMsgLog('onRecvMessageModified: ${msg.msgID}|${Utils.getMessageContent(msg)}');
      },
      onRecvMessageExtensionsChanged: (String msgID, List<V2TimMessageExtension> extensions) {
        String extensionsString = '';
        for (var extensions in extensions) {
          extensionsString += '${extensions.toLogString()}\n';
        }
        _logManager.updateAdvMsgLog('onRecvMessageExtensionsChanged, msgID: $msgID, extensions: $extensionsString');
      },
      onRecvMessageExtensionsDeleted: (String msgID, List<String> extensionIDList) {
        _logManager.updateAdvMsgLog('onRecvMessageExtensionsDeleted, msgID: $msgID, extensionIDList: $extensionIDList');
      },
      onMessageDownloadProgressCallback: (V2TimMessageDownloadProgress messageProgress) {
        _logManager.updateAdvMsgLog('onMessageDownloadProgressCallback: ${messageProgress.toLogString()}');
      },
      onRecvMessageReactionsChanged: (List<V2TIMMessageReactionChangeInfo> changeInfos) {
        String changeInfoString = '';
        for (var info in changeInfos) {
          changeInfoString += '${info.toLogString()}\n';
        }
        _logManager.updateAdvMsgLog('onRecvMessageReactionsChanged: $changeInfoString');
      },
      onRecvMessageRevokedWithInfo: (String msgID, V2TimUserFullInfo operateUser, String reason) {
        _logManager.updateAdvMsgLog('onRecvMessageRevokedWithInfo, msgID: $msgID, operateUser: ${operateUser.toLogString()}, reason: $reason');
      },
      onGroupMessagePinned: (String groupID, V2TimMessage message, bool isPinned, V2TimGroupMemberInfo opUser) {
        _logManager.updateAdvMsgLog('onGroupMessagePinned, groupID: $groupID, msgID: ${message.msgID}, isPinned: $isPinned, opUser: ${opUser.toJson()}');
      },
    );
  }

  // 初始化群组监听器
  void _initGroupListener() {
    _groupListener = V2TimGroupListener(
      onGroupCreated: (String groupID) {
        _logManager.updateGroupLog('onGroupCreated: $groupID');
      },
      onGroupDismissed: (String groupID, V2TimGroupMemberInfo opUser) {
        _logManager.updateGroupLog('onGroupDismissed: $groupID by ${opUser.userID}');
      },
      onGroupRecycled: (String groupID, V2TimGroupMemberInfo opUser) {
        _logManager.updateGroupLog('onGroupRecycled: $groupID, opUser: ${opUser.userID}');
      },
      onGroupInfoChanged: (String groupID, List<V2TimGroupChangeInfo> changeInfos) {
        String changeLog = '';
        for (var changeInfo in changeInfos) {
          changeLog += '${changeInfo.toLogString()}\n';
        }
        _logManager.updateGroupLog('onGroupInfoChanged: $groupID, changeInfos: $changeLog');
      },
      onMemberEnter: (String groupID, List<V2TimGroupMemberInfo> memberList) {
        String memberListLog = '';
        for (var member in memberList) {
          memberListLog += '${member.userID}\n';
        }
        _logManager.updateGroupLog('onMemberEnter: $groupID, memberIDs: $memberListLog');
      },
      onMemberLeave: (String groupID, V2TimGroupMemberInfo member) {
        _logManager.updateGroupLog('onMemberLeave: $groupID, ${member.userID}');
      },
      onMemberInvited: (String groupID, V2TimGroupMemberInfo opUser, List<V2TimGroupMemberInfo> memberList) {
        String memberListLog = '';
        for (var member in memberList) {
          memberListLog += '${member.userID}\n';
        }
        _logManager.updateGroupLog('onMemberInvited: $groupID, memberIDs: $memberListLog');
      },
      onMemberKicked: (String groupID, V2TimGroupMemberInfo opUser, List<V2TimGroupMemberInfo> memberList) {
        String memberListLog = '';
        for (var member in memberList) {
          memberListLog += '${member.userID}\n';
        }
        _logManager.updateGroupLog('onMemberKicked: $groupID, opUser: ${opUser.userID}, memberIDs: $memberListLog');
      },
      onQuitFromGroup: (String groupID) {
        _logManager.updateGroupLog('onQuitFromGroup: $groupID');
      },
      onAllGroupMembersMuted: (String groupID, bool isMute) {
        _logManager.updateGroupLog('onAllGroupMembersMuted: $groupID, isMute: $isMute');
      },
      onMemberInfoChanged: (String groupID, List<V2TimGroupMemberChangeInfo> v2TIMGroupMemberChangeInfoList) {
        String memberListLog = '';
        for (var memberChangeInfo in v2TIMGroupMemberChangeInfoList) {
          memberListLog += '${memberChangeInfo.toLogString()}\n';
        }
        _logManager.updateGroupLog('onMemberInfoChanged: $groupID, memberIDs: $memberListLog');
      },
      onMemberMarkChanged: (String groupID, List<String> memberIDList, int markType, bool enableMark) {
        _logManager.updateGroupLog('onMemberMarkChanged: $groupID, memberIDList: $memberIDList, markType: $markType, enableMark: $enableMark');
      },
      onReceiveJoinApplication: (String groupID, V2TimGroupMemberInfo member, String opReason) {
        _logManager.updateGroupLog('onReceiveJoinApplication: $groupID, member: ${member.userID}, opReason: $opReason');
      },
      onApplicationProcessed: (String groupID, V2TimGroupMemberInfo opUser, bool isAgreeJoin, String opReason) {
        _logManager.updateGroupLog('onApplicationProcessed: $groupID, opUser: ${opUser.userID}, isAgreeJoin: $isAgreeJoin, opReason: $opReason');
      },
      onGrantAdministrator: (String groupID, V2TimGroupMemberInfo opUser, List<V2TimGroupMemberInfo> memberList) {
        String memberListLog = '';
        for (var member in memberList) {
          memberListLog += '${member.userID}\n';
        }
        _logManager.updateGroupLog('onGrantAdministrator: $groupID, opUser:${opUser.userID}, memberListLog: $memberListLog');
      },
      onRevokeAdministrator: (String groupID, V2TimGroupMemberInfo opUser, List<V2TimGroupMemberInfo> memberList) {
        String memberListLog = '';
        for (var member in memberList) {
          memberListLog += '${member.userID}\n';
        }
        _logManager.updateGroupLog('onRevokeAdministrator: $groupID, opUser:${opUser.userID}, memberListLog: $memberListLog');
      },
      onGroupAttributeChanged: (String groupID, Map<String, String> groupAttributeMap) {
        String attributeLog = '';
        for (var key in groupAttributeMap.keys) {
          attributeLog += '$key: ${groupAttributeMap[key]}\n';
        }
        _logManager.updateGroupLog('onGroupAttributeChanged: $groupID, groupAttributeMap: $attributeLog');
      },
      onReceiveRESTCustomData: (String groupID, String customData) {
        _logManager.updateGroupLog('onReceiveRESTCustomData: $groupID, customData: $customData');
      },
      onGroupCounterChanged: (String groupID, String key, int newValue) {
        _logManager.updateGroupLog('onGroupCounterChanged: $groupID, key: $key, newValue: $newValue');
      },
    );
  }

  // 初始化会话监听器
  void _initConversationListener() {
    _conversationListener = V2TimConversationListener(
      onSyncServerStart: () {
        _logManager.updateConversationLog('onSyncServerStart');
      },
      onSyncServerFinish: () {
        _logManager.updateConversationLog('onSyncServerFinish');
      },
      onSyncServerFailed: () {
        _logManager.updateConversationLog('onSyncServerFailed');
      },
      onNewConversation: (conversationList) {
        _logManager.updateConversationLog('onNewConversation, size: ${conversationList.length}');
        for (var conversation in conversationList) {
          _logManager.updateConversationLog('conversation: ${conversation.toLogString()}\n');
        }
      },
      onConversationChanged: (List<V2TimConversation> conversationList) {
        _logManager.updateConversationLog('onConversationChanged, size:${conversationList.length}');
        for (var conversation in conversationList) {
          _logManager.updateConversationLog('conversation: ${conversation.toLogString()}\n');
        }
      },
      onTotalUnreadMessageCountChanged: (totalUnreadCount) {
        _logManager.updateConversationLog('onTotalUnreadMessageCountChanged: $totalUnreadCount');
      },
      onConversationDeleted: (List<String> conversationIDList) {
        _logManager.updateConversationLog('onConversationDeleted: $conversationIDList');
      },
      onUnreadMessageCountChangedByFilter: (V2TimConversationFilter filter, int totalUnreadCount) {
        _logManager.updateConversationLog('onUnreadMessageCountChangedByFilter, filter:${filter.toLogString()}, totalUnreadCount:$totalUnreadCount');
      },
      onConversationGroupCreated: (String groupName, List<V2TimConversation> conversationList) {
        var logConversationIDList = '';
        for (var conversation in conversationList) {
          logConversationIDList += '${conversation.conversationID},';
        }
        _logManager.updateConversationLog('onConversationGroupCreated, groupName: $groupName, conversationList:$logConversationIDList\n');
      },
      onConversationGroupDeleted: (String groupName) {
        _logManager.updateConversationLog('onConversationGroupDeleted: $groupName');
      },
      onConversationGroupNameChanged: (String oldName, String newName) {
        _logManager.updateConversationLog('onConversationGroupNameChanged, oldName: $oldName, newName: $newName');
      },
      onConversationsAddedToGroup: (String groupName, List<V2TimConversation> conversationList) {
        var logConversationIDList = '';
        for (var conversation in conversationList) {
          logConversationIDList += '${conversation.conversationID},';
        }
        _logManager.updateConversationLog('onConversationsAddedToGroup, groupName: $groupName, conversationList:$logConversationIDList\n');
      },
      onConversationsDeletedFromGroup: (String groupName, List<V2TimConversation> conversationList) {
        var logConversationIDList = '';
        for (var conversation in conversationList) {
          logConversationIDList += '${conversation.conversationID},';
        }
        _logManager.updateConversationLog('onConversationsDeletedFromGroup, groupName: $groupName, conversationList:$logConversationIDList\n');
      },
    );
  }

  // 初始化社区监听器
  void _initCommunityListener() {
    _communityListener = V2TimCommunityListener(
      onCreateTopic: (String groupID, String topicID) {
        _logManager.updateCommunityLog('onCreateTopic|groupID:$groupID, topicID:$topicID');
      },
      onDeleteTopic: (String groupID, List<String> topicIDList) {
        _logManager.updateCommunityLog('onDeleteTopic|groupID:$groupID, topicIDList:$topicIDList');
      },
      onChangeTopicInfo: (String groupID, topicInfo) {
        _logManager.updateCommunityLog('onTopicUpdated|groupID:$groupID, topicInfo:${topicInfo.toJson()}');
      },
      onReceiveTopicRESTCustomData: (String topicID, String customData) {
        _logManager.updateCommunityLog('onReceiveTopicRESTCustomData|topicID:$topicID, customData:$customData');
      },
      onCreatePermissionGroup: (String groupID, V2TimPermissionGroupInfo permissionGroupInfo) {
        _logManager.updateCommunityLog('onCreatePermissionGroup|groupID:$groupID, permissionGroupInfo:${permissionGroupInfo.toLogString()}');
      },
      onDeletePermissionGroup: (String groupID, List<String> permissionGroupIDList) {
        _logManager.updateCommunityLog('onDeletePermissionGroup|groupID:$groupID, permissionGroupIDList:$permissionGroupIDList');
      },
      onChangePermissionGroupInfo: (String groupID, V2TimPermissionGroupInfo permissionGroupInfo) {
        _logManager.updateCommunityLog('onChangePermissionGroupInfo|groupID:$groupID, permissionGroupInfo:${permissionGroupInfo.toLogString()}');
      },
      onAddMembersToPermissionGroup: (String groupID, String permissionGroupID, List<String> memberIDList) {
        _logManager.updateCommunityLog('onAddMembersToPermissionGroup|groupID:$groupID, permissionGroupID:$permissionGroupID, memberIDList:$memberIDList');
      },
      onRemoveMembersFromPermissionGroup: (String groupID, String permissionGroupID, List<String> memberIDList) {
        _logManager.updateCommunityLog('onRemoveMembersFromPermissionGroup|groupID:$groupID, permissionGroupID:$permissionGroupID, memberIDList:$memberIDList');
      },
      onAddTopicPermission: (String groupID, String permissionGroupID, Map<String, int> topicPermissionMap) {
        _logManager.updateCommunityLog('onAddTopicPermission|groupID:$groupID, permissionGroupID:$permissionGroupID, topicPermissionMap:$topicPermissionMap');
      },
      onDeleteTopicPermission: (String groupID, String permissionGroupID, List<String> topicIDList) {
        _logManager.updateCommunityLog('onDeleteTopicPermission|groupID:$groupID, permissionGroupID:$permissionGroupID, topicIDList:$topicIDList');
      },
      onModifyTopicPermission: (String groupID, String permissionGroupID, Map<String, int> topicPermissionMap) {
        _logManager.updateCommunityLog('onModifyTopicPermission|groupID:$groupID, permissionGroupID:$permissionGroupID, topicPermissionMap:$topicPermissionMap');
      },
    );
  }

  // 初始化好友关系监听器
  void _initFriendshipListener() {
    _friendshipListener = V2TimFriendshipListener(
      onFriendApplicationListAdded: (applicationList) {
        _logManager.updateFriendshipLog('onFriendApplicationListAdded: ${applicationList.length} applications');
      },
      onFriendApplicationListDeleted: (userIDList) {
        _logManager.updateFriendshipLog('onFriendApplicationListDeleted: ${userIDList.length} applications');
      },
      onFriendApplicationListRead: () {
        _logManager.updateFriendshipLog('onFriendApplicationListRead');
      },
      onFriendListAdded: (friendInfoList) {
        _logManager.updateFriendshipLog('onFriendListAdded: ${friendInfoList.length} friends');
      },
      onFriendListDeleted: (userIDList) {
        _logManager.updateFriendshipLog('onFriendListDeleted: ${userIDList.length} friends');
      },
      onBlackListAdd: (blacklistInfoList) {
        _logManager.updateFriendshipLog('onBlacklistAdded: ${blacklistInfoList.length} users');
      },
      onBlackListDeleted: (userIDList) {
        _logManager.updateFriendshipLog('onBlacklistDeleted: ${userIDList.length} users');
      },
      onFriendInfoChanged: (friendInfoList) {
        _logManager.updateFriendshipLog('onFriendProfileChanged: ${friendInfoList.length} friends');
      },
    );
  }

  void _initSignalingListener() {
    _signalingListener = V2TimSignalingListener(
      onReceiveNewInvitation: (String inviteID, String inviter, String groupID, List<String> inviteeList, String data) {
        _logManager.updateSimpleMsgLog('onReceiveNewInvitation, inviteID:$inviteID, inviter:$inviter, groupID:$groupID, inviteeList:$inviteeList, data:$data');
      },

      onInviteeAccepted: (String inviteID, String invitee, String data) {
        _logManager.updateSimpleMsgLog('onInviteeAccepted, inviteID:$inviteID, invitee:$invitee, data:$data');
      },

      onInviteeRejected: (String inviteID, String invitee, String data) {
        _logManager.updateSimpleMsgLog('onInviteeRejected, inviteID:$inviteID, invitee:$invitee, data:$data');
      },

      onInvitationCancelled: (String inviteID, String inviter, String data) {
        _logManager.updateSimpleMsgLog('onInvitationCancelled, inviteID:$inviteID, inviter:$inviter, data:$data');
      },

      onInvitationTimeout: (String inviteID, List<String> inviteeList) {
        _logManager.updateSimpleMsgLog('onInvitationTimeout, inviteID:$inviteID, inviteeList:$inviteeList');
      },

      onInvitationModified: (String inviteID, String data,) {
        _logManager.updateSimpleMsgLog('onInvitationModified, inviteID:$inviteID, data:$data');
      }
    );
  }

  // 注册所有监听器到SDK
  void registerAllListeners() {
    if (!_isInitialized) {
      initialize();
    }

    // 注册SDK监听器（在 initSDK 时已注册）

    // 注册消息监听器
    TencentImSDKPlugin.v2TIMManager.addSimpleMsgListener(listener: _simpleMsgListener);
    TencentImSDKPlugin.v2TIMManager.getMessageManager().addAdvancedMsgListener(listener: _advancedMsgListener);

    // 注册群组监听器
    TencentImSDKPlugin.v2TIMManager.addGroupListener(listener: _groupListener);

    // 注册会话监听器
    TencentImSDKPlugin.v2TIMManager.getConversationManager().addConversationListener(listener: _conversationListener);

    // 注册社区监听器
    TencentImSDKPlugin.v2TIMManager.getCommunityManager().addCommunityListener(listener: _communityListener);

    // 注册好友关系监听器
    TencentImSDKPlugin.v2TIMManager.getFriendshipManager().addFriendListener(listener: _friendshipListener);

    // 注册信令监听器
    TencentImSDKPlugin.v2TIMManager.getSignalingManager().addSignalingListener(listener: _signalingListener);

    _logManager.updateLogText('所有监听器已注册');
  }

  // 获取SDK监听器
  V2TimSDKListener get sdkListener {
    if (!_isInitialized) {
      initialize();
    }
    return _sdkListener;
  }

  // 获取简单消息监听器
  V2TimSimpleMsgListener get simpleMsgListener {
    if (!_isInitialized) {
      initialize();
    }
    return _simpleMsgListener;
  }

  // 获取高级消息监听器
  V2TimAdvancedMsgListener get advancedMsgListener {
    if (!_isInitialized) {
      initialize();
    }
    return _advancedMsgListener;
  }

  // 获取群组监听器
  V2TimGroupListener get groupListener {
    if (!_isInitialized) {
      initialize();
    }
    return _groupListener;
  }

  // 获取会话监听器
  V2TimConversationListener get conversationListener {
    if (!_isInitialized) {
      initialize();
    }
    return _conversationListener;
  }

  // 获取社区监听器
  V2TimCommunityListener get communityListener {
    if (!_isInitialized) {
      initialize();
    }
    return _communityListener;
  }

  // 获取好友关系监听器
  V2TimFriendshipListener get friendshipListener {
    if (!_isInitialized) {
      initialize();
    }
    return _friendshipListener;
  }
} 