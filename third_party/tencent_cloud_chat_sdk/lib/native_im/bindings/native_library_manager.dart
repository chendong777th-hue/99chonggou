import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:logging/logging.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_change_info_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_tips_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation_filter.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_report_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_tips_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_extension.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_reaction_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_official_account_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_receive_message_opt_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_friendship_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';
import 'package:tencent_cloud_chat_sdk/enum/user_info_allow_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimCommunityListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimFriendshipListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimGroupListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSignalingListener.dart';
import 'native_imsdk_bindings_generated.dart';

const String _libName = 'dart_native_imsdk';
/// The dynamic library in which the symbols for [NativeImsdkBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }

  if (Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }

  if (Platform.isMacOS) {
    return DynamicLibrary.open('$_libName.framework/Versions/A/$_libName');
  }

  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }

  if (Platform.operatingSystem == 'ohos') {
    return DynamicLibrary.open('lib$_libName.so');
  }

  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

typedef ApiCallback = void Function(Map);
const String APICallbackKey = 'user_data';
const String APIJsonParamKey = 'json_param';
// 整个 JSON 字符串做 base64 编码后的固定前缀，FFI 层发送失败时会对整个 JSON 做 base64 编码并加上该前缀
const String _kBase64Prefix = 'base64:';
class NativeLibraryManager {
  static NativeLibraryManager instance = NativeLibraryManager();

  static final NativeImsdkBindings bindings = NativeImsdkBindings(_dylib);
  static final ReceivePort _receivePort = ReceivePort();
  static final Map<String, ApiCallback> _apiCallbackMap = Map.from({});

  static V2TimSDKListener? _sdkListener;
  static V2TimAdvancedMsgListener? _advancedMessageListener;
  static V2TimConversationListener? _conversationListener;
  static V2TimGroupListener? _groupListener;
  static V2TimCommunityListener? _communityListener;
  static V2TimFriendshipListener? _friendshipListener;
  static V2TimSignalingListener? _signalingListener;

  static bool _isInitialized = false;
  static bool _isRegisterPort = false;

  static void setSdkListener(V2TimSDKListener listener, {bool enableLogCallback = false}) {
    _sdkListener = listener;
    String userData = Tools.generateUserData('setSdkListener');
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    bindings.DartSetNetworkStatusListenerCallback(pUserData);
    bindings.DartSetKickedOfflineCallback(pUserData);
    bindings.DartSetUserSigExpiredCallback(pUserData);
    bindings.DartSetSelfInfoUpdatedCallback(pUserData);
    bindings.DartSetUserStatusChangedCallback(pUserData);
    bindings.DartSetUserInfoChangedCallback(pUserData);
    bindings.DartSetMsgAllMessageReceiveOptionCallback(pUserData);
    bindings.DartSetExperimentalNotifyCallback(pUserData);
    if (enableLogCallback) {
      bindings.DartSetLogCallback(pUserData);
    }
  }

  static void setAdvancedMessageListener(V2TimAdvancedMsgListener listener) {
    _advancedMessageListener = listener;
    String userData = Tools.generateUserData('setAdvancedMessageListener');
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    bindings.DartAddReceiveNewMsgCallback(pUserData);
    bindings.DartSetMsgElemUploadProgressCallback(pUserData);
    bindings.DartSetMsgReadReceiptCallback(pUserData);
    bindings.DartSetMsgRevokeCallback(pUserData);
    bindings.DartSetMsgUpdateCallback(pUserData);
    bindings.DartSetMsgExtensionsChangedCallback(pUserData);
    bindings.DartSetMsgExtensionsDeletedCallback(pUserData);
    bindings.DartSetMsgReactionsChangedCallback(pUserData);
    bindings.DartSetMsgAllMessageReceiveOptionCallback(pUserData);
    bindings.DartSetMsgGroupPinnedMessageChangedCallback(pUserData);
  }

  static void setConversationListener(V2TimConversationListener listener) {
    _conversationListener = listener;
    String userData = Tools.generateUserData('setConversationListener');
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    bindings.DartSetConvEventCallback(pUserData);
    bindings.DartSetConvTotalUnreadMessageCountChangedCallback(pUserData);
    bindings.DartSetConvUnreadMessageCountChangedByFilterCallback(pUserData);
    bindings.DartSetConvConversationGroupCreatedCallback(pUserData);
    bindings.DartSetConvConversationGroupDeletedCallback(pUserData);
    bindings.DartSetConvConversationGroupNameChangedCallback(pUserData);
    bindings.DartSetConvConversationsAddedToGroupCallback(pUserData);
    bindings.DartSetConvConversationsDeletedFromGroupCallback(pUserData);
  }

  static void setGroupListener(V2TimGroupListener listener)  {
    _groupListener = listener;
    String userData = Tools.generateUserData('setGroupListener');
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    bindings.DartSetGroupTipsEventCallback(pUserData);
    bindings.DartSetGroupAttributeChangedCallback(pUserData);
    bindings.DartSetGroupCounterChangedCallback(pUserData);
  }

  static void setCommunityListener(V2TimCommunityListener listener) {
    _communityListener = listener;
    String userData = Tools.generateUserData('setCommunityListener');
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    bindings.DartSetCommunityCreateTopicCallback(pUserData);
    bindings.DartSetCommunityDeleteTopicCallback(pUserData);
    bindings.DartSetCommunityChangeTopicInfoCallback(pUserData);
    bindings.DartSetCommunityReceiveTopicRESTCustomDataCallback(pUserData);
    bindings.DartSetCommunityCreatePermissionGroupCallback(pUserData);
    bindings.DartSetCommunityDeletePermissionGroupCallback(pUserData);
    bindings.DartSetCommunityChangePermissionGroupInfoCallback(pUserData);
    bindings.DartSetCommunityAddMembersToPermissionGroupCallback(pUserData);
    bindings.DartSetCommunityRemoveMembersFromPermissionGroupCallback(pUserData);
    bindings.DartSetCommunityAddTopicPermissionCallback(pUserData);
    bindings.DartSetCommunityDeleteTopicPermissionCallback(pUserData);
    bindings.DartSetCommunityModifyTopicPermissionCallback(pUserData);
  }

  static void setFriendshipListener(V2TimFriendshipListener listener)  {
    _friendshipListener = listener;
    String userData = Tools.generateUserData('setFriendshipListener');
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    bindings.DartSetOnAddFriendCallback(pUserData);
    bindings.DartSetOnDeleteFriendCallback(pUserData);
    bindings.DartSetUpdateFriendProfileCallback(pUserData);
    bindings.DartSetFriendAddRequestCallback(pUserData);
    bindings.DartSetFriendApplicationListDeletedCallback(pUserData);
    bindings.DartSetFriendApplicationListReadCallback(pUserData);
    bindings.DartSetFriendBlackListAddedCallback(pUserData);
    bindings.DartSetFriendBlackListDeletedCallback(pUserData);
    bindings.DartSetFriendGroupCreatedCallback(pUserData);
    bindings.DartSetFriendGroupDeletedCallback(pUserData);
    bindings.DartSetFriendGroupNameChangedCallback(pUserData);
    bindings.DartSetFriendsAddedToGroupCallback(pUserData);
    bindings.DartSetFriendsDeletedFromGroupCallback(pUserData);
    bindings.DartSetOfficialAccountSubscribedCallback(pUserData);
    bindings.DartSetOfficialAccountUnsubscribedCallback(pUserData);
    bindings.DartSetOfficialAccountDeletedCallback(pUserData);
    bindings.DartSetOfficialAccountInfoChangedCallback(pUserData);
    bindings.DartSetMyFollowingListChangedCallback(pUserData);
    bindings.DartSetMyFollowersListChangedCallback(pUserData);
    bindings.DartSetMutualFollowersListChangedCallback(pUserData);
  }

  static void setSignalingListener(V2TimSignalingListener listener)  {
    _signalingListener = listener;
    String userData = Tools.generateUserData('setSignalingListener');
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    bindings.DartSetSignalingReceiveNewInvitationCallback(pUserData);
    bindings.DartSetSignalingInvitationCancelledCallback(pUserData);
    bindings.DartSetSignalingInviteeAcceptedCallback(pUserData);
    bindings.DartSetSignalingInviteeRejectedCallback(pUserData);
    bindings.DartSetSignalingInvitationTimeoutCallback(pUserData);
    bindings.DartSetSignalingInvitationModifiedCallback(pUserData);
  }

  static void _handleNativeMessage(dynamic message) {
    try {
      String data = message;
      // 检查是否是 base64 编码的数据（FFI 层直接发送失败后会对整个 JSON 做 base64 编码并加上 "base64:" 前缀）
      if (data.startsWith(_kBase64Prefix)) {
        String base64Data = data.substring(_kBase64Prefix.length);
        List<int> bytes = base64Decode(base64Data);
        // allowMalformed: true: 允许错误格式的UTF-8解码，确保含 \u0000 等特殊字符的数据也能解码
        data = utf8.decode(bytes, allowMalformed: true);
      }
      Map<String, dynamic> dataFromNativeMap = json.decode(data);
      String callbackName = dataFromNativeMap["callback"];

      _handleNativeCallback(callbackName, dataFromNativeMap);
    } catch (err) {
      final Logger logger = Logger('NativeLibraryManager');
      logger.severe(
          'NativeLibraryManager _handleNativeMessage error $message $err');
    }
  }

  static void _handleNativeCallback(String callbackName, Map<String, dynamic> dataFromNativeMap) async {
    switch (callbackName) {
      case "apiCallback":
        String userData = dataFromNativeMap[APICallbackKey];
        if (_apiCallbackMap.containsKey(userData)) {
            _apiCallbackMap[userData]!(dataFromNativeMap);
        }
        break;
      case "globalCallback":
        _handleGlobalCallback(dataFromNativeMap);
        break;
      default:
        break;
    }
  }

  static void registerPort() {
    _initializeIfNeeded();

    if (_isRegisterPort) {
      return;
    }

    bindings.DartRegisterSendPort(_receivePort.sendPort.nativePort);
    _isRegisterPort = true;
  }

  static void unregisterPort() {
    if (!_isRegisterPort) {
      return;
    }

    bindings.DartUnregisterSendPort(_receivePort.sendPort.nativePort);
    _isRegisterPort = false;
  }

  static void _initializeIfNeeded() {
    if (_isInitialized) {
      return;
    }

    bindings.DartInitDartApiDL(NativeApi.initializeApiDLData);
    /// 1、_receivePort.listen 不能调用多次调用，否则报错；
    /// 2、_receivePort.close 调用后，_receivePort 就无法再使用了，再次 listen 也会报错，因此不要 close。
    _receivePort.listen((dynamic message) {
      _handleNativeMessage(message);
    });
    _isInitialized = true;
  }

  static void addTimCallback2Map(String userData, Completer<V2TimCallback> completer) {
    _apiCallbackMap.addAll({userData: (Map jsonResult) { completer.complete(V2TimCallback.fromJson(jsonResult)); }});
  }

  static void addTimValueCallback2Map<T>(String userData, Completer<V2TimValueCallback<T>> completer) {
    _apiCallbackMap.addAll({userData: (Map jsonResult) { completer.complete(V2TimValueCallback<T>.fromJson(jsonResult)); }});
  }

  static void addTimApiValueCallback2Map(String userData, ApiCallback callback) {
    _apiCallbackMap.addAll({userData: callback});
  }

  static void removeTimCallbackFromMap(String userData) {
    _apiCallbackMap.remove(userData);
  }

  /// 从全局回调数据中获取指定 key 的字符串值
  static String _getGlobalCallbackJsonString(Map<String, dynamic> dataFromNativeMap, String key) {
    String rawValue = dataFromNativeMap[key] ?? '';
    return rawValue;
  }

  static void _handleGlobalCallback(Map<String, dynamic> dataFromNativeMap) {
    int callbackType = dataFromNativeMap["callbackType"];
    GlobalCallbackType globalCallbackType = GlobalCallbackType.fromValue(callbackType);
    switch (globalCallbackType) {
      case GlobalCallbackType.NetworkStatus: {
        int code = dataFromNativeMap["code"];
        String desc = dataFromNativeMap["desc"];
        int status = dataFromNativeMap["status"];
        if (status == 0) {
          _sdkListener?.onConnectSuccess();
        } else if (status == 1 || status == 3) {
          _sdkListener?.onConnectFailed(code, desc);
        } else if (status == 2) {
          _sdkListener?.onConnecting();
        }
      }

        break;
      case GlobalCallbackType.KickedOffline:
        _sdkListener?.onKickedOffline();

        break;
      case GlobalCallbackType.UserSigExpired:
        _sdkListener?.onUserSigExpired();

        break;
      case GlobalCallbackType.SelfInfoUpdated: {
          String jsonUserInfo = _getGlobalCallbackJsonString(dataFromNativeMap, "json_user_profile");
          Map<String, dynamic> userInfo = json.decode(jsonUserInfo);
          V2TimUserFullInfo v2timUserFullInfo = V2TimUserFullInfo.fromJson(userInfo);

          _sdkListener?.onSelfInfoUpdated(v2timUserFullInfo);
      }

        break;
      case GlobalCallbackType.UserStatusChanged: {
        String jsonUserStatusArray = _getGlobalCallbackJsonString(dataFromNativeMap, "json_user_status_array");
        List<dynamic> userStatusArray = json.decode(jsonUserStatusArray);
        List<V2TimUserStatus> userStatusList = [];
        for (dynamic userStatus in userStatusArray) {
          V2TimUserStatus v2timUserStatus = V2TimUserStatus.fromJson(userStatus);
          userStatusList.add(v2timUserStatus);
        }

        _sdkListener?.onUserStatusChanged(userStatusList);
      }

        break;
      case GlobalCallbackType.UserInfoChanged: {
        String jsonUserInfoArray = _getGlobalCallbackJsonString(dataFromNativeMap, "json_user_info_array");
        List<dynamic> userInfoArray = json.decode(jsonUserInfoArray);
        List<V2TimUserFullInfo> userInfoList = [];
        for (dynamic userInfo in userInfoArray) {
          V2TimUserFullInfo v2timUserFullInfo = V2TimUserFullInfo.fromJson(userInfo);
          userInfoList.add(v2timUserFullInfo);
        }

        _sdkListener?.onUserInfoChanged(userInfoList);
      }
        break;
      case GlobalCallbackType.LogCallback: {
        int logLevel = dataFromNativeMap["level"];
        String log = dataFromNativeMap["log"];
        _sdkListener?.onLog(logLevel, log);
      }

        break;
      case GlobalCallbackType.ReceiveNewMessage: {
        String jsonMessageArray = _getGlobalCallbackJsonString(dataFromNativeMap, "json_msg_array");
        List<dynamic> messageArray = json.decode(jsonMessageArray);
        for (Map<String, dynamic> message in messageArray) {
          V2TimMessage v2timMessage = V2TimMessage.fromJson(message);
          if (v2timMessage.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_REPORT) {
            _notifyGroupReport(v2timMessage.groupReportElem);
            continue;
          }

          _advancedMessageListener?.onRecvNewMessage(v2timMessage);
        }
      }

        break;
      case GlobalCallbackType.MessageElemUploadProgress: {
        String jsonMessage = _getGlobalCallbackJsonString(dataFromNativeMap, "json_msg");
        Map<String, dynamic> messageInfo = json.decode(jsonMessage);
        V2TimMessage v2timMessage = V2TimMessage.fromJson(messageInfo);
        int index = dataFromNativeMap["index"];
        int currentSize = dataFromNativeMap["cur_size"];
        int totalSize = dataFromNativeMap["total_size"];
        int progress = 0;
        if (totalSize > 0) {
          progress = (100 * currentSize / totalSize).floor();
        }

        _advancedMessageListener?.onSendMessageProgress(v2timMessage, progress);
      }

        break;
      case GlobalCallbackType.MessageReadReceipt: {
        String jsonMsgReadReceiptArray = _getGlobalCallbackJsonString(dataFromNativeMap, "json_msg_read_receipt_array");
        List<dynamic> msgReadReceiptArray = json.decode(jsonMsgReadReceiptArray);
        List<V2TimMessageReceipt> c2cMessageReceiptList = [];
        List<V2TimMessageReceipt> messageReceiptList = [];
        for (dynamic msgReadReceipt in msgReadReceiptArray) {
          V2TimMessageReceipt v2timMessageReceipt = V2TimMessageReceipt.fromJson(msgReadReceipt);
          messageReceiptList.add(v2timMessageReceipt);
          if (v2timMessageReceipt.userID.isNotEmpty) {
            c2cMessageReceiptList.add(v2timMessageReceipt);
          }
        }
        if (c2cMessageReceiptList.isNotEmpty) {
          _advancedMessageListener?.onRecvC2CReadReceipt(c2cMessageReceiptList);
        }

        if (messageReceiptList.isNotEmpty) {
          _advancedMessageListener?.onRecvMessageReadReceipts(messageReceiptList);
        }
      }

        break;
      case GlobalCallbackType.MessageRevoke: {
        String jsonMessageRevokeArray = _getGlobalCallbackJsonString(dataFromNativeMap, "json_msg_locator_array");
        List<Map<String, dynamic>> messageRevokeArray = List<Map<String, dynamic>>.from(json.decode(jsonMessageRevokeArray));
        for (Map<String, dynamic> messageRevoke in messageRevokeArray) {
          String msgID = messageRevoke["message_msg_id"];
          String reason = messageRevoke["message_revoke_reason"];
          String revokerUserID = messageRevoke["message_revoker_user_id"];
          String revokerNickName = messageRevoke["message_revoker_nick_name"];
          String revokerFaceUrl = messageRevoke["message_revoker_face_url"];
          V2TimUserFullInfo v2timUserFullInfo = V2TimUserFullInfo();
          v2timUserFullInfo.userID = revokerUserID;
          v2timUserFullInfo.nickName = revokerNickName;
          v2timUserFullInfo.faceUrl = revokerFaceUrl;

          _advancedMessageListener?.onRecvMessageRevoked(msgID);

          _advancedMessageListener?.onRecvMessageRevokedWithInfo(msgID, v2timUserFullInfo, reason);
        }
      }

        break;
      case GlobalCallbackType.MessageUpdate: {
        String jsonMessageArray = _getGlobalCallbackJsonString(dataFromNativeMap, "json_msg_array");
        List<dynamic> messageArray = json.decode(jsonMessageArray);
        for (dynamic message in messageArray) {
          V2TimMessage v2timMessage = V2TimMessage.fromJson(message);
          _advancedMessageListener?.onRecvMessageModified(v2timMessage);
        }
      }

        break;
      case GlobalCallbackType.MessageExtensionsChanged: {
        String msgID = dataFromNativeMap["message_id"];
        String jsonMessageExtensionArray = _getGlobalCallbackJsonString(dataFromNativeMap, "message_extension_array");
        List<dynamic> messageExtensionArray = json.decode(jsonMessageExtensionArray);
        List<V2TimMessageExtension> messageExtensionList = [];
        for (dynamic messageExtension in messageExtensionArray) {
          V2TimMessageExtension v2timMessageExtension = V2TimMessageExtension.fromJson(messageExtension);
          messageExtensionList.add(v2timMessageExtension);
        }

        _advancedMessageListener?.onRecvMessageExtensionsChanged(msgID, messageExtensionList);
      }

        break;
      case GlobalCallbackType.MessageExtensionsDeleted: {
        String msgID = dataFromNativeMap["message_id"];
        String jsonMessageExtensionKeyArray = _getGlobalCallbackJsonString(dataFromNativeMap, "message_extension_key_array");
        List<String> messageExtensionArray = List<Map<String, dynamic>>.from(json.decode(jsonMessageExtensionKeyArray)).expand((map) => map.values).whereType<String>().toList();

        _advancedMessageListener?.onRecvMessageExtensionsDeleted(msgID, messageExtensionArray);
      }

        break;
      case GlobalCallbackType.MessageReactionChange: {
        String jsonMessageReactionChangeInfoArray = _getGlobalCallbackJsonString(dataFromNativeMap, "message_reaction_change_info_array");
        List<dynamic> messageReactionChangeInfoArray = jsonMessageReactionChangeInfoArray.isNotEmpty ? json.decode(jsonMessageReactionChangeInfoArray) : [];
        List<V2TIMMessageReactionChangeInfo> messageReactionChangeInfoList = [];
        for (dynamic messageReactionChangeInfo in messageReactionChangeInfoArray) {
          V2TIMMessageReactionChangeInfo v2timMessageReactionChangeInfo = V2TIMMessageReactionChangeInfo.fromJson(messageReactionChangeInfo);
          messageReactionChangeInfoList.add(v2timMessageReactionChangeInfo);
        }

        _advancedMessageListener?.onRecvMessageReactionsChanged(messageReactionChangeInfoList);
      }

        break;
      case GlobalCallbackType.AllMessageReceiveOption: {
          String jsonAllMessageReceiveOption = _getGlobalCallbackJsonString(dataFromNativeMap, "json_receive_message_option_info");
          Map<String, dynamic> allMessageReceiveOption = json.decode(jsonAllMessageReceiveOption);
          V2TimReceiveMessageOptInfo v2timReceiveMessageOpt = V2TimReceiveMessageOptInfo.fromJson(allMessageReceiveOption);

          _sdkListener?.onAllReceiveMessageOptChanged(v2timReceiveMessageOpt);
        }

        break;
      case GlobalCallbackType.GroupTipsEvent: {
          String jsonGroupTipStr = _getGlobalCallbackJsonString(dataFromNativeMap, "json_group_tip");
          Map<String, dynamic> jsonGroupTips = jsonGroupTipStr.isNotEmpty ? json.decode(jsonGroupTipStr) : {};
          V2TimGroupTipsElem groupTips = V2TimGroupTipsElem.fromJson(jsonGroupTips);

          _notifyGroupTips(groupTips);
        }

        break;
      case GlobalCallbackType.GroupPinnedMessageChanged: {
          String groupID = dataFromNativeMap["group_id"];
          String jsonMsg = _getGlobalCallbackJsonString(dataFromNativeMap, "json_msg");
          Map<String, dynamic> messageInfo = json.decode(jsonMsg);
          V2TimMessage v2timMessage = V2TimMessage.fromJson(messageInfo);
          bool isPinned = dataFromNativeMap["is_pinned"];
          String jsonOpUser = dataFromNativeMap["op_user"];
          Map<String, dynamic> groupMemberInfo = json.decode(jsonOpUser);
          V2TimGroupMemberInfo v2timGroupMemberInfo = V2TimGroupMemberInfo.fromJson(groupMemberInfo);

          _advancedMessageListener?.onGroupMessagePinned(groupID, v2timMessage, isPinned, v2timGroupMemberInfo);
      }

        break;
      case GlobalCallbackType.GroupAttributeChanged: {
        final groupID = dataFromNativeMap["group_id"];
        final groupChangeAttributeList = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_group_attribute_array"));
        Map<String, String> groupAttributeMap = {};
        if (groupChangeAttributeList is List && groupChangeAttributeList.isNotEmpty) {
          groupAttributeMap = Tools.jsonList2Map<String>(groupChangeAttributeList.whereType<Map<String, dynamic>>().toList(), 'group_attribute_key', 'group_attribute_value');
        }

        _groupListener?.onGroupAttributeChanged(groupID, groupAttributeMap);
      }

        break;
      case GlobalCallbackType.GroupCounterChanged: {
        final groupID = dataFromNativeMap["group_id"];
        final key = dataFromNativeMap["group_counter_key"];
        final value = dataFromNativeMap["group_counter_new_value"];

        _groupListener?.onGroupCounterChanged(groupID, key, value);
      }

        break;
      case GlobalCallbackType.TopicCreated: {
        final groupID = dataFromNativeMap["group_id"];
        final topicID = dataFromNativeMap["topic_id"];

        _groupListener?.onTopicCreated(groupID, topicID);
        _communityListener?.onCreateTopic(groupID, topicID);
      }

        break;
      case GlobalCallbackType.TopicDeleted: {
        final groupID = dataFromNativeMap["group_id"];
        final topicIDList = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "topic_id_array"));

        _groupListener?.onTopicDeleted(groupID, topicIDList.whereType<String>().toList());
        _communityListener?.onDeleteTopic(groupID, topicIDList.whereType<String>().toList());
      }

        break;
      case GlobalCallbackType.TopicChanged: {
        final groupID = dataFromNativeMap["group_id"];
        final topicInfo = V2TimTopicInfo.fromJson(json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "topic_info")));

        _groupListener?.onTopicInfoChanged(groupID, topicInfo);
        _communityListener?.onChangeTopicInfo(groupID, topicInfo);
      }

        break;
      case GlobalCallbackType.ReceiveTopicRESTCustomData: {
        final topicID = dataFromNativeMap["topic_id"];
        final customData = dataFromNativeMap["custom_data"];

        _groupListener?.onReceiveRESTCustomData(topicID, customData);
        _communityListener?.onReceiveTopicRESTCustomData(topicID, customData);
      }

        break;
      case GlobalCallbackType.CreatePermissionGroup: {
        final groupID = dataFromNativeMap["group_id"];
        final permissionGroupInfo = V2TimPermissionGroupInfo.fromJson(json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "permission_group_info")));

        _communityListener?.onCreatePermissionGroup(groupID, permissionGroupInfo);
      }

        break;
      case GlobalCallbackType.DeletePermissionGroup: {
        final groupID = dataFromNativeMap["group_id"];
        final permissionGroupIDList = json.decode(dataFromNativeMap["permission_group_id_array"]);

        _communityListener?.onDeletePermissionGroup(groupID, permissionGroupIDList);
      }

        break;
      case GlobalCallbackType.ChangePermissionGroupInfo: {
        final groupID = dataFromNativeMap["group_id"];
        final permissionGroupInfo = V2TimPermissionGroupInfo.fromJson(json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "permission_group_info")));

        _communityListener?.onChangePermissionGroupInfo(groupID, permissionGroupInfo);
      }

        break;
      case GlobalCallbackType.AddMembersToPermissionGroup: {
        final groupID = dataFromNativeMap["group_id"];
        final jsonResult = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_result"));
        String permissionGroupID = jsonResult["permission_group_id"];
        List<String> memberIDList = List<String>.from(jsonResult["member_id_array"] ?? []);

        _communityListener?.onAddMembersToPermissionGroup(groupID, permissionGroupID, memberIDList);
      }

        break;
      case GlobalCallbackType.RemoveMembersFromPermissionGroup: {
        final groupID = dataFromNativeMap["group_id"];
        final jsonResult = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_result"));
        String permissionGroupID = jsonResult["permission_group_id"];
        List<String> memberIDList = List<String>.from(jsonResult["member_id_array"] ?? []);

        _communityListener?.onRemoveMembersFromPermissionGroup(groupID, permissionGroupID, memberIDList);
      }

        break;
      case GlobalCallbackType.AddTopicPermission: {
        final groupID = dataFromNativeMap["group_id"];
        final jsonResult = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_result"));
        String permissionGroupID = jsonResult["permission_group_id"];
        final topicPermissionList = jsonResult["topic_permission_map"];
        Map<String, int> topicPermissionMap = {};
        if (topicPermissionList is List && topicPermissionList.isNotEmpty) {
          topicPermissionMap = Tools.jsonList2Map<int>(topicPermissionList.whereType<Map<String, dynamic>>().toList(), 'topic_permission_key', 'topic_permission_value');
        }

        _communityListener?.onAddTopicPermission(groupID, permissionGroupID, topicPermissionMap);
      }

        break;
      case GlobalCallbackType.DeleteTopicPermission: {
        final groupID = dataFromNativeMap["group_id"];
        final jsonResult = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_result"));
        String permissionGroupID = jsonResult["permission_group_id"];
        final topicIDList = jsonResult["topic_id_list"];

        _communityListener?.onDeleteTopicPermission(groupID, permissionGroupID, topicIDList);
      }

        break;
      case GlobalCallbackType.ModifyTopicPermission: {
        final groupID = dataFromNativeMap["group_id"];
        final jsonResult = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_result"));
        String permissionGroupID = jsonResult["permission_group_id"];
                final topicPermissionList = jsonResult["topic_permission_map"];
        Map<String, int> topicPermissionMap = {};
        if (topicPermissionList is List && topicPermissionList.isNotEmpty) {
          topicPermissionMap = Tools.jsonList2Map<int>(topicPermissionList.whereType<Map<String, dynamic>>().toList(), 'topic_permission_key', 'topic_permission_value');
        }

        _communityListener?.onModifyTopicPermission(groupID, permissionGroupID, topicPermissionMap);
      }

        break;
      case GlobalCallbackType.ConversationEvent: {
        final convEvent = dataFromNativeMap["conv_event"];
        // List<dynamic>
        var resultList = [];
        String jsonConvArray = _getGlobalCallbackJsonString(dataFromNativeMap, "json_conv_array");
        if (jsonConvArray.isNotEmpty) {
          resultList = json.decode(jsonConvArray);
        }
        List<V2TimConversation> conversationList = [];
        List<String> conversationIDList = [];

        switch (convEvent) {
          case CConversationEvent.conversationEventAdd:
            conversationList = resultList.map((v) => V2TimConversation.fromJson(v)).toList();
            _conversationListener?.onNewConversation(conversationList);

            break;
          case CConversationEvent.conversationEventDel:
            conversationIDList = resultList.whereType<String>().toList();
            _conversationListener?.onConversationDeleted(conversationIDList);

            break;
          case CConversationEvent.conversationEventUpdate:
            conversationList = resultList.map((v) => V2TimConversation.fromJson(v)).toList();
            _conversationListener?.onConversationChanged(conversationList);
            
            break;
          case CConversationEvent.conversationEventStart:
            _conversationListener?.onSyncServerStart();

            break;
          case CConversationEvent.conversationEventFinish:
            _conversationListener?.onSyncServerFinish();
          
            break;
          default:
            break;
        }
      }

        break;
      case GlobalCallbackType.TotalUnreadMessageCountChanged: {
        final totalUnreadCount = dataFromNativeMap["total_unread_count"];

        _conversationListener?.onTotalUnreadMessageCountChanged(totalUnreadCount);
      }

        break;
      case GlobalCallbackType.TotalUnreadMessageCountChangedByFilter: {
        final filter = V2TimConversationFilter.fromJson(json.decode(dataFromNativeMap["filter"]));
        final totalUnreadCount = dataFromNativeMap["total_unread_count"];

        _conversationListener?.onUnreadMessageCountChangedByFilter(filter, totalUnreadCount);
      }

        break;
      case GlobalCallbackType.ConversationGroupCreated: {
        final groupName = dataFromNativeMap["group_name"];
        final conversationArray = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "conversation_array"));
        List<V2TimConversation> conversationList = [];
        if (conversationArray is List && conversationArray.isNotEmpty) {
          conversationList = conversationArray.whereType<Map>().map((v) => V2TimConversation.fromJson(v)).toList();
        }

        _conversationListener?.onConversationGroupCreated(groupName, conversationList);
      }

        break;
      case GlobalCallbackType.ConversationGroupDeleted: {
        final groupName = dataFromNativeMap["group_name"];

        _conversationListener?.onConversationGroupDeleted(groupName);
      }

        break;
      case GlobalCallbackType.ConversationGroupNameChanged: {
        final oldName = dataFromNativeMap["old_name"];
        final newName = dataFromNativeMap["new_name"];

        _conversationListener?.onConversationGroupNameChanged(oldName, newName);
      }

        break;
      case GlobalCallbackType.ConversationsAddedToGroup: {
        final groupName = dataFromNativeMap["group_name"];
        final conversationArray = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "conversation_array"));
        List<V2TimConversation> conversationList = [];
        if (conversationArray is List && conversationArray.isNotEmpty) {
          conversationList = conversationArray.whereType<Map>().map((v) => V2TimConversation.fromJson(v)).toList();
        }

        _conversationListener?.onConversationsAddedToGroup(groupName, conversationList);
      }

        break;
      case GlobalCallbackType.ConversationsDeletedFromGroup: {
        final groupName = dataFromNativeMap["group_name"];
        final conversationArray = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "conversation_array"));
        List<V2TimConversation> conversationList = [];
        if (conversationArray is List && conversationArray.isNotEmpty) {
          conversationList = conversationArray.whereType<Map>().map((v) => V2TimConversation.fromJson(v)).toList();
        }

        _conversationListener?.onConversationsDeletedFromGroup(groupName, conversationList);
      }

        break;
      case GlobalCallbackType.AddFriend: {
        final friendInfoArray = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "friend_info_array"));
        List<V2TimFriendInfo> friendInfoList = [];
        if (friendInfoArray is List && friendInfoArray.isNotEmpty) {
          friendInfoList = friendInfoArray.whereType<Map>().map((v) => V2TimFriendInfo.fromJson(v)).toList();
          if (friendInfoList.isEmpty) {
            TIMFriendshipManager.instance.getFriendsInfo(userIDList: friendInfoArray.whereType<String>().toList())
              .then((result) {
                if (result.code == 0 && result.data is List && result.data!.isNotEmpty) {
                  friendInfoList = result.data!.where((e) => e.resultCode == 0).map((e) => e.friendInfo!).toList();
                }

                _friendshipListener?.onFriendListAdded(friendInfoList);
              })
              .catchError((error) {
                print('error: $error');
              });
          } else {
             _friendshipListener?.onFriendListAdded(friendInfoList);
          }
        }
      }

        break;
      case GlobalCallbackType.DeleteFriend: {
        final friendIDList = json.decode(dataFromNativeMap["friend_id_array"]);

        _friendshipListener?.onFriendListDeleted(friendIDList.whereType<String>().toList());
      }

        break;
      case GlobalCallbackType.UpdateFriendProfile: {
        final friendInfoArray = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "friend_info_update_array"));
        List<V2TimFriendInfo> friendInfoList = [];
        if (friendInfoArray is List && friendInfoArray.isNotEmpty) {
          Map<String, dynamic> updateFriendProfile = friendInfoArray[0];
          String userID = updateFriendProfile["friend_profile_update_identifier"];
          if (userID == null || userID.isEmpty) {
            return;
          }

          V2TimFriendInfo v2timFriendInfo = V2TimFriendInfo(userID: userID);

          Map<String, dynamic> updateItemMap = Map<String, dynamic>.from(updateFriendProfile["friend_profile_update_item"] ?? {});
          if (updateItemMap.isNotEmpty) {
            var friendCustomStringInfoList = List<Map<String, dynamic>>.from(updateItemMap["friend_profile_item_custom_string_array"] ?? []);
            v2timFriendInfo.friendCustomInfo = Tools.jsonList2Map<String>(friendCustomStringInfoList, "friend_profile_custom_string_info_key", "friend_profile_custom_string_info_value");
            v2timFriendInfo.friendCustomInfo = v2timFriendInfo.friendCustomInfo?.map((k, v) => 
              MapEntry(
                k.startsWith('Tag_SNS_Custom_') 
                  ? k.replaceFirst('Tag_SNS_Custom_', '') 
                  : k, 
                v
              )
            );
            v2timFriendInfo.friendGroups = List<String>.from(updateItemMap["friend_profile_item_group_name_array"] ?? []);
            v2timFriendInfo.friendRemark = updateItemMap["friend_profile_item_remark"] ?? '';

            V2TimUserFullInfo userFullInfo = V2TimUserFullInfo();
            userFullInfo.userID = userID;
            int? addPermission = updateItemMap["user_profile_item_add_permission"] ?? CFriendAddPermission.Unknown;
            switch (addPermission) {
              case CFriendAddPermission.AllowAny:
                userFullInfo.allowType = AllowType.V2TIM_FRIEND_ALLOW_ANY;
                break;
              case CFriendAddPermission.NeedConfirm:
                userFullInfo.allowType = AllowType.V2TIM_FRIEND_NEED_CONFIRM;
                break;
              case CFriendAddPermission.DenyAny:
                userFullInfo.allowType = AllowType.V2TIM_FRIEND_DENY_ANY;
                break;
              default:
                userFullInfo.allowType = AllowType.V2TIM_FRIEND_ALLOW_ANY;
                break;
            }

            userFullInfo.birthday = updateItemMap["user_profile_item_birthday"] ?? CFriendAddPermission.Unknown;
            var userCustomStringInfoList = List<Map<String, dynamic>>.from(updateItemMap["user_profile_item_custom_string_array"] ?? []);
            // C 接口抛好友资料变更的时候，用户自定义字段使用了好友自定义字段的 json key，所以这里使用好友自定义字段的 json key 来解析
            userFullInfo.customInfo = Tools.jsonList2Map<String>(userCustomStringInfoList, "friend_profile_custom_string_info_key", "friend_profile_custom_string_info_value");
            userFullInfo.customInfo = userFullInfo.customInfo?.map((k, v) => 
              MapEntry(
                k.startsWith('Tag_Profile_Custom_') 
                  ? k.replaceFirst('Tag_Profile_Custom_', '') 
                  : k, 
                v
              )
            );
            userFullInfo.faceUrl = updateItemMap["user_profile_item_face_url"] ?? '';
            userFullInfo.gender = updateItemMap["user_profile_item_gender"] ?? 0;
            userFullInfo.level = updateItemMap["user_profile_item_level"] ?? 0;
            userFullInfo.nickName = updateItemMap["user_profile_item_nick_name"] ?? '';
            userFullInfo.role = updateItemMap["user_profile_item_role"] ?? 0;
            userFullInfo.selfSignature = updateItemMap["user_profile_item_self_signature"] ?? '';
            v2timFriendInfo.userProfile = userFullInfo;
          }

          friendInfoList.add(v2timFriendInfo);
        }

        _friendshipListener?.onFriendInfoChanged(friendInfoList);
      }

        break;
      case GlobalCallbackType.FriendAddRequest: {
        final applicationArray = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_application_array"));
        List<V2TimFriendApplication> applicationList = [];
        if (applicationArray is List && applicationArray.isNotEmpty) {
          applicationList = applicationArray.whereType<Map>().map((v) => V2TimFriendApplication.fromJsonForCallback(v)).toList();
        }

        _friendshipListener?.onFriendApplicationListAdded(applicationList);
      }

        break;
      case GlobalCallbackType.FriendApplicationListDeleted: {
        final userIDList = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_user_id_array"));

        _friendshipListener?.onFriendApplicationListDeleted(userIDList.whereType<String>().toList());
      }

        break;
      case GlobalCallbackType.FriendApplicationListRead:
        _friendshipListener?.onFriendApplicationListRead();

        break;
      case GlobalCallbackType.FriendBlackListAdded: {
        final friendInfoArray = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_friend_info_array"));
        List<V2TimFriendInfo> friendInfoList = [];
        if (friendInfoArray is List && friendInfoArray.isNotEmpty) {
          friendInfoList = friendInfoArray.whereType<Map>().map((v) => V2TimFriendInfo.fromJson(v)).toList();
        }

        _friendshipListener?.onBlackListAdd(friendInfoList);
      }

        break;
      case GlobalCallbackType.FriendBlackListDeleted: {
        final userIDList = json.decode(dataFromNativeMap["json_user_id_array"]);
        _friendshipListener?.onBlackListDeleted(userIDList.whereType<String>().toList());
      }

        break;
      case GlobalCallbackType.FriendGroupCreated: {
        final groupName = dataFromNativeMap["group_name"];
        final friendInfoArray = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_friend_info_array"));
        List<V2TimFriendInfo> friendInfoList = [];
        if (friendInfoArray is List && friendInfoArray.isNotEmpty) {
          friendInfoList = friendInfoArray.whereType<Map>().map((v) => V2TimFriendInfo.fromJson(v)).toList();
        }

        _friendshipListener?.onFriendGroupCreated(groupName, friendInfoList);
      }

        break;
      case GlobalCallbackType.FriendGroupDeleted: {
        final groupNameList = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_group_name_array"));

        _friendshipListener?.onFriendGroupDeleted(groupNameList.whereType<String>().toList());
      }

        break;
      case GlobalCallbackType.FriendGroupNameChanged: {
        final oldGroupName = dataFromNativeMap["old_group_name"];
        final newGroupName = dataFromNativeMap["new_group_name"];

        _friendshipListener?.onFriendGroupNameChanged(oldGroupName, newGroupName);
      }

        break;
      case GlobalCallbackType.FriendsAddedToGroup: {
        final groupName = dataFromNativeMap["group_name"];
        final friendInfoArray = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_friend_info_array"));
        List<V2TimFriendInfo> friendInfoList = [];
        if (friendInfoArray is List && friendInfoArray.isNotEmpty) {
          friendInfoList = friendInfoArray.whereType<Map>().map((v) => V2TimFriendInfo.fromJson(v)).toList();
        }

        _friendshipListener?.onFriendsAddedToGroup(groupName, friendInfoList);
      }

        break;
      case GlobalCallbackType.FriendsDeletedFromGroup: {
        final groupName = dataFromNativeMap["group_name"];
        final friendIDList = json.decode(dataFromNativeMap["json_friend_id_array"]);

        _friendshipListener?.onFriendsDeletedFromGroup(groupName, friendIDList.whereType<String>().toList());
      }

        break;
      case GlobalCallbackType.OfficialAccountSubscribed: {
        final officialAccountInfo = V2TimOfficialAccountInfo.fromJson(json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_official_account_info")));

        _friendshipListener?.onOfficialAccountSubscribed(officialAccountInfo);
      }

        break;
      case GlobalCallbackType.OfficialAccountUnsubscribed: {
        final officialAccountID = dataFromNativeMap["official_account_id"];

        _friendshipListener?.onOfficialAccountUnsubscribed(officialAccountID);
      }

        break;
      case GlobalCallbackType.OfficialAccountDeleted: {
        final officialAccountID = dataFromNativeMap["official_account_id"];

        _friendshipListener?.onOfficialAccountDeleted(officialAccountID);
      }

        break;
      case GlobalCallbackType.OfficialAccountInfoChanged: {
        final officialAccountInfo = V2TimOfficialAccountInfo.fromJson(json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_official_account_info")));

        _friendshipListener?.onOfficialAccountInfoChanged(officialAccountInfo);
      }

        break;
      case GlobalCallbackType.MyFollowingListChanged: {
        final isAdd = dataFromNativeMap["is_add"];
        final userInfoArray = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_user_info_list"));
        List<V2TimUserFullInfo> userInfoList = [];
        if (userInfoArray is List && userInfoArray.isNotEmpty) {
          userInfoList = userInfoArray.whereType<Map>().map((v) => V2TimUserFullInfo.fromJson(v)).toList();
        }

        _friendshipListener?.onMyFollowingListChanged(userInfoList, isAdd);
      }

        break;
      case GlobalCallbackType.MyFollowersListChanged: {
        final isAdd = dataFromNativeMap["is_add"];
        final userInfoArray = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_user_info_list"));
        List<V2TimUserFullInfo> userInfoList = [];
        if (userInfoArray is List && userInfoArray.isNotEmpty) {
          userInfoList = userInfoArray.whereType<Map>().map((v) => V2TimUserFullInfo.fromJson(v)).toList();
        }

        _friendshipListener?.onMyFollowersListChanged(userInfoList, isAdd);
      }

        break;
      case GlobalCallbackType.MutualFollowersListChanged: {
        final isAdd = dataFromNativeMap["is_add"];
        final userInfoArray = json.decode(_getGlobalCallbackJsonString(dataFromNativeMap, "json_user_info_list"));
        List<V2TimUserFullInfo> userInfoList = [];
        if (userInfoArray is List && userInfoArray.isNotEmpty) {
          userInfoList = userInfoArray.whereType<Map>().map((v) => V2TimUserFullInfo.fromJson(v)).toList();
        }

        _friendshipListener?.onMutualFollowersListChanged(userInfoList, isAdd);
      }

        break;
      case GlobalCallbackType.SignalingReceiveNewInvitation: {
        String inviteID = dataFromNativeMap["invite_id"];
        String inviter = dataFromNativeMap["inviter"];
        String groupID = dataFromNativeMap["group_id"];
        final inviteeList = json.decode(dataFromNativeMap["json_invitee_list"]);
        dynamic dataValue = dataFromNativeMap["data"];
        String data = "";
        if (dataValue != null) {
          data = dataValue.toString();
        }

        _signalingListener?.onReceiveNewInvitation(inviteID, inviter, groupID, inviteeList.whereType<String>().toList(), data);
      }

        break;
      case GlobalCallbackType.SignalingInvitationCancelled: {
        String inviteID = dataFromNativeMap["invite_id"];
        String inviter = dataFromNativeMap["inviter"];
        String data = dataFromNativeMap["data"];

        _signalingListener?.onInvitationCancelled(inviteID, inviter, data);
      }

        break;
      case GlobalCallbackType.SignalingInviteeAccepted: {
        String inviteID = dataFromNativeMap["invite_id"];
        String invitee = dataFromNativeMap["invitee"];
        String data = dataFromNativeMap["data"];

        _signalingListener?.onInviteeAccepted(inviteID, invitee, data);
      }

        break;
      case GlobalCallbackType.SignalingInviteeRejected: {
        String inviteID = dataFromNativeMap["invite_id"];
        String invitee = dataFromNativeMap["invitee"];
        String data = dataFromNativeMap["data"];

        _signalingListener?.onInviteeRejected(inviteID, invitee, data);
      }

        break;
      case GlobalCallbackType.SignalingInvitationTimeout: {
        String inviteID = dataFromNativeMap["invite_id"];
        final inviteeList = json.decode(dataFromNativeMap["json_invitee_list"]);

        _signalingListener?.onInvitationTimeout(inviteID, inviteeList.whereType<String>().toList());
      }

        break;
      case GlobalCallbackType.SignalingInvitationModified: {
        String inviteID = dataFromNativeMap["invite_id"];
        String data = dataFromNativeMap["data"];

        _signalingListener?.onInvitationModified(inviteID, data);
      }

        break;
      case GlobalCallbackType.ExperimentalNotify: {
        String key = dataFromNativeMap["key"] ?? '';
        String dataStr = dataFromNativeMap["data"] ?? '';
        dynamic param;
        try {
          param = json.decode(dataStr);
        } catch (_) {
          param = dataStr;
        }

        _sdkListener?.onExperimentalNotify(key, param);
      }

        break;
      default:
        break;
    }

  }

  static void _notifyGroupTips(V2TimGroupTipsElem? v2timGroupTips) {
    if (v2timGroupTips == null) {
      print('invalid group tips');
      return;
    }

    final groupID = v2timGroupTips.groupID;
    final opUser = v2timGroupTips.opMember;
    final groupMemberList = v2timGroupTips.memberList?.map((e) => e!).toList() ?? [];
    final groupChangeInfoList = v2timGroupTips.groupChangeInfoList?.map((e) => e!).toList() ?? [];
    final memberChangeInfoList = v2timGroupTips.memberChangeInfoList?.map((e) => e!).toList() ?? [];
    final loginUser = TIMManager.instance.getLoginUser();

    switch (v2timGroupTips.type) {
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE:
        // 剔除自己
        groupMemberList.removeWhere((member) => member.userID == loginUser);
        if (groupMemberList.isNotEmpty) {
          _groupListener?.onMemberInvited(groupID, opUser, groupMemberList);
        }

        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_JOIN:
        // 剔除自己
        groupMemberList.removeWhere((member) => member.userID == loginUser);
        if (groupMemberList.isNotEmpty) {
          _groupListener?.onMemberEnter(groupID, groupMemberList);
        }

        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_QUIT:
        _groupListener?.onMemberLeave(groupID, opUser);

        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_KICKED:
        groupMemberList.removeWhere((member) => member.userID == loginUser);
        if (groupMemberList.isNotEmpty) {
          _groupListener?.onMemberKicked(groupID, opUser, groupMemberList);
        }

        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN:
        _groupListener?.onGrantAdministrator(groupID, opUser, groupMemberList);

        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN:
        _groupListener?.onRevokeAdministrator(groupID, opUser, groupMemberList);

        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_GROUP_INFO_CHANGE:
        // changeType 7 为群属性变更，通过 GroupAttributeChanged 回调，这里不做处理
        // C 接口是从接收的消息转换的 GroupTipsEvent，不像 native 那样底层统一做了过滤
        groupChangeInfoList.removeWhere((changeInfo) => changeInfo.type == 7);
        if (groupChangeInfoList.isNotEmpty) {
          _groupListener?.onGroupInfoChanged(groupID, groupChangeInfoList);
        }

        // 检测全员禁言变更，额外触发 onAllGroupMembersMuted 回调
        for (var changeInfo in groupChangeInfoList) {
          if (changeInfo.type == GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_SHUT_UP_ALL) {
            _groupListener?.onAllGroupMembersMuted(groupID, changeInfo.boolValue ?? false);
            break;
          }
        }

        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_MEMBER_INFO_CHANGE:
        memberChangeInfoList.removeWhere((member) => member.userID == loginUser);
        if (groupMemberList.isNotEmpty) {
          _groupListener?.onMemberInfoChanged(groupID, memberChangeInfoList);
        }

        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_TOPIC_INFO_CHANGE:
        // 这里没有该通知
        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_PINNED_MESSAGE_ADDED:   
        // 无此通知
        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_PINNED_MESSAGE_DELETED:
        // 无此通知
        break;
      default:
        break;
    }
  }

  static void _notifyGroupReport(V2TimGroupReportElem? v2timGroupReport) async {
    if (v2timGroupReport == null) {
      print('invalid group report');
      return;
    }

    final groupID = v2timGroupReport.groupID;
    final opUserID = v2timGroupReport.opUserID;
    final opUserInfo = v2timGroupReport.opUserInfo;
    final opMemberInfo = v2timGroupReport.opMemberInfo;
    final reason = v2timGroupReport.reason;
    final customData = v2timGroupReport.customData;
    final platform = v2timGroupReport.platform;
    final shutUpTime = v2timGroupReport.shutUpTime;
    final messageReceiveOpt = v2timGroupReport.messageReceiveOpt;
    final loginUser = TIMManager.instance.getLoginUser();
    V2TimUserFullInfo? selfInfo = V2TimUserFullInfo(userID: loginUser);

    switch (v2timGroupReport.type) {
      case V2TimGroupReportElem.kTIMGroupReport_AddRequest:
        _groupListener?.onReceiveJoinApplication(groupID, opMemberInfo!, reason!);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_AddAccept:
        var userInfoList = await TIMManager.instance.getUsersInfo(userIDList: [loginUser]);
        if (userInfoList.data != null && userInfoList.data!.isNotEmpty) {
          selfInfo = userInfoList.data!.first;
        }
        var selfMemberInfoForEnter = V2TimGroupMemberInfo(userID: loginUser, nickName: selfInfo.nickName, faceUrl: selfInfo.faceUrl);

        _groupListener?.onMemberEnter(groupID, [selfMemberInfoForEnter]);
        _groupListener?.onApplicationProcessed(groupID, opMemberInfo!, true, reason!);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_AddRefuse:
        _groupListener?.onApplicationProcessed(groupID, opMemberInfo!, false, reason!);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_BeKicked:
        var userInfoListForKicked = await TIMManager.instance.getUsersInfo(userIDList: [loginUser]);
        if (userInfoListForKicked.data != null && userInfoListForKicked.data!.isNotEmpty) {
          selfInfo = userInfoListForKicked.data!.first;
        }

        var selfMemberInfoForKicked = V2TimGroupMemberInfo(userID: loginUser, nickName: selfInfo.nickName, faceUrl: selfInfo.faceUrl);
        _groupListener?.onMemberKicked(groupID, opMemberInfo!, [selfMemberInfoForKicked]);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_Delete:
        _groupListener?.onGroupDismissed(groupID, opMemberInfo!);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_Create:
        _groupListener?.onGroupCreated(groupID);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_Invite:
        var userInfoListForInvite = await TIMManager.instance.getUsersInfo(userIDList: [loginUser]);
        if (userInfoListForInvite.data != null && userInfoListForInvite.data!.isNotEmpty) {
          selfInfo = userInfoListForInvite.data!.first;
        }

        var selfMemberInfoForInvite = V2TimGroupMemberInfo(userID: loginUser, nickName: selfInfo.nickName, faceUrl: selfInfo.faceUrl);
        _groupListener?.onMemberInvited(groupID, opMemberInfo!, [selfMemberInfoForInvite]);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_Quit:
        _groupListener?.onQuitFromGroup(groupID);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_GrantAdmin:
        // 不做处理

        break;
      case V2TimGroupReportElem.kTIMGroupReport_CancelAdmin:
        // 不做处理

        break;
      case V2TimGroupReportElem.kTIMGroupReport_GroupRecycle:
        _groupListener?.onGroupRecycled(groupID, opMemberInfo!);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_InviteReqToInvitee:
        // 暂时未暴露该通知

        break;
      case V2TimGroupReportElem.kTIMGroupReport_InviteAccept:
        _groupListener?.onApplicationProcessed(groupID, opMemberInfo!, true, reason!);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_InviteRefuse:
        _groupListener?.onApplicationProcessed(groupID, opMemberInfo!, false, reason!);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_ReadReport:
        // 无此通知

        break;
      case V2TimGroupReportElem.kTIMGroupReport_UserDefine:
        _groupListener?.onReceiveRESTCustomData(groupID, customData!);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_ShutUpMember:
        _groupListener?.onMemberInfoChanged(groupID, [V2TimGroupMemberChangeInfo(userID: loginUser, muteTime: shutUpTime)]);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_TopicCreate:
        // 无此通知

        break;
      case V2TimGroupReportElem.kTIMGroupReport_TopicDelete:
        // 无此通知

        break;
      case V2TimGroupReportElem.kTIMGroupReport_GroupMessageRead:
        // 无此通知

        break;
      case V2TimGroupReportElem.kTIMGroupReport_GroupMessageRecvOption:
        V2TimGroupChangeInfo changeInfo = V2TimGroupChangeInfo(
          type:GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_RECEIVE_MESSAGE_OPT,
          intValue: messageReceiveOpt);

        _groupListener?.onGroupInfoChanged(groupID, [changeInfo]);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_BannedFromGroup:
        var userInfoListForBanned = await TIMManager.instance.getUsersInfo(userIDList: [loginUser]);
        if (userInfoListForBanned.data != null && userInfoListForBanned.data!.isNotEmpty) {
          selfInfo = userInfoListForBanned.data!.first;
        }

        var selfMemberInfoForBanned = V2TimGroupMemberInfo(userID: loginUser, nickName: selfInfo.nickName, faceUrl: selfInfo.faceUrl);
        _groupListener?.onMemberKicked(groupID, opMemberInfo!, [selfMemberInfoForBanned]);

        break;
      case V2TimGroupReportElem.kTIMGroupReport_UnbannedFromGroup:
        // 暂时没有该通知

        break;
      case V2TimGroupReportElem.kTIMGroupReport_InviteReqToAdmin:
        _groupListener?.onReceiveJoinApplication(groupID, opMemberInfo!, reason!);

        break;
      default:
        print("invalid group report type");
        break;
    }
  }

}