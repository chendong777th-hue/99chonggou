import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_ringtone.dart';

/// Legacy bridge surface kept for offline-push helpers / compile shims.
/// LiveKit cutover: no TUICallKit dependency.

class AppOfflinePushInfo {
  String title = '';
  String desc = '';
  bool ignoreIOSBadge = false;
  bool isDisablePush = false;
  String iOSSound = '';
  String androidSound = '';
  String androidOPPOChannelID = '';
  String androidFCMChannelID = '';
  int androidVIVOClassification = 0;
  String androidHuaWeiCategory = '';
}

class AppCallKit {
  AppCallKit._();
  static final AppCallKit instance = AppCallKit._();

  static NavigatorObserver? get navigatorObserver => null;

  Future<void> login(int sdkAppId, String userId, String userSig) async {}

  Future<void> logout() async {}

  Future<void> stopRing() => LiveKitCallRingtone.instance.stop();

  void enableIncomingBanner(bool enable) {}

  Future<void> enableMuteMode(bool mute) async {}
}
