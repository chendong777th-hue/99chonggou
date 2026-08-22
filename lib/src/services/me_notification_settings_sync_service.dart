import 'package:tencent_cloud_chat_demo/src/api/me_notification_settings_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/notification_display_mode.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';

/// 同步服务端「未打开时」通知偏好到 [LocalSetting]。
class MeNotificationSettingsSyncService {
  MeNotificationSettingsSyncService._();

  static final MeNotificationSettingsSyncService instance =
      MeNotificationSettingsSyncService._();

  Future<MeNotificationSettings> fetchAndApply(LocalSetting local) async {
    final remote = await MeNotificationSettingsApi.instance.fetch();
    local.applyRemoteNotificationPreferences(
      systemMessageNotificationEnabled: remote.systemMessageNotificationEnabled,
      callNotificationEnabled: remote.callNotificationEnabled,
      notificationDisplayContent: remote.notificationDisplayContent,
    );
    return remote;
  }

  Future<void> updateSystemMessageEnabled(
    LocalSetting local,
    bool enabled,
  ) async {
    final previous = local.notifySystemMessage;
    local.notifySystemMessage = enabled;
    try {
      await MeNotificationSettingsApi.instance.update(
        systemMessageNotificationEnabled: enabled,
      );
    } catch (e) {
      local.notifySystemMessage = previous;
      rethrow;
    }
  }

  Future<void> updateCallNotificationEnabled(
    LocalSetting local,
    bool enabled,
  ) async {
    final previousCall = local.notifyVoiceVideoCall;
    final previousQuick = local.notifyCallQuickAnswerPopup;
    local.notifyVoiceVideoCall = enabled;
    if (!enabled) {
      local.notifyCallQuickAnswerPopup = false;
    }
    try {
      await MeNotificationSettingsApi.instance.update(
        callNotificationEnabled: enabled,
      );
    } catch (e) {
      local.notifyVoiceVideoCall = previousCall;
      local.notifyCallQuickAnswerPopup = previousQuick;
      rethrow;
    }
  }

  Future<void> updateDisplayContent(
    LocalSetting local,
    NotificationDisplayMode mode,
  ) async {
    final previous = local.notifyDisplayContent;
    local.notifyDisplayContent = mode;
    try {
      await MeNotificationSettingsApi.instance.update(
        notificationDisplayContent: mode,
      );
    } catch (e) {
      local.notifyDisplayContent = previous;
      rethrow;
    }
  }
}
