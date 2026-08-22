// ignore_for_file: avoid_shadowing_type_parameters

import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_filter.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_follow_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_follow_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_follow_type_check_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_application_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_check_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_group.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_message_read_member_list.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_change_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_extension.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_extension_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_list_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_online_url.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_reaction_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_reaction_user_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_msg_create_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_official_account_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_member_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_member_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_receive_message_opt_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_search_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_signaling_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_permission_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'dart:convert';

dynamic decode = json.decode;
dynamic encode = json.encode;

/// V2TimValueCallback
///
/// {@category Models}
///
class V2TimValueCallback<T> {
  late int code;
  late String desc;
  T? data;
  V2TimValueCallback({
    required this.code,
    required this.desc,
    this.data,
  });

  V2TimValueCallback.fromBool(bool isSuccess, String desc)  {
    code = isSuccess ? 0 : 1;
    desc = desc;
  }

  V2TimValueCallback.fromObject(T result)  {
    code = 0;
    desc = 'success';
    data = result;
  }

  _getT<T>() => T;

  V2TimValueCallback.fromJson(Map json) {
    json = Utils.formatJson(json);
    late dynamic fromJsonData;
    if (json['data'] == null) {
      fromJsonData = data;
    } else {
      if (T == V2TimMessage) {
        fromJsonData = V2TimMessage.fromJson(json['data']) as T;
      } else if (T == V2TimUserFullInfo) {
        fromJsonData = V2TimUserFullInfo.fromJson(json['data']) as T;
      } else if (T == _getT<List<V2TimUserFullInfo>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimUserFullInfo.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimGroupInfo>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimGroupInfo.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimGroupInfoResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimGroupInfoResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<Map<String, String>>()) {
        fromJsonData = Map<String, String>.from(json['data']) as T;
      } else if (T == _getT<Map<String, int>>()) {
        fromJsonData = Map<String, int>.from(json['data']) as T;
      } else if (T == V2TimGroupMemberInfoResult) {
        fromJsonData = V2TimGroupMemberInfoResult.fromJson(json['data']) as T;
      } else if (T == _getT<List<V2TimGroupMemberFullInfo>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimGroupMemberFullInfo.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimGroupMemberOperationResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimGroupMemberOperationResult.fromJson(e);
        }).toList() as T;
      } else if (T == V2TimGroupApplicationResult) {
        fromJsonData = V2TimGroupApplicationResult.fromJson(json['data']) as T;
      } else if (T == V2TimReceiveMessageOptInfo) {
        fromJsonData = V2TimReceiveMessageOptInfo.fromJson(json['data']) as T;
      } else if (T == V2TimConversationResult) {
        fromJsonData = V2TimConversationResult.fromJson(json['data']) as T;
      } else if (T == V2TimConversation) {
        fromJsonData = V2TimConversation.fromJson(json['data']) as T;
      } else if (T == _getT<List<V2TimFriendInfo>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimFriendInfo.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimFriendInfoResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimFriendInfoResult.fromJson(e);
        }).toList() as T;
      } else if (T == V2TimFriendOperationResult) {
        fromJsonData = V2TimFriendOperationResult.fromJson(json['data']) as T;
      } else if (T == _getT<List<V2TimFriendOperationResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimFriendOperationResult.fromJson(e);
        }).toList() as T;
      } else if (T == V2TimFriendCheckResult) {
        fromJsonData = V2TimFriendCheckResult.fromJson(json['data']) as T;
      } else if (T == V2TimConversationOperationResult) {
        fromJsonData = V2TimConversationOperationResult.fromJson(json['data']) as T;
      } else if (T == _getT<List<V2TimFriendCheckResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimFriendCheckResult.fromJson(e);
        }).toList() as T;
      } else if (T == V2TimFriendApplicationResult) {
        fromJsonData = V2TimFriendApplicationResult.fromJson(json['data']) as T;
      } else if (T == _getT<List<V2TimFriendGroup>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimFriendGroup.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimMessage>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimMessage.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimOfficialAccountInfoResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimOfficialAccountInfoResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimMessageExtensionResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimMessageExtensionResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimMessageExtension>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimMessageExtension.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimConversation>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimConversation.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimReceiveMessageOptInfo>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimReceiveMessageOptInfo.fromJson(e);
        }).toList() as T;
      } else if (T == V2TimMessageSearchResult) {
        fromJsonData = V2TimMessageSearchResult.fromJson(json['data']) as T;
      } else if (T == V2GroupMemberInfoSearchResult) {
        fromJsonData = V2GroupMemberInfoSearchResult.fromJson(json['data']); // V2TimSignalingInfo
      } else if (T == V2TimSignalingInfo) {
        fromJsonData = V2TimSignalingInfo.fromJson(json['data']);
      } else if (T == V2TimMessageListResult) {
        fromJsonData = V2TimMessageListResult.fromJson(json['data']);
      } else if (T == V2TimMessageOnlineUrl) {
        fromJsonData = V2TimMessageOnlineUrl.fromJson(json['data']);
      } else if (T == V2TimMessageChangeInfo) {
        fromJsonData = V2TimMessageChangeInfo.fromJson(json['data']);
      } else if (T == V2TimMsgCreateInfoResult) {
        fromJsonData = V2TimMsgCreateInfoResult.fromJson(json['data']);
      } else if (T == V2TimUserInfoResult) {
        fromJsonData = V2TimUserInfoResult.fromJson(json['data']);
      } else if (T == V2TimGroupMessageReadMemberList) {
        fromJsonData = V2TimGroupMessageReadMemberList.fromJson(json['data']);
      } else if (T == _getT<List<V2TimMessageReceipt>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimMessageReceipt.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimPermissionGroupInfoResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimPermissionGroupInfoResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimTopicInfoResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimTopicInfoResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimFollowOperationResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimFollowOperationResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimTopicOperationResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimTopicOperationResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimGroupInfo>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimGroupInfo.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimUserStatus>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimUserStatus.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimMessageReactionResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimMessageReactionResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimConversationOperationResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimConversationOperationResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimFollowInfo>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimFollowInfo.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimFollowTypeCheckResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimFollowTypeCheckResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimPermissionGroupMemberOperationResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimPermissionGroupMemberOperationResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimPermissionGroupOperationResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimPermissionGroupOperationResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<V2TimTopicPermissionResult>>()) {
        fromJsonData = (json['data'] as List).map((e) {
          return V2TimTopicPermissionResult.fromJson(e);
        }).toList() as T;
      } else if (T == _getT<List<String>>()) {
        fromJsonData = List.from(json["data"]).map((e) => e.toString()).toList();
      } else if (T == V2TimConversationFilter) {
        fromJsonData = V2TimConversationFilter.fromJson(json['data']) as T;
      } else if (T == V2TimReceiveMessageOptInfo) {
        fromJsonData = V2TimReceiveMessageOptInfo.fromJson(json['data']) as T;
      } else if (T == V2TimMessageReactionResult) {
        fromJsonData = V2TimMessageReactionResult.fromJson(json['data']) as T;
      } else if (T == V2TimMessageReactionUserResult) {
        fromJsonData = V2TimMessageReactionUserResult.fromJson(json['data']) as T;
      } else if (T == V2TimFollowInfo) {
        fromJsonData = V2TimFollowInfo.fromJson(json['data']) as T;
      } else if (T == V2TimFollowTypeCheckResult) {
        fromJsonData = V2TimFollowTypeCheckResult.fromJson(json['data']) as T;
      } else if (T == V2TimPermissionGroupMemberInfoResult) {
        fromJsonData = V2TimPermissionGroupMemberInfoResult.fromJson(json['data']) as T;
      } else {
        fromJsonData = json['data'] as T;
      }
    }

    code = json['code'];
    desc = json['desc'] ?? '';
    data = fromJsonData;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['code'] = code;
    data['desc'] = desc;
    dynamic toJsonData = this.data;
    if (this.data == null) {
      data['data'] = this.data;
    } else {
      if (T == V2TimMessage) {
        toJsonData = (this.data as V2TimMessage).toJson();
      } else if (T == V2TimFollowTypeCheckResult) {
        toJsonData = (this.data as V2TimFollowTypeCheckResult).toJson();
      } else if (T == V2TimConversationFilter) {
        toJsonData = (this.data as V2TimConversationFilter).toJson();
      } else if (T == V2TimUserInfoResult) {
        toJsonData = (this.data as V2TimUserInfoResult).toJson();
      } else if (T == V2TimFollowInfo) {
        toJsonData = (this.data as V2TimFollowInfo).toJson();
      } else if (T == V2TimMessageListResult) {
        toJsonData = (this.data as V2TimMessageListResult).toJson();
      } else if (T == V2TimUserFullInfo) {
        toJsonData = (this.data as V2TimUserFullInfo).toJson();
      } else if (T == _getT<List<V2TimOfficialAccountInfoResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimOfficialAccountInfoResult).toJson()).toList();
      } else if (T == _getT<List<V2TimPermissionGroupMemberOperationResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimPermissionGroupMemberOperationResult).toJson()).toList();
      } else if (T == _getT<List<V2TimPermissionGroupOperationResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimPermissionGroupOperationResult).toJson()).toList();
      } else if (T == _getT<List<V2TimTopicPermissionResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimTopicPermissionResult).toJson()).toList();
      } else if (T == _getT<List<V2TimFollowInfo>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimFollowInfo).toJson()).toList();
      } else if (T == _getT<List<V2TimFollowTypeCheckResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimFollowTypeCheckResult).toJson()).toList();
      } else if (T == _getT<List<V2TimFollowOperationResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimFollowOperationResult).toJson()).toList();
      } else if (T == _getT<List<V2TimUserFullInfo>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimUserFullInfo).toJson()).toList();
      } else if (T == _getT<List<V2TimGroupInfo>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimGroupInfo).toJson()).toList();
      } else if (T == _getT<List<V2TimGroupInfoResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimGroupInfoResult).toJson()).toList();
      } else if (T == _getT<Map<String, String>>()) {
        toJsonData = this.data as Map<String, String>;
      } else if (T == _getT<Map<String, int>>()) {
        toJsonData = this.data as Map<String, int>;
      } else if (T == V2TimGroupMemberInfoResult) {
        toJsonData = (this.data as V2TimGroupMemberInfoResult).toJson();
      } else if (T == _getT<List<V2TimGroupMemberFullInfo>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimGroupMemberFullInfo).toJson()).toList();
      } else if (T == _getT<List<V2TimMessageReactionResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimMessageReactionResult).toJson()).toList();
      } else if (T == _getT<List<V2TimGroupMemberOperationResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimGroupMemberOperationResult).toJson()).toList();
      } else if (T == V2TimGroupApplicationResult) {
        toJsonData = (this.data as V2TimGroupApplicationResult).toJson();
      } else if (T == V2TimConversation) {
        toJsonData = (this.data as V2TimConversation).toJson();
      } else if (T == V2TimConversationResult) {
        toJsonData = (this.data as V2TimConversationResult).toJson();
      } else if (T == _getT<List<V2TimFriendInfo>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimFriendInfo).toJson()).toList();
      } else if (T == _getT<List<V2TimFriendInfoResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimFriendInfoResult).toJson()).toList();
      } else if (T == _getT<List<V2TimReceiveMessageOptInfo>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimReceiveMessageOptInfo).toJson()).toList();
      } else if (T == V2TimFriendOperationResult) {
        toJsonData = (this.data as V2TimFriendOperationResult).toJson();
      } else if (T == _getT<List<V2TimFriendOperationResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimFriendOperationResult).toJson()).toList();
      } else if (T == V2TimFriendCheckResult) {
        toJsonData = (this.data as V2TimFriendCheckResult).toJson();
      } else if (T == _getT<List<V2TimFriendCheckResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimFriendCheckResult).toJson()).toList();
      } else if (T == V2TimFriendApplicationResult) {
        toJsonData = (this.data as V2TimFriendApplicationResult).toJson();
      } else if (T == _getT<List<V2TimFriendGroup>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimFriendGroup).toJson()).toList();
      } else if (T == _getT<List<V2TimMessage>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimMessage).toJson()).toList();
      } else if (T == _getT<List<V2TimMessageExtensionResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimMessageExtensionResult).toJson()).toList();
      } else if (T == _getT<List<V2TimMessageExtension>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimMessageExtension).toJson()).toList();
      } else if (T == V2TimMessageSearchResult) {
        toJsonData = (this.data as V2TimMessageSearchResult).toJson();
      } else if (T == V2TimMessageOnlineUrl) {
        toJsonData = (this.data as V2TimMessageOnlineUrl).toJson();
      } else if (T == V2TimSignalingInfo) {
        toJsonData = (this.data as V2TimSignalingInfo).toJson();
      } else if (T == V2TimReceiveMessageOptInfo) {
        toJsonData = (this.data as V2TimReceiveMessageOptInfo).toJson();
      } else if (T == V2TimMsgCreateInfoResult) {
        toJsonData = (this.data as V2TimMsgCreateInfoResult).toJson();
      } else if (T == V2TimMessageChangeInfo) {
        toJsonData = (this.data as V2TimMessageChangeInfo).toJson();
      } else if (T == V2TimPermissionGroupMemberInfoResult) {
        toJsonData = (this.data as V2TimPermissionGroupMemberInfoResult).toJson();
      } else if (T == V2TimConversationOperationResult) {
        toJsonData = (this.data as V2TimConversationOperationResult).toJson();
      } else if (T == V2TimGroupMessageReadMemberList) {
        toJsonData = (this.data as V2TimGroupMessageReadMemberList).toJson();
      } else if (T == _getT<List<V2TimMessageReceipt>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimMessageReceipt).toJson()).toList();
      } else if (T == _getT<List<V2TimTopicInfoResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimTopicInfoResult).toJson()).toList();
      } else if (T == _getT<List<V2TimTopicOperationResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimTopicOperationResult).toJson()).toList();
      } else if (T == _getT<List<V2TimGroupInfo>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimGroupInfo).toJson()).toList();
      } else if (T == _getT<List<V2TimUserStatus>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimUserStatus).toJson()).toList();
      } else if (T == _getT<List<V2TimPermissionGroupInfoResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimPermissionGroupInfoResult).toJson()).toList();
      } else if (T == _getT<List<V2TimConversationOperationResult>>()) {
        toJsonData = (this.data as List).map((e) => (e as V2TimConversationOperationResult).toJson()).toList();
      } else if (T == V2TimReceiveMessageOptInfo) {
        toJsonData = (this.data as V2TimReceiveMessageOptInfo).toJson();
      } else if (T == V2TimMessageReactionResult) {
        toJsonData = (this.data as V2TimMessageReactionResult).toJson();
      } else if (T == V2TimMessageReactionUserResult) {
        toJsonData = (this.data as V2TimMessageReactionUserResult).toJson();
      } else {
        toJsonData = this.data;
      }
      data['data'] = toJsonData;
    }
    return data;
  }

  String toLogString() {
    String res = "";

    res += "$code|$desc|";

    if (this.data == null) {
      res += "null";
    } else {
      if (T == V2TimMessage) {
        res += (this.data as V2TimMessage).toLogString();
      } else if (T == V2TimFollowTypeCheckResult) {
        res += (this.data as V2TimFollowTypeCheckResult).toLogString();
      } else if (T == V2TimConversationFilter) {
        res += (this.data as V2TimConversationFilter).toLogString();
      } else if (T == V2TimUserInfoResult) {
        res += (this.data as V2TimUserInfoResult).toLogString();
      } else if (T == V2TimFollowInfo) {
        res += (this.data as V2TimFollowInfo).toLogString();
      } else if (T == V2TimMessageListResult) {
        res += (this.data as V2TimMessageListResult).toLogString();
      } else if (T == V2TimUserFullInfo) {
        res += (this.data as V2TimUserFullInfo).toLogString();
      } else if (T == _getT<List<V2TimOfficialAccountInfoResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimOfficialAccountInfoResult).toLogString()).toList());
      } else if (T == _getT<List<V2TimPermissionGroupMemberOperationResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimPermissionGroupMemberOperationResult).toLogString()).toList());
      } else if (T == _getT<List<V2TimPermissionGroupOperationResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimPermissionGroupOperationResult).toLogString()).toList());
      } else if (T == _getT<List<V2TimTopicPermissionResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimTopicPermissionResult).toLogString()).toList());
      } else if (T == _getT<List<V2TimFollowInfo>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimFollowInfo).toLogString()).toList());
      } else if (T == _getT<List<V2TimFollowTypeCheckResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimFollowTypeCheckResult).toLogString()).toList());
      } else if (T == _getT<List<V2TimFollowOperationResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimFollowOperationResult).toLogString()).toList());
      } else if (T == _getT<List<V2TimUserFullInfo>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimUserFullInfo).toLogString()).toList());
      } else if (T == _getT<List<V2TimGroupInfo>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimGroupInfo).toLogString()).toList());
      } else if (T == _getT<List<V2TimGroupInfoResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimGroupInfoResult).toLogString()).toList());
      } else if (T == _getT<Map<String, String>>()) {
        res += json.encode(this.data as Map<String, String>);
      } else if (T == _getT<Map<String, int>>()) {
        res += json.encode(this.data as Map<String, int>);
      } else if (T == V2TimGroupMemberInfoResult) {
        res += (this.data as V2TimGroupMemberInfoResult).toLogString();
      } else if (T == _getT<List<V2TimGroupMemberFullInfo>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimGroupMemberFullInfo).toLogString()).toList());
      } else if (T == _getT<List<V2TimMessageReactionResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimMessageReactionResult).toLogString()).toList());
      } else if (T == _getT<List<V2TimGroupMemberOperationResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimGroupMemberOperationResult).toLogString()).toList());
      } else if (T == V2TimGroupApplicationResult) {
        res += (this.data as V2TimGroupApplicationResult).toLogString();
      } else if (T == V2TimConversation) {
        res += (this.data as V2TimConversation).toLogString();
      } else if (T == V2TimConversationResult) {
        res += (this.data as V2TimConversationResult).toLogString();
      } else if (T == _getT<List<V2TimFriendInfo>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimFriendInfo).toLogString()).toList());
      } else if (T == _getT<List<V2TimFriendInfoResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimFriendInfoResult).toLogString()).toList());
      } else if (T == _getT<List<V2TimReceiveMessageOptInfo>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimReceiveMessageOptInfo).toLogString()).toList());
      } else if (T == V2TimFriendOperationResult) {
        res += (this.data as V2TimFriendOperationResult).toLogString();
      } else if (T == _getT<List<V2TimFriendOperationResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimFriendOperationResult).toLogString()).toList());
      } else if (T == V2TimFriendCheckResult) {
        res += (this.data as V2TimFriendCheckResult).toLogString();
      } else if (T == _getT<List<V2TimFriendCheckResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimFriendCheckResult).toLogString()).toList());
      } else if (T == V2TimFriendApplicationResult) {
        res += (this.data as V2TimFriendApplicationResult).toLogString();
      } else if (T == _getT<List<V2TimFriendGroup>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimFriendGroup).toLogString()).toList());
      } else if (T == _getT<List<V2TimMessage>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimMessage).toLogString()).toList());
      } else if (T == _getT<List<V2TimMessageExtensionResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimMessageExtensionResult).toLogString()).toList());
      } else if (T == _getT<List<V2TimMessageExtension>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimMessageExtension).toLogString()).toList());
      } else if (T == V2TimMessageSearchResult) {
        res += (this.data as V2TimMessageSearchResult).toLogString();
      } else if (T == V2TimMessageOnlineUrl) {
        res += (this.data as V2TimMessageOnlineUrl).toLogString();
      } else if (T == V2TimSignalingInfo) {
        res += (this.data as V2TimSignalingInfo).toLogString();
      } else if (T == V2TimReceiveMessageOptInfo) {
        res += (this.data as V2TimReceiveMessageOptInfo).toLogString();
      } else if (T == V2TimMsgCreateInfoResult) {
        res += (this.data as V2TimMsgCreateInfoResult).toLogString();
      } else if (T == V2TimMessageChangeInfo) {
        res += (this.data as V2TimMessageChangeInfo).toLogString();
      } else if (T == V2TimPermissionGroupMemberInfoResult) {
        res += (this.data as V2TimPermissionGroupMemberInfoResult).toLogString();
      } else if (T == V2TimConversationOperationResult) {
        res += (this.data as V2TimConversationOperationResult).toLogString();
      } else if (T == V2TimGroupMessageReadMemberList) {
        res += (this.data as V2TimGroupMessageReadMemberList).toLogString();
      } else if (T == _getT<List<V2TimMessageReceipt>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimMessageReceipt).toLogString()).toList());
      } else if (T == _getT<List<V2TimTopicInfoResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimTopicInfoResult).toLogString()).toList());
      } else if (T == _getT<List<V2TimTopicOperationResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimTopicOperationResult).toJson()).toList());
      } else if (T == _getT<List<V2TimGroupInfo>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimGroupInfo).toLogString()).toList());
      } else if (T == _getT<List<V2TimUserStatus>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimUserStatus).toLogString()).toList());
      } else if (T == _getT<List<V2TimPermissionGroupInfoResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimPermissionGroupInfoResult).toLogString()).toList());
      } else if (T == _getT<List<V2TimConversationOperationResult>>()) {
        res += json.encode((this.data as List).map((e) => (e as V2TimConversationOperationResult).toLogString()).toList());
      } else if (T == V2TimReceiveMessageOptInfo) {
        res += (this.data as V2TimReceiveMessageOptInfo).toLogString();
      } else if (T == V2TimMessageReactionResult) {
        res += (this.data as V2TimMessageReactionResult).toLogString();
      } else if (T == V2TimMessageReactionUserResult) {
        res += (this.data as V2TimMessageReactionUserResult).toLogString();
      } else {
        res = "$res|${this.data}";
      }
    }
    return res;
  }
}
