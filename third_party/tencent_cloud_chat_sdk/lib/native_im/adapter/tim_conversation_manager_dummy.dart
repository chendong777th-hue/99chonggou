import 'dart:async';
import 'dart:collection';

import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_filter.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';

class TIMConversationManager {
  static TIMConversationManager instance = TIMConversationManager();

  TIMConversationManager();

  void init() {}

  void setConversationListener({
    required V2TimConversationListener listener,
  }) { }

  void addConversationListener({V2TimConversationListener? listener}) {}

  void removeConversationListener({V2TimConversationListener? listener}) {}

  Future<V2TimValueCallback<V2TimConversationResult>> getConversationList({
    required String nextSeq,
    required int count,
  }) async {
    return V2TimValueCallback<V2TimConversationResult>.fromBool(false, "invoke error");
  }

  Future<LinkedHashMap<dynamic, dynamic>> getConversationListWithoutFormat({
    required String nextSeq,
    required int count,
  }) async {
    return LinkedHashMap<dynamic, dynamic>();
  }

  Future<V2TimValueCallback<V2TimConversation>> getConversation({
    required String conversationID,
  }) async {
    return V2TimValueCallback<V2TimConversation>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimConversation>>>
      getConversationListByConversationIds({
    required List<String> conversationIDList,
  }) async {
    return V2TimValueCallback<List<V2TimConversation>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimConversationResult>> getConversationListByFilter({
    required V2TimConversationFilter filter,
    required int nextSeq,
    required int count,
  }) async {
    return V2TimValueCallback<V2TimConversationResult>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> pinConversation({
    required String conversationID,
    required bool isPinned,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<int>> getTotalUnreadMessageCount() async {
    return V2TimValueCallback<int>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> deleteConversation({
    required String conversationID,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>>
      deleteConversationList({
    required List<String> conversationIDList,
    required bool clearMessage,
  }) async {
    return V2TimValueCallback<List<V2TimConversationOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> setConversationDraft({
    required String conversationID,
    String? draftText = "",
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>>
      setConversationCustomData({
    required String customData,
    required List<String> conversationIDList,
  }) async {
    return V2TimValueCallback<List<V2TimConversationOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>>
      markConversation({
    required int markType,
    required bool enableMark,
    required List<String> conversationIDList,
  }) async {
    return V2TimValueCallback<List<V2TimConversationOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>>
      createConversationGroup({
    required String groupName,
    required List<String> conversationIDList,
  }) async {
    return V2TimValueCallback<List<V2TimConversationOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<String>>> getConversationGroupList() async {
    return V2TimValueCallback<List<String>>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> deleteConversationGroup({
    required String groupName,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> renameConversationGroup({
    required String oldName,
    required String newName,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>> addConversationsToGroup({
    required String groupName,
    required List<String> conversationIDList,
  }) async {
    return V2TimValueCallback<List<V2TimConversationOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>> deleteConversationsFromGroup({
    required String groupName,
    required List<String> conversationIDList,
  }) async {
    return V2TimValueCallback<List<V2TimConversationOperationResult>>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<int>> getUnreadMessageCountByFilter({
    required V2TimConversationFilter filter,
  }) async {
    return V2TimValueCallback<int>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> subscribeUnreadMessageCountByFilter({
    required V2TimConversationFilter filter,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> unsubscribeUnreadMessageCountByFilter({
    required V2TimConversationFilter filter,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> cleanConversationUnreadMessageCount({
    required String conversationID,
    required int cleanTimestamp,
    required int cleanSequence,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }
}