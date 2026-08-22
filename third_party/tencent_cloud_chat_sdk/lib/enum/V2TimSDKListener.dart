// ignore_for_file: prefer_function_declarations_over_variables, file_names

import 'package:tencent_cloud_chat_sdk/enum/callbacks.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_receive_message_opt_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_receive_message_opt_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';

class V2TimSDKListener {
  VoidCallback onConnecting = () {};
  VoidCallback onConnectSuccess = () {};
  ErrorCallback onConnectFailed = (int code, String error) {};
  VoidCallback onKickedOffline = () {};
  VoidCallback onUserSigExpired = () {};
  V2TimUserFullInfoCallback onSelfInfoUpdated = (
    V2TimUserFullInfo info,
  ) {};
  OnUserStatusChanged onUserStatusChanged =
      (List<V2TimUserStatus> userStatusList) {};
  OnLog onLog = (int logLevel, String logContent) {};
  /// 标记用户是否显式传入了 onLog 回调，外部只读
  bool _hasCustomOnLog = false;
  bool get hasCustomOnLog => _hasCustomOnLog;
  OnUserInfoChanged onUserInfoChanged =
      (List<V2TimUserFullInfo> userInfoList) {};
  OnAllReceiveMessageOptChanged onAllReceiveMessageOptChanged =
      (V2TimReceiveMessageOptInfo receiveMessageOptInfo) {};
  OnExperimentalNotify onExperimentalNotify = (String key, dynamic param) {};
  OnUIKitEventEmited onUIKitEventEmited = (UIKitEvent event) {};
  OnPluginEventEmited onPluginEventEmited = (PluginEvent event) {};
  V2TimSDKListener({
    ErrorCallback? onConnectFailed,
    VoidCallback? onConnectSuccess,
    VoidCallback? onConnecting,
    VoidCallback? onKickedOffline,
    V2TimUserFullInfoCallback? onSelfInfoUpdated,
    VoidCallback? onUserSigExpired,
    OnUserStatusChanged? onUserStatusChanged,
    OnLog? onLog,
    OnUserInfoChanged? onUserInfoChanged,
    OnAllReceiveMessageOptChanged? onAllReceiveMessageOptChanged,
    OnExperimentalNotify? onExperimentalNotify,
    OnUIKitEventEmited? onUIKitEventEmited,
    OnPluginEventEmited? onPluginEventEmited,
  }) {
    if (onConnectFailed != null) {
      this.onConnectFailed = onConnectFailed;
    }
    if (onConnectSuccess != null) {
      this.onConnectSuccess = onConnectSuccess;
    }
    if (onConnecting != null) {
      this.onConnecting = onConnecting;
    }
    if (onKickedOffline != null) {
      this.onKickedOffline = onKickedOffline;
    }
    if (onSelfInfoUpdated != null) {
      this.onSelfInfoUpdated = onSelfInfoUpdated;
    }
    if (onUserSigExpired != null) {
      this.onUserSigExpired = onUserSigExpired;
    }
    if (onUserStatusChanged != null) {
      this.onUserStatusChanged = onUserStatusChanged;
    }
    if (onLog != null) {
      this.onLog = onLog;
      _hasCustomOnLog = true;
    }
    if (onUserInfoChanged != null) {
      this.onUserInfoChanged = onUserInfoChanged;
    }
    if (onAllReceiveMessageOptChanged != null) {
      this.onAllReceiveMessageOptChanged = onAllReceiveMessageOptChanged;
    }
    if (onExperimentalNotify != null) {
      this.onExperimentalNotify = onExperimentalNotify;
    }
    if (onUIKitEventEmited != null) {
      this.onUIKitEventEmited = onUIKitEventEmited;
    }
    if (onPluginEventEmited != null) {
      this.onPluginEventEmited = onPluginEventEmited;
    }
  }
}
