import 'dart:async';

import 'package:tencent_cloud_chat_sdk/enum/V2TimSignalingListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_signaling_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';

class TIMSignalingManager {
  static TIMSignalingManager instance = TIMSignalingManager();

  TIMSignalingManager();

  void init() {}

  void addSignalingListener(V2TimSignalingListener? listener) {}

  void removeSignalingListener({V2TimSignalingListener? listener}) {}

  Future<V2TimValueCallback<String>> invite({
    required String invitee,
    required String data,
    int timeout = 30,
    bool onlineUserOnly = false,
    OfflinePushInfo? offlinePushInfo,
  }) async {
    return V2TimValueCallback<String>.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<String>> inviteInGroup({
    required String groupID,
    required List<String> inviteeList,
    required String data,
    int timeout = 30,
    bool onlineUserOnly = false,
  }) async {
    return V2TimValueCallback<String>.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> cancel({
    required String inviteID,
    String? data,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> accept({
    required String inviteID,
    String? data,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> reject({
    required String inviteID,
    String? data,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimValueCallback<V2TimSignalingInfo>> getSignalingInfo({
    required String msgID,
  }) async {
    return V2TimValueCallback<V2TimSignalingInfo>.fromBool(
        false, "invoke error");
  }

  Future<V2TimCallback> modifyInvitation({
    required String inviteID,
    String? data,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }
}
