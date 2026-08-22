import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimGroupListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSimpleMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/common_utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_search_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_community_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_conversation_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_friendship_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_group_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_message_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_signaling_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_imsdk_bindings_generated.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_library_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';
import 'package:tencent_cloud_chat_sdk/utils/const.dart';

class TIMManager {
  static TIMManager instance = TIMManager();

  late V2TimSDKListener _sdkListener;
  late V2TimAdvancedMsgListener _advancedMsgListener;
  List<V2TimSDKListener> v2TimSDKListenerList = List.empty(growable: true);
  List<V2TimSimpleMsgListener> v2TimSimpleMsgListenerList = List.empty(growable: true);
  bool _isInitSDK = false;
  int? _sdkAppID;

  TIMManager();

  bool isInitSDK() {
    return _isInitSDK;
  }

  int? getSDKAppID() {
    return _sdkAppID;
  }

  void addSDKListener(V2TimSDKListener? listener) {
    if (listener == null || v2TimSDKListenerList.contains(listener)) {
      return;
    }

    v2TimSDKListenerList.add(listener);
  }

  void removeSDKListener({V2TimSDKListener? listener}) {
    if (listener != null) {
      v2TimSDKListenerList.remove(listener);
    }
  }

  String _getDefaultInitPath() {
    Directory internalDir = CommonUtils.appFileDir;
    if (Platform.isAndroid) {
      return '${internalDir.path}/';
    } else if (Platform.isIOS) {
      return '${internalDir.parent.path}/Documents/com_tencent_imsdk_data/';
    } else if (Platform.isMacOS) {
      return '${internalDir.parent.path}/Documents/com_tencent_imsdk_data/';
    } else if (Platform.isWindows) {
      return '${internalDir.path}/TencentCloudChat/Config';
    } else if (Platform.operatingSystem == 'ohos') {
      return '${internalDir.path}/';
    }

    return '';
  }

  String _getDefaultLogPath() {
    Directory internalDir = CommonUtils.appFileDir;
    if (Platform.isAndroid) {
      Directory? externalStorageDir = CommonUtils.externalCacheDir;
      return '${externalStorageDir?.path ?? internalDir.path}/log/tencent/imsdk/';
    } else if (Platform.isIOS) {
      return '${internalDir.parent.path}/Library/Caches/com_tencent_imsdk_log/';
    } else if (Platform.isMacOS) {
      return '${internalDir.parent.path}/Library/Caches/com_tencent_imsdk_log/';
    } else if (Platform.isWindows) {
      return '${internalDir.path}/TencentCloudChat/Log';
    } else if (Platform.operatingSystem == 'ohos') {
      return '${internalDir.path}/log/tencent/imsdk/';
    }

    return '';
  }

  Future<bool> initSDK({
    required int sdkAppID,
    LogLevelEnum logLevel = LogLevelEnum.V2TIM_LOG_DEBUG,
    V2TimSDKListener? listener,
    String? initPath,
    String? logPath,
    required int uiPlatform,
    bool? showImLog,
    Map<String, dynamic>? networkInfo,
    Map<String, dynamic>? deviceInfo,
    int? mainThreadLooperPointer,
  }) async {
    if (_isInitSDK) {
      print('sdk has already been initialized');
      return true;
    }

    await CommonUtils.init(getSDKAppID: getSDKAppID, getLoginUser: getLoginUser);
    _sdkAppID = sdkAppID;
    _initInternalSDKListener(listener);
    _initSimpleMessageListener();
    TIMMessageManager.instance.init();
    TIMConversationManager.instance.init();
    TIMGroupManager.instance.init();
    TIMCommunityManager.instance.init();
    TIMFriendshipManager.instance.init();
    TIMSignalingManager.instance.init();

    NativeLibraryManager.registerPort();

    addSDKListener(listener);

    setUIPlatform(uiPlatform: uiPlatform);

    setConfig(
      logLevel: logLevel,
      showImLog: showImLog,
    );

    if (networkInfo != null && networkInfo.isNotEmpty) {
      setNetworkInfo(networkInfo: networkInfo);
    }

    // APIType::FlutterFFI: 0x1 << 6;
    Map<String, dynamic> configMap = {};
    configMap["sdk_config_config_file_path"] = initPath ?? _getDefaultInitPath();
    configMap["sdk_config_log_file_path"] = logPath ?? _getDefaultLogPath();
    configMap["sdk_config_api_type"] = 64;

    if (deviceInfo != null && deviceInfo.isNotEmpty) {
      print("deviceInfo: $deviceInfo");
      configMap["sdk_config_device_type"] = deviceInfo["deviceType"];
      configMap["sdk_config_brand_type"] = deviceInfo["deviceBrand"];
      configMap["sdk_config_system_version"] = deviceInfo["systemVersion"];
    }

    if (mainThreadLooperPointer != null && mainThreadLooperPointer != 0) {
      configMap["sdk_config_main_looper_pointer"] = mainThreadLooperPointer;
    }

    Pointer<Char> jsonSdkConfig = Tools.string2PointerChar(json.encode(configMap));
    int initResult = NativeLibraryManager.bindings.DartInitSDK(sdkAppID, jsonSdkConfig);
    Tools.freePointer(jsonSdkConfig);

    _isInitSDK = initResult == TIMResult.TIM_SUCC.value;

    if (_isInitSDK) {
      Future.delayed(const Duration(milliseconds: 500), () {
        writeSDKLog(trace: "version: ${TencentIMSDKCONST.version}", logLevel: LogLevel.V2TIM_LOG_INFO);
      });
    }

    return _isInitSDK;
  }

  void setConfig({
    LogLevelEnum logLevel = LogLevelEnum.V2TIM_LOG_DEBUG,
    bool? showImLog,
  }) {
    Pointer<Char> jsonConfig = Tools.string2PointerChar(json.encode({
      "set_config_log_level": logLevel.index,
      "set_config_callback_log_level": logLevel.index,
      "set_config_is_log_output_console": showImLog ?? true,
    }));

    NativeLibraryManager.bindings.DartSetConfig(jsonConfig, Pointer<Void>.fromAddress(0));
    
    Tools.freePointer(jsonConfig);
  }

  void setUIPlatform({
    required int uiPlatform,
  }) {
    String userData = Tools.generateUserData('setUIPlatform');

    Map<String, dynamic> jsonParam = {};
    jsonParam['request_internal_operation'] = 'internal_operation_set_ui_platform';
    jsonParam['request_set_ui_platform_param'] = uiPlatform;
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(jsonParam));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);

    NativeLibraryManager.bindings.DartCallExperimentalAPI(pJsonParam, pUserData);
    
    Tools.freePointers([pJsonParam, pUserData]);
  }

  void setNetworkInfo({
    required Map<String, dynamic> networkInfo,
  }) {
    String userData = Tools.generateUserData('setNetworkInfo');

    Map<String, dynamic> jsonParam = {};
    jsonParam['request_internal_operation'] = 'internal_operation_set_network_info';
    jsonParam["request_set_network_info_network_type_param"] = networkInfo["networkType"]! as int;
    jsonParam["request_set_network_info_ip_type_param"] = networkInfo["ipType"]! as int;
    jsonParam["request_set_network_info_network_id_param"] = networkInfo["networkId"]! as String;
    jsonParam["request_set_network_info_wifi_network_handle_param"] = networkInfo["wifiNetworkHandle"]! as int;
    jsonParam["request_set_network_info_xg_network_handle_param"] = networkInfo["xgNetworkHandle"]! as int;
    jsonParam["request_set_network_info_network_connected_param"] = networkInfo["networkConnected"]! as bool;
    jsonParam["request_set_network_info_initialize_cost_time_param"] = networkInfo["initializeCostTime"]! as int;
    Pointer<Char> pJsonParam = Tools.string2PointerChar(json.encode(jsonParam));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);

    NativeLibraryManager.bindings.DartCallExperimentalAPI(pJsonParam, pUserData);

    Tools.freePointers([pJsonParam, pUserData]);
  }

  bool unInitSDK() {
    _sdkAppID = null;
    removeSDKListener();
    removeSimpleMsgListener();
    TIMMessageManager.instance.removeAdvancedMsgListener();
    TIMConversationManager.instance.removeConversationListener();
    TIMGroupManager.instance.removeGroupListener();
    TIMFriendshipManager.instance.removeFriendListener();
    TIMSignalingManager.instance.removeSignalingListener();
    TIMCommunityManager.instance.removeCommunityListener();

    NativeLibraryManager.unregisterPort();

    int result = NativeLibraryManager.bindings.DartUnitSDK();
    _isInitSDK = false;
    return result == TIMResult.TIM_SUCC.value;
  }

  String getSDKVersion() {
    Pointer<Char> sdkVersion = NativeLibraryManager.bindings.DartGetSDKVersion();
    return Tools.pointerChar2String(sdkVersion);
  }

  int getServerTime() {
    return NativeLibraryManager.bindings.DartGetServerTime();
  }

  Future<V2TimCallback> login({
    required String userID,
    required String userSig,
  }) async {
    if (!_isInitSDK) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('login');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pUserID = Tools.string2PointerChar(userID);
    Pointer<Char> pUserSig = Tools.string2PointerChar(userSig);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartLogin(pUserID, pUserSig, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserID, pUserSig, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> logout() async {
    if (!_isInitSDK) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('logout');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartLogout(pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointer(pUserData);
      return value;
    });
  }

  String getLoginUser() {
    Pointer<Char> userID = NativeLibraryManager.bindings.DartGetLoginUserID();
    String userIDDart = Tools.pointerChar2String(userID);
    return userIDDart;
  }

  int getLoginStatus() {
    return NativeLibraryManager.bindings.DartGetLoginStatus();
  }

  Future<V2TimCallback> joinGroup({
    required String groupID,
    required String message,
  }) async {
    if (!_isInitSDK) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('joinGroup');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Char> pMessage = Tools.string2PointerChar(message);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartJoinGroup(pGroupID, pMessage, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pMessage, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> quitGroup({
    required String groupID,
  }) async {
    if (!_isInitSDK) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    if (groupID.isEmpty) {
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "groupID is empty");
    }

    String userData = Tools.generateUserData('quitGroup');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartQuitGroup(pGroupID, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> dismissGroup({
    required String groupID,
  }) async {
    if (!_isInitSDK) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('dismissGroup');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pGroupID = Tools.string2PointerChar(groupID);
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartDeleteGroup(pGroupID, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pGroupID, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimUserFullInfo>>> getUsersInfo({
    required List<String> userIDList,
  }) async {
    if (!_isInitSDK) {
      return V2TimValueCallback<List<V2TimUserFullInfo>>(
          code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('getUsersInfo');
    Completer<V2TimValueCallback<List<V2TimUserFullInfo>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimUserFullInfo>>(userData, completer);

    Map<String, dynamic> jsonParm = {'friendship_getprofilelist_param_identifier_array': userIDList};
    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(jsonParm));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartGetUsersInfo(pUserIDList, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return V2TimValueCallback<List<V2TimUserFullInfo>>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> setSelfInfo({
    required V2TimUserFullInfo userFullInfo,
  }) async {
    if (!_isInitSDK) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('setSelfInfo');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pSetParam = Tools.string2PointerChar(json.encode(userFullInfo.toSetUserInfoParam()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartSetSelfInfo(pSetParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pSetParam, pUserData]);
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pSetParam, pUserData]);
      return value;
    });
  }

  static const Set<String> _syncExperimentalAPIs = {
    'internal_operation_sso_data',
    'internal_operation_set_env',
    'internal_operation_disable_crash_report',
    'internal_operation_set_ipv6_prior',
    'internal_operation_set_max_retry_count',
    'internal_operation_set_packet_request_timeout',
    'internal_operation_set_custom_server_info',
    'internal_operation_enable_quic_channel',
    'internal_operation_set_sm4_gcm_callback',
    'internal_operation_init_local_storage',
    'internal_operation_set_cos_save_region_for_conversation',
    'internal_operation_set_ui_platform',
    'internal_operation_set_database_encrypt_info',
    'internal_operation_set_log_setting',
    'internal_operation_write_log',
    'internal_operation_update_proxy_info',
    'internal_operation_set_application_id',
    'internal_operation_set_ignore_repeat_login',
    'internal_operation_set_custom_login_info',
    'internal_operation_disable_http_request',
    'internal_operation_set_network_info',
    'internal_operation_set_custom_upload_callback',
  };

  Future<V2TimValueCallback<Object>> callExperimentalAPI({
    required String api,
    Object? param,
  }) async {
    Map<String, dynamic> cJsonParam = {};
    if (param is Map<String, dynamic>) {
      cJsonParam = Map<String, dynamic>.from(param);
    }
    cJsonParam['request_internal_operation'] = api;

    // C 层直接通过返回值传递数据，不走回调
    if (api == 'internal_operation_get_login_account_type') {
      Pointer<Char> pCJsonParam = Tools.string2PointerChar(json.encode(cJsonParam));
      Pointer<Void> pUserData = Tools.string2PointerVoid('');
      int accountType = NativeLibraryManager.bindings.DartCallExperimentalAPI(pCJsonParam, pUserData);
      Tools.freePointers([pCJsonParam, pUserData]);
      return V2TimValueCallback<Object>(code: 0, desc: '', data: accountType);
    }

    // C 层同步操作，不会触发回调，直接返回结果
    if (_syncExperimentalAPIs.contains(api)) {
      Pointer<Char> pCJsonParam = Tools.string2PointerChar(json.encode(cJsonParam));
      Pointer<Void> pUserData = Tools.string2PointerVoid('');
      int result = NativeLibraryManager.bindings.DartCallExperimentalAPI(pCJsonParam, pUserData);
      Tools.freePointers([pCJsonParam, pUserData]);
      if (result != TIMResult.TIM_SUCC.value) {
        return V2TimValueCallback<Object>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
      }
      return V2TimValueCallback<Object>(code: 0, desc: '');
    }

    // C 层异步操作，通过回调返回结果
    String userData = Tools.generateUserData('callExperimentalAPI');
    Completer<V2TimValueCallback<Object>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<Object>(userData, completer);

    Pointer<Char> pCJsonParam = Tools.string2PointerChar(json.encode(cJsonParam));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);

    int result = NativeLibraryManager.bindings.DartCallExperimentalAPI(pCJsonParam, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pCJsonParam, pUserData]);
      return V2TimValueCallback<Object>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        NativeLibraryManager.removeTimCallbackFromMap(userData);
        Tools.freePointers([pCJsonParam, pUserData]);
        return V2TimValueCallback<Object>(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "callExperimentalAPI timeout, api: $api");
      },
    ).then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pCJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<int>> checkAbility({int? ability}) async {
    if (!_isInitSDK) {
      return V2TimValueCallback<int>(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: 'sdk not init');
    }

    String userData = Tools.generateUserData('checkAbility');
    Completer<V2TimValueCallback<int>> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      V2TimValueCallback<Map<String, bool>> result = V2TimValueCallback<Map<String, bool>>.fromJson(jsonResult);
      bool checkResult = result.data?['commercial_ability_result_enabled'] ?? false;
      completer.complete(V2TimValueCallback<int>(code: result.code, desc: result.desc, data: checkResult ? 1 : 0));
    }

    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    Map<String, dynamic> cJsonParam = {};
    cJsonParam['request_internal_operation'] = 'internal_operation_is_commercial_ability_enabled';
    cJsonParam['request_is_commercial_ability_enabled_param'] = ability ?? 0;
    Pointer<Char> pCJsonParam = Tools.string2PointerChar(json.encode(cJsonParam));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartCallExperimentalAPI(pCJsonParam, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pCJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<List<V2TimUserStatus>>> getUserStatus({
    required List<String> userIDList,
  }) async {
    if (!_isInitSDK) {
      return V2TimValueCallback<List<V2TimUserStatus>>(
          code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: 'sdk not init');
    }

    String userData = Tools.generateUserData('getUserStatus');
    Completer<V2TimValueCallback<List<V2TimUserStatus>>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<List<V2TimUserStatus>>(userData, completer);

    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(userIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartGetUserStatus(pUserIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> setSelfStatus({
    required String status,
  }) async {
    if (!_isInitSDK) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: 'sdk not init');
    }

    String userData = Tools.generateUserData('setSelfStatus');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Map<String, dynamic> jsonParam = {'user_status_custom_status': status};
    Pointer<Char> pStatus = Tools.string2PointerChar(json.encode(jsonParam));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartSetSelfStatus(pStatus, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pStatus, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> subscribeUserStatus({
    required List<String> userIDList,
  }) async {
    if (!_isInitSDK) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: 'sdk not init');
    }

    if (userIDList.isEmpty) {
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: 'userIDList is empty');
    }

    String userData = Tools.generateUserData('subscribeUserStatus');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(userIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartSubscribeUserStatus(pUserIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> unsubscribeUserStatus({
    required List<String> userIDList,
  }) async {
    if (!_isInitSDK) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: 'sdk not init');
    }

    String userData = Tools.generateUserData('unsubscribeUserStatus');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(userIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartUnsubscribeUserStatus(pUserIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  Future<void> writeSDKLog({
    required String trace,
    int? logLevel,
    String? fileName,
    String? funcName,
    int? lineNum,
  }) async {
    String userData = Tools.generateUserData('uikitTrace');
    Completer<void> completer = Completer();
    void handleApiCallback(Map jsonResult) {
      completer.complete();
    }

    NativeLibraryManager.addTimApiValueCallback2Map(userData, handleApiCallback);

    Map<String, dynamic> cJsonParam = {};
    cJsonParam['request_internal_operation'] = 'internal_operation_write_log';
    cJsonParam['request_write_log_log_level_param'] = logLevel ?? LogLevel.V2TIM_LOG_DEBUG;
    cJsonParam['request_write_log_file_name_param'] = fileName ?? 'flutter_imsdk';
    cJsonParam['request_write_log_log_content_param'] = trace;
    cJsonParam['request_write_log_func_name_param'] = funcName;
    cJsonParam['request_write_log_line_number_param'] = lineNum;
    Pointer<Char> pCJsonParam = Tools.string2PointerChar(json.encode(cJsonParam));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);

    NativeLibraryManager.bindings.DartCallExperimentalAPI(pCJsonParam, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pCJsonParam, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> subscribeUserInfo({
    required List<String> userIDList,
  }) async {
    if (!_isInitSDK) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: 'sdk not init');
    }

    String userData = Tools.generateUserData('subscribeUserInfo');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(userIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartSubscribeUserInfo(pUserIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimCallback> unsubscribeUserInfo({
    required List<String> userIDList,
  }) async {
    if (!_isInitSDK) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: 'sdk not init');
    }

    String userData = Tools.generateUserData('unsubscribeUserInfo');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Char> pUserIDList = Tools.string2PointerChar(json.encode(userIDList));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartUnsubscribeUserInfo(pUserIDList, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pUserIDList, pUserData]);
      return value;
    });
  }

  Future<V2TimValueCallback<V2TimUserSearchResult>> searchUsers({required V2TimUserSearchParam param}) async {
    if (!_isInitSDK) {
      return V2TimValueCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: 'sdk not init');
    }

    String userData = Tools.generateUserData('searchUsers');
    Completer<V2TimValueCallback<V2TimUserSearchResult>> completer = Completer();
    NativeLibraryManager.addTimValueCallback2Map<V2TimUserSearchResult>(userData, completer);

    Pointer<Char> pParam = Tools.string2PointerChar(json.encode(param.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartSearchUsers(pParam, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pParam, pUserData]);
      return value;
    });
  }

  void _initInternalSDKListener(V2TimSDKListener? userListener) {
    _sdkListener = V2TimSDKListener(
      onConnectFailed: (code, desc) {
        for (var listener in v2TimSDKListenerList) {
          listener.onConnectFailed(code, desc);
        }
      },
      onConnecting: () {
        for (var listener in v2TimSDKListenerList) {
          listener.onConnecting();
        }
      },
      onConnectSuccess: () {
        for (var listener in v2TimSDKListenerList) {
          listener.onConnectSuccess();
        }
      },
      onLog: (level, msg) {
        for (var listener in v2TimSDKListenerList) {
          listener.onLog(level, msg);
        }
      },
      onKickedOffline: () {
        for (var listener in v2TimSDKListenerList) {
          listener.onKickedOffline();
        }
      },
      onUserSigExpired: () {
        for (var listener in v2TimSDKListenerList) {
          listener.onUserSigExpired();
        }
      },
      onSelfInfoUpdated: (userInfo) {
        for (var listener in v2TimSDKListenerList) {
          listener.onSelfInfoUpdated(userInfo);
        }
      },
      onUserStatusChanged: (userStatusList) {
        for (var listener in v2TimSDKListenerList) {
          listener.onUserStatusChanged(userStatusList);
        }
      },
      onUserInfoChanged: (userInfoList) {
        for (var listener in v2TimSDKListenerList) {
          listener.onUserInfoChanged(userInfoList);
        }
      },
      onAllReceiveMessageOptChanged: (opt) {
        for (var listener in v2TimSDKListenerList) {
          listener.onAllReceiveMessageOptChanged(opt);
        }
      },
      onExperimentalNotify: (key, param) {
        for (var listener in v2TimSDKListenerList) {
          listener.onExperimentalNotify(key, param);
        }
      },
    );

    bool enableLogCallback = userListener?.hasCustomOnLog ?? false;
    NativeLibraryManager.setSdkListener(_sdkListener, enableLogCallback: enableLogCallback);
  }

  void _initSimpleMessageListener() {
    _advancedMsgListener = V2TimAdvancedMsgListener(
      onRecvNewMessage: (message) {
        if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_TEXT) {
          if (message.groupID != null && message.groupID!.isNotEmpty) {
            for (var listener in v2TimSimpleMsgListenerList) {
              listener.onRecvGroupTextMessage(message.id ?? '', message.groupID!,
                  message.senderGroupMemberInfo ?? V2TimGroupMemberInfo(), message.textElem?.text ?? '');
            }
          } else {
            V2TimUserInfo userInfo =
                V2TimUserInfo(userID: message.sender ?? '', nickName: message.nickName, faceUrl: message.faceUrl);
            for (var listener in v2TimSimpleMsgListenerList) {
              listener.onRecvC2CTextMessage(message.id ?? '', userInfo, message.textElem?.text ?? '');
            }
          }
        } else if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
          if (message.groupID != null && message.groupID!.isNotEmpty) {
            for (var listener in v2TimSimpleMsgListenerList) {
              listener.onRecvGroupCustomMessage(message.id ?? '', message.groupID!,
                  message.senderGroupMemberInfo ?? V2TimGroupMemberInfo(), message.customElem?.data ?? '');
            }
          } else {
            V2TimUserInfo userInfo =
                V2TimUserInfo(userID: message.sender ?? '', nickName: message.nickName, faceUrl: message.faceUrl);
            for (var listener in v2TimSimpleMsgListenerList) {
              listener.onRecvC2CCustomMessage(message.id ?? '', userInfo, message.customElem?.data ?? '');
            }
          }
        }
      },
    );

    TIMMessageManager.instance.addAdvancedMsgListener(_advancedMsgListener);
  }

  void addIMDKListener(V2TimSDKListener? listener) {
    if (listener == null || v2TimSDKListenerList.contains(listener)) {
      return;
    }

    v2TimSDKListenerList.add(listener);
  }

  void removeIMSDKListener(V2TimSDKListener? listener) {
    if (listener == null) {
      return;
    }

    v2TimSDKListenerList.remove(listener);
  }

  void addGroupListener({required V2TimGroupListener listener}) {
    TIMGroupManager.instance.addGroupListener(listener);
  }

  void removeGroupListener({V2TimGroupListener? listener}) {
    TIMGroupManager.instance.removeGroupListener(listener: listener);
  }

  Future<String> addSimpleMsgListener({
    required V2TimSimpleMsgListener listener,
  }) {
    if (v2TimSimpleMsgListenerList.contains(listener)) {
      return Future.value('error: listener already exists');
    }

    v2TimSimpleMsgListenerList.add(listener);
    return Future.value('add success');
  }

  Future<void> removeSimpleMsgListener({
    V2TimSimpleMsgListener? listener,
    String? uuid,
  }) {
    if (listener == null) {
      v2TimSimpleMsgListenerList.clear();
    } else {
      v2TimSimpleMsgListenerList.remove(listener);
    }

    return Future.value();
  }
}
