// void 	onMemberEnter (String groupID, List< V2TIMGroupMemberInfo > memberList)

// void 	onMemberLeave (String groupID, V2TIMGroupMemberInfo member)

// void 	onMemberInvited (String groupID, V2TIMGroupMemberInfo opUser, List< V2TIMGroupMemberInfo > memberList)

// void 	onMemberKicked (String groupID, V2TIMGroupMemberInfo opUser, List< V2TIMGroupMemberInfo > memberList)

// void 	onMemberInfoChanged (String groupID, List< V2TIMGroupMemberChangeInfo > v2TIMGroupMemberChangeInfoList)

// void 	onGroupCreated (String groupID)

// void 	onGroupDismissed (String groupID, V2TIMGroupMemberInfo opUser)

// void 	onGroupRecycled (String groupID, V2TIMGroupMemberInfo opUser)

// void 	onGroupInfoChanged (String groupID, List< V2TIMGroupChangeInfo > changeInfos)

// void 	onReceiveJoinApplication (String groupID, V2TIMGroupMemberInfo member, String opReason)

// void 	onApplicationProcessed (String groupID, V2TIMGroupMemberInfo opUser, boolean isAgreeJoin, String opReason)

// void 	onGrantAdministrator (String groupID, V2TIMGroupMemberInfo opUser, List< V2TIMGroupMemberInfo > memberList)

// void 	onRevokeAdministrator (String groupID, V2TIMGroupMemberInfo opUser, List< V2TIMGroupMemberInfo > memberList)

// void 	onQuitFromGroup (String groupID)

// void 	onReceiveRESTCustomData (String groupID, byte[] customData)

// void 	onGroupAttributeChanged (String groupID, Map< String, String > groupAttributeMap)

// ignore_for_file: file_names, prefer_function_declarations_over_variables

import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';

import 'callbacks.dart';

class V2TimGroupListener {
  OnMemberEnterCallback onMemberEnter = (
    String groupID,
    List<V2TimGroupMemberInfo> memberList,
  ) {};
  OnMemberLeaveCallback onMemberLeave = (
    String groupID,
    V2TimGroupMemberInfo member,
  ) {};
  OnMemberInvitedCallback onMemberInvited = (
    String groupID,
    V2TimGroupMemberInfo opUser,
    List<V2TimGroupMemberInfo> memberList,
  ) {};
  OnMemberKickedCallback onMemberKicked = (
    String groupID,
    V2TimGroupMemberInfo opUser,
    List<V2TimGroupMemberInfo> memberList,
  ) {};
  OnMemberInfoChangedCallback onMemberInfoChanged = (
    String groupID,
    List<V2TimGroupMemberChangeInfo> v2TIMGroupMemberChangeInfoList,
  ) {};
  OnGroupCreatedCallback onGroupCreated = (String groupID) {};
  OnGroupDismissedCallback onGroupDismissed = (
    String groupID,
    V2TimGroupMemberInfo opUser,
  ) {};
  OnGroupRecycledCallback onGroupRecycled = (
    String groupID,
    V2TimGroupMemberInfo opUser,
  ) {};
  OnGroupInfoChangedCallback onGroupInfoChanged = (
    String groupID,
    List<V2TimGroupChangeInfo?> changeInfos,
  ) {};
  OnReceiveJoinApplicationCallback onReceiveJoinApplication = (
    String groupID,
    V2TimGroupMemberInfo member,
    String opReason,
  ) {};
  OnApplicationProcessedCallback onApplicationProcessed = (
    String groupID,
    V2TimGroupMemberInfo opUser,
    bool isAgreeJoin,
    String opReason,
  ) {};
  OnGrantAdministratorCallback onGrantAdministrator = (
    String groupID,
    V2TimGroupMemberInfo opUser,
    List<V2TimGroupMemberInfo> memberList,
  ) {};
  OnRevokeAdministratorCallback onRevokeAdministrator = (
    String groupID,
    V2TimGroupMemberInfo opUser,
    List<V2TimGroupMemberInfo> memberList,
  ) {};
  OnQuitFromGroupCallback onQuitFromGroup = (String groupID) {};
  OnReceiveRESTCustomDataCallback onReceiveRESTCustomData = (
    String groupID,
    String customData,
  ) {};
  OnGroupAttributeChangedCallback onGroupAttributeChanged = (
    String groupID,
    Map<String, String> groupAttributeMap,
  ) {};
  OnTopicCreated onTopicCreated = (String groupID, String topicID) {};

  OnTopicDeleted onTopicDeleted = (String groupID, List<String> topicIDList) {};

  OnTopicInfoChanged onTopicInfoChanged = (
    String groupID,
    V2TimTopicInfo topicInfo,
  ) {};
  OnGroupCounterChanged onGroupCounterChanged = (
    groupID,
    key,
    newValue,
  ) {};
  OnAllGroupMembersMuted onAllGroupMembersMuted =
      (String groupID, bool isMute) {};
  OnMemberMarkChanged onMemberMarkChanged = (String groupID,
      List<String> memberIDList, int markType, bool enableMark) {};

  V2TimGroupListener({
    OnGroupCreatedCallback? onGroupCreated,
    OnGroupDismissedCallback? onGroupDismissed,
    OnGroupRecycledCallback? onGroupRecycled,
    OnGroupInfoChangedCallback? onGroupInfoChanged,
    OnMemberEnterCallback? onMemberEnter,
    OnMemberLeaveCallback? onMemberLeave,
    OnMemberInvitedCallback? onMemberInvited,
    OnMemberKickedCallback? onMemberKicked,
    OnQuitFromGroupCallback? onQuitFromGroup,
    OnAllGroupMembersMuted? onAllGroupMembersMuted,
    OnMemberInfoChangedCallback? onMemberInfoChanged,
    OnMemberMarkChanged? onMemberMarkChanged,
    OnReceiveJoinApplicationCallback? onReceiveJoinApplication,
    OnApplicationProcessedCallback? onApplicationProcessed,
    OnGrantAdministratorCallback? onGrantAdministrator,
    OnRevokeAdministratorCallback? onRevokeAdministrator,
    OnGroupAttributeChangedCallback? onGroupAttributeChanged,
    OnGroupCounterChanged? onGroupCounterChanged,
    OnReceiveRESTCustomDataCallback? onReceiveRESTCustomData,
    OnTopicCreated? onTopicCreated,
    OnTopicDeleted? onTopicDeleted,
    OnTopicInfoChanged? onTopicInfoChanged,
  }) {
    if (onGroupCreated != null) {
      this.onGroupCreated = onGroupCreated;
    }
    if (onGroupDismissed != null) {
      this.onGroupDismissed = onGroupDismissed;
    }
    if (onGroupRecycled != null) {
      this.onGroupRecycled = onGroupRecycled;
    }
    if (onGroupInfoChanged != null) {
      this.onGroupInfoChanged = onGroupInfoChanged;
    }
    if (onMemberEnter != null) {
      this.onMemberEnter = onMemberEnter;
    }
    if (onMemberLeave != null) {
      this.onMemberLeave = onMemberLeave;
    }
    if (onMemberInvited != null) {
      this.onMemberInvited = onMemberInvited;
    }
    if (onMemberKicked != null) {
      this.onMemberKicked = onMemberKicked;
    }
    if (onQuitFromGroup != null) {
      this.onQuitFromGroup = onQuitFromGroup;
    }
    if (onAllGroupMembersMuted != null) {
      this.onAllGroupMembersMuted = onAllGroupMembersMuted;
    }
    if (onMemberInfoChanged != null) {
      this.onMemberInfoChanged = onMemberInfoChanged;
    }
    if (onMemberMarkChanged != null) {
      this.onMemberMarkChanged = onMemberMarkChanged;
    }
    if (onReceiveJoinApplication != null) {
      this.onReceiveJoinApplication = onReceiveJoinApplication;
    }
    if (onApplicationProcessed != null) {
      this.onApplicationProcessed = onApplicationProcessed;
    }
    if (onGrantAdministrator != null) {
      this.onGrantAdministrator = onGrantAdministrator;
    }
    if (onRevokeAdministrator != null) {
      this.onRevokeAdministrator = onRevokeAdministrator;
    }
    if (onGroupAttributeChanged != null) {
      this.onGroupAttributeChanged = onGroupAttributeChanged;
    }
    if (onGroupCounterChanged != null) {
      this.onGroupCounterChanged = onGroupCounterChanged;
    }
    if (onReceiveRESTCustomData != null) {
      this.onReceiveRESTCustomData = onReceiveRESTCustomData;
    }
    if (onTopicCreated != null) {
      this.onTopicCreated = onTopicCreated;
    }
    if (onTopicDeleted != null) {
      this.onTopicDeleted = onTopicDeleted;
    }
    if (onTopicInfoChanged != null) {
      this.onTopicInfoChanged = onTopicInfoChanged;
    }
  }
}
