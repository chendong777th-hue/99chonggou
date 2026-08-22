import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:tencent_cloud_chat_sdk/enum/V2TimCommunityListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_create_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_create_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_info_modify_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_member_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_member_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info_set_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_permission_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_imsdk_bindings_generated.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_library_manager.dart';

class TIMCommunityManager {
  static TIMCommunityManager instance = TIMCommunityManager();
  late V2TimCommunityListener _communityListener;
  List<V2TimCommunityListener> v2TimCommunityListenerList = List.empty(growable: true);

  TIMCommunityManager();

  void init() {
    _initInternalCommunityListener();
  }

  void addCommunityListener(V2TimCommunityListener? listener) {
    if (listener == null || v2TimCommunityListenerList.contains(listener)) {
      return;
    }

    v2TimCommunityListenerList.add(listener);
  }

  void removeCommunityListener({V2TimCommunityListener? listener}) {
    if (listener == null) {
      v2TimCommunityListenerList.clear();
    } else {
      v2TimCommunityListenerList.remove(listener);
    }
  }

  Future<V2TimValueCallback<String>> createCommunity({
    required V2TimGroupInfo info,
    required List<V2TimCreateGroupMemberInfo> memberList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<String>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('createCommunity');
    Completer<V2TimValueCallback<String>> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<Map<String, String>> v2timValueCallback =
          V2TimValueCallback<Map<String, String>>.fromJson(jsonResult);
      String groupID =
          v2timValueCallback.data?['create_group_result_groupid'] ?? '';
      completer.complete(V2TimValueCallback<String>(
          code: v2timValueCallback.code,
          desc: v2timValueCallback.desc,
          data: groupID));
    }

    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    V2TimGroupCreateParam jsonParam = V2TimGroupCreateParam.fromGroupInfo(info);
    jsonParam.memberList = memberList.map((e) => V2TimGroupMember(userID: e.userID, role: GroupMemberRoleTypeEnum.values[e.role])).toList();
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(jsonParam.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartCreateCommunity(pJsonParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return V2TimValueCallback<String>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimGroupInfo>>> getJoinedCommunityList() async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimGroupInfo>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getJoinedCommunityList');
    Completer<V2TimValueCallback<List<V2TimGroupInfo>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimGroupInfo>>(userData, completer);

    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetJoinedCommunityList(pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointer(pUserData);
      return value;
    });
  }

  Future<V2TimValueCallback<String>> createTopicInCommunity({
    required String groupID,
    required V2TimTopicInfo topicInfo,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<String>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('createTopicInCommunity');
    Completer<V2TimValueCallback<String>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<String>(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pTopicInfo = Tools.string2PointerChar(json.encode(topicInfo.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartCreateTopicInCommunity(pGroupID, pTopicInfo, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pTopicInfo, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimTopicOperationResult>>> deleteTopicFromCommunity({
    required String groupID,
    required List<String> topicIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimTopicOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('deleteTopicFromCommunity');
    Completer<V2TimValueCallback<List<V2TimTopicOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimTopicOperationResult>>(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pTopicIDList = Tools.string2PointerChar(json.encode(topicIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);

    NativeLibraryManager.bindings.DartDeleteTopicFromCommunity(pGroupID, pTopicIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pTopicIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> setTopicInfo({
    required V2TimTopicInfo topicInfo,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('setTopicInfo');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    V2TimTopicInfoSetParam param = V2TimTopicInfoSetParam(topicInfo: topicInfo);
    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartSetTopicInfo(pParam, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimTopicInfoResult>>> getTopicInfoList({
    required String groupID,
    required List<String> topicIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimTopicInfoResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getTopicInfoList');
    Completer<V2TimValueCallback<List<V2TimTopicInfoResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimTopicInfoResult>>(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pTopicIDList = Tools.string2PointerChar(json.encode(topicIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetTopicInfoList(pGroupID, pTopicIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pTopicIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<String>> createPermissionGroupInCommunity({
    required V2TimPermissionGroupInfo info,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<String>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('createPermissionGroupInCommunity');
    Completer<V2TimValueCallback<String>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    Pointer<Char> pInfo = Tools.string2PointerChar(json.encode(info.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartCreatePermissionGroupInCommunity(pInfo, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pInfo, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimPermissionGroupOperationResult>>> deletePermissionGroupFromCommunity({
    required String groupID,
    required List<String> permissionGroupIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimPermissionGroupOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('deletePermissionGroupFromCommunity');
    Completer<V2TimValueCallback<List<V2TimPermissionGroupOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pPermissionGroupIDList = Tools.string2PointerChar(json.encode(permissionGroupIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartDeletePermissionGroupFromCommunity(pGroupID, pPermissionGroupIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pPermissionGroupIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> modifyPermissionGroupInfoInCommunity({
    required V2TimPermissionGroupInfo info,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('modifyPermissionGroupInfoInCommunity');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    V2TimPermissionGroupInfoModifyParam modifyParam = V2TimPermissionGroupInfoModifyParam(info: info);
    Pointer<Char> pModifyParam = Tools.string2PointerChar(json.encode(modifyParam.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartModifyPermissionGroupInfoInCommunity(pModifyParam, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pModifyParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimPermissionGroupInfoResult>>> getJoinedPermissionGroupListInCommunity({
    required String groupID,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimPermissionGroupInfoResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getJoinedPermissionGroupListInCommunity');
    Completer<V2TimValueCallback<List<V2TimPermissionGroupInfoResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetJoinedPermissionGroupListInCommunity(pGroupID, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimPermissionGroupInfoResult>>>
      getPermissionGroupListInCommunity({
    required String groupID,
    required List<String> permissionGroupIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimPermissionGroupInfoResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getPermissionGroupListInCommunity');
    Completer<V2TimValueCallback<List<V2TimPermissionGroupInfoResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pPermissionGroupIDList = Tools.string2PointerChar(json.encode(permissionGroupIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetPermissionGroupListInCommunity(pGroupID, pPermissionGroupIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pPermissionGroupIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimPermissionGroupMemberOperationResult>>> addCommunityMembersToPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required List<String> memberList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimPermissionGroupMemberOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('addCommunityMembersToPermissionGroup');
    Completer<V2TimValueCallback<List<V2TimPermissionGroupMemberOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pPermissionGroupID = Tools.string2PointerChar(permissionGroupID);
    Pointer<Char> pMemberList = Tools.string2PointerChar(json.encode(memberList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartAddCommunityMembersToPermissionGroup(pGroupID, pPermissionGroupID, pMemberList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pPermissionGroupID, pMemberList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimPermissionGroupMemberOperationResult>>> removeCommunityMembersFromPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required List<String> memberList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimPermissionGroupMemberOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('removeCommunityMembersFromPermissionGroup');
    Completer<V2TimValueCallback<List<V2TimPermissionGroupMemberOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pPermissionGroupID = Tools.string2PointerChar(permissionGroupID);
    Pointer<Char> pMemberList = Tools.string2PointerChar(json.encode(memberList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartRemoveCommunityMembersFromPermissionGroup(pGroupID, pPermissionGroupID, pMemberList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pPermissionGroupID, pMemberList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimPermissionGroupMemberInfoResult>>
      getCommunityMemberListInPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required String nextCursor,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimPermissionGroupMemberInfoResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getCommunityMemberListInPermissionGroup');
    Completer<V2TimValueCallback<V2TimPermissionGroupMemberInfoResult>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pPermissionGroupID = Tools.string2PointerChar(permissionGroupID);
    Pointer<Char> pNextCursor = Tools.string2PointerChar(nextCursor);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetCommunityMemberListInPermissionGroup(pGroupID, pPermissionGroupID, pNextCursor, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pPermissionGroupID, pNextCursor, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimTopicOperationResult>>>
      addTopicPermissionToPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required Map<String, int> topicPermissionMap,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimTopicOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('addTopicPermissionToPermissionGroup');
    Completer<V2TimValueCallback<List<V2TimTopicOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pPermissionGroupID = Tools.string2PointerChar(permissionGroupID);
    List<Map<String, dynamic>> jsonTopicPermissionList = Tools.map2JsonList(topicPermissionMap, 'topic_permission_key', 'topic_permission_value');
    Pointer<Char> pJsonTopicPermissionList = Tools.string2PointerChar(json.encode(jsonTopicPermissionList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartAddTopicPermissionToPermissionGroup(pGroupID, pPermissionGroupID, pJsonTopicPermissionList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pPermissionGroupID, pJsonTopicPermissionList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimTopicOperationResult>>>
      deleteTopicPermissionFromPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required List<String> topicIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimTopicOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('deleteTopicPermissionFromPermissionGroup');
    Completer<V2TimValueCallback<List<V2TimTopicOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pPermissionGroupID = Tools.string2PointerChar(permissionGroupID);
    Pointer<Char> pTopicIDList = Tools.string2PointerChar(json.encode(topicIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartDeleteTopicPermissionFromPermissionGroup(pGroupID, pPermissionGroupID, pTopicIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pPermissionGroupID, pTopicIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimTopicOperationResult>>>
      modifyTopicPermissionInPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required Map<String, int> topicPermissionMap,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimTopicOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('modifyTopicPermissionInPermissionGroup');
    Completer<V2TimValueCallback<List<V2TimTopicOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pPermissionGroupID = Tools.string2PointerChar(permissionGroupID);
    List<Map<String, dynamic>> jsonTopicPermissionList = Tools.map2JsonList(topicPermissionMap, 'topic_permission_key', 'topic_permission_value');
    Pointer<Char> pJsonTopicPermissionList = Tools.string2PointerChar(json.encode(jsonTopicPermissionList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartModifyTopicPermissionInPermissionGroup(pGroupID, pPermissionGroupID, pJsonTopicPermissionList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pPermissionGroupID, pJsonTopicPermissionList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimTopicPermissionResult>>>
      getTopicPermissionInPermissionGroup({
    required String groupID,
    required String permissionGroupID,
    required List<String> topicIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimTopicPermissionResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getTopicPermissionInPermissionGroup');
    Completer<V2TimValueCallback<List<V2TimTopicPermissionResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pPermissionGroupID = Tools.string2PointerChar(permissionGroupID);
    Pointer<Char> pTopicIDList = Tools.string2PointerChar(json.encode(topicIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetTopicPermissionInPermissionGroup(pGroupID, pPermissionGroupID, pTopicIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pPermissionGroupID, pTopicIDList, pUserData]);
      return value;
    });
  }


  void _initInternalCommunityListener() {
    _communityListener = V2TimCommunityListener(
      onCreateTopic: (String groupID, String topicID) {
        for (var listener in v2TimCommunityListenerList) {
          listener.onCreateTopic(groupID, topicID);
        }
      },

      onDeleteTopic: (String groupID, List<String> topicIDList) {
        for (var listener in v2TimCommunityListenerList) {
          listener.onDeleteTopic(groupID, topicIDList);
        }
      },

      onChangeTopicInfo: (String groupID, V2TimTopicInfo topicInfo) {
        for (var listener in v2TimCommunityListenerList) {
          listener.onChangeTopicInfo(groupID, topicInfo);
        }
      },

      onReceiveTopicRESTCustomData: (String topicID, String customData) {
        for (var listener in v2TimCommunityListenerList) {
          listener.onReceiveTopicRESTCustomData(topicID, customData);
        }
      },

      onCreatePermissionGroup: (String groupID, V2TimPermissionGroupInfo permissionGroupInfo) {
        for (var listener in v2TimCommunityListenerList) {
          listener.onCreatePermissionGroup(groupID, permissionGroupInfo);
        }
      },

      onDeletePermissionGroup: (String groupID,  List<String> permissionGroupIDList) {
        for (var listener in v2TimCommunityListenerList) {
          listener.onDeletePermissionGroup(groupID, permissionGroupIDList);
        }
      },

      onChangePermissionGroupInfo: (String groupID, V2TimPermissionGroupInfo permissionGroupInfo) {
        for (var listener in v2TimCommunityListenerList) {
          listener.onChangePermissionGroupInfo(groupID, permissionGroupInfo);
        }
      },

      onAddMembersToPermissionGroup: (String groupID, String permissionGroupID, List<String> memberIDList) {
        for (var listener in v2TimCommunityListenerList) {
          listener.onAddMembersToPermissionGroup(groupID, permissionGroupID, memberIDList);
        }
      },

      onRemoveMembersFromPermissionGroup: (String groupID, String permissionGroupID, List<String> memberIDList) {
        for (var listener in v2TimCommunityListenerList) {
          listener.onRemoveMembersFromPermissionGroup(groupID, permissionGroupID, memberIDList);
        }
      },

      onAddTopicPermission: (String groupID, String permissionGroupID, Map<String, int> topicPermissionMap) {
        for (var listener in v2TimCommunityListenerList) {
          listener.onAddTopicPermission(groupID, permissionGroupID, topicPermissionMap);
        }
      },

      onDeleteTopicPermission: (String groupID, String permissionGroupID, List<String> topicIDList) {
        for (var listener in v2TimCommunityListenerList) {
          listener.onDeleteTopicPermission(groupID, permissionGroupID, topicIDList);
        }
      },

      onModifyTopicPermission: (String groupID, String permissionGroupID, Map<String, int> topicPermissionMap) {
        for (var listener in v2TimCommunityListenerList) {
          listener.onModifyTopicPermission(groupID, permissionGroupID, topicPermissionMap);
        }
      },
    );

    NativeLibraryManager.setCommunityListener(_communityListener);
  }
}