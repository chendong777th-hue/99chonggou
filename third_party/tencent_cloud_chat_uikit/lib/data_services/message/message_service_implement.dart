// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSimpleMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/get_group_message_read_member_list_filter.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_priority_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_message_read_member_list.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_message_read_member_list.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_list_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_list_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_online_url.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_online_url.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_msg_create_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_msg_create_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/conversation_notify_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'message_web_history_loader_stub.dart'
    if (dart.library.html) 'message_web_history_loader_web.dart';
import 'outgoing_message_send_queue.dart';

class MessageServiceImpl extends MessageService {
  final CoreServicesImpl _coreService = serviceLocator<CoreServicesImpl>();
  final Map<String, List<V2TimMessage>> messageListMap = {};
  final Map<String, List<V2TimMessage>> sendingMessage = {};

  static const Duration _groupReadMinInterval = Duration(seconds: 5);
  static const Duration _groupReadFrequencyBackoff = Duration(seconds: 12);
  static const Set<int> _groupReadFrequencyCodes = <int>{-10113, 6015, 7008};
  static final Map<String, Future<V2TimCallback>> _groupReadInFlight = {};
  static final Map<String, Future<V2TimCallback>> _groupReadDeferred = {};
  static final Map<String, DateTime> _groupReadLastSuccess = {};
  static final Map<String, DateTime> _groupReadBlockedUntil = {};
  static final Set<String> _groupReadNeedsTrailing = <String>{};

  bool _isSoftWebSdkError(Object error) {
    if (!PlatformUtils().isWeb) {
      return false;
    }
    final text = error.toString();
    return text.contains('Unexpected null value') ||
        text.contains('Future already completed') ||
        text.contains("NoSuchMethodError: 'message'") ||
        text.contains('TypeErrorImpl');
  }

  void _printSoftWebSdkError(String scope, Object error) {
    if (kDebugMode) {
      debugPrint('$scope: $error');
    }
  }

  @override
  Future<MessageListResponse> getHistoryMessageListV2({
    HistoryMsgGetTypeEnum getType = HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
    String? userID,
    String? groupID,
    int lastMsgSeq = -1,
    required int count,
    String? lastMsgID,
    List<int>? messageTypeList,
  }) async {
    bool haveMoreData = true;
    try {
      if (PlatformUtils().isWeb) {
        final webRes = await WebHistoryLoader.loadWithComplete(
          count: count,
          getType: getType,
          userID: userID,
          groupID: groupID,
          lastMsgID: lastMsgID,
          lastMsgSeq: lastMsgSeq,
          messageTypeList: messageTypeList,
        );
        if (webRes != null) {
          final conversationID = userID ?? groupID;
          final responseMessageList = webRes.messageList;
          final cachedMessageList = messageListMap[conversationID];
          List<V2TimMessage> combinedMessageList = [];
          if (lastMsgID != null && cachedMessageList != null) {
            combinedMessageList = [...cachedMessageList, ...responseMessageList];
          } else {
            final bool existSendingMessage =
                sendingMessage[conversationID] != null && sendingMessage[conversationID]!.isNotEmpty;
            if (existSendingMessage) {
              combinedMessageList = [...sendingMessage[conversationID]!, ...responseMessageList];
            } else {
              sendingMessage.remove(conversationID);
              combinedMessageList = responseMessageList;
            }
          }
          return MessageListResponse(
            haveMoreData: !webRes.isFinished,
            data: combinedMessageList,
          );
        }
      }
      final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager().getHistoryMessageList(
          count: count,
          getType: getType,
          userID: userID,
          groupID: groupID,
          lastMsgID: lastMsgID,
          lastMsgSeq: lastMsgSeq,
          messageTypeList: messageTypeList);
      final List<V2TimMessage> responseMessageList = res.data ?? [];
      final conversationID = userID ?? groupID;
      final cachedMessageList = messageListMap[conversationID];
      List<V2TimMessage> combinedMessageList = [];
      if (lastMsgID != null && cachedMessageList != null) {
        combinedMessageList = [...cachedMessageList, ...responseMessageList];
      } else {
        final bool existSendingMessage =
            sendingMessage[conversationID] != null && sendingMessage[conversationID]!.isNotEmpty;
        if (existSendingMessage) {
          combinedMessageList = [...sendingMessage[conversationID]!, ...responseMessageList];
        } else {
          sendingMessage.remove(conversationID);
          combinedMessageList = responseMessageList;
        }
      }
      if (res.code != 0) {
        _coreService
            .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      }
      if (responseMessageList.isEmpty ||
          (!PlatformUtils().isWeb && responseMessageList.length < count) ||
          (PlatformUtils().isWeb && responseMessageList.length < min(count, 20))) {
        haveMoreData = false;
      } else {
        haveMoreData = true;
      }
      return MessageListResponse(haveMoreData: haveMoreData, data: combinedMessageList);
    } catch (e) {
      if (_isSoftWebSdkError(e)) {
        _printSoftWebSdkError('load messages fallback failed on web', e);
        final conversationID = userID ?? groupID;
        return MessageListResponse(
          haveMoreData: false,
          data: messageListMap[conversationID] ?? const [],
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<V2TimMessage>> getHistoryMessageList({
    HistoryMsgGetTypeEnum getType = HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
    String? userID,
    String? groupID,
    int lastMsgSeq = -1,
    required int count,
    String? lastMsgID,
    V2TimMessage? lastMsg,
    List<int>? messageTypeList,
  }) async {
    try {
      if (PlatformUtils().isWeb) {
        final webList = await WebHistoryLoader.loadList(
          count: count,
          getType: getType,
          userID: userID,
          groupID: groupID,
          lastMsgID: lastMsgID,
          lastMsgSeq: lastMsgSeq,
          messageTypeList: messageTypeList,
        );
        if (webList != null) {
          return webList;
        }
      }
      final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager().getHistoryMessageList(
          count: count,
          getType: getType,
          userID: userID,
          groupID: groupID,
          lastMsg: lastMsg,
          lastMsgID: lastMsgID,
          lastMsgSeq: lastMsgSeq,
          messageTypeList: messageTypeList);
      final reponseMessageList = res.data ?? [];
      ChatHistoryTrace.log(
        'sdk_get_history',
        conversationID: groupID ?? userID,
        extras: <String, Object?>{
          'api': 'getHistoryMessageList',
          'getType': getType.index,
          'isGroup': groupID != null,
          'reqCount': count,
          'lastMsgID': lastMsgID,
          'lastMsgSeq': lastMsgSeq,
          'code': res.code,
          'desc': res.desc,
          'dataLen': reponseMessageList.length,
        },
      );
      if (res.code != 0) {
        _coreService
            .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      }
      return reponseMessageList;
    } catch (e) {
      if (_isSoftWebSdkError(e)) {
        _printSoftWebSdkError('load messages fallback failed on web', e);
        return const [];
      }
      rethrow;
    }
  }

  @override
  Future<V2TimMessageListResult?> getHistoryMessageListWithComplete({
    HistoryMsgGetTypeEnum getType = HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
    String? userID,
    String? groupID,
    int lastMsgSeq = 0,
    required int count,
    String? lastMsgID,
    V2TimMessage? lastMsg,
    List<int>? messageTypeList,
    List<int>? messageSeqList,
    int? timeBegin,
    int? timePeriod,
  }) async {
    try {
      if (PlatformUtils().isWeb) {
        // Web hopping 不支持 timeBegin/timePeriod/messageSeqList；按洞 IM 在上层跳过。
        final webRes = await WebHistoryLoader.loadWithComplete(
          count: count,
          getType: getType,
          userID: userID,
          groupID: groupID,
          lastMsgID: lastMsgID,
          lastMsgSeq: lastMsgSeq,
          messageTypeList: messageTypeList,
        );
        if (webRes != null) {
          return webRes;
        }
      }
      final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager().getHistoryMessageListV2(
          count: count,
          getType: getType,
          userID: userID,
          groupID: groupID,
          lastMsg: lastMsg,
          lastMsgID: lastMsgID,
          lastMsgSeq: lastMsgSeq,
          messageTypeList: messageTypeList,
          messageSeqList: messageSeqList,
          timeBegin: timeBegin,
          timePeriod: timePeriod);
      final responseMessageList = res.data;
      ChatHistoryTrace.log(
        'sdk_get_history',
        conversationID: groupID ?? userID,
        extras: <String, Object?>{
          'api': 'getHistoryMessageListWithComplete',
          'getType': getType.index,
          'isGroup': groupID != null,
          'reqCount': count,
          'lastMsgID': lastMsgID,
          'lastMsgSeq': lastMsgSeq,
          'code': res.code,
          'desc': res.desc,
          'dataLen': responseMessageList?.messageList.length,
          'isFinished': responseMessageList?.isFinished,
        },
      );
      if (res.code != 0) {
        _coreService
            .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      }
      return responseMessageList;
    } catch (e) {
      if (_isSoftWebSdkError(e)) {
        _printSoftWebSdkError('load messages fallback failed on web', e);
        return null;
      }
      rethrow;
    }
  }

  @override
  Future addSimpleMsgListener({
    required V2TimSimpleMsgListener listener,
  }) async {
    return TencentImSDKPlugin.v2TIMManager.addSimpleMsgListener(listener: listener);
  }

  @override
  Future<void> removeSimpleMsgListener({V2TimSimpleMsgListener? listener}) {
    return TencentImSDKPlugin.v2TIMManager.removeSimpleMsgListener(listener: listener);
  }

  @override
  Future<void> addAdvancedMsgListener({
    required V2TimAdvancedMsgListener listener,
  }) async {
    try {
      await TencentImSDKPlugin.v2TIMManager
          .getMessageManager()
          .addAdvancedMsgListener(listener: listener);
    } catch (e) {
      if (_isSoftWebSdkError(e)) {
        _printSoftWebSdkError('message listener ignored on web', e);
        return;
      }
      rethrow;
    }
  }

  @override
  Future<V2TimValueCallback<V2TimGroupMessageReadMemberList>> getGroupMessageReadMemberList({
    required String messageID,
    required GetGroupMessageReadMemberListFilter filter,
    int nextSeq = 0,
    int count = 100,
  }) async {
    if (PlatformUtils().isWeb) {
      return V2TimValueCallback<V2TimGroupMessageReadMemberList>(
        code: 0,
        desc: '',
        data: V2TimGroupMessageReadMemberList(
          nextSeq: 0,
          isFinished: true,
          memberInfoList: const [],
        ),
      );
    }
    final result = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .getGroupMessageReadMemberList(messageID: messageID, filter: filter, nextSeq: nextSeq, count: count);
    if (result.code != 0 && !(PlatformUtils().isWeb && result.code == 10007)) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  @override
  Future<V2TimValueCallback<List<V2TimMessageReceipt>>> getMessageReadReceipts({
    required List<String> messageIDList,
  }) async {
    if (PlatformUtils().isWeb) {
      return V2TimValueCallback<List<V2TimMessageReceipt>>(
        code: 0,
        desc: '',
        data: const [],
      );
    }
    final result =
        await TencentImSDKPlugin.v2TIMManager.getMessageManager().getMessageReadReceipts(messageIDList: messageIDList);
    if (result.code != 0 && !(PlatformUtils().isWeb && result.code == 10007)) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  @override
  Future<V2TimCallback> sendMessageReadReceipts({
    required List<String> messageIDList,
  }) async {
    if (PlatformUtils().isWeb) {
      return V2TimCallback(code: 0, desc: '');
    }
    return _retryMarkMessageAsRead(action: () {
      return TencentImSDKPlugin.v2TIMManager.getMessageManager().sendMessageReadReceipts(messageIDList: messageIDList);
    });
  }

  @override
  Future<V2TimMsgCreateInfoResult?> createTextMessage({required String text}) async {
    final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager().createTextMessage(text: text);
    if (res.code == 0) {
      final messageResult = res.data;
      return messageResult;
    }
    _coreService.callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    return null;
  }

  @override
  Future<V2TimMsgCreateInfoResult?> createCustomMessage({required String data}) async {
    final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager().createCustomMessage(data: data);
    if (res.code == 0) {
      final messageResult = res.data;
      return messageResult;
    }
    _coreService.callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    return null;
  }

  @override
  Future<V2TimMsgCreateInfoResult?> createFaceMessage({required int index, required String data}) async {
    final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager().createFaceMessage(index: index, data: data);
    if (res.code == 0) {
      final messageResult = res.data;
      return messageResult;
    }
    _coreService.callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    return null;
  }

  @override
  Future<V2TimValueCallback<V2TimMessage>> reSendMessage({required String msgID, bool? onlineUserOnly}) async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .reSendMessage(msgID: msgID, onlineUserOnly: onlineUserOnly ?? false);
    if (res.code != 0) {
      String recommendText = ErrorMessageConverter.getErrorMessage(res.code, res.desc);
      _coreService.callOnCallback(TIMCallback(
          type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code, infoRecommendText: recommendText));
    }
    return res;
  }

  @override
  Future<V2TimMsgCreateInfoResult?> createTextAtMessage(
      {required String text, required List<String> atUserList}) async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .createTextAtMessage(text: text, atUserList: atUserList);
    if (res.code == 0) {
      final messageResult = res.data;
      return messageResult;
    }
    _coreService.callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    return null;
  }

  @override
  Future<V2TimMsgCreateInfoResult?> createImageMessage(
      {String? imageName, String? imagePath, dynamic inputElement}) async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .createImageMessage(imageName: imageName, imagePath: imagePath ?? "", inputElement: inputElement);
    if (res.code == 0) {
      return res.data;
    }
    _coreService.callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    return null;
  }

  @override
  Future<V2TimMsgCreateInfoResult?> createSoundMessage({
    required String soundPath,
    required int duration,
  }) async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .createSoundMessage(soundPath: soundPath, duration: duration);
    if (res.code == 0) {
      return res.data;
    }
    _coreService.callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    return null;
  }

  @override
  Future<V2TimValueCallback<V2TimMessage>> sendMessage({
    required String id, // 自己创建的ID
    required String receiver,
    required String groupID,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool onlineUserOnly = false,
    bool isExcludedFromUnreadCount = false,
    bool needReadReceipt = false,
    OfflinePushInfo? offlinePushInfo,
    String? cloudCustomData,
    String? localCustomData,
    bool isExcludedFromContentModeration = false,
  }) async {
    final toOfficialAccount =
        groupID.isEmpty && _isOfficialAccountUserId(receiver);
    if (toOfficialAccount) {
      await _ensureOfficialAccountSubscribed(receiver);
      needReadReceipt = false;
    }
    // 社群（@TGS#_… / @TGS#_@TGS#…）不支持已读回执；硬关避免 6017 导致发送失败。
    if (needReadReceipt && _looksLikeCommunityGroupId(groupID)) {
      needReadReceipt = false;
    }
    final convKey = OutgoingMessageSendQueue.conversationKey(
      receiver: receiver,
      groupID: groupID,
    );
    return OutgoingMessageSendQueue.instance.runSerial(
      convKey,
      () => _sendMessageNow(
        id: id,
        receiver: receiver,
        groupID: groupID,
        priority: priority,
        onlineUserOnly: onlineUserOnly,
        offlinePushInfo: offlinePushInfo,
        needReadReceipt: needReadReceipt,
        localCustomData: localCustomData,
        cloudCustomData: cloudCustomData,
        isExcludedFromContentModeration: isExcludedFromContentModeration,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount,
        toOfficialAccount: toOfficialAccount,
      ),
    );
  }

  Future<V2TimValueCallback<V2TimMessage>> _sendMessageNow({
    required String id,
    required String receiver,
    required String groupID,
    required MessagePriorityEnum priority,
    required bool onlineUserOnly,
    required bool needReadReceipt,
    required bool isExcludedFromUnreadCount,
    required bool isExcludedFromContentModeration,
    required bool toOfficialAccount,
    OfflinePushInfo? offlinePushInfo,
    String? cloudCustomData,
    String? localCustomData,
  }) async {
    debugPrint(
      '[IM_SEND] id=$id receiver=$receiver groupID=$groupID onlineOnly=$onlineUserOnly',
    );
    final convID = groupID.trim().isNotEmpty ? groupID.trim() : receiver.trim();
    final result = await TencentImSDKPlugin.v2TIMManager.getMessageManager().sendMessage(
          id: id,
          receiver: receiver,
          groupID: groupID,
          priority: priority,
          onlineUserOnly: onlineUserOnly,
          offlinePushInfo: offlinePushInfo,
          needReadReceipt: needReadReceipt,
          localCustomData: localCustomData,
          cloudCustomData: cloudCustomData,
          isExcludedFromContentModeration: isExcludedFromContentModeration,
          isExcludedFromUnreadCount: isExcludedFromUnreadCount,
          onSyncMsgID: (syncMsgID) {
            if (convID.isEmpty || syncMsgID.trim().isEmpty) {
              return;
            }
            try {
              serviceLocator<TUIChatGlobalModel>().bindOutgoingSyncMsgId(
                convID,
                id,
                syncMsgID,
              );
            } catch (_) {}
          },
        );
    if (result.code != 0) {
      debugPrint(
        '[IM_SEND_FAIL] id=$id code=${result.code} desc=${result.desc} receiver=$receiver groupID=$groupID',
      );
      String recommendText = ErrorMessageConverter.getErrorMessage(result.code, result.desc);
      if (toOfficialAccount) {
        final officialText =
            officialAccountSendErrorText(result.code, result.desc);
        if (officialText.isNotEmpty) {
          recommendText = officialText;
        }
      }
      _coreService.callOnCallback(TIMCallback(
          type: TIMCallbackType.API_ERROR,
          errorMsg: result.desc,
          errorCode: result.code,
          infoRecommendText: recommendText));
    } else {
      debugPrint(
        '[IM_SEND_DONE] id=$id msgID=${result.data?.msgID} status=${result.data?.status} code=${result.code} seq=${result.data?.seq}',
      );
    }
    return result;
  }

  @override
  Future<V2TimCallback> deleteMessageFromLocalStorage({
    required String msgID,
    Object? webMessageInstance,
  }) async {
    V2TimCallback result;
    if (kIsWeb) {
      result = await TencentImSDKPlugin.v2TIMManager
          .getMessageManager()
          .deleteMessages(msgIDs: [], webMessageInstanceList: [webMessageInstance]);
    } else {
      result = await TencentImSDKPlugin.v2TIMManager.getMessageManager().deleteMessageFromLocalStorage(msgID: msgID);
    }

    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  @override
  Future<V2TimCallback> revokeMessage({required String msgID, Object? webMessageInstance}) async {
    final result = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .revokeMessage(msgID: msgID, webMessageInstatnce: webMessageInstance);
    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  @override
  Future<V2TimCallback> clearC2CHistoryMessage({
    required String userID,
  }) async {
    final result = await TencentImSDKPlugin.v2TIMManager.getMessageManager().clearC2CHistoryMessage(userID: userID);
    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  @override
  Future<V2TimCallback> clearGroupHistoryMessage({
    required String groupID,
  }) async {
    final result = await TencentImSDKPlugin.v2TIMManager.getMessageManager().clearGroupHistoryMessage(groupID: groupID);
    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  bool _isOfficialAccountUserId(String? userId) {
    return userId != null && userId.startsWith('@TOA#_');
  }

  /// 社群 ID：`@TGS#_…`（含默认分配 `@TGS#_@TGS#…`）。公开群 `@TGS#{数字}` 不含。
  bool _looksLikeCommunityGroupId(String? input) {
    var id = input?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    if (id.length > 6 && id.toLowerCase().startsWith('group_')) {
      id = id.substring(6);
    }
    final upper = id.toUpperCase();
    return upper.startsWith('@TGS#_') || upper.startsWith('TGS#_');
  }

  bool _isOfficialAccountSubscribeOk(int code, String? desc) {
    if (code == 0) {
      return true;
    }
    final lower = (desc ?? '').toLowerCase();
    if (lower.contains('already') &&
        (lower.contains('subscrib') || lower.contains('follow'))) {
      return true;
    }
    final raw = desc ?? '';
    if (raw.contains('已经') && raw.contains('订阅')) {
      return true;
    }
    if (raw.contains('重复') && raw.contains('订阅')) {
      return true;
    }
    return false;
  }

  Future<void> _ensureOfficialAccountSubscribed(String receiver) async {
    if (!_isOfficialAccountUserId(receiver)) {
      return;
    }
    final friendshipManager =
        TencentImSDKPlugin.v2TIMManager.getFriendshipManager();
    final subscribeRes = await friendshipManager.subscribeOfficialAccount(
      officialAccountID: receiver,
    );
    if (!_isOfficialAccountSubscribeOk(subscribeRes.code, subscribeRes.desc)) {
      debugPrint(
        'subscribeOfficialAccount before send failed: '
        '${subscribeRes.code} ${subscribeRes.desc}',
      );
    }
  }

  static String officialAccountSendErrorText(int code, String? desc) {
    if (code != 131006) {
      return '';
    }
    final lower = (desc ?? '').toLowerCase();
    if (lower.contains('not open') &&
        (lower.contains('official') || lower.contains('account'))) {
      return TIM_t("公众号未开通或未发布，暂无法发送消息，请联系管理员在 IM 控制台启用运营公众号");
    }
    return '';
  }

  bool _isOfficialAccountC2cReadReportError(V2TimCallback result, String userID) {
    return _isOfficialAccountUserId(userID) &&
        result.code == 131006 &&
        result.desc.toLowerCase().contains('official account');
  }

  Future<V2TimCallback> _retryMarkMessageAsRead({
    required Future<V2TimCallback> Function() action,
    int retries = 3,
    String? c2cUserID,
    bool Function(V2TimCallback result)? shouldRetry,
  }) async {
    V2TimCallback result;
    int attempts = 0;
    do {
      try {
        result = await action();
      } catch (e) {
        if (PlatformUtils().isWeb) {
          debugPrint('MessageServiceImpl: mark read ignored on web: $e');
          return V2TimCallback(code: 0, desc: '');
        }
        rethrow;
      }
      if (result.code == 0) {
        return result;
      }
      if (PlatformUtils().isWeb && result.code == 10007) {
        _printSoftWebSdkError('mark read no permission ignored on web', result.desc);
        return V2TimCallback(code: 0, desc: '');
      }
      if (c2cUserID != null && _isOfficialAccountC2cReadReportError(result, c2cUserID)) {
        return V2TimCallback(code: 0, desc: '');
      }
      if (shouldRetry != null && !shouldRetry(result)) {
        break;
      }
      attempts++;
      await Future.delayed(const Duration(milliseconds: 500));
    } while (attempts < retries);

    if (PlatformUtils().isWeb && result.code == 10007) {
      _printSoftWebSdkError('mark read no permission ignored on web', result.desc);
      return V2TimCallback(code: 0, desc: '');
    }
    if (c2cUserID != null && _isOfficialAccountC2cReadReportError(result, c2cUserID)) {
      return V2TimCallback(code: 0, desc: '');
    }

    _coreService
        .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));

    return result;
  }

  @override
  Future<V2TimCallback> markC2CMessageAsRead({
    required String userID,
  }) {
    return _retryMarkMessageAsRead(
      c2cUserID: userID,
      action: () {
        return TencentImSDKPlugin.v2TIMManager.getConversationManager().cleanConversationUnreadMessageCount(
              conversationID: "${TUIConversationViewModel.conversationC2CPrefix}$userID",
              cleanTimestamp: 0,
              cleanSequence: 0,
            );
      },
    );
  }

  @override
  Future<V2TimCallback> markGroupMessageAsRead({
    required String groupID,
  }) {
    if (PlatformUtils().isWeb) {
      return Future.value(V2TimCallback(code: 0, desc: ''));
    }
    final id = groupID.trim().startsWith(TUIConversationViewModel.conversationGroupPrefix)
        ? groupID.trim().substring(TUIConversationViewModel.conversationGroupPrefix.length)
        : groupID.trim();
    if (id.isEmpty) {
      return Future.value(V2TimCallback(code: 0, desc: ''));
    }
    final active = _groupReadInFlight[id];
    if (active != null) {
      // A message may have arrived after the active SDK call started. Join the
      // call now and retain one trailing clean instead of issuing concurrently.
      _groupReadNeedsTrailing.add(id);
      return active;
    }
    final deferred = _groupReadDeferred[id];
    if (deferred != null) {
      return deferred;
    }
    final now = DateTime.now();
    final blockedUntil = _groupReadBlockedUntil[id];
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      return _deferGroupRead(id, blockedUntil.difference(now));
    }
    final lastSuccess = _groupReadLastSuccess[id];
    if (lastSuccess != null) {
      final nextAllowed = lastSuccess.add(_groupReadMinInterval);
      if (now.isBefore(nextAllowed)) {
        return _deferGroupRead(id, nextAllowed.difference(now));
      }
    }
    return _startGroupRead(id);
  }

  Future<V2TimCallback> _deferGroupRead(String groupID, Duration delay) {
    final active = _groupReadDeferred[groupID];
    if (active != null) {
      return active;
    }
    late final Future<V2TimCallback> tracked;
    tracked = Future<void>.delayed(delay).then((_) {
      if (identical(_groupReadDeferred[groupID], tracked)) {
        _groupReadDeferred.remove(groupID);
      }
      return _startGroupRead(groupID);
    }).whenComplete(() {
      if (identical(_groupReadDeferred[groupID], tracked)) {
        _groupReadDeferred.remove(groupID);
      }
    });
    _groupReadDeferred[groupID] = tracked;
    return tracked;
  }

  Future<V2TimCallback> _startGroupRead(String groupID) {
    final active = _groupReadInFlight[groupID];
    if (active != null) {
      _groupReadNeedsTrailing.add(groupID);
      return active;
    }
    late final Future<V2TimCallback> tracked;
    tracked = _retryMarkMessageAsRead(
      shouldRetry: (result) => !_groupReadFrequencyCodes.contains(result.code),
      action: () {
        return TencentImSDKPlugin.v2TIMManager
            .getConversationManager()
            .cleanConversationUnreadMessageCount(
              conversationID:
                  "${TUIConversationViewModel.conversationGroupPrefix}$groupID",
              cleanTimestamp: 0,
              cleanSequence: 0,
            );
      },
    ).then((result) {
      final now = DateTime.now();
      if (result.code == 0) {
        _groupReadLastSuccess[groupID] = now;
        _groupReadBlockedUntil.remove(groupID);
      } else if (_groupReadFrequencyCodes.contains(result.code)) {
        _groupReadBlockedUntil[groupID] =
            now.add(_groupReadFrequencyBackoff);
      }
      return result;
    }).whenComplete(() {
      if (identical(_groupReadInFlight[groupID], tracked)) {
        _groupReadInFlight.remove(groupID);
      }
      if (_groupReadNeedsTrailing.remove(groupID)) {
        final now = DateTime.now();
        final blockedUntil = _groupReadBlockedUntil[groupID];
        final lastSuccess = _groupReadLastSuccess[groupID];
        var nextAllowed = now;
        if (blockedUntil != null && blockedUntil.isAfter(nextAllowed)) {
          nextAllowed = blockedUntil;
        }
        if (lastSuccess != null) {
          final afterSuccess = lastSuccess.add(_groupReadMinInterval);
          if (afterSuccess.isAfter(nextAllowed)) {
            nextAllowed = afterSuccess;
          }
        }
        unawaited(_deferGroupRead(groupID, nextAllowed.difference(now)));
      }
    });
    _groupReadInFlight[groupID] = tracked;
    return tracked;
  }

  @override
  Future<void> removeAdvancedMsgListener({V2TimAdvancedMsgListener? listener}) async {
    try {
      await TencentImSDKPlugin.v2TIMManager
          .getMessageManager()
          .removeAdvancedMsgListener(listener: listener);
    } catch (e) {
      if (_isSoftWebSdkError(e)) {
        _printSoftWebSdkError('message listener remove ignored on web', e);
        return;
      }
      rethrow;
    }
  }

  @override
  Future<List<V2TimMessage>?> downloadMergerMessage({
    required String msgID,
  }) async {
    final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager().downloadMergerMessage(msgID: msgID);
    if (res.code == 0) {
      return res.data;
    }
    _coreService.callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    return null;
  }

  @override
  Future<V2TimMsgCreateInfoResult?> createForwardMessage({
    String? msgID,
    V2TimMessage? message,
    String? webMessageInstance,
  }) async {
    final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager()
        .createForwardMessage(
      message: message,
      msgID: msgID,
      webMessageInstance: webMessageInstance,
    );
    if (res.code == 0) {
      return res.data;
    }
    _coreService.callOnCallback(TIMCallback(
      type: TIMCallbackType.API_ERROR,
      errorMsg: res.desc,
      errorCode: res.code,
      infoRecommendText: TIM_t('该消息不支持单条转发'),
    ));
    return null;
  }

  @override
  Future<V2TimMsgCreateInfoResult?> createMergerMessage({
    required List<String> msgIDList,
    required String title,
    required List<String> abstractList,
    required String compatibleText,
  }) async {
    final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager().createMergerMessage(
        msgIDList: msgIDList, title: title, abstractList: abstractList, compatibleText: compatibleText);
    if (res.code == 0) {
      return res.data;
    }
    _coreService.callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    return null;
  }

  @override
  Future<V2TimCallback> deleteMessages({required List<String> msgIDs, List<dynamic>? webMessageInstanceList}) async {
    final result = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .deleteMessages(msgIDs: msgIDs, webMessageInstanceList: webMessageInstanceList);
    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  @override
  Future<V2TimMsgCreateInfoResult?> createVideoMessage(
      {String? videoPath, String? type, int? duration, String? snapshotPath, dynamic inputElement}) async {
    final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager().createVideoMessage(
        videoFilePath: videoPath ?? "",
        type: type ?? "",
        duration: duration ?? 1,
        snapshotPath: snapshotPath ?? "",
        inputElement: inputElement);
    if (res.code == 0) {
      return res.data;
    }
    _coreService.callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    return null;
  }

  @override
  Future<V2TimValueCallback<V2TimMessage>> sendReplyMessage({
    required String id, // 自己创建的ID
    required String receiver,
    required String groupID,
    OfflinePushInfo? offlinePushInfo,
    bool needReadReceipt = false,
    required V2TimMessage replyMessage, // 被回复的消息
  }) async {
    final result = await TencentImSDKPlugin.v2TIMManager.getMessageManager().sendReplyMessage(
        id: id,
        receiver: receiver,
        offlinePushInfo: offlinePushInfo,
        groupID: groupID,
        needReadReceipt: needReadReceipt,
        replyMessage: replyMessage);
    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  @override
  Future<V2TimMsgCreateInfoResult?> createFileMessage(
      {String? filePath, required String fileName, dynamic inputElement}) async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .createFileMessage(filePath: filePath ?? "", fileName: fileName, inputElement: inputElement);
    if (res.code == 0) {
      return res.data;
    }
    _coreService.callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    return null;
  }

  @override
  Future<V2TimMsgCreateInfoResult?> createLocationMessage(
      {required String desc, required double longitude, required double latitude}) async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .createLocationMessage(desc: desc, longitude: longitude, latitude: latitude);
    if (res.code == 0) {
      return res.data;
    }
    _coreService.callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    return null;
  }

  @override
  Future<V2TimValueCallback<V2TimMessageSearchResult>> searchLocalMessages(
      {required V2TimMessageSearchParam searchParam}) async {
    final result =
        await TencentImSDKPlugin.v2TIMManager.getMessageManager().searchLocalMessages(searchParam: searchParam);
    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  @override
  Future<List<V2TimMessage>?> findMessages({
    required List<String> messageIDList,
  }) async {
    final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager().findMessages(messageIDList: messageIDList);
    if (res.code == 0) {
      return res.data;
    }
    _coreService.callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    return null;
  }

  @override
  Future<V2TimCallback> setLocalCustomInt({required String msgID, required int localCustomInt}) async {
    final result = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .setLocalCustomInt(msgID: msgID, localCustomInt: localCustomInt);
    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  @override
  Future<V2TimCallback> setC2CReceiveMessageOpt({
    required List<String> userIDList,
    required ReceiveMsgOptEnum opt,
  }) async {
    final result = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .setC2CReceiveMessageOpt(userIDList: userIDList, opt: opt);
    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    } else {
      _reportConversationMuteSynced(
        chatType: 'c2c',
        peerIds: userIDList,
        opt: opt,
      );
    }
    return result;
  }

  @override
  Future<V2TimCallback> setGroupReceiveMessageOpt({
    required String groupID,
    required ReceiveMsgOptEnum opt,
  }) async {
    final result =
        await TencentImSDKPlugin.v2TIMManager.getMessageManager().setGroupReceiveMessageOpt(groupID: groupID, opt: opt);
    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    } else {
      _reportConversationMuteSynced(
        chatType: 'group',
        peerIds: [groupID],
        opt: opt,
      );
    }
    return result;
  }

  void _reportConversationMuteSynced({
    required String chatType,
    required List<String> peerIds,
    required ReceiveMsgOptEnum opt,
  }) {
    final reporter = ConversationNotifyBridge.onMuteSynced;
    if (reporter == null) {
      return;
    }
    final muted = opt != ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE;
    for (final rawPeerId in peerIds) {
      final peerId = rawPeerId.trim();
      if (peerId.isEmpty) {
        continue;
      }
      unawaited(
        reporter(
          chatType: chatType,
          peerId: peerId,
          muted: muted,
        ),
      );
    }
  }

  @override
  Future<V2TimValueCallback<V2TimMessageChangeInfo>> modifyMessage({required V2TimMessage message}) async {
    final result = await TencentImSDKPlugin.v2TIMManager.getMessageManager().modifyMessage(message: message);
    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  @override
  Future<V2TimCallback> setLocalCustomData({required String msgID, required String localCustomData}) async {
    final result = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .setLocalCustomData(msgID: msgID, localCustomData: localCustomData);
    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  bool _isBenignMessageResourceError(String? desc) {
    final normalized = (desc ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.contains('missing necessary download info') ||
        normalized.contains('message not found') ||
        normalized.contains('invalid msgid') ||
        normalized.contains('invalid message id') ||
        normalized.contains('msgid is empty') ||
        normalized.contains('message is sending') ||
        normalized.contains('file not exist') ||
        normalized.contains('file not found');
  }

  @override
  Future<V2TimValueCallback<V2TimMessageOnlineUrl>> getMessageOnlineUrl({
    required String msgID,
    bool reportError = true,
  }) async {
    final result = await TencentImSDKPlugin.v2TIMManager.getMessageManager().getMessageOnlineUrl(msgID: msgID);

    if (result.code != 0 &&
        reportError &&
        !_isBenignMessageResourceError(result.desc)) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  @override
  Future<V2TimCallback> downloadMessage(
      {required String msgID,
      required int messageType,
      required int imageType,
      required bool isSnapshot,
      bool reportError = true}) async {
    final result = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .downloadMessage(msgID: msgID, messageType: messageType, imageType: imageType, isSnapshot: isSnapshot);
    if (result.code != 0 &&
        reportError &&
        !_isBenignMessageResourceError(result.desc)) {
      _coreService.callOnCallback(TIMCallback(
          type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result;
  }

  @override
  Future<String> translateText(String text, String target) async {
    final result =
        await TencentImSDKPlugin.v2TIMManager.getMessageManager().translateText(texts: [text], targetLanguage: target);
    if (result.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: result.desc, errorCode: result.code));
    }
    return result.data?[text] ?? "";
  }
}
