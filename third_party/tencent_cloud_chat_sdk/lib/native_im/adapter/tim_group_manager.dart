import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:tencent_cloud_chat_sdk/enum/V2TimGroupListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_add_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_get_members_info_list_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_handle_application_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info_modify_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_invite_user_to_group_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_kick_group_member_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info_modify_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_search_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_search_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_create_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_community_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_imsdk_bindings_generated.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_library_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';

class TIMGroupManager {
  static TIMGroupManager instance = TIMGroupManager();
  late V2TimGroupListener _groupListener;
  List<V2TimGroupListener> v2TimGroupListenerList = List.empty(growable: true);

  TIMGroupManager();

  void init() {
    _initInternalGroupListener();
  }

  void addGroupListener(V2TimGroupListener? listener) {
    if (listener == null || v2TimGroupListenerList.contains(listener)) {
      return;
    }

    v2TimGroupListenerList.add(listener);
  }

  void removeGroupListener({V2TimGroupListener? listener}) {
    if (listener == null) {
      v2TimGroupListenerList.clear();
    } else {
      v2TimGroupListenerList.remove(listener);
    }
  }

  Future<V2TimValueCallback<String>> createGroup({
    String? groupID,
    required String groupType,
    required String groupName,
    String? notification,
    String? introduction,
    String? faceUrl,
    bool? isAllMuted,
    bool? isSupportTopic = false,
    GroupAddOptTypeEnum? addOpt,
    List<V2TimGroupMember>? memberList,
    GroupAddOptTypeEnum? approveOpt,
    bool? isEnablePermissionGroup,
    int? defaultPermissions,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<String>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('createGroup');
    Completer<V2TimValueCallback<String>> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<Map<String, String>> v2timValueCallback = V2TimValueCallback<Map<String, String>>.fromJson(jsonResult);
      String groupID = v2timValueCallback.data?['create_group_result_groupid'] ?? '';
      completer.complete(V2TimValueCallback<String>(code: v2timValueCallback.code, desc: v2timValueCallback.desc, data: groupID));
    }
    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    V2TimGroupCreateParam createParams = V2TimGroupCreateParam(
      groupID: groupID,
      groupType: groupType,
      groupName: groupName,
      notification: notification,
      introduction: introduction,
      faceUrl: faceUrl,
      isAllMuted: isAllMuted,
      isSupportTopic: isSupportTopic,
      addOpt: addOpt,
      memberList: memberList,
      approveOpt: approveOpt,
      isEnablePermissionGroup: isEnablePermissionGroup,
      defaultPermissions: defaultPermissions
    );
    var temp = json.encode(createParams.toJson());
    // Pointer<Char> pCreateParams = Tools.string2PointerChar(json.encode(createParams.toJson()));
    Pointer<Char> pCreateParams = Tools.string2PointerChar(temp);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartCreateGroup(pCreateParams, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pCreateParams, pUserData]);
      return V2TimValueCallback<String>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pCreateParams, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimGroupInfo>>> getJoinedGroupList() async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimGroupInfo>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getJoinedGroupList');
    Completer<V2TimValueCallback<List<V2TimGroupInfo>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimGroupInfo>>(userData, completer);

    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetJoinedGroupList(pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointer(pUserData);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimGroupInfoResult>>> getGroupsInfo({
    required List<String> groupIDList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimGroupInfoResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getGroupsInfo');
    Completer<V2TimValueCallback<List<V2TimGroupInfoResult>>> completer = Completer();
    // 打断点测试
    // void handleApiCallback(Map jsonResult) {
    //   V2TimValueCallback<List<V2TimGroupInfoResult>> result = V2TimValueCallback<List<V2TimGroupInfoResult>>.fromJson(jsonResult);
    //   completer.complete(result);
    // }
    // NativeLibraryManager.timApiValueCallback2Future(userData, handleApiCallback);

    NativeLibraryManager.addTimValueCallback2Map<List<V2TimGroupInfoResult>>(userData, completer);

    String jsonGroupIDList = json.encode(groupIDList);
    Pointer<Char> pGroupIDList = Tools.string2PointerChar(jsonGroupIDList);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartGetGroupsInfo(pGroupIDList, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupIDList, pUserData]);
      return V2TimValueCallback<List<V2TimGroupInfoResult>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> setGroupInfo({
    required V2TimGroupInfo info,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('setGroupInfo');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pInfo = Tools.string2PointerChar(json.encode(V2TimGroupInfoModifyParam(groupInfo: info).toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartSetGroupInfo(pInfo, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pInfo, pUserData]);
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pInfo, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> initGroupAttributes({
    required String groupID,
    required Map<String, String> attributes,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('initGroupAttributes');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    List<Map<String, dynamic>> jsonAttributesList = Tools.map2JsonList(attributes, 'group_attribute_key', 'group_attribute_value');
    Pointer<Char> pAttributes = Tools.string2PointerChar(json.encode(jsonAttributesList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartInitGroupAttributes(pGroupID, pAttributes, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pAttributes, pUserData]);
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pAttributes, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> setGroupAttributes({
    required String groupID,
    required Map<String, String> attributes,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('setGroupAttributes');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    List<Map<String, dynamic>> jsonAttributesList = Tools.map2JsonList(attributes, 'group_attribute_key', 'group_attribute_value');
    Pointer<Char> pAttributes = Tools.string2PointerChar(json.encode(jsonAttributesList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartSetGroupAttributes(pGroupID, pAttributes, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pAttributes, pUserData]);
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pAttributes, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> deleteGroupAttributes({
    required String groupID,
    required List<String> keys,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('deleteGroupAttributes');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pKeys = Tools.string2PointerChar(json.encode(keys));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartDeleteGroupAttributes(pGroupID, pKeys, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pKeys, pUserData]);
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pKeys, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<Map<String, String>>> getGroupAttributes({
    required String groupID,
    List<String>? keys,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<Map<String, String>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getGroupAttributes');
    Completer<V2TimValueCallback<Map<String, String>>> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<List<dynamic>> result = V2TimValueCallback<List<dynamic>>.fromJson(jsonResult);
      List<Map<String, dynamic>>? data = result.data?.whereType<Map<String, dynamic>>().toList();
      var attributes = Tools.jsonList2Map<String>(data ?? [], 'group_attribute_key', 'group_attribute_value');
      completer.complete(V2TimValueCallback<Map<String, String>>(code: result.code, desc: result.desc, data: attributes));
    }
    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pKeys = Tools.string2PointerChar(json.encode(keys ?? []));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartGetGroupAttributes(pGroupID, pKeys, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pKeys, pUserData]);
      return V2TimValueCallback<Map<String, String>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pKeys, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<int>> getGroupOnlineMemberCount({
    required String groupID,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<int>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
      }

    String userData = Tools.generateUserData('getGroupOnlineMemberCount');
    Completer<V2TimValueCallback<int>> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<Map<String, int>> result = V2TimValueCallback<Map<String, int>>.fromJson(jsonResult);
      int count = result.data?['group_get_online_member_count_result'] ?? 0;
      completer.complete(V2TimValueCallback<int>(code: result.code, desc: result.desc, data: count));
    }

    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);
    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartGetOnlineMemberCount(pGroupID, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pUserData]);
      return V2TimValueCallback<int>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimGroupMemberInfoResult>> getGroupMemberList({
    required String groupID,
    required GroupMemberFilterTypeEnum filter,
    required String nextSeq,
    int count = 15,
    int offset = 0,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimGroupMemberInfoResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getGroupMemberList');
    Completer<V2TimValueCallback<V2TimGroupMemberInfoResult>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<V2TimGroupMemberInfoResult>(userData, completer);

    // nextSeq 是 uint64_t，可能超出 Dart int 有符号范围（> 2^63-1）
    int? seq = nextSeq.isNotEmpty ? int.tryParse(nextSeq) : 0;
    String? seqFallbackStr = (seq == null && nextSeq != '0') ? nextSeq : null;
    seq ??= 0;

    GroupGetMemberInfoListParam param = GroupGetMemberInfoListParam(groupID: groupID, filter: filter, nextSeq: seq);
    String jsonStr = json.encode(param.toJson());
    // 兜底：String nextSeq 超出 int64 范围时，用原始字符串替换
    if (seqFallbackStr != null) {
      jsonStr = jsonStr.replaceFirst('"group_get_members_info_list_param_next_seq":0', '"group_get_members_info_list_param_next_seq":$seqFallbackStr');
    }

    Pointer<Char> pJsonParam = Tools.string2PointerChar(jsonStr);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartGetGroupMemberList(pJsonParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return V2TimValueCallback<V2TimGroupMemberInfoResult>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimGroupMemberFullInfo>>>
      getGroupMembersInfo({
    required String groupID,
    required List<String> memberList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimGroupMemberFullInfo>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getGroupMembersInfo');
    Completer<V2TimValueCallback<List<V2TimGroupMemberFullInfo>>> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<V2TimGroupMemberInfoResult> result = V2TimValueCallback<V2TimGroupMemberInfoResult>.fromJson(jsonResult);
      var resultList = result.data?.memberInfoList ?? [];
      List<V2TimGroupMemberFullInfo> memberInfoList = resultList.where((element) => element != null).cast<V2TimGroupMemberFullInfo>().toList();
      completer.complete(V2TimValueCallback<List<V2TimGroupMemberFullInfo>>(code: result.code, desc: result.desc, data: memberInfoList));
    }
    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    GroupGetMemberInfoListParam param = GroupGetMemberInfoListParam(groupID: groupID, filter: GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ALL, memberList: memberList);
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartGetGroupMemberList(pJsonParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return V2TimValueCallback<List<V2TimGroupMemberFullInfo>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> setGroupMemberInfo({
    required String groupID,
    required String userID,
    String? nameCard,
    Map<String, String>? customInfo,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('setGroupMemberInfo');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    V2TimGroupMemberInfoModifyParam param = V2TimGroupMemberInfoModifyParam(groupID: groupID, userID: userID, nameCard: nameCard, customInfo: customInfo);
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartModifyGroupMemberInfo(pJsonParam, pUserData);
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

  Future<V2TimCallback> muteGroupMember({
    required String groupID,
    required String userID,
    required int seconds,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('muteGroupMember');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    V2TimGroupMemberInfoModifyParam param = V2TimGroupMemberInfoModifyParam(groupID: groupID, userID: userID, seconds: seconds);
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartModifyGroupMemberInfo(pJsonParam, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> muteAllGroupMembers({
    required String groupID,
    required bool isMute,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    V2TimGroupInfo info = V2TimGroupInfo(groupID: groupID, groupType: "", isAllMuted: isMute);
    return setGroupInfo(info: info);
  }

  Future<V2TimValueCallback<List<V2TimGroupMemberOperationResult>>> inviteUserToGroup({
    required String groupID,
    required List<String> userList,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimGroupMemberOperationResult>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('inviteUserToGroup');
    Completer<V2TimValueCallback<List<V2TimGroupMemberOperationResult>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    V2TimGroupInviteUserToGroupParam param = V2TimGroupInviteUserToGroupParam(groupID: groupID, userList: userList);
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartInviteUserToGroup(pJsonParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return V2TimValueCallback<List<V2TimGroupMemberOperationResult>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> kickGroupMember({
    required String groupID,
    required List<String> memberList,
    int? duration,
    String? reason,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('kickGroupMember');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    V2TimGroupKickGroupMemberParam param = V2TimGroupKickGroupMemberParam(groupID: groupID, userList: memberList, duration: duration, reason: reason);
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartKickGroupMember(pJsonParam, pUserData);
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

  Future<V2TimCallback> setGroupMemberRole({
    required String groupID,
    required String userID,
    required GroupMemberRoleTypeEnum role,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('setGroupMemberRole');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    V2TimGroupMemberInfoModifyParam param = V2TimGroupMemberInfoModifyParam(groupID: groupID, userID: userID, role: role);
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartModifyGroupMemberInfo(pJsonParam, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> transferGroupOwner({
    required String groupID,
    required String userID,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('transferGroupOwner');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    V2TimGroupInfo info = V2TimGroupInfo(groupID: groupID, groupType: "", owner: userID);
    Pointer<Char> pInfo = Tools.string2PointerChar(json.encode(V2TimGroupInfoModifyParam(groupInfo: info).toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartSetGroupInfo(pInfo, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pInfo, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> markGroupMemberList({
    required String groupID,
    required List<String> memberIDList,
    required int markType,
    required bool enableMark,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('markGroupMemberList');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pMemberIDList = Tools.string2PointerChar(json.encode(memberIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartMarkGroupMemberList(pGroupID, pMemberIDList, markType, enableMark, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pMemberIDList, pUserData]);
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pMemberIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimGroupApplicationResult>> getGroupApplicationList() async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimGroupApplicationResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getGroupApplicationList');
    Completer<V2TimValueCallback<V2TimGroupApplicationResult>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map(userData, completer);

    Pointer<Char> pParam = Tools.string2PointerChar("not used");
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetGroupPendencyList(pParam, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> acceptGroupApplication({
    required String groupID,
    String? reason,
    required String fromUser,
    required String toUser,
    int? addTime,
    GroupApplicationTypeEnum? type,
    V2TimGroupApplication? application,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('acceptGroupApplication');

    V2TimGroupApplication adjustApplication = V2TimGroupApplication(groupID: groupID, fromUser: fromUser, toUser: toUser, addTime: addTime, type: type?.index ?? 0, handleStatus: 0, handleResult: 0);
    if (application != null && application.authentication.isNotEmpty) {
      adjustApplication = application;
      adjustApplication.groupID = groupID;
      adjustApplication.fromUser = fromUser;
      adjustApplication.toUser = toUser;
      adjustApplication.addTime = addTime ?? application.addTime;
      adjustApplication.type = type?.index ?? application.type;

      Completer<V2TimCallback> completer = Completer();
      NativeLibraryManager.addTimCallback2Map(userData, completer);

      V2TimGroupHandleApplicationParam param = V2TimGroupHandleApplicationParam(isAccept: true, reason: reason ?? '', application: adjustApplication);
      Pointer<Char> pParam = Tools.string2PointerChar(json.encode(param.toJson()));
      Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
      int result = NativeLibraryManager.bindings.DartHandleGroupPendency(pParam, pUserData);
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

    // 兼容旧版本的处理
    return handleGroupApplication(groupID: groupID, fromUser: fromUser, toUser: toUser, addTime: addTime ?? 0, type: type, isAccept: true, userData: userData);
  }

  Future<V2TimCallback> refuseGroupApplication({
    required String groupID,
    String? reason,
    required String fromUser,
    required String toUser,
    required int addTime,
    required GroupApplicationTypeEnum type,
    V2TimGroupApplication? application,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('refuseGroupApplication');

    V2TimGroupApplication adjustApplication = V2TimGroupApplication(groupID: groupID, fromUser: fromUser, toUser: toUser, addTime: addTime, type: type.index, handleStatus: 0, handleResult: 0);
    if (application != null && application.authentication.isNotEmpty) {
      adjustApplication = application;
      adjustApplication.groupID = groupID;
      adjustApplication.fromUser = fromUser;
      adjustApplication.toUser = toUser;
      adjustApplication.addTime = addTime;
      adjustApplication.type = type.index;

      Completer<V2TimCallback> completer = Completer();
      NativeLibraryManager.addTimCallback2Map(userData, completer);

      V2TimGroupHandleApplicationParam param = V2TimGroupHandleApplicationParam(isAccept: false, reason: reason ?? '', application: adjustApplication);
      Pointer<Char> pParam = Tools.string2PointerChar(json.encode(param.toJson()));
      Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
      int result = NativeLibraryManager.bindings.DartHandleGroupPendency(pParam, pUserData);
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

    // 兼容旧版本的处理
    return handleGroupApplication(groupID: groupID, fromUser: fromUser, toUser: toUser, addTime: addTime, type: type, isAccept: false, userData: userData);
  }

  Future<V2TimCallback> handleGroupApplication({
    required String groupID,
    String? reason,
    required String fromUser,
    required String toUser,
    required int addTime,
    required GroupApplicationTypeEnum? type,
    required bool isAccept,
    required String userData,
  }) async {
    var result = await getGroupApplicationList();
    if (result.code != TIMErrCode.ERR_SUCC.value) {
      return V2TimCallback(code: result.code, desc: "get group application list failed");
    }

    var targetApplication = result.data?.groupApplicationList?.firstWhere((element) => element?.groupID == groupID && element?.fromUser == fromUser && element?.toUser == toUser && element?.addTime == addTime && element?.type == type?.index);
    if (targetApplication == null) {
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "find group application failed");
    }

    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    V2TimGroupHandleApplicationParam param = V2TimGroupHandleApplicationParam(isAccept: isAccept, reason: reason ?? '', application: targetApplication);
    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int resultCode = NativeLibraryManager.bindings.DartHandleGroupPendency(pParam, pUserData);
    if (resultCode != TIMResult.TIM_SUCC.value) {
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

  Future<V2TimCallback> setGroupApplicationRead() async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('setGroupApplicationRead');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartMarkGroupPendencyRead(0, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointer(pUserData);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimGroupInfo>>> searchGroups({
    required V2TimGroupSearchParam searchParam,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<List<V2TimGroupInfo>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('searchGroups');
    Completer<V2TimValueCallback<List<V2TimGroupInfo>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimGroupInfo>>(userData, completer);

    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(searchParam.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartSearchGroups(pParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return V2TimValueCallback<List<V2TimGroupInfo>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimGroupSearchResult>> searchCloudGroups({
    required V2TimGroupSearchParam searchParam,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimGroupSearchResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('searchCloudGroups');
    Completer<V2TimValueCallback<V2TimGroupSearchResult>> completer = Completer();

    // 打断点测试
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<V2TimGroupSearchResult> result = V2TimValueCallback<V2TimGroupSearchResult>.fromJson(jsonResult);
      completer.complete(result);
    }
    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);
    // NativeLibraryManager.timValueCallback2Future<V2TimGroupSearchResult>(userData, completer);

    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(searchParam.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartSearchCloudGroups(pParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return V2TimValueCallback<V2TimGroupSearchResult>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2GroupMemberInfoSearchResult>> searchGroupMembers({
    required V2TimGroupMemberSearchParam param,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2GroupMemberInfoSearchResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('searchGroupMembers');
    Completer<V2TimValueCallback<V2GroupMemberInfoSearchResult>> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<List<dynamic>> result = V2TimValueCallback<List<dynamic>>.fromJson(jsonResult);
      List<Map<String, dynamic>>? data = result.data?.whereType<Map<String, dynamic>>().toList();
      Map<String, dynamic> mapResult = Tools.jsonList2Map(data ?? [], 'group_search_member_result_groupid', 'group_search_member_result_member_info_list');
      V2GroupMemberInfoSearchResult searchResult = V2GroupMemberInfoSearchResult.fromJson(mapResult);
      completer.complete(V2TimValueCallback<V2GroupMemberInfoSearchResult>(code: result.code, desc: result.desc, data: searchResult));
    }
    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartSearchGroupMembers(pParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return V2TimValueCallback<V2GroupMemberInfoSearchResult>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2GroupMemberInfoSearchResult>> searchCloudGroupMembers({
    required V2TimGroupMemberSearchParam param,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2GroupMemberInfoSearchResult>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('searchCloudGroupMembers');
    Completer<V2TimValueCallback<V2GroupMemberInfoSearchResult>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<V2GroupMemberInfoSearchResult>(userData, completer);

    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartSearchCloudGroupMembers(pParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return V2TimValueCallback<V2GroupMemberInfoSearchResult>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimGroupInfo>> searchGroupByID({
    required String groupID,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<V2TimGroupInfo>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('searchGroupByID');
    Completer<V2TimValueCallback<V2TimGroupInfo>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<V2TimGroupInfo>(userData, completer);

    V2TimGroupSearchParam param = V2TimGroupSearchParam(keywordList: [groupID], isSearchGroupID: true, isSearchGroupName: false);
    Pointer<Char> pParam = Tools.string2PointerChar(jsonEncode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartSearchGroups(pParam, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimGroupInfo>>> getJoinedCommunityList() async {
    return TIMCommunityManager.instance.getJoinedCommunityList();
  }

  Future<V2TimValueCallback<String>> createTopicInCommunity({
    required String groupID,
    required V2TimTopicInfo topicInfo,
  }) async {
    return TIMCommunityManager.instance.createTopicInCommunity(
      groupID: groupID,
      topicInfo: topicInfo,
    );
  }

  Future<V2TimValueCallback<List<V2TimTopicOperationResult>>> deleteTopicFromCommunity({
    required String groupID,
    required List<String> topicIDList,
  }) async {
    return TIMCommunityManager.instance.deleteTopicFromCommunity(groupID: groupID, topicIDList: topicIDList);
  }

  Future<V2TimCallback> setTopicInfo({
    required V2TimTopicInfo topicInfo,
  }) async {
    return TIMCommunityManager.instance.setTopicInfo(topicInfo: topicInfo);
  }

  Future<V2TimValueCallback<List<V2TimTopicInfoResult>>> getTopicInfoList({
    required String groupID,
    required List<String> topicIDList,
  }) async {
    return TIMCommunityManager.instance
        .getTopicInfoList(groupID: groupID, topicIDList: topicIDList);
  }

  Future<V2TimValueCallback<Map<String, int>>> setGroupCounters({
    required String groupID,
    required Map<String, int> counters,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<Map<String, int>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('setGroupCounters');
    Completer<V2TimValueCallback<Map<String, int>>> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<List<Map<String, dynamic>>> result = V2TimValueCallback<List<Map<String, dynamic>>>.fromJson(jsonResult);
      List<Map<String, dynamic>> jsonResultList = result.data ?? [];
      Map<String, int> counter = Tools.jsonList2Map<int>(jsonResultList, 'group_counter_key', 'group_counter_value');
      completer.complete(V2TimValueCallback<Map<String, int>>(code: result.code, desc: result.desc, data: counter));
    }
    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    var jsonList = Tools.map2JsonList(counters, 'group_counter_key', 'group_counter_value');
    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pCounters = Tools.string2PointerChar(json.encode(jsonList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartSetGroupCounters(pGroupID, pCounters, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      return V2TimValueCallback<Map<String, int>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future;
  }

  Future<V2TimValueCallback<Map<String, int>>> getGroupCounters({
    required String groupID,
    required List<String> keys,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<Map<String, int>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getGroupCounters');
    Completer<V2TimValueCallback<Map<String, int>>> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<List<Map<String, dynamic>>> result = V2TimValueCallback<List<Map<String, dynamic>>>.fromJson(jsonResult);
      List<Map<String, dynamic>> jsonResultList = result.data ?? [];
      Map<String, int> counter = Tools.jsonList2Map<int>(jsonResultList, 'group_counter_key', 'group_counter_value');
      completer.complete(V2TimValueCallback<Map<String, int>>(code: result.code, desc: result.desc, data: counter));
    }
    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pKeys = Tools.string2PointerChar(json.encode(keys));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartGetGroupCounters(pGroupID, pKeys, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      return V2TimValueCallback<Map<String, int>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future;
  }

  Future<V2TimValueCallback<Map<String, int>>> increaseGroupCounter({
    required String groupID,
    required String key,
    required int value,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<Map<String, int>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('increaseGroupCounter');
    Completer<V2TimValueCallback<Map<String, int>>> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<List<Map<String, dynamic>>> result = V2TimValueCallback<List<Map<String, dynamic>>>.fromJson(jsonResult);
      List<Map<String, dynamic>> jsonResultList = result.data ?? [];
      Map<String, int> counter = Tools.jsonList2Map<int>(jsonResultList, 'group_counter_key', 'group_counter_value');
      completer.complete(V2TimValueCallback<Map<String, int>>(code: result.code, desc: result.desc, data: counter));
    }
    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pKey = Tools.string2PointerChar(key);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartIncreaseGroupCounter(pGroupID, pKey, value, pUserData);

    return completer.future;
  }

    Future<V2TimValueCallback<Map<String, int>>> decreaseGroupCounter({
    required String groupID,
    required String key,
    required int value,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimValueCallback<Map<String, int>>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('decreaseGroupCounter');
    Completer<V2TimValueCallback<Map<String, int>>> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<List<Map<String, dynamic>>> result = V2TimValueCallback<List<Map<String, dynamic>>>.fromJson(jsonResult);
      List<Map<String, dynamic>> jsonResultList = result.data ?? [];
      Map<String, int> counter = Tools.jsonList2Map<int>(jsonResultList, 'group_counter_key', 'group_counter_value');
      completer.complete(V2TimValueCallback<Map<String, int>>(code: result.code, desc: result.desc, data: counter));
    }
    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pKey = Tools.string2PointerChar(key);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartDecreaseGroupCounter(pGroupID, pKey, value, pUserData);

    return completer.future;
  }

  void _initInternalGroupListener() {
    _groupListener = V2TimGroupListener(
      onApplicationProcessed: (String groupID, V2TimGroupMemberInfo opUser, bool isAgreeJoin, String opReason) {
        for (var listener in v2TimGroupListenerList) {
          listener.onApplicationProcessed(groupID, opUser, isAgreeJoin, opReason);
        }
      },

      onGrantAdministrator: (String groupID, V2TimGroupMemberInfo opUser, List<V2TimGroupMemberInfo> memberList) {
        for (var listener in v2TimGroupListenerList) {
          listener.onGrantAdministrator(groupID, opUser, memberList);
        }
      }, 

      onGroupAttributeChanged:  (String groupID, Map<String, String> groupAttributeMap) {
        for (var listener in v2TimGroupListenerList) {
          listener.onGroupAttributeChanged(groupID, groupAttributeMap);
        }
      },

      onGroupCreated: (String groupID) {
        for (var listener in v2TimGroupListenerList) {
          listener.onGroupCreated(groupID);
        }
      },

      onGroupDismissed: (String groupID, V2TimGroupMemberInfo opUser) {
        for (var listener in v2TimGroupListenerList) {
          listener.onGroupDismissed(groupID, opUser);
        }
      },

      onGroupInfoChanged: (String groupID, List<V2TimGroupChangeInfo> changeInfos) {
        for (var listener in v2TimGroupListenerList) {
          listener.onGroupInfoChanged(groupID, changeInfos);
        }
      },

      onGroupRecycled: (String groupID, V2TimGroupMemberInfo opUser) {
        for (var listener in v2TimGroupListenerList) {
          listener.onGroupRecycled(groupID, opUser);
        }
      },

      onMemberEnter: (String groupID, List<V2TimGroupMemberInfo> memberList) {
        for (var listener in v2TimGroupListenerList) {
          listener.onMemberEnter(groupID, memberList);
        }
      },

      onMemberInfoChanged: (String groupID, List<V2TimGroupMemberChangeInfo> v2TIMGroupMemberChangeInfoList) {
        for (var listener in v2TimGroupListenerList) {
          listener.onMemberInfoChanged(groupID, v2TIMGroupMemberChangeInfoList);
        }
      },

      onMemberInvited: (String groupID, V2TimGroupMemberInfo opUser, List<V2TimGroupMemberInfo> memberList) {
        for (var listener in v2TimGroupListenerList) {
          listener.onMemberInvited(groupID, opUser, memberList);
        }
      },

      onMemberKicked: (String groupID, V2TimGroupMemberInfo opUser, List<V2TimGroupMemberInfo> memberList) {
        for (var listener in v2TimGroupListenerList) {
          listener.onMemberKicked(groupID, opUser, memberList);
        }
      },

      onMemberLeave: (String groupID, V2TimGroupMemberInfo member) {
        for (var listener in v2TimGroupListenerList) {
          listener.onMemberLeave(groupID, member);
        }
      },

      onQuitFromGroup: (String groupID) {
        for (var listener in v2TimGroupListenerList) {
          listener.onQuitFromGroup(groupID);
        }
      },

      onReceiveJoinApplication: (String groupID, V2TimGroupMemberInfo member, String opReason) {
        for (var listener in v2TimGroupListenerList) {
          listener.onReceiveJoinApplication(groupID, member, opReason);
        }
      },

      onReceiveRESTCustomData: (String groupID, String customData) {
        for (var listener in v2TimGroupListenerList) {
          listener.onReceiveRESTCustomData(groupID, customData);
        }
      },

      onRevokeAdministrator: (String groupID, V2TimGroupMemberInfo opUser, List<V2TimGroupMemberInfo> memberList) {
        for (var listener in v2TimGroupListenerList) {
          listener.onRevokeAdministrator(groupID, opUser, memberList);
        }
      },

      onTopicCreated: (String groupID, String topic) {
        for (var listener in v2TimGroupListenerList) {
          listener.onTopicCreated(groupID, topic);
        }
      },

      onTopicDeleted: (String groupID, List<String> topicIDList) {
        for (var listener in v2TimGroupListenerList) {
          listener.onTopicDeleted(groupID, topicIDList);
        }
      },

      onTopicInfoChanged: (String groupID, V2TimTopicInfo topicInfo) {
        for (var listener in v2TimGroupListenerList) {
          listener.onTopicInfoChanged(groupID, topicInfo);
        }
      },

      onGroupCounterChanged: (String groupID, String key, int newValue) {
        for (var listener in v2TimGroupListenerList) {
          listener.onGroupCounterChanged(groupID, key, newValue);
        }
      },

      onAllGroupMembersMuted: (String groupID, bool isMuted) {
        for (var listener in v2TimGroupListenerList) {
          listener.onAllGroupMembersMuted(groupID, isMuted);
        }
      },

      onMemberMarkChanged: (String groupID, List<String> memberIDList, int markType, bool enableMark) {
        for (var listener in v2TimGroupListenerList) {
          listener.onMemberMarkChanged(groupID, memberIDList, markType, enableMark);
        }
      }
    );

    NativeLibraryManager.setGroupListener(_groupListener);
  }

}