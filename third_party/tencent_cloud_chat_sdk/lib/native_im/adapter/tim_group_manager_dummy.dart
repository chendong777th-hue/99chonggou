import 'dart:async';

import 'package:tencent_cloud_chat_sdk/enum/V2TimGroupListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_add_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role_enum.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_search_param.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_search_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_search_param.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_search_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';

class TIMGroupManager {
  static TIMGroupManager instance = TIMGroupManager();

  TIMGroupManager();

  void init() {}

  void addGroupListener(V2TimGroupListener? listener) {}

  void removeGroupListener({V2TimGroupListener? listener}) {}

  Future<V2TimValueCallback<String>> createGroup({
    String? groupID,
    required String groupType,
    required String groupName,
    String? notification,
    String? introduction,
    String? faceUrl,
    bool? isAllMuted,
    bool? isSupportTopic = false,
    GroupAddOptTypeEnum? addOpt,
    List<V2TimGroupMember>? memberList,
    GroupAddOptTypeEnum? approveOpt,
    bool? isEnablePermissionGroup,
    int? defaultPermissions,
  }) async {
    return V2TimValueCallback<String>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimGroupInfo>>> getJoinedGroupList() async {
    return V2TimValueCallback<List<V2TimGroupInfo>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimGroupInfoResult>>> getGroupsInfo({
    required List<String> groupIDList,
  }) async {
    return V2TimValueCallback<List<V2TimGroupInfoResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> setGroupInfo({
    required V2TimGroupInfo info,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> initGroupAttributes({
    required String groupID,
    required Map<String, String> attributes,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> setGroupAttributes({
    required String groupID,
    required Map<String, String> attributes,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> deleteGroupAttributes({
    required String groupID,
    required List<String> keys,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<Map<String, String>>> getGroupAttributes({
    required String groupID,
    List<String>? keys,
  }) async {
    return V2TimValueCallback<Map<String, String>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<int>> getGroupOnlineMemberCount({
    required String groupID,
  }) async {
    return V2TimValueCallback<int>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimGroupMemberInfoResult>> getGroupMemberList({
    required String groupID,
    required GroupMemberFilterTypeEnum filter,
    required String nextSeq,
    int count = 15,
    int offset = 0,
  }) async {
    return V2TimValueCallback<V2TimGroupMemberInfoResult>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimGroupMemberFullInfo>>> getGroupMembersInfo({
    required String groupID,
    required List<String> memberList,
  }) async {
    return V2TimValueCallback<List<V2TimGroupMemberFullInfo>>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> setGroupMemberInfo({
    required String groupID,
    required String userID,
    String? nameCard,
    Map<String, String>? customInfo,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> muteGroupMember({
    required String groupID,
    required String userID,
    required int seconds,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> muteAllGroupMembers({
    required String groupID,
    required bool isMute,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimGroupMemberOperationResult>>> inviteUserToGroup({
    required String groupID,
    required List<String> userList,
  }) async {
    return V2TimValueCallback<List<V2TimGroupMemberOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> kickGroupMember({
    required String groupID,
    required List<String> memberList,
    int? duration,
    String? reason,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> setGroupMemberRole({
    required String groupID,
    required String userID,
    required GroupMemberRoleTypeEnum role,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> transferGroupOwner({
    required String groupID,
    required String userID,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> markGroupMemberList({
    required String groupID,
    required List<String> memberIDList,
    required int markType,
    required bool enableMark,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimGroupApplicationResult>> getGroupApplicationList() async {
    return V2TimValueCallback<V2TimGroupApplicationResult>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> acceptGroupApplication({
    required String groupID,
    String? reason,
    required String fromUser,
    required String toUser,
    int? addTime,
    GroupApplicationTypeEnum? type,
    V2TimGroupApplication? application,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> refuseGroupApplication({
    required String groupID,
    String? reason,
    required String fromUser,
    required String toUser,
    required int addTime,
    required GroupApplicationTypeEnum type,
    V2TimGroupApplication? application,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> setGroupApplicationRead() async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimGroupInfo>>> searchGroups({
    required V2TimGroupSearchParam searchParam,
  }) async {
    return V2TimValueCallback<List<V2TimGroupInfo>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimGroupSearchResult>> searchCloudGroups({
    required V2TimGroupSearchParam searchParam,
  }) async {
    return V2TimValueCallback<V2TimGroupSearchResult>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2GroupMemberInfoSearchResult>> searchGroupMembers({
    required V2TimGroupMemberSearchParam param,
  }) async {
    return V2TimValueCallback<V2GroupMemberInfoSearchResult>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2GroupMemberInfoSearchResult>> searchCloudGroupMembers({
    required V2TimGroupMemberSearchParam param,
  }) async {
    return V2TimValueCallback<V2GroupMemberInfoSearchResult>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimGroupInfo>> searchGroupByID({
    required String groupID,
  }) async {
    return V2TimValueCallback<V2TimGroupInfo>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimGroupInfo>>> getJoinedCommunityList() async {
    return V2TimValueCallback<List<V2TimGroupInfo>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<String>> createTopicInCommunity({
    required String groupID,
    required V2TimTopicInfo topicInfo,
  }) async {
    return V2TimValueCallback<String>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimTopicOperationResult>>> deleteTopicFromCommunity({
    required String groupID,
    required List<String> topicIDList,
  }) async {
    return V2TimValueCallback<List<V2TimTopicOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> setTopicInfo({
    required V2TimTopicInfo topicInfo,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimTopicInfoResult>>> getTopicInfoList({
    required String groupID,
    required List<String> topicIDList,
  }) async {
    return V2TimValueCallback<List<V2TimTopicInfoResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<Map<String, int>>> setGroupCounters({
    required String groupID,
    required Map<String, int> counters,
  }) async {
    return V2TimValueCallback<Map<String, int>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<Map<String, int>>> getGroupCounters({
    required String groupID,
    required List<String> keys,
  }) async {
    return V2TimValueCallback<Map<String, int>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<Map<String, int>>> increaseGroupCounter({
    required String groupID,
    required String key,
    required int value,
  }) async {
    return V2TimValueCallback<Map<String, int>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<Map<String, int>>> decreaseGroupCounter({
    required String groupID,
    required String key,
    required int value,
  }) async {
    return V2TimValueCallback<Map<String, int>>.fromBool(false, "invoke error");
  }
}
