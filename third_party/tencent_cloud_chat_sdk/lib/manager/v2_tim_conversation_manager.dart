import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation_filter.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_filter.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation_operation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_conversation_manager.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_conversation_manager_dummy.dart';
import 'package:tencent_cloud_chat_sdk/tencent_cloud_chat_sdk_platform_interface.dart';

class V2TIMConversationManager {
  Future<void> setConversationListener({
    required V2TimConversationListener listener,
  }) {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
        .setConversationListener(listener: listener);
    }

    TIMConversationManager.instance
        .setConversationListener(listener: listener);
  
    return Future.value();
  }

  Future<void> addConversationListener({
    required V2TimConversationListener listener,
  }) {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
        .addConversationListener(listener: listener);
    }

    TIMConversationManager.instance
        .addConversationListener(listener: listener);

    return Future.value();
  }

  Future<void> removeConversationListener(
      {V2TimConversationListener? listener}) {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.removeConversationListener(
        listener: listener,
      );
    }
      
    TIMConversationManager.instance.removeConversationListener(
      listener: listener,
    );

    return Future.value();
  }

  ///   获取会话列表
  /// ```
  ///   一个会话对应一个聊天窗口，比如跟一个好友的 1v1 聊天，或者一个聊天群，都是一个会话。
  ///   由于历史的会话数量可能很多，所以该接口希望您采用分页查询的方式进行调用。
  ///   该接口拉取的是本地缓存的会话，如果服务器会话有更新，SDK 内部会自动同步，然后在 V2TIMConversationListener 回调告知客户。
  ///   该接口获取的会话列表默认已经按照会话 lastMessage -> timestamp 做了排序，timestamp 越大，会话越靠前。
  ///   如果会话全部拉取完毕，成功回调里面 V2TIMConversationResult 中的 isFinished 获取字段值为 true。
  ///   最多能拉取到最近的5000个会话。
  /// ```
  /// 参数
  ///
  ///```
  /// nextSeq	分页拉取的游标，第一次默认取传 0，后续分页拉传上一次分页拉取成功回调里的 nextSeq
  /// count	分页拉取的个数，一次分页拉取不宜太多，会影响拉取的速度，建议每次拉取 100 个会话
  /// ```
  ///
  Future<V2TimValueCallback<V2TimConversationResult>> getConversationList({
    required String nextSeq,
    required int count,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getConversationList(
        nextSeq: nextSeq,
        count: count,
      );
    }

    return TIMConversationManager.instance.getConversationList(
      nextSeq: nextSeq,
      count: count,
    );
  }

  /// 获取会话不格式化
  Future<LinkedHashMap<dynamic, dynamic>> getConversationListWithoutFormat({
    required String nextSeq,
    required int count,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
          .getConversationListWithoutFormat(
        nextSeq: nextSeq,
        count: count,
      );
    }

    return TIMConversationManager.instance.getConversationListWithoutFormat(
      nextSeq: nextSeq,
      count: count,
    );
  }

  /// 获取指定会话
  ///
  /// 参数
  ///
  /// ```
  /// conversationID	会话唯一 ID，如果是 C2C 单聊，组成方式为 c2c_userID，如果是群聊，组成方式为 group_groupID
  ///
  /// ```
  ///
  Future<V2TimValueCallback<V2TimConversation>> getConversation({
    required String conversationID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
        .getConversation(conversationID: conversationID);
    }

    return TIMConversationManager.instance
        .getConversation(conversationID: conversationID);
  }

  /// 通过会话ID获取指定会话列表
  ///
  Future<V2TimValueCallback<List<V2TimConversation>>>
      getConversationListByConversationIds({
    required List<String> conversationIDList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getConversationListByConversationIds(
          conversationIDList: conversationIDList);
    }

    return TIMConversationManager.instance.getConversationListByConversationIds(
        conversationIDList: conversationIDList);
  }

  /// 高级获取会话接口
  ///
  Future<V2TimValueCallback<V2TimConversationResult>>
      getConversationListByFilter({
    required V2TimConversationFilter filter,
    required int nextSeq,
    required int count,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getConversationListByFilter(
        filter: filter,
        nextSeq: nextSeq,
        count: count,
      );
    }

    return TIMConversationManager.instance.getConversationListByFilter(
      filter: filter,
      nextSeq: nextSeq,
      count: count,
    );
  }

  /// 会话置顶
  ///
  Future<V2TimCallback> pinConversation({
    required String conversationID,
    required bool isPinned,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
        .pinConversation(conversationID: conversationID, isPinned: isPinned);
    }

    return TIMConversationManager.instance
        .pinConversation(conversationID: conversationID, isPinned: isPinned);
  }

  /// 获取会话未读总数
  ///
  Future<V2TimValueCallback<int>> getTotalUnreadMessageCount() async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getTotalUnreadMessageCount();
    }

    return TIMConversationManager.instance.getTotalUnreadMessageCount();
  }

  /// 删除会话
  ///
  /// 请注意:
  ///
  /// ```
  /// 删除会话会在本地删除的同时，在服务器也会同步删除。
  /// 会话内的消息在本地删除的同时，在服务器也会同步删除。
  /// ```
  ///
  Future<V2TimCallback> deleteConversation({
    required String conversationID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
        .deleteConversation(conversationID: conversationID);
    }

    return TIMConversationManager.instance
        .deleteConversation(conversationID: conversationID);
  }

  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>>
      deleteConversationList({
    required List<String> conversationIDList,
    required bool clearMessage,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.deleteConversationList(
        conversationIDList: conversationIDList, clearMessage: clearMessage);
    }

    return TIMConversationManager.instance.deleteConversationList(
        conversationIDList: conversationIDList, clearMessage: clearMessage);
  }

  /// 设置会话草稿
  ///
  /// ```
  /// 只在本地保存，不会存储 Server，不能多端同步，程序卸载重装会失效。
  /// ```
  /// 参数
  ///
  /// ```
  /// draftText	草稿内容, 为 null 则表示取消草稿
  /// ```
  ///
  Future<V2TimCallback> setConversationDraft({
    required String conversationID,
    String? draftText = "",
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setConversationDraft(
        conversationID: conversationID, draftText: draftText);
    }

    return TIMConversationManager.instance.setConversationDraft(
        conversationID: conversationID, draftText: draftText);
  }

  /// 设置会话自定义数据
  /// 
  /// 自定义数据，最大支持 256 bytes
  ///
  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>>
      setConversationCustomData({
    required String customData,
    required List<String> conversationIDList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setConversationCustomData(
        customData: customData, conversationIDList: conversationIDList);
    }

    return TIMConversationManager.instance.setConversationCustomData(
        customData: customData, conversationIDList: conversationIDList);
  }

  /// 标记会话
  /// 4.0.8及以后版本支持，web不支持，且应用为旗舰版
  /// 会话分组最大支持 20 个，不再使用的分组请及时删除。
  /// 如果已有标记不能满足您的需求，您可以自定义扩展标记，扩展标记需要满足以下两个条件：
  /// 1、扩展标记值不能和 V2TIMConversation 已有的标记值冲突
  /// 扩展标记值必须是 0x1L << n 的位移值（32 <= n < 64，即 n 必须大于等于 32 并且小于 64），比如自定义 0x1L << 32 标记值表示 "iPhone 在线"
  /// 扩展标记值不能设置为 0x1 << 32，要设置为 0x1L << 32，明确告诉编译器是 64 位的整型常量
  /// flutter中使用markType可参考 V2TimConversationMarkType
  ///
  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>>
      markConversation({
    required int markType,
    required bool enableMark,
    required List<String> conversationIDList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.markConversation(
        markType: markType,
        enableMark: enableMark,
        conversationIDList: conversationIDList);
    }

    return TIMConversationManager.instance.markConversation(
        markType: markType,
        enableMark: enableMark,
        conversationIDList: conversationIDList);
  }

  /// 创建会话分组
  /// 4.0.8及以后版本支持，web不支持
  /// 会话分组最大支持 20 个，不再使用的分组请及时删除。
  ///
  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>>
      createConversationGroup({
    required String groupName,
    required List<String> conversationIDList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.createConversationGroup(
        groupName: groupName, conversationIDList: conversationIDList);
    }

    return TIMConversationManager.instance.createConversationGroup(
        groupName: groupName, conversationIDList: conversationIDList);
  }

  /// 获取会话分组列表
  /// 4.0.8及以后版本支持，web不支持
  ///
  Future<V2TimValueCallback<List<String>>> getConversationGroupList() async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getConversationGroupList();
    }

    return TIMConversationManager.instance.getConversationGroupList();
  }

  /// 删除会话分组
  /// 4.0.8及以后版本支持，web不支持
  ///
  Future<V2TimCallback> deleteConversationGroup({
    required String groupName,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
        .deleteConversationGroup(groupName: groupName);
    }

    return TIMConversationManager.instance
        .deleteConversationGroup(groupName: groupName);
  }

  /// 重命名会话分组
  /// 4.0.8及以后版本支持，web不支持
  ///
  Future<V2TimCallback> renameConversationGroup({
    required String oldName,
    required String newName,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.renameConversationGroup(
        oldName: oldName,
        newName: newName,
      );
    }

    return TIMConversationManager.instance.renameConversationGroup(
      oldName: oldName,
      newName: newName,
    );
  }

  /// 添加会话到一个会话分组
  /// 4.0.8及以后版本支持，web不支持
  ///
  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>>
      addConversationsToGroup({
    required String groupName,
    required List<String> conversationIDList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.addConversationsToGroup(
        groupName: groupName,
        conversationIDList: conversationIDList,
      );
    }

    return TIMConversationManager.instance.addConversationsToGroup(
      groupName: groupName,
      conversationIDList: conversationIDList,
    );
  }

  /// 从一个会话分组中删除会话
  /// 4.0.8及以后版本支持，web不支持
  ///
  Future<V2TimValueCallback<List<V2TimConversationOperationResult>>>
      deleteConversationsFromGroup({
    required String groupName,
    required List<String> conversationIDList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.deleteConversationsFromGroup(
        groupName: groupName,
        conversationIDList: conversationIDList,
      );
    }

    return TIMConversationManager.instance.deleteConversationsFromGroup(
      groupName: groupName,
      conversationIDList: conversationIDList,
    );
  }

  Future<V2TimValueCallback<int>> getUnreadMessageCountByFilter({
    required V2TimConversationFilter filter,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
        .getUnreadMessageCountByFilter(filter: filter);
    }

    return TIMConversationManager.instance
        .getUnreadMessageCountByFilter(filter: filter);
  }

  Future<V2TimCallback> subscribeUnreadMessageCountByFilter({
    required V2TimConversationFilter filter,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
        .subscribeUnreadMessageCountByFilter(filter: filter);
    }

    return TIMConversationManager.instance
        .subscribeUnreadMessageCountByFilter(filter: filter);
  }

  Future<V2TimCallback> unsubscribeUnreadMessageCountByFilter({
    required V2TimConversationFilter filter,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
        .unsubscribeUnreadMessageCountByFilter(filter: filter);
    }

    return TIMConversationManager.instance
        .unsubscribeUnreadMessageCountByFilter(filter: filter);
  }

  Future<V2TimCallback> cleanConversationUnreadMessageCount({
    required String conversationID,
    required int cleanTimestamp,
    required int cleanSequence,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
          .cleanConversationUnreadMessageCount(
              conversationID: conversationID,
              cleanTimestamp: cleanTimestamp,
              cleanSequence: cleanSequence);
    }

    return TIMConversationManager.instance
        .cleanConversationUnreadMessageCount(
            conversationID: conversationID,
            cleanTimestamp: cleanTimestamp,
            cleanSequence: cleanSequence);
  }
}
