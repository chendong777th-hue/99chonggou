import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';

class PushHandler {
  PushHandler._();

  static bool needsTimPush(LocalSetting settings) {
    return settings.notifySystemMessage || settings.notifyVoiceVideoCall;
  }

  static bool allowsMessageBanner(LocalSetting settings) {
    return settings.notifySystemMessage && settings.notifyMessageBanner;
  }

  /// 前台横幅关闭时，仍可按设置播放提示音/振动。
  static bool wantsInAppMessageAlert(LocalSetting settings) {
    return settings.notifyMessageSound || settings.notifyVibration;
  }

  static bool allowsCallNotify(LocalSetting settings) {
    return settings.notifyVoiceVideoCall;
  }
}
