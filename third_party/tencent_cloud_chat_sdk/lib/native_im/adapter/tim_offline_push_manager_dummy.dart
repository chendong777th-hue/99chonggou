import 'dart:async';

import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';

class TIMOfflinePushManager {
  static TIMOfflinePushManager instance = TIMOfflinePushManager();

  TIMOfflinePushManager();

  void init() {}

  Future<V2TimCallback> setOfflinePushConfig({
    required double businessID,
    required String token,
    bool isTPNSToken = false,
    bool isVoip = false,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> doBackground({
    required int unreadCount,
  }) async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

  Future<V2TimCallback> doForeground() async {
    return V2TimCallback.fromBool(false, "invoke error");
  }

}