import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_offline_push_manager.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_offline_push_manager_dummy.dart';
import 'package:tencent_cloud_chat_sdk/tencent_cloud_chat_sdk_platform_interface.dart';

class V2TIMOfflinePushManager {
  ///   设置离线推送配置信息
  ///
  /// 参数
  ///
  /// ```
  /// config	离线推送配置
  /// callback	回调
  /// isTPNSToken 是否使用tpnstoken
  /// ```
  ///
  Future<V2TimCallback> setOfflinePushConfig({
    required double businessID,
    required String token,
    bool isTPNSToken = false,
    bool isVoip = false,
  }) async {
    if (kIsWeb || Platform.isIOS) {
      return TencentCloudChatSdkPlatform.instance.setOfflinePushConfig(
        businessID: businessID,
        token: token,
        isTPNSToken: isTPNSToken,
        isVoip: isVoip,
      );
    }

    return TIMOfflinePushManager.instance.setOfflinePushConfig(
      businessID: businessID,
      token: token,
      isTPNSToken: isTPNSToken,
      isVoip: isVoip,
    );
  }

  /// APP 检测到应用退后台时可以调用此接口，可以用作桌面应用角标的初始化未读数量。
  ///
  /// ```
  /// 从5.0.1（native）版本开始，如果配置了离线推送，会收到厂商的离线推送通道下发的通知栏消息，注意：仅安卓端和 iOS 端需要调用。
  /// ```
  ///
  /// 参数
  ///
  /// ```
  /// unreadCount	未读数量
  /// callback	回调
  /// ```
  Future<V2TimCallback> doBackground({
    required int unreadCount,
  }) async {
    if (kIsWeb || Platform.isIOS) {
      return TencentCloudChatSdkPlatform.instance.doBackground(unreadCount: unreadCount);
    }

    return TIMOfflinePushManager.instance.doBackground(unreadCount: unreadCount);
  }

  /// APP 检测到应用进前台时可以调用此接口
  ///
  /// ```
  /// 从5.0.1（native）版本开始，对应 doBackground，会停止厂商的离线推送。但如果应用被 kill，仍然可以正常接收离线推送 注意：仅安卓端需要调用。
  /// ```
  ///
  /// 参数
  ///
  /// ```
  /// callback	回调
  /// ```
  Future<V2TimCallback> doForeground() async {
    if (kIsWeb || Platform.isIOS) {
      return TencentCloudChatSdkPlatform.instance.doForeground();
    }

    return TIMOfflinePushManager.instance.doForeground();
  }

  ///@nodoc
  Map buildParam(Map param) {
    param["TIMManagerName"] = "offlinePushManager";
    return param;
  }

  ///@nodoc
  formatJson(jsonSrc) {
    return json.decode(json.encode(jsonSrc));
  }
}
