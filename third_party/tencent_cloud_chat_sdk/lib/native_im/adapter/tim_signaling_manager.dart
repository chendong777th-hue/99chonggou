import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:tencent_cloud_chat_sdk/enum/V2TimSignalingListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_signaling_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_message_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_imsdk_bindings_generated.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_library_manager.dart';

class TIMSignalingManager {
  static TIMSignalingManager instance = TIMSignalingManager();
  late V2TimSignalingListener _signalingListener;
  List<V2TimSignalingListener> v2TimSignalingListenerList = List.empty(growable: true);

  TIMSignalingManager();

  void init() {
    _initInternalSignalingListener();
  }

  void addSignalingListener(V2TimSignalingListener? listener) {
    if (listener == null || v2TimSignalingListenerList.contains(listener)) {
      return;
    }

    v2TimSignalingListenerList.add(listener);
  }

  void removeSignalingListener({V2TimSignalingListener? listener}) {
    if (listener == null) {
      v2TimSignalingListenerList.clear();
    } else {
      v2TimSignalingListenerList.remove(listener);
    }
  }

  Future<V2TimValueCallback<String>> invite({
    required String invitee,
    required String data,
    int timeout = 30,
    bool onlineUserOnly = false,
    OfflinePushInfo? offlinePushInfo,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<String>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('invite');
    Completer<V2TimValueCallback<String>> completer = Completer();
    String inviteID = '';
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<String> callbackResult = V2TimValueCallback<String>.fromJson(jsonResult);
      callbackResult.data = inviteID;
      completer.complete(callbackResult);
    }
    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    Pointer<Char> pInvitee = Tools.string2PointerChar(invitee);
    Pointer<Char> pData = Tools.string2PointerChar(data);
    Pointer<Char> pOfflinePushInfo = Tools.string2PointerChar(json.encode(offlinePushInfo?.toJson() ?? {}));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    Pointer<Char> pInviteID = NativeLibraryManager.bindings.DartInvite(pInvitee, pData, onlineUserOnly, pOfflinePushInfo, timeout, Pointer<Char>.fromAddress(0), pUserData);
    inviteID = Tools.pointerChar2String(pInviteID);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pInvitee, pData, pOfflinePushInfo, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<String>> inviteInGroup({
    required String groupID,
    required List<String> inviteeList,
    required String data,
    int timeout = 30,
    bool onlineUserOnly = false,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<String>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    if (inviteeList.isEmpty) {
      return V2TimValueCallback<String>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    String userData = Tools.generateUserData('inviteInGroup');
    String inviteID = '';
    Completer<V2TimValueCallback<String>> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<String> callbackResult = V2TimValueCallback<String>.fromJson(jsonResult);
      callbackResult.data = inviteID;
      completer.complete(callbackResult);
    }
    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pInviteeList = Tools.string2PointerChar(json.encode(inviteeList));
    Pointer<Char> pData = Tools.string2PointerChar(data);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    Pointer<Char> pInviteID = NativeLibraryManager.bindings.DartInviteInGroup(pGroupID, pInviteeList, pData, onlineUserOnly, timeout, Pointer<Char>.fromAddress(0), pUserData);
    inviteID = Tools.pointerChar2String(pInviteID);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pInviteeList, pData, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> cancel({
    required String inviteID,
    String? data,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('cancel');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pInviteID = Tools.string2PointerChar(inviteID);
    Pointer<Char> pData = Tools.string2PointerChar(data ?? '');
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartCancel(pInviteID, pData, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pInviteID, pData, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> accept({
    required String inviteID,
    String? data,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('accept');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pInviteID = Tools.string2PointerChar(inviteID);
    Pointer<Char> pData = Tools.string2PointerChar(data ?? '');
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartAccept(pInviteID, pData, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pInviteID, pData, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> reject({
    required String inviteID,
    String? data,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('reject');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);
  
    Pointer<Char> pInviteID = Tools.string2PointerChar(inviteID);
    Pointer<Char> pData = Tools.string2PointerChar(data ?? '');
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartReject(pInviteID, pData, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pInviteID, pData, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimSignalingInfo>> getSignalingInfo({
    required String msgID,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimSignalingInfo>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    V2TimValueCallback<List<V2TimMessage>> findResult = await TIMMessageManager.instance.findMessages(messageIDList: [msgID]);
    if (findResult.code != TIMErrCode.ERR_SUCC.value) {
      print("deleteMessageFromLocalStorage, find message failed");
      return V2TimValueCallback<V2TimSignalingInfo>(code: findResult.code, desc: findResult.desc);
    }

    List<V2TimMessage> msgList = findResult.data!;
    if (msgList.isEmpty) {
      print("deleteMessageFromLocalStorage, message not found");
      return V2TimValueCallback<V2TimSignalingInfo>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "message not found");
    }

    String userData = Tools.generateUserData('getSignalingInfo');
    Completer<V2TimValueCallback<V2TimSignalingInfo>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<V2TimSignalingInfo>(userData, completer);

    V2TimMessage message = msgList[0];
    Pointer<Char> pMsgID = Tools.string2PointerChar(json.encode(message.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetSignalingInfo(pMsgID, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pMsgID, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> modifyInvitation({
    required String inviteID,
    String? data,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('modifyInvitation');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pInviteID = Tools.string2PointerChar(inviteID);
    Pointer<Char> pData = Tools.string2PointerChar(data ?? '');
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartModifyInvitation(pInviteID, pData, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pInviteID, pData, pUserData]);
      return value;
    });
  }

  void _initInternalSignalingListener() {
    _signalingListener = V2TimSignalingListener(
      onReceiveNewInvitation: (String inviteID, String inviter, String groupID, List<String> inviteeList, String data) {
        for (var listener in v2TimSignalingListenerList) {
          listener.onReceiveNewInvitation(inviteID, inviter, groupID, inviteeList, data);
        }
      },

      onInviteeAccepted: (String inviteID, String invitee, String data) {
        for (var listener in v2TimSignalingListenerList) {
          listener.onInviteeAccepted(inviteID, invitee, data);
        }
      },

      onInviteeRejected: (String inviteID, String invitee, String data) {
        for (var listener in v2TimSignalingListenerList) {
          listener.onInviteeRejected(inviteID, invitee, data);
        }
      },

      onInvitationCancelled: (String inviteID, String inviter, String data) {
        for (var listener in v2TimSignalingListenerList) {
          listener.onInvitationCancelled(inviteID, inviter, data);
        }
      },

      onInvitationTimeout: (String inviteID, List<String> inviteeList) {
        for (var listener in v2TimSignalingListenerList) {
          listener.onInvitationTimeout(inviteID, inviteeList);
        }
      }
    );

    NativeLibraryManager.setSignalingListener(_signalingListener);
  }
}