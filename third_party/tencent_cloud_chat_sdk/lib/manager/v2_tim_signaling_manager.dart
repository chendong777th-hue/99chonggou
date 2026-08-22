// ignore_for_file: unused_field

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSignalingListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_signaling_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_signaling_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_signaling_manager.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_signaling_manager_dummy.dart';
import 'package:tencent_cloud_chat_sdk/tencent_cloud_chat_sdk_platform_interface.dart';

class V2TIMSignalingManager {
  ///添加信令监听
  ///
  Future<void> addSignalingListener({
    required V2TimSignalingListener listener,
  }) {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.addSignalingListener(
        listener: listener,
      );
    }

    TIMSignalingManager.instance.addSignalingListener(listener);
    return Future.value();
  }

  ///移除信令监听
  ///
  Future<void> removeSignalingListener({
    V2TimSignalingListener? listener,
  }) {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
          .removeSignalingListener(listener: listener);
    }

    TIMSignalingManager.instance.removeSignalingListener(listener: listener);
    return Future.value();
  }

  Future<V2TimValueCallback<String>> invite({
    required String invitee,
    required String data,
    int timeout = 30,
    bool onlineUserOnly = false,
    OfflinePushInfo? offlinePushInfo,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.invite(
          invitee: invitee,
          data: data,
          timeout: timeout,
          onlineUserOnly: onlineUserOnly,
          offlinePushInfo: offlinePushInfo);
    }

    return TIMSignalingManager.instance.invite(
        invitee: invitee,
        data: data,
        timeout: timeout,
        onlineUserOnly: onlineUserOnly,
        offlinePushInfo: offlinePushInfo);
  }

  Future<V2TimValueCallback<String>> inviteInGroup({
    required String groupID,
    required List<String> inviteeList,
    required String data,
    int timeout = 30,
    bool onlineUserOnly = false,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.inviteInGroup(
          groupID: groupID,
          inviteeList: inviteeList,
          data: data,
          timeout: timeout,
          onlineUserOnly: onlineUserOnly);
    }

    return TIMSignalingManager.instance.inviteInGroup(
        groupID: groupID,
        inviteeList: inviteeList,
        data: data,
        timeout: timeout,
        onlineUserOnly: onlineUserOnly);
  }

  Future<V2TimCallback> cancel({
    required String inviteID,
    String? data,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.cancel(
        inviteID: inviteID,
        data: data,
      );
    }

    return TIMSignalingManager.instance.cancel(
      inviteID: inviteID,
      data: data,
    );
  }

  Future<V2TimCallback> accept({
    required String inviteID,
    String? data,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.accept(
        inviteID: inviteID,
        data: data,
      );
    }

    return TIMSignalingManager.instance.accept(
      inviteID: inviteID,
      data: data,
    );
  }

  Future<V2TimCallback> reject({
    required String inviteID,
    String? data,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.reject(
        inviteID: inviteID,
        data: data,
      );
    }

    return TIMSignalingManager.instance.reject(
      inviteID: inviteID,
      data: data,
    );
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
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getSignalingInfo(
        msgID: msgID,
      );
    }
  
    return TIMSignalingManager.instance.getSignalingInfo(
      msgID: msgID,
    );
  }

  Future<V2TimCallback> addInvitedSignaling({
    required V2TimSignalingInfo info,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.addInvitedSignaling(
        info: info,
      );
    }

    // 该接口在 native 6.7 版本后废弃，使用 V2TimSignalingListener 中的 onReceiveNewInvitation 就可以正常收到信令
    return V2TimCallback.fromBool(true, '');
  }

  Future<V2TimCallback> modifyInvitation({
    required String inviteID,
    String? data,
  }) async {
    if (kIsWeb) {
      return V2TimCallback(code: 0, desc: '');
    }

    return TIMSignalingManager.instance.modifyInvitation(
      inviteID: inviteID,
      data: data,
    );
  }
}
