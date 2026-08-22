import 'dart:async';

import 'package:tencent_cloud_chat_sdk/enum/V2TimCommunityListener.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_create_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_member_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_member_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_permission_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';

class TIMCommunityManager {
  static TIMCommunityManager instance = TIMCommunityManager();

  TIMCommunityManager();

  void init() {}

  void addCommunityListener(V2TimCommunityListener? listener) {}

  void removeCommunityListener({V2TimCommunityListener? listener}) {}

  Future<V2TimValueCallback<String>> createCommunity({
    required V2TimGroupInfo info,
    required List<V2TimCreateGroupMemberInfo> memberList,
  }) async {
    return V2TimValueCallback<String>.fromBool(false, "invoke error");
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

  Future<V2TimValueCallback<String>> createPermissionGroupInCommunity({
    required V2TimPermissionGroupInfo info,
  }) async {
    return V2TimValueCallback<String>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimPermissionGroupOperationResult>>> deletePermissionGroupFromCommunity({
    required String groupID,
    required List<String> permissionGroupIDList,
  }) async {
    return V2TimValueCallback<List<V2TimPermissionGroupOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> modifyPermissionGroupInfoInCommunity({
    required V2TimPermissionGroupInfo info,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimPermissionGroupInfoResult>>> getJoinedPermissionGroupListInCommunity({
    required String groupID,
  }) async {
    return V2TimValueCallback<List<V2TimPermissionGroupInfoResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimPermissionGroupInfoResult>>>
      getPermissionGroupListInCommunity({
    required String groupID,
    required List<String> permissionGroupIDList,
  }) async {
    return V2TimValueCallback<List<V2TimPermissionGroupInfoResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimPermissionGroupMemberOperationResult>>> addCommunityMembersToPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required List<String> memberList,
  }) async {
    return V2TimValueCallback<List<V2TimPermissionGroupMemberOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimPermissionGroupMemberOperationResult>>> removeCommunityMembersFromPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required List<String> memberList,
  }) async {
    return V2TimValueCallback<List<V2TimPermissionGroupMemberOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimPermissionGroupMemberInfoResult>>
      getCommunityMemberListInPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required String nextCursor,
  }) async {
    return V2TimValueCallback<V2TimPermissionGroupMemberInfoResult>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimTopicOperationResult>>>
      addTopicPermissionToPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required Map<String, int> topicPermissionMap,
  }) async {
    return V2TimValueCallback<List<V2TimTopicOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimTopicOperationResult>>>
      deleteTopicPermissionFromPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required List<String> topicIDList,
  }) async {
    return V2TimValueCallback<List<V2TimTopicOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimTopicOperationResult>>>
      modifyTopicPermissionInPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required Map<String, int> topicPermissionMap,
  }) async {
    return V2TimValueCallback<List<V2TimTopicOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimTopicPermissionResult>>>
      getTopicPermissionInPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required List<String> topicIDList,
  }) async {
    return V2TimValueCallback<List<V2TimTopicPermissionResult>>.fromBool(false, "invoke error");
  }
}