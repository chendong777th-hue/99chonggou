import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSignalingListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/enum/v2_signaling_action_type.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_msg_create_info_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_signaling_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_cloud_chat_sdk_web.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TIMSignalingManager {
  ///@nodoc
  static Map<String, V2TimSignalingListener> signalingListenerList = {};
  Map<String, Timer?> timeoutTimer = {};
  static Map<String, dynamic> currentInvite = {};

  ///添加信令监听
  ///
  Future<void> addSignalingListenerForWeb({
    required V2TimSignalingListener listener,
    String? listenerUuid,
  }) {
    signalingListenerList[listenerUuid ?? ""] = listener;
    return Future.value();
  }

  ///移除信令监听
  ///
  Future<void> removeSignalingListener({
    V2TimSignalingListener? listener,
    required String listenerUuid,
  }) {
    var listenerUuid = "";
    if (listener != null) {
      listenerUuid = signalingListenerList.keys.firstWhere(
          (k) => signalingListenerList[k] == listener,
          orElse: () => "");
      signalingListenerList.remove(listenerUuid);
    } else {
      signalingListenerList.clear();
    }
    return Future.value();
  }

  Future<int> _sendCustomData({
    required String data,
    String? groupID,
    String? toUserId,
    OfflinePushInfo? pusinfo,
    bool? onlineUserOnly,
  }) async {
    V2TimValueCallback<V2TimMsgCreateInfoResult> res =
        await TencentCloudChatSdkWeb().createCustomMessage(
      data: data,
      extension: "",
      desc: "",
    );
    if (res.data != null) {
      String id = res.data!.id!;
      V2TimValueCallback<V2TimMessage> callback =
          await TencentCloudChatSdkWeb().sendMessage(
        id: id,
        receiver: toUserId ?? "",
        groupID: groupID ?? "",
        offlinePushInfo: pusinfo?.toJson(),
        onlineUserOnly: onlineUserOnly ?? false,
      );
      return callback.code;
    }
    return -1;
  }

  _timeout(int timeout, String inviteID) async {
    if (timeout > 0) {
      timeoutTimer[inviteID] =
          Timer.periodic(Duration(seconds: timeout), (timer) async {
        if (timeoutTimer[inviteID] != null) {
          timeoutTimer[inviteID]!.cancel();
          timeoutTimer[inviteID] = null;
          if (timeoutTimer[inviteID]!.isActive) {
            // check if there is a avilabal signal
            if (currentInvite["inviteID"] != null) {
              // V2TimValueCallback<String> user = await TencentCloudChatSdkWeb().getLoginUser();
              // send a timeout message
              List<String> inviteeList =
                  List<String>.from(currentInvite["inviteeList"]);
              if (inviteeList.isNotEmpty) {
                String data = _buildSignalData(
                  type: V2SignalingActionType
                      .SIGNALING_ACTION_TYPE_INVITE_TIMEOUT,
                  customData: currentInvite["data"],
                  inviteID: currentInvite["inviteID"],
                  timeout: currentInvite["timeout"],
                  groupID: currentInvite["groupID"],
                  inviter: currentInvite["inviter"],
                  inviteeList: inviteeList,
                );
                debugPrint("send timeout message");
                await _sendCustomData(
                  data: data,
                  groupID: currentInvite["groupID"] ?? "",
                  toUserId:
                      _isGroupCall(currentInvite) ? "" : inviteeList.first,
                );
                signalingListenerList.forEach((key, value) {
                  value.onInvitationTimeout(inviteID, inviteeList);
                });
                currentInvite = {};
              }
            }
          }
        }
      });
    }
  }

  bool _isGroupCall(Map<String, dynamic> callinfo) {
    if (callinfo["groupID"] == null) {
      return false;
    } else {
      if (callinfo["groupID"].isNotEmpty) {
        return true;
      }
      return false;
    }
  }

  _onCallbackTimeout(Map<String, dynamic> callinfo) async {
    int timeout = callinfo["timeout"] ?? 30;
    String inviteID = callinfo["inviteID"] ?? "";
    if (timeout >= 0 && inviteID.isNotEmpty) {
      V2TimValueCallback<String> user =
          await TencentCloudChatSdkWeb().getLoginUser();
      // The countdown on the receiver side is two seconds less because of network transfer time
      timeoutTimer[inviteID] = Timer.periodic(
          Duration(seconds: timeout - 2 > 0 ? timeout - 2 : timeout), (timer) {
        // List<String> inviteeList = callinfo["inviteeList"];
        callinfo["inviteeList"] = [user.data];
        _sendCustomData(
            data: json.encode(callinfo),
            toUserId: _isGroupCall(callinfo) ? "" : callinfo["inviter"],
            groupID: callinfo["groupID"]);
      });
    }
  }

  beforeCallback(int type, Map<String, dynamic> callinfo) async {
    switch (type) {
      case V2SignalingActionType.SIGNALING_ACTION_TYPE_ACCEPT_INVITE:
        List<String> inviteeList = List<String>.from(callinfo["inviteeList"]);
        if (inviteeList.isNotEmpty) {
          List<String> currentInviteeList =
              List<String>.from(currentInvite["inviteeList"]);
          for (var element in inviteeList) {
            currentInviteeList.remove(element);
          }
          currentInvite["inviteeList"] = currentInviteeList;
          if (currentInviteeList.isEmpty) {
            currentInvite = {};
          }
        }
        break;
      case V2SignalingActionType.SIGNALING_ACTION_TYPE_CANCEL_INVITE:
        String inviteID = callinfo["callinfo"] ?? "";
        if (inviteID.isNotEmpty) {
          currentInvite = {};
        }
        break;
      case V2SignalingActionType.SIGNALING_ACTION_TYPE_INVITE:
        // handle on invited and timeout
        currentInvite = callinfo;
        _onCallbackTimeout(callinfo);
        break;
      case V2SignalingActionType.SIGNALING_ACTION_TYPE_INVITE_TIMEOUT:
        List<String> inviteeList = List<String>.from(callinfo["inviteeList"]);
        if (inviteeList.isNotEmpty) {
          List<String> currentInviteeList =
              List<String>.from(currentInvite["inviteeList"]);
          for (var element in inviteeList) {
            currentInviteeList.remove(element);
          }
          currentInvite["inviteeList"] = currentInviteeList;
          if (currentInviteeList.isEmpty) {
            currentInvite = {};
          }
        }
        break;
      case V2SignalingActionType.SIGNALING_ACTION_TYPE_REJECT_INVITE:
        List<String> inviteeList = List<String>.from(callinfo["inviteeList"]);
        if (inviteeList.isNotEmpty) {
          List<String> currentInviteeList =
              List<String>.from(currentInvite["inviteeList"]);
          for (var element in inviteeList) {
            currentInviteeList.remove(element);
          }
          currentInvite["inviteeList"] = currentInviteeList;
          if (currentInviteeList.isEmpty) {
            currentInvite = {};
          }
        }
        break;
    }
  }

  String _buildSignalData({
    required int type,
    required String customData,
    required String inviteID,
    required int timeout,
    String? groupID,
    required List<String> inviteeList,
    required String inviter,
    bool? onlineUserOnly,
  }) {
    Map<String, dynamic> signal = {
      "businessID": 1,
      "inviteID": inviteID,
      "data": customData,
      "inviter": inviter,
      "actionType": type,
      "inviteeList": inviteeList,
      "timeout": timeout,
      "groupID": groupID ?? "",
      "onlineUserOnly": onlineUserOnly ?? false,
    };
    return json.encode(signal);
  }

  Future<V2TimValueCallback<String>> invite({
    required String invitee,
    required String data,
    int timeout = 30,
    bool onlineUserOnly = false,
    OfflinePushInfo? offlinePushInfo,
  }) async {
    // send custom message and handle timeout.
    V2TimValueCallback<String> user =
        await TencentCloudChatSdkWeb().getLoginUser();
    String inviteID = Utils.generateUniqueString();
    String customData = _buildSignalData(
      type: V2SignalingActionType.SIGNALING_ACTION_TYPE_INVITE,
      customData: data,
      inviteID: inviteID,
      timeout: timeout,
      groupID: "",
      inviteeList: [invitee],
      inviter: user.data ?? "",
      onlineUserOnly: onlineUserOnly,
    );
    int code = await _sendCustomData(
      data: customData,
      toUserId: invitee,
      pusinfo: offlinePushInfo,
      onlineUserOnly: onlineUserOnly,
    );
    if (code == 0) {
      currentInvite = json.decode(customData);
      _timeout(timeout, inviteID);
    }
    return V2TimValueCallback(
      code: code,
      data: inviteID,
      desc: code == 0 ? "success" : "error",
    );
  }

  Future<V2TimValueCallback<String>> inviteInGroup({
    required String groupID,
    required List<String> inviteeList,
    required String data,
    int timeout = 30,
    bool onlineUserOnly = false,
  }) async {
    // send custom message and handle timeout.
    String inviteID = Utils.generateUniqueString();
    V2TimValueCallback<String> user =
        await TencentCloudChatSdkWeb().getLoginUser();
    String customData = _buildSignalData(
      type: V2SignalingActionType.SIGNALING_ACTION_TYPE_INVITE,
      customData: data,
      inviteID: inviteID,
      timeout: timeout,
      groupID: groupID,
      inviteeList: inviteeList,
      inviter: user.data ?? "",
    );
    int code = await _sendCustomData(
      data: customData,
      groupID: groupID,
      onlineUserOnly: onlineUserOnly,
    );
    if (code == 0) {
      currentInvite = json.decode(customData);
      _timeout(timeout, inviteID);
    }
    return V2TimValueCallback(
      code: code,
      data: inviteID,
      desc: code == 0 ? "success" : "error",
    );
  }

  Future<V2TimCallback> cancel({
    required String inviteID,
    String? data,
  }) async {
    if (currentInvite[inviteID] != null) {
      List<String> inviteeList =
          List<String>.from(currentInvite["inviteeList"]);
      String customData = _buildSignalData(
        type: V2SignalingActionType.SIGNALING_ACTION_TYPE_CANCEL_INVITE,
        customData: data ?? "",
        inviteID: inviteID,
        timeout: currentInvite["timeout"],
        groupID: currentInvite["groupID"],
        inviteeList: inviteeList,
        inviter: currentInvite["inviter"],
      );
      if (inviteeList.isNotEmpty) {
        int code = await _sendCustomData(
          data: customData,
          groupID: currentInvite["groupID"] ?? "",
          toUserId: _isGroupCall(currentInvite) ? "" : inviteeList.first,
        );
        currentInvite = {};
        if (timeoutTimer[inviteID] != null) {
          timeoutTimer[inviteID]!.cancel();
          timeoutTimer[inviteID] = null;
        }
        return V2TimCallback(code: code, desc: code == 0 ? "success" : "error");
      }
    }
    return V2TimCallback(
      code: 8010,
      desc: "inviteID is invalid or invitation has been processed",
    );
  }

  rmUserFormInviteeList(String user, String invitID) {
    if (currentInvite["invitID"] != null && user.isNotEmpty) {
      List<String> inviteeList =
          List<String>.from(currentInvite["inviteeList"]);
      if (inviteeList.contains(user)) {
        inviteeList.remove(user);
        if (inviteeList.isEmpty) {
          currentInvite = {};
        } else {
          currentInvite["inviteeList"] = inviteeList;
        }
      }
    }
  }

  Future<V2TimCallback> accept({
    required String inviteID,
    String? data,
  }) async {
    if (currentInvite[inviteID] != null) {
      V2TimValueCallback<String> user =
          await TencentCloudChatSdkWeb().getLoginUser();
      String customData = _buildSignalData(
        type: V2SignalingActionType.SIGNALING_ACTION_TYPE_ACCEPT_INVITE,
        customData: data ?? "",
        inviteID: inviteID,
        timeout: currentInvite["timeout"],
        groupID: currentInvite["groupID"],
        inviteeList: [user.data ?? ""],
        inviter: currentInvite["inviter"],
      );
      int code = await _sendCustomData(
        data: customData,
        groupID: currentInvite["groupID"] ?? "",
        toUserId: _isGroupCall(currentInvite) ? "" : currentInvite["inviter"],
      );
      rmUserFormInviteeList(user.data ?? "", inviteID);

      if (timeoutTimer[inviteID] != null) {
        timeoutTimer[inviteID]!.cancel();
        timeoutTimer[inviteID] = null;
      }

      return V2TimCallback(code: code, desc: code == 0 ? "success" : "error");
    }
    return V2TimCallback(
        code: 8010,
        desc: "inviteID is invalid or invitation has been processed");
  }

  Future<V2TimCallback> reject({
    required String inviteID,
    String? data,
  }) async {
    if (currentInvite[inviteID] != null) {
      V2TimValueCallback<String> user =
          await TencentCloudChatSdkWeb().getLoginUser();
      String customData = _buildSignalData(
          type: V2SignalingActionType.SIGNALING_ACTION_TYPE_REJECT_INVITE,
          customData: data ?? "",
          inviteID: inviteID,
          timeout: currentInvite["timeout"],
          groupID: currentInvite["groupID"],
          inviteeList: [user.data!],
          inviter: currentInvite["inviter"]);
      int code = await _sendCustomData(
        data: customData,
        groupID: currentInvite["groupID"] ?? "",
        toUserId: _isGroupCall(currentInvite) ? "" : currentInvite["inviter"],
      );
      rmUserFormInviteeList(user.data ?? "", inviteID);
      if (timeoutTimer[inviteID] != null) {
        timeoutTimer[inviteID]!.cancel();
        timeoutTimer[inviteID] = null;
      }
      return V2TimCallback(code: code, desc: code == 0 ? "success" : "error");
    }
    return V2TimCallback(
        code: 8010,
        desc: "inviteID is invalid or invitation has been processed");
  }

  /// 获取信令信息
  ///
  /// 如果 invite 设置 onlineUserOnly 为 false，每次信令操作（包括 invite、cancel、accept、reject、timeout）都会产生一条自定义消息， 该消息会通过 V2TIMAdvancedMsgListener -> onRecvNewMessage 抛给用户，用户也可以通过历史消息拉取，如果需要根据信令信息做自定义化文本展示，可以调用下面接口获取信令信息。
  ///
  /// 参数
  /// msg	消息对象
  ///
  /// 返回
  /// V2TIMSignalingInfo 信令信息，如果为 null，则 msg 不是一条信令消息。
  ///
  Future<V2TimValueCallback<V2TimSignalingInfo>> getSignalingInfo({
    required String msgID,
  }) async {
    return V2TimValueCallback<V2TimSignalingInfo>.fromJson({
      "code": -1,
      "desc": "web not support this api",
    });
  }

  Future<V2TimCallback> addInvitedSignaling({
    required V2TimSignalingInfo info,
  }) async {
    return V2TimCallback.fromJson({
      "code": -1,
      "desc": "web not support this api",
    });
  }
}
