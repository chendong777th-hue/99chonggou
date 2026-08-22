import 'dart:async';

import 'package:tencent_cloud_chat_sdk/enum/V2TimGroupListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSimpleMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_search_param.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_search_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';

class TIMManager {
  static TIMManager instance = TIMManager();

  TIMManager();

  bool isInitSDK() {
    return false;
  }

  int? getSDKAppID() {
    return 0;
  }

  void addSDKListener(V2TimSDKListener? listener) {}

  void removeSDKListener({V2TimSDKListener? listener}) {}

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
    return false;
  }

  bool unInitSDK() {
    return false;
  }

  String getSDKVersion() {
    return '';
  }

  int getServerTime() {
    return 0;
  }

  Future<V2TimCallback> login({
    required String userID,
    required String userSig,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> logout() async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  String getLoginUser() {
    return '';
  }

  int getLoginStatus() {
    return 0;
  }

  Future<V2TimCallback> joinGroup({
    required String groupID,
    required String message,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> quitGroup({
    required String groupID,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> dismissGroup({
    required String groupID,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimUserFullInfo>>> getUsersInfo({
    required List<String> userIDList,
  }) async {
    return V2TimValueCallback<List<V2TimUserFullInfo>>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> setSelfInfo({
    required V2TimUserFullInfo userFullInfo,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<Object>> callExperimentalAPI({
    required String api,
    Object? param,
  }) async {
    return V2TimValueCallback<Object>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<int>> checkAbility({int? ability}) async {
    return V2TimValueCallback<int>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<List<V2TimUserStatus>>> getUserStatus({
    required List<String> userIDList,
  }) async {
    return V2TimValueCallback<List<V2TimUserStatus>>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> setSelfStatus({
    required String status,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> subscribeUserStatus({
    required List<String> userIDList,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> unsubscribeUserStatus({
    required List<String> userIDList,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<void> writeSDKLog({
    required String trace,
    int? logLevel,
    String? fileName,
    String? funcName,
    int? lineNum,
  }) async {
    return Future.value();
  }

  Future<V2TimCallback> subscribeUserInfo({
    required List<String> userIDList,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> unsubscribeUserInfo({
    required List<String> userIDList,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimUserSearchResult>> searchUsers({required V2TimUserSearchParam param}) async {
    return V2TimValueCallback<V2TimUserSearchResult>.fromBool(false, "invoke error");
  }

  void addIMDKListener(V2TimSDKListener? listener) {}

  void removeIMSDKListener(V2TimSDKListener? listener) {}

  void addGroupListener({required V2TimGroupListener listener}) {}

  void removeGroupListener({V2TimGroupListener? listener}) {}

  Future<String> addSimpleMsgListener({
    required V2TimSimpleMsgListener listener,
  }) {
    return Future.value("invoke error");
  }

  Future<void> removeSimpleMsgListener({
    V2TimSimpleMsgListener? listener,
    String? uuid,
  }) {
    return Future.value();
  }
}
