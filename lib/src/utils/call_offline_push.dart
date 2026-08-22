import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_kit_bridge.dart';

class CallOfflinePush {
  CallOfflinePush._();

  static const String fcmChannelId = '99chat_call_channel_v2';

  static AppOfflinePushInfo buildBridge({
    required String desc,
    String? title,
    bool disablePush = false,
  }) {
    final push = AppOfflinePushInfo();
    push.title = title ?? '';
    push.desc = desc;
    push.isDisablePush = disablePush || IMDemoConfig.selfHostedPushEnabled;
    push.ignoreIOSBadge = false;
    // Use system default sound. The old custom sound name had no bundled
    // android/raw or iOS resource in this project, so offline call pushes could
    // arrive silently after background/killed-process delivery.
    push.iOSSound = 'default';
    push.androidSound = 'default';
    push.androidFCMChannelID = fcmChannelId;
    push.androidVIVOClassification = 1;
    push.androidHuaWeiCategory = 'IM';
    return push;
  }

  static AppOfflinePushInfo forBridgeC2CCall({
    required String userId,
    required bool isVideo,
    required String desc,
    String? title,
  }) {
    return buildBridge(title: title, desc: desc);
  }
}
