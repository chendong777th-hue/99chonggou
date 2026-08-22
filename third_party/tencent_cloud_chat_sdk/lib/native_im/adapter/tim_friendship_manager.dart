import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:tencent_cloud_chat_sdk/enum/V2TimFriendshipListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_response_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_follow_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_follow_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_follow_type_check_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_add_friend_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application_delete_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application_handle_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_check_friend_type_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_check_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_delete_friend_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_group_create_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_group_modify_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_group.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_official_account_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_official_account_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_imsdk_bindings_generated.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_library_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';


class TIMFriendshipManager {
  static TIMFriendshipManager instance = TIMFriendshipManager();
  late V2TimFriendshipListener _friendshipListener;
  List<V2TimFriendshipListener> v2TimFriendshipListenerList = List.empty(growable: true);

  TIMFriendshipManager();

  void init() {
    _initInternalFriendshipListener();
  }

  Future<void> setFriendListener({
    required V2TimFriendshipListener listener,
  }) {
    addFriendListener(listener: listener);
    return Future.value();
  }

  Future<void> addFriendListener({V2TimFriendshipListener? listener}) {
    if (listener == null || v2TimFriendshipListenerList.contains(listener)) {
      return Future.value();
    }

    v2TimFriendshipListenerList.add(listener);
    return Future.value();
  }

  Future<void> removeFriendListener({V2TimFriendshipListener? listener}) {
    if (listener == null) {
      v2TimFriendshipListenerList.clear();
    } else {
      v2TimFriendshipListenerList.remove(listener);
    }

    return Future.value();
  }

  Future<V2TimValueCallback<List<V2TimFriendInfo>>> getFriendList() async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFriendInfo>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getFriendList');
    Completer<V2TimValueCallback<List<V2TimFriendInfo>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFriendInfo>>(userData, completer);

    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetFriendList(pUserData);

    return completer.future;
  }

  Future<V2TimValueCallback<List<V2TimFriendInfoResult>>> getFriendsInfo({
    required List<String> userIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFriendInfoResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getFriendsInfo');
    Completer<V2TimValueCallback<List<V2TimFriendInfoResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFriendInfoResult>>(userData, completer);

    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(userIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartGetFriendsInfo(pUserIDList, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return V2TimValueCallback<List<V2TimFriendInfoResult>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> setFriendInfo({
    required String userID,
    String? friendRemark,
    Map<String, String>? friendCustomInfo,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('setFriendInfo');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    V2TimFriendInfo param = V2TimFriendInfo(userID: userID, friendRemark: friendRemark, friendCustomInfo: friendCustomInfo);
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toModifyJsonParam()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartSetFriendInfo(pJsonParam, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimFriendOperationResult>> addFriend({
    required String userID,
    String? remark,
    String? friendGroup,
    String? addWording,
    String? addSource,
    required FriendTypeEnum addType,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimFriendOperationResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('addFriend');
    Completer<V2TimValueCallback<V2TimFriendOperationResult>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<V2TimFriendOperationResult>(userData, completer);

    V2TimFriendAddFriendParam param = V2TimFriendAddFriendParam(
      userID: userID,
      remark: remark,
      friendGroup: friendGroup,
      addWording: addWording,
      addSource: addSource,
      addType: addType,
    );

    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartAddFriend(pJsonParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return V2TimValueCallback<V2TimFriendOperationResult>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFriendOperationResult>>> deleteFromFriendList({
    required List<String> userIDList,
    required FriendTypeEnum deleteType,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFriendOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('deleteFromFriendList');
    Completer<V2TimValueCallback<List<V2TimFriendOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFriendOperationResult>>(userData, completer);

    V2TimFriendDeleteFriendParam param = V2TimFriendDeleteFriendParam(
      userIDList: userIDList,
      deleteType: deleteType,
    );
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartDeleteFromFriendList(pJsonParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return V2TimValueCallback<List<V2TimFriendOperationResult>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFriendCheckResult>>> checkFriend({
    required List<String> userIDList,
    required FriendTypeEnum checkType,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFriendCheckResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('checkFriend');
    Completer<V2TimValueCallback<List<V2TimFriendCheckResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFriendCheckResult>>(userData, completer);

    V2TimFriendCheckFriendTypeParam param = V2TimFriendCheckFriendTypeParam(
      userIDList: userIDList,
      checkType: checkType,
    );

    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartCheckFriend(pJsonParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return V2TimValueCallback<List<V2TimFriendCheckResult>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimFriendApplicationResult>> getFriendApplicationList() async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimFriendApplicationResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getFriendApplicationList');
    Completer<V2TimValueCallback<V2TimFriendApplicationResult>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<V2TimFriendApplicationResult>(userData, completer);

    Pointer<Char> pJsonParam = Tools.string2PointerChar('not used');  // 该参数非空即可，内部不再使用
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartGetFriendApplicationList(pJsonParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return V2TimValueCallback<V2TimFriendApplicationResult>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimFriendOperationResult>> acceptFriendApplication({
    required FriendResponseTypeEnum responseType,
    FriendApplicationTypeEnum? type,
    required String userID,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimFriendOperationResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('acceptFriendApplication');
    Completer<V2TimValueCallback<V2TimFriendOperationResult>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<V2TimFriendOperationResult>(userData, completer);

    int cResponseType = CFriendResponseAction.responseActionAgree;
    switch (responseType) {
      case FriendResponseTypeEnum.V2TIM_FRIEND_ACCEPT_AGREE:
        cResponseType = CFriendResponseAction.responseActionAgree;
        break;
      case FriendResponseTypeEnum.V2TIM_FRIEND_ACCEPT_AGREE_AND_ADD:
        cResponseType = CFriendResponseAction.responseActionAgreeAndAdd;
        break;
      default:
        print('invalid responseType');
        break;
    }

    V2TimFriendApplicationHandleParam param = V2TimFriendApplicationHandleParam(userID: userID, responseType: cResponseType);
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartHandleFriendAddRequest(pJsonParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return V2TimValueCallback<V2TimFriendOperationResult>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimFriendOperationResult>> refuseFriendApplication({
    FriendApplicationTypeEnum? type,
    required String userID,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimFriendOperationResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('refuseFriendApplication');
    Completer<V2TimValueCallback<V2TimFriendOperationResult>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<V2TimFriendOperationResult>(userData, completer);

    int cResponseType = CFriendResponseAction.responseActionReject;
    V2TimFriendApplicationHandleParam param = V2TimFriendApplicationHandleParam(userID: userID, responseType: cResponseType);
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartHandleFriendAddRequest(pJsonParam, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> deleteFriendApplication({
    required FriendApplicationTypeEnum type,
    required String userID,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('deleteFriendApplication');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    V2TimFriendApplicationDeleteParam param = V2TimFriendApplicationDeleteParam(userIDList: [userID], applicationType: type);
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartDeleteFriendApplication(pJsonParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> setFriendApplicationRead() async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('setFriendApplicationRead');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartSetFriendApplicationRead(0, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointer(pUserData);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFriendOperationResult>>> addToBlackList({
    required List<String> userIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFriendOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('addToBlackList');
    Completer<V2TimValueCallback<List<V2TimFriendOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFriendOperationResult>>(userData, completer);

    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(userIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartAddToBlackList(pUserIDList, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return V2TimValueCallback<List<V2TimFriendOperationResult>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFriendOperationResult>>> deleteFromBlackList({
    required List<String> userIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFriendOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('deleteFromBlackList');
    Completer<V2TimValueCallback<List<V2TimFriendOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFriendOperationResult>>(userData, completer);

    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(userIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartDeleteFromBlackList(pUserIDList, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return V2TimValueCallback<List<V2TimFriendOperationResult>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFriendInfo>>> getBlackList() async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFriendInfo>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getBlackList');
    Completer<V2TimValueCallback<List<V2TimFriendInfo>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFriendInfo>>(userData, completer);

    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetBlackList(pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointer(pUserData);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFriendOperationResult>>> createFriendGroup({
    required String groupName,
    List<String>? userIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFriendOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('createFriendGroup');
    Completer<V2TimValueCallback<List<V2TimFriendOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFriendOperationResult>>(userData, completer);

    V2TimFriendGroupCreateParam param = V2TimFriendGroupCreateParam(groupNameList: [groupName], userIDList: userIDList ?? []);
    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartCreateFriendGroup(pParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return V2TimValueCallback<List<V2TimFriendOperationResult>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFriendGroup>>> getFriendGroups({
    List<String>? groupNameList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFriendGroup>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getFriendGroups');
    Completer<V2TimValueCallback<List<V2TimFriendGroup>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFriendGroup>>(userData, completer);

    Pointer<Char> pGroupNameList = Tools.string2PointerChar(json.encode(groupNameList ?? []));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartGetFriendGroupList(pGroupNameList, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupNameList, pUserData]);
      return V2TimValueCallback<List<V2TimFriendGroup>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupNameList, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> deleteFriendGroup({
    required List<String> groupNameList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('deleteFriendGroup');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pGroupNameList = Tools.string2PointerChar(json.encode(groupNameList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartDeleteFriendGroup(pGroupNameList, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupNameList, pUserData]);
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupNameList, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> renameFriendGroup({
    required String oldName,
    required String newName,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('renameFriendGroup');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    V2TimFriendGroupModifyParam param = V2TimFriendGroupModifyParam(groupName: oldName, newGroupName: newName);
    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);

    int result = NativeLibraryManager.bindings.DartModifyFriendGroup(pParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFriendOperationResult>>> addFriendsToFriendGroup({
    required String groupName,
    required List<String> userIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFriendOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('addFriendsToFriendGroup');
    Completer<V2TimValueCallback<List<V2TimFriendOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFriendOperationResult>>(userData, completer);

    V2TimFriendGroupModifyParam param = V2TimFriendGroupModifyParam(groupName: groupName, addUserIDList: userIDList);
    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);

    int result = NativeLibraryManager.bindings.DartModifyFriendGroup(pParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return V2TimValueCallback<List<V2TimFriendOperationResult>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFriendOperationResult>>> deleteFriendsFromFriendGroup({
    required String groupName,
    required List<String> userIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFriendOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('deleteFriendsFromFriendGroup');
    Completer<V2TimValueCallback<List<V2TimFriendOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFriendOperationResult>>(userData, completer);

    V2TimFriendGroupModifyParam param = V2TimFriendGroupModifyParam(groupName: groupName, deleteUserIDList: userIDList);
    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);

    int result = NativeLibraryManager.bindings.DartModifyFriendGroup(pParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return V2TimValueCallback<List<V2TimFriendOperationResult>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFriendInfoResult>>> searchFriends({
    required V2TimFriendSearchParam searchParam,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFriendInfoResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('searchFriends');
    Completer<V2TimValueCallback<List<V2TimFriendInfoResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFriendInfoResult>>(userData, completer);

    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(searchParam.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);

    int result = NativeLibraryManager.bindings.DartSearchFriends(pParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return V2TimValueCallback<List<V2TimFriendInfoResult>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> subscribeOfficialAccount({
    required String officialAccountID,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('subscribeOfficialAccount');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pOfficialAccountID = Tools.string2PointerChar(officialAccountID);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartSubscribeOfficialAccount(pOfficialAccountID, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pOfficialAccountID, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> unsubscribeOfficialAccount({
    required String officialAccountID,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('unsubscribeOfficialAccount');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pOfficialAccountID = Tools.string2PointerChar(officialAccountID);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartUnsubscribeOfficialAccount(pOfficialAccountID, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pOfficialAccountID, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimOfficialAccountInfoResult>>> getOfficialAccountsInfo({
    required List<String> officialAccountIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimOfficialAccountInfoResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getOfficialAccountsInfo');
    Completer<V2TimValueCallback<List<V2TimOfficialAccountInfoResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimOfficialAccountInfoResult>>(userData, completer);

    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(officialAccountIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartGetOfficialAccountsInfo(pParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return V2TimValueCallback<List<V2TimOfficialAccountInfoResult>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFollowOperationResult>>> followUser({
    required List<String> userIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFollowOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('followUser');
    Completer<V2TimValueCallback<List<V2TimFollowOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFollowOperationResult>>(userData, completer);

    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(userIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartFollowUser(pUserIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFollowOperationResult>>> unfollowUser({
    required List<String> userIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFollowOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('unfollowUser');
    Completer<V2TimValueCallback<List<V2TimFollowOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFollowOperationResult>>(userData, completer);

    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(userIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartUnfollowUser(pUserIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimUserInfoResult>> getMyFollowingList({
    required String nextCursor,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimUserInfoResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getMyFollowingList');
    Completer<V2TimValueCallback<V2TimUserInfoResult>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<V2TimUserInfoResult>(userData, completer);

    Pointer<Char> pNextCursor = Tools.string2PointerChar(nextCursor);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetMyFollowingList(pNextCursor, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pNextCursor, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimUserInfoResult>> getMyFollowersList({
    required String nextCursor,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimUserInfoResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getMyFollowersList');
    Completer<V2TimValueCallback<V2TimUserInfoResult>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<V2TimUserInfoResult>(userData, completer);

    Pointer<Char> pNextCursor = Tools.string2PointerChar(nextCursor);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetMyFollowersList(pNextCursor, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pNextCursor, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimUserInfoResult>> getMutualFollowersList({
    required String nextCursor,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimUserInfoResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getMutualFollowersList');
    Completer<V2TimValueCallback<V2TimUserInfoResult>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<V2TimUserInfoResult>(userData, completer);

    Pointer<Char> pNextCursor = Tools.string2PointerChar(nextCursor);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetMutualFollowersList(pNextCursor, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pNextCursor, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFollowInfo>>> getUserFollowInfo({
    required List<String> userIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFollowInfo>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getUserFollowInfo');
    Completer<V2TimValueCallback<List<V2TimFollowInfo>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFollowInfo>>(userData, completer);

    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(userIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetUserFollowInfo(pUserIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimFollowTypeCheckResult>>> checkFollowType({
    required List<String> userIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimFollowTypeCheckResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('checkFollowType');
    Completer<V2TimValueCallback<List<V2TimFollowTypeCheckResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimFollowTypeCheckResult>>(userData, completer);

    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(userIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartCheckFollowType(pUserIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  void _initInternalFriendshipListener() {
    _friendshipListener = V2TimFriendshipListener(
      onFriendApplicationListAdded: (List<V2TimFriendApplication> applicationList) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onFriendApplicationListAdded(applicationList);
        }
      },

      onFriendApplicationListDeleted: (List<String> userIDList) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onFriendApplicationListDeleted(userIDList);
        }
      },

      onFriendApplicationListRead: () {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onFriendApplicationListRead();
        }
      },

      onFriendListAdded: (List<V2TimFriendInfo> friendInfoList) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onFriendListAdded(friendInfoList);
        }
      },

      onFriendListDeleted: (List<String> userIDList) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onFriendListDeleted(userIDList);
        }
      },

      onBlackListAdd: (List<V2TimFriendInfo> friendInfoList) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onBlackListAdd(friendInfoList);
        }
      },

      onBlackListDeleted: (List<String> userIDList) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onBlackListDeleted(userIDList);
        }
      },

      onFriendInfoChanged: (List<V2TimFriendInfo> friendInfoList) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onFriendInfoChanged(friendInfoList);
        }
      },

      onOfficialAccountSubscribed: (V2TimOfficialAccountInfo officialAccountInfo) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onOfficialAccountSubscribed(officialAccountInfo);
        }
      },

      onOfficialAccountUnsubscribed: (String officialAccountID) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onOfficialAccountUnsubscribed(officialAccountID);
        }
      },

      onOfficialAccountDeleted: (String officialAccountID) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onOfficialAccountDeleted(officialAccountID);
        }
      },

      onOfficialAccountInfoChanged: (V2TimOfficialAccountInfo officialAccountInfo) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onOfficialAccountInfoChanged(officialAccountInfo);
        }
      },

      onMyFollowingListChanged: (List<V2TimUserFullInfo> userInfoList, bool isAdd) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onMyFollowingListChanged(userInfoList, isAdd);
        }
      },

      onMyFollowersListChanged: (List<V2TimUserFullInfo> userInfoList, bool isAdd) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onMyFollowersListChanged(userInfoList, isAdd);
        }
      },

      onMutualFollowersListChanged: (List<V2TimUserFullInfo> userInfoList, bool isAdd) {
        for (var listener in v2TimFriendshipListenerList) {
          listener.onMutualFollowersListChanged(userInfoList, isAdd);
        }
      },
    );

    NativeLibraryManager.setFriendshipListener(_friendshipListener);
  }
}