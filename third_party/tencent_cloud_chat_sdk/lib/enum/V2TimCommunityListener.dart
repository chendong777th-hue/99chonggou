// void

// void

// void

// void

// void

// void

// void

// void

// void

import 'package:tencent_cloud_chat_sdk/enum/callbacks.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_info.dart';

class V2TimCommunityListener {
  OnCreateTopic onCreateTopic = (String groupID, String topicID) {};
  OnDeleteTopic onDeleteTopic = (String groupID, List<String> topicIDList) {};
  OnChangeTopicInfo onChangeTopicInfo =
      (String groupID, V2TimTopicInfo topicInfo) {};
  OnReceiveTopicRESTCustomData onReceiveTopicRESTCustomData =
      (String topicID, String customData) {};
  OnCreatePermissionGroup onCreatePermissionGroup =
      (String groupID, V2TimPermissionGroupInfo permissionGroupInfo) {};
  OnDeletePermissionGroup onDeletePermissionGroup =
      (String groupID, List<String> permissionGroupIDList) {};
  OnChangePermissionGroupInfo onChangePermissionGroupInfo =
      (String groupID, V2TimPermissionGroupInfo permissionGroupInfo) {};
  OnAddMembersToPermissionGroup onAddMembersToPermissionGroup =
      (String groupID, String permissionGroupID, List<String> memberIDList) {};
  OnRemoveMembersFromPermissionGroup onRemoveMembersFromPermissionGroup =
      (String groupID, String permissionGroupID, List<String> memberIDList) {};
  OnAddTopicPermission onAddTopicPermission = (String groupID,
      String permissionGroupID, Map<String, int> topicPermissionMap) {};
  OnDeleteTopicPermission onDeleteTopicPermission =
      (String groupID, String permissionGroupID, List<String> topicIDList) {};
  OnModifyTopicPermission onModifyTopicPermission = (String groupID,
      String permissionGroupID, Map<String, int> topicPermissionMap) {};
  V2TimCommunityListener({
    OnCreateTopic? onCreateTopic,
    OnDeleteTopic? onDeleteTopic,
    OnChangeTopicInfo? onChangeTopicInfo,
    OnReceiveTopicRESTCustomData? onReceiveTopicRESTCustomData,
    OnCreatePermissionGroup? onCreatePermissionGroup,
    OnDeletePermissionGroup? onDeletePermissionGroup,
    OnChangePermissionGroupInfo? onChangePermissionGroupInfo,
    OnAddMembersToPermissionGroup? onAddMembersToPermissionGroup,
    OnRemoveMembersFromPermissionGroup? onRemoveMembersFromPermissionGroup,
    OnAddTopicPermission? onAddTopicPermission,
    OnDeleteTopicPermission? onDeleteTopicPermission,
    OnModifyTopicPermission? onModifyTopicPermission,
  }) {
    if (onCreateTopic != null) {
      this.onCreateTopic = onCreateTopic;
    }
    if (onDeleteTopic != null) {
      this.onDeleteTopic = onDeleteTopic;
    }
    if (onChangeTopicInfo != null) {
      this.onChangeTopicInfo = onChangeTopicInfo;
    }
    if (onReceiveTopicRESTCustomData != null) {
      this.onReceiveTopicRESTCustomData = onReceiveTopicRESTCustomData;
    }
    if (onCreatePermissionGroup != null) {
      this.onCreatePermissionGroup = onCreatePermissionGroup;
    }
    if (onDeletePermissionGroup != null) {
      this.onDeletePermissionGroup = onDeletePermissionGroup;
    }
    if (onChangePermissionGroupInfo != null) {
      this.onChangePermissionGroupInfo = onChangePermissionGroupInfo;
    }
    if (onAddMembersToPermissionGroup != null) {
      this.onAddMembersToPermissionGroup = onAddMembersToPermissionGroup;
    }
    if (onRemoveMembersFromPermissionGroup != null) {
      this.onRemoveMembersFromPermissionGroup =
          onRemoveMembersFromPermissionGroup;
    }
    if (onAddTopicPermission != null) {
      this.onAddTopicPermission = onAddTopicPermission;
    }
    if (onDeleteTopicPermission != null) {
      this.onDeleteTopicPermission = onDeleteTopicPermission;
    }
    if (onModifyTopicPermission != null) {
      this.onModifyTopicPermission = onModifyTopicPermission;
    }
  }
}
