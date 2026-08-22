import 'dart:async';

import 'package:tencent_cloud_chat_sdk/enum/V2TimFriendshipListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_response_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_follow_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_follow_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_follow_type_check_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_application_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_check_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_group.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_search_param.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_official_account_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';


class TIMFriendshipManager {
  static TIMFriendshipManager instance = TIMFriendshipManager();

  TIMFriendshipManager();

  void init() {}

  Future<void> setFriendListener({
    required V2TimFriendshipListener listener,
  }) {
    return Future.value();
  }

  Future<void> addFriendListener({V2TimFriendshipListener? listener}) {
    return Future.value();
  }

  Future<void> removeFriendListener({V2TimFriendshipListener? listener}) {
    return Future.value();
  }

  Future<V2TimValueCallback<List<V2TimFriendInfo>>> getFriendList() async {
    return V2TimValueCallback<List<V2TimFriendInfo>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFriendInfoResult>>> getFriendsInfo({
    required List<String> userIDList,
  }) async {
    return V2TimValueCallback<List<V2TimFriendInfoResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> setFriendInfo({
    required String userID,
    String? friendRemark,
    Map<String, String>? friendCustomInfo,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimFriendOperationResult>> addFriend({
    required String userID,
    String? remark,
    String? friendGroup,
    String? addWording,
    String? addSource,
    required FriendTypeEnum addType,
  }) async {
    return V2TimValueCallback<V2TimFriendOperationResult>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFriendOperationResult>>> deleteFromFriendList({
    required List<String> userIDList,
    required FriendTypeEnum deleteType,
  }) async {
    return V2TimValueCallback<List<V2TimFriendOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFriendCheckResult>>> checkFriend({
    required List<String> userIDList,
    required FriendTypeEnum checkType,
  }) async {
    return V2TimValueCallback<List<V2TimFriendCheckResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimFriendApplicationResult>> getFriendApplicationList() async {
    return V2TimValueCallback<V2TimFriendApplicationResult>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimFriendOperationResult>> acceptFriendApplication({
    required FriendResponseTypeEnum responseType,
    FriendApplicationTypeEnum? type,
    required String userID,
  }) async {
    return V2TimValueCallback<V2TimFriendOperationResult>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimFriendOperationResult>> refuseFriendApplication({
    FriendApplicationTypeEnum? type,
    required String userID,
  }) async {
    return V2TimValueCallback<V2TimFriendOperationResult>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> deleteFriendApplication({
    required FriendApplicationTypeEnum type,
    required String userID,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> setFriendApplicationRead() async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFriendOperationResult>>> addToBlackList({
    required List<String> userIDList,
  }) async {
    return V2TimValueCallback<List<V2TimFriendOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFriendOperationResult>>> deleteFromBlackList({
    required List<String> userIDList,
  }) async {
    return V2TimValueCallback<List<V2TimFriendOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFriendInfo>>> getBlackList() async {
    return V2TimValueCallback<List<V2TimFriendInfo>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFriendOperationResult>>> createFriendGroup({
    required String groupName,
    List<String>? userIDList,
  }) async {
    return V2TimValueCallback<List<V2TimFriendOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFriendGroup>>> getFriendGroups({
    List<String>? groupNameList,
  }) async {
    return V2TimValueCallback<List<V2TimFriendGroup>>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> deleteFriendGroup({
    required List<String> groupNameList,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> renameFriendGroup({
    required String oldName,
    required String newName,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFriendOperationResult>>> addFriendsToFriendGroup({
    required String groupName,
    required List<String> userIDList,
  }) async {
    return V2TimValueCallback<List<V2TimFriendOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFriendOperationResult>>> deleteFriendsFromFriendGroup({
    required String groupName,
    required List<String> userIDList,
  }) async {
    return V2TimValueCallback<List<V2TimFriendOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFriendInfoResult>>> searchFriends({
    required V2TimFriendSearchParam searchParam,
  }) async {
    return V2TimValueCallback<List<V2TimFriendInfoResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> subscribeOfficialAccount({
    required String officialAccountID,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> unsubscribeOfficialAccount({
    required String officialAccountID,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimOfficialAccountInfoResult>>> getOfficialAccountsInfo({
    required List<String> officialAccountIDList,
  }) async {
    return V2TimValueCallback<List<V2TimOfficialAccountInfoResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFollowOperationResult>>> followUser({
    required List<String> userIDList,
  }) async {
    return V2TimValueCallback<List<V2TimFollowOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFollowOperationResult>>> unfollowUser({
    required List<String> userIDList,
  }) async {
    return V2TimValueCallback<List<V2TimFollowOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimUserInfoResult>> getMyFollowingList({
    required String nextCursor,
  }) async {
    return V2TimValueCallback<V2TimUserInfoResult>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimUserInfoResult>> getMyFollowersList({
    required String nextCursor,
  }) async {
    return V2TimValueCallback<V2TimUserInfoResult>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimUserInfoResult>> getMutualFollowersList({
    required String nextCursor,
  }) async {
    return V2TimValueCallback<V2TimUserInfoResult>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFollowInfo>>> getUserFollowInfo({
    required List<String> userIDList,
  }) async {
    return V2TimValueCallback<List<V2TimFollowInfo>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimFollowTypeCheckResult>>> checkFollowType({
    required List<String> userIDList,
  }) async {
    return V2TimValueCallback<List<V2TimFollowTypeCheckResult>>.fromBool(false, "invoke error");
  }

}